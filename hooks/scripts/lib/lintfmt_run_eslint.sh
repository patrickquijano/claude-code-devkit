#!/usr/bin/env bash
#
# lintfmt_run_eslint — lint+fix a JS/TS/Vue file with ESLint via npx.
# Covers React, Next.js, Angular, Vue.js, and Nuxt.js since they all run
# on eslint underneath. Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_eslint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping eslint.'
    return 0
  fi
  lintfmt_run_step 'eslint --fix' npx eslint --fix "${file}"
}
