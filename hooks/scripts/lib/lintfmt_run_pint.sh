#!/usr/bin/env bash
#
# lintfmt_run_pint — format a PHP file with Laravel Pint. Depends on
# lintfmt_pint_binary, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path, $2 = project directory (the hook's `cwd`).
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_pint() {
  local file="${1}"
  local dir="${2}"
  local pint_bin
  pint_bin="$(lintfmt_pint_binary "${dir}")"
  if [[ -z "${pint_bin}" ]]; then
    lintfmt_log_warn 'pint not found (no vendor/bin/pint or global pint), skipping.'
    return 0
  fi
  lintfmt_run_step 'pint' "${pint_bin}" "${file}"
}
