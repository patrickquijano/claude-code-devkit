#!/usr/bin/env bash
#
# devkit_log_warn — print a warning log line. Repo-wide (not
# `gitcfg_`-namespaced) since logging isn't specific to any one script in
# scripts/lib/.
#
# Args: $1 = message.
# Outputs: "[WARN] <message>" to stderr.
# Returns: always 0.

devkit_log_warn() {
  printf '[WARN] %s\n' "${1}" >&2
}
