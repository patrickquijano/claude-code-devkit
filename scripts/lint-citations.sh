#!/bin/sh
# Governance-citation freshness check (FR-036).
#
# Usage:
#   scripts/lint-citations.sh          report stale quotations, modify nothing
#   scripts/lint-citations.sh --fix    nothing to rewrite; reports and exits 0
#
# The change-proposal templates quote the constitution so an author and a
# reviewer see the actual obligation rather than a summary of it. A quotation is
# a copy, and a copy goes stale the moment the original is amended -- silently,
# because a template that once matched still reads as authoritative.
#
# So the correspondence is verified rather than trusted. Every
#
#     <!-- cite: <path> -->
#     > quoted text
#
# in .github/ is checked: the blockquote is joined to one line and must appear
# in the file the marker names. A mismatch exits 1 naming the template, the
# cited path and the quotation that was not found.
#
# Comparison is whitespace-normalised on BOTH sides, which is the whole reason
# this is a script and not a grep. The cited documents hard-wrap their prose, so
# one quoted sentence spans two lines there; `grep -F` on the joined quotation
# returns 0 matches for a citation that is perfectly accurate. See
# specs/001-quality-gate-plugin/research.md section 23.
#
# This check needs no tool and no container -- it reads committed files. It also
# declares no skipped paths, because it has none to declare: it examines one
# fixed directory rather than a filtered file list, so it takes no part in the
# scope agreement lint-scope.sh verifies (FR-013a, FR-013b).
#
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
	# Which of the two texts is wrong is a judgement. The constitution may have
	# been amended deliberately, in which case the template follows it; or the
	# quotation may have been mistyped, in which case the template is wrong.
	# A rewrite would have to guess, and guessing wrong rewrites governance.
	no_automatic_fix "stale governance quotations"
fi

cd "$REPO_ROOT"

# The directory the hosting surface reads templates from. Fixed, not a glob:
# these citations exist to carry governance into the proposal surface, and
# nothing else in the repository quotes the constitution for that purpose.
TEMPLATE_DIR=.github

if [ ! -d "$TEMPLATE_DIR" ]; then
	say "$PROG: no $TEMPLATE_DIR directory; no citations to check"
	exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM

# --- Normalisation ----------------------------------------------------------
#
# Every newline and run of whitespace becomes one space, and the ends are
# trimmed. Applied identically to the quotation and to the cited document, so
# the comparison is about words and not about where either happens to wrap.

normalise() {
	tr '\n\t' '  ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# --- Extraction -------------------------------------------------------------
#
# Emits one TAB-separated record per marker: LINE, CITED PATH, QUOTATION.
#
# A marker may be followed by blank lines before its blockquote; anything else
# between them ends the record with an empty quotation, which is reported as a
# malformed marker rather than passed over. A marker is never skipped.

extract_citations() {
	awk '
		/^<!-- cite: .* -->$/ {
			if (pending) { print markline "\t" path "\t" quote }
			path = $0
			sub(/^<!-- cite: /, "", path)
			sub(/ -->$/, "", path)
			markline = NR
			quote = ""
			pending = 1
			next
		}
		pending && /^>/ {
			line = $0
			sub(/^>[ ]?/, "", line)
			quote = (quote == "" ? line : quote " " line)
			next
		}
		pending && quote == "" && /^[[:space:]]*$/ { next }
		pending {
			print markline "\t" path "\t" quote
			pending = 0
			next
		}
		END { if (pending) { print markline "\t" path "\t" quote } }
	' "$1"
}

# --- Comparison -------------------------------------------------------------

FAILED=0
MARKERS=0
FILES=0

say "$PROG (no tool required: comparing quotations in $TEMPLATE_DIR against the documents they cite)"

# Sorted so the report reads the same on every machine and in every filesystem.
find "$TEMPLATE_DIR" -type f -name '*.md' | sort > "$WORK/templates"

if [ ! -s "$WORK/templates" ]; then
	say "$PROG: no Markdown in $TEMPLATE_DIR; no citations to check"
	exit 0
fi

while IFS= read -r template; do
	FILES=$((FILES + 1))
	extract_citations "$template" > "$WORK/citations"

	while IFS="$(printf '\t')" read -r lineno cited quote; do
		MARKERS=$((MARKERS + 1))

		if [ -z "$quote" ]; then
			FAILED=1
			printf '%s:%s: cite marker for %s has no quotation beneath it.\n' \
				"$template" "$lineno" "$cited"
			printf '  A marker must be followed by a blockquote, so there is something to verify.\n\n'
			continue
		fi

		# A missing cited file is a mismatch, not a skip: a citation whose
		# source has been moved or deleted is exactly as stale as one whose
		# wording has changed, and skipping it would report success.
		if [ ! -f "$cited" ]; then
			FAILED=1
			printf '%s:%s: cited file does not exist: %s\n' \
				"$template" "$lineno" "$cited"
			printf '  quotation: %s\n\n' "$quote"
			continue
		fi

		printf '%s' "$quote" | normalise > "$WORK/needle"
		normalise < "$cited" > "$WORK/haystack"

		_needle=$(cat "$WORK/needle")
		_haystack=$(cat "$WORK/haystack")

		case "$_haystack" in
			*"$_needle"*)
				printf '  %s:%s  MATCH  (%s)\n' "$template" "$lineno" "$cited"
				;;
			*)
				FAILED=1
				printf '  %s:%s  STALE  (%s)\n\n' "$template" "$lineno" "$cited"
				printf '%s:%s: this quotation does not appear in %s.\n' \
					"$template" "$lineno" "$cited"
				printf '  quoted:  %s\n' "$_needle"
				printf '  Either the document was amended and the template must follow it,\n'
				printf '  or the quotation is wrong. Whitespace and line wrapping are already\n'
				printf '  normalised on both sides, so the difference is in the words.\n\n'
				;;
		esac
	done < "$WORK/citations"
done < "$WORK/templates"

if [ "$MARKERS" -eq 0 ]; then
	say "$PROG: $FILES file(s) in $TEMPLATE_DIR, 0 cite markers found"
	exit 0
fi

if [ "$FAILED" -ne 0 ]; then
	die "$PROG: one or more governance quotations no longer match the document they cite (see above)." 1
fi

say "$PROG: $MARKERS quotation(s) across $FILES file(s) match the documents they cite"
