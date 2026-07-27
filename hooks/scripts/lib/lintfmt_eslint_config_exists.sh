#!/usr/bin/env bash
#
# lintfmt_eslint_config_exists — check whether a project directory has a
# real ESLint config. ESLint hard-errors with no config, so this gates
# whether it's worth even trying. Depends on lintfmt_command_exists.
#
# Args: $1 = project directory (the hook's `cwd`).
# Outputs: none.
# Returns: 0 if a config is found, 1 otherwise.

lintfmt_eslint_config_exists() {
  local dir="${1}"
  local candidate
  for candidate in .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.mjs \
    .eslintrc.json .eslintrc.yml .eslintrc.yaml \
    eslint.config.js eslint.config.cjs eslint.config.mjs eslint.config.ts; do
    [[ -f "${dir}/${candidate}" ]] && return 0
  done
  if [[ -f "${dir}/package.json" ]] && lintfmt_command_exists jq; then
    local has_config
    has_config="$(jq -r 'has("eslintConfig")' "${dir}/package.json" 2>/dev/null)"
    [[ "${has_config}" == "true" ]] && return 0
  fi
  return 1
}
