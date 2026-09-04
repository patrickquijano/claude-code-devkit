# Contract: the conflict scripts' CLI

**Feature**: [005-merge-conflict-resolution](../spec.md) | **Date**: 2026-09-04

Four scripts ship inside `skills/ccd-conflict-resolve/scripts/`. This is their interface: how they are invoked, what they print, and what their exit codes mean. FR-015 requires the skill's identification and application steps to be carried out by "deterministic, inspectable procedures distributed with the skill itself" — this document is the inspectable part, and it is what the skill body branches on.

## Invocation

Every script is invoked through `${CLAUDE_SKILL_DIR}`, with `sh` explicit and the variable quoted:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-preflight.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-apply.sh" <mechanism> <path>
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-conclude.sh"
```

`${CLAUDE_SKILL_DIR}` is "the directory containing the skill's `SKILL.md` file", documented for "scripts or files bundled with the skill, regardless of the current working directory" (research §1.6.1). It is **not** `${CLAUDE_PLUGIN_ROOT}`, which is documented for resources shared between a plugin's skills — `branch-options.sh` is that case, these are not. `sh` is explicit because nothing documents the executable bit surviving installation (research §2.6.3); the variable is quoted so a path containing a space does not split.

Every script runs with the repository being operated on as the working directory. None takes a repository path argument: the user's current directory is the subject, and accepting a path would invite the skill to act on a repository the user is not looking at.

## Shared conventions

**Output is tab-separated `key<TAB>value` lines**, the form `branch-options.sh` and `forge-detect.sh` already use in this repository. One record per line, keys stable, values never containing a tab. A consumer reads it with `cut -f1,2` or a `while read` loop and never needs a parser.

**Diagnostics go to stderr, prefixed with a stable token.** `not-a-git-repo:`, `no-git:`, `remote-unreachable:` — the token is the contract, the prose after it is not. This matches `branch-options.sh`, which prints `not-a-git-repo: run this from inside the target repository` to stderr.

**Exit codes are the branch signal, not the output.** A script that cannot answer says so with a code; the skill body never parses prose to decide what happened.

**No script writes to the working tree except `conflict-apply.sh` and `conflict-conclude.sh`.** The other two are read-only with respect to the tree and the index, which is what makes them safe to re-run at any point in the iteration.

**No script mutates configuration.** Not `merge.conflictStyle`, not `rerere.enabled`, not anything. Research §3.4 and §3.6 record both as deliberate: the skill reads the user's configuration and reports what enabling something would do, and never sets it.

**Every script is POSIX `sh`**, opens `#!/bin/sh` then `set -u`, indents with tabs, and passes `shellcheck --shell=sh --severity=style` with zero findings. It exits non-zero on the first failing step and masks no exit status behind a pipeline or subshell.

## `conflict-preflight.sh`

Establishes the Workspace state entity from `data-model.md`. Takes no arguments. Read-only.

Prints, one per line:

| Key                | Values                                                            |
| ------------------ | ----------------------------------------------------------------- |
| `git`              | `available` / `absent`                                            |
| `repo`             | `yes` / `no`                                                      |
| `operation`        | `none` / `merge` / `rebase` / `cherry-pick` / `revert`            |
| `conflicts`        | integer count of unmerged paths                                   |
| `remote`           | `reachable` / `unreachable` / `none-configured` / `not-attempted` |
| `upstream`         | `up-to-date` / `behind` / `ahead` / `diverged` / `no-upstream`    |
| `ahead`            | integer                                                           |
| `behind`           | integer                                                           |
| `staged-unrelated` | integer count of staged paths that are not unmerged               |
| `rerere`           | `enabled` / `disabled`                                            |

Exit codes:

| Code | Meaning                                                                                                                |
| ---- | ---------------------------------------------------------------------------------------------------------------------- |
| `0`  | Probe completed. Read the keys; `git available` and `repo yes` are both guaranteed in this case.                       |
| `1`  | Not a git repository. `not-a-git-repo:` on stderr.                                                                     |
| `2`  | `git` is not available. `no-git:` on stderr, and **nothing else was attempted.**                                       |
| `3`  | The remote update failed. Every other key is still printed from on-disk state, so the skill can offer FR-020's choice. |

