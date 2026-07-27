#!/usr/bin/env bash
#
# gitcfg_local_set — idempotently write a --local git config value for the
# current repo. Depends on gitcfg_local_get (scripts/lib/gitcfg_local_get.sh)
# being sourced first.
#
# Args: $1 = config key (e.g. "user.name"), $2 = value to set.
# Outputs: a one-line status message on stdout — "<key> set to <value>" if
#   the value changed, or "<key> already set to <value> (no change)" if it
#   was already the requested value (no `git config` call is made in that
#   case).
# Returns: 0 on success (both changed and unchanged are success).

gitcfg_local_set() {
  local key="${1}"
  local value="${2}"
  local current
  current="$(gitcfg_local_get "${key}")"
  if [[ "${current}" == "${value}" ]]; then
    printf '%s already set to %s (no change)\n' "${key}" "${value}"
    return 0
  fi
  git config --local "${key}" "${value}"
  printf '%s set to %s\n' "${key}" "${value}"
}
