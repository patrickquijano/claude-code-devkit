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

collect yaml '*.yml' '*.yaml'

if [ "$MODE" = fix ]; then
	no_automatic_fix yaml
fi

# yamllint publishes no image. The pinned Docker Official python image installs
# the exactly-pinned tool version, then execs it over the file list (constitution
# Principle III, second clause). NATIVE_ARGS is what the native path passes.
NATIVE_ARGS='--strict'
run_files_sh "$LIST" yamllint "$IMAGE_YAML" \
	"pip install --quiet --disable-pip-version-check --root-user-action=ignore 'yamllint==$VERSION_YAMLLINT' >/dev/null && exec yamllint --strict \"\$@\""
