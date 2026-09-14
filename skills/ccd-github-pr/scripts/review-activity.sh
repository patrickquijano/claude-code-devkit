#!/bin/sh
# Check whether a GitHub pull request carries review activity.
#
# Usage: sh review-activity.sh <pr-number>
#
# Review activity means a submitted review, an approval or change request,
# or a comment thread attached to a line of the diff. A plain conversation
# comment on the pull request is NOT review activity, and neither is anything
# a bot posted: neither is anchored to a commit, so neither is broken by a
# branch rewrite.
#
# Output (to stdout): one line:
#   has-activity    - review activity present; do not rebase
#   no-activity     - no review activity; safe to rebase
#
# Exit codes:
#   0 - check completed, output on stdout
#   1 - gh missing, unauthenticated, or API call failed
set -eu

if [ $# -ne 1 ]; then
	echo "usage: review-activity.sh <pr-number>" >&2
	exit 1
fi

pr_number=$1

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 1
fi

tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT INT TERM

# Fetch reviews and review decision
if ! gh pr view "$pr_number" --json reviews,reviewDecision,latestReviews \
	> "$tmpdir/reviews.json" 2> "$tmpdir/err"; then
	err=$(tr '\n' ' ' < "$tmpdir/err") || err="(stderr unreadable)"
	echo "gh-pr-view-failed: $err" >&2
	exit 1
fi

# Count submitted reviews (approvals, changes requested, commented reviews)
review_count=$(jq '[.reviews[] | select(.state != "PENDING")] | length' \
	< "$tmpdir/reviews.json" 2> /dev/null) || review_count=0

# Check review decision (APPROVED, CHANGES_REQUESTED, etc.)
review_decision=$(jq -r '.reviewDecision // "NONE"' \
	< "$tmpdir/reviews.json" 2> /dev/null) || review_decision="NONE"

# Fetch inline review comments (comments on diff lines)
owner_repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2> /dev/null) || {
	echo "gh-repo-view-failed: could not determine owner/repo" >&2
	exit 1
}

if ! gh api "repos/$owner_repo/pulls/$pr_number/comments" \
	> "$tmpdir/comments.json" 2> "$tmpdir/err2"; then
	err=$(tr '\n' ' ' < "$tmpdir/err2") || err="(stderr unreadable)"
	echo "gh-api-comments-failed: $err" >&2
	exit 1
fi

comment_count=$(jq 'length' < "$tmpdir/comments.json" 2> /dev/null) || comment_count=0

# Determine result
if [ "$review_count" -gt 0 ] || [ "$comment_count" -gt 0 ] \
	|| [ "$review_decision" != "NONE" ] && [ "$review_decision" != "null" ]; then
	echo "has-activity"
else
	echo "no-activity"
fi
