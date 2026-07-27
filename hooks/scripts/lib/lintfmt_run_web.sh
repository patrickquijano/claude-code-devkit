#!/usr/bin/env bash
#
# Web tooling wrappers: eslint (JS/TS/Vue), stylelint (CSS/SCSS/SASS/LESS),
# htmlhint + prettier (HTML). All npx-based. Depend on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.

# lintfmt_run_eslint — lint+fix a JS/TS/Vue file with ESLint via npx.
# Covers React, Next.js, Angular, Vue.js, and Nuxt.js since they all run
# on eslint underneath.
# Args: $1 = file path.
lintfmt_run_eslint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping eslint.'
    return 0
  fi
  lintfmt_run_step 'eslint --fix' npx eslint --fix "${file}"
}

# lintfmt_eslint_config_exists — check whether a project directory has a
# real ESLint config. ESLint hard-errors with no config, so this gates
# whether it's worth even trying. Depends on lintfmt_command_exists.
# Args: $1 = project directory (the hook's `cwd`).
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

# lintfmt_run_stylelint — lint+fix a CSS/SCSS/SASS/LESS file with
# Stylelint via npx.
# Args: $1 = file path.
lintfmt_run_stylelint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping stylelint.'
    return 0
  fi
  lintfmt_run_step 'stylelint --fix' npx stylelint --fix "${file}"
}

# lintfmt_stylelint_config_exists — check whether a project directory has
# a real Stylelint config. Stylelint hard-errors with no config, so this
# gates whether it's worth even trying. Depends on lintfmt_command_exists.
# Args: $1 = project directory (the hook's `cwd`).
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

# lintfmt_run_htmlhint — lint an HTML file with htmlhint via npx.
# Args: $1 = file path.
lintfmt_run_htmlhint() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping htmlhint.'
    return 0
  fi
  lintfmt_run_step 'htmlhint' npx htmlhint "${file}"
}

# lintfmt_run_prettier — format a file with Prettier via npx (used for
# HTML, which has no dedicated lint+fix combo tool in this hook's set).
# Args: $1 = file path.
lintfmt_run_prettier() {
  local file="${1}"
  if ! lintfmt_command_exists npx; then
    lintfmt_log_warn 'npx not found on PATH, skipping prettier.'
    return 0
  fi
  lintfmt_run_step 'prettier --write' npx prettier --write "${file}"
}
