#!/bin/sh
# The body of scripts/format-file.sh, a PostToolUse hook registered in
# .claude/settings.json. No arguments; one JSON object on stdin.
# Contract: specs/004-format-hook-scope/contracts/format-file-cli.md
#
# Sources NOTHING. The only name it needs from outside is run_standard, which
# its caller has already sourced from lib/checks.sh -- so a test can substitute
# a stand-in run_standard without substituting anything else. parse_args is
# deliberately not used: it would reject what the hook runner sends.
#
# Sourced, not executed. POSIX sh only.
#
# SC2034: MODE and REQUESTED_PATHS are set here and read by run_standard, which
# arrives from lib/checks.sh. ShellCheck analyses one file at a time and cannot
# see that use from here.
# shellcheck disable=SC2034

# REQUESTED_PATHS is newline-terminated, and POSIX sh has no $'\n'.
FH_LF='
'

FH_MSG=''
FH_OUT=''
FH_PROG=''
FH_REL=''
FH_RESOLVED=''

# Status lines accumulate and are emitted as ONE JSON object: stdout carries a
# single object, so a message per check would be a parse error.
fh_add_msg() {
	if [ -z "$FH_MSG" ]; then
		FH_MSG=$1
	else
		FH_MSG="$FH_MSG
$1"
	fi
}

# Escape for a JSON string literal: backslashes, then quotes, then newlines.
fh_json_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

fh_emit_msg() {
	if [ -n "$FH_MSG" ]; then
		# Captured on its own line: a command substitution inside an argument
		# masks its exit status (SC2312).
		_fh_json=$(fh_json_escape "$FH_MSG")
		printf '{"systemMessage":"%s"}\n' "$_fh_json"
	fi
}

# fh_run_check STANDARD -- data-model.md's Check invocation table:
#   0 with files in scope  -> status line, continue
#   0 with none in scope   -> no message, continue
#   3                      -> visible skip naming tool and image, continue
#   1, 2 or 4              -> stop here, exit 2, detail on stderr
#
# The subshell with MODE and REQUESTED_PATHS set is the in-process equivalent of
# the contract's `--fix -- <path>` invocation. The message names the
# per-standard entry point, so hook output reads the same as check output.
fh_run_check() {
	_fh_std=$1
	_fh_name="lint-$_fh_std.sh"
	_fh_status=0

	(
		MODE=fix
		REQUESTED_PATHS="$FH_RESOLVED$FH_LF"
		run_standard_as "$_fh_name" "$_fh_std"
	) > "$FH_OUT" 2>&1 || _fh_status=$?

	case "$_fh_status" in
		0)
			# Anchored, so a path this check does not govern stays silent
			# (FR-007) and a file name cannot trip the match.
			if grep -q ': no files in scope$' "$FH_OUT"; then
				return 0
			fi
			fh_add_msg "==> $FH_PROG: $FH_REL ($_fh_name)"
			;;
		3)
			# Not a failure. Exit 3 means neither the tool nor docker is
			# available; forwarding the check's own message keeps a container
			# runtime from becoming a precondition for editing (Principle I).
			_fh_why=$(sed -n '$p' "$FH_OUT")
			fh_add_msg "==> $FH_PROG: $FH_REL - $_fh_name skipped: $_fh_why"
			;;
		*)
			# Stop at the first stopping status (Principle II).
			fh_emit_msg
			{
				printf '%s: %s failed on %s (exit %s)\n' \
					"$FH_PROG" "$_fh_name" "$FH_REL" "$_fh_status"
				# The check's own output, UNMODIFIED: it already names the
				# file and the location. stderr, because a PostToolUse hook's
				# stderr is what reaches the session (FR-011).
				cat "$FH_OUT"
			} >&2
			exit 2
			;;
	esac
}

