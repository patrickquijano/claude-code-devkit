#!/usr/bin/env bash
#
# gitcfg_is_valid_email — validator: value must look like an email address
# (basic syntax check, not a deliverability check).
#
# Args: $1 = value to check.
# Outputs: none.
# Returns: 0 if it matches a basic email pattern, 1 otherwise.

gitcfg_is_valid_email() {
  local value="${1}"
  [[ "${value}" =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$ ]]
}
