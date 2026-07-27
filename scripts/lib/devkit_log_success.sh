#!/usr/bin/env bash
#
# devkit_log_success — print a success log line. Repo-wide (not
# `gitcfg_`-namespaced) since logging isn't specific to any one script in
# scripts/lib/.
#
# Args: $1 = message.
# Outputs: "[OK] <message>" to stdout.
# Returns: always 0.

devkit_log_success() {
  printf '[OK] %s\n' "${1}"
}
