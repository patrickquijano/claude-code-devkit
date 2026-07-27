#!/usr/bin/env bash
#
# lintfmt_run_yamllint — lint a YAML file with yamllint (lint-only, no
# autofix tool exists). Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_yamllint() {
  local file="${1}"
  if ! lintfmt_command_exists yamllint; then
    lintfmt_log_warn 'yamllint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'yamllint' yamllint "${file}"
}