**`operation` is determined from the pseudorefs, in the order git itself documents** for `git log --merge`: `MERGE_HEAD`, then `CHERRY_PICK_HEAD`, then `REVERT_HEAD`, then `REBASE_HEAD` (research §3.1.7). Each is probed with `git rev-parse --verify --quiet`. The directories `.git/rebase-merge/` and `.git/rebase-apply/` are **not** consulted, because research §3.1.10 found them documented nowhere.

**`operation` and `conflicts` are independent, and the skill must treat them so.** A conflicted tree can report `operation none` — research §3.1.8 found that `git merge --squash` "does not actually make a commit, move the HEAD, or record `$GIT_DIR/MERGE_HEAD`", so a conflicted squash merge has unmerged entries and no marker. Inferring either field from the other is the bug this separation exists to prevent, and it is the same requirement FR-017 states from the other direction.

Exit code `2` is checked before anything else runs, which is FR-009: the tool's absence is established before the working tree is touched, read, or reasoned about.

`staged-unrelated` is what SC-006a is measured against, and it is captured **here**, before any resolution — capturing it afterwards would make the guarantee unverifiable.

## `conflict-list.sh`

Emits the Conflict report: one line per conflicted path with its classification. Takes no arguments. Read-only.

```text
path<TAB>kind<TAB>stages<TAB>text
```

`kind` is one of the nine values in `data-model.md`. `stages` is a three-character field of `1`/`2`/`3` and `-` showing which stages are present, e.g. `123` for a both-modified path and `-23` for a both-added one. `text` is `text` or `binary`.

Exit codes:

| Code | Meaning                                                                                               |
| ---- | ----------------------------------------------------------------------------------------------------- |
| `0`  | Zero or more conflicted paths were listed. **Zero is a success**, printed as no output, not an error. |
| `1`  | Not a git repository, or `git` unavailable.                                                           |

**Source is `git status --porcelain=v2`**, not `git diff --name-only --diff-filter=U`. The reason is research §3.2.3: the `u` record carries the `<XY>` code and the stage modes in the same line as the path, so one invocation yields path _and_ classification, where `--diff-filter=U` would need a second pass per path. Porcelain is also the format git documents as stable "for scripts" and which "will remain stable across Git versions and regardless of user configuration".

Two consequences of that choice are contract, not incidental. Porcelain v2 emits **one line per path** where `ls-files -u` emits one per stage. And **the order is undefined** — git documents that "tracked entries are printed in an undefined order; parsers should allow for a mixture of the 3 line types in any order" — so this script sorts by path before printing, making its output deterministic where git's is not. SC-005 requires identical reports across runs, and git alone does not provide that.

`kind` derivation, per research §3.3: seven values come from the `<XY>` code directly. `type-changed` and `binary` are derived, because no `XY` code distinguishes either — `type-changed` from the stage mode fields, `binary` from a content test. `binary` wins over any other classification.

## `conflict-apply.sh`

