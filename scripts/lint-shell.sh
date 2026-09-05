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

# Git hook files have no extension -- git decides which hook to run from the
# filename alone, so `.husky/commit-msg` cannot be called `commit-msg.sh`. A
# bare '*.sh' therefore skips them silently, which is the worst shape of gap:
# scripts the constitution requires be checked, that nothing checks, with no
# error to notice. The hook LOGIC lives in scripts/hooks/*.sh and is caught by
# the glob; these two paths are the thin dispatchers that exec it.
#
# Do not "tidy" these away. Removing them stops checking the hooks and reports
# success. specs/008-commit-hooks/research.md section 8.
collect shell '*.sh' '.husky/commit-msg' '.husky/pre-push'

if [ "$MODE" = fix ]; then
	no_automatic_fix shell
fi

run_files "$LIST" shellcheck "$IMAGE_SHELL"
