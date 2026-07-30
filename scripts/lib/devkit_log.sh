#!/usr/bin/env bash
#
# Logging helpers, one level each. Repo-wide (not `gitcfg_`-namespaced)
# since logging isn't specific to any one script in scripts/lib/.

# devkit_log_info — print an informational log line.
# Args: $1 = message. Outputs: "[INFO] <message>" to stdout. Returns: 0.
devkit_log_info() {
  printf '[INFO] %s\n' "${1}"
}

# devkit_log_success — print a success log line.
# Args: $1 = message. Outputs: "[OK] <message>" to stdout. Returns: 0.
devkit_log_success() {
  printf '[OK] %s\n' "${1}"
}

# devkit_log_warn — print a warning log line.
# Args: $1 = message. Outputs: "[WARN] <message>" to stderr. Returns: 0.
devkit_log_warn() {
  printf '[WARN] %s\n' "${1}" >&2
}

# devkit_log_error — print an error log line.
# Args: $1 = message. Outputs: "[ERROR] <message>" to stderr. Returns: 0.
devkit_log_error() {
  printf '[ERROR] %s\n' "${1}" >&2
}
