# Data Model: Merge Conflict Resolution

**Feature**: [005-merge-conflict-resolution](./spec.md) | **Date**: 2026-09-04

There is no database and no persisted schema. The entities below are the shapes that pass between the skill's four scripts and its body, and the states the workflow moves through. They exist here so that the scripts' output contracts in [contracts/conflict-scripts-cli.md](./contracts/conflict-scripts-cli.md) have something to be contracts _of_, and so that `tasks.md` can be written against named things rather than descriptions.

Every field below is derived from a requirement in [spec.md](./spec.md); the requirement is named against each. Nothing here is invented for symmetry.

## Entities

### Workspace state

What `conflict-preflight.sh` establishes before anything else happens. One record per run, replaced rather than accumulated.

| Field                   | Values                                               | Derived from      |
| ----------------------- | ---------------------------------------------------- | ----------------- |
| `tool_available`        | yes / no                                             | FR-009            |
| `inside_repository`     | yes / no                                             | FR-009, edge case |
| `operation_in_progress` | none / merge / rebase / cherry-pick / revert         | FR-017            |
| `remote_reachable`      | yes / no / not-attempted                             | FR-020            |
| `upstream_relation`     | up-to-date / behind / ahead / diverged / no-upstream | FR-017a           |
| `unrelated_dirty_paths` | list of paths                                        | FR-016, FR-017c   |

Validation rules that follow from the requirements rather than from convenience:

- `tool_available: no` terminates the run. No other field is meaningful, and none is reported as though it were — FR-009 requires the working tree be left unchanged, so nothing further is even probed.
- `operation_in_progress` is read from the repository's own state rather than inferred from the presence of conflicts. A conflicted tree with no operation in progress is possible, and FR-017's "MUST NOT assume one" is exactly this case.
- `unrelated_dirty_paths` is captured **before** any resolution is applied. It is what FR-017c's guarantee is checked against at the end, so capturing it afterwards would make the guarantee unverifiable.
- `remote_reachable: no` does not terminate the run. FR-020 requires reporting and letting the user decide, so this is a branch and not a failure.

### Conflicted path

One path the tool reports as unmerged. The unit `conflict-list.sh` emits and the unit a resolution applies to.

| Field            | Values                             | Derived from   |
| ---------------- | ---------------------------------- | -------------- |
| `path`           | repository-relative path           | FR-011         |
| `kind`           | see the classification table below | FR-011, FR-019 |
| `stages_present` | base / ours / theirs (derived)     | FR-019         |
| `is_text`        | yes / no (derived)                 | FR-019         |
| `resolved`       | yes / no                           | FR-014         |

`kind` is a closed set, which CHK002 asked for. Seven of the nine values map directly onto a documented `XY` code from `git status`; two are derived. Research §3.3 is the source for both halves.

| `kind`            | `XY` code | Meaning                                                              | Resolvable by choosing content?                 |
| ----------------- | --------- | -------------------------------------------------------------------- | ----------------------------------------------- |
| `both-modified`   | `UU`      | Content differs on both sides                                        | Yes — line-level or whole-file                  |
| `both-added`      | `AA`      | Added independently on both sides; no common ancestor                | Yes — but there is no base to show              |
| `both-deleted`    | `DD`      | Removed on both sides                                                | No — the only question is whether it stays gone |
| `added-by-us`     | `AU`      | Added on our side only                                               | No — whole-file only                            |
| `added-by-them`   | `UA`      | Added on their side only                                             | No — whole-file only                            |
| `deleted-by-us`   | `DU`      | Removed on our side, modified on theirs                              | No — whole-file only                            |
| `deleted-by-them` | `UD`      | Modified on our side, removed on theirs                              | No — whole-file only                            |
| `type-changed`    | _derived_ | A path is a file on one side and a directory or symlink on the other | No — whole-file only                            |
| `binary`          | _derived_ | Content is not text, whatever the stage layout                       | No — whole-file only                            |

FR-019 is satisfied by the last column: every `kind` reading "No" must be offered whole-file candidate resolutions rather than line-level ones, and the classification is what tells the skill which it is. `binary` takes precedence over any other kind — a both-modified binary file is reported as `binary`, because line-level options would be meaningless. That precedence is a rule of this feature, not something git reports.

