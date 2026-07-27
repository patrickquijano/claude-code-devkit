#!/usr/bin/env bash
#
# lintfmt_extension_of — determine the dispatch key for a file path:
# `dockerfile` for any `Dockerfile*` basename (case-insensitive), else
# the lowercase extension after the last dot, else empty (no extension).
#
# Args: $1 = file path.
# Outputs: dispatch key to stdout.
# Returns: always 0.

lintfmt_extension_of() {
  local path="${1}"
  local base
  base="$(basename -- "${path}")"
  if [[ "${base}" =~ ^[Dd][Oo][Cc][Kk][Ee][Rr][Ff][Ii][Ll][Ee] ]]; then
    printf 'dockerfile\n'
    return 0
  fi
  if [[ "${base}" == *.* ]]; then
    printf '%s\n' "${base##*.}" | tr '[:upper:]' '[:lower:]'
  fi
}
