#!/usr/bin/env bash
#
# lintfmt_log_warn — print a warning log line.
#
# Args: $1 = message.
# Outputs: "[WARN] <message>" to stderr.
# Returns: always 0.

lintfmt_log_warn() {
  printf '[WARN] %s\n' "${1}" >&2
}
