# Workspace modes — current checkout, or a fresh worktree

Step 1 decides two things, not one: which branch this feature is cut from, and **which working tree the run happens in**. `reference/base-branch.md` owns the branch. This file owns the tree.

## Contents

- Why the choice exists
- What each mode costs
- 1b — ask
- Worktree mode: create, exclude, enter, verify
- Copy env files
- What worktree mode changes in later steps
- Restrictions that make worktree mode unavailable
- 6d — teardown
- Never

## Why the choice exists

Checkout mode moves the user's own working tree. It switches branch under whatever is currently open, carries uncommitted changes across, stashes them when they collide, and **stops the run** when `git stash pop` conflicts. That is the single most likely way a run dies before Phase 1, and it dies holding the user's uncommitted work in a stash.

Worktree mode does not touch the user's tree at all. A second working directory is created off the chosen base, the run happens entirely inside it, and the tree the user left open is byte-for-byte where they left it — same branch, same uncommitted edits, same open editor buffers.

Neither is correct in general, which is why it is asked rather than assumed.

## What each mode costs

|                            | Checkout mode                                     | Worktree mode                                                                                                                                                                   |
| -------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User's open tree           | switched, possibly stashed                        | untouched                                                                                                                                                                       |
| Uncommitted work at Step 1 | rides along, or blocks the run                    | stays in the main checkout, out of the feature entirely                                                                                                                         |
| Dirty-tree snapshot        | load-bearing: separates user dirt from run output | near-empty by construction, still taken                                                                                                                                         |
| Disk                       | none                                              | a second full checkout of the tree                                                                                                                                              |
| Tooling                    | whatever already runs in that directory           | language servers, watchers and installed dependencies are **per directory** — `node_modules`, `.venv`, `target/` are not shared, so a first build in the worktree is a cold one |
| Feature branch at Step 6c  | protected by a hand-written override              | protected by `cleanup-plan.sh` itself, because it is checked out                                                                                                                |
| Extra teardown decision    | none                                              | 6d                                                                                                                                                                              |

The dependency point is the one that surprises people: a worktree shares the object store, not the untracked build tree. A repo whose test command needs an install step will need it again in the worktree, and Step 5's check pays for that.

## 1b — Ask

Asked in the **same** `AskUserQuestion` call as the base-branch question — two questions, one call, per `reference/base-branch.md`. Neither answer depends on the other, so batching costs nothing and saves the user a round trip.

`header: "Workspace"`, two options:

1. `Fresh worktree (Recommended)` — the run gets its own directory off the chosen base; the tree you have open now is not touched, and nothing is stashed. Say the worktree's path and that it is excluded from git status. Cost: a second checkout on disk, and a cold first build for whatever Step 5 runs.
2. `Current checkout` — the run switches this tree to the base branch, carrying any uncommitted changes with it, and stashes them if they collide. Cost: your open tree moves, and a stash collision stops the run.

Recommend the worktree **unless** one of the Restrictions below applies. When one does, do not offer the option at all — say which restriction ruled it out and ask only the branch question.

Not a git repo → neither mode applies; Step 1 skips itself entirely, per `reference/base-branch.md`.

Record the answer as `workspace` in state before doing anything with it.

## Worktree mode: create, exclude, enter, verify

Four commands, in this order, none of them skippable.

### Create — always detached

Capture the original checkout's path first — it is the copy source for the next section, and it is not recoverable once `EnterWorktree` moves the session:

```bash
orig_dir=$(git rev-parse --show-toplevel)
```

```bash
git worktree add --detach <path> <base>
```

`--detach` is not a preference. `git worktree add` **refuses a branch that is already checked out in another worktree**, and the chosen base is very often exactly that — it is where the user was sitting when they invoked the run. Detaching at the base's commit sidesteps that refusal completely, and costs nothing: Phase 2 (`specify`) cuts the feature branch off `HEAD`, which is what a detached worktree has. Never reach for `--force` to work around the refusal; it is the wrong tool for this and it puts two trees on one branch.

