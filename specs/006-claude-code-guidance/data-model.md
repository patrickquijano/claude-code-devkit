# Data Model: Claude Code guidance and pipeline gating

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

This feature has no database and no application types. Its "entities" are file-shaped and state-shaped: documents with a required structure, frontmatter with validation rules, and two additions to the pipeline's run-state file. Each is given here with its fields, its validation rules, and its lifecycle where it has one.

## Contents

- Recorded practice document
- Path-scoped rule file
- Skill frontmatter
- Boundary check
- Phase proposal
- Workspace choice
- Falsified statement

## Recorded practice document

A file under `docs/` recording practices for working with Claude Code.

| Field                | Type        | Rule                                                                                                                                   |
| -------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Title                | H1          | Present, first line of the file                                                                                                        |
| Preamble             | prose       | States what the document covers, and that a claim without an authoritative source is recorded as a gap rather than filled with a guess |
| Sources statement    | prose       | Names `https://code.claude.com/docs` and the specific pages relied on                                                                  |
| Contents             | bullet list | One entry per H2 section, in document order                                                                                            |
| Sections             | H2          | Each carries at least one cited claim                                                                                                  |
| "In this repository" | prose       | At most one per section, grounding the general practice in what this repository actually does                                          |
| Recorded gaps        | H2          | Present, last section, collecting every gap the body raises                                                                            |

**Validation rules**

- Every claim of fact about Claude Code carries a source link, or appears under a `GAP` marker (FR-002).
- A gap is stated as "no authoritative source was found", never as "the opposite is true".
- A correction to an earlier claim is recorded in a corrections table rather than replacing the text silently (FR-003).
- No hard-wrapped prose: one line per paragraph, however long.

**Instances after this feature**: `claude-code-practices.md`, `claude-code-project-structure.md` (new), `merge-conflict-practices.md`, `skill-authoring-practices.md`.

## Path-scoped rule file

A file under `.claude/rules/` read only when a governed file is worked on.

| Field             | Type               | Rule                                                  |
| ----------------- | ------------------ | ----------------------------------------------------- |
| `paths`           | YAML list of globs | **Required.** The key is `paths`, not `path`          |
| Title             | H1                 | Present                                               |
| Reasoning pointer | link               | Points at the `docs/` document carrying the rationale |
| Body              | H2 sections        | States rules, not reasoning                           |

**Validation rules**

- A rule file **must** declare `paths`. Without it the file is loaded unconditionally at launch and behaves like always-loaded content while sitting in a directory named `rules` (FR-005).
- The `paths` list shares a budget of 1,000 expanded patterns and 4 MiB; patterns without braces do not count against it.
- The file falls inside no exclusion declaration, so `format`, `markdown` and `editorconfig` govern it (FR-006).
- Rules are stated here; reasoning lives in `docs/` and is linked, not restated — a rule in two places agrees the day it is written and drifts afterwards.

**Instances after this feature**: `repository-docs.md` (new, `docs/**` and `CLAUDE.md`), `shell-scripts.md` (`**/*.sh`), `skill-authoring.md` (`skills/**`).

## Skill frontmatter

The YAML block at the top of a `SKILL.md`.

| Field                      | Present on | Rule after this feature                                                                                                           |
| -------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `name`                     | all six    | Equals the directory basename, and carries the `ccd-` prefix. Not a loader requirement; a convention with a maintenance rationale |
| `description`              | all six    | Triggering use case in the first sentence. Shares 1,536 characters with `when_to_use`                                             |
| `disable-model-invocation` | **none**   | Was on `ccd-speckit-run` only. Removed by FR-008                                                                                  |
| `user-invocable`           | none       | Absent, deliberately. Its absence leaves a skill user-invocable; `false` would hide it from the `/` menu                          |

**State transition** — the only one in this feature:

```text
ccd-speckit-run:  disable-model-invocation: true  →  (field absent)
plugin-wide count:                             1  →  0
```

**Validation rules**

- Zero of the six skills carry `disable-model-invocation` (FR-008). The invariant is committed at `contracts/skill-names.md` and verified by the grep recorded there.
- No skill carries `user-invocable`.
- The four skills `ccd-speckit-run` dispatches must never acquire `disable-model-invocation`; under the strict reading of an unresolved documentation ambiguity it would break that dispatch silently.

## Boundary check

The determination made after each step and each phase of whether the working tree is conflicted. Recorded in the run state as an element of `conflict_checks[]`.

