#!/bin/sh
# Shared helpers for the quality-check runners.
#
# POSIX sh only. No arrays, no [[ ]], no <<<, no ${var/a/b}, no $'...'.
# `set -o pipefail` does not exist in POSIX sh, so pipelines are structured so
# that the command whose status matters is last, or the status is captured.
#
# Sourced, not executed.

# Exit statuses. Documented in specs/001-quality-gate-plugin/contracts/cli.md;
# a caller is entitled to rely on these.
#
# EX_NOGIT is read by lib/scope.sh, which is sourced separately, so ShellCheck
# cannot see the use from here.
# shellcheck disable=SC2034
EX_OK=0
# shellcheck disable=SC2034
EX_VIOLATION=1
# shellcheck disable=SC2034
EX_USAGE=2
# shellcheck disable=SC2034
EX_NOTOOL=3
# shellcheck disable=SC2034
EX_NOGIT=4

# Colour for this script's own output only. Tool output is never rewritten.
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
	C_BOLD=''
	C_RESET=''
else
	C_BOLD=$(printf '\033[1m')
	C_RESET=$(printf '\033[0m')
fi

# Resolved once, so the container branches do not embed command substitutions.
RUN_UID=$(id -u)
RUN_GID=$(id -g)
RUN_USER="$RUN_UID:$RUN_GID"

# Set by parse_args. Arguments the native path passes where it differs from the
# container path; empty for the runners that do not use run_files_sh.
MODE=check
NATIVE_ARGS=''

# Some images set no ENTRYPOINT (their binary is the Cmd), so passing arguments
# replaces the command and docker tries to exec the first file as a program.
# A runner facing such an image sets CONTAINER_CMD to the binary name; it is
# inserted before the arguments in the container branch only.
CONTAINER_CMD=''

# Set by normalise_status. A variable rather than a return value, so callers do
# not have to wrap it in a command substitution whose own status is then masked.
NORM_STATUS=0

# Filled by init_runner and collect.
LIST=''

# die MESSAGE [STATUS]
# Message to stderr, exit with STATUS (default 1). Never writes to stdout:
# stdout carries violations, and a caller may be reading it.
die() {
	printf '%s\n' "$1" >&2
	exit "${2:-1}"
}

# have COMMAND -> 0 if COMMAND is on PATH.
# `command -v` is POSIX; `which` is not, and its exit status is unreliable.
have() {
	command -v "$1" > /dev/null 2>&1
}

# say MESSAGE -- progress line, stdout, so it interleaves with tool output in
# the order things actually happened.
say() {
	printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$1"
}

# The heredoc body is flush left on purpose. Leading spaces here are printed
# output, not code indentation, but a whitespace checker cannot tell the
# difference -- and punching a hole in the whitespace standard for the one file
# that failed it would be the wrong trade.
usage() {
	cat << USAGE
Usage: $1 [--fix]

no arguments  Report violations. Modifies no file.
--fix         Rewrite files into conformance where the tool supports it.
-h, --help    This message.

Exit: 0 pass, 1 violations, 2 usage, 3 no tool and no container, 4 not a git tree.
USAGE
}

# parse_args "$@" -> sets MODE.
# Anything but --fix, -h, --help is a usage error: a runner that silently
# ignores an argument is a runner that silently did something else.
parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--fix)
				MODE=fix
				;;
			-h | --help)
				usage "$PROG"
				exit 0
				;;
			*)
				usage "$PROG" >&2
				die "$PROG: unrecognised argument: $1" 2
				;;
		esac
		shift
	done
}

# no_automatic_fix STANDARD
# FR-012a: for standards whose tools cannot rewrite files, --fix reports and
# leaves files untouched. Not an error, so it does not change the status.
no_automatic_fix() {
	say "$PROG: no automatic fix available for $1; run without --fix to see violations"
}

# normalise_status STATUS -> sets NORM_STATUS
# xargs returns 123 when any invocation exited 1-125. Map that back to 1 so the
# documented exit statuses hold even when a long file list was split across
# several invocations.
normalise_status() {
	if [ "$1" -eq 123 ]; then
		NORM_STATUS=1
	else
		NORM_STATUS=$1
	fi
}

# init_runner -- temp list file plus cleanup. Bare signal names: SIGTERM is a
# bashism, TERM is POSIX.
init_runner() {
	LIST=$(mktemp)
	trap 'rm -f "$LIST"' EXIT INT TERM
}

