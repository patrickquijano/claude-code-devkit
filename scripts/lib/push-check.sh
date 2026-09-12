#!/bin/sh
# The outgoing-signature check, reached through .husky/pre-push.
# Contract: specs/008-commit-hooks/contracts/pre-push-hook.md
#
# THIS REWRITES NOTHING. A signature is part of the commit object, so producing
# one changes the commit's identifier -- and git has already computed the ref
# updates it is about to send by the time this hook runs, so a rewrite here would
# push the pre-rewrite objects and move the contributor's branch out from under
# them. Signing happens at commit time, arranged by scripts/install-hooks.sh.
# research.md section 7.
#
# Sourced, not executed. POSIX sh only.

PP_ZERO='0000000000000000000000000000000000000000'
PP_EX_REFUSED=1
PP_EX_USAGE=2

pp_fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$PP_EX_USAGE"
}

# push_check_main [REMOTE_NAME [REMOTE_URL]] -- ref-update lines on stdin.
push_check_main() {
	_pp_remote=${1:-origin}

	_pp_dir=$(mktemp -d)
	trap 'rm -rf "$_pp_dir"' EXIT INT TERM
	: > "$_pp_dir/report"

	_pp_offenders=0

	# Read git's ref-update lines in the MAIN shell, not in a pipeline: a
	# pipeline would put this loop in a subshell and the count would come back
	# zero however many bad commits it found (Principle II).
	while read -r _pp_local_ref _pp_local_oid _pp_remote_ref _pp_remote_oid; do
		[ -n "${_pp_local_ref:-}" ] || continue

		# A deletion adds nothing, so there is nothing to examine.
		if [ "$_pp_local_oid" = "$PP_ZERO" ]; then
			continue
		fi

		_pp_st=0
		if [ "$_pp_remote_oid" = "$PP_ZERO" ]; then
			# A ref the remote does not have yet. Limiting to commits not
			# already reachable from that remote keeps the check off history
			# pushed before this rule existed -- FR-006 governs the outgoing
			# range, not the repository.
			git log --format='%G? %h %s' "$_pp_local_oid" \
				--not --remotes="$_pp_remote" > "$_pp_dir/range" 2> /dev/null || _pp_st=$?
		else
			git log --format='%G? %h %s' "$_pp_remote_oid..$_pp_local_oid" \
				> "$_pp_dir/range" 2> /dev/null || _pp_st=$?
		fi

		if [ "$_pp_st" -ne 0 ]; then
			pp_fatal "could not compute the outgoing range for $_pp_remote_ref ($_pp_remote_oid..$_pp_local_oid). Nothing was judged."
		fi

		# A nested read from a FILE, so it does not consume the ref-update
		# lines still queued on this hook's own stdin.
		while read -r _pp_gstatus _pp_gshort _pp_gsubject; do
			[ -n "${_pp_gstatus:-}" ] || continue
			_pp_reason=''
			case "$_pp_gstatus" in
				N)
					_pp_reason='no signature'
					;;
				B)
					_pp_reason='bad signature'
					;;
				G | U | X | Y | R | E)
					# E is the ordinary status of a correctly signed commit
					# when gpg.ssh.allowedSignersFile is unset, which is the
					# default. Refusing it would push contributors who have
					# done nothing wrong toward --no-verify as routine.
					;;
				*) ;;
			esac
			if [ -n "$_pp_reason" ]; then
				_pp_offenders=$((_pp_offenders + 1))
				printf '  %s  %s  (%s)\n' "$_pp_gshort" "$_pp_gsubject" "$_pp_reason" >> "$_pp_dir/report"
			fi
		done < "$_pp_dir/range"
	done

	if [ "$_pp_offenders" -eq 0 ]; then
		exit 0
	fi

	# Every offender across every ref update, then one exit. Stopping at the
	# first would satisfy the letter of failing fast and break FR-007; FR-014
	# records that enumerating within one check is not a departure from
	# Principle II.
	{
		printf '%s: push refused -- %s commit(s) in the outgoing range are not acceptably signed:\n\n' \
			"$PROG" "$_pp_offenders"
		cat "$_pp_dir/report"
		printf '\n  Only an absent or failing signature refuses a push. A signature that is\n'
		printf '  present but unverifiable is accepted.\n'
		printf '\n  To sign the most recent commit:      git commit --amend --no-edit -S\n'
		printf '  To sign a run of commits:            git rebase --exec "git commit --amend --no-edit -S" <base>\n'
		printf '  To arrange signing from now on:      sh scripts/install-hooks.sh\n'
		printf '\n  To bypass this check: git push --no-verify -- which leaves unsigned work\n'
		printf '  on the remote, where nobody can attribute it.\n'
	} >&2

	exit "$PP_EX_REFUSED"
}
