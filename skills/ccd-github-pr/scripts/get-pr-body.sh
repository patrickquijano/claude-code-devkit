#!/bin/sh
# Retrieve the body of an existing GitHub pull request.
#
# Usage: sh get-pr-body.sh <pr-number>
#
# Output (to stdout): the PR body text, or empty string if no body.
#
# Exit codes:
#   0 - success, body on stdout (may be empty)
#   1 - usage error or missing argument
#   2 - gh missing or unauthenticated
#   3 - gh pr view failed
set -eu

if [ $# -ne 1 ]; then
	echo "usage: get-pr-body.sh <pr-number>" >&2
	exit 1
fi

pr_number=$1

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 2
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 2
fi

body=$(gh pr view "$pr_number" --json body --jq '.body' 2> /dev/null) || {
	echo "gh-pr-view-failed: could not retrieve body for PR #$pr_number" >&2
	exit 3
}

printf '%s\n' "$body"
exit 0
