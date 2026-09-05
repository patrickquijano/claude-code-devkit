#!/bin/sh
# Compaction audit: did this compaction lose anything normative, and did it shorten the file?
#
# Review aid, NOT a lint.sh check. The quality gate stays at seven checks -- adding an eighth
# would create a new content-kind/concern pairing under the constitution's Quality Gate
# Requirements, for a concern that only means anything across two versions of one file during
# one deliberate pass. See specs/011-narrow-gates-pipeline-fix/research.md decision R3.
#
# Contract: specs/011-narrow-gates-pipeline-fix/contracts/compaction-audit-cli.md
# Read the `verdict` line, never the exit status alone.

set -eu

PROG=$(basename "$0")
THRESHOLD=15

usage() {
	printf '%s: usage: %s <baseline-ref> <path>\n' "$PROG" "$PROG" >&2
	printf '  <baseline-ref>  git ref holding the pre-compaction version\n' >&2
	printf '  <path>          repository-relative path to one document\n' >&2
}

emit() {
	printf '%s\t%s\n' "$1" "$2"
}

# Reduce a document to its prose stream: drop YAML frontmatter, drop fenced code blocks,
# drop blank lines. Applied identically to both versions so the comparison is like-for-like.
prose_stream() {
	awk '
		NR == 1 && $0 == "---" { in_fm = 1; next }
		in_fm && $0 == "---"   { in_fm = 0; next }
		in_fm                  { next }
		/^[ \t]*```/           { in_fence = !in_fence; next }
		in_fence               { next }
		/^[ \t]*$/             { next }
		{ print }
	' "$1"
}

# Extract fenced code blocks only. Normative in their entirety, compared byte-for-byte.
code_blocks() {
	awk '
		/^[ \t]*```/ { in_fence = !in_fence; print; next }
		in_fence     { print }
	' "$1"
}

# Normative lines per the R1 rule, normalized so re-indentation and list-marker changes
# are not reported as loss. Reordering is not loss; deletion is.
normative() {
	grep -E 'MUST|MAY|SHOULD|never|Never|always|Always|only|forbidden|not optional|no exception|zero|Rationale:|because|the reason|which is why|so that|WARNING|defect|regression|silently|breaks|fails|wrong|`|[0-9]|three|ten' "$1" \
		|| true
}

# POSIX bracket classes, never `[ \t]`: BSD sed does not read `\t` as a tab inside a bracket
# expression, so `[ \t]` matches space, backslash, or the literal letter `t` -- which silently
# deletes every `t` from the compared text and made a lost line unrecognisable. The selftest's
# removed-must fixture is what caught it.
normalize() {
	sed -E \
		-e 's/^[[:blank:]]*([-*+]|[0-9]+\.)[[:blank:]]+//' \
		-e 's/^[[:blank:]]+//' \
		-e 's/[[:blank:]]+$//' \
		-e 's/[[:blank:]]+/ /g' \
		"$1"
}

