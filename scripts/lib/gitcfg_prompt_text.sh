#!/usr/bin/env bash
#
# gitcfg_prompt_text — read free-text input with a default, re-prompting
# until a validator function accepts it.
#
# Args: $1 = label shown in the prompt, $2 = current/default value (used
#   if the user presses Enter with no input), $3 = name of a validator
#   function taking one argument and returning 0/1 (e.g. gitcfg_is_non_empty
#   from scripts/lib/gitcfg_is_non_empty.sh).
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
