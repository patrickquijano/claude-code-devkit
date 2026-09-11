#!/bin/sh
# Compaction audit: did this compaction lose anything normative, and did it
# shorten the file?
#
# A review aid, NOT a lint.sh check. The quality gate stays at seven checks --
# an eighth would create a new content-kind/concern pairing under the
# constitution's Quality Gate Requirements, for a concern that only means
# anything across two versions of one file during one deliberate pass.
# specs/011-narrow-gates-pipeline-fix/research.md decision R3.
#
# Contract: specs/011-narrow-gates-pipeline-fix/contracts/compaction-audit-cli.md
# Read the `verdict` line, never the exit status alone.
#
# Sourced, not executed. POSIX sh only.

CA_THRESHOLD=15

ca_usage() {
	printf '%s: usage: %s <baseline-ref> <path>\n' "$PROG" "$PROG" >&2
	printf '  <baseline-ref>  git ref holding the pre-compaction version\n' >&2
	printf '  <path>          repository-relative path to one document\n' >&2
}

ca_emit() {
	printf '%s\t%s\n' "$1" "$2"
}

# The prose stream: no frontmatter, no fenced blocks, no blank lines. Applied
# identically to both versions so the comparison is like-for-like.
ca_prose_stream() {
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

# Fenced code blocks only. Normative in their entirety, compared byte-for-byte.
ca_code_blocks() {
	awk '
		/^[ \t]*```/ { in_fence = !in_fence; print; next }
		in_fence     { print }
	' "$1"
}

# Normative lines per the R1 rule. Reordering is not loss; deletion is.
ca_normative() {
	grep -E 'MUST|MAY|SHOULD|never|Never|always|Always|only|forbidden|not optional|no exception|zero|Rationale:|because|the reason|which is why|so that|WARNING|defect|regression|silently|breaks|fails|wrong|`|[0-9]|three|ten' "$1" \
		|| true
}

# POSIX bracket classes, never `[ \t]`: BSD sed does not read `\t` as a tab
# inside a bracket expression, so `[ \t]` matches space, backslash or a literal
# `t` -- which silently deleted every `t` from the compared text and made a lost
# line unrecognisable. The selftest's removed-must fixture caught it.
ca_normalize() {
	sed -E \
		-e 's/^[[:blank:]]*([-*+]|[0-9]+\.)[[:blank:]]+//' \
		-e 's/^[[:blank:]]+//' \
		-e 's/[[:blank:]]+$//' \
		-e 's/[[:blank:]]+/ /g' \
		"$1"
}

# A rule's FINGERPRINT: its backticked identifiers, bare numbers and modal
# keywords, lowercased, deduplicated and sorted.
#
# Whole-line comparison was tried first and fails the only compaction it was
# built to police: compaction rewrites lines, so every shortened rule reported as
# deleted -- tooling.md compacted 9% with nothing dropped and the audit called 10
# rules lost, all present in shorter form. A reworded rule keeps its identifiers,
# numbers and modal; a deleted rule takes them away.
#
# WARNING, and it is the known weakness: a rule reworded into something subtly
# WEAKER -- same identifiers, same modal, softer scope -- passes this. The diff
# is what catches that, which is why a compaction pass is reviewed and not merely
# audited.
ca_fingerprint() {
	awk '
		{
			line = $0
			out = ""
			rest = line
			while (match(rest, /`[^`]+`/)) {
				tok = substr(rest, RSTART + 1, RLENGTH - 2)
				out = out " " tolower(tok)
				rest = substr(rest, RSTART + RLENGTH)
			}
			rest = line
			while (match(rest, /[0-9][0-9,]*/)) {
				out = out " #" substr(rest, RSTART, RLENGTH)
				rest = substr(rest, RSTART + RLENGTH)
			}
			low = tolower(line)
			split("must not|must|may|should not|should|never|always|forbidden|no exception|not optional|only|zero", mods, "|")
			for (i in mods) {
				if (index(low, mods[i]) > 0) { out = out " @" mods[i] }
			}
			if (out == "") { next }
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

# compaction_audit_main BASELINE_REF PATH
compaction_audit_main() {
	if [ "$#" -ne 2 ]; then
		ca_usage
		exit 2
	fi

	_ca_ref=$1
	_ca_path=$2

	if [ ! -f "$_ca_path" ]; then
		ca_emit path "$_ca_path"
		ca_emit baseline "$_ca_ref"
		ca_emit verdict unreadable
		exit 3
	fi

	_ca_dir=$(mktemp -d "${TMPDIR:-/tmp}/compaction-audit.XXXXXX")
	trap 'rm -rf "$_ca_dir"' EXIT INT TERM

	if ! git show "$_ca_ref:$_ca_path" > "$_ca_dir/before.md" 2> /dev/null; then
		ca_emit path "$_ca_path"
		ca_emit baseline "$_ca_ref"
		ca_emit verdict unreadable
		exit 3
	fi

	cp "$_ca_path" "$_ca_dir/after.md"

	ca_prose_stream "$_ca_dir/before.md" > "$_ca_dir/before.prose"
	ca_prose_stream "$_ca_dir/after.md" > "$_ca_dir/after.prose"
	ca_code_blocks "$_ca_dir/before.md" > "$_ca_dir/before.code"
	ca_code_blocks "$_ca_dir/after.md" > "$_ca_dir/after.code"

	_ca_lines_before=$(wc -l < "$_ca_dir/before.prose")
	_ca_lines_after=$(wc -l < "$_ca_dir/after.prose")
	_ca_lines_before=$((_ca_lines_before))
	_ca_lines_after=$((_ca_lines_after))

	# Measured in CHARACTERS, not lines: .claude/rules/repository-docs.md forbids
	# hard-wrapping prose, so a document is one line per paragraph however long
	# it runs. Compaction makes those lines shorter, rarely fewer, so a
	# line-count floor scores a halved file at 0% and leaves most files
	# arithmetically exempt before anyone reads them.
	_ca_chars_before=$(wc -c < "$_ca_dir/before.prose")
	_ca_chars_after=$(wc -c < "$_ca_dir/after.prose")
	_ca_chars_before=$((_ca_chars_before))
	_ca_chars_after=$((_ca_chars_after))

	ca_normative "$_ca_dir/before.prose" > "$_ca_dir/before.norm.raw"
	ca_normative "$_ca_dir/after.prose" > "$_ca_dir/after.norm.raw"
	ca_normalize "$_ca_dir/before.norm.raw" | sort -u > "$_ca_dir/before.norm"
	ca_normalize "$_ca_dir/after.norm.raw" | sort -u > "$_ca_dir/after.norm"

	ca_fingerprint "$_ca_dir/before.norm.raw" | sort -u > "$_ca_dir/before.fp"
	ca_fingerprint "$_ca_dir/after.norm.raw" | sort -u > "$_ca_dir/after.fp"

	# The match is SUBSET, not equality: adding a word of emphasis while
	# shortening a rule changes the token set and reported the rule as deleted.
	# Subset still catches a real deletion, whose identifiers, numbers and modal
	# appear nowhere afterwards.
	#
	# `NR == FNR` is NOT usable to tell the two files apart: when the first is
	# empty -- exactly what happens when a compaction removed the last normative
	# line -- NR and FNR are still equal on the first record of the SECOND file,
	# so a baseline rule is mistaken for a survivor and the deletion reports as
	# clean. Compare FILENAME instead.
	awk -v af="$_ca_dir/after.fp" '
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
	' "$_ca_dir/after.fp" "$_ca_dir/before.fp" > "$_ca_dir/lost.fp"

	# Code blocks are NOT fingerprinted: a command whose flags were reworded is
	# a different command, and there is no shorter equivalent.
	ca_normalize "$_ca_dir/before.code" | sort -u > "$_ca_dir/before.code.norm"
	ca_normalize "$_ca_dir/after.code" | sort -u > "$_ca_dir/after.code.norm"
	comm -23 "$_ca_dir/before.code.norm" "$_ca_dir/after.code.norm" > "$_ca_dir/lost.code"

	# Report the losing rule in its original wording, so the output names
	# something a reader can find in the baseline.
	: > "$_ca_dir/lost.prose"
	if [ -s "$_ca_dir/lost.fp" ]; then
		while IFS= read -r _ca_fp; do
			[ -n "$_ca_fp" ] || continue
			ca_fingerprint "$_ca_dir/before.norm.raw" > "$_ca_dir/before.fp.ordered"
			_ca_hit=$(grep -n -x -F "$_ca_fp" "$_ca_dir/before.fp.ordered" | head -1 | cut -d: -f1) || _ca_hit=''
			if [ -n "$_ca_hit" ]; then
				sed -n "${_ca_hit}p" "$_ca_dir/before.norm.raw" >> "$_ca_dir/lost.prose"
			else
				printf '%s\n' "$_ca_fp" >> "$_ca_dir/lost.prose"
			fi
		done < "$_ca_dir/lost.fp"
	fi

	cat "$_ca_dir/lost.prose" "$_ca_dir/lost.code" > "$_ca_dir/lost"

	_ca_norm_before=$(wc -l < "$_ca_dir/before.norm")
	_ca_norm_after=$(wc -l < "$_ca_dir/after.norm")
	_ca_lost=$(wc -l < "$_ca_dir/lost")
	_ca_norm_before=$((_ca_norm_before))
	_ca_norm_after=$((_ca_norm_after))
	_ca_lost=$((_ca_lost))

	if [ "$_ca_chars_before" -eq 0 ]; then
		_ca_reduction=0
	else
		_ca_reduction=$(((_ca_chars_before - _ca_chars_after) * 100 / _ca_chars_before))
	fi

	if [ "$_ca_lost" -gt 0 ]; then
		_ca_verdict=fail-lost
		_ca_status=1
	elif [ "$_ca_reduction" -lt "$CA_THRESHOLD" ]; then
		_ca_verdict=fail-short
		_ca_status=1
	else
		_ca_verdict=pass
		_ca_status=0
	fi

	ca_emit path "$_ca_path"
	ca_emit baseline "$_ca_ref"
	ca_emit lines-before "$_ca_lines_before"
	ca_emit lines-after "$_ca_lines_after"
	ca_emit chars-before "$_ca_chars_before"
	ca_emit chars-after "$_ca_chars_after"
	ca_emit reduction-pct "$_ca_reduction"
	ca_emit normative-before "$_ca_norm_before"
	ca_emit normative-after "$_ca_norm_after"
	ca_emit normative-lost "$_ca_lost"
	ca_emit verdict "$_ca_verdict"

	if [ "$_ca_lost" -gt 0 ]; then
		while IFS= read -r _ca_line; do
			ca_emit lost "$_ca_line"
		done < "$_ca_dir/lost"
	fi

	exit "$_ca_status"
}
