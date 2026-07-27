#!/usr/bin/env bash
#
# lintfmt_run_dotnet_format — format+lint a C# file with `dotnet format`,
# scoped to the file via --include. Requires a project/solution in the
# project directory (checked by the caller via
# lintfmt_dotnet_project_exists). Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
#
# Args: $1 = file path, $2 = project directory (the hook's `cwd`).
# Returns: 0 if skipped or the wrapped command succeeded; the command's
#   exit status otherwise.

lintfmt_run_dotnet_format() {
  local file="${1}"
  local dir="${2}"
  if ! lintfmt_command_exists dotnet; then
    lintfmt_log_warn 'dotnet not found on PATH, skipping dotnet format.'
    return 0
  fi
  lintfmt_run_step 'dotnet format' dotnet format "${dir}" --include "${file}"
}
