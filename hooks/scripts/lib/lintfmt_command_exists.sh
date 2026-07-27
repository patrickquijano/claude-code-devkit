#!/usr/bin/env bash
#
# lintfmt_command_exists — validator: check whether a command is
# available on PATH.
#
# Args: $1 = command name.
# Outputs: none.
# Returns: 0 if the command is found, 1 otherwise.

lintfmt_command_exists() {
  command -v "${1}" >/dev/null 2>&1
}
