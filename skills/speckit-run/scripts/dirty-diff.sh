#!/bin/sh
# speckit-run — tell this run's output apart from pre-existing uncommitted work.
#
# Usage:
#   dirty-diff.sh snapshot <file>   Step 1: record the paths dirty before the run.
#   dirty-diff.sh compare  <file>   Step 6a: split today's dirty paths against it.
#
# compare output, tab separated:
#   pre-existing|new|internal  <path>
#
# internal marks this run's own bookkeeping (.specify/.speckit-*), which is
# never reported as the run's output.
#
# A missing snapshot file is not an error: everything is reported as new and a
# note goes to stderr, because that is the state after a run that skipped Step 1.
set -u

mode=${1:-}
file=${2:-}

if [ -z "$mode" ] || [ -z "$file" ]; then
	echo "usage: dirty-diff.sh snapshot|compare <file>" >&2
	exit 2
fi

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the target repository" >&2
	exit 1
fi

# Porcelain v1: the two status letters are columns 1-2, the path field starts at
# column 4. Only a rename or copy (R or C in either column) reads "old -> new",
# and for those the new path is the one that exists on disk, so that is the one
# recorded. Stripping the arrow unconditionally would truncate any path that
# legitimately contains " -> ", rewriting it to something that then fails to
# match its own snapshot entry — the exact misfiling this script prevents.
# --untracked-files=all expands untracked directories into their files, so a
# whole-directory entry can never hide this run's own bookkeeping inside it.
# core.quotepath=false stops git backslash-escaping non-ASCII bytes, which would
# otherwise make a path fail to match its own snapshot entry and be misread as new.
dirty_paths() {
	git -c core.quotepath=false status --porcelain=v1 --untracked-files=all 2> /dev/null \
		| awk '{ xy = substr($0, 1, 2); path = substr($0, 4); if (xy ~ /[RC]/) sub(/^.* -> /, "", path); print path }' \
		| sed 's/^"\(.*\)"$/\1/' | sort -u
}

is_internal() {
	case "$1" in
		.specify/.speckit-*) return 0 ;;
		*) return 1 ;;
	esac
}

case "$mode" in
	snapshot)
		dir=$(dirname "$file")
		[ -d "$dir" ] || mkdir -p "$dir" || exit 1
		dirty_paths | grep -v '^\.specify/\.speckit-' > "$file" || : > "$file"
		count=$(wc -l < "$file" | tr -d ' ')
		echo "snapshot written: $file ($count pre-existing dirty paths)"
		;;
	compare)
		tmp=$(mktemp) || exit 1
		trap 'rm -f "$tmp"' EXIT INT TERM
		dirty_paths > "$tmp"

		have_snapshot=yes
		if [ ! -f "$file" ]; then
			have_snapshot=no
			echo "snapshot-missing: $file — every dirty path reported as new" >&2
		fi

		while IFS= read -r path; do
			[ -n "$path" ] || continue
			if is_internal "$path"; then
				printf 'internal\t%s\n' "$path"
			elif [ "$have_snapshot" = yes ] && grep -qxF -- "$path" "$file"; then
				printf 'pre-existing\t%s\n' "$path"
			else
				printf 'new\t%s\n' "$path"
			fi
		done < "$tmp"
		;;
	*)
		echo "usage: dirty-diff.sh snapshot|compare <file>" >&2
		exit 2
		;;
esac
