#!/bin/sh
# Format one file that Claude Code just edited. A PostToolUse hook entry point,
# registered in .claude/settings.json. No arguments; one JSON object on stdin.
# Contract: specs/004-format-hook-scope/contracts/format-file-cli.md
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# -P, so the containment test in format_hook_main compares physical paths on
# both sides.
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)

# shellcheck source=lib/checks.sh
. "$SCRIPT_DIR/lib/checks.sh"
# shellcheck source=lib/format-hook.sh
. "$SCRIPT_DIR/lib/format-hook.sh"

format_hook_main "$PROG" "$REPO_ROOT"