**Two honesty notes, both from research §3.3, because they bound what this model can claim.**

`type-changed` and `binary` are **not** `XY` codes — no documented code distinguishes either. `conflict-list.sh` derives `type-changed` from the stage mode fields in porcelain v2 and `is_text` from a content test. So these two values are this feature's classification, layered on git's, and a future git release could report the underlying cases differently without breaking any documented promise.

`stages_present` is likewise **derived and not documented**. Git documents only that "the index file records up to three versions"; the mapping from which stages are present to which `XY` code applies is inferable from `git-read-tree(1)`'s collapse rules but is stated nowhere. The field is kept because it is genuinely useful for explaining a conflict — a missing base stage means there is no common ancestor to show the user — but it is read from the porcelain v2 mode fields rather than assumed from the `kind`, and nothing in the skill's behaviour depends on the inference holding.

### Candidate resolution

One way a given conflicted path could be settled. Generated per path, presented as a group, applied one at a time.

| Field           | Values                                  | Derived from   |
| --------------- | --------------------------------------- | -------------- |
| `applies_to`    | a `path`                                | FR-012         |
| `mechanism`     | ours / theirs / union / staged / remove | FR-012, FR-019 |
| `explanation`   | what this would do to the content       | FR-012         |
| `recommended`   | yes / no — exactly one per group        | FR-012         |
| `justification` | why the recommended one is recommended  | FR-012         |
| `approved`      | yes / no / not-yet-asked                | FR-012, FR-013 |

The five mechanisms, and which `kind` each is valid for:

| `mechanism` | Effect                                                      | Valid for                                          |
| ----------- | ----------------------------------------------------------- | -------------------------------------------------- |
| `ours`      | Check out stage 2 and stage it                              | any kind with stage 2 present                      |
| `theirs`    | Check out stage 3 and stage it                              | any kind with stage 3 present                      |
| `union`     | Three-way merge taking lines from both sides                | `both-modified` text only                          |
| `staged`    | Stage content already written into the working tree by hand | any text kind                                      |
| `remove`    | `git rm` the path, recording the deletion as the resolution | `both-deleted`, `deleted-by-us`, `deleted-by-them` |

Validation rules:

- Exactly one candidate in a group carries `recommended: yes`, and that one carries a non-empty `justification`. A group with no recommendation, or with a recommendation and no reason, fails SC-001's "zero decisions presented without both".
- Every candidate carries a non-empty `explanation`, recommended or not. SC-001 counts decisions where _either_ was missing, so an unexplained non-recommended option fails it just as surely.
- `approved` starts at `not-yet-asked` and only the user's answer moves it. FR-012 forbids modifying any file while any candidate is still `not-yet-asked`, and FR-016 forbids the skill setting it to `yes` on its own judgment.
- **Every conflicted `kind` has at least one valid mechanism.** `both-deleted` is the case that makes this a rule rather than an observation: it has neither stage 2 nor stage 3, so `ours` and `theirs` are both invalid for it and `remove` is the only resolution. A `kind` with no valid mechanism is unresolvable, and the skill would report it and then be unable to act on it.

**Aborting is not a mechanism.** Abandoning the operation acts on the whole operation rather than on one path, so it is not a `Candidate resolution` and does not go through `conflict-apply.sh`. It is an action the skill body offers alongside the per-path candidates, and it runs the matching `--abort` for the operation `conflict-preflight.sh` detected. It is always available and is never the recommendation — offering it exists so the user is never cornered into approving a content change, and recommending it would make the skill's default answer "give up".

Two things follow from that placement. The abort action is subject to research §3.8.3's caveat — `git merge --abort` "will in some cases be unable to reconstruct" uncommitted changes present when the merge started — so the skill states that limit rather than promising a clean return. And `applies_to` is therefore always a single `path`: there is no whole-set candidate, because the only whole-set action is abort and abort is not a candidate.

**Replaying a previously recorded resolution is deliberately not a mechanism.** `git rerere` can supply one, and `conflict-preflight.sh` reports whether it is enabled, but applying a recorded resolution is left to git's own automatic behaviour rather than driven by the skill. The plan scoped rerere to read-only reporting, and reversing that would mean enabling configuration the user did not ask for. Where rerere has already resolved something, it simply shows up as fewer conflicted paths in the next `conflict-list.sh` pass.

