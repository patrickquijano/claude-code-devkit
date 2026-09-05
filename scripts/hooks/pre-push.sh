#!/bin/sh
# The outgoing-signature check.
#
# Invoked by git through .husky/pre-push, and invoked directly by
# scripts/selftest.sh with synthesised stdin. Contract:
# specs/008-commit-hooks/contracts/pre-push-hook.md
#
# THIS SCRIPT REWRITES NOTHING. No amend, no rebase, no re-signing. A signature
# is part of the commit object, so producing one changes the commit's
# identifier -- and git has already computed the ref updates it is about to send
# by the time this hook runs, so a rewrite here would push the pre-rewrite
# objects and move the contributor's branch out from under them. There is no
# correct version of "sign it during the push"; signing happens at commit time,
# arranged by scripts/install-hooks.sh. See research.md section 7.
set -eu

PROG=$(basename "$0")
ZERO='0000000000000000000000000000000000000000'

EX_REFUSED=1
EX_USAGE=2

REMOTE_NAME=${1:-origin}

fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$EX_USAGE"
}

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT INT TERM
RANGE_OUT="$WORKDIR/range"
REPORT="$WORKDIR/report"
: > "$REPORT"

OFFENDERS=0

# Reading git's ref-update lines in the MAIN shell, not in a pipeline. A
# pipeline would put this loop in a subshell and OFFENDERS would come back zero
# however many bad commits it found -- a check that always passes, which is
# worse than no check (Principle II).
while read -r local_ref local_oid remote_ref remote_oid; do
	[ -n "${local_ref:-}" ] || continue

	# A deletion. Nothing is being added, so there is nothing to examine.
	if [ "$local_oid" = "$ZERO" ]; then
		continue
	fi

	_st=0
	if [ "$remote_oid" = "$ZERO" ]; then
		# A ref the remote does not have yet. Limiting to commits not
		# already reachable from that remote keeps the check off history
		# that was pushed before this rule existed -- FR-006 governs the
		# outgoing range, not the repository.
		git log --format='%G? %h %s' "$local_oid" \
			--not --remotes="$REMOTE_NAME" > "$RANGE_OUT" 2> /dev/null || _st=$?
	else
		git log --format='%G? %h %s' "$remote_oid..$local_oid" \
			> "$RANGE_OUT" 2> /dev/null || _st=$?
	fi

	if [ "$_st" -ne 0 ]; then
		fatal "could not compute the outgoing range for $remote_ref ($remote_oid..$local_oid). Nothing was judged."
	fi

	# A nested read from a FILE, so it does not consume the ref-update lines
	# still queued on this script's own stdin.
	while read -r gstatus gshort gsubject; do
		[ -n "${gstatus:-}" ] || continue
		_reason=''
		case "$gstatus" in
			N)
				_reason='no signature'
				;;
			B)
				_reason='bad signature'
				;;
			G | U | X | Y | R | E)
				# E is the ordinary status of a correctly signed
				# commit when gpg.ssh.allowedSignersFile is unset,
				# which is the default. Refusing it would block
				# contributors who have done nothing wrong, and push
				# them toward --no-verify as routine.
				;;
			*) ;;
		esac
		if [ -n "$_reason" ]; then
			OFFENDERS=$((OFFENDERS + 1))
			printf '  %s  %s  (%s)\n' "$gshort" "$gsubject" "$_reason" >> "$REPORT"
		fi
	done < "$RANGE_OUT"
done

if [ "$OFFENDERS" -eq 0 ]; then
	exit 0
fi

# Every offender across every ref update, then one exit. Stopping at the first
# would satisfy the letter of failing fast and break FR-007, which requires the
# contributor be told about all of them; FR-014 records that enumerating within
# one check is not a departure from Principle II.
{
	printf '%s: push refused -- %s commit(s) in the outgoing range are not acceptably signed:\n\n' \
		"$PROG" "$OFFENDERS"
	cat "$REPORT"
	printf '\n  Only an absent or failing signature refuses a push. A signature that is\n'
	printf '  present but unverifiable is accepted.\n'
	printf '\n  To sign the most recent commit:      git commit --amend --no-edit -S\n'
	printf '  To sign a run of commits:            git rebase --exec "git commit --amend --no-edit -S" <base>\n'
	printf '  To arrange signing from now on:      sh scripts/install-hooks.sh\n'
	printf '\n  To bypass this check: git push --no-verify -- which leaves unsigned work\n'
	printf '  on the remote, where nobody can attribute it.\n'
} >&2

exit "$EX_REFUSED"
