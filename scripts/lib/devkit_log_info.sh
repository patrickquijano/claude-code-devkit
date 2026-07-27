#!/usr/bin/env bash
#
# devkit_log_info — print an informational log line. Repo-wide (not
# `gitcfg_`-namespaced) since logging isn't specific to any one script in
# scripts/lib/.
#
# Args: $1 = message.
# Outputs: "[INFO] <message>" to stdout.
# Returns: always 0.

devkit_log_info() {
  printf '[INFO] %s\n' "${1}"
}