# format_hook_main PROG REPO_ROOT
# REPO_ROOT is resolved by the caller from its own location on disk, never from
# the payload's `cwd`: `cwd` follows the session into a worktree while the hook,
# the checks and the configuration must agree on one tree.
format_hook_main() {
	# The recursion guard, tested before anything else this function does.
	#
	# This is the SECOND of two independent guarantees. The first is the event:
	# PostToolUse fires on tool calls, and this hook's writes reach disk through
	# formatters that write directly, with no tool call -- which is also why
	# FileChanged, which does fire on plain disk writes, was rejected
	# (research.md section 1). FR-010 must not rest on a single argument.
	#
	# An environment variable rather than a lock file, because it needs no
	# cleanup. A stale lock would disable formatting silently, which is the
	# failure mode FR-018 exists to prevent, arriving by another route.
	if [ -n "${CCD_FORMAT_FILE_ACTIVE:-}" ]; then
		exit 0
	fi
	CCD_FORMAT_FILE_ACTIVE=1
	export CCD_FORMAT_FILE_ACTIVE

	FH_PROG=$1
	_fh_root=$2

	# Rule 1: a file path can be extracted.
	#
	# `sed`, not `jq`: Principle I forbids making a global install a
	# precondition, and this runs after every edit. Not general JSON parsing --
	# it extracts one well-known scalar. A path containing an escaped quote
	# yields a TRUNCATED value, which fails rules 4 and 6 and is refused, so the
	# blind spot's failure mode is a refusal and never the wrong file
	# (research.md section 4).
	_fh_candidate=$(sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
	if [ -z "$_fh_candidate" ]; then
		exit 0
	fi

	# Rules 2 and 3: resolvable, and inside this repository. `cd` plus `pwd -P`
	# rather than `realpath` or `readlink -f`: neither is POSIX, and the
	# readlink macOS ships has no -f. Resolving BEFORE the containment test is
	# what makes the test meaningful against an outward symlink.
	_fh_dir=$(dirname -- "$_fh_candidate")
	_fh_base=$(basename -- "$_fh_candidate")
	_fh_absdir=$(CDPATH='' cd -- "$_fh_dir" 2> /dev/null && pwd -P) || exit 0
	if [ -z "$_fh_absdir" ]; then
		exit 0
	fi
	FH_RESOLVED="$_fh_absdir/$_fh_base"

	# The trailing slash is load-bearing: without it a sibling directory whose
	# name merely begins with this repository's name would pass.
	case "$FH_RESOLVED" in
		"$_fh_root"/*) ;;
		*)
			exit 0
			;;
	esac

	# Rules 4 and 6 are both tested, in the order the contract fixes them,
	# though -f subsumes -e: a deleted file and a directory are different
	# rejections to a reader.
	if [ ! -e "$FH_RESOLVED" ]; then
		exit 0
	fi

	# Rule 5: a symlink is refused rather than followed. Rule 3 resolves only
	# the directory portion, so a link whose parent is inside the repository
	# passes containment while its last component points anywhere; -f in rule 6
	# would follow it. Refused rather than resolved because `readlink -f` is not
	# portable and Prettier rejects a symlink argument outright. A link pointing
	# inside loses nothing: editing the target formats it by its real path.
	if [ -L "$FH_RESOLVED" ]; then
		exit 0
	fi

	if [ ! -f "$FH_RESOLVED" ]; then
		exit 0
	fi

	# Rule 7: no NUL byte in the first 8 KiB. Defence, not the primary
	# mechanism -- the rewriting checks match text extensions only -- but FR-009
	# must be verifiable on its own (SC-005). `od` is POSIX where `grep -I` and
	# `file --mime` are not.
	if od -An -v -c -N 8192 -- "$FH_RESOLVED" | grep -q '\\0'; then
		exit 0
	fi

	FH_REL=${FH_RESOLVED#"$_fh_root"/}

	FH_OUT=$(mktemp)
	trap 'rm -f "$FH_OUT"' EXIT INT TERM

	# The three rewriting checks, in lib/checks.sh's CHECKS order. The order
	# matters for Markdown, which both govern: Prettier writes, then markdownlint
	# over what it leaves. One order in this repository, not two (FR-005).
	#
	# Only these three: the other four report and cannot fix, so running them
	# per edit would fail the session on violations the edit did not cause
	# (FR-004). No extension-to-check mapping here -- each check's collect()
	# owns its globs and exits 0 with "no files in scope" otherwise.
	fh_run_check format
	fh_run_check markdown
	fh_run_check python

	fh_emit_msg
	exit 0
}
