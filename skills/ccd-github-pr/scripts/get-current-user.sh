#!/bin/sh
# Get the current authenticated GitHub user's login.
#
# Usage: sh get-current-user.sh
#
# Output (to stdout): one line containing the user's login handle.
#
# Exit codes:
#   0 - success, login on stdout
#   1 - gh missing or unauthenticated
set -eu

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 1
fi

gh api user --jq '.login'
