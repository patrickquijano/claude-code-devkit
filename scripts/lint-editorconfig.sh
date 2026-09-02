#!/bin/sh
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/images.sh
. "$SCRIPT_DIR/lib/images.sh"
# shellcheck source=lib/scope.sh
. "$SCRIPT_DIR/lib/scope.sh"

parse_args "$@"
init_runner

# Every in-scope file: whitespace and line endings are not file-type specific.
collect '*'

if [ "$MODE" = fix ]; then
	no_automatic_fix editorconfig
fi

# This image sets no ENTRYPOINT -- its binary is the Cmd -- so the binary has to
# be named or docker execs the first file as a program.
CONTAINER_CMD='editorconfig-checker'

run_files "$LIST" editorconfig-checker "$IMAGE_EDITORCONFIG"
