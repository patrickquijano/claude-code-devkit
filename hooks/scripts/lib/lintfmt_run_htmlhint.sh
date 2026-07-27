#!/usr/bin/env bash
#
# lintfmt_run_htmlhint — lint an HTML file with htmlhint via npx.
# Depends on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_htmlhint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping htmlhint.'
    return 0
  fi
  lintfmt_run_step 'htmlhint' npx htmlhint "${file}"
}
