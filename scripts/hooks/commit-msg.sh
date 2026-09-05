#!/bin/sh
# The commit-message rule check.
#
# Invoked by git through .husky/commit-msg, and invoked directly by
# scripts/selftest.sh with a fixture. Both callers pass exactly one argument --
# the path of a file holding a candidate message -- which is what makes this
# check provable without a temporary repository. Contract:
# specs/008-commit-hooks/contracts/commit-msg-hook.md
#
# Exit 1 means the message was refused. Exit 2 means nothing was judged: a usage
# or configuration error. The two are distinct on purpose, because a contributor
# whose configuration file is missing must not read that as "my message is bad".
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
CONF="$REPO_ROOT/.commit-msg.conf"

EX_REFUSED=1
EX_USAGE=2

fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$EX_USAGE"
}

# refuse RULE DETAIL -- FR-003: name the rule and reproduce the offending value.
# A refusal that says only "invalid" leaves the contributor guessing, and the
# Quality Gate Requirements forbid a check that reports a failure without
# saying what it is about.
refuse() {
	{
		printf '%s: commit message refused -- %s\n' "$PROG" "$1"
		printf '\n  subject: %s\n' "$SUBJECT"
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
	exit "$EX_REFUSED"
}

if [ "$#" -ne 1 ]; then
	fatal "expected exactly one argument, the commit-message file; got $#."
fi

MSGFILE=$1
[ -f "$MSGFILE" ] || fatal "the commit-message file $MSGFILE does not exist."

# A missing configuration file is fatal and is NEVER a fall back to built-in
# defaults (Principle V). scripts/lib/scope.sh applies the same rule to a
# missing exclusion declaration, for the same reason: a silent default is
# indistinguishable from a value somebody chose.
[ -f "$CONF" ] || fatal "the rule declaration $CONF is missing, so no message can be judged. Refusing to fall back to built-in defaults rather than silently applying rules nobody committed."

# shellcheck source=/dev/null
. "$CONF"

[ -n "${COMMIT_MSG_TYPES:-}" ] || fatal "$CONF declares no COMMIT_MSG_TYPES."
[ -n "${COMMIT_MSG_SCOPE_POLICY:-}" ] || fatal "$CONF declares no COMMIT_MSG_SCOPE_POLICY."
[ -n "${COMMIT_MSG_MAX_SUBJECT:-}" ] || fatal "$CONF declares no COMMIT_MSG_MAX_SUBJECT."

case "$COMMIT_MSG_SCOPE_POLICY" in
	required | optional | forbidden) ;;
	*)
		fatal "$CONF sets COMMIT_MSG_SCOPE_POLICY to \"$COMMIT_MSG_SCOPE_POLICY\"; it must be required, optional or forbidden."
		;;
esac

case "$COMMIT_MSG_MAX_SUBJECT" in
	'' | *[!0-9]*)
		fatal "$CONF sets COMMIT_MSG_MAX_SUBJECT to \"$COMMIT_MSG_MAX_SUBJECT\"; it must be a positive integer."
		;;
	*) ;;
esac
[ "$COMMIT_MSG_MAX_SUBJECT" -gt 0 ] || fatal "$CONF sets COMMIT_MSG_MAX_SUBJECT to zero."

# The subject is the first line that is neither a comment nor blank. Git's own
# message template puts comment lines in this file, so a naive "first line"
# would judge git's boilerplate instead of the contributor's text.
SUBJECT=$(sed -e '/^#/d' -e '/^[[:space:]]*$/d' "$MSGFILE" | head -n 1)

[ -n "$SUBJECT" ] || refuse 'the message is empty' ''

# Rule 0 -- FR-005. A message whose shape was fixed by the tool that wrote it
# cannot be reworded by the contributor, so refusing it would block an operation
# rather than improve a message.
#
# FR-005a: this exempts the GENERATED revert form. The hand-written `revert:`
# form is not exempt and does not need to be -- `revert` is a permitted type, so
# it passes the ordinary rules below. Both shapes are acceptable and they reach
# acceptance by different routes.
case "$SUBJECT" in
	'Merge '* | 'Revert '* | 'fixup! '* | 'squash! '* | 'amend! '*)
		exit 0
		;;
	*) ;;
esac

# Rule 1 -- the shape. Split on the first ": ", which the Conventional Commits
# grammar requires and which nothing else in a well-formed subject contains
# before the description.
case "$SUBJECT" in
	*': '*) ;;
	*)
		refuse 'the subject does not match <type>[(scope)][!]: <description>' \
			'there is no ": " separating the type from the description'
		;;
esac

PREFIX=${SUBJECT%%: *}
DESCRIPTION=${SUBJECT#*: }

[ -n "$DESCRIPTION" ] || refuse 'the description is empty' 'a subject must say what changed, not only its type'

case "$PREFIX" in
	*'!')
		PREFIX=${PREFIX%!}
		;;
	*) ;;
esac

SCOPE=''
case "$PREFIX" in
	*'('*')')
		SCOPE=${PREFIX#*\(}
		SCOPE=${SCOPE%\)}
		TYPE=${PREFIX%%\(*}
		[ -n "$SCOPE" ] || refuse 'the scope is empty' 'write type(scope): or omit the parentheses entirely'
		;;
	*'('* | *')'*)
		refuse 'the scope parentheses are unbalanced' "prefix: $PREFIX"
		;;
	*)
		TYPE=$PREFIX
		;;
esac

[ -n "$TYPE" ] || refuse 'the type is empty' 'a subject must begin with a permitted type'

TYPE_OK=0
for _t in $COMMIT_MSG_TYPES; do
	if [ "$_t" = "$TYPE" ]; then
		TYPE_OK=1
		break
	fi
done
[ "$TYPE_OK" -eq 1 ] || refuse "\"$TYPE\" is not a permitted type" "permitted: $COMMIT_MSG_TYPES"

# Rule 2 -- the scope policy.
case "$COMMIT_MSG_SCOPE_POLICY" in
	required)
		[ -n "$SCOPE" ] || refuse 'a scope is required by COMMIT_MSG_SCOPE_POLICY' 'write type(scope): description'
		;;
	forbidden)
		[ -z "$SCOPE" ] || refuse 'a scope is forbidden by COMMIT_MSG_SCOPE_POLICY' "found scope: $SCOPE"
		;;
	optional) ;;
	*) ;;
esac

# Rule 3 -- FR-002. The FIRST line only. Body and trailer lines are never
# length-checked: this repository's own commit trailers carry URLs, and a
# per-line rule would make its existing convention illegal.
LENGTH=${#SUBJECT}
if [ "$LENGTH" -gt "$COMMIT_MSG_MAX_SUBJECT" ]; then
	refuse "the first line is $LENGTH characters; the limit is $COMMIT_MSG_MAX_SUBJECT" \
		"measured length: $LENGTH"
fi

exit 0
