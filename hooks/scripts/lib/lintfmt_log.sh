#!/usr/bin/env bash
#
# Logging helpers, one level each.

# lintfmt_log_info — print an informational log line.
# Args: $1 = message. Outputs: "[INFO] <message>" to stdout. Returns: 0.
lintfmt_log_info() {
  printf '[INFO] %s\n' "${1}"
}

# lintfmt_log_warn — print a warning log line.
# Args: $1 = message. Outputs: "[WARN] <message>" to stderr. Returns: 0.
lintfmt_log_warn() {
  printf '[WARN] %s\n' "${1}" >&2
}

# lintfmt_log_error — print an error log line.
# Args: $1 = message. Outputs: "[ERROR] <message>" to stderr. Returns: 0.
lintfmt_log_error() {
  printf '[ERROR] %s\n' "${1}" >&2
}
