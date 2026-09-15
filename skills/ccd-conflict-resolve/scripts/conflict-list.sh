#!/bin/sh
# Every conflicted path, with its classification.
#
# Output, tab separated, one record per path, sorted by path:
#
#	<path>	<kind>	<stages>	<text|binary>
#
# <kind> is one of nine:
#
#	both-modified	both-added	both-deleted
#	added-by-us	added-by-them
#	deleted-by-us	deleted-by-them
#	type-changed	binary
#
# <stages> is three characters drawn from 1/2/3 and `-`, showing which index
# stages are present: `123` for a both-modified path, `-23` for a both-added
# one, `12-` for deleted-by-them.
#
# Read-only. Touches neither the working tree nor the index.
#
# Exit 0: zero or more paths listed. ZERO IS A SUCCESS, printed as no output.
# Exit 1: not a git repository, or git unavailable.
#
# WHY PORCELAIN V2. `git status --porcelain=v2` carries the XY code and the
# stage modes in the same record as the path, so one invocation yields path AND
# classification. `git diff --name-only --diff-filter=U` yields only paths and
# would need a second pass each. Porcelain is also the format git documents as
# stable "for scripts" and "regardless of user configuration".
#
# WHY SORT. Git documents porcelain v2's order as UNDEFINED -- "tracked entries
# are printed in an undefined order; parsers should allow for a mixture of the 3
# line types in any order". The requirement that the same conflicted state
# produces the same report on every run is therefore this script's to provide,
# not git's, and sorting is how it does so.
#
# WHAT IS DERIVED. Seven of the nine kinds come from the XY code directly. Git
# publishes no code for a type change or for a binary file, so `type-changed` is
# derived from the stage modes and `binary` from a content test. `binary` wins
# over every other classification, because line-level options are meaningless
# for content that is not text -- that precedence is this feature's rule, not
# something git reports.

set -u

if ! command -v git > /dev/null 2>&1; then
	echo "no-git: git is not on PATH; install git or add it to PATH" >&2
	exit 1
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the repository with the conflict" >&2
	exit 1
fi

# Mode 160000 is a gitlink (submodule); 040000 a tree. Neither is a regular
# blob, so a path whose stages disagree on that is a type change.
is_regular_mode() {
	case "$1" in
		100644 | 100755 | 120000) return 0 ;;
		*) return 1 ;;
	esac
}

classify() {
	# classify XY m1 m2 m3
	_xy=$1
	_m1=$2
	_m2=$3
	_m3=$4

	# A type change is visible in the modes rather than the code: two present
	# stages that disagree on whether the path is a regular blob.
	if [ "$_m2" != 000000 ] && [ "$_m3" != 000000 ]; then
		if is_regular_mode "$_m2" && ! is_regular_mode "$_m3"; then
			printf 'type-changed'
			return 0
		fi
		if ! is_regular_mode "$_m2" && is_regular_mode "$_m3"; then
			printf 'type-changed'
			return 0
		fi
	fi
	if [ "$_m1" != 000000 ] && [ "$_m2" != 000000 ]; then
		if is_regular_mode "$_m1" && ! is_regular_mode "$_m2"; then
			printf 'type-changed'
			return 0
		fi
	fi

	case "$_xy" in
		UU) printf 'both-modified' ;;
		AA) printf 'both-added' ;;
		DD) printf 'both-deleted' ;;
		AU) printf 'added-by-us' ;;
		UA) printf 'added-by-them' ;;
		DU) printf 'deleted-by-us' ;;
		UD) printf 'deleted-by-them' ;;
		*) printf 'both-modified' ;;
	esac
}

stages_field() {
	# stages_field m1 m2 m3
	_out=''
	if [ "$1" != 000000 ]; then _out="${_out}1"; else _out="${_out}-"; fi
	if [ "$2" != 000000 ]; then _out="${_out}2"; else _out="${_out}-"; fi
	if [ "$3" != 000000 ]; then _out="${_out}3"; else _out="${_out}-"; fi
	printf '%s' "$_out"
}

EMPTY_OID=0000000000000000000000000000000000000000

# A path is binary if any present stage's blob contains a NUL byte in its first
# 8000 bytes -- git's own heuristic. Counting bytes with and against `tr -d`
# detects one without needing a grep that can match NUL, which POSIX grep
# cannot portably do.
is_binary() {
	# is_binary h1 h2 h3
	for _h in "$1" "$2" "$3"; do
		[ "$_h" = "$EMPTY_OID" ] && continue
		_all=$(git cat-file blob "$_h" 2> /dev/null | head -c 8000 | wc -c || true)
		_stripped=$(git cat-file blob "$_h" 2> /dev/null | head -c 8000 | tr -d '\000' | wc -c || true)
		[ "$_all" = "$_stripped" ] || return 0
	done
	return 1
}

# Porcelain v2 without `-z`, so records are newline separated and a path with an
# unusual character is quoted per core.quotePath rather than being emitted raw.
# Unmerged records are the ones beginning `u`.
git status --porcelain=v2 -- \
	| while IFS= read -r record; do
		case "$record" in
			u\ *) ;;
			*) continue ;;
		esac

		xy=$(printf '%s' "$record" | cut -d' ' -f2)
		m1=$(printf '%s' "$record" | cut -d' ' -f4)
		m2=$(printf '%s' "$record" | cut -d' ' -f5)
		m3=$(printf '%s' "$record" | cut -d' ' -f6)
		h1=$(printf '%s' "$record" | cut -d' ' -f8)
		h2=$(printf '%s' "$record" | cut -d' ' -f9)
		h3=$(printf '%s' "$record" | cut -d' ' -f10)
		path=$(printf '%s' "$record" | cut -d' ' -f11-)

		kind=$(classify "$xy" "$m1" "$m2" "$m3")
		stages=$(stages_field "$m1" "$m2" "$m3")

		text=text
		if is_binary "$h1" "$h2" "$h3"; then
			text=binary
			kind=binary
		fi

		printf '%s\t%s\t%s\t%s\n' "$path" "$kind" "$stages" "$text"
	done \
	| sort

exit 0
