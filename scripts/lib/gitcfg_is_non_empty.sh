#!/usr/bin/env bash
#
# gitcfg_is_non_empty — validator: value must be a non-empty string.
#
# Args: $1 = value to check.
# Outputs: none.
# Returns: 0 if non-empty, 1 otherwise.

gitcfg_is_non_empty() {
  local value="${1}"
  [[ -n "${value}" ]]
}
