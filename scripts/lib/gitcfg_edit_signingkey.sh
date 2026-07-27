#!/usr/bin/env bash
#
# gitcfg_edit_signingkey — prompt for and idempotently set --local
# user.signingkey. Depends on gitcfg_local_get, gitcfg_local_set,
# gitcfg_is_non_empty, and gitcfg_prompt_text being sourced first.
#
# Args: none.
# Outputs: the gitcfg_local_set status line to stdout.
# Returns: 0 on success.

gitcfg_edit_signingkey() {
  local current value
  current="$(gitcfg_local_get user.signingkey)"
  value="$(gitcfg_prompt_text 'user.signingkey' "${current}" gitcfg_is_non_empty)"
  gitcfg_local_set user.signingkey "${value}"
}
