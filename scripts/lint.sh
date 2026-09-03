#!/bin/sh
# Aggregate quality check: runs every standard, stops at the first failure.
#
# Usage:
#   scripts/lint.sh          report violations, modify nothing
#   scripts/lint.sh --fix    rewrite files into conformance where possible
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

# Declared here, not derived from a directory listing, so two runs on the same
# tree fail at the same place (FR-007). Cheapest and most universal checks
# first: a whitespace failure should not wait behind a container pull.
#
# `citations` leads because it needs no tool at all, and because a governance
# quotation gone stale should be reported before a container is pulled to check
# whitespace (FR-036).
#
# `scope` used to lead, checking that one central list and five per-check
# mirrors of it still agreed. With one declaration per check there is no second
# copy to disagree with, so the check has nothing to compare and is gone; see
# specs/004-format-hook-scope/contracts/exclusion-declaration.md.
CHECKS='citations editorconfig format markdown yaml shell python'

FIX_ARG=''
if [ "$MODE" = fix ]; then
	FIX_ARG='--fix'
fi

for check in $CHECKS; do
	status=0
	if [ -n "$FIX_ARG" ]; then
		"$SCRIPT_DIR/lint-$check.sh" "$FIX_ARG" || status=$?
	else
		"$SCRIPT_DIR/lint-$check.sh" || status=$?
	fi
	if [ "$status" -ne 0 ]; then
		# Stop here. A combined report at the end is a different requirement,
		# and a partial result that exits zero is indistinguishable from a pass.
		die "$PROG: '$check' failed (exit $status). Later checks did not run." "$status"
	fi
done

say "$PROG: all checks passed"
