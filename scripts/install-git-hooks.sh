#!/usr/bin/env bash
#
# Idempotently point this repo's --local core.hooksPath at .githooks/, so
# the pre-commit (format + lint) and commit-msg (Conventional Commits)
# hooks in that directory actually run. See .githooks/README.md for what
# each hook does.
#
# Usage:
#   ./scripts/install-git-hooks.sh     (run from the repo root, or any
#                                        subdirectory of a git work tree)
#
# Idempotent: re-running when core.hooksPath is already .githooks is a
# no-op — reuses gitcfg_local_set's own idempotent-write behavior.
#
# All logic lives in scripts/lib/devkit_*.sh and scripts/lib/gitcfg_*.sh
# — see scripts/README.md for the full function reference. Sourcing this
# file instead of executing it skips the main run and just defines the
# functions.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_dir="${script_dir}/lib"

# shellcheck source=lib/devkit_log_info.sh disable=SC1091
source "${lib_dir}/devkit_log_info.sh"
# shellcheck source=lib/devkit_log_success.sh disable=SC1091
source "${lib_dir}/devkit_log_success.sh"
# shellcheck source=lib/devkit_log_error.sh disable=SC1091
source "${lib_dir}/devkit_log_error.sh"
# shellcheck source=lib/gitcfg_require_repo.sh disable=SC1091
source "${lib_dir}/gitcfg_require_repo.sh"
# shellcheck source=lib/gitcfg_local_get.sh disable=SC1091
source "${lib_dir}/gitcfg_local_get.sh"
# shellcheck source=lib/gitcfg_local_set.sh disable=SC1091
source "${lib_dir}/gitcfg_local_set.sh"

main() {
  gitcfg_require_repo
  devkit_log_info 'Installing git hooks.'
  gitcfg_local_set core.hooksPath '.githooks'
  devkit_log_success 'Git hooks installed: pre-commit, commit-msg.'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
