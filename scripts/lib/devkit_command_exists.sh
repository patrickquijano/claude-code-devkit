#!/usr/bin/env bash
#
# devkit_command_exists — validator: check whether a command is available
# on PATH. Repo-wide (not `gitcfg_`-namespaced) since this isn't specific
# to any one script in scripts/lib/.
#
# Args: $1 = command name.
# Outputs: none.
# Returns: 0 if the command is found, 1 otherwise.

devkit_command_exists() {
  local name="${1}"
  command -v "${name}" >/dev/null 2>&1
}
