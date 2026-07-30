#!/usr/bin/env bash
#
# Shell script wrappers: shfmt (format) + shellcheck (lint). Depend on
# lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.

# lintfmt_run_shfmt — format a shell script in place with shfmt (2-space
# indent, matching .editorconfig; switch-case bodies indented).
# Args: $1 = file path.
lintfmt_run_shfmt() {
  local file="${1}"
  if ! lintfmt_command_exists shfmt; then
    lintfmt_log_warn 'shfmt not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'shfmt -w' shfmt -w -i 2 -ci "${file}"
}

# lintfmt_run_shellcheck — lint a shell script with shellcheck.
# Args: $1 = file path.
lintfmt_run_shellcheck() {
  local file="${1}"
  if ! lintfmt_command_exists shellcheck; then
    lintfmt_log_warn 'shellcheck not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'shellcheck' shellcheck "${file}"
}
