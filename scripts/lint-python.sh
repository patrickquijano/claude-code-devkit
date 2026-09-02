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

collect '*.py' '*.pyi'

if [ "$MODE" = fix ]; then
	run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" check --fix --
	run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" format --
else
	run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" check --
	run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" format --check --
fi
