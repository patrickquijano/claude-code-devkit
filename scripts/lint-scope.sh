#!/bin/sh
# Scope agreement check (FR-013b).
#
# Usage:
#   scripts/lint-scope.sh          report divergence, modify nothing
#   scripts/lint-scope.sh --fix    nothing to rewrite; reports and exits 0
#
# The other six checks each declare, in their own configuration file, which
# paths they do not examine. .lintignore declares the same thing once for the
# runner. Six declarations of one fact is six chances to disagree, and a
# disagreement is silent: the tool checks more or fewer files than the
# repository intended and reports nothing unusual either way.
#
# So the agreement is verified rather than structural. This check extracts each
# declaration, normalises away the syntax differences, and fails when any of
# them does not match .lintignore exactly -- same paths, no more, no fewer.
#
# ShellCheck is the exception and is reported UNVERIFIABLE, not PASS: it has no
# path-exclusion mechanism at all, so there is nothing to compare. See
# .shellcheckrc and research.md section 13.
#
# This check needs no tool and no container -- it reads five committed files.
# Exit statuses are documented in
# specs/001-quality-gate-plugin/contracts/cli.md and are part of the contract.
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_args "$@"

if [ "$MODE" = fix ]; then
	# Which declaration is wrong is a judgement, not a rewrite: the fix may be
	# to change .lintignore rather than the five that mirror it.
	no_automatic_fix "scope agreement"
fi

cd "$REPO_ROOT"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

# --- Extractors -------------------------------------------------------------
#
# Each writes one path per line, sorted, with the tool's own syntax removed.
# `sort` rather than preserving order: these declare a set, and requiring the
# same order would fail on a difference that changes no behaviour.

# Comments and blank lines out; that is the whole of gitignore-style syntax
# this repository uses. Serves .lintignore and .prettierignore alike.
extract_plain() {
	sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' | sort
}

# JSONC. Anchored on the array's own line, because the file's header comment
# mentions "ignores" too and an unanchored match would find that first.
# Directories carry a trailing /** -- these are globs matched against file
# paths, and a bare directory name matches no file inside it.
extract_markdownlint() {
	sed -n '/^  "ignores": \[$/,/^  \],$/p' .markdownlint-cli2.jsonc \
		| sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}$/\1/p' \
		| sed -e 's|/\*\*$||' \
		| grep -v '^$' | sort
}

# A YAML block scalar: the body is every following line indented by two
# spaces, ending at the first line that is neither indented nor blank.
extract_yamllint() {
	sed -n '/^ignore: |$/,/^[^[:space:]]/p' .yamllint.yml \
		| sed -n 's/^  \(.*\)$/\1/p' \
		| grep -v '^$' | sort
}

extract_prettier() {
	extract_plain .prettierignore
}

extract_ruff() {
	sed -n '/^exclude = \[$/,/^\]$/p' ruff.toml \
		| sed -n 's/^[[:space:]]*"\(.*\)",$/\1/p' \
		| sort
}

# REGEXES, not globs. Undo the anchoring and the escaping so the comparison is
# against paths: leading ^, and a trailing / for directories or $ for files.
#
# Then every backslash is deleted outright. That is safe rather than lazy: the
# only escape these patterns use is an escaped dot, and JSON writes each one as
# two characters, so a single unescaping pass would leave one behind.
extract_editorconfig() {
	sed -n '/"Exclude": \[/,/^[[:space:]]*\]/p' .editorconfig-checker.json \
		| sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}$/\1/p' \
		| sed -e 's|^\^||' -e 's|\$$||' -e 's|/$||' \
		| sed -e 's|[\]||g' \
		| grep -v '^$' | sort
}

# --- Comparison -------------------------------------------------------------

extract_plain .lintignore > "$WORK/expected"

FAILED=0

# compare NAME CONFIG_FILE EXTRACTOR
compare() {
	_name=$1
	_config=$2
	_st=0

	"$3" > "$WORK/actual"
	diff -u "$WORK/expected" "$WORK/actual" > "$WORK/diff" || _st=$?

	if [ "$_st" -eq 0 ]; then
		printf '  %-14s PASS  (%s)\n' "$_name" "$_config"
		return 0
	fi

	FAILED=1
	printf '  %-14s FAIL  (%s)\n' "$_name" "$_config"
	printf '\n'
	# Named so the reader knows which side is which before reading the diff:
	# -/< is what .lintignore declares, +/> is what this configuration does.
	printf '%s: %s does not declare the same paths as .lintignore.\n' \
		"$PROG" "$_config"
	printf '  -  declared in .lintignore, absent from %s\n' "$_config"
	printf '  +  declared in %s, absent from .lintignore\n\n' "$_config"
	sed -e '1,2d' -e "s|^|    |" "$WORK/diff"
	printf '\n'
	return 0
}

say "$PROG (no tool required: comparing six declarations against .lintignore)"

compare editorconfig .editorconfig-checker.json extract_editorconfig
compare format .prettierignore extract_prettier
compare markdown .markdownlint-cli2.jsonc extract_markdownlint
compare yaml .yamllint.yml extract_yamllint
compare python ruff.toml extract_ruff

# Not PASS. There is no mechanism to compare, and calling that agreement would
# hide the one check whose by-hand scope this repository cannot govern.
printf '  %-14s UNVERIFIABLE  (.shellcheckrc has no path-exclusion mechanism)\n' shell

if [ "$FAILED" -ne 0 ]; then
	die "$PROG: scope declarations diverge (see above). Reconcile them, or change .lintignore if it is the one that is wrong." 1
fi

say "$PROG: five declarations agree with .lintignore; shell unverifiable"
