#!/usr/bin/env bash
#
# devkit_format_* — repo-wide formatting steps used by
# format-and-lint.sh, each a thin devkit_run_step wrapper around one
# formatter. Depend on devkit_run_step (and devkit_log_info/
# devkit_log_success/devkit_log_error, transitively) being sourced first.
# The caller is responsible for any tool-exists gating (see
# format-and-lint.sh's main()).
#
# Args: none — each formats the whole repo (cwd).
# Returns: the wrapped command's exit status.

devkit_format_prettier() {
  devkit_run_step 'prettier --write' npx prettier --write .
}

devkit_format_markdownlint() {
  devkit_run_step 'markdownlint-cli2 --fix' npx markdownlint-cli2 --fix '**/*.md' '#node_modules' '#.venv'
}

devkit_format_ruff() {
  devkit_run_step 'ruff format' uv run ruff format .
}
