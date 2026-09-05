---
name: ccd-conflict-resolve
description: Use when a git working tree has merge conflicts and the user wants help resolving them — e.g. "I have conflicts", "help me resolve this merge", "fix these conflict markers", "this rebase stopped with conflicts", or after a pull, merge, rebase, cherry-pick or revert has left unmerged paths. Also when a branch is behind and the user wants to integrate the remote work. Not for creating a branch, committing finished work, or opening a merge or pull request.
---

# Resolve merge conflicts

Walks a user from a conflicted working tree to a resolved one: confirms `git` is there, updates the remote, reports exactly what is conflicted and why, proposes resolutions with a justified recommendation, applies only what was approved, and iterates until nothing is left before concluding the interrupted operation.

**Nothing is modified before the user approves it.** That is the property the whole skill is built around, and every rule below exists to keep it true.

## When NOT to use

- Creating a branch — `claude-code-devkit:ccd-branch-push`.
- Committing finished work — `claude-code-devkit:ccd-commit-push`.
- Opening a review request — `claude-code-devkit:ccd-github-pr` or `claude-code-devkit:ccd-gitlab-mr`.
- A conflict inside another skill's workflow. Report it to that skill and let it decide; a rebase started by another workflow is that workflow's to finish.

## Scripts — run them, do not re-derive them

Every deterministic step lives in a script that ships with this skill. Invoke them exactly as written, with `sh` explicit and the variable quoted:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-preflight.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-apply.sh" <mechanism> <path>
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-conclude.sh"
```

`${CLAUDE_SKILL_DIR}` is the directory holding this file, so no install location is written down and a rename of this skill touches nothing else. `sh` is explicit because the executable bit is not documented to survive installation.

**Act on the exit code, never on the prose.** Each script's stderr is a diagnostic for the user; its exit code is what this skill branches on. Never reimplement a script's logic in a bash call, and never parse a script's message to decide what happened.

## Workflow

### 1. Preflight — before anything else

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-preflight.sh"
```

| Exit | Meaning                         | Do                                                                                                                                                                                                                                                                                           |
| ---- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `2`  | `git` is not available          | **Stop.** Tell the user git is not on `PATH` and that nothing was changed. Nothing else in this skill runs.                                                                                                                                                                                  |
| `1`  | Not a git repository            | **Stop.** Say so.                                                                                                                                                                                                                                                                            |
| `3`  | The remote could not be reached | Report it, then `AskUserQuestion`: continue against the state already on disk (recommended — the conflict is local and the resolution does not need the remote, at the cost of comparing against a possibly stale base), or stop and retry once the network is back. Never proceed silently. |
| `0`  | Probe succeeded                 | Continue                                                                                                                                                                                                                                                                                     |

Read the printed keys. `operation` and `conflicts` are **independent facts** — a conflicted tree can report `operation none`, because `git merge --squash` records no marker. Never infer one from the other.

### 2. Decide what situation this is

- **`conflicts` is non-zero** → go to step 3. Resolve whatever is in front of you.
- **`conflicts` is zero and `operation` is not `none`** → nothing to resolve; go to step 6 and conclude.
- **`conflicts` is zero, `operation` is `none`, `upstream` is `behind` or `diverged`** → the branch is behind. Propose integrating, per step 2a.
- **`conflicts` is zero, `operation` is `none`, `upstream` is `up-to-date` or `ahead`** → report that there is nothing to do, and stop.

### 2a. Proposing an integration

Only when the branch is behind and no operation is in progress. Present the ways of integrating as options with an explanation of each, a recommendation, and the reason for it — merging preserves history and adds a merge commit; rebasing replays your commits on top and rewrites their hashes, which matters if they are already pushed.

**Do not start anything until the user approves one.** Then run the approved command, and return to step 1.

