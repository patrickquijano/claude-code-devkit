# Data Model: Distribute the Toolkit's Own Skills

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-02

This feature stores nothing and runs no process. Its "data" is the set of committed files the plugin distributes and the resolvable names by which they reach each other. The entities below are therefore structural: each has a location, a set of fields a reader or a tool can inspect, and validation rules drawn from the requirements. Where an entity has states, they are states of a file in the repository, not of a running system.

## 1. Distributed skill

One of the five skills, as the plugin ships it.

| Field                  | Value                                                                           | Source                                  |
| ---------------------- | ------------------------------------------------------------------------------- | --------------------------------------- |
| `directory`            | `skills/<name>/` at the repository root                                         | FR-001, plan Structure Decision         |
| `name`                 | the `name:` value in the skill's frontmatter, matching `<directory>`'s basename | FR-001                                  |
| `resolved_name`        | the name the host resolves the skill by once installed: `<plugin-name>:<name>`  | FR-005, [research.md](./research.md) §4 |
| `instruction_document` | `SKILL.md` -- the only file that loads without being asked for                  | FR-002                                  |
| `supporting_documents` | zero or more further Markdown files, loaded on demand                           | FR-024                                  |
| `scripts`              | zero or more `.sh` files the skill invokes                                      | FR-009                                  |
| `templates`            | zero or more files the skill reads but does not execute                         | FR-027                                  |
| `test_scenarios`       | exactly one test-scenario document                                              | FR-024, SC-014                          |
| `entry_point`          | true for exactly one of the five                                                | FR-014, SC-009                          |

**Validation rules**

- `directory` basename equals frontmatter `name`. A mismatch is the one error that makes a skill unloadable rather than merely wrong.
- Exactly one of the five has `entry_point` true, and it is `speckit-run` (FR-014). Enforced by inspection, not by a tool.
- `test_scenarios` is present for all five (SC-014: 5 of 5), and the reference to it from `instruction_document` resolves (SC-014: 0 of 6 failing).
- Every file under `directory` is in the repository's lint scope, because `.lintignore` excludes nothing here (FR-016, FR-019).
- No file under `directory` is machine-local, generated, or binary (FR-017, SC-007).

**The five instances**

| `name`             | `entry_point` | scripts | templates | supporting docs       |
| ------------------ | ------------- | ------- | --------- | --------------------- |
| `speckit-run`      | **true**      | 5       | 0         | 13 under `reference/` |
| `auto-branch-push` | false         | 1       | 0         | 0                     |
| `auto-commit-push` | false         | 0       | 0         | 0                     |
| `auto-github-pr`   | false         | 1       | 7         | 0                     |
| `auto-gitlab-mr`   | false         | 1       | 1         | 0                     |

`speckit-run` shows 5 scripts rather than 6, and `auto-branch-push` 1 rather than 1-of-4, because the shared helper is a separate entity below. `speckit-run`'s test-scenario document is one of the 13 supporting documents (`reference/evaluations.md`); the other four skills carry theirs at the skill root.

## 2. Companion reference

A place where one distributed skill names another in order to hand work to it. The unit FR-005 through FR-008 govern, and the entity SC-002 counts.

| Field          | Value                                                                                                  |
| -------------- | ------------------------------------------------------------------------------------------------------ |
| `site`         | the file and line where the name appears                                                               |
| `source_skill` | the skill whose file contains it                                                                       |
| `target_skill` | the skill named                                                                                        |
| `kind`         | `dispatch` (a `Skill` tool call that must resolve) or `prose` (a mention that must merely be accurate) |
| `written_form` | the text as committed                                                                                  |
| `resolution`   | which copy the name reaches at run time                                                                |

**Validation rules**

- Every reference of `kind = dispatch` resolves to a distributed copy when the plugin is the only source (FR-005).
- Where both a distributed and a personal copy exist, `resolution` is deterministic and recorded by the resolving skill (FR-006).
- A `dispatch` whose name does not resolve is reported naming `target_skill`, and follows that skill's documented rule for an unavailable companion (FR-007).
- `kind = prose` references need no resolution but must stay true. This is the distinction CHK022 turns on: `auto-github-pr/SKILL.md:227` is prose that FR-011 falsifies.

