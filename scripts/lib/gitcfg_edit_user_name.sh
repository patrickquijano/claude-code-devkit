#!/usr/bin/env bash
#
# gitcfg_edit_user_name — prompt for and idempotently set --local
# user.name. Depends on gitcfg_local_get, gitcfg_local_set,
# gitcfg_is_non_empty, and gitcfg_prompt_text being sourced first.
#
# Args: none.
# Outputs: the gitcfg_local_set status line to stdout.
# Returns: 0 on success.

gitcfg_edit_user_name() {
  local current value
  current="$(gitcfg_local_get user.name)"
  value="$(gitcfg_prompt_text 'user.name' "${current}" gitcfg_is_non_empty)"
  gitcfg_local_set user.name "${value}"
}