### 3. Identify

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh"
```

One line per conflicted path: `path`, `kind`, `stages`, `text|binary`.

Report **every** path with its kind before proposing anything. The user needs to see the whole shape of the problem before being asked about any part of it.

### 4. Propose

For each conflicted path, present the candidate resolutions with:

- **an explanation** of what each would do to the content,
- **exactly one recommendation**, and
- **the justification** for that recommendation.

Every option gets an explanation, recommended or not. An option offered without one is a decision the user cannot actually make.

Use `AskUserQuestion`. Aborting the whole operation is always offered alongside the per-path options (see step 5a), and is never the recommendation.

#### Which mechanisms are valid for which kind

| `kind`                              | Offer                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------- |
| `both-modified`                     | `ours`, `theirs`, `union`, or a hand resolution via `staged`              |
| `both-added`                        | `ours`, `theirs`, or `staged` — there is no common ancestor to show       |
| `both-deleted`                      | `remove` — the only question is whether it stays gone                     |
| `added-by-us` / `added-by-them`     | `ours` or `theirs`, whole-file                                            |
| `deleted-by-us` / `deleted-by-them` | keep the modified version, or `remove` to accept the deletion             |
| `type-changed`                      | `ours` or `theirs`, whole-file — the sides are not the same kind of thing |
| `binary`                            | `ours` or `theirs` only. Line-level options are meaningless               |

**Never offer a line-level option for a kind whose sides cannot be merged by lines.** The table is the authority, not the file extension.

#### Never say "ours" and "theirs" to the user

This is the rule most likely to cause real damage if broken.

`--ours` and `--theirs` **reverse under a rebase.** Git's own documentation: during `git rebase` and `git pull --rebase`, "`--ours` gives the version from the branch the changes are rebased onto, while `--theirs` gives the version from the branch that holds your work that is being rebased." A user reading "take ours" during a rebase will believe they are keeping their own work and will get the upstream version instead.

So describe the **effect**, using the `operation` from step 1:

- Under a **merge**: "keep your branch's version, discarding the incoming change from `<branch>`" / "take the incoming version from `<branch>`, discarding your change".
- Under a **rebase**: "keep the version from `<upstream>`, discarding the change in the commit being replayed" / "keep the change in the commit being replayed, discarding `<upstream>`'s version".

Naming the mechanism afterwards is fine. Leading with the label is not.

Where the kind is `both-modified` and all three stages are present, showing the common ancestor helps — `git show :1:<path>` reads it without changing any configuration.

### 5. Apply what was approved

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-apply.sh" <mechanism> <path>
```

One path per invocation, only what the user approved.

| Exit | Meaning                                               | Do                                                              |
| ---- | ----------------------------------------------------- | --------------------------------------------------------------- |
| `0`  | Applied and staged                                    | Continue                                                        |
| `2`  | Not a conflicted path                                 | Report; do not retry blindly                                    |
| `3`  | Mechanism invalid for that path                       | Report which, and re-propose from the valid set                 |
| `4`  | Conflict markers still present after a `staged` apply | **Report it.** Nothing was staged. The file still needs editing |
| `1`  | No repository or no git                               | Stop                                                            |

A hand resolution is: edit the file, then apply with `staged`. The script refuses to stage a file that still carries markers, which is what stops a half-finished edit from being committed as resolved.

### 5a. Abandoning the operation

Always available, never the recommendation. It runs the matching abort for the operation from step 1 — `git merge --abort`, `git rebase --abort`, `git cherry-pick --abort`, `git revert --abort`.

**State the limit when offering it.** Git documents that if there were uncommitted worktree changes present when the merge started, `git merge --abort` "will in some cases be unable to reconstruct these changes". Offer it as a return to the pre-operation state, not as a guaranteed one.

Abort is not a `conflict-apply.sh` mechanism — it acts on the whole operation, not a path — and passing it there is an error.

### 6. Iterate, then conclude

After every applied resolution, run `conflict-list.sh` again.

