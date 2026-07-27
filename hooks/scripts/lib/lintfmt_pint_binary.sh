#!/usr/bin/env bash
#
# lintfmt_pint_binary — resolve which Laravel Pint binary to use: the
# project-local `vendor/bin/pint` first (the normal Laravel install
# location), falling back to a global `pint` on PATH. Depends on
# lintfmt_command_exists.
#
# Args: $1 = project directory (the hook's `cwd`).
# Outputs: the resolved binary path to stdout, or empty if none found.
# Returns: always 0.

lintfmt_pint_binary() {
  local dir="${1}"
  if [[ -x "${dir}/vendor/bin/pint" ]]; then
    printf '%s\n' "${dir}/vendor/bin/pint"
    return 0
  fi
  if lintfmt_command_exists pint; then
    command -v pint
  fi
}
