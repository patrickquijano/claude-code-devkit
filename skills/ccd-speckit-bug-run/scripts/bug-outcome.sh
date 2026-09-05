#!/bin/sh
# Report which of a bug directory's three reports exist, and what outcome each one records.
#
# This is the determinism point for the run's closing report. The alternative -- having the
# model read the Markdown and remember what it said -- is exactly the drift this script exists
# to prevent, and it is the one thing in the workflow that must not vary between runs.
#
# WHAT IT DEPENDS ON, stated plainly because it is a real dependency and not a safe one: the
# bold field labels the bug extension's own output templates emit. Those are Markdown, not a
# published schema, and nothing upstream commits to keeping them. See
# specs/009-bug-triage-run/research.md gap G3.
#
# So the failure mode is chosen deliberately: an absent label, an unparseable line, and a value
# outside its vocabulary all yield `unknown`, and the caller STOPS on `unknown` for a report
# that exists. The script never picks the nearest legal value and never infers one from
# surrounding prose. A loud stop beats a quiet wrong branch that edits source code.
#
# Output is tab-separated key/value lines, matching bug-preflight.sh.
# Contract: specs/009-bug-triage-run/contracts/bug-outcome-cli.md
#
# EXIT STATUS IS NOT THE OUTCOME. A run whose assessment is `invalid` exits 0; so does one whose
# reports are all unreadable. Read the lines.

set -eu

if [ "$#" -ne 1 ]; then
	printf 'usage: %s <bug-dir>\n' "$0" >&2
	exit 1
fi

bug_dir=$1

if [ ! -d "$bug_dir" ]; then
	printf 'error: %s is not a readable directory\n' "$bug_dir" >&2
	exit 1
fi

# Match the FIRST line carrying the label, and take everything after its colon.
#
# The pattern is deliberately loose about what precedes the label. The templates emit these as
# list items -- `   - **Verdict**: valid` -- so anchoring at the start of the line would match
# nothing and report `unknown` for every well-formed report. It is anchored to the label itself
# instead, and `q` stops at the first hit so that prose later in the report quoting the field
# cannot override the declared value.
extract() {
	_file=$1
	_label=$2
	if [ ! -f "$_file" ]; then
		printf ''
		return 0
	fi
	sed -n "/\\*\\*${_label}\\*\\*:/{s/.*\\*\\*${_label}\\*\\*:[[:space:]]*//;p;q;}" "$_file"
}

# Strip Markdown emphasis, code spans, trailing punctuation and surrounding whitespace, then
# lowercase. What remains is compared against a closed vocabulary; anything else is `unknown`.
normalise() {
	printf '%s' "$1" \
		| sed 's/[`*_]//g; s/[[:space:]]*$//; s/^[[:space:]]*//; s/[.;,]*$//' \
		| tr '[:upper:]' '[:lower:]'
}

assessment_file="$bug_dir/assessment.md"
fix_file="$bug_dir/fix.md"
test_file="$bug_dir/test.md"

file_state() {
	if [ -f "$1" ]; then
		printf 'present'
	else
		printf 'absent'
	fi
}

raw_verdict=$(extract "$assessment_file" 'Verdict')
raw_severity=$(extract "$assessment_file" 'Severity')
raw_status=$(extract "$fix_file" 'Status')
raw_result=$(extract "$test_file" 'Result')

verdict=$(normalise "$raw_verdict")
severity=$(normalise "$raw_severity")
status=$(normalise "$raw_status")
result=$(normalise "$raw_result")

# Closed vocabularies. `valid` is a substring of `invalid`, so these are exact matches on the
# whole value and never a prefix or substring test.
case "$verdict" in
	'valid' | 'likely valid, needs reproduction' | 'invalid') ;;
	*) verdict=unknown ;;
esac

case "$severity" in
	'critical' | 'high' | 'medium' | 'low') ;;
	*) severity=unknown ;;
esac

case "$status" in
	'applied' | 'partial' | 'not-applied') ;;
	*) status=unknown ;;
esac

case "$result" in
	'verified' | 'partial' | 'failed') ;;
	*) result=unknown ;;
esac

# Assigned on their own lines rather than substituted inside printf: a command substitution in
# an argument masks its exit status, which Principle II forbids and shellcheck flags as SC2312.
assessment_state=$(file_state "$assessment_file")
fix_state=$(file_state "$fix_file")
test_state=$(file_state "$test_file")

printf 'bug-dir\t%s\n' "$bug_dir"
printf 'assessment\t%s\n' "$assessment_state"
printf 'fix\t%s\n' "$fix_state"
printf 'test\t%s\n' "$test_state"
printf 'verdict\t%s\n' "$verdict"
printf 'severity\t%s\n' "$severity"
printf 'status\t%s\n' "$status"
printf 'result\t%s\n' "$result"
