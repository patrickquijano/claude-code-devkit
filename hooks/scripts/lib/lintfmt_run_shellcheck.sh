#!/usr/bin/env bash
#
# lintfmt_run_shellcheck — lint a shell script with shellcheck. Depends
# on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_shellcheck() {
  local file="${1}"
  if ! lintfmt_command_exists shellcheck; then
    lintfmt_log_warn 'shellcheck not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'shellcheck' shellcheck "${file}"
}
