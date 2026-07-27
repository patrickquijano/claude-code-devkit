#!/usr/bin/env bash
#
# lintfmt_is_blade_template — check whether a file path is a Laravel
# Blade template (`*.blade.php`). Blade mixes HTML with `@directive`
# syntax, so it fails plain PHP syntax checks and no linter here is safe
# to run on it.
#
# Args: $1 = file path.
# Outputs: none.
# Returns: 0 if the basename ends in `.blade.php`, 1 otherwise.

lintfmt_is_blade_template() {
  local base
  base="$(basename -- "${1}")"
  [[ "${base}" == *.blade.php ]]
}
