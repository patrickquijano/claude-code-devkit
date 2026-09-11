#!/bin/sh
# The commit-message check, as git reaches it: one argument, the path of a file
# holding a candidate message. Invoked through .husky/commit-msg.
# Contract: specs/008-commit-hooks/contracts/commit-msg-hook.md
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)

# shellcheck source=../lib/commit-msg.sh
. "$SCRIPT_DIR/../lib/commit-msg.sh"

commit_msg_main "$@"
