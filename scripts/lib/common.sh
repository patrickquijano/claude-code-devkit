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

# A newline, for the pattern matches below. POSIX sh has no $'\n'.
LF='
'

# Set by parse_args from a trailing `-- PATH...`: the paths the caller named,
# one per line, empty when none were named. Every invocation that existed
# before this was added leaves it empty, and empty means "no narrowing", so
# those invocations are unaffected (FR-017).
#
# Newline-separated rather than NUL-separated because a shell variable cannot
# hold a NUL byte -- which is also why lib/scope.sh streams its pathspecs
# instead of accumulating them. A path containing a newline is refused in
# parse_args rather than mis-parsed here.
REQUESTED_PATHS=''

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
Usage: $1 [--fix] [-- PATH...]

no arguments  Report violations. Modifies no file.
--fix         Rewrite files into conformance where the tool supports it.
-- PATH...    Narrow this run to the named paths. Never widens it.
-h, --help    This message.

Exit: 0 pass, 1 violations, 2 usage, 3 no tool and no container, 4 not a git tree.
USAGE
}

# parse_args "$@" -> sets MODE and REQUESTED_PATHS.
# Anything but --fix, -h, --help is a usage error: a runner that silently
# ignores an argument is a runner that silently did something else. That rule
# now applies to the arguments before `--` only; after it, every argument is a
# path and none is interpreted, which is what keeps a path beginning with `-`
# from being read as a flag.
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
			--)
				# Bare `--` with nothing after it names no paths and so
				# narrows nothing, the same reading git gives it.
				shift
				while [ "$#" -gt 0 ]; do
					case "$1" in
						*"$LF"*)
							die "$PROG: path contains a newline: $1" 2
							;;
						*)
							# A path with no newline needs no handling.
							;;
					esac
					REQUESTED_PATHS="$REQUESTED_PATHS$1$LF"
					shift
				done
				return 0
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
	trap 'rm -f "$LIST" "$LIST.req" "$LIST.raw" "$LIST.out"' EXIT INT TERM
}

# repo_relative PATH -- prints PATH relative to the repository root, or nothing
# at all when it does not resolve to something under it.
#
# No `realpath` and no `readlink -f`: neither is POSIX, and the readlink macOS
# ships has no -f. `cd` plus `pwd -P` is the portable resolution, and it
# resolves the directory part, which is the part a symlink can use to point
# outside the tree while still looking like a path inside it.
repo_relative() {
	rr_dir=$(dirname -- "$1")
	rr_base=$(basename -- "$1")
	rr_abs_dir=$(CDPATH='' cd -- "$rr_dir" 2> /dev/null && pwd -P) || return 0
	[ -n "$rr_abs_dir" ] || return 0
	# REPO_ROOT is resolved the same way before comparing, so a symlinked
	# checkout does not make every path look external.
	rr_root=$(CDPATH='' cd -- "$REPO_ROOT" && pwd -P)
	# Strip the prefix from the whole path, not from the directory part. For a
	# file at the repository root the directory part IS the root, with no
	# trailing slash to match, so stripping there leaves the path absolute.
	rr_abs="$rr_abs_dir/$rr_base"
	case "$rr_abs" in
		"$rr_root"/*)
			printf '%s\n' "${rr_abs#"$rr_root"/}"
			;;
		*)
			# Outside the repository. Printing nothing drops it from the
			# filter, so it matches no file and the run reports an empty
			# scope -- FR-005's refusal, reached without a special case.
			;;
	esac
}

# filter_list -- narrows LIST to REQUESTED_PATHS.
#
# It filters the list the check already computed; it never treats a requested
# path as a file to examine. Passing requested paths through would let a caller
# reach a file outside the check's globs or excluded by its own configuration,
# which is exactly what FR-006 and FR-007 forbid.
filter_list() {
	printf '%s' "$REQUESTED_PATHS" > "$LIST.raw"
	: > "$LIST.req"
	while IFS= read -r fl_path; do
		fl_rel=$(repo_relative "$fl_path")
		if [ -n "$fl_rel" ]; then
			printf '%s\n' "$fl_rel" >> "$LIST.req"
		fi
	done < "$LIST.raw"

	# The comparison below is line-oriented, so a file name containing a
	# newline would match the wrong record. `git ls-files -z` emits names
	# literally, so detect that rather than mis-handle it: the NUL count and
	# the line count after translation must agree (Principle II).
	fl_nuls=$(tr -dc '\0' < "$LIST" | wc -c | tr -d ' ')
	fl_lines=$(tr '\0' '\n' < "$LIST" | wc -l | tr -d ' ')
	if [ "$fl_nuls" -ne "$fl_lines" ]; then
		die "$PROG: a file name contains a newline; refusing to filter" 1
	fi

	# grep exits 1 when nothing matches, which is a legitimate outcome here
	# (a path list matching nothing is exit 0 with "no files in scope"), so
	# the status is consumed rather than allowed to end the run under set -e.
	if tr '\0' '\n' < "$LIST" | grep -x -F -f "$LIST.req" > "$LIST.out"; then
		tr '\n' '\0' < "$LIST.out" > "$LIST"
	else
		: > "$LIST"
	fi
}

# collect CHECK GLOB... -- fills LIST. Empty list reports success and says so,
# rather than failing on an empty input set or staying silent.
#
# CHECK names the check whose exclusion declaration governs this list; see
# exclusions_for() in lib/scope.sh. The arguments are forwarded to file_list
# unchanged, so the check's own call site is the single place its scope is
# stated: `collect markdown '*.md' '*.markdown'`.
collect() {
	file_list "$@" > "$LIST"
	if [ -n "$REQUESTED_PATHS" ]; then
		filter_list
	fi
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
