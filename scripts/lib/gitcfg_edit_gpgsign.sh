#!/usr/bin/env bash
#
# gitcfg_edit_gpgsign — prompt for and idempotently set --local
# commit.gpgsign (true|false). Depends on gitcfg_local_get,
# gitcfg_local_set, and gitcfg_prompt_choice being sourced first.
#
# Args: none.
# Outputs: the gitcfg_local_set status line to stdout.
# Returns: 0 on success.

gitcfg_edit_gpgsign() {
  local current value
  current="$(gitcfg_local_get commit.gpgsign)"
  if [[ -z "${current}" ]]; then
    current='false'
  fi
  value="$(gitcfg_prompt_choice 'commit.gpgsign' "${current}" true false)"
  gitcfg_local_set commit.gpgsign "${value}"
}
