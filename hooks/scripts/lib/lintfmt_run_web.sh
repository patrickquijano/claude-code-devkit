#!/usr/bin/env bash
#
# Prettier wrapper for HTML (no dedicated lint+fix combo tool covers it).
# Depends on lintfmt_command_exists, lintfmt_run_step, lintfmt_log_warn.

# lintfmt_run_prettier — format a file with Prettier via npx (used for
# HTML, which has no dedicated lint+fix combo tool in this hook's set).
# Args: $1 = file path.
lintfmt_run_prettier() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping prettier.'
    return 0
  fi
  lintfmt_run_step 'prettier --write' npx prettier --write "${file}"
}
