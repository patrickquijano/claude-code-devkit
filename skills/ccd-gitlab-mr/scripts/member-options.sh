#!/bin/sh
# Ranked GitLab project members for an AskUserQuestion option set.
#
# Output, tab separated, best candidate first:
#   <username>  <name>  <access_level>  recent-committer|-
#
# Ranking: members who authored a commit on the current branch in the last 200
# commits come first (they already know this code), then descending access
# level, then username. Take the first four lines for the option set.
#
# Read-only. Exit 1: glab missing or not authenticated. Exit 2: jq missing.
# Exit 0 otherwise, including an empty listing when the project has no members
# the token can see.
set -u

if ! command -v glab > /dev/null 2>&1; then
	echo "glab-missing: install glab, or fall back to the GitLab MCP server" >&2
	exit 1
fi
if ! command -v jq > /dev/null 2>&1; then
	echo "jq-missing: install jq, or read members with the GitLab MCP server" >&2
	exit 2
fi

tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT INT TERM

# members/all includes members inherited from parent groups, which runs to
# thousands on a large group. Only the top four ever reach the question, so cap
# the listing — and say so on stderr, since a silent cap would misrepresent how
# much of the project was considered.
MAX_MEMBERS=500

if ! glab api projects/:id/members/all --paginate --per-page 100 \
	--output ndjson > "$tmpdir/all" 2> "$tmpdir/err"; then
	err=$(tr '\n' ' ' < "$tmpdir/err") || err="(stderr unreadable)"
	echo "glab-api-failed: $err" >&2
	exit 1
fi

total=$(wc -l < "$tmpdir/all" | tr -d ' ')
head -n "$MAX_MEMBERS" "$tmpdir/all" > "$tmpdir/members"
if [ "$total" -gt "$MAX_MEMBERS" ]; then
	echo "truncated: ranked the first $MAX_MEMBERS of $total members" >&2
fi

# Commit author emails and names on the current branch, used as the recency
# signal. Absent outside a git repo, which only costs ranking quality.
: > "$tmpdir/committers"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	git log -n 200 --format='%ae%n%an' 2> /dev/null \
		| tr '[:upper:]' '[:lower:]' | sort -u > "$tmpdir/committers"
fi

jq -r '[.username, .name, (.access_level|tostring)] | @tsv' \
	< "$tmpdir/members" \
	| awk -F'\t' -v cf="$tmpdir/committers" '
		BEGIN {
			while ((getline line < cf) > 0) seen[line] = 1
		}
		{
			user = tolower($1)
			name = tolower($2)
			# Match on username, on the display name, or on the local part of a
			# commit email (jane.doe@corp -> jane.doe).
			hit = 0
			if (user in seen || name in seen) hit = 1
			if (!hit) {
				for (s in seen) {
					local = s
					sub(/@.*/, "", local)
					if (local == user) { hit = 1; break }
				}
			}
			# Sort key: committers first (0), then access level descending.
			printf "%d\t%09d\t%s\t%s\t%s\t%s\n",
				(hit ? 0 : 1), (999999999 - $3), $1, $2, $3,
				(hit ? "recent-committer" : "-")
		}
	' \
	| sort -t'	' -k1,1 -k2,2 -k3,3 \
	| cut -f3-
