#!/usr/bin/env bash
#
# Repo guard clause + config summary printer for setup-git-config.sh.

# gitcfg_require_repo — guard clause for scripts that must run inside a
# git repository work tree. Depends on devkit_log_error being sourced first.
# Args: none.
# Outputs: error message via devkit_log_error if not inside a git repository.
# Returns: does not return on failure — exits the process with status 1.
gitcfg_require_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    devkit_log_error 'Not inside a git repository.'
    exit 1
  fi
}

# The 5 git config keys this script manages, in menu/display order.
# Namespaced (not just CONFIG_KEYS) because scripts/lib/ is sourced by
# other scripts too, and an uppercase global here would otherwise be
# free to collide with an unrelated same-named constant elsewhere.
readonly GITCFG_CONFIG_KEYS=(user.name user.email user.signingkey gpg.format commit.gpgsign)

# gitcfg_print_config — print the current --local value of every git
# config key this script manages. Depends on gitcfg_local_get being
# sourced first.
# Args: none.
# Outputs: one "<key> <value>" line per managed key to stdout ("(not set)"
#   for unset keys), preceded by a header line.
# Returns: always 0.
gitcfg_print_config() {
  local key value
  printf 'Current --local git config:\n'
  for key in "${GITCFG_CONFIG_KEYS[@]}"; do
    value="$(gitcfg_local_get "${key}")"
    if [[ -n "${value}" ]]; then
      printf '  %-16s %s\n' "${key}" "${value}"
    else
      printf '  %-16s %s\n' "${key}" "(not set)"
    fi
  done
}
