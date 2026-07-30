#!/usr/bin/env bash
#
# .NET tooling: project detection + `dotnet format`.

# lintfmt_dotnet_project_exists — check whether a project directory has a
# .NET project or solution file. `dotnet format` requires project
# context; it can't run against a bare file.
# Args: $1 = project directory (the hook's `cwd`).
# Returns: 0 if a `*.sln` or `*.csproj` is found directly in the
#   directory, 1 otherwise.
lintfmt_dotnet_project_exists() {
  local dir="${1}"
  compgen -G "${dir}/*.sln" >/dev/null 2>&1 && return 0
  compgen -G "${dir}/*.csproj" >/dev/null 2>&1 && return 0
  return 1
}

# lintfmt_run_dotnet_format — format+lint a C# file with `dotnet format`,
# scoped to the file via --include. Requires a project/solution in the
# project directory (checked by the caller via
# lintfmt_dotnet_project_exists). Depends on lintfmt_command_exists,
# lintfmt_run_step, lintfmt_log_warn.
# Args: $1 = file path, $2 = project directory (the hook's `cwd`).
lintfmt_run_dotnet_format() {
  local file="${1}"
  local dir="${2}"
  if ! lintfmt_command_exists dotnet; then
    lintfmt_log_warn 'dotnet not found on PATH, skipping dotnet format.'
    return 0
  fi
  lintfmt_run_step 'dotnet format' dotnet format "${dir}" --include "${file}"
}
