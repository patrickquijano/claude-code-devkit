#!/usr/bin/env bash
#
# devkit_lint_* — repo-wide lint steps used by format-and-lint.sh, each a
# thin devkit_run_step wrapper around one linter. Depend on
# devkit_run_step (and devkit_log_info/devkit_log_success/
# devkit_log_error, transitively) being sourced first. The caller is
# responsible for any tool-exists gating (see format-and-lint.sh's
# main()).
#
# Args: none — each lints the whole repo (cwd).
# Returns: the wrapped command's exit status.

devkit_lint_yamllint() {
  devkit_run_step 'yamllint' uv run yamllint .
}

devkit_lint_shellcheck() {
  devkit_run_step 'shellcheck' bash -c \
    'find . -type f -name "*.sh" | grep -vFf .shellcheckignore | xargs -I{} shellcheck {}'
}

devkit_lint_hadolint() {
  devkit_run_step 'hadolint' bash -c \
    'find . -iname "Dockerfile*" | grep -vFf .hadolintignore | xargs -I{} hadolint {}'
}

devkit_lint_ruff() {
  devkit_run_step 'ruff check --fix' uv run ruff check --fix .
}
