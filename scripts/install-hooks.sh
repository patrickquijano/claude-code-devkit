#!/bin/sh
# Activates the commit-message and signature checks for this working copy.
#
#   sh scripts/install-hooks.sh            activate, then report
#   sh scripts/install-hooks.sh --status   report only; write nothing
#
# Contract: specs/008-commit-hooks/contracts/install-hooks-cli.md
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=lib/hooks-install.sh
. "$SCRIPT_DIR/lib/hooks-install.sh"

install_hooks_main "$@"
