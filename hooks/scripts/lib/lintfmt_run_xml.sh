#!/usr/bin/env bash
#
# XML wrappers: xmllint format + validate. Depend on
# lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.

# lintfmt_run_xmllint_format — reformat an XML file in place with
# `xmllint --format`.
# Args: $1 = file path.
lintfmt_run_xmllint_format() {
  local file="${1}"
  if ! lintfmt_command_exists xmllint; then
    lintfmt_log_warn 'xmllint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'xmllint --format' xmllint --format --output "${file}" "${file}"
}

# lintfmt_run_xmllint_lint — validate an XML file with `xmllint --noout`.
# Args: $1 = file path.
lintfmt_run_xmllint_lint() {
  local file="${1}"
  if ! lintfmt_command_exists xmllint; then
    lintfmt_log_warn 'xmllint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'xmllint --noout' xmllint --noout "${file}"
}
