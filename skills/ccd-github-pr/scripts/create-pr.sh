#!/bin/sh
# Create a GitHub pull request using a body file.
#
# Usage: sh create-pr.sh <base> <head> <title> <body-file> [assignee] [reviewers] [--draft]
#
# Arguments:
#   base       - target branch (e.g. main)
#   head       - source branch (or fork-owner:branch for forks)
#   title      - PR title (conventional commits format)
#   body-file  - path to file containing PR description
#   assignee   - optional; login handle or empty string for unassigned
#   reviewers  - optional; comma-separated list of logins or org/team handles
#   --draft    - optional; open as draft when present
#
# Output (to stdout): the created PR URL on success.
#
# Exit codes:
#   0 - PR created, URL on stdout
#   1 - usage error
#   2 - gh missing or unauthenticated
#   3 - gh pr create failed
set -eu

if [ $# -lt 4 ]; then
	echo "usage: create-pr.sh <base> <head> <title> <body-file> [assignee] [reviewers] [--draft]" >&2
	exit 1
fi

base=$1
head=$2
title=$3
body_file=$4
assignee=${5:-}
reviewers=${6:-}
draft=${7:-}

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 2
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 2
fi

# Build the command arguments
args="--base $base --head $head --title $title --body-file $body_file"

if [ -n "$assignee" ]; then
	args="$args --assignee $assignee"
fi

if [ -n "$reviewers" ]; then
	args="$args --reviewer $reviewers"
fi

if [ "$draft" = "--draft" ]; then
	args="$args --draft"
fi

# shellcheck disable=SC2086
url=$(gh pr create $args 2> /dev/null) || {
	echo "gh-pr-create-failed: could not create pull request" >&2
	exit 3
}

printf '%s\n' "$url"
exit 0
