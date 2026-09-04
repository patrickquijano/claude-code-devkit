#!/bin/sh
# Workspace state for a conflict-resolution run: is the tool there, is this a
# repository, what operation is in progress, what is conflicted, and where does
# the branch stand against its upstream.
#
# Output, tab separated, one record per line:
#
#	git			available|absent
#	repo			yes|no
#	operation		none|merge|rebase|cherry-pick|revert
#	conflicts		<integer>
#	remote			reachable|unreachable|none-configured|not-attempted
#	upstream		up-to-date|behind|ahead|diverged|no-upstream
#	ahead			<integer>
#	behind			<integer>
#	staged-unrelated	<integer>
#	rerere			enabled|disabled
#
# Read-only with respect to the working tree and the index. The single write of
# any kind is `git fetch`, which touches only remote-tracking refs.
#
# Exit 0: probe completed; `git available` and `repo yes` both hold.
# Exit 1: not a git repository.
# Exit 2: git is not available -- nothing else was attempted.
# Exit 3: the remote update failed; every other key is still printed from
#         on-disk state so the caller can offer the continue-anyway choice.
#
# OPERATION DETECTION. The pseudorefs are probed in the order git itself
# documents for `git log --merge`: MERGE_HEAD, CHERRY_PICK_HEAD, REVERT_HEAD,
# REBASE_HEAD. The rebase state directories are deliberately NOT consulted --
# `.git/rebase-merge/` and `.git/rebase-apply/` appear in no git manual page, so
# they could change without notice, while REBASE_HEAD is documented.
#
# `operation` and `conflicts` are INDEPENDENT and must stay so. A conflicted
# tree can report `operation none`: `git merge --squash` does not record
# MERGE_HEAD, so a conflicted squash merge has unmerged index entries and no
# marker at all. Inferring either field from the other is the bug this
# separation exists to prevent.

set -u

emit() {
	printf '%s\t%s\n' "$1" "$2"
}

# Exit 2 comes first and alone. FR-009 requires the tool's absence to be
# established before the working tree is touched, read, or reasoned about.
if ! command -v git > /dev/null 2>&1; then
	echo "no-git: git is not on PATH; install git or add it to PATH" >&2
	exit 2
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the repository with the conflict" >&2
	exit 1
fi

emit git available
emit repo yes

operation=none
if git rev-parse --verify --quiet MERGE_HEAD > /dev/null 2>&1; then
	operation=merge
elif git rev-parse --verify --quiet CHERRY_PICK_HEAD > /dev/null 2>&1; then
	operation=cherry-pick
elif git rev-parse --verify --quiet REVERT_HEAD > /dev/null 2>&1; then
	operation=revert
elif git rev-parse --verify --quiet REBASE_HEAD > /dev/null 2>&1; then
	operation=rebase
fi
emit operation "$operation"

# Unmerged paths, counted once each. `ls-files -u` prints one line per stage, so
# the path column is deduplicated before counting.
conflicts=$(git ls-files -u -- | cut -f2 | sort -u | grep -c . || true)
emit conflicts "$conflicts"

# The remote update. A failure here is a branch, not a fatal error: FR-020
# requires reporting it and letting the user decide whether to continue against
# what is already on disk.
remote_status=not-attempted
fetch_failed=0
remotes=$(git remote || true)
if [ -z "$remotes" ]; then
	remote_status=none-configured
else
	if git fetch --quiet 2> /dev/null; then
		remote_status=reachable
	else
		remote_status=unreachable
		fetch_failed=1
		echo "remote-unreachable: could not update from the remote; reported state is from disk" >&2
	fi
fi
emit remote "$remote_status"

# Upstream relation. Absent upstream is a normal state, not an error.
ahead=0
behind=0
upstream=no-upstream
if git rev-parse --verify --quiet '@{upstream}' > /dev/null 2>&1; then
	counts=$(git rev-list --left-right --count '@{upstream}...HEAD' 2> /dev/null || echo '0	0')
	behind=$(printf '%s' "$counts" | cut -f1)
	ahead=$(printf '%s' "$counts" | cut -f2)
	if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
		upstream=up-to-date
	elif [ "$ahead" -eq 0 ]; then
		upstream=behind
	elif [ "$behind" -eq 0 ]; then
		upstream=ahead
	else
		upstream=diverged
	fi
fi
emit upstream "$upstream"
emit ahead "$ahead"
emit behind "$behind"

# Staged paths that are not unmerged. Captured HERE, before any resolution, so
# that the guarantee "unrelated work is still uncommitted afterwards" has
# something to be checked against. Capturing it later would make it
# unverifiable.
#
# During a conflicted merge git has already staged the cleanly-merged paths
# itself, and those are part of the operation rather than unrelated work -- so
# this count is informational for the caller to interpret, and
# conflict-conclude.sh does the authoritative comparison against the conflict
# set at the moment of concluding.
staged_unrelated=0
if [ "$operation" = none ]; then
	staged_unrelated=$(git diff --cached --name-only -- | sort -u | grep -c . || true)
fi
emit staged-unrelated "$staged_unrelated"

# rerere is read, never enabled. Enabling it would be writing configuration the
# user did not ask for.
rerere=disabled
rerere_config=$(git config --get rerere.enabled 2> /dev/null || echo false)
rr_cache=$(git rev-parse --git-path rr-cache || true)
if [ "$rerere_config" = true ]; then
	rerere=enabled
elif [ -n "$rr_cache" ] && [ -d "$rr_cache" ]; then
	rerere=enabled
fi
emit rerere "$rerere"

if [ "$fetch_failed" -eq 1 ]; then
	exit 3
fi
exit 0
