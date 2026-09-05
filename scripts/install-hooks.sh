#!/bin/sh
# Activates the commit-message and signature checks for this working copy, and
# reports the resulting state. Contract:
# specs/008-commit-hooks/contracts/install-hooks-cli.md
#
#   sh scripts/install-hooks.sh            activate, then report
#   sh scripts/install-hooks.sh --status   report only; write nothing
#
# Needs POSIX sh and git. No package manager, no virtual environment, no install
# step -- Principle I, which is the whole reason this script exists rather than
# `npm install husky`. Husky's own activation writes core.hooksPath to
# .husky/_, and .husky/_ is gitignored by Husky itself, so a fresh clone with no
# npm install has no hooks at all. See research.md sections 1-3.
set -eu

PROG=$(basename "$0")

EX_FAILED=1
EX_USAGE=2

fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$EX_USAGE"
}

failed() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$EX_FAILED"
}

MODE=install
if [ "$#" -gt 1 ]; then
	fatal "expected at most one argument; got $#. Usage: $PROG [--status]"
fi
if [ "$#" -eq 1 ]; then
	case "$1" in
		--status)
			MODE=status
			;;
		*)
			fatal "unknown argument \"$1\". Usage: $PROG [--status]"
			;;
	esac
fi

# The target is the repository of the CURRENT directory, not of this script.
# That is what lets the self-test point it at a fixture, and what makes it
# correct inside a worktree. A script that configured its own repository would
# reconfigure this one every time the test ran.
ROOT=''
ROOT=$(git rev-parse --show-toplevel 2> /dev/null) || ROOT=''
[ -n "$ROOT" ] || failed 'not inside a git working tree, so there is nothing to configure.'
cd "$ROOT"

# report NAME VALUE CHANGED -- CHANGED is `set`, `already set` or `not configured`.
report() {
	printf '  %-18s %-24s %s\n' "$1" "$2" "$3"
}

printf '%s: %s\n' "$PROG" "$ROOT"

# --- core.hooksPath ---------------------------------------------------------
#
# DETECT, never assume. Writing .husky unconditionally breaks a Husky user on
# their next `npm install`, when husky sets the value back to .husky/_ and the
# two disagree about which file git actually runs.
CURRENT_PATH=''
CURRENT_PATH=$(git config --local --get core.hooksPath 2> /dev/null) || CURRENT_PATH=''

WANTED_PATH='.husky'
if [ -d '.husky/_' ]; then
	WANTED_PATH='.husky/_'
fi
if [ "$CURRENT_PATH" = '.husky/_' ]; then
	WANTED_PATH='.husky/_'
fi

if [ "$MODE" = status ]; then
	if [ -n "$CURRENT_PATH" ]; then
		report core.hooksPath "$CURRENT_PATH" 'already set'
	else
		report core.hooksPath '(unset)' 'not configured'
	fi
elif [ "$CURRENT_PATH" = "$WANTED_PATH" ]; then
	report core.hooksPath "$CURRENT_PATH" 'already set'
else
	git config --local core.hooksPath "$WANTED_PATH" \
		|| failed "could not write core.hooksPath. Nothing was activated."
	CURRENT_PATH=$WANTED_PATH
	report core.hooksPath "$WANTED_PATH" 'set'
fi

# --- commit.gpgsign ---------------------------------------------------------
#
# FR-012: commits are signed when they are created, which is what leaves the
# push check with nothing to refuse under ordinary use.
CURRENT_SIGN=''
CURRENT_SIGN=$(git config --local --get commit.gpgsign 2> /dev/null) || CURRENT_SIGN=''

if [ "$MODE" = status ]; then
	if [ -n "$CURRENT_SIGN" ]; then
		report commit.gpgsign "$CURRENT_SIGN" 'already set'
	else
		report commit.gpgsign '(unset)' 'not configured'
	fi
elif [ "$CURRENT_SIGN" = true ]; then
	report commit.gpgsign true 'already set'
else
	git config --local commit.gpgsign true \
		|| failed 'could not write commit.gpgsign.'
	report commit.gpgsign true 'set'
fi

# --- the signing identity, which this script REPORTS and never writes --------
#
# gpg.format names a signing scheme and user.signingkey names a person's key.
# Guessing either produces commits signed by the wrong identity, which is worse
# than no signature at all: an unsigned commit is visibly unattributed, and a
# wrongly signed one is confidently misattributed. Reporting them absent is not
# a failure and does not affect the exit status -- the contributor can still
# commit, and the push check names the remedy at the point it matters.
for _setting in gpg.format user.signingkey; do
	_value=''
	_value=$(git config --get "$_setting" 2> /dev/null) || _value=''
	if [ -n "$_value" ]; then
		report "$_setting" "$_value" 'already set'
	else
		report "$_setting" '(unset)' 'not configured'
	fi
done

# --- the hook files ---------------------------------------------------------
#
# git silently skips a hook that is not executable, which is the quietest
# possible way for this whole feature to stop working.
HOOKS_PRESENT=0
for _hook in commit-msg pre-push; do
	if [ -f ".husky/$_hook" ]; then
		HOOKS_PRESENT=$((HOOKS_PRESENT + 1))
		if [ "$MODE" != status ] && [ ! -x ".husky/$_hook" ]; then
			chmod +x ".husky/$_hook" || failed "could not make .husky/$_hook executable."
			report ".husky/$_hook" 'executable' 'set'
		elif [ -x ".husky/$_hook" ]; then
			report ".husky/$_hook" 'executable' 'already set'
		else
			report ".husky/$_hook" 'not executable' 'not configured'
		fi
	else
		report ".husky/$_hook" '(missing)' 'not configured'
	fi
done

# --- the answer FR-013 requires ---------------------------------------------
#
# One line, unambiguous, from this command's own output. A contributor must
# never have to read a script to find out whether the checks are on.
STATE=inactive
case "$CURRENT_PATH" in
	.husky | .husky/_)
		if [ "$HOOKS_PRESENT" -gt 0 ]; then
			STATE=active
		fi
		;;
	*) ;;
esac

printf '\n  state: %s\n' "$STATE"

if [ "$STATE" = inactive ]; then
	printf '  To activate:   sh scripts/install-hooks.sh   (from the repository root)\n'
	printf '  To deactivate: git config --unset core.hooksPath\n'
fi

exit 0
