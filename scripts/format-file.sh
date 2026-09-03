#!/bin/sh
# Format one file that Claude Code just edited.
#
# A PostToolUse hook entry point, configured in .claude/settings.json and
# committed. It takes no arguments and reads one JSON object on stdin.
# Contract: specs/004-format-hook-scope/contracts/format-file-cli.md
#
# POSIX sh only, like every script here. No arrays, no [[ ]], no <<<, no
# `set -o pipefail`.
#
# This script deliberately does NOT source lib/common.sh. It is a hook entry
# point with a different contract: common.sh's parse_args would reject the
# arguments the hook runner sends, and its exit statuses mean something else
# here. What it reuses instead is the check scripts themselves -- so the
# native-tool-or-container resolution, the pinned image digests, each check's
# globs and each check's exclusions all stay in the one place that owns them.
set -eu

# --- Recursion guard, tested before anything else ----------------------------
#
# This is the SECOND of two independent guarantees, not the only one. The first
# is the event itself: PostToolUse fires on tool calls, and this script's writes
# reach disk through formatters that write directly, with no tool call. So the
# loop cannot form through the designed path -- which is also why FileChanged,
# which does fire on plain disk writes, was rejected (research.md section 1).
#
# FR-010 is a hard requirement and must not rest on a single argument, so the
# guard covers what the reasoning does not: a formatter that itself invoked
# Claude Code, a future edit that introduces a tool-calling step, and any path
# nobody has thought of.
#
# An environment variable rather than a lock file, because it needs no cleanup.
# A stale lock would disable formatting silently, which is the failure mode
# FR-018 exists to prevent, arriving by another route.
if [ -n "${CCD_FORMAT_FILE_ACTIVE:-}" ]; then
	exit 0
fi

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# -P, so the containment test below compares physical paths on both sides.
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)

# The repository root comes from this script's own location, never from the
# payload's `cwd`. ${CLAUDE_PROJECT_DIR} stays at the project root while `cwd`
# follows the session into a worktree, so reading `cwd` would let the hook, the
# checks and the configuration disagree about which tree they are in.

