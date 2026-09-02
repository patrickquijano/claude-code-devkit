#!/bin/sh
# speckit-run Step 0 — report whether a run is already in progress.
#
# Usage: resume-state.sh [spec-root]      spec-root defaults to ./specs
#
# Output, tab separated key/value lines:
#   in-worktree       yes|no
#   state-file        <path>|absent
#   state-file-elsewhere  <path>        (zero or more; sibling worktrees)
#   spec-dir          <path>|none
#   spec.md           yes|no
#   plan.md           yes|no
#   tasks.md          yes|no
#   checklists        <count>
#   tasks-total       <count>
#   tasks-done        <count>
#   suggested-resume  <phase name>
#
# Read-only. Reports what exists; the skill decides what to do about it.
set -u

specroot=${1:-specs}
state=.specify/.speckit-run-state.json

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the target repository" >&2
	exit 1
fi

# A run in worktree mode keeps its state file inside the worktree, because every
# path in that run is relative to it. Resuming from the main checkout would then
# read `state-file absent` and start over on top of finished work, so report both
# this tree and every sibling worktree that holds a state file.
gitdir=$(git rev-parse --absolute-git-dir 2> /dev/null || echo "")
commonref=$(git rev-parse --git-common-dir 2> /dev/null) || commonref=.
commondir=$(cd "$commonref" 2> /dev/null && pwd || echo "")
if [ -n "$gitdir" ] && [ -n "$commondir" ] && [ "$gitdir" != "$commondir" ]; then
	printf 'in-worktree\tyes\n'
else
	printf 'in-worktree\tno\n'
fi

if [ -f "$state" ]; then
	printf 'state-file\t%s\n' "$state"
else
	printf 'state-file\tabsent\n'
fi

# `git worktree list` includes the main checkout and every linked worktree, this
# one among them; skip our own toplevel so the current tree is only reported once,
# by the `state-file` line above.
here=$(git rev-parse --show-toplevel 2> /dev/null || echo "")
git worktree list --porcelain 2> /dev/null \
	| awk '/^worktree /{ $1=""; sub(/^ /, ""); print }' \
	| while IFS= read -r wt; do
		[ -n "$wt" ] || continue
		[ "$wt" = "$here" ] && continue
		[ -f "$wt/.specify/.speckit-run-state.json" ] || continue
		printf 'state-file-elsewhere\t%s\n' "$wt/.specify/.speckit-run-state.json"
	done

# Prefer the spec directory whose slug matches the current branch, else the
# highest-numbered one, which is the feature Spec Kit created most recently.
#
# Only NNN-slug directories are candidates. A plain `sort | tail -1` over every
# subdirectory picks whatever sorts last in byte order, so a templates/,
# archive/ or _shared/ directory would win over the real feature. `sort -V`
# also keeps 010 above 9 once a repo passes three digits; not every sort has
# it, so fall back to plain sort, which is correct for zero-padded names.
branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null || echo "")
specdir=""
if [ -d "$specroot" ]; then
	if [ -n "$branch" ] && [ "$branch" != "HEAD" ] && [ -d "$specroot/$branch" ]; then
		specdir="$specroot/$branch"
	else
		if printf '%s\n' 1 | sort -V > /dev/null 2>&1; then
			sortcmd="sort -V"
		else
			sortcmd="sort"
		fi
		specdir=$(find "$specroot" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9]-*' 2> /dev/null | $sortcmd | tail -1)
	fi
fi

if [ -z "$specdir" ]; then
	printf 'spec-dir\tnone\n'
	printf 'spec.md\tno\nplan.md\tno\ntasks.md\tno\nchecklists\t0\ntasks-total\t0\ntasks-done\t0\n'
	printf 'suggested-resume\tPhase 1 (constitution)\n'
	exit 0
fi

printf 'spec-dir\t%s\n' "$specdir"
for f in spec.md plan.md tasks.md; do
	if [ -f "$specdir/$f" ]; then printf '%s\tyes\n' "$f"; else printf '%s\tno\n' "$f"; fi
done

checklists=0
[ -d "$specdir/checklists" ] && checklists=$(find "$specdir/checklists" -type f -name '*.md' 2> /dev/null | wc -l | tr -d ' ')
printf 'checklists\t%s\n' "$checklists"

total=0
done_count=0
if [ -f "$specdir/tasks.md" ]; then
	# grep -c prints the count and exits 1 when it is zero, so `|| echo 0`
	# would append a second line and break the numeric test below.
	total=$(grep -cE '^[[:space:]]*- \[[ xX]\]' "$specdir/tasks.md" 2> /dev/null) || true
	done_count=$(grep -cE '^[[:space:]]*- \[[xX]\]' "$specdir/tasks.md" 2> /dev/null) || true
	total=${total:-0}
	done_count=${done_count:-0}
fi
printf 'tasks-total\t%s\n' "$total"
printf 'tasks-done\t%s\n' "$done_count"

if [ ! -f "$specdir/spec.md" ]; then
	resume='Phase 2 (specify)'
elif [ ! -f "$specdir/plan.md" ]; then
	resume='Phase 5 (plan)'
elif [ ! -f "$specdir/tasks.md" ]; then
	resume='Phase 6 (tasks)'
elif [ "$total" -gt 0 ] && [ "$done_count" -lt "$total" ]; then
	resume='Phase 8 (implement)'
else
	resume='Step 5 (verify)'
fi
printf 'suggested-resume\t%s\n' "$resume"
