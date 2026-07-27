#!/usr/bin/env bash
#
# gitcfg_edit_gpg_format — prompt for and idempotently set --local
# gpg.format (openpgp|ssh). Depends on gitcfg_local_get, gitcfg_local_set,
# and gitcfg_prompt_choice being sourced first.
#
# Args: none.
# Outputs: the gitcfg_local_set status line to stdout.
# Returns: 0 on success.

gitcfg_edit_gpg_format() {
  local current value
  current="$(gitcfg_local_get gpg.format)"
  if [[ -z "${current}" ]]; then
    current='openpgp'
  fi
  value="$(gitcfg_prompt_choice 'gpg.format' "${current}" openpgp ssh)"
  gitcfg_local_set gpg.format "${value}"
}
