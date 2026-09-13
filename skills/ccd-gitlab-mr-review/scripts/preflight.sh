#!/bin/sh
# preflight.sh — Environment validation and MR detection for ccd-gitlab-mr-review
# POSIX sh, fail fast. Outputs key-value pairs on stdout; errors to stderr.
set -e

# 1. Check git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "Not inside a git repository" >&2
	exit 1
fi

# 2. Check glab availability
if ! command -v glab > /dev/null 2>&1; then
	echo "glab CLI not found. Install it: https://gitlab.com/gitlab-org/cli" >&2
	exit 1
fi

# 3. Check glab authentication
if ! glab auth status > /dev/null 2>&1; then
	echo "glab not authenticated. Run: glab auth login" >&2
	exit 1
fi

# 4. Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "HEAD" ]; then
	echo "Detached HEAD state; cannot determine source branch" >&2
	exit 1
fi

# 5. Find open MR for current branch
MR_JSON=$(glab mr list --source-branch "$CURRENT_BRANCH" --output json 2> /dev/null || true)
if [ -z "$MR_JSON" ] || [ "$MR_JSON" = "[]" ] || [ "$MR_JSON" = "null" ]; then
	echo "No open merge request for branch $CURRENT_BRANCH" >&2
	exit 1
fi

# Extract first matching MR (should be exactly one for this branch)
MR_IID=$(printf '%s' "$MR_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['iid'])" 2> /dev/null || true)
if [ -z "$MR_IID" ]; then
	echo "Failed to parse MR IID from glab output" >&2
	exit 1
fi

# 6. Get full MR details
MR_VIEW=$(glab mr view "$MR_IID" --output json 2> /dev/null)
MR_TITLE=$(printf '%s' "$MR_VIEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))")
MR_STATE=$(printf '%s' "$MR_VIEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('state',''))")
MR_SOURCE=$(printf '%s' "$MR_VIEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sourceBranch',''))")
MR_TARGET=$(printf '%s' "$MR_VIEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('targetBranch',''))")
WEB_URL=$(printf '%s' "$MR_VIEW" | python3 -c "import sys,json; print(json.load(sys.stdin).get('webUrl',''))")

# Validate state
if [ "$MR_STATE" != "opened" ]; then
	echo "MR !$MR_IID is $MR_STATE, not opened. Stopping." >&2
	exit 1
fi

# 7. Get current user
CURRENT_USER=$(glab api user --output json 2> /dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('username',''))")
if [ -z "$CURRENT_USER" ]; then
	echo "Failed to resolve current GitLab user" >&2
	exit 1
fi

# 8. Check if current user is reviewer
IS_REVIEWER=$(printf '%s' "$MR_VIEW" | python3 -c "
import sys, json
d = json.load(sys.stdin)
reviewers = d.get('reviewers', []) or []
user = '$CURRENT_USER'
print('true' if any(r.get('username') == user for r in reviewers) else 'false')
")

# Output key-value pairs
echo "MR_IID=$MR_IID"
echo "MR_TITLE=$MR_TITLE"
echo "MR_STATE=$MR_STATE"
echo "MR_SOURCE_BRANCH=$MR_SOURCE"
echo "MR_TARGET_BRANCH=$MR_TARGET"
echo "CURRENT_USER=$CURRENT_USER"
echo "IS_REVIEWER=$IS_REVIEWER"
echo "WEB_URL=$WEB_URL"
