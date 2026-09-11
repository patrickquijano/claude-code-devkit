#!/bin/sh
# Aggregate quality check: runs every standard, stops at the first failure.
#
#   scripts/lint.sh                    report violations, modify nothing
#   scripts/lint.sh --fix              rewrite files into conformance where possible
#   scripts/lint.sh [--fix] -- PATH... narrow the run to the named paths
#
# Exit statuses are documented in specs/001-quality-gate-plugin/contracts/cli.md
# and are part of the contract.
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

lint_main "$@"
