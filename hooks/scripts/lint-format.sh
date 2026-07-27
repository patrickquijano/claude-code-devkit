#!/usr/bin/env bash
#
# PostToolUse hook: lint + format a single file right after Claude edits
# or writes it, dispatched by extension. Reads the hook's JSON payload
# from stdin (Claude Code's PostToolUse contract), extracts
# tool_input.file_path and cwd, and runs the matching tool(s) below.
#
# Every tool wrapper checks its own binary/config is actually usable
# before running anything — an uninstalled or unconfigured toolchain is a
# logged skip, never a crash. This hook never blocks the edit: it always
# exits 0 (PostToolUse can't deny a call anyway), so lint/format failures
# only ever show up as warnings, not a stopped session.
#
# All logic lives in hooks/scripts/lib/lintfmt_*.sh (one function per
# file) — see hooks/README.md for the full function reference. Sourcing
# this file instead of executing it skips the main run and just defines
# the functions.

set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_dir="${script_dir}/lib"

# shellcheck source=lib/lintfmt_log_info.sh disable=SC1091
source "${lib_dir}/lintfmt_log_info.sh"
# shellcheck source=lib/lintfmt_log_warn.sh disable=SC1091
source "${lib_dir}/lintfmt_log_warn.sh"
# shellcheck source=lib/lintfmt_log_error.sh disable=SC1091
source "${lib_dir}/lintfmt_log_error.sh"
# shellcheck source=lib/lintfmt_command_exists.sh disable=SC1091
source "${lib_dir}/lintfmt_command_exists.sh"
# shellcheck source=lib/lintfmt_run_step.sh disable=SC1091
source "${lib_dir}/lintfmt_run_step.sh"
# shellcheck source=lib/lintfmt_read_file_path.sh disable=SC1091
source "${lib_dir}/lintfmt_read_file_path.sh"
# shellcheck source=lib/lintfmt_read_cwd.sh disable=SC1091
source "${lib_dir}/lintfmt_read_cwd.sh"
# shellcheck source=lib/lintfmt_is_blade_template.sh disable=SC1091
source "${lib_dir}/lintfmt_is_blade_template.sh"
# shellcheck source=lib/lintfmt_extension_of.sh disable=SC1091
source "${lib_dir}/lintfmt_extension_of.sh"
# shellcheck source=lib/lintfmt_eslint_config_exists.sh disable=SC1091
source "${lib_dir}/lintfmt_eslint_config_exists.sh"
# shellcheck source=lib/lintfmt_stylelint_config_exists.sh disable=SC1091
source "${lib_dir}/lintfmt_stylelint_config_exists.sh"
# shellcheck source=lib/lintfmt_dotnet_project_exists.sh disable=SC1091
source "${lib_dir}/lintfmt_dotnet_project_exists.sh"
# shellcheck source=lib/lintfmt_run_eslint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_eslint.sh"
# shellcheck source=lib/lintfmt_run_stylelint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_stylelint.sh"
# shellcheck source=lib/lintfmt_run_hadolint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_hadolint.sh"
# shellcheck source=lib/lintfmt_run_markdownlint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_markdownlint.sh"
# shellcheck source=lib/lintfmt_run_ruff.sh disable=SC1091
source "${lib_dir}/lintfmt_run_ruff.sh"
# shellcheck source=lib/lintfmt_run_shfmt.sh disable=SC1091
source "${lib_dir}/lintfmt_run_shfmt.sh"
# shellcheck source=lib/lintfmt_run_shellcheck.sh disable=SC1091
source "${lib_dir}/lintfmt_run_shellcheck.sh"
# shellcheck source=lib/lintfmt_run_yamllint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_yamllint.sh"
# shellcheck source=lib/lintfmt_pint_binary.sh disable=SC1091
source "${lib_dir}/lintfmt_pint_binary.sh"
# shellcheck source=lib/lintfmt_run_pint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_pint.sh"
# shellcheck source=lib/lintfmt_run_php_lint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_php_lint.sh"
# shellcheck source=lib/lintfmt_run_dotnet_format.sh disable=SC1091
source "${lib_dir}/lintfmt_run_dotnet_format.sh"
# shellcheck source=lib/lintfmt_run_prettier.sh disable=SC1091
source "${lib_dir}/lintfmt_run_prettier.sh"
# shellcheck source=lib/lintfmt_run_htmlhint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_htmlhint.sh"
# shellcheck source=lib/lintfmt_run_xmllint_format.sh disable=SC1091
source "${lib_dir}/lintfmt_run_xmllint_format.sh"
# shellcheck source=lib/lintfmt_run_xmllint_lint.sh disable=SC1091
source "${lib_dir}/lintfmt_run_xmllint_lint.sh"

main() {
  local payload
  payload="$(cat)"

  local file cwd
  file="$(lintfmt_read_file_path "${payload}")"
  cwd="$(lintfmt_read_cwd "${payload}")"

  [[ -z "${file}" ]] && return 0
  [[ -f "${file}" ]] || return 0
  [[ -z "${cwd}" ]] && cwd="$(dirname -- "${file}")"

  if lintfmt_is_blade_template "${file}"; then
    lintfmt_log_info "Blade template, no safe formatter: ${file}"
    return 0
  fi

  local ext
  ext="$(lintfmt_extension_of "${file}")"

  case "${ext}" in
    ts | tsx | mts | cts | js | jsx | mjs | cjs | vue)
      if lintfmt_eslint_config_exists "${cwd}"; then
        lintfmt_run_eslint "${file}"
      else
        lintfmt_log_info 'No eslint config found, skipping.'
      fi
      ;;
    dockerfile)
      lintfmt_run_hadolint "${file}"
      ;;
    md | markdown)
      lintfmt_run_markdownlint "${file}"
      ;;
    py | pyi)
      lintfmt_run_ruff "${file}"
      ;;
    sh | bash)
      lintfmt_run_shfmt "${file}"
      lintfmt_run_shellcheck "${file}"
      ;;
    yml | yaml)
      lintfmt_run_yamllint "${file}"
      ;;
    php | phtml)
      lintfmt_run_pint "${file}" "${cwd}"
      lintfmt_run_php_lint "${file}"
      ;;
    css | scss | sass | less)
      if lintfmt_stylelint_config_exists "${cwd}"; then
        lintfmt_run_stylelint "${file}"
      else
        lintfmt_log_info 'No stylelint config found, skipping.'
      fi
      ;;
    cs | csx)
      if lintfmt_dotnet_project_exists "${cwd}"; then
        lintfmt_run_dotnet_format "${file}" "${cwd}"
      else
        lintfmt_log_info 'No .sln/.csproj found, skipping dotnet format.'
      fi
      ;;
    html | htm)
      lintfmt_run_prettier "${file}"
      lintfmt_run_htmlhint "${file}"
      ;;
    xml)
      lintfmt_run_xmllint_format "${file}"
      lintfmt_run_xmllint_lint "${file}"
      ;;
    *)
      : # no linter configured for this extension
      ;;
  esac

  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
