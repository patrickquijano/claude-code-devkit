#!/usr/bin/env bash
#
# Interactively view and set --local git config for the current repository:
# user.name, user.email, user.signingkey, gpg.format, commit.gpgsign.
#
# Designed to be both executed directly and sourced by other scripts —
# sourcing skips the interactive main loop, exposing the functions below.

set -euo pipefail

readonly CONFIG_KEYS=(user.name user.email user.signingkey gpg.format commit.gpgsign)

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Error: not inside a git repository.\n' >&2
    exit 1
  fi
}

git_local_get() {
  local key="${1}"
  local value=""
  if value="$(git config --local --get "${key}" 2>/dev/null)"; then
    printf '%s' "${value}"
  else
    printf ''
  fi
}

git_local_set() {
  local key="${1}"
  local value="${2}"
  git config --local "${key}" "${value}"
}

print_config() {
  local key value
  printf 'Current --local git config:\n'
  for key in "${CONFIG_KEYS[@]}"; do
    value="$(git_local_get "${key}")"
    if [[ -n "${value}" ]]; then
      printf '  %-16s %s\n' "${key}" "${value}"
    else
      printf '  %-16s %s\n' "${key}" "(not set)"
    fi
  done
}

is_non_empty() {
  local value="${1}"
  [[ -n "${value}" ]]
}

is_valid_email() {
  local value="${1}"
  [[ "${value}" =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$ ]]
}

# Read free-text input with a default (current value) and re-prompt until
# `validator` (a function name) accepts it.
prompt_text() {
  local label="${1}"
  local current="${2}"
  local validator="${3}"
  local input
  while true; do
    read -r -p "${label} [${current:-none}]: " input
    if [[ -z "${input}" ]]; then
      input="${current}"
    fi
    if "${validator}" "${input}"; then
      printf '%s' "${input}"
      return 0
    fi
    printf 'Invalid value for %s. Try again.\n' "${label}" >&2
  done
}

# Numbered choice list for fields with a fixed set of valid values.
prompt_choice() {
  local label="${1}"
  local current="${2}"
  shift 2
  local -a options=("${@}")
  local choice i
  printf '%s (current: %s)\n' "${label}" "${current:-none}" >&2
  for i in "${!options[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${options[${i}]}" >&2
  done
  while true; do
    read -r -p "Choose [1-${#options[@]}]: " choice
    if [[ "${choice}" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
      printf '%s' "${options[$((choice - 1))]}"
      return 0
    fi
    printf 'Invalid choice. Try again.\n' >&2
  done
}

edit_user_name() {
  local current value
  current="$(git_local_get user.name)"
  value="$(prompt_text 'user.name' "${current}" is_non_empty)"
  git_local_set user.name "${value}"
  printf 'user.name set to %s\n' "${value}"
}

edit_user_email() {
  local current value
  current="$(git_local_get user.email)"
  value="$(prompt_text 'user.email' "${current}" is_valid_email)"
  git_local_set user.email "${value}"
  printf 'user.email set to %s\n' "${value}"
}

edit_signingkey() {
  local current value
  current="$(git_local_get user.signingkey)"
  value="$(prompt_text 'user.signingkey' "${current}" is_non_empty)"
  git_local_set user.signingkey "${value}"
  printf 'user.signingkey set to %s\n' "${value}"
}

edit_gpg_format() {
  local current value
  current="$(git_local_get gpg.format)"
  if [[ -z "${current}" ]]; then
    current='openpgp'
  fi
  value="$(prompt_choice 'gpg.format' "${current}" openpgp ssh)"
  git_local_set gpg.format "${value}"
  printf 'gpg.format set to %s\n' "${value}"
}

edit_gpgsign() {
  local current value
  current="$(git_local_get commit.gpgsign)"
  if [[ -z "${current}" ]]; then
    current='false'
  fi
  value="$(prompt_choice 'commit.gpgsign' "${current}" true false)"
  git_local_set commit.gpgsign "${value}"
  printf 'commit.gpgsign set to %s\n' "${value}"
}

main() {
  require_git_repo
  print_config
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
      edit_user_name
      ;;
    2)
      edit_user_email
      ;;
    3)
      edit_signingkey
      ;;
    4)
      edit_gpg_format
      ;;
    5)
      edit_gpgsign
      ;;
    0)
      printf 'Done.\n'
      print_config
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
