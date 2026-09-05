#!/bin/sh
# Answer, in one call, the three factual questions ccd-speckit-bug-run needs before it invokes
# anything: is the bug-triage capability installed here, is the working tree already dirty, and
# is this bug slug already in use.
#
# They are collapsed into one script because they are needed at the same moment and nowhere
# else, and because each is a question with a wrong answer rather than a judgement. That also
# lets evaluations.md exercise them against a fixture, which prose cannot be.
#
# The capability check deliberately tests the COMPILED SKILLS, not just the extension directory.
# `.specify/extensions/bug/` present with `.claude/skills/speckit-bug-*/` absent is a real state
# -- an extension added but never compiled for this agent -- and it fails at dispatch, not here.
# Reporting `capability present` on the strength of the directory alone would hide it.
#
# But the check is one-sided by design: it can report `present`, and otherwise reports
# `undetermined`. It never reports `absent`, because a filesystem probe cannot establish absence
# -- where a compiled skill's files live is an install detail. The caller settles `undetermined`
# against the session's own available-skills listing, which is authoritative.
#
# Output is tab-separated key/value lines, matching conflict-state.sh and forge-detect.sh.
# Contract: specs/009-bug-triage-run/contracts/bug-preflight-cli.md
#
# EXIT STATUS IS NOT THE VERDICT. `exit 0` means the check ran; read the `verdict` line. A
# repository with no bug extension installed exits 0 and says `verdict undetermined: ...`.

set -eu

if [ "$#" -gt 1 ]; then
	printf 'usage: %s [slug]\n' "$0" >&2
	exit 1
fi

raw_slug=${1-}

extension_dir='.specify/extensions/bug'
bugs_root='.specify/bugs'
skills_root='.claude/skills'

# Operate from the repository root when there is one, so a run started in a subdirectory still
# finds `.specify/`. Not a git repository is a normal result, not a failure: the bug extension
# needs no git, and only the dirty-tree question becomes unanswerable.
root=''
in_git=no
if root=$(git rev-parse --show-toplevel 2> /dev/null); then
	in_git=yes
	cd "$root"
fi

# Normalise the slug the way the extension documents: lowercase, hyphen-separated, nothing but
# letters, digits and hyphens. Echoed back so the caller sees what it will actually collide
# against rather than what was typed.
slug='-'
if [ -n "$raw_slug" ]; then
	slug=$(printf '%s' "$raw_slug" \
		| tr '[:upper:]' '[:lower:]' \
		| tr ' _' '--' \
		| sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//')
	if [ -z "$slug" ]; then
		printf 'error: slug "%s" normalises to an empty string\n' "$raw_slug" >&2
		exit 1
	fi
fi

extension_found='-'
if [ -f "$extension_dir/extension.yml" ]; then
	extension_found=$extension_dir
fi

# Resolved once, printed once, and used to decide `capability`. A stage is "found" only if the
# compiled skill body exists, because that is what the run dispatches.
# Written as `if`, not `[ ... ] && var=found`: under `set -e` a failing AND-list at top level
# exits the script, so the terse form would abort the moment a stage is missing -- which is the
# case this check exists to report.
stage_assess=missing
stage_fix=missing
stage_test=missing
if [ -f "$skills_root/speckit-bug-assess/SKILL.md" ]; then
	stage_assess=found
fi
if [ -f "$skills_root/speckit-bug-fix/SKILL.md" ]; then
	stage_fix=found
fi
if [ -f "$skills_root/speckit-bug-test/SKILL.md" ]; then
	stage_test=found
fi

# `present` or `undetermined`, and NEVER `absent`.
#
# A filesystem test can prove that something is here. It cannot prove that something is not: where
# a compiled skill's files live is an install detail, and a skill can be listed and dispatchable
# with nothing on disk where this script thought to look. Reporting `absent` from a miss here is
# how a wrong, confident refusal reaches a consumer whose layout differs from the author's.
#
# So a miss downgrades to `undetermined`, and the caller resolves it against the session's own
# available-skills listing, which is authoritative. See the sibling rule at
# skills/ccd-speckit-run/reference/preflight.md.
capability=undetermined
if [ "$stage_assess" = found ] && [ "$stage_fix" = found ] && [ "$stage_test" = found ]; then
	capability=present
fi

slug_taken='n-a'
if [ "$slug" != '-' ]; then
	slug_taken=no
	if [ -d "$bugs_root/$slug" ]; then
		slug_taken=yes
	fi
fi

# `git status --porcelain` is assigned on its own line and its status checked, never piped into a
# counter: `git status --porcelain | wc -l` reports wc's status, not git's, which Principle II
# forbids and shellcheck does not always catch.
dirty=unknown
dirty_count=0
dirty_paths=''
if [ "$in_git" = yes ]; then
	porcelain=''
	if ! porcelain=$(git status --porcelain); then
		printf 'error: git status --porcelain failed\n' >&2
		exit 1
	fi
	dirty=no
	if [ -n "$porcelain" ]; then
		dirty=yes
		# Columns 1-2 are the status code and column 3 a space, so the path starts at 4. A
		# rename prints `R  old -> new`; the destination is what the caller will see changed.
		dirty_paths=$(printf '%s\n' "$porcelain" | sed 's/^...//; s/^.* -> //')
		saved_ifs=$IFS
		IFS='
'
		for path in $dirty_paths; do
			[ -n "$path" ] || continue
			dirty_count=$((dirty_count + 1))
		done
		IFS=$saved_ifs
	fi
fi

# The script does not emit `blocked`. It cannot: blocking requires having determined absence, and
# this script can only determine presence. `undetermined` hands that decision to the caller, which
# has the available-skills listing this script does not.
verdict=ready
if [ "$capability" = undetermined ]; then
	verdict='undetermined: compiled stage skills not found on disk; resolve against the session listing'
fi

printf 'capability\t%s\n' "$capability"
printf 'extension-dir\t%s\n' "$extension_found"
printf 'stage-assess\t%s\n' "$stage_assess"
printf 'stage-fix\t%s\n' "$stage_fix"
printf 'stage-test\t%s\n' "$stage_test"
printf 'bugs-root\t%s\n' "$bugs_root"
printf 'slug\t%s\n' "$slug"
printf 'slug-taken\t%s\n' "$slug_taken"
printf 'dirty\t%s\n' "$dirty"
printf 'dirty-count\t%s\n' "$dirty_count"
if [ -n "$dirty_paths" ]; then
	saved_ifs=$IFS
	IFS='
'
	for path in $dirty_paths; do
		[ -n "$path" ] || continue
		printf 'dirty-path\t%s\n' "$path"
	done
	IFS=$saved_ifs
fi
printf 'verdict\t%s\n' "$verdict"
