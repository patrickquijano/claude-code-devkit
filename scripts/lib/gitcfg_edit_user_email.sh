#!/usr/bin/env bash
#
# gitcfg_edit_user_email — prompt for and idempotently set --local
# user.email. Depends on gitcfg_local_get, gitcfg_local_set,
# gitcfg_is_valid_email, and gitcfg_prompt_text being sourced first.
#
# Args: none.
# Outputs: the gitcfg_local_set status line to stdout.
# Returns: 0 on success.

gitcfg_edit_user_email() {
  local current value
  current="$(gitcfg_local_get user.email)"
  value="$(gitcfg_prompt_text 'user.email' "${current}" gitcfg_is_valid_email)"
  gitcfg_local_set user.email "${value}"
}
