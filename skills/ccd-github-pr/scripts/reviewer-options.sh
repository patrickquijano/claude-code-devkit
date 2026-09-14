#!/bin/sh
# Ranked GitHub reviewer/assignee candidates for an AskUserQuestion option set.
#
# Output, tab separated, best candidate first:
#   <handle>  <name|->  user|team  codeowner|-  recent-committer|-
#
# Ranking: CODEOWNERS matches who also committed on this branch first, then
# other CODEOWNERS entries, then other recent committers, then everyone else
# assignable; ties broken by handle. Take the first four lines for the option
# set. `team` rows are `org/team` handles from CODEOWNERS — `gh pr create
# --reviewer org/team` accepts them, but `--assignee` does not.
#
# GitHub exposes no per-collaborator access level to a non-push token
# (repos/:owner/:repo/collaborators is 403 without push access), so CODEOWNERS
# stands in as the authority signal. That is the better signal anyway: it is the
# repo's own declaration of who reviews which paths.
#
# Read-only. Exit 1: gh missing, not authenticated, or the repo query failed.
# Exit 2: jq missing. Exit 0 otherwise, including an empty listing.
set -u

if ! command -v gh > /dev/null 2>&1; then
	echo "gh-missing: install gh (brew install gh), then gh auth login" >&2
	exit 1
fi
if ! command -v jq > /dev/null 2>&1; then
	echo "jq-missing: install jq, or name the reviewers directly" >&2
	exit 2
fi
if ! gh auth status > /dev/null 2>&1; then
	echo "gh-unauthenticated: run gh auth login" >&2
	exit 1
fi

tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT INT TERM

# assignableUsers is the right source: it resolves for a read-only token, which
# repos/:owner/:repo/collaborators does not. Fields are login, name, id.
if ! gh repo view --json assignableUsers > "$tmpdir/repo.json" 2> "$tmpdir/err"; then
	err=$(tr '\n' ' ' < "$tmpdir/err") || err="(stderr unreadable)"
	echo "gh-repo-view-failed: $err" >&2
	exit 1
fi

# The GraphQL connection behind assignableUsers is a single page, so a very
# large org can be cut off upstream. Cap locally too, and say so — a silent cap
# would misrepresent how much of the repo was considered.
MAX_USERS=500

jq -r '.assignableUsers[] | [.login, (.name // "-")] | @tsv' \
	< "$tmpdir/repo.json" > "$tmpdir/users.all" 2> /dev/null || : > "$tmpdir/users.all"
total=$(wc -l < "$tmpdir/users.all" | tr -d ' ')
head -n "$MAX_USERS" "$tmpdir/users.all" > "$tmpdir/users"
if [ "$total" -gt "$MAX_USERS" ]; then
	echo "truncated: ranked the first $MAX_USERS of $total assignable users" >&2
fi

# CODEOWNERS, from the three paths GitHub honors, first match wins.
: > "$tmpdir/owners"
for p in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
	if [ -f "$p" ]; then
		# Drop comments and the leading path pattern, keep @handles only.
		sed 's/#.*//' "$p" | awk 'NF > 1 { for (i = 2; i <= NF; i++) print $i }' \
			| grep '^@' | sed 's/^@//' | sort -u > "$tmpdir/owners"
		echo "codeowners: $p" >&2
		break
	fi
done

# Commit author logins are not in git history, so match on email local part and
# on display name — the same two signals a GitHub handle usually echoes.
: > "$tmpdir/committers"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	git log -n 200 --format='%ae%n%an' 2> /dev/null \
		| tr '[:upper:]' '[:lower:]' | sort -u > "$tmpdir/committers"
fi

# Teams cannot appear in assignableUsers, so emit CODEOWNERS teams as their own
# rows. They are never recent committers.
grep '/' "$tmpdir/owners" 2> /dev/null | sort -u \
	| awk -F'\t' '{ printf "1\t%s\t-\tteam\tcodeowner\t-\n", $1 }' > "$tmpdir/teams"

awk -F'\t' -v of="$tmpdir/owners" -v cf="$tmpdir/committers" '
	BEGIN {
		while ((getline line < of) > 0) if (line !~ /\//) own[tolower(line)] = 1
		while ((getline line < cf) > 0) seen[line] = 1
	}
	{
		login = tolower($1)
		name = tolower($2)
		isown = (login in own) ? 1 : 0
		hit = (login in seen || name in seen) ? 1 : 0
		if (!hit) {
			for (s in seen) {
				local = s
				sub(/@.*/, "", local)
				if (local == login) { hit = 1; break }
			}
		}
		# Sort key: codeowner+committer (0), codeowner (1), committer (2), rest (3).
		if (isown && hit) rank = 0
		else if (isown) rank = 1
		else if (hit) rank = 2
		else rank = 3
		printf "%d\t%s\t%s\tuser\t%s\t%s\n", rank, $1, $2,
			(isown ? "codeowner" : "-"), (hit ? "recent-committer" : "-")
	}
' "$tmpdir/users" > "$tmpdir/ranked"

cat "$tmpdir/ranked" "$tmpdir/teams" \
	| sort -t'	' -k1,1 -k2,2 \
	| cut -f2-
