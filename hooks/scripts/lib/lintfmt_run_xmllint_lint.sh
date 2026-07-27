#!/usr/bin/env bash
#
# lintfmt_run_xmllint_lint — validate an XML file with `xmllint --noout`.
# Depends on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_xmllint_lint() {
  local file="${1}"
  if ! lintfmt_command_exists xmllint; then
    lintfmt_log_warn 'xmllint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'xmllint --noout' xmllint --noout "${file}"
}
