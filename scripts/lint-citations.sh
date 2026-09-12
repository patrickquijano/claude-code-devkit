#!/bin/sh
# The citations standard, on its own.
#
#   scripts/lint-citations.sh                    report violations
#   scripts/lint-citations.sh --fix              accepted, but this check rewrites nothing
#   scripts/lint-citations.sh [--fix] -- PATH... accepted, but this check ignores the paths
#
# It examines one fixed directory rather than a filtered file list, so a path
# list narrows nothing here -- specs/004-format-hook-scope/contracts/check-cli.md
# exempts it from the scope machinery.
#
# Exit statuses are documented in specs/001-quality-gate-plugin/contracts/cli.md
# and are part of the contract.
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"

check_main citations "$@"