Applies one approved resolution to one path, and stages it. Takes two arguments.

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-apply.sh" <mechanism> <path>
```

`<mechanism>` is one of five, matching `data-model.md`'s Candidate resolution entity exactly:

| `<mechanism>` | Effect                                                       | Valid for                                          |
| ------------- | ------------------------------------------------------------ | -------------------------------------------------- |
| `ours`        | Check out stage 2, then stage the path                       | any `kind` with stage 2 present                    |
| `theirs`      | Check out stage 3, then stage the path                       | any `kind` with stage 3 present                    |
| `union`       | Three-way merge taking lines from both sides, then stage     | `both-modified` text only                          |
| `staged`      | Stage content already written into the working tree by hand  | any text `kind`                                    |
| `remove`      | `git rm -- <path>`, recording the deletion as the resolution | `both-deleted`, `deleted-by-us`, `deleted-by-them` |

**`remove` exists because `both-deleted` has no other resolution.** A `DD` path has neither stage 2 nor stage 3, so `ours` and `theirs` are both invalid for it and every content-selecting mechanism fails. Without `remove`, `conflict-apply.sh` would return exit `3` for every both-deleted path and the skill could report that kind but never resolve it. It also serves the modify/delete cases, where accepting the deletion is one of the two sensible answers. Research §3.7.14 records that `git-rm(1)` documents no role in conflict resolution — the behaviour is real and the documentation is silent, which is why it is written down here.

**Aborting is not a mechanism and is not accepted by this script.** Abandoning the operation acts on the whole operation rather than on one path, so it belongs to the skill body, which runs the `--abort` matching the operation `conflict-preflight.sh` detected. Passing `abort` here is exit `3`. The skill body must also carry research §3.8.3's caveat when it offers that action: `git merge --abort` "will in some cases be unable to reconstruct" uncommitted changes present when the merge started, so it is offered as a return to the pre-merge state rather than a guaranteed one.

**Replaying a rerere-recorded resolution is likewise not a mechanism.** `conflict-preflight.sh` reports whether rerere is enabled and the skill reports what enabling it would do, but nothing here applies a recorded resolution — git does that itself when it is enabled, and it shows up as fewer conflicted paths in the next `conflict-list.sh` pass. Driving it from the skill would mean enabling configuration the user did not ask for.

Exit codes:

| Code | Meaning                                                                                                          |
| ---- | ---------------------------------------------------------------------------------------------------------------- |
| `0`  | Applied and staged.                                                                                              |
| `1`  | Not a git repository, or `git` unavailable.                                                                      |
| `2`  | The path is not unmerged. Nothing was changed.                                                                   |
| `3`  | The mechanism is not valid for that path's `kind` — `union` on a binary file, for instance. Nothing was changed. |
| `4`  | The path still contains conflict markers after a `staged` apply. **Nothing was staged.**                         |

Exit `3` covers every invalid pairing, and the two that matter most are `ours` or `theirs` against a `both-deleted` path — where the stage simply is not there — and `abort`, which is not a mechanism at all.

**Staging is always `git add -- <path>`, one path per invocation**, or `git rm -- <path>` for the `remove` mechanism, which stages the deletion in the same way. Never `git add -A`, never `git add .`, never `git commit -a`. Research §3.7 is why this is contract rather than style: concluding commits the whole index and `git commit` **refuses** to be limited to pathnames during a merge — "the command refuses to run when given pathnames". So the only control over what gets committed is what was staged, and the only way to keep that narrow is to stage exactly one known path at a time.

Exit code `4` exists because a `staged` apply is the one mechanism whose input the script did not produce. Staging a file that still carries `<<<<<<<` markers would mark a conflict resolved that is not, and git would commit the markers. The check is cheap and the failure it prevents is silent.

**`ours` and `theirs` are never surfaced to the user as those words.** Research §3.5 records the reversal: under a rebase, `--ours` is the branch being rebased onto and `--theirs` is the user's own work, which is the opposite of what the words suggest. The script takes the mechanism name because it is an internal interface; the skill body is required to describe the effect in concrete terms — naming the branch and whose change is discarded — using the `operation` value from `conflict-preflight.sh`. FR-012 requires an explanation, and under a rebase the label alone is worse than no label.

## `conflict-conclude.sh`

Concludes the operation once no conflicts remain. Takes no arguments.

Exit codes:

| Code | Meaning                                                                                                                                   |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `0`  | The operation was concluded.                                                                                                              |
| `1`  | Not a git repository, or `git` unavailable.                                                                                               |
| `2`  | Conflicts remain. **Nothing was concluded** — the caller should return to `conflict-list.sh`.                                             |
| `3`  | No operation is in progress, so there is nothing to conclude. Not an error; the tree may simply be clean.                                 |
| `4`  | Staged paths were found that are not part of the resolution. **Nothing was concluded**, and each is printed so the skill can report them. |
| `5`  | The concluding command itself failed. Its stderr is passed through, and **the resolved content is left in place.**                        |

Concluding dispatches on the `operation` value: `git commit --no-edit` for a merge, `git rebase --continue`, `git cherry-pick --continue`, `git revert --continue`. Research §3.7.2 records that `git merge --continue` is a thin wrapper that "checks whether there is a (interrupted) merge in progress before calling `git commit`", so either form works for a merge and the explicit `git commit` is used for its clearer failure output.

**Exit code `4` is the enforcement point for FR-017c**, and it is a refusal rather than a fix. The script does not unstage anything — unstaging is a mutation the user did not approve, and an unrelated staged change might be deliberate. It stops, names the paths, and lets the skill ask. Research §3.7.7 and §3.7.9 bound what this check must look at: git has already staged the _cleanly merged_ paths itself and those belong in the commit, while pre-existing local modifications are left unstaged and are not at risk. What code `4` catches is the narrow real case — a path staged before the operation began, or anything staged beyond the resolution.

**Exit code `5` never reverts.** FR-017b requires reporting why concluding failed and leaving the resolved content in place. Research §3.8.9 is the reason this is stated as contract: an unstaged or uncommitted hand resolution has no reflog entry and no rerere record, so a script that "cleaned up" after a failed conclude could destroy work that exists nowhere else.

## What none of these scripts do

- **No script decides anything.** They report state and apply an already-approved mechanism. Every candidate resolution, every recommendation, and every question belongs to the skill body, which is where the user is.
- **No script calls another.** The skill body sequences them, so each one's output is visible to the user rather than consumed internally.
- **No script loops.** FR-014's iteration lives in the skill body, which is where the approval gate for each pass also lives. A script that looped would resolve a second conflict on the strength of the first one's approval.
- **No script runs `git reset --hard`, `git checkout --force`, `git stash drop`, `git clean`, or `git rerere clear`.** Research §3.8 records that git's own pages carry no data-loss warning on the first three, which is exactly why the prohibition is written here.
- **No script pushes, fetches beyond the single update in `conflict-preflight.sh`, or writes to any remote.**

## Verifying this contract

```sh
# every script is POSIX sh with the required preamble
for f in skills/ccd-conflict-resolve/scripts/*.sh; do
  head -1 "$f" | grep -qx '#!/bin/sh' || echo "BAD SHEBANG $f"
  grep -qx 'set -u' "$f" || echo "NO set -u $f"
done # expect no output

# zero findings at the repository's own settings
shellcheck --shell=sh --severity=style skills/ccd-conflict-resolve/scripts/*.sh # expect exit 0

# no forbidden staging or destructive command anywhere in the skill.
# Comment lines are stripped first: the scripts name the prohibited forms in
# order to record the prohibition, and a check that fires on its own
# documentation is a check the next reader learns to ignore.
grep -nE 'git add (-A|-a|\.)|git commit -a|reset --hard|checkout --force|stash drop|git clean' \
  skills/ccd-conflict-resolve/scripts/*.sh \
  | grep -v ':[0-9][0-9]*:[[:space:]]*#' # expect no output

# scripts are reached through CLAUDE_SKILL_DIR, not CLAUDE_PLUGIN_ROOT
grep -c 'CLAUDE_SKILL_DIR' skills/ccd-conflict-resolve/SKILL.md   # expect 4 or more
grep -c 'CLAUDE_PLUGIN_ROOT' skills/ccd-conflict-resolve/SKILL.md # expect 0
```

## The regression to catch

A script that starts making decisions. The pressure is real and reasonable-sounding: `conflict-list.sh` already knows a path is `both-added`, so it could suggest the mechanism; `conflict-apply.sh` already validates the mechanism, so it could pick a valid one. Each step is small and the endpoint is a skill that resolves conflicts without asking, which FR-012 and FR-016 forbid and which no exit code would reveal.

The second regression is `git add` growing an argument. `git add -A` in any of these scripts silently converts every conclude into a commit of the user's whole working tree, and research §3.7.8 means the commit cannot be narrowed afterwards. The grep above is the check, and counting is the method for the same reason feature 003 counted skills rather than comparing them.