### Conflict report

The output of one identification pass — the set of conflicted paths at a moment in time. This is the entity the iteration is defined against.

| Field             | Values                                   | Derived from |
| ----------------- | ---------------------------------------- | ------------ |
| `paths`           | list of Conflicted path                  | FR-011       |
| `pass_number`     | 1, 2, 3, …                               | FR-014       |
| `previous_report` | the report from the pass before, or none | FR-014       |

The comparison between a report and its predecessor is what makes FR-014 checkable, and it distinguishes two outcomes a single count cannot:

- Fewer conflicted paths than the previous pass — progress. Propose again against what remains.
- The same set as the previous pass, after a resolution was applied — **no progress**. This is the Edge Cases entry about an approved resolution that did not resolve what it targeted, and it must be reported as such rather than looped on. CHK006 asked for a requirement covering it; this is the shape that requirement is checked against.

### Practice entry

One recorded practice in the published documentation. Not a runtime entity — it is the unit SC-002 counts.

| Field       | Values                                                 | Derived from           |
| ----------- | ------------------------------------------------------ | ---------------------- |
| `statement` | the practice, as prose                                 | FR-001, FR-002, FR-003 |
| `source`    | a citation, or the explicit marker that none was found | FR-004                 |
| `subject`   | claude-code / skill-authoring / merge-conflicts        | FR-001, FR-002, FR-003 |

The only validation rule, and the one SC-002 measures: `source` is never empty. Where no authoritative source exists, it carries the recorded gap instead — which is a value, not an absence. This mirrors how `specs/002-vendor-plugin-skills/research.md` and `specs/003-ccd-skill-rename/research.md` already treat gaps, so a reader moving between them meets one convention.

## State transitions

The workflow is a state machine, and writing it as one is what shows that the iteration terminates. States in **bold** are terminal.

```text
                        ┌─────────────────────┐
                        │  invoked            │
                        └──────────┬──────────┘
                                   ▼
                        tool_available? ──no──► **stopped: no tool**   (FR-009)
                                   │yes
                                   ▼
                     inside_repository? ──no──► **stopped: not a repo**
                                   │yes
                                   ▼
                          update the remote                            (FR-010)
                                   │
                    reachable? ──no──► ask: continue on disk state?    (FR-020)
                                   │              │no ──► **stopped: user declined**
                                   │yes           │yes
                                   ▼              ▼
                        operation_in_progress?
                          │                    │
                          │none                │merge/rebase/cherry-pick/revert
                          ▼                    ▼
                 upstream_relation?      ┌──────────────┐
                   │           │         │  identify    │◄──────────────┐        (FR-011)
                   │up-to-date │behind   └──────┬───────┘               │
                   ▼           ▼                ▼                       │
        **nothing to do**   propose        conflicts? ──none──► conclude the operation  (FR-017b)
                            integration         │                       │              │
                                 │              │some                   │              ▼
                            approved? ──no──►   ▼                       │      succeeded? ──no──► **stopped: reported,
                                 │yes      propose resolutions          │              │yes          content kept**  (FR-017b)
                                 └────────►      │                      │              ▼
                                                 ▼                      │      **resolved and concluded**
                                            approved? ──no──► **stopped: tree untouched**  (FR-012)
                                                 │yes                   │
                                                 ▼                      │
                                            apply approved              │              (FR-013, FR-017c)
                                                 │                      │
                                                 └──────────────────────┘
                                                 │
                                    report identical to previous pass?
                                                 │yes
                                                 ▼
                                    **stopped: no progress, reported**
```

Two properties of this machine matter, and both were argued for during clarification:

**It terminates.** Each loop iteration either reduces the conflicted-path set or is detected as making no progress and stops. There is no path that applies a resolution and returns to the same state unremarked.

**Every mutation is downstream of an approval.** The only edges that change the working tree are "apply approved" and "conclude the operation", and both are reached only through an `approved? yes`. This is what makes FR-018's decision safe — an automatically-reached skill still cannot resolve anything automatically, because automatic invocation enters at the top of this diagram and every write is behind a gate further down.
