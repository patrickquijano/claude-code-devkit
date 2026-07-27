#!/usr/bin/env bash
#
# lintfmt_log_error — print an error log line.
#
# Args: $1 = message.
# Outputs: "[ERROR] <message>" to stderr.
# Returns: always 0.

lintfmt_log_error() {
  printf '[ERROR] %s\n' "${1}" >&2
}
