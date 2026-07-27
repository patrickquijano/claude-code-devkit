#!/usr/bin/env bash
#
# lintfmt_log_info — print an informational log line.
#
# Args: $1 = message.
# Outputs: "[INFO] <message>" to stdout.
# Returns: always 0.

lintfmt_log_info() {
  printf '[INFO] %s\n' "${1}"
}
