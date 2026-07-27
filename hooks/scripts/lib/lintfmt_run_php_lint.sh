#!/usr/bin/env bash
#
# lintfmt_run_php_lint — syntax-check a PHP file with `php -l`. Depends
# on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_php_lint() {
  local file="${1}"
  if ! lintfmt_command_exists php; then
    lintfmt_log_warn 'php not found on PATH, skipping php -l.'
    return 0
  fi
  lintfmt_run_step 'php -l' php -l "${file}"
}
