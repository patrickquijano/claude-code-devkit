#!/usr/bin/env bash
#
# devkit_log_error — print an error log line. Repo-wide (not
# `gitcfg_`-namespaced) since logging isn't specific to any one script in
# scripts/lib/.
#
# Args: $1 = message.
# Outputs: "[ERROR] <message>" to stderr.
# Returns: always 0.

devkit_log_error() {
  printf '[ERROR] %s\n' "${1}" >&2
}
