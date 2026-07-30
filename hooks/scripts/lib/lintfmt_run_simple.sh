#!/usr/bin/env bash
#
# Single-command linters with no supporting config-check helper: ruff
# (Python), markdownlint-cli2 (Markdown), yamllint (YAML), hadolint
# (Dockerfile). Depend on lintfmt_command_exists, lintfmt_run_step,
# lintfmt_log_warn.

# lintfmt_run_ruff — format then lint+fix a Python file with ruff.
# Args: $1 = file path.
# Returns: 0 if skipped; otherwise the worse of the two steps' exit
#   statuses (both run even if the first fails).
lintfmt_run_ruff() {
  local file="${1}"
  if ! lintfmt_command_exists uv; then
    lintfmt_log_warn 'uv not found on PATH, skipping ruff.'
    return 0
  fi
  local status=0
  lintfmt_run_step 'ruff format' uv run ruff format "${file}" || status="${?}"
  lintfmt_run_step 'ruff check --fix' uv run ruff check --fix "${file}" || status="${?}"
  return "${status}"
}

# lintfmt_run_markdownlint — lint+fix a Markdown file with
# markdownlint-cli2 via npx.
# Args: $1 = file path.
lintfmt_run_markdownlint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping markdownlint-cli2.'
    return 0
  fi
  lintfmt_run_step 'markdownlint-cli2 --fix' npx markdownlint-cli2 --fix "${file}"
}

# lintfmt_run_yamllint — lint a YAML file with yamllint (lint-only, no
# autofix tool exists).
# Args: $1 = file path.
lintfmt_run_yamllint() {
  local file="${1}"
  if ! lintfmt_command_exists uv; then
    lintfmt_log_warn 'uv not found on PATH, skipping yamllint.'
    return 0
  fi
  lintfmt_run_step 'yamllint' uv run yamllint "${file}"
}

# lintfmt_run_hadolint — lint a Dockerfile with hadolint.
# Args: $1 = file path.
lintfmt_run_hadolint() {
  local file="${1}"
  if ! lintfmt_command_exists hadolint; then
    lintfmt_log_warn 'hadolint not found on PATH, skipping.'
    return 0
  fi
  lintfmt_run_step 'hadolint' hadolint "${file}"
}
