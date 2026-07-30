#!/usr/bin/env bash
#
# PHP tooling wrappers: Laravel Pint (format) + `php -l` (syntax check).

# lintfmt_pint_binary — resolve which Laravel Pint binary to use: the
# project-local `vendor/bin/pint` first (the normal Laravel install
# location), falling back to a global `pint` on PATH. Depends on
# lintfmt_command_exists.
# Args: $1 = project directory (the hook's `cwd`).
# Outputs: the resolved binary path to stdout, or empty if none found.
lintfmt_pint_binary() {
  local dir="${1}"
  if [[ -x "${dir}/vendor/bin/pint" ]]; then
    printf '%s\n' "${dir}/vendor/bin/pint"
    return 0
  fi
  if lintfmt_command_exists pint; then
    command -v pint
  fi
}

# lintfmt_run_pint — format a PHP file with Laravel Pint. Depends on
# lintfmt_pint_binary, lintfmt_run_step, lintfmt_log_warn.
# Args: $1 = file path, $2 = project directory (the hook's `cwd`).
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

# lintfmt_run_php_lint — syntax-check a PHP file with `php -l`. Depends
# on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
# Args: $1 = file path.
lintfmt_run_php_lint() {
  local file="${1}"
  if ! lintfmt_command_exists php; then
    lintfmt_log_warn 'php not found on PATH, skipping php -l.'
    return 0
  fi
  lintfmt_run_step 'php -l' php -l "${file}"
}
