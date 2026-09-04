# Merge conflict practices

How to resolve a git merge conflict without losing work, and how to explain one to someone else. Every claim carries its source; where git's own documentation settles nothing, that is recorded as a **GAP**.

Sources are git's manual pages at version 2.55.0 — `git-merge(1)` means `man git-merge`, which is the same text as <https://git-scm.com/docs/git-merge>.

This repository ships a skill that automates the workflow below: `claude-code-devkit:ccd-conflict-resolve`. This document is what it is built on, and is worth reading whether or not you use it.

## Contents

- Find out what is actually happening
- List and classify the conflicts
- See all three sides
- The ours/theirs trap
- Resolving
- Concluding — what actually gets committed
- Getting out
- Avoiding the next one
- Recorded gaps

## Find out what is actually happening

Two questions, and they are **independent**: which operation is in progress, and what is conflicted. Answer them separately.

Which operation is in progress is told by a pseudoref, all of which are documented in one place — `git-rev-parse(1)`, under the `<refname>` resolution rules:

| Ref                | Set during                                  |
| ------------------ | ------------------------------------------- |
| `MERGE_HEAD`       | `git merge`                                 |
| `CHERRY_PICK_HEAD` | `git cherry-pick`                           |
| `REVERT_HEAD`      | `git revert`                                |
| `REBASE_HEAD`      | a rebase stopped on a conflict or an `edit` |
| `AUTO_MERGE`       | the ort strategy, when a merge conflicted   |

Probe one with `git rev-parse --verify --quiet MERGE_HEAD`.

**Check them in git's own order**, the one documented for `git log --merge`: `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `REBASE_HEAD`.

**The trap: `git merge --squash` sets no marker.** It "does not actually make a commit, move the HEAD, or record `$GIT_DIR/MERGE_HEAD`" — so a conflicted squash merge has unmerged index entries and no operation marker at all. Anything that infers "no operation in progress" from "no `MERGE_HEAD`" is wrong here, and anything that infers "a merge is in progress" from "there are conflicts" is wrong in general.

**GAP: `git status --porcelain=v2` carries no field naming the operation.** Its complete header set is `# branch.oid`, `# branch.head`, `# branch.upstream`, `# branch.ab` and `# stash <N>`. Conflicts appear only as `u` records. Porcelain cannot answer "which operation?".

**GAP: `.git/rebase-merge/` and `.git/rebase-apply/` appear in no git manual page.** `git-rebase(1)` names the two backends but never their state directories, and `gitrepository-layout(5)` documents none of the in-progress state. Probe `REBASE_HEAD` instead — it is documented.

## List and classify the conflicts

Three ways, which are not equivalent:

| Command                                | Gives                                                                                    |
| -------------------------------------- | ---------------------------------------------------------------------------------------- |
| `git diff --name-only --diff-filter=U` | each conflicted path once, and nothing else                                              |
| `git ls-files -u`                      | **one line per stage**, so a path appears up to three times, with mode, object and stage |
| `git status --porcelain=v2`            | one line per path, with the conflict code and all three stage modes and hashes           |

For a script, porcelain v2 is usually right: the classification and the path arrive in the same record. It is also the format git documents as stable "for scripts" and "regardless of user configuration".

`git diff --check` is **not** in this list — it warns about conflict markers and whitespace errors in a diff, which also fires on markers accidentally committed long ago.

The classification is a two-character code, and there are exactly seven for unmerged paths (`git-status(1)`, short format):

| Code | Meaning         |
| ---- | --------------- |
| `UU` | both modified   |
| `AA` | both added      |
| `DD` | both deleted    |
| `AU` | added by us     |
| `UA` | added by them   |
| `DU` | deleted by us   |
| `UD` | deleted by them |

The term "merge" here "also includes rebases using the default `--merge` strategy, cherry-picks, and anything else using the merge machinery" — so the same codes apply throughout.

Stage numbers are documented in `gitrevisions(7)`: **stage 1 is the common ancestor, stage 2 is ours, stage 3 is theirs**, and stage 0 means resolved.

**Two things the codes do not tell you.** No code distinguishes a **type change** (file on one side, directory or symlink on the other) or a **binary file** — those are properties of the modes and the content, and must be derived. And a binary conflict deserves separate treatment regardless of its code, because choosing lines is meaningless.

**GAP: git does not document which stages are present for each code.** Only that "the index file records **up to** three versions". The mapping is inferable from `git-read-tree(1)`'s collapse rules but is stated nowhere, so treat it as inference rather than contract.

**GAP: `git status`'s long-format labels are undocumented** — the strings you actually see, "both modified:", "deleted by us:", "Unmerged paths". Only the two-letter codes are documented. Parse the codes, not the prose.

## See all three sides

The default conflict style hides the thing you most need:

> "The default is `merge`, which shows a `<<<<<<<` conflict marker, changes made by one side, a `=======` marker, changes made by the other side, and then a `>>>>>>>` marker. An alternate style, `diff3`, adds a `|||||||` marker and the original text before the `=======` marker … Another alternate style, `zdiff3`, is similar to diff3 but removes matching lines on the two sides from the conflict region when those matching lines appear near either the beginning or end of a conflict region."
>
> — `git-config(1)`, `merge.conflictStyle`

**Recommendation: set `zdiff3`**, if you are on **Git 2.35.0 or later**, which is when it was added. It shows the common ancestor like `diff3` while trimming the matching edges that make `diff3` noisy. Without the ancestor you are guessing at intent from two competing outputs.

```sh
git config --global merge.conflictStyle zdiff3
```

Reading the three sides directly, which needs no configuration change at all:

```sh
git show :1:path        # common ancestor
git show :2:path        # ours
git show :3:path        # theirs
git log --merge -p path # the commits that touched it, HEAD's side first
git diff AUTO_MERGE     # what you have changed so far resolving it
```

`git checkout --conflict=zdiff3 -- <path>` re-materialises an already-conflicted file in a different style without redoing the merge.

## The ours/theirs trap

This is the single most dangerous thing about conflict resolution, and it is documented plainly:

> "Note that during `git rebase` and `git pull --rebase`, **ours** and **theirs** may appear swapped; `--ours` gives the version from the branch the changes are rebased onto, while `--theirs` gives the version from the branch that holds your work that is being rebased."
>
> — `git-checkout(1)`

Said again from the other side: "when a merge conflict happens, the side reported as ours is the so-far rebased series, starting with `<upstream>`, and theirs is the working branch. **In other words, the sides are swapped**" (`git-rebase(1)`).

| During       | `--ours` is                          | `--theirs` is       |
| ------------ | ------------------------------------ | ------------------- |
| a merge      | your branch                          | the incoming branch |
| a **rebase** | the branch you are rebasing **onto** | **your own work**   |

It is not a bug and not configurable — it follows from rebase treating the upstream as the canonical history and your commits as the thing being integrated. It propagates to `git restore --ours/--theirs` and to `-X ours` / `-X theirs`.

**The practical rule: never think in "ours" and "theirs" during a rebase. Think in branch names.** And if you are explaining a choice to someone else, say which branch's content survives, not which flag produces it.

## Resolving

| Want                  | Command                                                                 |
| --------------------- | ----------------------------------------------------------------------- |
| Take one whole side   | `git checkout --ours <path>` / `--theirs <path>` — mind the table above |
| Merge lines from both | `git merge-file --union -p ours base theirs > merged`                   |
| Start this path over  | `git checkout --merge -- <path>`                                        |
| Use a GUI             | `git mergetool`                                                         |
| Edit by hand          | edit the file, remove every marker, then `git add <path>`               |

Whatever you do, **`git add <path>` is what marks a path resolved**, and `git rm <path>` is what marks a deletion as the resolution. Check with `git ls-files -u` — "after resolving conflicts and staging the result, `git ls-files -u` would stop mentioning the conflicted path".

**`-s ours` and `-X ours` are different and the difference destroys work.** `-X ours` resolves conflicting hunks in your favour while still taking the other side's non-conflicting changes. `-s ours` "does not even look at what the other tree contains at all. It discards everything the other tree did." Reach for `-X` if you reach for either; `-s ours` is for deliberately superseding a branch.

### Repeated conflicts: `git rerere`

If you are resolving the same conflict over and over — a long-lived branch repeatedly rebased — `rerere` records your resolutions and replays them:

```sh
git config --global rerere.enabled true
```

`git rerere status` shows what it will record, `git rerere remaining` shows what it could not auto-resolve, `git rerere forget <path>` discards a recorded resolution.

Two documented limits. `rerere.autoUpdate` **defaults to false**, so "git rerere leaves the index file alone" — you still review and `git add`. And it "relies on the conflict markers in the file to detect the conflict", so a file that legitimately contains marker-like lines can defeat it; `conflict-marker-size` in `.gitattributes` is the documented workaround. Submodule conflicts cannot be tracked at all.

## Concluding — what actually gets committed

The most misunderstood part, and the one that quietly commits work you did not mean to ship.

**Concluding commits the whole index. You cannot narrow it to paths.**

> "During a merge resolution, you cannot use `git commit` with pathnames to alter the order the changes are committed, because the merge should be recorded as a single commit. **In fact, the command refuses to run when given pathnames**."
>
> — `git-commit(1)`

Two facts make that manageable:

- Git **already staged the clean part**: "after a merge … stops because of conflicts, cleanly merged paths are already staged to be committed for you". Those belong in the commit.
- Pre-existing local modifications are **left unstaged**, "matching `HEAD`". Ordinary dirty work is not at risk.

