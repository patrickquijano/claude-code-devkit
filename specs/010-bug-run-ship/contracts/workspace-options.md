# Contract: the two workspace questions, and both guards

`ccd-speckit-bug-run` asks about the workspace exactly twice — once before Stage 1, once after the review request exists. Both option sets are mirrored from `skills/ccd-speckit-run/reference/ship.md` and `reference/worktree.md`; the reasoning lives there and is cited rather than restated.

## Question 1 — Step 1, before any stage runs

`AskUserQuestion`, `header: "Workspace"`. Asked in every run, including one that will skip every stage, because remediation edits source files and the choice must precede that.

Options offered depend on what preflight found:

| Option                         | Offered when                                                                                            | Effect                                                                                                                                                |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Fresh worktree (Recommended)` | `tooling.worktree_supported` and `tooling.enter_worktree`, and the session is not already in a worktree | `git worktree add --detach <path> <base>`, append the exclude line, `EnterWorktree(path:)`, **verify the session moved**, copy untracked local config |
| `New branch here`              | always, in a git repository                                                                             | `git switch -c <name>` in the current tree, carrying uncommitted changes                                                                              |
| `Stay on the current branch`   | always, in a git repository                                                                             | nothing runs                                                                                                                                          |
| `Stay in this worktree`        | replaces the first two when already inside a worktree                                                   | nothing runs; `worktree.created` is `false`                                                                                                           |

Rules:

- **A choice that cannot be carried out is not offered, and its absence is explained** (FR-002). Submodules present, `git worktree` unsupported, or `EnterWorktree` unavailable each withhold the worktree option with the reason named.
- The recommended option is the worktree when it is available, because it leaves the maintainer's open tree untouched (`reference/worktree.md`).
- `workspace` is written to state **the moment the answer returns**, before the mode is acted on (FR-006).
- Worktree mode **must verify** with `git rev-parse --show-toplevel` that the session actually moved. Creating a directory does not move the session; without the check, every stage runs in the old tree while looking isolated.
- Not a git repository → the whole question is skipped, recorded as such, and the run continues. Never `git init`.

## Question 2 — Step 4c, after the review request exists

`AskUserQuestion`, one call. Which option set depends on `workspace`. Skipped, with the reason recorded, when no review request was raised (FR-026) — with nothing to leave the workspace _for_, the run ends where it is.

**Checkout mode** — `header: "Branch"`:

1. `Stay on the branch (Recommended)` — nothing runs.
2. `Switch to <target>, keep the branch` — `git switch <target>`.
3. `Switch to <target> and delete the branch` — then `git branch -d <branch>`.

**Worktree mode** — `header: "Worktree"`. Skipped when `worktree.created` is false (FR-025).

1. `Stay in the worktree (Recommended)` — nothing runs.
2. `Exit, keep the worktree` — `ExitWorktree(action: "keep")`, returning to `worktree.original_dir`.
3. `Exit and remove the worktree` — the same, then `git worktree remove <path>`.
4. `Exit, remove the worktree, delete the branch` — the same, then `git branch -d <branch>` from the original directory.

`<target>` is the review request's target branch, learned from the review skill's result. It is never supplied _to_ that skill, which asks for it itself.

## The two guards

They are different, and conflating them is the failure this section exists to prevent.

| Action              | Guarded on                                                     | Why                                                                                                                                      |
| ------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Deleting a branch   | its commits being pushed                                       | history exists on the remote; `git branch -d` enforces this itself and its refusal is a signal, never something to work around with `-D` |
| Removing a worktree | **no** uncommitted path in that directory, whatever its origin | `git worktree remove` discards the whole directory, so where the work came from makes no difference to its being gone                    |

- A guarded-out option is **not offered**, and the reason is said out loud rather than the option quietly vanishing (FR-024).
- **No skip-approval phrase reaches either.** A skip phrase covers approval of proposed content, never a deletion (FR-027).
- `git worktree remove --force` is never used. `git branch -D` is never used.
- `ExitWorktree(action: "remove")` does not apply: that action only removes a worktree the tool itself created with `name`; one entered by `path` is left on disk whatever is passed. The removal is the explicit `git worktree remove`.
- The outcome is **verified** with `git worktree list` and `git branch --list` rather than trusted, and recorded in `worktree.teardown` or `branch.teardown` (FR-028).

## Why the recommended option is the least destructive in both sets

The review request has been raised and nobody has read it. The branch is where a reviewer's comment will be answered, and the worktree is where the run's work lives. Recommending disposal at the one moment the change is least settled is the wrong default (FR-023).
