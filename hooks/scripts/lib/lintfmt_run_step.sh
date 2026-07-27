#!/usr/bin/env bash
#
# lintfmt_run_step — run one command as a labeled, logged step. Depends
# on lintfmt_log_info and lintfmt_log_error being sourced first.
#
# Runs the command inside an `if`, so a failing command does not trip
# `set -e` in the caller — the caller gets the exit status back instead.
#
# Args: $1 = label shown in the log lines, $2.. = command and its
#   arguments to run.
# Outputs: an info line before running, an error line if it fails.
# Returns: the wrapped command's exit status.

lintfmt_run_step() {
  local label="${1}"
  shift
  local status=0
  lintfmt_log_info "Running: ${label}"
  if "${@}"; then
    status=0
  else
    status="${?}"
    lintfmt_log_error "${label} failed (exit ${status})"
  fi
  return "${status}"
}
