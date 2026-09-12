#!/bin/sh
# Compaction audit: did this compaction lose anything normative, and did it
# shorten the file? A review aid, not a lint.sh check.
#
#   sh scripts/compaction-audit.sh <baseline-ref> <path>
#
# Contract: specs/011-narrow-gates-pipeline-fix/contracts/compaction-audit-cli.md
# Read the `verdict` line, never the exit status alone.
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=lib/compaction.sh
. "$SCRIPT_DIR/lib/compaction.sh"

compaction_audit_main "$@"
