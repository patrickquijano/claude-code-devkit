#!/bin/sh
# The citations standard, on its own.
#
#   scripts/lint-citations.sh                    report violations
#   scripts/lint-citations.sh --fix              accepted, but this check rewrites nothing
#   scripts/lint-citations.sh [--fix] -- PATH... narrow the run to the named paths
#
# It enumerates .github/ itself rather than through lib/scope.sh, having no
# configuration file to read exclusions from. That is a different file list, not
# a different contract: check-cli.md exempts only scripts/format-file.sh from the
# common shape, so the path list narrows this check like any other.
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
