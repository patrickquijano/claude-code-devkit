#!/bin/sh
# Preflight for ccd-pipeline-fix: which forge, can we read its pipelines, and what failed.
#
# Read the `verdict` line, never the exit status. `exit 0` means the probe ran -- a repository
# with no remote, no CLI, or no failed run all exit 0 and say so, because each is an ordinary
# outcome the skill continues from rather than a failure.
#
# The forge is decided ONCE, here, by the shared forge-detect.sh. Never re-derived downstream:
# a hostname inside a pasted log says nothing about where this repository lives.
#
# Contract: specs/011-narrow-gates-pipeline-fix/contracts/pipeline-fix-interface.md

# SC2310: `have` is a predicate, so `set -e` being disabled inside these conditions is the
# intended behaviour -- a missing CLI is a branch, not an error.
# shellcheck disable=SC2310
set -eu

LIMIT=${PIPELINE_FIX_LIMIT:-10}

emit() {
	printf '%s\t%s\n' "$1" "$2"
}

have() {
	command -v "$1" > /dev/null 2>&1
}

INSIDE=0
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || INSIDE=$?
if [ "$INSIDE" -ne 0 ]; then
	emit forge none
	emit retrieval-path maintainer-supplied
	emit evidence 'not a git work tree'
	emit verdict 'skip: not a git repository'
	exit 0
fi

# The shared detector lives in ccd-speckit-run and is reached, never forked. A fork of a shared
# script is the regression this plugin already records against branch-options.sh.
DETECT="${CLAUDE_PLUGIN_ROOT:-}/skills/ccd-speckit-run/scripts/forge-detect.sh"
FORGE=unknown
FORGE_CLI=none

if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$DETECT" ]; then
	DETECT_OUT=$(sh "$DETECT" 2> /dev/null) || DETECT_OUT=''
	FORGE=$(printf '%s\n' "$DETECT_OUT" | awk -F'\t' '$1 == "forge" { print $2 }')
	FORGE_CLI=$(printf '%s\n' "$DETECT_OUT" | awk -F'\t' '$1 == "cli" { print $2 }')
	[ -n "$FORGE" ] || FORGE=unknown
	[ -n "$FORGE_CLI" ] || FORGE_CLI=none
else
	emit note "forge-detect.sh not reachable at $DETECT"
fi

emit forge "$FORGE"
emit forge-cli "$FORGE_CLI"

BRANCH=$(git symbolic-ref --short -q HEAD 2> /dev/null) || BRANCH=''
[ -n "$BRANCH" ] && emit branch "$BRANCH"

# Authentication is probed here rather than at first use: a CLI that fails per call turns a
# missing login into a mid-run surprise, and the skill must announce its retrieval path first.
CLI_STATUS=absent
case "$FORGE_CLI" in
	gh)
		if have gh; then
			if gh auth status > /dev/null 2>&1; then
				CLI_STATUS=ready
			else
				CLI_STATUS=unauthenticated
			fi
		fi
		;;
	glab)
		if have glab; then
			if glab auth status > /dev/null 2>&1; then
				CLI_STATUS=ready
			else
				CLI_STATUS=unauthenticated
			fi
		fi
		;;
	*)
		CLI_STATUS=n-a
		;;
esac

emit cli-status "$CLI_STATUS"

if [ "$CLI_STATUS" = ready ]; then
	emit retrieval-path cli
else
	emit retrieval-path maintainer-supplied
fi

CANDIDATES=0

if [ "$CLI_STATUS" = ready ] && [ "$FORGE" = github ]; then
	RUNS=$(gh run list --status failure --limit "$LIMIT" \
		--json databaseId,name,headBranch,createdAt \
		--template '{{range .}}{{.databaseId}}	{{.name}}	{{.headBranch}}	{{.createdAt}}{{"\n"}}{{end}}' \
		2> /dev/null) || RUNS=''
	if [ -n "$RUNS" ]; then
		printf '%s\n' "$RUNS" | while IFS= read -r _row; do
			[ -n "$_row" ] || continue
			emit failed-run "$_row"
		done
		CANDIDATES=$(printf '%s\n' "$RUNS" | grep -c .) || CANDIDATES=0
	fi
fi

if [ "$CLI_STATUS" = ready ] && [ "$FORGE" = gitlab ]; then
	PIPES=$(glab ci list --status failed --per-page "$LIMIT" 2> /dev/null) || PIPES=''
	if [ -n "$PIPES" ]; then
		printf '%s\n' "$PIPES" | while IFS= read -r _row; do
			[ -n "$_row" ] || continue
			emit failed-pipeline "$_row"
		done
		CANDIDATES=$(printf '%s\n' "$PIPES" | grep -c .) || CANDIDATES=0
	fi
fi

emit candidates "$CANDIDATES"

case "$CLI_STATUS" in
	ready)
		if [ "$CANDIDATES" -eq 0 ]; then
			emit verdict 'skip: no failed run found'
		else
			emit verdict ready
		fi
		;;
	unauthenticated)
		emit verdict "skip: $FORGE_CLI is installed but not authenticated"
		;;
	absent)
		emit verdict "skip: $FORGE_CLI is not installed"
		;;
	*)
		emit verdict "skip: no supported forge (forge=$FORGE)"
		;;
esac

exit 0
