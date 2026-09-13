#!/bin/sh
# post-comment.sh — Safe comment posting to GitLab MR
# Usage: post-comment.sh <mr-iid> <comment-file-path>
# POSIX sh, fail fast. Uses $(cat) to avoid shell expansion of backticks/$.
set -e

if [ $# -ne 2 ]; then
	echo "Usage: post-comment.sh <mr-iid> <comment-file-path>" >&2
	exit 1
fi

MR_IID="$1"
COMMENT_FILE="$2"

if [ ! -f "$COMMENT_FILE" ]; then
	echo "Comment file not found: $COMMENT_FILE" >&2
	exit 1
fi

if [ ! -s "$COMMENT_FILE" ]; then
	echo "Comment file is empty: $COMMENT_FILE" >&2
	exit 1
fi

# Post comment using -m with file content via $(cat) to avoid shell expansion
NOTE_OUTPUT=$(glab mr note create "$MR_IID" -m "$(cat "$COMMENT_FILE")" --output json 2>&1) || {
	echo "Failed to post comment: $NOTE_OUTPUT" >&2
	exit 1
}

# Extract note ID
NOTE_ID=$(printf '%s' "$NOTE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2> /dev/null || true)

if [ -z "$NOTE_ID" ]; then
	echo "Comment posted but failed to extract note ID" >&2
	exit 1
fi

echo "$NOTE_ID"
