#!/usr/bin/env bash
#
# Small utility helpers. Repo-wide (not `gitcfg_`-namespaced) since
# neither is specific to any one script in scripts/lib/.

# devkit_command_exists — validator: check whether a command is available
# on PATH.
# Args: $1 = command name. Returns: 0 if found, 1 otherwise.
devkit_command_exists() {
  local name="${1}"
  command -v "${name}" >/dev/null 2>&1
}

# devkit_run_step — run one command as a labeled, logged step. Depends on
# devkit_log_info, devkit_log_success, and devkit_log_error being sourced
# first. Runs the command inside an `if`, so a failing command does not
# trip `set -e` in the caller — the caller gets the exit status back
# instead and decides how to aggregate it across multiple steps.
# Args: $1 = label shown in the log lines, $2.. = command and its
#   arguments to run.
# Outputs: a devkit_log_info line before running, then a
#   devkit_log_success or devkit_log_error line with the outcome.
# Returns: the wrapped command's exit status.
devkit_run_step() {
  local label="${1}"
  shift
  local status=0
  devkit_log_info "Running: ${label}"
  if "${@}"; then
    devkit_log_success "${label}"
  else
    status="${?}"
    devkit_log_error "${label} failed (exit ${status})"
  fi
  return "${status}"
}
