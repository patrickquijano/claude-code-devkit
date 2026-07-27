#!/usr/bin/env bash
#
# gitcfg_local_get — read a --local git config value for the current repo.
#
# Args: $1 = config key (e.g. "user.name").
# Outputs: the value on stdout, or an empty string if the key is unset.
# Returns: always 0 — an unset key is not treated as an error.

gitcfg_local_get() {
  local key="${1}"
  local value=""
  if value="$(git config --local --get "${key}" 2>/dev/null)"; then
    printf '%s' "${value}"
  else
    printf ''
  fi
}