- **Fewer paths than last pass** → progress. Propose again for what remains.
- **Zero paths** → conclude.
- **The same set as last pass** → **no progress.** Report that the resolution did not resolve what it targeted, then `AskUserQuestion`, `header: "No progress"`: try a different resolution for the same paths (recommended — the previous choice demonstrably did not take, and changing it is the only move that can), open the files and resolve by hand outside this skill, or abort the whole operation. Never loop.

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-conclude.sh"
```

| Exit | Meaning                             | Do                                                                                                                                                                                                                                                                                                   |
| ---- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`  | Concluded                           | Report what was committed                                                                                                                                                                                                                                                                            |
| `2`  | Conflicts remain                    | Go back to step 3                                                                                                                                                                                                                                                                                    |
| `3`  | No operation in progress            | Nothing to conclude; report and stop                                                                                                                                                                                                                                                                 |
| `4`  | Staged paths outside the resolution | **Report each path**, then `AskUserQuestion`: conclude including them (recommended only when the user confirms they belong — they were staged deliberately and discarding that intent is not this skill's to do), conclude after they unstage them by hand, or stop. Never unstage anything yourself |
| `5`  | The concluding command failed       | Report its output. **The resolved content is left in place** — do not revert it                                                                                                                                                                                                                      |

Exit `4` is the guard that keeps unrelated work out of the commit. Concluding commits the whole index and `git commit` refuses to be limited to pathnames during a merge, so this check is the only thing standing between a staged unrelated change and the commit. Never work around it by unstaging on the user's behalf.

## Boundaries / Safety

**Never run any of these**, whatever the situation appears to call for:

- `git reset --hard` — overwrites files and may remove untracked ones.
- `git checkout --force` / `git checkout -f` — documented as a way "to throw away local changes and any untracked files".
- `git clean` — removes untracked files.
- `git stash drop` — the stash is someone's work.
- `git add -A`, `git add .`, `git commit -a` — these are how unrelated work reaches a merge commit.
- `git rerere clear`, or setting `rerere.enabled` — the user's configuration is theirs.
- Setting `merge.conflictStyle` — read it, do not change it. To show a common ancestor, read stage 1 directly.

**Never resolve a conflict on your own judgment.** Not even one that looks obvious, not even a whitespace-only difference, not even when only one option is plausible. Propose it, recommend it, say why — and wait.

**Never discard uncommitted work.** A hand resolution that was never staged has no reflog entry and no rerere record; it exists only in the working tree, and any command that re-materialises the conflict destroys it permanently.

**Never push.** This skill reads from the remote once, in preflight, and writes to it never.

## Tool Reference

| Need                                         | Use                              |
| -------------------------------------------- | -------------------------------- |
| Ask the user to choose                       | `AskUserQuestion`                |
| Read a conflicted file                       | `Read`                           |
| Edit a conflicted file for a hand resolution | `Edit`, then apply with `staged` |
| Everything git                               | the four scripts above           |

## Maintenance

Re-run the scenarios in [evaluations.md](./evaluations.md) after editing this skill or any of its scripts.

**Do not add `disable-model-invocation` to this skill.** It is deliberately reachable both when a user names it and when a conflicted tree is detected without being named — every mutation is already gated on the user's approval, so being reached automatically cannot cause anything to be resolved automatically. The plugin's count of **zero** skills carrying that field is a committed contract at `specs/010-bug-run-ship/contracts/skill-names.md`. This skill's own reason for omitting it changed in feature 006: `ccd-speckit-run` now dispatches it at every step and phase boundary, conditionally on a conflicted working tree, so it falls under the same rule as the other dispatched skills. The second reason still holds independently — every mutation here is gated on the user's approval, so being reached automatically cannot cause anything to be resolved automatically.

The scripts' full interface — every exit code and output field — is `specs/005-merge-conflict-resolution/contracts/conflict-scripts-cli.md`. The git facts the workflow rests on, with their sources, are `specs/005-merge-conflict-resolution/research.md` §3.
