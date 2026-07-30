#!/usr/bin/env bash
#
# Small utility helpers used by lint-format.sh's main() before dispatch:
# command detection, a labeled step runner, hook-payload parsing, and
# file-type detection.

# lintfmt_command_exists — validator: check whether a command is
# available on PATH.
# Args: $1 = command name. Returns: 0 if found, 1 otherwise.
lintfmt_command_exists() {
  command -v "${1}" >/dev/null 2>&1
}

# lintfmt_run_step — run one command as a labeled, logged step. Depends
# on lintfmt_log_info and lintfmt_log_error being sourced first. Runs the
# command inside an `if`, so a failing command does not trip `set -e` in
# the caller — the caller gets the exit status back instead.
# Args: $1 = label shown in the log lines, $2.. = command and its args.
# Returns: the wrapped command's exit status.
lintfmt_run_step() {
  local label="${1}"
  shift
  local status=0
  lintfmt_log_info "Running: ${label}"
  if "${@}"; then
    status=0
  else
    status="${?}"
    lintfmt_log_error "${label} failed (exit ${status})"
  fi
  return "${status}"
}

# lintfmt_read_file_path — extract tool_input.file_path from a
# PostToolUse hook JSON payload. Requires `jq`.
# Args: $1 = raw JSON payload. Outputs: file path to stdout, or empty.
lintfmt_read_file_path() {
  local payload="${1}"
  jq -r '.tool_input.file_path // empty' <<<"${payload}" 2>/dev/null
}

# lintfmt_read_cwd — extract cwd from a PostToolUse hook JSON payload.
# Requires `jq`.
# Args: $1 = raw JSON payload. Outputs: cwd to stdout, or empty.
lintfmt_read_cwd() {
  local payload="${1}"
  jq -r '.cwd // empty' <<<"${payload}" 2>/dev/null
}

# lintfmt_extension_of — dispatch key for a file path: `dockerfile` for
# any `Dockerfile*` basename (case-insensitive), else the lowercase
# extension after the last dot, else empty (no extension).
# Args: $1 = file path. Outputs: dispatch key to stdout.
lintfmt_extension_of() {
  local path="${1}"
  local base
  base="$(basename -- "${path}")"
  if [[ "${base}" =~ ^[Dd][Oo][Cc][Kk][Ee][Rr][Ff][Ii][Ll][Ee] ]]; then
    printf 'dockerfile\n'
    return 0
  fi
  if [[ "${base}" == *.* ]]; then
    printf '%s\n' "${base##*.}" | tr '[:upper:]' '[:lower:]'
  fi
}

# lintfmt_is_blade_template — true if a file path is a Laravel Blade
# template (`*.blade.php`). Blade mixes HTML with `@directive` syntax, so
# it fails plain PHP syntax checks and no linter here is safe to run on it.
# Args: $1 = file path. Returns: 0 if basename ends in `.blade.php`, 1 otherwise.
lintfmt_is_blade_template() {
  local base
  base="$(basename -- "${1}")"
  [[ "${base}" == *.blade.php ]]
}
