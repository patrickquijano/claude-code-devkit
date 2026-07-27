#!/usr/bin/env bash
#
# lintfmt_run_markdownlint — lint+fix a Markdown file with
# markdownlint-cli2 via npx. Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path.
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_markdownlint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping markdownlint-cli2.'
    return 0
  fi
  lintfmt_run_step 'markdownlint-cli2 --fix' npx markdownlint-cli2 --fix "${file}"
}
