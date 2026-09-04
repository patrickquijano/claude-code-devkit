# Step 1 — Base branch and workspace

Phase 2 (`specify`) cuts the feature branch off `HEAD`. Whatever branch the session starts on becomes the base for every artifact and for Step 6's merge request. Decide it here, before any phase.

Step 1 settles **two** things: the base branch, and which working tree the run happens in. This file owns the branch. `reference/worktree.md` owns the tree — read it before asking 1a, because which options 1a may offer depends on the restriction probes it defines.

Not a git repo → skip the step, record `steps.1 = "skipped: not a git repo"`, continue to Step 2. Never `git init`.

State precondition: `steps.0` is `done`. In checkout mode this step moves the user's own uncommitted work onto another branch → full proposal cycle: propose, approve, execute. Worktree mode moves nothing of the user's, but it still creates a directory and still proposes, because the proposal is where the path and the mode get stated.

## 1a — Gather candidates

Never enumerate branches by hand. Run:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh"
```

Columns: branch, `local` / `remote` / `both`, last commit date, and a fourth column carrying `default`, `current`, both comma-joined in that order, or `-` when neither applies. Order: the repository's default branch first, then by commit date descending, then by name. The script fetches every configured remote, strips the remote prefix, dedupes, and excludes `refs/remotes/<remote>/HEAD` — whose git short form is a bare remote name indistinguishable from a branch called `origin`.

The script is not this skill's file. It ships once, in `ccd-branch-push`, and all four consumers invoke that one copy — which is why the fourth column and the ordering described above differ from what this file said before: the single surviving implementation is the 88-line one the three `auto-*` skills shared, and the 48-line copy this skill used to carry is gone. It emitted a `current`-or-`-` fourth column, ordered by commit date alone, and printed `origin/HEAD` as a branch named `origin`. FR-011 is the requirement that forced the reconciliation; the three defects it removed are recorded in the script's own header comment.

No remote configured → local names only, and the script says so. Failed fetch — offline, auth — goes to stderr and the listing continues from refs already on disk. Neither stops the run; both get reported at the gate.

Exit 1 means not a git repo. Skip the step.

## 1b — Ask: workspace and base branch

**One `AskUserQuestion` call, two questions.** Both answers are needed before anything is created, and neither depends on the other, so batching them costs nothing and saves the user a round trip.

Question one, `header: "Workspace"` — current checkout or a fresh worktree, per `reference/worktree.md`. Run that file's restriction probes first: any hit and the worktree option is not offered at all, the reason is stated, and this call carries only the branch question.

Question two, `header: "Base"` — 4 options max. Order: current branch first, then `dev` and `main` if present, then fill from the script's ordering. Say in the question that "Other" accepts any branch name not listed.

Each branch option's description carries the script's own columns — local, remote-only, or both, plus last commit date. That is what makes the pick informed rather than a guess. Never offer a branch the script did not print.

Write `workspace` to state as soon as the answer returns, before 1c runs. 1c and 1d both branch on it, and a mode held only in the conversation is a mode a compacted run cannot read.

## 1c — Snapshot the dirty tree

Before switching, record what was already dirty, so Step 6 can keep pre-existing edits out of the feature's merge request:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/dirty-diff.sh" snapshot .specify/.speckit-dirty-snapshot
```

Both modes take it. Checkout mode needs it to tell the user's dirt from the run's output. Worktree mode takes it **after** the worktree is entered, where it records close to nothing — and that near-empty snapshot is itself the evidence 6a's partition can be trusted, so it is not skipped for being boring.

## 1d — Worktree mode: create and enter

`workspace` is `worktree` → this replaces everything in 1d below. No `git switch`, no `git stash`, no carry, no collision, and `stash_ref` stays null.

Follow `reference/worktree.md`: `git worktree add --detach`, append the exclude line, `EnterWorktree(path: …)`, then verify the session actually moved before anything else runs. Take 1c's snapshot in the new directory. Write `worktree.path` and `worktree.created` to state.

The verify is the load-bearing part. A worktree created and not entered leaves all eight phases running in the old checkout while the worktree sits empty — the run looks isolated and is not.

## 1d — Checkout mode: switch, carrying uncommitted changes

`workspace` is `checkout`.

Uncommitted changes ride along. `git switch` carries them when they do not collide:

```bash
git switch <branch>
```

Branch exists only on the remote:

```bash
git switch -c <branch> --track origin/<branch>
```

`git switch` refuses because changes collide → recover, do not abort:

```bash
git stash push -u -m speckit-run-base-switch
git switch <branch>
git stash pop
```

Conflicted `git stash pop` → stop the run, report the conflicting paths, leave the stash on the stack. Never `git checkout --force`, never `git stash drop`, never `git reset --hard`.

Record the stash before stopping:

```bash
git stash list --format='%gd %gs' | head -1
```

Write that ref to `stash_ref` in state. A stash holding the user's uncommitted work, with nothing in state pointing at it, is work that Step 0's resume check and Step 7's summary both fail to mention — and the message `speckit-run-base-switch` is the only other trace it was this run that parked it.

## 1e — Report

At the gate: **the workspace mode**, previous branch, selected branch, local or remote-only, paths recorded by the snapshot, and any fetch failure.

Checkout mode adds: whether changes were carried directly or through the stash, and any stash left behind with its `stash_ref`.

Worktree mode adds: the worktree's absolute path, that the session is now inside it and this was verified rather than assumed, that the user's original tree was not touched, and that `HEAD` is detached until Phase 2 puts it on the feature branch.

The one exception is the session that was **already** inside a worktree and chose to stay in it — `worktree.created: false`. Nothing was created, nothing moved, and `HEAD` is on whatever branch that tree already had. Report it as the worktree it is, say that this run did not create it, and say that 6e will therefore not offer to remove it.

Write `previous_branch`, `base_branch`, `workspace`, `worktree`, `stash_ref` and `steps.1` to state. Step 3's prompt-review gate reports the base and the mode, Step 6c's cleanup plan protects the base, 6e reads `worktree`, Step 7 reports the base as what the feature branch was cut from.
