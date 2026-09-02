#!/bin/sh
#
# SC2310: `have` and `plugins_resolved` are predicates, so `set -e` being
# disabled inside their conditions is the intended behaviour -- a missing tool or
# an unresolvable plugin is a branch to take, not an error to abort on. Declared
# file-wide because a disable comment covers only the next command, and both are
# called from more than one place here.
# shellcheck disable=SC2310
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/images.sh
. "$SCRIPT_DIR/lib/images.sh"
# shellcheck source=lib/scope.sh
. "$SCRIPT_DIR/lib/scope.sh"

parse_args "$@"
init_runner

collect '*.json' '*.jsonc' '*.md' '*.markdown' '*.yml' '*.yaml' '*.xml' '*.sh'

# Which add-on plugins can the native Prettier actually load?
#
# FR-023: an absent plugin is treated exactly as an absent tool -- that content
# kind goes to the container path, where the plugin is pinned. Not a warning that
# reduces coverage, and not a failure: either would break FR-008's guarantee that
# the verdict does not depend on what the caller has installed.
#
# Prettier resolves a configured plugin through Node's module lookup, which finds
# a globally installed package on one machine and nothing on the next. So this is
# asked rather than assumed, and the answer is printed: a plugin that resolved
# and one that did not must never produce the same output (FR-023).
plugins_resolved() {
	_missing=''
	_report=''
	for _plugin in $PLUGIN_NAMES; do
		if printf 'x\n' | "$1" --stdin-filepath probe.md \
			--plugin "$_plugin" > /dev/null 2>&1; then
			_report="$_report $_plugin=native"
		else
			_report="$_report $_plugin=absent"
			_missing="$_missing $_plugin"
		fi
	done
	PLUGIN_REPORT=$_report
	PLUGIN_MISSING=$_missing
	[ -z "$_missing" ]
}

PLUGIN_REPORT=''
PLUGIN_MISSING=''

if [ "$MODE" = fix ]; then
	NATIVE_ARGS='--write'
	_action='--write'
else
	NATIVE_ARGS='--check'
	_action='--check'
fi

if [ -z "${LINT_FORCE_CONTAINER:-}" ] && have prettier; then
	if plugins_resolved prettier; then
		say "$PROG (native: prettier) plugins:$PLUGIN_REPORT"
		run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
			"$FORMAT_SNIPPET $_action \"\$@\""
	else
		# At least one plugin is absent natively. Every file goes to the
		# container path rather than only the affected content kinds: one
		# verdict from one tool version is the guarantee FR-008 makes, and
		# splitting a single check across two resolutions would produce two
		# violation lists to reconcile.
		say "$PROG (native prettier found, but plugins:$PLUGIN_REPORT)"
		say "$PROG: routing to the container path, where$PLUGIN_MISSING is pinned (FR-023)"
		LINT_FORCE_CONTAINER=1
		export LINT_FORCE_CONTAINER
		run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
			"$FORMAT_SNIPPET $_action \"\$@\""
	fi
else
	say "$PROG: plugins pinned in the container path:$PLUGIN_NAMES"
	run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
		"$FORMAT_SNIPPET $_action \"\$@\""
fi