Base is remote-only → `git worktree add --detach <path> origin/<base>`.

Path: `.claude/worktrees/<name>`, resolved to an absolute path. `<name>` is a short slug of the task description. Path already exists → append `-2`, `-3`; never write into a directory that is already there.

That location is deliberate. It is where Claude Code's own `EnterWorktree` puts worktrees, which keeps a later `EnterWorktree` switch legal — that tool only accepts a target under `.claude/worktrees/` of the same repository once the session is already inside a worktree.

### Exclude

A worktree created inside the repo is an untracked directory, so `git status` reports it and `dirty-diff.sh` files it under `new` — the run's own workspace counted as the run's output.

```bash
printf '%s\n' '/.claude/worktrees/' >> "$(git rev-parse --git-common-dir)/info/exclude"
```

`--git-common-dir`, not `--git-dir`: in a worktree those differ, and only the common one is shared. `.git/info/exclude` is never committed and is not a file the user maintains, so appending to it changes nothing they track. Append once — check for the line before adding it.

### Enter

```text
EnterWorktree(path: "<absolute path>")
```

**This tool call is what makes worktree mode work, and there is no substitute for it.** `git worktree add` creates a directory; it does not move the session. Every Spec Kit phase command runs in the session's working directory, so without this call all eight phases run in the _old_ checkout while the worktree sits empty — the exact failure worktree mode exists to prevent, arriving silently.

Pass `path`, never `name`. `EnterWorktree(name: …)` creates its own worktree and picks its own base ref from the `worktree.baseRef` setting — `origin/<default-branch>` by default — which discards the base the user just chose in the same call.

### Verify

Do not trust the call; confirm the move:

```bash
pwd
git rev-parse --show-toplevel
git rev-parse --git-common-dir # differs from --git-dir inside a worktree
```

Toplevel is not the worktree path → the session did not move. Stop and say so. Never run Phase 1 on the assumption the enter succeeded.

Then take the dirty snapshot as normal, in the new directory:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/speckit-run/scripts/dirty-diff.sh" snapshot .specify/.speckit-dirty-snapshot
```

It will record close to nothing, which is the point — a fresh worktree has no pre-existing dirt, so everything 6a later finds is unambiguously this run's.

### Copy env files

`git worktree add` checks out tracked history only. `.env*`, `appsettings*.json`, and the rest of a repo's untracked local config are gitignored on purpose and exist solely in the original checkout — a fresh worktree starts without them, and Step 5's check fails looking for config that was never missing before worktree mode existed.

Copy them across right after Verify, while `orig_dir` from the Create step still points at the tree that has them:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/speckit-run/scripts/copy-env-files.sh" "$orig_dir" "<path>"
```

Recognized patterns: `.env` / `.env.*`, `appsettings*.json`, `local.settings.json`, `secrets.yml` / `secrets.*.yml`, `master.key`. The script skips anything git already tracks in `$orig_dir` — a tracked file is already in the worktree via checkout, and overwriting it risks clobbering a version the feature branch legitimately differs on. No output at all means no matching untracked files existed, which is the common case and not a failure.

This runs once, here — not per-phase, and not again at 6d. A file added to the original checkout mid-run does not retroactively appear in the worktree; that is expected, not a bug to chase.

### One more check, after Phase 2

The worktree starts detached. `specify` is what puts it on a branch, so once Phase 2 reports:

```bash
git symbolic-ref --short -q HEAD
```

Empty → the run is still detached, `specify` did not create the feature branch, and every later commit would land nowhere reachable. Treat it as Phase 2 having failed: record `failed`, report it, and ask, per `SKILL.md`'s failed-phase rule. Never carry a detached HEAD into Phase 5.

## What worktree mode changes in later steps

