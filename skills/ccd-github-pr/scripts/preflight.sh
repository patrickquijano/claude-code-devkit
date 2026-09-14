#!/bin/sh
# Preflight checks for ccd-github-pr: establish head branch, verify GitHub
# remote, confirm gh is installed and authenticated, fetch repo metadata,
# check whether the branch exists on the remote, and list any existing PRs.
#
# Usage: sh preflight.sh
#
# Output (to stdout), one section per line, pipe-separated fields:
#   BRANCH|<head-branch-name>
#   GIT_DIR|<git-dir>|<git-common-dir>
#   REMOTE_URL|<origin-url>
#   REPO_JSON|<json-from-gh-repo-view>
#   REMOTE_BRANCH|present|absent
#   PR_LIST|<json-array-or-empty>
#
# Exit codes:
#   0 - all checks passed, output on stdout
#   1 - not inside a git work tree
#   2 - detached HEAD (no head branch)
#   3 - remote is not GitHub
#   4 - gh missing
#   5 - gh unauthenticated
#   6 - gh repo view failed
#   7 - gh pr list failed
set -eu

# --- Git work tree ---
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this skill from inside a git working tree" >&2
	exit 1
fi

# --- Head branch ---
head_branch=$(git rev-parse --abbrev-ref HEAD) || {
	echo "detached-head: checkout a branch before opening a PR" >&2
	exit 2
}
if [ "$head_branch" = "HEAD" ]; then
	echo "detached-head: checkout a branch before opening a PR" >&2
	exit 2
fi
printf 'BRANCH|%s\n' "$head_branch"

# --- Git directories (differ inside a worktree) ---
git_dir=$(git rev-parse --git-dir) || exit 1
git_common_dir=$(git rev-parse --git-common-dir) || exit 1
printf 'GIT_DIR|%s|%s\n' "$git_dir" "$git_common_dir"

# --- Remote URL ---
remote_url=$(git remote get-url origin 2> /dev/null) || {
	echo "no-origin-remote: add an origin remote pointing to GitHub" >&2
	exit 3
}
case "$remote_url" in
	*github.com* | *github.enterprise* | *ghe.com*) ;;
	*)
		echo "not-github-remote: origin ($remote_url) is not a GitHub host; use ccd-gitlab-mr instead" >&2
		exit 3
		;;
esac
printf 'REMOTE_URL|%s\n' "$remote_url"

# --- gh CLI ---
if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 4
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 5
fi

# --- Repo metadata ---
repo_json=$(gh repo view --json nameWithOwner,isFork,parent,viewerPermission,defaultBranchRef,squashMergeAllowed,deleteBranchOnMerge 2> /dev/null) || {
	echo "gh-repo-view-failed: could not fetch repository metadata" >&2
	exit 6
}
printf 'REPO_JSON|%s\n' "$repo_json"

# --- Branch on remote ---
if git ls-remote --heads origin "$head_branch" 2> /dev/null | grep -q .; then
	printf 'REMOTE_BRANCH|present\n'
else
	printf 'REMOTE_BRANCH|absent\n'
fi

# --- Existing PRs for this branch ---
pr_list=$(gh pr list --head "$head_branch" --state all \
	--json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author 2> /dev/null) || {
	echo "gh-pr-list-failed: could not list pull requests for $head_branch" >&2
	exit 7
}
printf 'PR_LIST|%s\n' "$pr_list"

exit 0