| Field        | Type                    | Rule                                                                                 |
| ------------ | ----------------------- | ------------------------------------------------------------------------------------ |
| `at`         | string                  | The step or phase just completed, e.g. `"after Phase 5"`                             |
| `verdict`    | `clean` \| `conflicted` | From `conflict-state.sh`, never from a reading of prose                              |
| `unmerged`   | integer                 | Count of unmerged paths; `0` when clean                                              |
| `operation`  | string \| null          | The interrupted operation — `merge`, `rebase`, `cherry-pick`, `revert` — or null     |
| `dispatched` | boolean                 | Whether `claude-code-devkit:ccd-conflict-resolve` was invoked                        |
| `resolved`   | boolean \| null         | After a dispatch: whether the tree came back clean. Null when nothing was dispatched |

**Lifecycle**

```text
clean      → recorded, reported as "checked, clean", run continues
conflicted → dispatch ccd-conflict-resolve
             ├─ tree now clean  → resolved: true,  run continues
             └─ still conflicted → resolved: false, RUN STOPS (CHK021)
```

**Validation rules**

- One element per boundary. The count of elements equals the count of boundaries reached (SC-006).
- A clean verdict is written and reported, never omitted for being unremarkable (FR-016).
- Written as each check completes, not batched at the end — a run that is summarized must still be able to report them (FR-017).
- The run never re-dispatches on a surviving conflict. The sub-skill iterates internally; a second dispatch finding the same state is a loop, not a retry.

## Phase proposal

The statement made before a phase is invoked. Not persisted; it is a message and an `AskUserQuestion` call.

| Field     | Rule                                                                                                  |
| --------- | ----------------------------------------------------------------------------------------------------- |
| Command   | The command about to be invoked, in the run's resolved naming form                                    |
| Argument  | The **verbatim** argument. Not summarized, not truncated, not paraphrased (FR-010)                    |
| Artifacts | What the phase will write                                                                             |
| Delta     | What changed since the Step 3 plan — stated explicitly as "nothing changed" when nothing did (FR-013) |
| Answers   | Proceed, Revise, Stop                                                                                 |

**Lifecycle**

```text
proposed → Proceed → phase invoked → phases.N written after artifacts seen on disk
         → Revise  → argument amended, re-proposed (max 3 revisions, then stop and ask)
         → Stop    → run halts, state left accurate
```

**Validation rules**

- A conditional phase about to be skipped still produces a proposal, stating the skip and its reason rather than being silent.
- Revise amends **only** that phase's argument. No other phase's argument changes.
- The delta field is what keeps the gate readable across eight of them; a proposal that omits it is indistinguishable from the last one.

## Workspace choice

The decision of where the maintainer is left once a review request exists. Recorded as `worktree.teardown` or `branch.teardown` in the run state.

| Mode     | Choices                                                                                                  | Guard                                                                                                       |
| -------- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Branch   | switch to target and delete feature branch; switch to target and keep it; **stay** (recommended)         | Deletion requires the branch's commits pushed. `git branch -d` refuses unmerged and the refusal is honoured |
| Worktree | exit, remove worktree, delete branch; exit and remove worktree; exit and keep it; **stay** (recommended) | Removal requires **no** uncommitted path in that directory, whatever its origin                             |

**Validation rules**

- The guards are different guards and are stated separately (CHK031). Branch deletion turns on unpushed commits; worktree removal turns on any uncommitted path, because `git worktree remove` discards the whole directory.
- A guarded-out choice is not offered, and the reason is said aloud (FR-026).
- No skip-approval phrase covers a deletion (FR-027).
- Removal is `ExitWorktree(action: "keep")` then `git worktree remove`. `ExitWorktree(action: "remove")` does not apply to a worktree entered by path, and `--force` is never used.

## Falsified statement

An entry in the enumeration that makes FR-028 checkable. Committed at `contracts/falsified-statements.md`.

| Field     | Type                     | Rule                                   |
| --------- | ------------------------ | -------------------------------------- |
| Location  | `path:line`              | Exact                                  |
| Statement | quoted text              | Verbatim, one or two lines             |
| Cause     | `A` \| `B` \| `C` \| `D` | Which of the four changes falsifies it |
| Bucket    | `live` \| `record`       | Decides the treatment                  |

**Treatment by bucket** — the criterion CHK015 asked for:

```text
live   → corrected in place
record → superseded by a new record, never edited
         └─ unless ALREADY marked superseded → left entirely alone
```

**Validation rules**

- The enumeration is finite and complete; FR-028 is checked against it rather than against "every statement".
- A `specs/` file recording a completed feature's decisions is a record, because editing it would falsify the account of what that feature shipped.
- Everything outside `specs/` — `CLAUDE.md`, `README.md`, `.claude/rules/`, `docs/`, `skills/` — is live.
