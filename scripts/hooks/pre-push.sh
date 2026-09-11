#!/bin/sh
# The outgoing-signature check, as git reaches it: the remote name and URL as
# arguments, ref-update lines on stdin. Invoked through .husky/pre-push.
# Contract: specs/008-commit-hooks/contracts/pre-push-hook.md
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=../lib/push-check.sh
. "$SCRIPT_DIR/../lib/push-check.sh"

push_check_main "$@"