What _is_ at risk is anything you had **already staged** before the operation, or anything you stage carelessly during it. So:

**Stage one known path at a time. Never `git add -A`, never `git add .`, never `git commit -a` while resolving.**

Concluding, by operation: `git commit` or `git merge --continue` for a merge (the latter "checks whether there is a (interrupted) merge in progress before calling `git commit`"), and `git rebase --continue`, `git cherry-pick --continue`, `git revert --continue` for the others.

**GAP: what `--continue` does with the index is documented only for merge.** For rebase, cherry-pick and revert the manual pages say nothing about it, so apply the same staging discipline and do not assume a guarantee that is not written down.

## Getting out

| Command              | Effect                                                       |
| -------------------- | ------------------------------------------------------------ |
| `git merge --abort`  | reconstruct the pre-merge state                              |
| `git rebase --abort` | reset `HEAD` back to the original branch                     |
| `git merge --quit`   | forget the merge, **leave the index and working tree as-is** |
| `git rebase --quit`  | same, and `HEAD` is **not** reset either                     |

`--abort` and `--quit` look adjacent and are not. `--quit` leaves you with a half-resolved tree and no operation in progress, which is usually the worst of both.

**`--abort` is not a guaranteed undo:**

> "If there were uncommitted worktree changes present when the merge started, `git merge --abort` **will in some cases be unable to reconstruct these changes.** It is therefore recommended to always commit or stash your changes before running `git merge`."

### The commands that destroy work

Do not reach for these to get out of a conflict:

- `git reset --hard` — "may overwrite untracked files".
- `git checkout --force` — "used to throw away local changes and any untracked files or directories that are in the way".
- `git clean` — removes untracked files.
- `git stash drop` — removes a stash entry.

Use `git reset --merge` instead where you need a reset: it "mainly exists to reset unmerged index entries" and keeps changes that differ between index and working tree. The documented contrast is explicit — `git reset --hard ORIG_HEAD` "will discard your local changes", `git reset --merge ORIG_HEAD` "keeps your local changes".

**GAP: neither `git-reset(1)` nor `git-stash(1)` carries an explicit data-loss warning** for `--hard` or for `drop`. The danger is real and the manual pages do not flag it in the terms you would expect, which is why it is spelled out here.

### If you lose a resolution

`ORIG_HEAD` holds where `HEAD` was before a merge, rebase, reset or am. The reflog holds where refs used to point. And `git fsck --lost-found` writes dangling objects out — critically, "if the object is a blob, the contents are written into the file, rather than its object name", which is what makes it usable for a lost resolution.

**GAP: git documents no end-to-end recovery procedure for a discarded resolution**, and there is a hard limit underneath it. A hand resolution that was **never staged** was never an object, so nothing can recover it — not the reflog, not `fsck`, not rerere. It exists only in the working tree, and any command that re-materialises the conflict destroys it.

That is the single best argument for staging incrementally as you resolve.

## Avoiding the next one

- **`merge.renormalize`** converts content to a canonical form before merging, "to reduce unnecessary conflicts" — aimed at branches with differing line-ending or clean-filter rules.
- **`-Xignore-space-change`** and its siblings treat whitespace-only changes as unchanged, with documented tie-breaks in both directions.
- **`-Xdiff-algorithm=histogram`** "can help avoid mismerges that occur due to unimportant matching lines (such as braces from distinct functions)". The default ort strategy already uses it.
- **`merge=union`** in `.gitattributes` takes lines from both sides instead of leaving markers — with git's own blunt warning: "This tends to leave the added lines in the resulting file in random order and the user should verify the result. **Do not use this if you do not understand the implications.**"
- **`git rebase --update-refs`** (Git 2.38.0+) force-updates branches pointing at rebased commits, though "any branches that are checked out in a worktree are not updated in this way".

One documented surprise no setting fixes: "if a change is made on both branches, but later reverted on one of the branches, that change will be present in the merged result … It occurs because only the heads and the merge base are considered."

## Recorded gaps

- No field in `git status --porcelain=v2` names the operation in progress.
- `.git/rebase-merge/` and `.git/rebase-apply/` are documented in no manual page.
- No manual page states that probing the pseudorefs is _the_ supported way to identify the operation.
- Which stages are present for each `XY` code is not documented.
- `git status`'s long-format labels are not documented.
- `git-add(1)` never mentions merges or conflicts; `git-rm(1)` documents no role in resolving a delete conflict.
- Index behaviour of `--continue` is documented only for merge.
- No data-loss warning on `git reset --hard` or `git stash drop`.
- No end-to-end recovery procedure for a lost resolution.
- There is no `merge.ours` configuration variable — "ours" exists only as `-s ours` and `-Xours`.
- `merge.default` is referenced by `gitattributes(5)` but absent from `git-config(1)`.
