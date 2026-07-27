#!/usr/bin/env bash
#
# devkit_validate_commit_msg — validate a commit message against this
# repo's Conventional Commits rule (CLAUDE.md's "Commit messages"
# section): first non-blank, non-comment line must be
# `<type>[(scope)]: <subject>` with a known type, and that line must be
# <=72 chars. Depends on devkit_log_error being sourced first.
#
# Args: $1 = path to the commit message file (git's commit-msg arg).
# Outputs: an error line (or two) via devkit_log_error on failure.
# Returns: 0 if valid, 1 otherwise.

devkit_validate_commit_msg() {
  local msg_file="${1}"
  local subject=""
  local line

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    [[ "${line}" == \#* ]] && continue
    subject="${line}"
    break
  done <"${msg_file}"

  if [[ -z "${subject}" ]]; then
    devkit_log_error 'Commit message is empty.'
    return 1
  fi

  local pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?: .+$'
  if [[ ! "${subject}" =~ ${pattern} ]]; then
    devkit_log_error "Commit message must be Conventional Commits: '<type>: <subject>'."
    devkit_log_error "Got: ${subject}"
    devkit_log_error 'Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.'
    return 1
  fi

  if ((${#subject} > 72)); then
    devkit_log_error "Commit message subject is ${#subject} chars, must be <=72: ${subject}"
    return 1
  fi

  return 0
}
