#!/usr/bin/env bash
#
# lintfmt_read_file_path — extract tool_input.file_path from a
# PostToolUse hook JSON payload. Requires `jq`.
#
# Args: $1 = raw JSON payload (the hook's stdin, already captured).
# Outputs: the file path to stdout, or empty string if absent/jq missing.
# Returns: always 0.

lintfmt_read_file_path() {
  local payload="${1}"
  jq -r '.tool_input.file_path // empty' <<<"${payload}" 2>/dev/null
}
