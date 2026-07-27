#!/usr/bin/env bash
#
# gitcfg_require_repo — guard clause for scripts that must run inside a
# git repository work tree. Depends on devkit_log_error
# (scripts/lib/devkit_log_error.sh) being sourced first.
#
# Args: none.
# Outputs: error message via devkit_log_error if not inside a git
#   repository.
# Returns: does not return on failure — exits the process with status 1.

gitcfg_require_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    devkit_log_error 'Not inside a git repository.'
    exit 1
  fi
}
