#!/bin/sh
# Scope: one declaration, one file list.
#
# `.lintignore` is the only place exclusions live. This file turns each of its
# lines into a git pathspec exclusion and produces the file list that every
# check consumes. Computing the list once is what makes "all checks agree on
# scope" (FR-013a) a property rather than a hope: six tools with six ignore
# syntaxes cannot be kept in agreement by review.
#
# git is required. It is not a language runtime or a package manager, so
# FR-010 is untouched, and this repository is a git repository by construction.
#
# Sourced, not executed.

LINTIGNORE="$REPO_ROOT/.lintignore"

# exclude_pathspecs
# Emits one NUL-terminated `:(exclude)PATTERN` argument per non-comment line of
# .lintignore. NUL-terminated because a pattern may contain whitespace and this
# is POSIX sh with no arrays to hold them.
exclude_pathspecs() {
	[ -f "$LINTIGNORE" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
			'' | '#'*)
				continue
				;;
			*)
				printf ':(exclude)%s\0' "$line"
				;;
		esac
	done < "$LINTIGNORE"
}

# file_list GLOB...
# NUL-separated, repository-relative paths of every in-scope file matching any
# GLOB. Tracked and untracked-but-not-gitignored files both count: a file that
# is not committed yet is still a file a contributor is about to commit.
file_list() {
	git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1 \
		|| die "$PROG: not a git working tree, so the file list cannot be computed. This check needs git for file enumeration." "$EX_NOGIT"

	{
		for glob in "$@"; do
			printf '%s\0' "$glob"
		done
		exclude_pathspecs
	} | xargs -0 git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard --
}

# count_files GLOB...
# How many files file_list would emit. Used to detect the empty case, which
# must report success rather than failing or staying silent.
count_files() {
	file_list "$@" | tr -dc '\0' | wc -c | tr -d ' '
}

# with_files GLOB... -- CMD...
# Runs CMD with the in-scope file list appended. Empty list -> report and
# succeed, per the spec's Edge Cases section.
#
# Not used by every runner: the ones whose tool takes a directory rather than a
# file list call file_list directly.
