#!/bin/sh
# Ranked base-branch candidates for an AskUserQuestion option set.
#
# Output, tab separated, repo default branch first then newest commit first:
#   <branch>  local|remote|both  <YYYY-MM-DD>  <tags>
#
# <tags> is a comma-joined subset of "default" and "current", or "-" when
# neither applies. Take the first four lines for the option set; the tool
# injects its own "Other" entry for anything outside them.
#
# Read-only with respect to the working tree. Fetches every configured remote
# first so remote-only branches are current; a failed fetch is reported on
# stderr and the listing continues from the refs already on disk.
#
# Exit 1: not a git repository. Exit 0 otherwise, including a repo with no
# commits or no remotes (possibly empty listing).
#
# THE ONLY COPY. Four skills consume this script -- auto-branch-push,
# auto-github-pr, auto-gitlab-mr and speckit-run -- and all four invoke this
# one file at
#   ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh
# Do not copy it into a consuming skill to make that skill self-contained.
# Self-containment is what produced four copies, and comparing copies is how
# the divergence below survived: the three drift checks that existed compared
# three of the four and never the fourth.
#
# WHAT WAS REJECTED, and why it must not be reintroduced as a simplification.
# speckit-run carried a 48-line fork of this script. It was shorter, and three
# of its behaviours were wrong:
#
#   1. It emitted refs/remotes/<remote>/HEAD as a branch. Git's short form
#      renders that ref as a bare remote name, so the listing contained a row
#      whose branch column read "origin" -- indistinguishable from a real
#      branch of that name, and offerable as a base branch that does not
#      exist. This was not theoretical: it was observed in a live run.
#   2. It lost the current branch on an unborn HEAD. A repository with no
#      commits yet has a symbolic HEAD but no commit to resolve, and the fork's
#      resolution returned empty, so no row carried the "current" tag.
#   3. It had no default-branch concept. The fourth column was "current" or
#      "-", and the ordering was commit date alone, so the branch a base
#      almost always is could appear anywhere in the list.
#
# The fix for each is above, not clever: excluding the symbolic ref by name
# rather than by pattern, resolving HEAD with symbolic-ref rather than through
# a commit, and resolving the default branch from refs/remotes/origin/HEAD with
# a main/master/develop fallback. A shorter version of this file that drops any
# of the three is not a simplification; it is a reintroduction. FR-011 of
# specs/002-vendor-plugin-skills is the requirement that reconciled the four.
set -u

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the target repository" >&2
	exit 1
fi

# symbolic-ref is the right probe: empty on detached HEAD, and it still names
# the branch on an unborn HEAD (fresh repo with no commits).
current=$(git symbolic-ref --short -q HEAD 2> /dev/null || true)

for r in $(git remote); do
	git fetch --quiet "$r" 2> /dev/null \
		|| echo "fetch-failed: $r (listing continues from local refs)" >&2
done

# Repo default branch, from origin's symbolic HEAD. Falls back to the first of
# main/master/develop that actually exists, then to empty (no branch pinned).
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2> /dev/null \
	| sed 's|^[^/]*/||')
if [ -z "$default" ]; then
	for c in main master develop; do
		if git show-ref --verify --quiet "refs/heads/$c" \
			|| git show-ref --verify --quiet "refs/remotes/origin/$c"; then
			default=$c
			break
		fi
	done
fi

tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT INT TERM

git for-each-ref --format='%(refname:short)	%(committerdate:short)' \
	refs/heads > "$tmpdir/local" 2> /dev/null || : > "$tmpdir/local"
# Full refname here, not the short form: git shortens refs/remotes/origin/HEAD
# to plain "origin", which is indistinguishable from a branch named "origin".
git for-each-ref --format='%(refname)	%(committerdate:short)' \
	refs/remotes > "$tmpdir/remote.raw" 2> /dev/null || : > "$tmpdir/remote.raw"

# refs/remotes/origin/dev -> dev, dropping every remote's symbolic HEAD.
awk -F'\t' '{
	n = $1
	sub(/^refs\/remotes\/[^\/]+\//, "", n)
	if (n == "HEAD" || n == "" || n == $1) next
	print n "\t" $2
}' "$tmpdir/remote.raw" > "$tmpdir/remote"

awk -F'\t' -v cur="$current" -v def="$default" '
	NR == FNR { loc[$1] = $2; next }
	{
		if ($1 in loc) { both[$1] = 1; if ($2 > loc[$1]) loc[$1] = $2 }
		else if (!($1 in rem) || $2 > rem[$1]) { rem[$1] = $2 }
	}
	function tags(b) {
		t = ""
		if (b == def) t = "default"
		if (b == cur) t = (t == "" ? "current" : t ",current")
		return (t == "" ? "-" : t)
	}
	# Sort key: default branch first (0), everything else after (1).
	function rank(b) { return (b == def ? 0 : 1) }
	END {
		for (b in loc)
			printf "%d\t%s\t%s\t%s\t%s\n", rank(b), b,
				(b in both ? "both" : "local"), loc[b], tags(b)
		for (b in rem)
			printf "%d\t%s\t%s\t%s\t%s\n", rank(b), b, "remote", rem[b], tags(b)
	}
' "$tmpdir/local" "$tmpdir/remote" \
	| sort -t'	' -k1,1 -k4,4r -k2,2 \
	| cut -f2-
