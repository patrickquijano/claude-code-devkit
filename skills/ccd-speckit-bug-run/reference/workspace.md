# Workspace modes — Step 1's choice, Step 4c's teardown

Two questions, one file. Step 1 asks where the work happens, before any stage runs. Step 4c asks where to leave the maintainer, after a review request exists. Both option sets are mirrored from `ccd-speckit-run`'s `reference/worktree.md` and `reference/ship.md` sub-step 6e; the reasoning lives there, and this file states the shape rather than restating the argument.

## Contents

- Why the choice comes first
- Step 1 — the option set
- Worktree mode: create, exclude, enter, verify
- Branch mode, and staying put
- Step 4c — teardown
- The two guards
- Never

## Why the choice comes first

Stage 2 edits source files. Doing that on whatever branch the maintainer happened to be sitting on, in the tree they have open, is how a triage run costs someone their own uncommitted work — and it happens before they have seen a single finding.

Worktree mode does not touch the tree they have open at all. A second working directory is created off the current commit, the run happens entirely inside it, and what they left open is byte-for-byte where they left it. That is why it is recommended wherever it is available.

## Step 1 — the option set

One `AskUserQuestion`, `header: "Workspace"`. **Offer only the applicable options, and say why one is missing rather than letting it be silently absent.**

| Option                         | Offered when                                                             | Effect                                                                      |
| ------------------------------ | ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `Fresh worktree (Recommended)` | worktree supported, `EnterWorktree` available, no submodules, not in one | new directory off `HEAD`; the open tree is untouched and nothing is stashed |
| `New branch here`              | in a git repository                                                      | `git switch -c <name>`, carrying uncommitted changes                        |
| `Stay on the current branch`   | in a git repository                                                      | nothing runs                                                                |
| `Stay in this worktree`        | already inside a worktree; replaces the first two                        | nothing runs; `worktree.created` is `false`                                 |

What withholds the worktree option, and what to say when it does:

| Condition                   | Probe                                                     | Say                                                                   |
| --------------------------- | --------------------------------------------------------- | --------------------------------------------------------------------- |
| Submodules present          | `test -f .gitmodules`                                     | git's own docs advise against multiple checkouts of a superproject    |
| `git worktree` unsupported  | `git worktree list` exits non-zero                        | the feature is unavailable in this repository                         |
| `EnterWorktree` unavailable | the tool is not present in this session                   | without it the session cannot move, and the mode degrades silently    |
| Already inside a worktree   | `git rev-parse --git-common-dir` differs from `--git-dir` | nesting a run's worktree inside another's is confusion with no upside |

**Write `workspace` to state the moment the answer returns**, before acting on it. Step 4c reads it, and a mode held only in the conversation is one a compacted run cannot read.

Not a git repository → skip the whole step, record the reason, continue to Stage 1. Never `git init`.

## Worktree mode: create, exclude, enter, verify

Four commands, in this order, none skippable.

Capture the original directory first — it is where Step 4c returns to, and it is not recoverable once the session moves:

```sh
orig_dir=$(git rev-parse --show-toplevel)
```

```sh
git worktree add --detach < path > HEAD
```

`--detach` is not a preference. `git worktree add` **refuses a branch already checked out in another worktree**, and the current branch is very often exactly that. Detaching sidesteps the refusal entirely, and the branch gets created inside the worktree afterwards. Never reach for `--force`; it puts two trees on one branch.

Path: `.claude/worktrees/<slug>`, absolute. Already exists → append `-2`, `-3`; never write into a directory that is already there. That location is deliberate — it is where Claude Code's own `EnterWorktree` puts worktrees, which keeps a later switch legal.

```sh
printf '%s\n' '/.claude/worktrees/' >> "$(git rev-parse --git-common-dir)/info/exclude"
```

`--git-common-dir`, not `--git-dir`: inside a worktree those differ and only the common one is shared. Append once — check for the line first. Without it the run's own workspace is reported as the run's output.

```text
EnterWorktree(path: "<absolute path>")
```

**This call is what makes worktree mode work, and there is no substitute.** `git worktree add` creates a directory; it does not move the session. Pass `path`, never `name` — `name` makes its own worktree off its own base ref and discards the one just created.

Then **verify**, and do not trust the call:

```sh
git rev-parse --show-toplevel
```

Not the worktree path → the session did not move. **Stop and say so.** Never run Stage 1 on the assumption the enter succeeded; every stage would run in the old tree while the run reported isolation.

Finally, create the branch inside the worktree so the work has somewhere to land — `HEAD` is detached until it does.

## Branch mode, and staying put

Branch mode is `git switch -c <name>`, which carries uncommitted changes along. Where a base other than the current commit is wanted, take candidates from the shared script rather than enumerating branches by hand:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh"
```

Staying put runs nothing at all, and is the honest choice when the maintainer already prepared the branch they want.

## Step 4c — teardown

Entered once Step 4b returned a review-request URL. **Skipped, with the reason recorded, when it did not** — with no review request there is nothing to leave the workspace for, and the run ends where it is.

One `AskUserQuestion`. Which set depends on `workspace`.

**Checkout mode** — `header: "Branch"`:

1. `Stay on the branch (Recommended)` — nothing runs.
2. `Switch to <target>, keep the branch` — `git switch <target>`. The branch stays for a review comment to be answered on.
3. `Switch to <target> and delete the branch` — then `git branch -d <branch>`.

**Worktree mode** — `header: "Worktree"`. Skipped when `worktree.created` is false; a worktree the session was already inside is not this run's to tear down.

1. `Stay in the worktree (Recommended)` — nothing runs.
2. `Exit, keep the worktree` — `ExitWorktree(action: "keep")`, returning to `worktree.original_dir`.
3. `Exit and remove the worktree` — the same, then `git worktree remove <path>`.
4. `Exit, remove the worktree, delete the branch` — the same, then `git branch -d <branch>` from the original directory.

`<target>` is the review request's target branch, learned from the review skill's result. It is never supplied **to** that skill, which asks for it itself.

**The least destructive option is recommended in both sets.** The review request has been raised and nobody has read it. Consult `cleanup-plan.sh` for the branch verdict rather than re-deriving deletion rules:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/cleanup-plan.sh"
```

**Verify the outcome** with `git worktree list` and `git branch --list` rather than trusting the action, and record `worktree.teardown` or `branch.teardown`.

## The two guards

They guard different things, and conflating them is the failure this section exists to prevent.

| Action              | Guarded on                                                     | Why                                                                                            |
| ------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Deleting a branch   | its commits being pushed                                       | history exists on the remote; `git branch -d` enforces this itself and its refusal is a signal |
| Removing a worktree | **no** uncommitted path in that directory, whatever its origin | `git worktree remove` discards the whole directory, so origin is irrelevant — it is all gone   |

**A guarded-out option is not offered, and the reason is said out loud** rather than the option quietly vanishing.

**No skip-approval phrase reaches either question.** A skip phrase covers approval of proposed content, never a deletion.

## Never

- Never `git worktree add --force` to get past the already-checked-out refusal. Use `--detach`.
- Never `git worktree remove --force`. It discards uncommitted work in that tree, which is this run's output.
- Never `git branch -D`. `-d`'s refusal is the guard, not an obstacle.
- Never `ExitWorktree(action: "remove")` for a worktree entered by `path` — that action only removes one the tool itself created with `name`, and leaves a path-entered one on disk whatever is passed. The removal is the explicit `git worktree remove`.
- Never `git worktree prune`. It is repo-wide and not this run's business.
- Never run the stages without confirming the session actually moved.
- Never write the state file into the main checkout while running in a worktree. One run, one tree, one state file.
