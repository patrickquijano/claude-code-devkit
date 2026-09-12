#!/bin/sh
# The editorconfig standard, on its own.
#
#   scripts/lint-editorconfig.sh                    report violations
#   scripts/lint-editorconfig.sh --fix              accepted, but this check rewrites nothing
#   scripts/lint-editorconfig.sh [--fix] -- PATH... narrow the run to the named paths
#
# Exit statuses are documented in specs/001-quality-gate-plugin/contracts/cli.md
# and are part of the contract.
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

check_main editorconfig "$@"