# --- Rule 1: a file path can be extracted ------------------------------------
#
# `sed`, not `jq` and not `python3`. Principle I forbids making a global install
# a precondition, and this path runs after every edit; the hooks guide's own
# example uses `jq`, and its troubleshooting section anticipates
# "jq: command not found" -- exactly the failure Principle I exists to prevent.
#
# This is not general JSON parsing and must not be read as such: it extracts one
# well-known scalar whose value is a filesystem path. Its single blind spot is
# safe by construction -- a path containing an escaped double quote yields a
# TRUNCATED value, because [^"]* stops at the backslash, and a truncated path
# fails rules 4 and 6 below and is refused. The blind spot's failure mode is a
# refusal, never the wrong file. research.md section 4 has the full reasoning.
#
# `head -n 1` bounds it to the first match: tool_input.file_path is the only
# file_path the matched tools emit, and a second occurrence would mean a payload
# shape this hook does not understand.
CANDIDATE=$(sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
if [ -z "$CANDIDATE" ]; then
	exit 0
fi

# --- Rules 2 and 3: resolvable, and inside this repository --------------------
#
# `cd` plus `pwd -P` rather than `realpath` or `readlink -f`: neither is POSIX,
# and the readlink macOS ships has no -f (research.md section 5). Resolving
# BEFORE the containment test is what makes the test meaningful against a
# symlink that sits inside the repository and points outward.
CAND_DIR=$(dirname -- "$CANDIDATE")
CAND_BASE=$(basename -- "$CANDIDATE")
ABS_DIR=$(CDPATH='' cd -- "$CAND_DIR" 2> /dev/null && pwd -P) || exit 0
if [ -z "$ABS_DIR" ]; then
	exit 0
fi
RESOLVED="$ABS_DIR/$CAND_BASE"

# The trailing slash is load-bearing: without it a sibling directory whose name
# merely begins with this repository's name would pass.
case "$RESOLVED" in
	"$REPO_ROOT"/*) ;;
	*)
		exit 0
		;;
esac

# --- Rules 4, 5 and 6: exists, not a symlink, and a regular file -------------
#
# Rules 4 and 6 are both tested, in the order the contract fixes them, though -f
# subsumes -e: a deleted file and a directory are different rejections to a
# reader, and this is the list a future reader checks against the contract.
if [ ! -e "$RESOLVED" ]; then
	exit 0
fi

# Rule 5: a symlink is refused rather than followed.
#
# This is the rule that stops a symlink INSIDE the repository from reaching a
# file outside it. Rule 3 cannot: it resolves the directory portion, and a link
# whose parent directory is genuinely inside the repository passes containment
# while its final component still points anywhere at all. -f follows the link,
# so rule 6 would pass it too.
#
# Refused rather than resolved, for three reasons. Resolution would need
# `readlink`, which is not POSIX and whose -f the macOS build lacks -- the same
# objection recorded against it in lib/common.sh. Prettier refuses a symlink
# argument outright ("Explicitly specified pattern ... is a symbolic link"), so
# following one would turn an ordinary edit into a check failure and an exit 2
# rather than a silent skip. And a symlink pointing inside the repository loses
# nothing by being skipped here: editing the file it points at formats it
# through its real path.
if [ -L "$RESOLVED" ]; then
	exit 0
fi

if [ ! -f "$RESOLVED" ]; then
	exit 0
fi

# --- Rule 7: no NUL byte in the first 8 KiB -----------------------------------
#
# Defence, not the primary mechanism: the three rewriting checks match text
# extensions only, so binary content is already outside their globs. FR-009 is
# a stated requirement and must be verifiable on its own (SC-005), so it is
# tested here too.
#
# `od` is POSIX. `grep -I`, `file --mime` and `grep -q $'\0'` are not portable
# enough to rely on. 8 KiB because this runs after every edit.
if od -An -v -c -N 8192 -- "$RESOLVED" | grep -q '\\0'; then
	exit 0
fi

REL=${RESOLVED#"$REPO_ROOT"/}

# --- Set the guard before invoking anything -----------------------------------
CCD_FORMAT_FILE_ACTIVE=1
export CCD_FORMAT_FILE_ACTIVE

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT INT TERM

# Status lines accumulate and are emitted as ONE JSON object at the end: stdout
# carries a single object, so a message per check would be a parse error.
MSG=''

add_msg() {
	if [ -z "$MSG" ]; then
		MSG=$1
	else
		MSG="$MSG
$1"
	fi
}

# json_escape STRING -- escape for a JSON string literal.
# Backslashes first, then double quotes, then embedded newlines. The hooks
# reference warns that a malformed payload produces a parse notice even on
# exit 0, so the path is escaped rather than interpolated raw.
json_escape() {
	printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

emit_msg() {
	if [ -n "$MSG" ]; then
		# Captured rather than substituted inline: a command substitution
		# inside an argument masks its own exit status, which Principle II
		# forbids and ShellCheck reports as SC2312.
		em_json=$(json_escape "$MSG")
		printf '{"systemMessage":"%s"}\n' "$em_json"
	fi
}

# run_check CHECK-SCRIPT
# Outcome mapping is data-model.md's Check invocation table:
#   0 with files in scope  -> status line, continue
#   0 with none in scope   -> no message, continue
#   3                      -> visible skip naming tool and image, continue
#   1, 2 or 4              -> stop here, exit 2, detail on stderr
run_check() {
	rc_name=$1
	rc_status=0
	"$SCRIPT_DIR/$rc_name" --fix -- "$RESOLVED" > "$OUT" 2>&1 || rc_status=$?

	case "$rc_status" in
		0)
			# The check's own "no files in scope" line, anchored, so a path
			# this check does not govern stays silent (FR-007). Matching the
			# line end keeps it from tripping on a file name.
			if grep -q ': no files in scope$' "$OUT"; then
				return 0
			fi
			add_msg "==> $PROG: $REL ($rc_name)"
			;;
		3)
			# Not a failure. common.sh exits 3 only when neither the native
			# tool nor docker is available, and its message names both, so the
			# hook forwards that message rather than reconstructing knowledge
			# it does not own. Passing this through as a failure would make a
			# container runtime a precondition for editing, which Principle I
			# forbids -- and editorconfig-checker is already absent natively
			# on this machine, so it is a live path.
			rc_why=$(sed -n '$p' "$OUT")
			add_msg "==> $PROG: $REL - $rc_name skipped: $rc_why"
			;;
		*)
			# Stop at the first stopping status; the remaining checks do not
			# run (Principle II).
			emit_msg
			{
				printf '%s: %s failed on %s (exit %s)\n' \
					"$PROG" "$rc_name" "$REL" "$rc_status"
				# The check's own output, UNMODIFIED. It already names the
				# file and the location, which the constitution's Quality
				# Gate section requires, and re-wrapping it risks losing
				# that. stderr, because a PostToolUse hook's stderr is shown
				# to Claude -- the delivery mechanism FR-011's
				# diagnose-and-retry requirement depends on.
				cat "$OUT"
			} >&2
			exit 2
			;;
	esac
}

# The three rewriting checks, in scripts/lint.sh's own CHECKS order. The order
# matters for Markdown, which both `format` and `markdown` govern: Prettier
# writes first, then markdownlint over the rules .markdownlint-cli2.jsonc leaves
# it. The other order is not deterministic, and there is one order in this
# repository rather than two (FR-005).
#
# Only these three: the other four report and cannot fix, so invoking them per
# edit would fail the session on violations the edit did not cause (FR-004).
#
# No extension-to-check mapping here. Each check's collect() declares its own
# globs and exits 0 with "no files in scope" when the path is not its business,
# which keeps that mapping in the one place that owns it.
run_check lint-format.sh
run_check lint-markdown.sh
run_check lint-python.sh

emit_msg
exit 0
