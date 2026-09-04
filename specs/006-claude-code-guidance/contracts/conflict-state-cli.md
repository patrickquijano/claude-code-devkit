# Contract: `conflict-state.sh`

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

The boundary check FR-014 requires. Ships in `skills/ccd-speckit-run/scripts/`, invoked after each step and each phase.

## Invocation

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/conflict-state.sh"
```

No arguments. Operates on the working tree of the current directory. Invoked as `sh <path>`, never executed directly — nothing documents whether the executable bit survives installation, and `sh <path>` is correct either way. The path is quoted so a plugin root containing a space does not split.

In worktree mode this reads the worktree, which is where the run is and where a conflict would be.

## Output

Tab-separated `key<TAB>value` lines on stdout, one per line, in this order. The format matches the plugin's existing scripts — `forge-detect.sh` and `resume-state.sh` — so a reader of one can read all of them.

| Key         | Value                                                            |
| ----------- | ---------------------------------------------------------------- |
| `verdict`   | `clean` or `conflicted`                                          |
| `unmerged`  | count of unmerged paths, `0` when none                           |
| `operation` | `merge`, `rebase`, `cherry-pick`, `revert`, or `none`            |
| `paths`     | one line per unmerged path, repeated; absent when there are none |

Example, clean:

```text
verdict	clean
unmerged	0
operation	none
```

Example, conflicted mid-merge:

```text
verdict	conflicted
unmerged	2
operation	merge
paths	src/auth.py
paths	src/session.py
```

Example, an interrupted rebase that left no conflict in the working tree — the case `git status --porcelain` parsing would miss:

```text
verdict	conflicted
unmerged	0
operation	rebase
```

## How the verdict is reached

`verdict` is `conflicted` when **either** condition holds:

1. `git ls-files -u` returns at least one entry. That is git's own unmerged index, not a rendering of it.
2. Any of these exists under `$(git rev-parse --git-dir)`: `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, or a `rebase-merge/` or `rebase-apply/` directory.

Condition 2 is why the script exists rather than a `git status --porcelain` grep. An interrupted rebase whose conflicts were resolved but never continued leaves a clean-looking working tree and a repository that is still mid-operation; the next phase committing into that state is the failure this check prevents. Porcelain output is also localizable, and its wording is not a stability contract.

`--git-dir` and not `--git-common-dir`: an in-progress operation belongs to the worktree it is running in, and in a worktree those two paths differ.

## Exit status

| Status | Meaning                                                                  |
| ------ | ------------------------------------------------------------------------ |
| `0`    | The check ran. Read `verdict` — **`0` does not mean clean**              |
| `1`    | Not a git repository, or `git` unavailable. Prints `verdict<TAB>unknown` |
| `2`    | A `git` invocation failed unexpectedly                                   |

The caller reads `verdict`, never the exit status, to decide whether the tree is conflicted. Conflating the two is the obvious misuse and is called out here because it would silently turn every conflicted tree into a clean one.

## Constitution compliance

**Principle IV — POSIX shell only.** POSIX `sh`, no bashisms, tabs for indentation, zero findings under shell static analysis in POSIX mode. It lands under `skills/`, which no exclusion declaration names, so the `shell` check reaches it.

**Principle II — fail fast.** Exits non-zero on the first failing condition. The `git ls-files -u` status is checked rather than being swallowed by a pipeline into a counter — the specific bashism-adjacent trap here, since `git ls-files -u | wc -l` reports the status of `wc`, not of `git`.

**Principle I — tooling independence.** `git` and shell builtins only. No package manager, no virtual environment, no install step.

## Caller behaviour

```text
verdict = clean       → record the check, report "checked, clean", continue
verdict = conflicted  → record it, dispatch Skill(skill: "claude-code-devkit:ccd-conflict-resolve")
                        then re-run this script
                        ├─ clean      → resolved: true,  continue
                        └─ conflicted → resolved: false, STOP the run
verdict = unknown     → record it with the reason, continue
                        (a run outside a git repository is supported; Step 1 skips itself)
```

Every verdict is appended to `conflict_checks[]` in the run state as it happens, not batched — a run that is summarized must still be able to report them.

**The run never re-dispatches on a surviving conflict.** The sub-skill iterates internally until nothing is left; a second dispatch that finds the same state is a loop, not a retry. The stop hands the decision back to the user, whose conflict it is.

## Verification

```sh
# Clean tree.
sh skills/ccd-speckit-run/scripts/conflict-state.sh
# expect: verdict<TAB>clean, unmerged<TAB>0, operation<TAB>none

# Real conflict. In a scratch clone, never in a working repository:
#   two branches editing one line, then `git merge` the second into the first.
# expect: verdict<TAB>conflicted, unmerged<TAB>1, operation<TAB>merge, one paths line

# Interrupted operation with a clean tree.
#   start a rebase that conflicts, `git add` the resolution, do not `git rebase --continue`.
# expect: verdict<TAB>conflicted, unmerged<TAB>0, operation<TAB>rebase

# Outside a repository.
cd /tmp && sh < abs-path > /conflict-state.sh
echo "exit=$?"
# expect: verdict<TAB>unknown, exit=1

# POSIX compliance.
shellcheck --shell=sh skills/ccd-speckit-run/scripts/conflict-state.sh
# expect: no output
```

## Regressions this contract exists to catch

**Exit status read as the verdict.** A caller that treats `exit 0` as "clean" skips every conflict the script correctly detected. The script cannot prevent this; the contract names it.

**A rewrite in terms of `git status`.** Someone simplifies the two conditions into one porcelain grep. Unmerged paths are still caught; the interrupted-rebase-with-clean-tree case is not, silently.

**The pipeline masking the exit status.** `git ls-files -u | wc -l` reports `wc`'s status. Principle II forbids it and shell static analysis will not always catch it, so it is stated here.
