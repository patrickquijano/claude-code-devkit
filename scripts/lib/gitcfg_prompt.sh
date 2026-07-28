#!/usr/bin/env bash
#
# Interactive prompts for setup-git-config.sh's menu.

# gitcfg_prompt_text — read free-text input with a default, re-prompting
# until a validator function accepts it.
# Args: $1 = label shown in the prompt, $2 = current/default value (used
#   if the user presses Enter with no input), $3 = name of a validator
#   function taking one argument and returning 0/1 (e.g. gitcfg_is_non_empty).
# Outputs: invalid-input messages to stderr while looping; the accepted
#   value to stdout once validated.
# Returns: 0 once a valid value is accepted (loops forever on invalid input).
gitcfg_prompt_text() {
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

# gitcfg_prompt_choice — numbered choice list for a field with a fixed set
# of valid values (e.g. gpg.format: openpgp|ssh).
# Args: $1 = label, $2 = current/default value (display only), $3.. =
#   the list of valid options in display order.
# Outputs: the label, current value, and numbered options to stderr;
#   invalid-choice messages to stderr while looping; the chosen option to
#   stdout once a valid index is picked.
# Returns: 0 once a valid choice is made (loops forever on invalid input).
gitcfg_prompt_choice() {
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
