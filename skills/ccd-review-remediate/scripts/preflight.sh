#!/bin/sh
# preflight.sh — Forge detection, CLI auth probe, CR discovery, head_sha capture, dirty-tree check
# Usage: sh preflight.sh
# Output: key=value lines for forge, cli_status, cr_id, head_sha, dirty_tree, verdict
set -e

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
FORGE_DETECT="${PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh"

if [ ! -f "$FORGE_DETECT" ]; then
	echo "verdict=stopped:unsupported-forge"
	echo "reason=forge-detect.sh not found at ${FORGE_DETECT}"
	exit 0
fi

# G1: Forge detection
FORGE_OUTPUT="$(sh "$FORGE_DETECT" 2> /dev/null)" || true
FORGE_VERDICT="$(echo "$FORGE_OUTPUT" | grep '^verdict=' | cut -d= -f2-)"

if [ "$FORGE_VERDICT" != "ready" ]; then
	echo "verdict=stopped:unsupported-forge"
	EVIDENCE="$(echo "$FORGE_OUTPUT" | grep '^evidence=' | cut -d= -f2- || true)"
	echo "reason=$EVIDENCE"
	exit 0
fi

FORGE="$(echo "$FORGE_OUTPUT" | grep '^forge=' | cut -d= -f2-)"
CLI="$(echo "$FORGE_OUTPUT" | grep '^cli=' | cut -d= -f2-)"

echo "forge=$FORGE"

# CLI auth probe
if ! command -v "$CLI" > /dev/null 2>&1; then
	echo "cli_status=missing"
	echo "verdict=stopped:no-cli"
	echo "reason=${CLI} not found on PATH"
	exit 0
fi

case "$FORGE" in
	github) AUTH_CHECK="$CLI auth status --show-token 2>&1" ;;
	gitlab) AUTH_CHECK="$CLI auth status 2>&1" ;;
	*)
		echo "verdict=stopped:unsupported-forge"
		echo "reason=unexpected forge value: $FORGE"
		exit 0
		;;
esac

if eval "$AUTH_CHECK" > /dev/null 2>&1; then
	echo "cli_status=authenticated"
else
	echo "cli_status=unauthenticated"
	echo "verdict=stopped:cli-auth-failed"
	echo "reason=${CLI} authentication failed"
	exit 0
fi

# G3: Dirty tree check
DIRTY_CHECK="$(git status --porcelain 2> /dev/null || true)"
if [ -n "$DIRTY_CHECK" ]; then
	echo "dirty_tree=true"
	echo "verdict=stopped:dirty-tree"
	echo "reason=uncommitted changes in working tree"
	exit 0
fi
echo "dirty_tree=false"

# G2: CR discovery
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
HEAD_SHA="$(git rev-parse HEAD 2> /dev/null)"
echo "head_sha=$HEAD_SHA"

case "$FORGE" in
	github)
		CR_LIST="$($CLI pr list --head "$CURRENT_BRANCH" --json number,title 2> /dev/null)" || CR_LIST="[]"
		CR_COUNT="$(echo "$CR_LIST" | grep -c '"number"' 2> /dev/null || echo 0)"
		;;
	gitlab)
		CR_LIST="$($CLI mr list --source-branch "$CURRENT_BRANCH" 2> /dev/null)" || CR_LIST=""
		CR_COUNT="$(echo "$CR_LIST" | grep -c '^[0-9]' 2> /dev/null || echo 0)"
		;;
	*)
		echo "verdict=stopped:unsupported-forge"
		echo "reason=unexpected forge value: $FORGE"
		exit 0
		;;
esac

if [ "$CR_COUNT" -eq 0 ]; then
	echo "cr_id=none"
	echo "verdict=stopped:no-change-request"
	echo "reason=no open change request for branch $CURRENT_BRANCH"
	exit 0
elif [ "$CR_COUNT" -gt 1 ]; then
	echo "cr_id=ambiguous"
	echo "verdict=stopped:ambiguous-cr"
	echo "reason=multiple open change requests for branch $CURRENT_BRANCH"
	echo "candidates=$CR_LIST"
	exit 0
fi

case "$FORGE" in
	github) CR_ID="$(echo "$CR_LIST" | grep '"number"' | head -1 | sed 's/[^0-9]//g')" ;;
	gitlab) CR_ID="$(echo "$CR_LIST" | grep '^[0-9]' | head -1 | awk '{print $1}')" ;;
	*)
		echo "verdict=stopped:unsupported-forge"
		echo "reason=unexpected forge value: $FORGE"
		exit 0
		;;
esac

echo "cr_id=$CR_ID"
echo "verdict=proceed"
