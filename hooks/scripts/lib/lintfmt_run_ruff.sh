#!/usr/bin/env bash
#
# lintfmt_run_ruff — format then lint+fix a Python file with ruff.
# Depends on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped; otherwise the worse of the two steps' exit
#   statuses (both run even if the first fails).

lintfmt_run_ruff() {
  local file="${1}"
  if ! lintfmt_command_exists ruff; then
    lintfmt_log_warn 'ruff not found on PATH, skipping.'
    return 0
  fi
  local status=0
  lintfmt_run_step 'ruff format' ruff format "${file}" || status="${?}"
  lintfmt_run_step 'ruff check --fix' ruff check --fix "${file}" || status="${?}"
  return "${status}"
}
