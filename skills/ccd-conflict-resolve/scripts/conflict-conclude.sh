#!/bin/sh
# Conclude the operation, once no conflicts remain.
#
# Takes no arguments. Dispatches on whichever operation is in progress.
#
# Exit 0: concluded.
# Exit 1: not a git repository, or git unavailable.
# Exit 2: conflicts remain. NOTHING concluded -- go back and list them.
# Exit 3: no operation is in progress, so there is nothing to conclude. Not an
#         error; the tree may simply be clean.
# Exit 4: staged paths were found that are not part of the resolution. NOTHING
#         concluded, and each is printed so the caller can report them.
# Exit 5: the concluding command itself failed. Its stderr is passed through and
#         THE RESOLVED CONTENT IS LEFT IN PLACE.
#
# WHY EXIT 4 REFUSES RATHER THAN FIXES. Concluding commits the whole index and
# `git commit` refuses to be limited to pathnames during a merge, so what is
# staged at this moment is exactly what gets committed. This script does not
# unstage anything: unstaging is a mutation the user did not approve, and an
# unrelated staged change may well be deliberate. It stops, names the paths, and
# lets the caller ask.
#
# What that check must NOT flag: git stages the cleanly-merged paths itself when
# a merge stops on a conflict, and those are part of the operation rather than
# unrelated work. Pre-existing local modifications are left unstaged, matching
# HEAD. So the comparison is against the operation's own changed set, not
# against "anything staged".
#
# WHY EXIT 5 NEVER REVERTS. A hand resolution that was never committed has no
# reflog entry and no rerere record; it exists only in the working tree. A
# script that "cleaned up" after a failed conclude would destroy work that
# exists nowhere else.

set -u

if ! command -v git > /dev/null 2>&1; then
	echo "no-git: git is not on PATH; install git or add it to PATH" >&2
	exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the repository with the conflict" >&2
	exit 1
fi

remaining=$(git ls-files -u -- | cut -f2 | sort -u | grep -c . || true)
if [ "$remaining" -ne 0 ]; then
	echo "conflicts-remain: $remaining path(s) still unmerged; nothing concluded" >&2
	exit 2
fi

operation=none
if git rev-parse --verify --quiet MERGE_HEAD > /dev/null 2>&1; then
	operation=merge
elif git rev-parse --verify --quiet CHERRY_PICK_HEAD > /dev/null 2>&1; then
	operation=cherry-pick
elif git rev-parse --verify --quiet REVERT_HEAD > /dev/null 2>&1; then
	operation=revert
elif git rev-parse --verify --quiet REBASE_HEAD > /dev/null 2>&1; then
	operation=rebase
fi

if [ "$operation" = none ]; then
	echo "no-operation: nothing is in progress to conclude" >&2
	exit 3
fi

# The operation's own changed set, against which staged paths are judged. For a
# merge this is everything that differs between HEAD and the merged-in commit,
# which is exactly what git staged for us plus what we resolved.
case "$operation" in
	merge)
		other=MERGE_HEAD
		;;
	cherry-pick)
		other=CHERRY_PICK_HEAD
		;;
	revert)
		other=REVERT_HEAD
		;;
	rebase)
		other=REBASE_HEAD
		;;
	*)
		other=''
		;;
esac

unrelated=''
if [ -n "$other" ]; then
	base=$(git merge-base HEAD "$other" 2> /dev/null || true)
	if [ -n "$base" ]; then
		operation_paths=$(git diff --name-only "$base" "$other" -- 2> /dev/null || true)
		staged_paths=$(git diff --cached --name-only -- 2> /dev/null || true)
		for p in $staged_paths; do
			if ! printf '%s\n' "$operation_paths" | grep -qxF "$p"; then
				unrelated="$unrelated$p
"
			fi
		done
	fi
fi

if [ -n "$unrelated" ]; then
	echo "staged-unrelated: these staged paths are not part of the operation; nothing concluded" >&2
	printf '%s' "$unrelated" >&2
	exit 4
fi

case "$operation" in
	merge)
		git commit --no-edit || exit 5
		;;
	rebase)
		git rebase --continue || exit 5
		;;
	cherry-pick)
		git cherry-pick --continue || exit 5
		;;
	revert)
		git revert --continue || exit 5
		;;
	*)
		# Unreachable: `none` exited at 3 above and the detection sets no other
		# value. Present because a silent fallthrough here would report success
		# having concluded nothing.
		echo "no-operation: unrecognised operation '$operation'; nothing concluded" >&2
		exit 3
		;;
esac

exit 0
