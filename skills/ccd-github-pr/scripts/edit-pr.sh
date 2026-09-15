#!/bin/sh
# Edit an existing GitHub pull request.
#
# Usage: sh edit-pr.sh <pr-number> [options]
#
# Options (all optional; only changed fields should be passed):
#   --title <title>         new PR title
#   --body-file <path>      path to file containing new PR description
#   --base <branch>         new target branch
#   --add-reviewer <list>   comma-separated logins or org/team handles to add
#   --add-assignee <login>  login handle to add as assignee
#
# Output (to stdout): the PR URL on success.
#
# Exit codes:
#   0 - PR edited, URL on stdout
#   1 - usage error or no fields to edit
#   2 - gh missing or unauthenticated
#   3 - gh pr edit failed
set -eu

if [ $# -lt 1 ]; then
	echo "usage: edit-pr.sh <pr-number> [--title T] [--body-file F] [--base B] [--add-reviewer R] [--add-assignee A]" >&2
	exit 1
fi

pr_number=$1
shift

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 2
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 2
fi

args="$pr_number"
has_field=false

while [ $# -gt 0 ]; do
	case "$1" in
		--title)
			args="$args --title $2"
			has_field=true
			shift 2
			;;
		--body-file)
			args="$args --body-file $2"
			has_field=true
			shift 2
			;;
		--base)
			args="$args --base $2"
			has_field=true
			shift 2
			;;
		--add-reviewer)
			args="$args --add-reviewer $2"
			has_field=true
			shift 2
			;;
		--add-assignee)
			args="$args --add-assignee $2"
			has_field=true
			shift 2
			;;
		*)
			echo "unknown-option: $1" >&2
			exit 1
			;;
	esac
done

if [ "$has_field" = false ]; then
	echo "no-fields: nothing to edit" >&2
	exit 1
fi

# shellcheck disable=SC2086
url=$(gh pr edit $args 2> /dev/null) || {
	echo "gh-pr-edit-failed: could not edit PR #$pr_number" >&2
	exit 3
}

printf '%s\n' "$url"
exit 0
