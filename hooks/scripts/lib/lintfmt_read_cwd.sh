#!/usr/bin/env bash
#
# lintfmt_read_cwd — extract cwd from a PostToolUse hook JSON payload.
# Requires `jq`.
#
# Args: $1 = raw JSON payload (the hook's stdin, already captured).
# Outputs: the cwd to stdout, or empty string if absent/jq missing.
# Returns: always 0.

lintfmt_read_cwd() {
  local payload="${1}"
  jq -r '.cwd // empty' <<<"${payload}" 2>/dev/null
}
