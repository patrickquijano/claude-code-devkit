#!/usr/bin/env bash
#
# lintfmt_dotnet_project_exists — check whether a project directory has a
# .NET project or solution file. `dotnet format` requires project
# context; it can't run against a bare file.
#
# Args: $1 = project directory (the hook's `cwd`).
# Outputs: none.
# Returns: 0 if a `*.sln` or `*.csproj` is found directly in the
#   directory, 1 otherwise.

lintfmt_dotnet_project_exists() {
  local dir="${1}"
  compgen -G "${dir}/*.sln" >/dev/null 2>&1 && return 0
  compgen -G "${dir}/*.csproj" >/dev/null 2>&1 && return 0
  return 1
}
