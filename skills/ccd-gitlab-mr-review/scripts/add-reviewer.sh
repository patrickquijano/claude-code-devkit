#!/bin/sh
# add-reviewer.sh — Add current user as reviewer without removing existing reviewers
# Usage: add-reviewer.sh <mr-iid> <username>
# POSIX sh, fail fast. Always uses +<username> prefix per research R-001 caveat.
set -e

if [ $# -ne 2 ]; then
	echo "Usage: add-reviewer.sh <mr-iid> <username>" >&2
	exit 1
fi

MR_IID="$1"
USERNAME="$2"

# Verify current reviewer list before modifying
CURRENT_REVIEWERS=$(glab mr view "$MR_IID" --output json 2> /dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
reviewers = d.get('reviewers', []) or []
print(','.join(r.get('username','') for r in reviewers))
" 2> /dev/null || true)

# Check if user is already a reviewer
case ",$CURRENT_REVIEWERS," in
	*",$USERNAME,"*)
		echo "User $USERNAME is already a reviewer on MR !$MR_IID"
		exit 0
		;;
esac

# Add reviewer using + prefix to append without replacing
UPDATE_OUTPUT=$(glab mr update "$MR_IID" --reviewer "+$USERNAME" --output json 2>&1) || {
	echo "Failed to add reviewer: $UPDATE_OUTPUT" >&2
	exit 1
}

# Verify the addition took effect
UPDATED_REVIEWERS=$(printf '%s' "$UPDATE_OUTPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
reviewers = d.get('reviewers', []) or []
names = [r.get('username','') for r in reviewers]
print(','.join(names))
" 2> /dev/null || true)

case ",$UPDATED_REVIEWERS," in
	*",$USERNAME,"*)
		echo "Added $USERNAME as reviewer on MR !$MR_IID"
		;;
	*)
		echo "Reviewer addition command succeeded but $USERNAME not found in updated list" >&2
		exit 1
		;;
esac
