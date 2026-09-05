---
description: 'Task list for feature implementation'
---

# Tasks: Guided Bug Triage Run

**Input**: Design documents from `/specs/009-bug-triage-run/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: This repository has no test runner. Its regression instrument is each skill's `evaluations.md` and its check is `scripts/lint.sh` plus `scripts/selftest.sh`. Test tasks below are therefore evaluation-scenario tasks and script-fixture tasks, not unit tests.

**Organization**: Grouped by user story so each can be implemented and exercised independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Include exact file paths in descriptions

## Path Conventions

The deliverable is a Claude Code plugin skill, not an application. Paths are repository-root-relative: `skills/ccd-speckit-bug-run/` for the skill, `docs/` and `.claude/rules/` for the written record, and four existing files for the count-and-version updates. See [plan.md](./plan.md) for the full tree.

---

## Phase 1: Setup

**Purpose**: The directory and the one configuration change everything else assumes.

- [x] T001 Create the skill directory tree `skills/ccd-speckit-bug-run/` with empty `SKILL.md`, `evaluations.md`, `reference/` and `scripts/`, matching the layout in plan.md
- [x] T002 Add `.specify/.speckit-bug-run-state.json` to `.gitignore`, in the "Spec Kit: machine-local run state" block beside the existing `.specify/.speckit-run-state.json` entry at line 11

---

## Phase 2: Foundational

**Purpose**: Blocking prerequisites. The scripts and reference files must exist before `SKILL.md` can invoke or cite them. **No user story can be completed until this phase is done.**

- [x] T003 [P] Write `skills/ccd-speckit-bug-run/scripts/bug-preflight.sh` to the output contract in `specs/009-bug-triage-run/contracts/bug-preflight-cli.md`: POSIX `sh`, `set -e`, read-only, emitting the `capability`, `extension-dir`, `stage-*`, `bugs-root`, `slug`, `slug-taken`, `dirty`, `dirty-count`, `dirty-path` and `verdict` keys
- [x] T004 [P] Write `skills/ccd-speckit-bug-run/scripts/bug-outcome.sh` to the output contract in `specs/009-bug-triage-run/contracts/bug-outcome-cli.md`: POSIX `sh`, `set -e`, read-only, emitting `bug-dir`, `assessment`, `fix`, `test`, `verdict`, `severity`, `status` and `result`, with `unknown` for any label absent or carrying a value outside its vocabulary
- [x] T005 Verify both scripts pass `sh scripts/lint-shell.sh` natively and under `LINT_FORCE_CONTAINER=1`, with zero ShellCheck findings in POSIX mode
- [x] T006 [P] Write `skills/ccd-speckit-bug-run/reference/stages.md` carrying the three outcome vocabularies, the branch table, and the outcome-location table from `specs/009-bug-triage-run/data-model.md`
- [x] T007 [P] Write `skills/ccd-speckit-bug-run/reference/run-state.md` carrying the `.specify/.speckit-bug-run-state.json` shape, the who-writes-what table, and the precondition rule from `specs/009-bug-triage-run/data-model.md`
- [x] T008 Write the frontmatter and opening of `skills/ccd-speckit-bug-run/SKILL.md`: `name: ccd-speckit-bug-run` and a `description` under 1,536 characters whose first sentence carries the trigger. No `disable-model-invocation`, no `user-invocable`, no other field. The opening also states the standing rule that the run never performs a stage's own work in place of invoking that stage (FR-006), and defines "happening" for the approval rule as invoking a stage or writing a file — reads and the read-only preflight are outside it (FR-019)

**Checkpoint**: both scripts behave per contract against a fixture, and `SKILL.md` exists with correct frontmatter.

---

## Phase 3: User Story 1 — One report, one guided run (Priority: P1) 🎯 MVP

**Goal**: A maintainer hands the run one bug report and is walked through assessment, remediation and validation, approving each stage, and is told at the end what each stage concluded and where each report was written.

**Independent test**: Run against a real defect in a repository with the capability installed, approve each stage, and confirm three reports exist and that the closing report's claims match what those reports say.

- [x] T009 [US1] Add the preflight step to `skills/ccd-speckit-bug-run/SKILL.md`: invoke `sh "${CLAUDE_SKILL_DIR}/scripts/bug-preflight.sh"`, act on its `verdict` line rather than its exit status, report an absent capability and stop (FR-023), report a taken slug and ask (FR-003), and report the `dirty-path` lines before Stage 2 (FR-029). This step also refuses a run that was given more than one bug report, before Stage 1 and with the reason stated (FR-021)
- [x] T010 [US1] Add Stage 1 to `skills/ccd-speckit-bug-run/SKILL.md`: state command, verbatim wording and artifacts, gate with Proceed/Revise/Stop, then dispatch `Skill(skill: "speckit-bug-assess")` passing the bug report **byte-identical** to what was supplied and never pre-fetching a URL (FR-004, FR-022, research D9). Append `slug=<slug>` **only** when the maintainer supplied one; where they did not, pass no slug and let the capability derive it (FR-002). Define Revise here for all three stages: it amends only the wording of the stage being approved and re-presents that same boundary, changing no other stage's wording and advancing nothing (FR-013)
- [x] T011 [US1] Add Stage 2 to `skills/ccd-speckit-bug-run/SKILL.md` on the same pattern, dispatching `Skill(skill: "speckit-bug-fix")` with `slug=<slug>` only
- [x] T012 [US1] Add Stage 3 to `skills/ccd-speckit-bug-run/SKILL.md` on the same pattern, dispatching `Skill(skill: "speckit-bug-test")` with `slug=<slug>` only
- [x] T013 [US1] Add the artifact confirmation to each stage in `skills/ccd-speckit-bug-run/SKILL.md`: run `bug-outcome.sh`, record `stages.N = done` only once that stage's report reads `present` (FR-015), and write the outcome into state from the script rather than from recollection (FR-016)
- [x] T014 [US1] Add the closing report to `skills/ccd-speckit-bug-run/SKILL.md`: every stage's status and outcome, every report's path, and the statement that governance requires those artifacts committed before review, naming `claude-code-devkit:ccd-commit-push` as the means and performing no commit itself (FR-017, FR-020, FR-030)
- [x] T015 [US1] Add Scenario A (the straight path: `valid` → `applied` → `verified`) to `skills/ccd-speckit-bug-run/evaluations.md`, per `specs/009-bug-triage-run/quickstart.md`

**Checkpoint**: a full three-stage run works end to end and reports honestly. This is the MVP.

---

## Phase 4: User Story 2 — The run refuses to waste a stage (Priority: P2)

**Goal**: When a stage would be invoked that the capability is guaranteed to refuse, the run announces a skip and its reason instead.

**Independent test**: Give the run a report that assessment will judge not to be a defect; confirm Stage 2 is announced as skipped and never invoked.

- [x] T016 [US2] Add the verdict branch to `skills/ccd-speckit-bug-run/SKILL.md` covering all three values: `invalid` skips Stages 2 and 3; `likely valid, needs reproduction` proceeds and states at the Stage 2 boundary that the defect was not reproduced, without raising the run's own question about it; `valid` proceeds (FR-007)
- [x] T017 [US2] Add the remediation-status branch to `skills/ccd-speckit-bug-run/SKILL.md` covering all three values: `not-applied` skips Stage 3; `partial` proceeds and carries the status into the closing report; `applied` proceeds (FR-008)
- [x] T018 [US2] Add the skip announcement to `skills/ccd-speckit-bug-run/SKILL.md`: a stage about to be skipped still gets its boundary, stating the skip and the recorded value that caused it, before the run moves past it (FR-009)
- [x] T019 [US2] Add Scenario B (the early exit: `invalid` verdict, one report on disk, two announced skips) to `skills/ccd-speckit-bug-run/evaluations.md`

**Checkpoint**: no stage is ever invoked that its preconditions would refuse (SC-002).

---

## Phase 5: User Story 3 — An unresolved defect is a question (Priority: P2)

**Goal**: A validation result of `failed` or `partial` stops the run and puts the choice to the maintainer, and the run never describes itself as successful.

**Independent test**: Run against a defect whose remediation is deliberately insufficient; confirm the run neither claims success nor re-invokes a stage unasked.

- [x] T020 [US3] Add the validation-result branch to `skills/ccd-speckit-bug-run/SKILL.md`: `verified` may complete; `partial` and `failed` both stop, present what validation found, and put the choice to the maintainer with no automatic re-run (FR-010, FR-028)
- [x] T021 [US3] Add to `skills/ccd-speckit-bug-run/SKILL.md` the rule that a run ending on `partial` or `failed` is never described as successful, and that the reason a result was `partial` is stated (SC-006)
- [x] T022 [US3] Add the `unknown`-outcome rule to `skills/ccd-speckit-bug-run/SKILL.md`: a report that reads `present` but whose outcome reads `unknown` stops the run and reports extraction drift; never branch on a guessed value (data-model branch table, research G3)
- [x] T023 [US3] Add the after-a-stop rules to `skills/ccd-speckit-bug-run/SKILL.md`: resuming is re-invoking with the same slug, and a stop that follows a source edit must say so, name the change record, and repeat the pre-existing dirty paths (data-model "After a stop")
- [x] T024 [US3] Add Scenario C (the unresolved defect) to `skills/ccd-speckit-bug-run/evaluations.md`

**Checkpoint**: the run cannot report success over an unfixed defect.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T025 [P] Write `docs/spec-kit-extensions.md` in the shape `.claude/rules/repository-docs.md` mandates — Contents list, per-section source citations, an "In this repository" paragraph per topic, a "Recorded gaps" section carrying G1–G5 from research.md, and a corrections table recording that the published extensions reference page omits `bug` from its bundled list while the installed 1.0.2.dev0 bundles four
- [x] T026 [P] Write `.claude/rules/spec-kit-bug-workflow.md` with `paths:` globs `skills/ccd-speckit-bug-run/**` and `.specify/bugs/**`, carrying the durable rules only: bare-name dispatch for the three stages, the three outcome vocabularies as closed sets, `unknown` stops, and the committed-artifact obligation
- [x] T027 [P] Add the two remaining evaluation scenarios to `skills/ccd-speckit-bug-run/evaluations.md`: the dirty working tree (paths named, run continues, nothing stashed) and the URL bug report (handed over verbatim, nothing fetched by the run)
- [x] T028 Update `.claude-plugin/plugin.json`: `version` `0.2.0` → `0.3.0`, and rewrite the `description` so it no longer says "six git and forge skills"
- [x] T029 Update `README.md`: the "six skills" sentence at line 5, the TOC entry and anchor at line 13, the `### The six skills` heading at line 43, and a table row for `ccd-speckit-bug-run`
- [x] T030 Update `CLAUDE.md`: the "six skills under `skills/`" claim at line 7, the "added the sixth skill" sentence at line 24, and a short paragraph placing `ccd-speckit-bug-run` and naming the three stages it dispatches
- [x] T031 Run the six verification commands in `specs/009-bug-triage-run/contracts/skill-names.md` and confirm each gives its expected output, check 4 returning `7`
- [x] T032 Run `sh scripts/lint.sh` and `sh scripts/selftest.sh` to green, then re-run `sh scripts/lint.sh` under `LINT_FORCE_CONTAINER=1` to confirm both paths agree
- [x] T033 **GATED — requires the user's approval of the chosen resolutions before it is written.** Write `specs/009-bug-triage-run/design-review.md` recording the risks, red flags, enhancements and improvements identified in the finished skill, the options weighed for each, and which resolution was chosen and why (FR-026). This task is ordered last because it reviews what every preceding task built, and its content is a set of decisions the user makes rather than the implementer

---

## Dependencies

```text
Phase 1 (T001–T002)
  └─> Phase 2 (T003–T008)          blocking; nothing below starts until T005 and T008 are done
        ├─> Phase 3, US1 (T009–T015)   MVP
        ├─> Phase 4, US2 (T016–T019)   needs T010–T013's stage scaffolding
        ├─> Phase 5, US3 (T020–T024)   needs T012–T013's Stage 3 scaffolding
        └─> Phase 6 (T025–T033)
              T031 needs the skill directory to exist (T001) and all seven skills present
              T032 needs every file written
              T033 needs everything, plus a user decision
```

**Story independence**: US2 and US3 both extend the stage scaffolding US1 builds, so they are independent of _each other_ but not of US1. US1 alone is a working, honest run — it simply invokes all three stages unconditionally. That is the MVP.

## Parallel execution

- **T003 and T004** — different scripts, no shared code.
- **T006 and T007** — different reference files.
- **T025, T026 and T027** — different files, no ordering between them.
- **Within US1**: T010, T011 and T012 all edit `SKILL.md` and are therefore **not** parallel, despite being structurally identical. Same for T016–T018 and T020–T023.

The single-file constraint is worth stating plainly: most of this feature is one Markdown file, so most of it is sequential. Marking `SKILL.md` tasks `[P]` would be wrong.

## Implementation strategy

**MVP is Phase 1 + Phase 2 + Phase 3.** That delivers a run that walks all three stages with gates and an honest closing report. It is shippable: on the happy path it is complete, and on the unhappy paths it is merely less helpful than it will be, not wrong.

**Increment 2 is Phase 4**, which stops the run wasting a stage the capability would refuse.

**Increment 3 is Phase 5**, which is the one that matters most for trust: without it a `failed` validation would still be reported by a run that had already declared itself done.

**Phase 6 last**, with T033 last of all and gated.