| Step       | Change                                                                                                                                                                                                                                                                         |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1c–1d      | No `git switch`, no `git stash`, no carry, no collision. `stash_ref` stays null — worktree mode cannot produce one.                                                                                                                                                            |
| State file | Lives at `.specify/.speckit-run-state.json` **inside the worktree**, because every path in this run is relative to the worktree. A resume started from the main checkout will not find it there; `resume-state.sh` scans sibling worktrees for exactly this reason.            |
| 5          | The check runs in the worktree. Its dependencies are the worktree's, and may need installing first. Report that as part of the check, not as a failure.                                                                                                                        |
| 6a         | Whatever the main checkout has dirty is irrelevant here and must not be reported as this run's. The snapshot handles it; the partition is trustworthy precisely because the tree started clean.                                                                                |
| 6c         | `cleanup-plan.sh` prints `keep — checked out in a worktree` for the feature branch on its own, so the hand-written feature-branch override in `reference/ship.md` is already satisfied. State that the script protected it, rather than claiming an override that did nothing. |
| 6d         | Exists only in this mode.                                                                                                                                                                                                                                                      |
| 7          | Report the mode, the worktree path, and whether the worktree still exists.                                                                                                                                                                                                     |

## Restrictions that make worktree mode unavailable

Probe these before offering the option. Any hit → worktree mode is not offered, and the reason is stated.

| Condition                                   | Probe                                                     | Why                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Repo has submodules                         | `test -f .gitmodules`                                     | Git's own docs: multiple checkouts of a superproject are not recommended and submodule support is incomplete.                                                                                                                                                                                                                                                                                                                        |
| `git worktree` unsupported                  | `git worktree list` exits non-zero                        | Predates the feature, or a plumbing restriction.                                                                                                                                                                                                                                                                                                                                                                                     |
| `EnterWorktree` unavailable in this session | the tool is not present                                   | Without it the session cannot move, and the mode silently degrades to phases running in the wrong tree.                                                                                                                                                                                                                                                                                                                              |
| Already inside a worktree                   | `git rev-parse --git-common-dir` differs from `--git-dir` | Report it and offer the current tree; nesting a run's worktree inside another run's is confusion with no upside. Record that case as `workspace: "worktree"` with `worktree.created: false` and the existing path — **not** as `checkout`, which would be false, and which would leave Step 7 describing a worktree run as a checkout run. `created: false` is what tells 6d to skip teardown: the tree is not this run's to remove. |

Bare repo, or a repo with no commits, is not a restriction — `--detach` on a base that exists works in both.

## 6d — Teardown

Worktree mode only. After 6c, before Step 7.

Default is **stay**. The run ends in the worktree, on the feature branch, exactly as checkout mode ends on the feature branch: review has not happened, and a review comment means editing this tree. Leaving is the choice, not the default.

Ask with `AskUserQuestion`, `header: "Worktree"`:

1. `Stay in the worktree (Recommended)` — nothing runs. The session stays where the review will need it. The main checkout is untouched and always has been.
2. `Return to the original directory, keep the worktree` — `ExitWorktree(action: "keep")`. The worktree and its branch stay on disk; come back with `EnterWorktree(path: …)`.
3. `Return and remove the worktree` — `ExitWorktree(action: "keep")`, then `git worktree remove <path>`. Offer this **only** when 6a reported no `new` uncommitted paths and the branch is pushed. Otherwise the option is not offered, and the reason is said out loud: removing the tree discards work that exists nowhere else.

`ExitWorktree(action: "remove")` does not apply here. That action only removes a worktree the tool itself created with `name`; one entered by `path` is left on disk whatever is passed, so removal is the explicit `git worktree remove` above.

Record the outcome in `worktree.teardown` and report it at Step 7.

## Never

- Never `git worktree add --force` to get past the already-checked-out refusal. Use `--detach`.
- Never `git worktree remove --force`. It discards uncommitted work in that tree, which is the run's entire output.
- Never remove a worktree that 6a reported dirty, whatever the user's earlier skip-approval phrase said. A skip phrase covers approval of proposed content, never a deletion.
- Never `git worktree prune` — it is repo-wide, and it is not this run's business to expire another worktree's metadata.
- Never run the phases without confirming the session actually moved. A worktree created and not entered is worse than no worktree: the run looks isolated and is not.
- Never write the state file into the main checkout while running in a worktree. One run, one tree, one state file.
