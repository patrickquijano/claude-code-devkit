#!/usr/bin/env bash
#
# gitcfg_require_repo — guard clause for scripts that must run inside a
# git repository work tree.
#
# Args: none.
# Outputs: error message to stderr if not inside a git repository.
# Returns: does not return on failure — exits the process with status 1.

gitcfg_require_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Error: not inside a git repository.\n' >&2
    exit 1
  fi
}
