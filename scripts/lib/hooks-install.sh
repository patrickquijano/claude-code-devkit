#!/bin/sh
# Activates the commit-message and signature checks for this working copy, and
# reports the resulting state.
# Contract: specs/008-commit-hooks/contracts/install-hooks-cli.md
#
# Needs POSIX sh and git. No package manager, no install step -- Principle I,
# which is why this exists rather than `npm install husky`: Husky's own
# activation writes core.hooksPath to .husky/_, which Husky itself gitignores,
# so a fresh clone with no npm install has no hooks at all. research.md §1-3.
#
# Sourced, not executed. POSIX sh only.

IH_EX_FAILED=1
IH_EX_USAGE=2

ih_fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$IH_EX_USAGE"
}

ih_failed() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$IH_EX_FAILED"
}

# ih_report NAME VALUE CHANGED -- CHANGED is `set`, `already set` or
# `not configured`.
ih_report() {
	printf '  %-18s %-24s %s\n' "$1" "$2" "$3"
}

# install_hooks_main [--status]
install_hooks_main() {
	_ih_mode=install
	if [ "$#" -gt 1 ]; then
		ih_fatal "expected at most one argument; got $#. Usage: $PROG [--status]"
	fi
	if [ "$#" -eq 1 ]; then
		case "$1" in
			--status)
				_ih_mode=status
				;;
			*)
				ih_fatal "unknown argument \"$1\". Usage: $PROG [--status]"
				;;
		esac
	fi

	# The target is the repository of the CURRENT directory, not of this file.
	# That is what lets the self-test point it at a fixture, and what makes it
	# correct inside a worktree.
	_ih_root=''
	_ih_root=$(git rev-parse --show-toplevel 2> /dev/null) || _ih_root=''
	[ -n "$_ih_root" ] || ih_failed 'not inside a git working tree, so there is nothing to configure.'
	cd "$_ih_root" || ih_failed "could not enter $_ih_root."

	printf '%s: %s\n' "$PROG" "$_ih_root"

	# DETECT core.hooksPath, never assume. Writing .husky unconditionally breaks
	# a Husky user on their next `npm install`, when husky sets the value back
	# to .husky/_ and the two disagree about which file git actually runs.
	_ih_current=''
	_ih_current=$(git config --local --get core.hooksPath 2> /dev/null) || _ih_current=''

	_ih_wanted='.husky'
	if [ -d '.husky/_' ]; then
		_ih_wanted='.husky/_'
	fi
	if [ "$_ih_current" = '.husky/_' ]; then
		_ih_wanted='.husky/_'
	fi

	if [ "$_ih_mode" = status ]; then
		if [ -n "$_ih_current" ]; then
			ih_report core.hooksPath "$_ih_current" 'already set'
		else
			ih_report core.hooksPath '(unset)' 'not configured'
		fi
	elif [ "$_ih_current" = "$_ih_wanted" ]; then
		ih_report core.hooksPath "$_ih_current" 'already set'
	else
		git config --local core.hooksPath "$_ih_wanted" \
			|| ih_failed "could not write core.hooksPath. Nothing was activated."
		_ih_current=$_ih_wanted
		ih_report core.hooksPath "$_ih_wanted" 'set'
	fi

	# FR-012: commits are signed when they are created, which is what leaves the
	# push check with nothing to refuse under ordinary use.
	_ih_sign=''
	_ih_sign=$(git config --local --get commit.gpgsign 2> /dev/null) || _ih_sign=''

	if [ "$_ih_mode" = status ]; then
		if [ -n "$_ih_sign" ]; then
			ih_report commit.gpgsign "$_ih_sign" 'already set'
		else
			ih_report commit.gpgsign '(unset)' 'not configured'
		fi
	elif [ "$_ih_sign" = true ]; then
		ih_report commit.gpgsign true 'already set'
	else
		git config --local commit.gpgsign true \
			|| ih_failed 'could not write commit.gpgsign.'
		ih_report commit.gpgsign true 'set'
	fi

	# The signing identity is REPORTED and never written. Guessing gpg.format or
	# user.signingkey produces commits signed by the wrong identity, which is
	# worse than no signature: an unsigned commit is visibly unattributed, a
	# wrongly signed one is confidently misattributed. Reporting them absent is
	# not a failure and does not affect the exit status.
	for _ih_setting in gpg.format user.signingkey; do
		_ih_value=''
		_ih_value=$(git config --get "$_ih_setting" 2> /dev/null) || _ih_value=''
		if [ -n "$_ih_value" ]; then
			ih_report "$_ih_setting" "$_ih_value" 'already set'
		else
			ih_report "$_ih_setting" '(unset)' 'not configured'
		fi
	done

	# git silently skips a hook that is not executable, which is the quietest
	# possible way for this whole feature to stop working.
	_ih_present=0
	for _ih_hook in commit-msg pre-push; do
		if [ -f ".husky/$_ih_hook" ]; then
			_ih_present=$((_ih_present + 1))
			if [ "$_ih_mode" != status ] && [ ! -x ".husky/$_ih_hook" ]; then
				chmod +x ".husky/$_ih_hook" || ih_failed "could not make .husky/$_ih_hook executable."
				ih_report ".husky/$_ih_hook" 'executable' 'set'
			elif [ -x ".husky/$_ih_hook" ]; then
				ih_report ".husky/$_ih_hook" 'executable' 'already set'
			else
				ih_report ".husky/$_ih_hook" 'not executable' 'not configured'
			fi
		else
			ih_report ".husky/$_ih_hook" '(missing)' 'not configured'
		fi
	done

	# FR-013: one unambiguous line. A contributor must never have to read a
	# script to find out whether the checks are on.
	_ih_state=inactive
	case "$_ih_current" in
		.husky | .husky/_)
			if [ "$_ih_present" -gt 0 ]; then
				_ih_state=active
			fi
			;;
		*) ;;
	esac

	printf '\n  state: %s\n' "$_ih_state"

	if [ "$_ih_state" = inactive ]; then
		printf '  To activate:   sh scripts/install-hooks.sh   (from the repository root)\n'
		printf '  To deactivate: git config --unset core.hooksPath\n'
	fi

	exit 0
}
