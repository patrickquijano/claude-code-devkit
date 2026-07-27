#!/usr/bin/env bash
#
# lintfmt_stylelint_config_exists — check whether a project directory has
# a real Stylelint config. Stylelint hard-errors with no config, so this
# gates whether it's worth even trying. Depends on lintfmt_command_exists.
#
# Args: $1 = project directory (the hook's `cwd`).
# Outputs: none.
# Returns: 0 if a config is found, 1 otherwise.

lintfmt_stylelint_config_exists() {
  local dir="${1}"
  local candidate
  for candidate in .stylelintrc .stylelintrc.js .stylelintrc.cjs .stylelintrc.mjs \
    .stylelintrc.json .stylelintrc.yml .stylelintrc.yaml \
    stylelint.config.js stylelint.config.cjs stylelint.config.mjs; do
    [[ -f "${dir}/${candidate}" ]] && return 0
  done
  if [[ -f "${dir}/package.json" ]] && lintfmt_command_exists jq; then
    local has_config
    has_config="$(jq -r 'has("stylelint")' "${dir}/package.json" 2>/dev/null)"
    [[ "${has_config}" == "true" ]] && return 0
  fi
  return 1
}
