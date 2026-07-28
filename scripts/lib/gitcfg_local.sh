#!/usr/bin/env bash
#
# Read/write --local git config values for the current repo.

# gitcfg_local_get — read a --local git config value for the current repo.
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

# gitcfg_local_set — idempotently write a --local git config value for the
# current repo. Depends on gitcfg_local_get, devkit_log_info,
# devkit_log_success, and devkit_log_error being sourced first.
# Args: $1 = config key (e.g. "user.name"), $2 = value to set.
# Outputs: a one-line status message — devkit_log_info "<key> already set
#   to <value> (no change)" if the value was already the requested value
#   (no `git config` call is made in that case), or devkit_log_success
#   "<key> set to <value>" once the write succeeds. On write failure,
#   devkit_log_error with the key/value that failed.
# Returns: 0 on success (both changed and unchanged are success), 1 if
#   the underlying `git config` write fails.
gitcfg_local_set() {
  local key="${1}"
  local value="${2}"
  local current
  current="$(gitcfg_local_get "${key}")"
  if [[ "${current}" == "${value}" ]]; then
    devkit_log_info "${key} already set to ${value} (no change)"
    return 0
  fi
  if ! git config --local "${key}" "${value}"; then
    devkit_log_error "Failed to set ${key} to ${value}."
    return 1
  fi
  devkit_log_success "${key} set to ${value}"
}
