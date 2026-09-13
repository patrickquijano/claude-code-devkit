#!/bin/sh
# collect-context.sh — Gather diff, comments, discussions, approvals, CI status, mergeability
# Usage: sh collect-context.sh <forge> <cr_id>
# Output: key=value lines for context fields per data-model.md ChangeRequest entity
set -e

FORGE="$1"
CR_ID="$2"

if [ -z "$FORGE" ] || [ -z "$CR_ID" ]; then
	echo "verdict=error"
	echo "reason=usage: collect-context.sh <forge> <cr_id>"
	exit 1
fi

case "$FORGE" in
	github)
		CLI="gh"
		# Diff
		DIFF="$($CLI pr diff "$CR_ID" 2> /dev/null)" || DIFF=""
		DIFF_LINES="$(echo "$DIFF" | wc -l | tr -d ' ' || true)"
		echo "diff_lines=$DIFF_LINES"

		# Comments
		COMMENTS="$($CLI api "repos/{owner}/{repo}/pulls/${CR_ID}/comments" --paginate 2> /dev/null)" || COMMENTS="[]"
		COMMENTS_COUNT="$(echo "$COMMENTS" | grep -c '"id"' 2> /dev/null || echo 0)"
		echo "comments_count=$COMMENTS_COUNT"

		# Reviews (approvals)
		REVIEWS="$($CLI api "repos/{owner}/{repo}/pulls/${CR_ID}/reviews" --paginate 2> /dev/null)" || REVIEWS="[]"
		APPROVALS="$(echo "$REVIEWS" | grep -i '"state":"APPROVED"' | grep -o '"user":{"login":"[^"]*"' | sed 's/.*"login":"//;s/"//' | sort -u | tr '\n' ',' | sed 's/,$//')"
		echo "approvals=$APPROVALS"

		# CI status rollup
		STATUS="$($CLI pr view "$CR_ID" --json statusCheckRollup 2> /dev/null)" || STATUS="{}"
		if echo "$STATUS" | grep -q '"state":"FAILURE"'; then
			echo "ci_status=fail"
		elif echo "$STATUS" | grep -q '"state":"PENDING"'; then
			echo "ci_status=pending"
		else
			echo "ci_status=pass"
		fi

		# Mergeable
		MERGEABLE="$($CLI pr view "$CR_ID" --json mergeable 2> /dev/null | grep -o '"mergeable":"[^"]*"' | cut -d'"' -f4)" || MERGEABLE="unknown"
		echo "mergeable=${MERGEABLE:-unknown}"

		# Author
		AUTHOR="$($CLI pr view "$CR_ID" --json author 2> /dev/null | grep -o '"login":"[^"]*"' | head -1 | cut -d'"' -f4)" || AUTHOR=""
		echo "author=$AUTHOR"
		;;
	gitlab)
		CLI="glab"
		# Diff
		DIFF="$($CLI mr diff "$CR_ID" 2> /dev/null)" || DIFF=""
		GL_DIFF_LINES="$(echo "$DIFF" | wc -l | tr -d ' ' || true)"
		echo "diff_lines=$GL_DIFF_LINES"

		# Comments via notes
		NOTES="$($CLI mr note list "$CR_ID" 2> /dev/null)" || NOTES=""
		GL_COMMENTS_COUNT="$(echo "$NOTES" | grep -c '^[0-9]' 2> /dev/null || echo 0)"
		echo "comments_count=$GL_COMMENTS_COUNT"

		# Approvals
		APPROVALS="$($CLI api "projects/{id}/merge_requests/${CR_ID}/approvals" 2> /dev/null | grep -o '"username":"[^"]*"' | sed 's/.*"username":"//;s/"//' | tr '\n' ',' | sed 's/,$//')" || APPROVALS=""
		echo "approvals=$APPROVALS"

		# CI status
		PIPELINE="$($CLI mr view "$CR_ID" 2> /dev/null | grep -i 'pipeline' | head -1)" || PIPELINE=""
		if echo "$PIPELINE" | grep -qi 'failed'; then
			echo "ci_status=fail"
		elif echo "$PIPELINE" | grep -qi 'running\|pending'; then
			echo "ci_status=pending"
		else
			echo "ci_status=pass"
		fi

		# Mergeable
		MR_VIEW="$($CLI mr view "$CR_ID" 2> /dev/null)" || MR_VIEW=""
		if echo "$MR_VIEW" | grep -qi 'mergeable'; then
			echo "mergeable=yes"
		else
			echo "mergeable=unknown"
		fi

		# Author
		AUTHOR="$(echo "$MR_VIEW" | grep -i 'author' | head -1 | sed 's/.*Author: *//;s/ *$//')" || AUTHOR=""
		echo "author=$AUTHOR"
		;;
	*)
		echo "verdict=error"
		echo "reason=unsupported forge: $FORGE"
		exit 1
		;;
esac

echo "verdict=ok"
