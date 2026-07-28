#!/usr/bin/env bash
#
# Prompt + idempotently set each of the 5 managed --local git config
# keys. Depend on gitcfg_local_get, gitcfg_local_set, gitcfg_prompt_text/
# gitcfg_prompt_choice, and (for the two free-text ones) gitcfg_is_non_empty/
# gitcfg_is_valid_email being sourced first.

# gitcfg_edit_user_name — prompt for and idempotently set --local user.name.
gitcfg_edit_user_name() {
  local current value
  current="$(gitcfg_local_get user.name)"
  value="$(gitcfg_prompt_text 'user.name' "${current}" gitcfg_is_non_empty)"
  gitcfg_local_set user.name "${value}"
}

# gitcfg_edit_user_email — prompt for and idempotently set --local user.email.
gitcfg_edit_user_email() {
  local current value
  current="$(gitcfg_local_get user.email)"
  value="$(gitcfg_prompt_text 'user.email' "${current}" gitcfg_is_valid_email)"
  gitcfg_local_set user.email "${value}"
}

# gitcfg_edit_signingkey — prompt for and idempotently set --local user.signingkey.
gitcfg_edit_signingkey() {
  local current value
  current="$(gitcfg_local_get user.signingkey)"
  value="$(gitcfg_prompt_text 'user.signingkey' "${current}" gitcfg_is_non_empty)"
  gitcfg_local_set user.signingkey "${value}"
}

# gitcfg_edit_gpg_format — prompt for and idempotently set --local gpg.format (openpgp|ssh).
gitcfg_edit_gpg_format() {
  local current value
  current="$(gitcfg_local_get gpg.format)"
  if [[ -z "${current}" ]]; then
    current='openpgp'
  fi
  value="$(gitcfg_prompt_choice 'gpg.format' "${current}" openpgp ssh)"
  gitcfg_local_set gpg.format "${value}"
}

# gitcfg_edit_gpgsign — prompt for and idempotently set --local commit.gpgsign (true|false).
gitcfg_edit_gpgsign() {
  local current value
  current="$(gitcfg_local_get commit.gpgsign)"
  if [[ -z "${current}" ]]; then
    current='false'
  fi
  value="$(gitcfg_prompt_choice 'commit.gpgsign' "${current}" true false)"
  gitcfg_local_set commit.gpgsign "${value}"
}
