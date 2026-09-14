#!/bin/sh
# Rebase the current branch onto a base branch and force-push the result.
#
# Usage: sh rebase-branch.sh <base-branch> [upstream-remote]
#
# Arguments:
#   base-branch      - the branch to rebase onto (e.g. main)
#   upstream-remote  - optional; the remote to fetch from (default: origin).
#                      Use "upstream" when rebasing a fork's branch onto the
#                      parent repository's base branch.
#
# Behavior:
#   1. Fetches the base branch from the specified remote.
#   2. Rebases the current HEAD onto <remote>/<base-branch>.
#   3. On success, force-pushes with lease to origin.
#   4. On conflict, exits non-zero without resolving; the caller decides.
#
# Output (to stdout):
#   REBASE|clean     - rebase succeeded, force-push confirmed
#   REBASE|conflict  - rebase stopped on conflict; working tree left as-is
#
# Exit codes:
#   0 - rebase clean and pushed
#   1 - usage error or missing argument
#   2 - fetch failed
#   3 - rebase conflict (caller must resolve or abort)
#   4 - force-push failed
set -eu

if [ $# -lt 1 ]; then
	echo "usage: rebase-branch.sh <base-branch> [upstream-remote]" >&2
	exit 1
fi

base=$1
remote=${2:-origin}
head=$(git rev-parse --abbrev-ref HEAD) || {
	echo "detached-head: cannot rebase without a checked-out branch" >&2
	exit 1
}

if ! git fetch "$remote" "$base" 2> /dev/null; then
	echo "fetch-failed: could not fetch $base from $remote" >&2
	exit 2
fi

if ! git rebase "$remote/$base" 2> /dev/null; then
	echo "REBASE|conflict"
	exit 3
fi

if ! git push --force-with-lease origin "$head" 2> /dev/null; then
	echo "push-failed: force-push of $head to origin failed" >&2
	exit 4
fi

echo "REBASE|clean"
exit 0
