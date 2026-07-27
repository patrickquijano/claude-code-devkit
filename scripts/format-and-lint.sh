#!/usr/bin/env bash
#
# Format then lint every supported file type in this repo, using the
# exact commands documented in CLAUDE.md's "Linting and formatting"
# section, as one entrypoint instead of six copy-pasted commands.
#
# Usage:
#   ./scripts/format-and-lint.sh     (run from the repo root, or any
#                                     subdirectory of a git work tree)
#
# Steps, in order (format first, then lint each language):
#   1. prettier --write .                     (all supported files)
#   2. markdownlint-cli2 --fix "**/*.md"      (markdown autofix)
#   3. yamllint .                             (if installed)
#   4. shellcheck on every *.sh file not in .shellcheckignore (if installed)
#   5. hadolint on every Dockerfile* not in .hadolintignore (if installed)
#   6. ruff format . then ruff check --fix . (if installed)
#
# yamllint, shellcheck, hadolint, and ruff are optional local binaries
# (not fetched via npx) — if one isn't on PATH, that step is skipped with a
# warning instead of failing the whole run. prettier and markdownlint-cli2
# run via `npx`, which fetches them on demand.
#
# Idempotent: re-running against an already-formatted, lint-clean repo
# is a no-op pass — prettier/markdownlint-cli2 make no further changes,
# and every lint step is read-only.
#
# All steps are run even if an earlier one fails, so one pass gives the
# full picture. Exit status is 0 only if every step that ran (i.e. wasn't
# skipped for a missing tool) succeeded; a summary line is printed either
# way.
#
# All logic lives in scripts/lib/devkit_*.sh (devkit_-namespaced so
# they're safe to source from other scripts). This
# file only wires them together — see scripts/README.md for the full
# function reference and how to reuse individual functions elsewhere.
# Sourcing this file instead of executing it skips the main run and just
# defines the functions.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_dir="${script_dir}/lib"

# shellcheck source=lib/devkit_log_info.sh disable=SC1091
source "${lib_dir}/devkit_log_info.sh"
# shellcheck source=lib/devkit_log_success.sh disable=SC1091
source "${lib_dir}/devkit_log_success.sh"
# shellcheck source=lib/devkit_log_warn.sh disable=SC1091
source "${lib_dir}/devkit_log_warn.sh"
# shellcheck source=lib/devkit_log_error.sh disable=SC1091
source "${lib_dir}/devkit_log_error.sh"
# shellcheck source=lib/devkit_command_exists.sh disable=SC1091
source "${lib_dir}/devkit_command_exists.sh"
# shellcheck source=lib/devkit_run_step.sh disable=SC1091
source "${lib_dir}/devkit_run_step.sh"
# shellcheck source=lib/devkit_format.sh disable=SC1091
source "${lib_dir}/devkit_format.sh"
# shellcheck source=lib/devkit_lint.sh disable=SC1091
source "${lib_dir}/devkit_lint.sh"
# shellcheck source=lib/gitcfg_require_repo.sh disable=SC1091
source "${lib_dir}/gitcfg_require_repo.sh"

main() {
  gitcfg_require_repo
  local repo_root
  repo_root="$(cd "${script_dir}/.." && pwd)"
  cd "${repo_root}"

  devkit_log_info 'Starting format and lint.'
  local failures=0

  devkit_format_prettier || failures=$((failures + 1))
  devkit_format_markdownlint || failures=$((failures + 1))

  if devkit_command_exists yamllint; then
    devkit_lint_yamllint || failures=$((failures + 1))
  else
    devkit_log_warn 'yamllint not found on PATH, skipping.'
  fi

  if devkit_command_exists shellcheck; then
    devkit_lint_shellcheck || failures=$((failures + 1))
  else
    devkit_log_warn 'shellcheck not found on PATH, skipping.'
  fi

  if devkit_command_exists hadolint; then
    devkit_lint_hadolint || failures=$((failures + 1))
  else
    devkit_log_warn 'hadolint not found on PATH, skipping.'
  fi

  if devkit_command_exists ruff; then
    devkit_format_ruff || failures=$((failures + 1))
    devkit_lint_ruff || failures=$((failures + 1))
  else
    devkit_log_warn 'ruff not found on PATH, skipping.'
  fi

  if ((failures > 0)); then
    devkit_log_error "Format and lint finished with ${failures} failing step(s)."
    return 1
  fi
  devkit_log_success 'Format and lint finished with no failures.'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