**Counts as measured 2026-09-02**: 74 references in total. The dispatch sites -- the ones that must resolve -- are the `Skill` tool calls in `speckit-run`'s `reference/ship.md` (6a and 6b) and the routing rows that name which skill each forge dispatches. The remainder are prose: red-flag table rows, "use X instead" pointers, and dispatch narration inside the five test-scenario documents.

## 3. Own-file path

A path by which a distributed skill reaches a file it ships alongside itself.

| Field               | Value                                |
| ------------------- | ------------------------------------ |
| `site`              | file and line                        |
| `target`            | the shipped file being reached       |
| `form`              | the path as written                  |
| `is_worked_example` | whether a reader is meant to copy it |

**Validation rules**

- `form` names no install location (FR-009).
- Where `is_worked_example` is true, `form` is followable under the install form the plugin produces (FR-010).
- SC-003 counts only sites where `is_worked_example` is true or the line is otherwise an instruction: **16** of the 22 literal occurrences measured. The other 6 name the user's own machine-wide instructions file, which is a real path the skills name in order to forbid touching it, and which must not be rewritten.

## 4. Shared helper

Behaviour more than one of the five requires, distributed once.

| Field                   | Value                                             |
| ----------------------- | ------------------------------------------------- |
| `location`              | one path, decided in plan.md                      |
| `consumers`             | the skills that invoke it                         |
| `output_contract`       | the columns it emits, in order                    |
| `reconciliation_record` | which previous copy's behaviour was kept, and why |

**Validation rules**

- Exactly one distributed implementation (FR-011, SC-004: 1).
- Every consumer obtains its candidates from it, and all consumers see the same candidate set and order for the same repository state (FR-012, SC-005: 0 differences).
- `reconciliation_record` exists and names the rejected behaviour (FR-013).

**The one instance**: `branch-options.sh`, consumers `auto-branch-push`, `auto-github-pr`, `auto-gitlab-mr` and `speckit-run`. Four copies existed at the start of this feature: three byte-identical at 88 lines (`md5 70edb6ae…`) and one divergent at 48 (`md5 c92eb52d…`).

`output_contract` is the 88-line form: `<branch>` TAB `local|remote|both` TAB `<YYYY-MM-DD>` TAB `<tags>`, where `<tags>` is a comma-joined subset of `default` and `current` or `-`, ordered default-branch first then newest commit first. The 48-line form emitted `current|-` in the fourth column and ordered by date alone.

## 5. Distribution decision

The recorded verdict on one file, or one class of file, in the source of these skills. The entity SC-008 counts.

| Field     | Value                                                                |
| --------- | -------------------------------------------------------------------- |
| `path`    | the source file or the class                                         |
| `verdict` | `distribute` or `withhold`                                           |
| `reason`  | required for `withhold`; the requirement or conflict that decided it |

**Validation rules**

- Every one of the 47 source files is covered by a decision (FR-018, SC-008: 0 of 47 uncovered).
- A class covers more than one file only where the reason is identical for all of them.

**State transitions**: none. A decision is recorded once and does not change during the feature; a later feature that changes one records a new decision rather than editing this.

## 6. Install form

How a skill came to be present.

| Value      | Meaning                                                             |
| ---------- | ------------------------------------------------------------------- |
| `plugin`   | distributed with this plugin, resolved under `<plugin-name>:<name>` |
| `personal` | copied into the user's own skills directory, resolved bare          |

**Validation rules**

- `install_form` determines how names and paths resolve (FR-005, FR-009) and MUST NOT determine behaviour (FR-004).
- Both forms may be present simultaneously (FR-006). On the maintainer's machine this state ends when FR-025 removes the personal copies; elsewhere it may persist, which is why FR-006 survives FR-025.

**State transitions**, and this is the only entity in this model with any:

```text
personal only  ──(distribution)──▶  both present  ──(FR-025 removal)──▶  plugin only
```

The middle state is where this feature's delivery itself sits, and it is load-bearing: the delivery executes from the `personal` copies, so the transition out of it must come after everything that depends on them (FR-026, spec Edge Cases). The `plugin only` state is terminal, and reaching it is irreversible -- once the personal copies are gone the distributed ones are the only ones, which is why FR-025 makes the passing check and the invocability confirmation preconditions rather than follow-ups.
