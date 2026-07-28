#!/usr/bin/env bash
#
# Validators for setup-git-config.sh's free-text prompts.

# gitcfg_is_non_empty — validator: value must be a non-empty string.
# Args: $1 = value to check. Returns: 0 if non-empty, 1 otherwise.
gitcfg_is_non_empty() {
  local value="${1}"
  [[ -n "${value}" ]]
}

# gitcfg_is_valid_email — validator: value must look like an email address
# (basic syntax check, not a deliverability check).
# Args: $1 = value to check.
# Returns: 0 if it matches a basic email pattern, 1 otherwise.
gitcfg_is_valid_email() {
  local value="${1}"
  [[ "${value}" =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$ ]]
}
