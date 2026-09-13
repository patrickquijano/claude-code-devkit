#!/bin/sh
# permission-check.sh — Read-only permission probe via gh/glab API, cache result, report verdict
# Usage: sh permission-check.sh <forge> <owner> <repo>
# Output: key=value lines for permission, verdict
set -e

FORGE="$1"
OWNER="$2"
REPO="$3"

if [ -z "$FORGE" ] || [ -z "$OWNER" ] || [ -z "$REPO" ]; then
	echo "verdict=error"
	echo "reason=usage: permission-check.sh <forge> <owner> <repo>"
	exit 1
fi

case "$FORGE" in
	github)
		CLI="gh"
		USER="$($CLI api user --jq '.login' 2> /dev/null)" || USER=""
		if [ -z "$USER" ]; then
			echo "permission=unknown"
			echo "verdict=skipped:permission-unknown"
			echo "reason=could not determine authenticated user"
			exit 0
		fi
		PERM="$($CLI api "repos/$OWNER/$REPO/collaborators/$USER/permission" --jq '.permission' 2> /dev/null)" || PERM=""
		case "$PERM" in
			admin | write)
				echo "permission=$PERM"
				echo "verdict=proceed"
				;;
			read | none)
				echo "permission=$PERM"
				echo "verdict=skipped:no-permission"
				echo "reason=user $USER has $PERM access"
				;;
			*)
				echo "permission=unknown"
				echo "verdict=skipped:permission-unknown"
				echo "reason=unexpected permission value: $PERM"
				;;
		esac
		;;
	gitlab)
		CLI="glab"
		USER="$($CLI api user --jq '.username' 2> /dev/null)" || USER=""
		if [ -z "$USER" ]; then
			echo "permission=unknown"
			echo "verdict=skipped:permission-unknown"
			echo "reason=could not determine authenticated user"
			exit 0
		fi
		PROJECT_ID="$($CLI api projects --jq ".[] | select(.path_with_namespace==\"$OWNER/$REPO\") | .id" 2> /dev/null)" || PROJECT_ID=""
		if [ -z "$PROJECT_ID" ]; then
			echo "permission=unknown"
			echo "verdict=skipped:permission-unknown"
			echo "reason=could not resolve project ID for $OWNER/$REPO"
			exit 0
		fi
		ACCESS="$($CLI api "projects/$PROJECT_ID/members/all/$USER" --jq '.access_level' 2> /dev/null)" || ACCESS=""
		# GitLab access levels: 10=Guest, 20=Reporter, 30=Developer, 40=Maintainer, 50=Owner
		case "$ACCESS" in
			30 | 40 | 50)
				echo "permission=write"
				echo "verdict=proceed"
				;;
			10 | 20)
				echo "permission=read"
				echo "verdict=skipped:no-permission"
				echo "reason=user $USER has access level $ACCESS"
				;;
			*)
				echo "permission=unknown"
				echo "verdict=skipped:permission-unknown"
				echo "reason=unexpected access level: $ACCESS"
				;;
		esac
		;;
	*)
		echo "verdict=error"
		echo "reason=unsupported forge: $FORGE"
		exit 1
		;;
esac