# A rule's FINGERPRINT: the backticked identifiers, bare numbers and modal keywords it carries,
# lowercased, deduplicated and sorted. This is what survival is measured on, and the reason is
# a defect measured during implementation.
#
# The loss check used to compare whole normalized lines. Compaction rewrites lines -- that is
# what compacting prose IS -- so every shortened rule reported as deleted: tooling.md compacted
# 9% with nothing dropped and the audit called 10 rules lost, all of them present in shorter
# form. A check that cannot distinguish "reworded" from "removed" fails the only compaction it
# was built to police.
#
# A reworded rule keeps its identifiers, its numbers and its modal; a deleted rule takes them
# away. Matching on that set is still fully mechanical and reproducible, so R1's rejection of
# semantic comparison stands.
#
# WARNING, and it is the known weakness: a rule reworded into something subtly WEAKER -- same
# identifiers, same modal, softer scope -- passes this check. The diff is what catches that,
# which is why a compaction pass is reviewed and not merely audited.
fingerprint() {
	awk '
		{
			line = $0
			out = ""
			n = split(line, chars, "")
			# backticked identifiers
			rest = line
			while (match(rest, /`[^`]+`/)) {
				tok = substr(rest, RSTART + 1, RLENGTH - 2)
				out = out " " tolower(tok)
				rest = substr(rest, RSTART + RLENGTH)
			}
			# bare numbers
			rest = line
			while (match(rest, /[0-9][0-9,]*/)) {
				out = out " #" substr(rest, RSTART, RLENGTH)
				rest = substr(rest, RSTART + RLENGTH)
			}
			# modal and absolute keywords, case-folded
			low = tolower(line)
			split("must not|must|may|should not|should|never|always|forbidden|no exception|not optional|only|zero", mods, "|")
			for (i in mods) {
				if (index(low, mods[i]) > 0) { out = out " @" mods[i] }
			}
			if (out == "") { next }
			# sort the tokens so word order does not matter
			m = split(out, toks, " ")
			for (a = 1; a <= m; a++) {
				for (b = a + 1; b <= m; b++) {
					if (toks[b] != "" && toks[a] > toks[b]) { t = toks[a]; toks[a] = toks[b]; toks[b] = t }
				}
			}
			key = ""
			prev = ""
			for (a = 1; a <= m; a++) {
				if (toks[a] != "" && toks[a] != prev) { key = key toks[a] " "; prev = toks[a] }
			}
			print key
		}
	' "$1"
}

if [ "$#" -ne 2 ]; then
	usage
	exit 2
fi

BASELINE_REF=$1
DOC_PATH=$2

if [ ! -f "$DOC_PATH" ]; then
	emit path "$DOC_PATH"
	emit baseline "$BASELINE_REF"
	emit verdict unreadable
	exit 3
fi

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/compaction-audit.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

if ! git show "$BASELINE_REF:$DOC_PATH" > "$WORK_DIR/before.md" 2> /dev/null; then
	emit path "$DOC_PATH"
	emit baseline "$BASELINE_REF"
	emit verdict unreadable
	exit 3
fi

cp "$DOC_PATH" "$WORK_DIR/after.md"

prose_stream "$WORK_DIR/before.md" > "$WORK_DIR/before.prose"
prose_stream "$WORK_DIR/after.md" > "$WORK_DIR/after.prose"
code_blocks "$WORK_DIR/before.md" > "$WORK_DIR/before.code"
code_blocks "$WORK_DIR/after.md" > "$WORK_DIR/after.code"

LINES_BEFORE=$(wc -l < "$WORK_DIR/before.prose")
LINES_AFTER=$(wc -l < "$WORK_DIR/after.prose")
LINES_BEFORE=$((LINES_BEFORE))
LINES_AFTER=$((LINES_AFTER))

# The reduction is measured in CHARACTERS, not lines, and the reason is this repository's own
# format: `.claude/rules/repository-docs.md` forbids hard-wrapping prose, so a document is one
# line per paragraph however long it runs. Compaction makes those lines SHORTER; it rarely makes
# them fewer. A line-count floor therefore scores a file whose every paragraph was halved at 0%,
# and -- because R1's normative pattern is deliberately broad -- left most files arithmetically
# exempt before anyone read them, which made the floor decorative. Measured at implementation:
# base-branch.md had 2 non-normative lines out of 38 and could never have reached 15%.
CHARS_BEFORE=$(wc -c < "$WORK_DIR/before.prose")
CHARS_AFTER=$(wc -c < "$WORK_DIR/after.prose")
CHARS_BEFORE=$((CHARS_BEFORE))
CHARS_AFTER=$((CHARS_AFTER))

normative "$WORK_DIR/before.prose" > "$WORK_DIR/before.norm.raw"
normative "$WORK_DIR/after.prose" > "$WORK_DIR/after.norm.raw"
normalize "$WORK_DIR/before.norm.raw" | sort -u > "$WORK_DIR/before.norm"
normalize "$WORK_DIR/after.norm.raw" | sort -u > "$WORK_DIR/after.norm"

# Prose rules are matched by fingerprint, so a rule shortened in place still counts as present.
#
# The match is SUBSET, not equality: a baseline rule survives when every token it carried is
# still present in some line of the new version. Equality was tried first and rejected during
# implementation -- adding a word of emphasis to a rule while shortening it changes the token
# set and reported the rule as deleted, which is the same false positive in a smaller costume.
# Subset still catches a real deletion, because a removed rule's identifiers, numbers and modal
# appear nowhere afterwards.
fingerprint "$WORK_DIR/before.norm.raw" | sort -u > "$WORK_DIR/before.fp"
fingerprint "$WORK_DIR/after.norm.raw" | sort -u > "$WORK_DIR/after.fp"

# `NR == FNR` is NOT usable to tell the two files apart here: when the first file is empty --
# which is exactly what happens when a compaction removed the last normative line -- NR and FNR
# are still equal on the first record of the SECOND file, so a baseline rule is mistaken for a
# survivor and the deletion reports as clean. The selftest's removed-must fixture caught it.
# Compare FILENAME instead.
awk -v af="$WORK_DIR/after.fp" '
	FILENAME == af { after[++n] = $0; next }
	{
		want = split($0, w, " ")
		for (i = 1; i <= n; i++) {
			ok = 1
			for (j = 1; j <= want; j++) {
				if (w[j] == "") { continue }
				if (index(" " after[i] " ", " " w[j] " ") == 0) { ok = 0; break }
			}
			if (ok) { next }
		}
		print
	}
' "$WORK_DIR/after.fp" "$WORK_DIR/before.fp" > "$WORK_DIR/lost.fp"

# Code blocks are NOT fingerprinted. They are compared byte-for-byte, because a command whose
# flags were reworded is a different command -- there is no such thing as a shorter equivalent.
normalize "$WORK_DIR/before.code" | sort -u > "$WORK_DIR/before.code.norm"
normalize "$WORK_DIR/after.code" | sort -u > "$WORK_DIR/after.code.norm"
comm -23 "$WORK_DIR/before.code.norm" "$WORK_DIR/after.code.norm" > "$WORK_DIR/lost.code"

# Report the losing rule in its original wording, not as its fingerprint, so the output names
# something a reader can find in the baseline.
: > "$WORK_DIR/lost.prose"
if [ -s "$WORK_DIR/lost.fp" ]; then
	while IFS= read -r _fp; do
		[ -n "$_fp" ] || continue
		fingerprint "$WORK_DIR/before.norm.raw" > "$WORK_DIR/before.fp.ordered"
		_hit=$(grep -n -x -F "$_fp" "$WORK_DIR/before.fp.ordered" | head -1 | cut -d: -f1) || _hit=''
		if [ -n "$_hit" ]; then
			sed -n "${_hit}p" "$WORK_DIR/before.norm.raw" >> "$WORK_DIR/lost.prose"
		else
			printf '%s\n' "$_fp" >> "$WORK_DIR/lost.prose"
		fi
	done < "$WORK_DIR/lost.fp"
fi

cat "$WORK_DIR/lost.prose" "$WORK_DIR/lost.code" > "$WORK_DIR/lost"

NORM_BEFORE=$(wc -l < "$WORK_DIR/before.norm")
NORM_AFTER=$(wc -l < "$WORK_DIR/after.norm")
LOST=$(wc -l < "$WORK_DIR/lost")
NORM_BEFORE=$((NORM_BEFORE))
NORM_AFTER=$((NORM_AFTER))
LOST=$((LOST))

if [ "$CHARS_BEFORE" -eq 0 ]; then
	REDUCTION=0
else
	REDUCTION=$(((CHARS_BEFORE - CHARS_AFTER) * 100 / CHARS_BEFORE))
fi

if [ "$LOST" -gt 0 ]; then
	VERDICT=fail-lost
	STATUS=1
elif [ "$REDUCTION" -lt "$THRESHOLD" ]; then
	VERDICT=fail-short
	STATUS=1
else
	VERDICT=pass
	STATUS=0
fi

emit path "$DOC_PATH"
emit baseline "$BASELINE_REF"
emit lines-before "$LINES_BEFORE"
emit lines-after "$LINES_AFTER"
emit chars-before "$CHARS_BEFORE"
emit chars-after "$CHARS_AFTER"
emit reduction-pct "$REDUCTION"
emit normative-before "$NORM_BEFORE"
emit normative-after "$NORM_AFTER"
emit normative-lost "$LOST"
emit verdict "$VERDICT"

if [ "$LOST" -gt 0 ]; then
	while IFS= read -r line; do
		emit lost "$line"
	done < "$WORK_DIR/lost"
fi

exit "$STATUS"
