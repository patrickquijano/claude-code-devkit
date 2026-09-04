#!/bin/sh
# Apply one approved resolution to one path, and stage it.
#
#	conflict-apply.sh <mechanism> <path>
#
# <mechanism> is one of five:
#
#	ours	check out stage 2, then stage the path
#	theirs	check out stage 3, then stage the path
#	union	three-way merge taking lines from both sides, then stage
#	staged	stage content already written into the working tree by hand
#	remove	git rm the path, recording the deletion as the resolution
#
# Exit 0: applied and staged.
# Exit 1: not a git repository, or git unavailable.
# Exit 2: the path is not unmerged. Nothing changed.
# Exit 3: the mechanism is not valid for that path. Nothing changed.
# Exit 4: a `staged` apply found conflict markers still present. NOTHING staged.
#
# WHY `remove` EXISTS. A both-deleted path has neither stage 2 nor stage 3, so
# `ours` and `theirs` are both invalid for it and every content-selecting
# mechanism fails. Without `remove` that kind would be reportable and never
# resolvable. It also serves the modify/delete cases, where accepting the
# deletion is one of the two sensible answers. Note that git-rm(1) documents no
# role in conflict resolution -- the behaviour is real and the documentation is
# silent, which is why it is written down here.
#
# WHY STAGING IS ONE PATH AT A TIME. Concluding commits the whole index, and
# `git commit` refuses to be limited to pathnames during a merge. So the only
# control over what gets committed is what was staged, and the only way to keep
# that narrow is to stage exactly one known path per invocation. Never
# `git add -A`, never `git add .`, never `git commit -a`.
#
# ABORT IS NOT A MECHANISM. Abandoning the operation acts on the whole
# operation rather than on one path, so it belongs to the skill body, which runs
# the matching `--abort`. Passing `abort` here is exit 3.

set -u

usage() {
	echo "usage: conflict-apply.sh <ours|theirs|union|staged|remove> <path>" >&2
}

if [ "$#" -ne 2 ]; then
	usage
	exit 3
fi

mechanism=$1
path=$2

if ! command -v git > /dev/null 2>&1; then
	echo "no-git: git is not on PATH; install git or add it to PATH" >&2
	exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the repository with the conflict" >&2
	exit 1
fi

# Which stages exist for this path decides which mechanisms are valid.
stages=$(git ls-files -u -- "$path" | cut -f1 | cut -d' ' -f3 | sort -u || true)
if [ -z "$stages" ]; then
	echo "not-unmerged: $path is not a conflicted path" >&2
	exit 2
fi

has_stage() {
	printf '%s\n' "$stages" | grep -qx "$1"
}

case "$mechanism" in
	ours)
		if ! has_stage 2; then
			echo "invalid-mechanism: $path has no stage 2; 'ours' cannot apply" >&2
			exit 3
		fi
		git checkout-index -f --stage=2 -- "$path" || exit 3
		git add -- "$path" || exit 3
		;;
	theirs)
		if ! has_stage 3; then
			echo "invalid-mechanism: $path has no stage 3; 'theirs' cannot apply" >&2
			exit 3
		fi
		git checkout-index -f --stage=3 -- "$path" || exit 3
		git add -- "$path" || exit 3
		;;
	union)
		if ! has_stage 1 || ! has_stage 2 || ! has_stage 3; then
			echo "invalid-mechanism: $path lacks all three stages; 'union' needs a common ancestor" >&2
			exit 3
		fi
		tmpdir=$(mktemp -d) || exit 3
		git show ":1:$path" > "$tmpdir/base" 2> /dev/null || exit 3
		git show ":2:$path" > "$tmpdir/ours" 2> /dev/null || exit 3
		git show ":3:$path" > "$tmpdir/theirs" 2> /dev/null || exit 3
		# merge-file exits with the number of conflicts; --union leaves none, so
		# a non-zero status here is a real failure rather than a conflict count.
		if ! git merge-file --union -p "$tmpdir/ours" "$tmpdir/base" "$tmpdir/theirs" > "$tmpdir/merged"; then
			rm -rf "$tmpdir"
			echo "invalid-mechanism: union merge of $path failed" >&2
			exit 3
		fi
		cp "$tmpdir/merged" "$path" || exit 3
		rm -rf "$tmpdir"
		git add -- "$path" || exit 3
		;;
	staged)
		if [ ! -f "$path" ]; then
			echo "invalid-mechanism: $path is not a file in the working tree" >&2
			exit 3
		fi
		# Exit 4 exists because this is the one mechanism whose content this
		# script did not produce. Staging a file that still carries markers
		# would mark a conflict resolved that is not, and concluding would
		# then commit the markers.
		if grep -qE '^(<<<<<<<|=======|>>>>>>>|\|\|\|\|\|\|\|)' "$path"; then
			echo "markers-remain: $path still contains conflict markers; nothing staged" >&2
			exit 4
		fi
		git add -- "$path" || exit 3
		;;
	remove)
		if has_stage 2 && has_stage 3; then
			echo "invalid-mechanism: $path exists on both sides; 'remove' is for deletion conflicts" >&2
			exit 3
		fi
		git rm -q -f -- "$path" || exit 3
		;;
	*)
		echo "invalid-mechanism: '$mechanism' is not a mechanism" >&2
		usage
		exit 3
		;;
esac

exit 0
