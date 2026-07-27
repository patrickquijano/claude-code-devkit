#!/usr/bin/env bash
#
# lintfmt_run_xmllint_format — reformat an XML file in place with
# `xmllint --format`. Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_xmllint_format() {
  local file="${1}"
  if ! lintfmt_command_exists xmllint; then
    lintfmt_log_warn 'xmllint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'xmllint --format' xmllint --format --output "${file}" "${file}"
}