# collect GLOB... -- fills LIST. Empty list reports success and says so, rather
# than failing on an empty input set or staying silent.
collect() {
	file_list "$@" > "$LIST"
	if [ ! -s "$LIST" ]; then
		say "$PROG: no files in scope"
		exit 0
	fi
}

# --- Running a tool over the in-scope file list ------------------------------
#
# Three-step resolution, fixed order:
#   1. native command on PATH -> run it directly, no container, no network
#   2. docker available       -> run the pinned image
#   3. neither                -> exit 3 naming both
#
# In check mode the repository is mounted READ-ONLY, which is what makes "a
# check run modifies no file" a property of the container boundary rather than a
# promise about six tools' behaviour (SC-007). Fix mode mounts read-write and
# passes the calling user's ids, so rewritten files are not left owned by root.
#
# LINT_FORCE_CONTAINER, if non-empty, skips step 1 entirely, so the container
# path can be exercised without uninstalling anything.
#
# The docker invocations are written out in full in each branch rather than
# wrapped in a helper: xargs runs an external command and cannot see a shell
# function, so a helper here would look tidy and never execute.

no_tool() {
	die "$PROG: cannot run this check. Neither the native command \"$1\" nor \"docker\" (which would run $2) is available. Install either one." 3
}

# run_files LISTFILE NATIVE IMAGE ARGS...
run_files() {
	_listfile=$1
	_native=$2
	_image=$3
	shift 3
	_st=0

	if [ -z "${LINT_FORCE_CONTAINER:-}" ] && have "$_native"; then
		say "$PROG (native: $_native)"
		xargs -0 "$_native" "$@" < "$_listfile" || _st=$?
	elif have docker; then
		say "$PROG (container: $_image)"
		if [ "$MODE" = fix ]; then
			# CONTAINER_CMD is a deliberate word-split: empty for most
			# images, one binary name for those with no ENTRYPOINT.
			# shellcheck disable=SC2086
			xargs -0 docker run --rm \
				-v "$REPO_ROOT:/work" -w /work \
				-u "$RUN_USER" -e HOME=/tmp -e npm_config_cache=/tmp/.npm \
				"$_image" $CONTAINER_CMD "$@" < "$_listfile" || _st=$?
		else
			# shellcheck disable=SC2086
			xargs -0 docker run --rm \
				-v "$REPO_ROOT:/work:ro" -w /work \
				"$_image" $CONTAINER_CMD "$@" < "$_listfile" || _st=$?
		fi
	else
		no_tool "$_native" "$_image"
	fi

	normalise_status "$_st"
	return "$NORM_STATUS"
}

# run_files_sh LISTFILE NATIVE IMAGE SHELL_SNIPPET
# For the two tools that publish no image of their own: the pinned language
# image runs a shell snippet that installs the exactly-pinned tool version and
# execs it, receiving the file list as positional parameters. The tool-version
# pin is as load-bearing as the image pin -- constitution Principle III, second
# clause. The native path passes NATIVE_ARGS instead.
run_files_sh() {
	_listfile=$1
	_native=$2
	_image=$3
	_snippet=$4
	_st=0

	if [ -z "${LINT_FORCE_CONTAINER:-}" ] && have "$_native"; then
		say "$PROG (native: $_native)"
		# NATIVE_ARGS is a deliberate word-split: it carries zero or more
		# separate flags, and this is POSIX sh with no arrays to hold them.
		# shellcheck disable=SC2086
		xargs -0 "$_native" $NATIVE_ARGS < "$_listfile" || _st=$?
	elif have docker; then
		say "$PROG (container: $_image)"
		if [ "$MODE" = fix ]; then
			xargs -0 docker run --rm \
				-v "$REPO_ROOT:/work" -w /work \
				-u "$RUN_USER" -e HOME=/tmp -e npm_config_cache=/tmp/.npm \
				"$_image" sh -c "$_snippet" sh < "$_listfile" || _st=$?
		else
			xargs -0 docker run --rm \
				-v "$REPO_ROOT:/work:ro" -w /work \
				-e HOME=/tmp -e npm_config_cache=/tmp/.npm \
				"$_image" sh -c "$_snippet" sh < "$_listfile" || _st=$?
		fi
	else
		no_tool "$_native" "$_image"
	fi

	normalise_status "$_st"
	return "$NORM_STATUS"
}
