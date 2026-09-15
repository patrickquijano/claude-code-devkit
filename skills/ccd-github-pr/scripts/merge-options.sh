#!/bin/sh
# Arm auto-merge, squash and/or delete-branch on an existing GitHub pull request.
#
# Usage: sh merge-options.sh <pr-url> [--auto] [--squash] [--delete-branch]
#
# At least one flag must be supplied. The script builds the gh pr merge call
# from exactly the flags passed — never from a fixed string.
#
# Output (to stdout): the PR URL on success.
#
# Exit codes:
#   0 - command succeeded
#   1 - usage error or no flags supplied
#   2 - gh missing or unauthenticated
#   3 - gh pr merge failed
set -eu

if [ $# -lt 1 ]; then
	echo "usage: merge-options.sh <pr-url> [--auto] [--squash] [--delete-branch]" >&2
	exit 1
fi

pr_url=$1
shift

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 2
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 2
fi

args="$pr_url"
has_flag=false

while [ $# -gt 0 ]; do
	case "$1" in
		--auto)
			args="$args --auto"
			has_flag=true
			shift
			;;
		--squash)
			args="$args --squash"
			has_flag=true
			shift
			;;
		--delete-branch)
			args="$args --delete-branch"
			has_flag=true
			shift
			;;
		*)
			echo "unknown-option: $1" >&2
			exit 1
			;;
	esac
done

if [ "$has_flag" = false ]; then
	echo "no-flags: at least one of --auto, --squash, --delete-branch required" >&2
	exit 1
fi

# shellcheck disable=SC2086
gh pr merge $args 2> /dev/null || {
	echo "gh-pr-merge-failed: could not apply merge options to $pr_url" >&2
	exit 3
}

printf '%s\n' "$pr_url"
exit 0
