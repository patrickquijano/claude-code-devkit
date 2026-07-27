#!/usr/bin/env bash
#
# Interactively view and idempotently set --local git config for the
# current repository: user.name, user.email, user.signingkey, gpg.format,
# commit.gpgsign.
#
# Usage:
#   ./scripts/setup-git-config.sh     (run from the repo root, or any
#                                       subdirectory of a git work tree)
#
# On start, prints the current --local value of all 5 keys, then loops a
# numbered menu letting you pick one to change. Free-text fields
# (user.name, user.email, user.signingkey) are validated and re-prompted
# on invalid input (user.email is additionally checked against a basic
# email pattern); fields with a fixed value set (gpg.format,
# commit.gpgsign) show a numbered choice list instead of free text.
#
# Idempotent: setting a key to the value it already has is a no-op (no
# `git config` call, reported as "already set ... (no change)") — safe to
# re-run with the same answers any number of times.
#
# All logic lives in scripts/lib/gitcfg_*.sh (one function per file,
# gitcfg_-namespaced so they're safe to source from other scripts). This
# file only wires them together — see scripts/README.md for the full
# function reference and how to reuse individual functions elsewhere.
# Sourcing this file instead of executing it skips the interactive main
# loop and just defines the functions.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_dir="${script_dir}/lib"

# shellcheck source=lib/devkit_log_info.sh disable=SC1091
source "${lib_dir}/devkit_log_info.sh"
# shellcheck source=lib/devkit_log_success.sh disable=SC1091
source "${lib_dir}/devkit_log_success.sh"
# shellcheck source=lib/devkit_log_error.sh disable=SC1091
source "${lib_dir}/devkit_log_error.sh"
# shellcheck source=lib/gitcfg_require_repo.sh disable=SC1091
source "${lib_dir}/gitcfg_require_repo.sh"
# shellcheck source=lib/gitcfg_local_get.sh disable=SC1091
source "${lib_dir}/gitcfg_local_get.sh"
# shellcheck source=lib/gitcfg_local_set.sh disable=SC1091
source "${lib_dir}/gitcfg_local_set.sh"
# shellcheck source=lib/gitcfg_print_config.sh disable=SC1091
source "${lib_dir}/gitcfg_print_config.sh"
# shellcheck source=lib/gitcfg_is_non_empty.sh disable=SC1091
source "${lib_dir}/gitcfg_is_non_empty.sh"
# shellcheck source=lib/gitcfg_is_valid_email.sh disable=SC1091
source "${lib_dir}/gitcfg_is_valid_email.sh"
# shellcheck source=lib/gitcfg_prompt_text.sh disable=SC1091
source "${lib_dir}/gitcfg_prompt_text.sh"
# shellcheck source=lib/gitcfg_prompt_choice.sh disable=SC1091
source "${lib_dir}/gitcfg_prompt_choice.sh"
# shellcheck source=lib/gitcfg_edit_user_name.sh disable=SC1091
source "${lib_dir}/gitcfg_edit_user_name.sh"
# shellcheck source=lib/gitcfg_edit_user_email.sh disable=SC1091
source "${lib_dir}/gitcfg_edit_user_email.sh"
# shellcheck source=lib/gitcfg_edit_signingkey.sh disable=SC1091
source "${lib_dir}/gitcfg_edit_signingkey.sh"
# shellcheck source=lib/gitcfg_edit_gpg_format.sh disable=SC1091
source "${lib_dir}/gitcfg_edit_gpg_format.sh"
# shellcheck source=lib/gitcfg_edit_gpgsign.sh disable=SC1091
source "${lib_dir}/gitcfg_edit_gpgsign.sh"

main() {
  devkit_log_info 'Starting git config setup.'
  gitcfg_require_repo
  gitcfg_print_config
  local choice
  while true; do
    printf '\nSelect a config key to set:\n'
    printf '  1) user.name\n'
    printf '  2) user.email\n'
    printf '  3) user.signingkey\n'
    printf '  4) gpg.format\n'
    printf '  5) commit.gpgsign\n'
    printf '  0) Exit\n'
    read -r -p 'Choice: ' choice
    case "${choice}" in
    1)
      gitcfg_edit_user_name
      ;;
    2)
      gitcfg_edit_user_email
      ;;
    3)
      gitcfg_edit_signingkey
      ;;
    4)
      gitcfg_edit_gpg_format
      ;;
    5)
      gitcfg_edit_gpgsign
      ;;
    0)
      devkit_log_success 'Git config setup complete.'
      gitcfg_print_config
      return 0
      ;;
    *)
      printf 'Invalid choice.\n' >&2
      ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
