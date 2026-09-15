#!/bin/sh
# Report whether the working tree is conflicted, for the boundary check ccd-speckit-run runs
# after every step and every phase.
#
# Two conditions make a tree conflicted, and the second is the reason this script exists rather
# than a `git status --porcelain` grep:
#
#   1. Unmerged paths in the index, from git's own `ls-files -u`.
#   2. An interrupted merge, rebase, cherry-pick or revert, from the marker files git itself
#      writes under the git dir. A rebase whose conflicts were resolved but never continued
#      leaves a CLEAN-LOOKING working tree and a repository still mid-operation. Committing into
#      that state is the failure this check prevents, and porcelain output does not report it.
#
# Porcelain prose is also localizable and its wording is not a stability contract.
#
# Output is tab-separated key/value lines, matching forge-detect.sh and resume-state.sh.
# Contract: specs/006-claude-code-guidance/contracts/conflict-state-cli.md
#
# EXIT STATUS IS NOT THE VERDICT. `exit 0` means the check ran; read the `verdict` line.

set -eu

# --git-dir, not --git-common-dir: an in-progress operation belongs to the worktree running it,
# and in a worktree those two paths differ.
git_dir=''
if ! git_dir=$(git rev-parse --git-dir 2> /dev/null); then
	printf 'verdict\tunknown\n'
	printf 'reason\tnot a git repository, or git unavailable\n'
	exit 1
fi

# Assigned on its own line and its status checked, never piped into a counter: `git ls-files -u |
# wc -l` reports wc's status, not git's, which Principle II forbids and shellcheck does not
# always catch.
unmerged_raw=''
if ! unmerged_raw=$(git ls-files -u); then
	printf 'verdict\tunknown\n'
	printf 'reason\tgit ls-files -u failed\n'
	exit 2
fi

# `ls-files -u` prints one line per stage per path, so the same path appears up to three times.
unmerged=0
paths=''
if [ -n "$unmerged_raw" ]; then
	paths=$(printf '%s\n' "$unmerged_raw" | cut -f2 | sort -u)
	count=$(printf '%s\n' "$paths" | wc -l)
	unmerged=$(printf '%s' "$count" | tr -d '[:space:]')
fi

operation=none
if [ -e "$git_dir/MERGE_HEAD" ]; then
	operation=merge
elif [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] || [ -e "$git_dir/REBASE_HEAD" ]; then
	operation=rebase
elif [ -e "$git_dir/CHERRY_PICK_HEAD" ]; then
	operation=cherry-pick
elif [ -e "$git_dir/REVERT_HEAD" ]; then
	operation=revert
fi

verdict=clean
if [ "$unmerged" -gt 0 ] || [ "$operation" != none ]; then
	verdict=conflicted
fi

printf 'verdict\t%s\n' "$verdict"
printf 'unmerged\t%s\n' "$unmerged"
printf 'operation\t%s\n' "$operation"

if [ -n "$paths" ]; then
	printf '%s\n' "$paths" | while IFS= read -r conflicted_path; do
		printf 'paths\t%s\n' "$conflicted_path"
	done
fi
