#!/bin/sh
# The commit-message rule check, reached through .husky/commit-msg.
# Contract: specs/008-commit-hooks/contracts/commit-msg-hook.md
#
# Exit 1 means the message was refused. Exit 2 means nothing was judged: a usage
# or configuration error. Distinct on purpose -- a contributor whose
# configuration is missing must not read that as "my message is bad".
#
# Sourced, not executed. POSIX sh only.

CM_EX_REFUSED=1
CM_EX_USAGE=2

CM_SUBJECT=''

cm_fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$CM_EX_USAGE"
}

# cm_refuse RULE DETAIL -- FR-003: name the rule and reproduce the offending
# value. A refusal that says only "invalid" leaves the contributor guessing.
cm_refuse() {
	{
		printf '%s: commit message refused -- %s\n' "$PROG" "$1"
		printf '\n  subject: %s\n' "$CM_SUBJECT"
		if [ -n "$2" ]; then
			printf '  %s\n' "$2"
		fi
		printf '\n  The rules live in .commit-msg.conf. Permitted types:\n'
		printf '    %s\n' "$COMMIT_MSG_TYPES"
		printf '  Shape: <type>[(scope)][!]: <description>, first line at most %s characters.\n' \
			"$COMMIT_MSG_MAX_SUBJECT"
		printf '\n  To bypass this check for one commit: git commit --no-verify\n'
		printf '  That is the emergency route; it leaves the check armed for the next commit.\n'
	} >&2
	exit "$CM_EX_REFUSED"
}

# commit_msg_main MSGFILE
commit_msg_main() {
	if [ "$#" -ne 1 ]; then
		cm_fatal "expected exactly one argument, the commit-message file; got $#."
	fi

	_cm_file=$1
	[ -f "$_cm_file" ] || cm_fatal "the commit-message file $_cm_file does not exist."

	_cm_conf="$REPO_ROOT/.commit-msg.conf"

	# A missing configuration file is fatal and NEVER a fall back to built-in
	# defaults (Principle V), for the reason lib/scope.sh refuses a missing
	# exclusion declaration: a silent default is indistinguishable from a value
	# somebody chose.
	[ -f "$_cm_conf" ] || cm_fatal "the rule declaration $_cm_conf is missing, so no message can be judged. Refusing to fall back to built-in defaults rather than silently applying rules nobody committed."

	# shellcheck source=/dev/null
	. "$_cm_conf"

	[ -n "${COMMIT_MSG_TYPES:-}" ] || cm_fatal "$_cm_conf declares no COMMIT_MSG_TYPES."
	[ -n "${COMMIT_MSG_SCOPE_POLICY:-}" ] || cm_fatal "$_cm_conf declares no COMMIT_MSG_SCOPE_POLICY."
	[ -n "${COMMIT_MSG_MAX_SUBJECT:-}" ] || cm_fatal "$_cm_conf declares no COMMIT_MSG_MAX_SUBJECT."

	case "$COMMIT_MSG_SCOPE_POLICY" in
		required | optional | forbidden) ;;
		*)
			cm_fatal "$_cm_conf sets COMMIT_MSG_SCOPE_POLICY to \"$COMMIT_MSG_SCOPE_POLICY\"; it must be required, optional or forbidden."
			;;
	esac

	case "$COMMIT_MSG_MAX_SUBJECT" in
		'' | *[!0-9]*)
			cm_fatal "$_cm_conf sets COMMIT_MSG_MAX_SUBJECT to \"$COMMIT_MSG_MAX_SUBJECT\"; it must be a positive integer."
			;;
		*) ;;
	esac
	[ "$COMMIT_MSG_MAX_SUBJECT" -gt 0 ] || cm_fatal "$_cm_conf sets COMMIT_MSG_MAX_SUBJECT to zero."

	# The subject is the first line that is neither a comment nor blank: git's
	# own template puts comment lines in this file, so a naive "first line"
	# would judge git's boilerplate.
	CM_SUBJECT=$(sed -e '/^#/d' -e '/^[[:space:]]*$/d' "$_cm_file" | head -n 1)

	[ -n "$CM_SUBJECT" ] || cm_refuse 'the message is empty' ''

	# Rule 0 (FR-005): a message whose shape the tool fixed cannot be reworded,
	# so refusing it would block an operation rather than improve a message.
	# FR-005a: this exempts the GENERATED revert form. The hand-written
	# `revert:` form passes the ordinary rules below, `revert` being a permitted
	# type -- two shapes, two routes to acceptance.
	case "$CM_SUBJECT" in
		'Merge '* | 'Revert '* | 'fixup! '* | 'squash! '* | 'amend! '*)
			exit 0
			;;
		*) ;;
	esac

	# Rule 1 -- the shape. Split on the first ": ".
	case "$CM_SUBJECT" in
		*': '*) ;;
		*)
			cm_refuse 'the subject does not match <type>[(scope)][!]: <description>' \
				'there is no ": " separating the type from the description'
			;;
	esac

	_cm_prefix=${CM_SUBJECT%%: *}
	_cm_description=${CM_SUBJECT#*: }

	[ -n "$_cm_description" ] || cm_refuse 'the description is empty' 'a subject must say what changed, not only its type'

	case "$_cm_prefix" in
		*'!')
			_cm_prefix=${_cm_prefix%!}
			;;
		*) ;;
	esac

	_cm_scope=''
	case "$_cm_prefix" in
		*'('*')')
			_cm_scope=${_cm_prefix#*\(}
			_cm_scope=${_cm_scope%\)}
			_cm_type=${_cm_prefix%%\(*}
			[ -n "$_cm_scope" ] || cm_refuse 'the scope is empty' 'write type(scope): or omit the parentheses entirely'
			;;
		*'('* | *')'*)
			cm_refuse 'the scope parentheses are unbalanced' "prefix: $_cm_prefix"
			;;
		*)
			_cm_type=$_cm_prefix
			;;
	esac

	[ -n "$_cm_type" ] || cm_refuse 'the type is empty' 'a subject must begin with a permitted type'

	_cm_type_ok=0
	for _cm_t in $COMMIT_MSG_TYPES; do
		if [ "$_cm_t" = "$_cm_type" ]; then
			_cm_type_ok=1
			break
		fi
	done
	[ "$_cm_type_ok" -eq 1 ] || cm_refuse "\"$_cm_type\" is not a permitted type" "permitted: $COMMIT_MSG_TYPES"

	# Rule 2 -- the scope policy.
	case "$COMMIT_MSG_SCOPE_POLICY" in
		required)
			[ -n "$_cm_scope" ] || cm_refuse 'a scope is required by COMMIT_MSG_SCOPE_POLICY' 'write type(scope): description'
			;;
		forbidden)
			[ -z "$_cm_scope" ] || cm_refuse 'a scope is forbidden by COMMIT_MSG_SCOPE_POLICY' "found scope: $_cm_scope"
			;;
		optional) ;;
		*) ;;
	esac

	# Rule 3 (FR-002) -- the FIRST line only. This repository's commit trailers
	# carry URLs, so a per-line rule would make its own convention illegal.
	_cm_length=${#CM_SUBJECT}
	if [ "$_cm_length" -gt "$COMMIT_MSG_MAX_SUBJECT" ]; then
		cm_refuse "the first line is $_cm_length characters; the limit is $COMMIT_MSG_MAX_SUBJECT" \
			"measured length: $_cm_length"
	fi

	exit 0
}
