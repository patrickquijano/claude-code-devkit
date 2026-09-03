#!/bin/sh
# ccd-speckit-run Step 6c — print a delete/keep verdict for every local branch.
#
# Usage: cleanup-plan.sh [protected-branch]
#   protected-branch defaults to the currently checked-out branch.
#
# Output, tab separated:
#   <branch>  delete|keep  <reason>
#
# Read-only: decides, never deletes. A branch is only marked delete when its
# upstream already contains every one of its commits, so deleting it cannot
# lose work. Everything else is kept, with the reason stated.
set -u

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the target repository" >&2
	exit 1
fi

protected=${1:-}
if [ -z "$protected" ]; then
	protected=$(git rev-parse --abbrev-ref HEAD 2> /dev/null || echo "")
	[ "$protected" = "HEAD" ] && protected=""
fi

checked_out=$(git worktree list --porcelain 2> /dev/null | awk '/^branch /{ n=$2; sub(/^refs\/heads\//, "", n); print n }')

is_checked_out() {
	for b in $checked_out; do
		[ "$b" = "$1" ] && return 0
	done
	return 1
}

git for-each-ref --format='%(refname:short)' refs/heads 2> /dev/null | while IFS= read -r branch; do
	[ -n "$branch" ] || continue

	if [ -n "$protected" ] && [ "$branch" = "$protected" ]; then
		printf '%s\tkeep\tprotected (base branch)\n' "$branch"
		continue
	fi

	if is_checked_out "$branch"; then
		printf '%s\tkeep\tchecked out in a worktree\n' "$branch"
		continue
	fi

	upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch@{u}" 2> /dev/null || true)
	if [ -z "$upstream" ]; then
		printf '%s\tkeep\tno upstream — work exists only here\n' "$branch"
		continue
	fi

	ahead=$(git rev-list --count "$upstream".."$branch" 2> /dev/null || echo unknown)
	case "$ahead" in
		0) printf '%s\tdelete\tlevel with %s\n' "$branch" "$upstream" ;;
		unknown) printf '%s\tkeep\tcannot compare against %s\n' "$branch" "$upstream" ;;
		*) printf '%s\tkeep\t%s commits not on %s\n' "$branch" "$ahead" "$upstream" ;;
	esac
done
