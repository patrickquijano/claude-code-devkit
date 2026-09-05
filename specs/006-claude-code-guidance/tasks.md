---
description: 'Task list for feature 006-claude-code-guidance'
---

# Tasks: Claude Code guidance and pipeline gating

**Input**: Design documents from `/specs/006-claude-code-guidance/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/)

**Tests**: No test tasks. This repository has no test runner and none is added — `specs/001-quality-gate-plugin/plan.md:128` rejected inventing `src/` or `tests/` for it. The check is `sh scripts/lint.sh` and the acceptance evidence is [quickstart.md](./quickstart.md). Neither the spec nor the feature request asked for TDD.

**Organization**: Tasks are grouped by user story so each can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: US1–US5, mapping to the user stories in `spec.md`
- Exact file paths in every description

## Path conventions

No `src/` and no `tests/`. Paths are repository-root-relative: `docs/`, `.claude/rules/`, `skills/<name>/`, `specs/006-claude-code-guidance/`.

---

## Phase 1: Setup

**Purpose**: establish that the tree is green before anything changes, so a later failure is attributable to this feature.

- [x] T001 Run `sh scripts/lint.sh` on the unmodified branch and record the exit status; a non-zero baseline must be resolved or explicitly noted before any edit
- [x] T002 Confirm the working tree is on `006-claude-code-guidance` and clean apart from `specs/006-claude-code-guidance/`, via `git status --porcelain`
- [x] T003 [P] Record the current `wc -l < CLAUDE.md` and the output of `grep -n '^## ' CLAUDE.md` as the FR-007a baseline the final check compares against

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: one hazard blocks every correction task, and it is not obvious.

**⚠️ CRITICAL**: no correction task may begin until T004 is complete.

- [x] T004 Re-anchor [contracts/falsified-statements.md](./contracts/falsified-statements.md) from line numbers to quoted text. All 42 entries cite `path:line`, and the first edit to any multi-item file invalidates every later line number in it — `skills/ccd-speckit-run/SKILL.md` alone carries 16 items. Verify each quoted statement still matches the file by text search, not by line, and correct any entry whose quote has drifted
- [x] T005 Confirm every file the enumeration names still exists and that `git diff --name-only main -- specs/005-merge-conflict-resolution/` is empty, establishing the untouched-record baseline FR-029 is checked against

**Checkpoint**: the enumeration is text-anchored and the record bucket is provably untouched. Story work can begin.

---

## Phase 3: User Story 1 — Approving each pipeline phase as it happens (Priority: P1) 🎯 MVP

**Goal**: the pipeline becomes model-reachable and gates every phase on its own, with the safety property moving from the frontmatter into the workflow.

**Independent Test**: quickstart scenarios 4, 7 and 8 — zero skills carry `disable-model-invocation`, the skill is reachable both ways, and no phase is invoked without a preceding proposal naming its verbatim argument.

**Why these ship together**: removing the field is only defensible because the per-phase gates replace what it protected. Landing the frontmatter change without the gates would leave an eight-phase pipeline model-startable with one up-front approval — the state `specs/005-.../contracts/skill-names.md:45` argued against.

- [x] T006 [US1] Delete the `disable-model-invocation: true` line from `skills/ccd-speckit-run/SKILL.md` frontmatter. Add no `user-invocable` field — its absence is what leaves the skill user-invocable (falsified-statements #7)
- [x] T007 [US1] Rewrite `skills/ccd-speckit-run/SKILL.md`'s opening paragraph so it no longer claims phases "run start to finish without stopping" (#8)
- [x] T008 [US1] Rewrite Step 3 in `skills/ccd-speckit-run/SKILL.md`: it drafts all eight arguments and applies the `reference/prompt-rules.md` leakage check across them, then **presents them as a plan** rather than taking approval (#13, #14)
- [x] T009 [US1] Rewrite the click-through paragraph at `skills/ccd-speckit-run/SKILL.md` rather than deleting it — preserve the argument and answer it with the delta requirement, per `research.md` Decision 5 (#15)
- [x] T010 [US1] Rewrite Step 4 in `skills/ccd-speckit-run/SKILL.md` to require a per-phase proposal stating command, verbatim argument, artifacts and delta, approved with `AskUserQuestion` offering Proceed / Revise / Stop under the existing three-revision cap (#16, #17, #18)
- [x] T011 [US1] Update the progress checklist and the Step 7 summary wording in `skills/ccd-speckit-run/SKILL.md` (#9, #10, #19)
- [x] T012 [US1] Replace the "Phases are not gated" red-flag row in `skills/ccd-speckit-run/SKILL.md`, whose premise is now false, with one guarding the new failure mode: proposals that carry no delta (#20)
- [x] T013 [US1] Rewrite the authoring note at `skills/ccd-speckit-run/SKILL.md` so it states why this skill no longer carries the field while the four it dispatches still must not (#21, #22)
- [x] T014 [P] [US1] Update `skills/ccd-speckit-run/reference/prompt-rules.md` so the leakage check is described as running at the plan presentation
- [x] T015 [P] [US1] Correct the not-gated sentences in `skills/ccd-speckit-run/reference/constitution.md` and `skills/ccd-speckit-run/reference/run-state.md` (#31, #32)
- [x] T016 [P] [US1] Add `conflict_checks[]` and the teardown fields to the state shape in `skills/ccd-speckit-run/reference/run-state.md`, per [data-model.md](./data-model.md)

**Checkpoint**: the pipeline is model-reachable and every phase is gated. Verify with quickstart scenarios 4, 7 and 8 before continuing.

---

## Phase 4: User Story 2 — Finding the practice while editing the file it governs (Priority: P2)

**Goal**: project structure is documented as its own subject, and the authoring practices reach an author at edit time.

**Independent Test**: quickstart scenarios 3 and 11 — every rule file declares `paths:`, the new document exists with sources and a gaps section, and the markdown and format checks reach the new rule file.

- [x] T017 [P] [US2] Create `docs/claude-code-project-structure.md` covering what `.claude/` holds and when each part loads, the instruction-file precedence chain with per-platform paths, `@path` imports, plugin layout and the extend-versus-replace behaviour of each manifest field, and the documented size and count budgets in one table — citing `claude-directory.md`, `memory.md`, `plugins-reference.md` and `plugins.md` per section (FR-001)
- [x] T018 [US2] Add an "In this repository" paragraph to each section of `docs/claude-code-project-structure.md`, and a "Recorded gaps" section carrying the open questions from `research.md` (FR-002)
- [x] T019 [P] [US2] Create `.claude/rules/repository-docs.md` with `paths:` frontmatter listing `docs/**` and `CLAUDE.md`. The key is `paths`, not `path` — without it the file loads unconditionally at launch (FR-005)
- [x] T020 [US2] Write the body of `.claude/rules/repository-docs.md`: the under-200-line target, the three-way choice between always-loaded file, path-scoped rule and skill, the cite-a-source-or-record-a-gap requirement, and the "In this repository" convention — linking to the docs for reasoning rather than restating it, as `.claude/rules/skill-authoring.md:8` does
- [x] T020a [US2] Confirm `.claude/rules/repository-docs.md` is named in none of the six exclusion declarations — `.prettierignore`, `ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `Exclude` in `.editorconfig-checker.json`, the marked block in `.shellcheckrc` — so `format`, `markdown` and `editorconfig` all reach it. Narrow any exclusion that would swallow it (FR-006)
- [x] T021 [P] [US2] Correct the hook event list in `docs/claude-code-practices.md`, which names 12 events where the documentation now lists 32 (`research.md` F10)
- [x] T022 [P] [US2] Add the brace exemption to the `paths` budget in `docs/claude-code-practices.md` — "patterns without braces don't count against it" (F4) — and add F3, F5, F6, F8 and F9
- [x] T023 [P] [US2] Correct the description-truncation mechanism in `docs/skill-authoring-practices.md`: whole descriptions are **dropped**, least-invoked first, not shortened (F11). Record it in the existing corrections table rather than replacing the text silently (FR-003)
- [x] T024 [US2] Add the eight missing frontmatter fields and features to `docs/skill-authoring-practices.md`, and promote the basename/`name` entry from GAP to a settled finding with the documented example (F7, F14)

**Checkpoint**: the documentation set is complete and current. Verify with quickstart scenarios 3 and 11.

---

## Phase 5: User Story 3 — Not walking past a conflicted working tree (Priority: P2)

**Goal**: a conflicted tree is detected at every boundary and handed off, and a clean tree is reported rather than passed over in silence.

**Independent Test**: quickstart scenarios 6 and 9 — including the case a `git status` grep would miss, an interrupted rebase with a clean working tree.

- [x] T025 [P] [US3] Create `skills/ccd-speckit-run/scripts/conflict-state.sh` per [contracts/conflict-state-cli.md](./contracts/conflict-state-cli.md): POSIX `sh`, tabs, fail fast, tab-separated `key<TAB>value` output matching the existing scripts' format
- [x] T026 [US3] Implement both verdict conditions in `conflict-state.sh` — `git ls-files -u`, and the presence of `MERGE_HEAD` / `REBASE_HEAD` / `CHERRY_PICK_HEAD` / `REVERT_HEAD` / `rebase-merge/` / `rebase-apply/` under `--git-dir`. Use `--git-dir`, not `--git-common-dir`: an in-progress operation belongs to the worktree running it
- [x] T027 [US3] Check the `git ls-files -u` exit status directly rather than piping into `wc -l`, which reports `wc`'s status and would mask a git failure (constitution Principle II)
- [x] T028 [US3] Verify with `shellcheck --shell=sh skills/ccd-speckit-run/scripts/conflict-state.sh` and confirm zero findings (Principle IV)
- [x] T029 [US3] Add the boundary check to `skills/ccd-speckit-run/reference/conflicts.md`: run after each step and phase, dispatch `Skill(skill: "claude-code-devkit:ccd-conflict-resolve")` on a conflicted verdict, report "checked, clean" otherwise (FR-014, FR-015, FR-016)
- [x] T030 [US3] Specify in `skills/ccd-speckit-run/reference/conflicts.md` that the caller reads `verdict` and never the exit status — `exit 0` means the check ran, not that the tree is clean — and that a surviving conflict **stops the run** with no re-dispatch (CHK021)
- [x] T031 [P] [US3] Correct `CLAUDE.md:13`, which states `ccd-conflict-resolve` "is dispatched by nothing" (#1). **Correct only this statement; change no heading and no section order** (FR-007a)
- [x] T032 [P] [US3] Correct `docs/skill-authoring-practices.md:63`, whose rationale for that skill omitting `disable-model-invocation` was that nothing dispatches it (#6)

**Checkpoint**: boundaries are checked and handoffs work. Verify with quickstart scenarios 6 and 9.

---

## Phase 6: User Story 4 — Choosing where to be left once the review request exists (Priority: P3)

**Goal**: one teardown question, offered when the review request is created, with choices matching the workspace mode and guards that differ by what they protect.

**Independent Test**: quickstart scenario 10 — the right choices per mode, the least-destructive one recommended, and no destructive option offered while anything is uncommitted or unpushed.

- [x] T033 [US4] Add Step 6e to `skills/ccd-speckit-run/reference/ship.md`, entered after 6b returns a review-request URL (FR-021)
- [x] T034 [US4] Specify the branch-mode choices in Step 6e: switch to the review request's target and delete the feature branch; switch and keep it; stay (recommended) (FR-022, FR-025)
- [x] T035 [US4] Specify the worktree-mode choices in Step 6e: exit, remove the worktree and delete the branch; exit and remove; exit and keep; stay (recommended) (FR-023, FR-025)
- [x] T036 [US4] Specify the two guards separately in Step 6e — branch deletion on unpushed commits, worktree removal on any uncommitted path in that directory whatever its origin — and that a withheld choice is not offered silently (FR-026, CHK031)
- [x] T037 [US4] State in Step 6e that no skip-approval phrase covers a branch deletion or a worktree removal, and that removal is `ExitWorktree(action: "keep")` then `git worktree remove`, never `action: "remove"` and never `--force` (FR-027)
- [x] T038 [US4] Fold the existing 6d into 6e in `skills/ccd-speckit-run/reference/worktree.md` and `ship.md` so one teardown question remains, not two

**Checkpoint**: teardown is offered once, correctly guarded. Verify with quickstart scenario 10.

---

## Phase 7: User Story 5 — Gathering evidence without filling the run's context (Priority: P3)

**Goal**: up to ten concurrent readers per batch, with every hard rule and the Phase 8 prohibition intact.

**Independent Test**: a run may dispatch ten independent read-only questions at once; no reader writes anything; `tasks.md` execution is not distributed.

- [x] T039 [US5] Change the cap in `skills/ccd-speckit-run/reference/subagents.md` to ten, stated as a number in exactly one place (#23, #24)
- [x] T040 [US5] State in `skills/ccd-speckit-run/reference/subagents.md` that ten is a **per-batch concurrency cap**, not a per-run budget — a run may dispatch several batches, each bounded independently of what earlier batches used (Q-002)
- [x] T041 [US5] Verify that `skills/ccd-speckit-run/reference/subagents.md`'s Phase 8 prohibition and its full reasoning are unchanged. The cap is not what forbids it, and the prohibition must survive this edit verbatim (FR-020)
- [x] T041a [US5] Verify that `skills/ccd-speckit-run/reference/subagents.md`'s hard-rules block survived the cap edit unchanged: evidence returns and decisions stay in the main run, no writes, no `AskUserQuestion` from an agent, bounded reports, name what was searched. Diff the block against `main` and confirm only the cap sentence moved (FR-019)
- [x] T042 [P] [US5] Correct the "two fan-out points" references in `skills/ccd-speckit-run/SKILL.md` and `skills/ccd-speckit-run/reference/tooling.md` (#11, #12, #33)
- [x] T043 [P] [US5] Correct the fan-out references in `skills/ccd-speckit-run/reference/evaluations.md` (#29, #30)

**Checkpoint**: all five stories complete.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: the corrections that span stories, the superseding contract, and the final verification.

- [x] T044 Correct `CLAUDE.md:20`, which states only `ccd-speckit-run` carries `disable-model-invocation`; the count is now zero (#2). **Only this line and T031's — no heading moves** (FR-007a)
- [x] T045 [P] Correct `.claude/rules/skill-authoring.md:17-19`, which states exactly one skill carries the field (#4)
- [x] T046 [P] Correct `docs/skill-authoring-practices.md:61` for both the count and the dispatch count, which becomes four (#5)
- [x] T047 [P] Narrow the recorded `disable-model-invocation` gap in `docs/skill-authoring-practices.md` per `research.md` F12 — a second documented passage now bears on it and weighs toward the strict reading. The gap is narrowed, not closed
- [x] T048 [P] Correct `README.md:66`, which describes the phase-prompt review as one item alongside the Step 1 questions (#3)
- [x] T049 [P] Correct `skills/ccd-conflict-resolve/SKILL.md:194` to point at this feature's contract and state the count of zero (#34)
- [x] T050 Add regression scenarios to `skills/ccd-speckit-run/reference/evaluations.md` for each of the four changes: a run whose proposals carry no delta, a boundary check reported silently, a teardown offered while work is uncommitted, and a batch exceeding ten (#25, #26, #27, #28)
- [x] T051 Verify all 42 entries in [contracts/falsified-statements.md](./contracts/falsified-statements.md) are handled, using that contract's own four greps (FR-028)
- [x] T052 Verify `git diff --name-only main -- specs/005-merge-conflict-resolution/` is empty — the record bucket was superseded, not edited (FR-029)
- [x] T052a Close the FR-007 proof: re-run `wc -l < CLAUDE.md` and `grep -n '^## ' CLAUDE.md` and compare both against T003's recorded baseline. The line count must be under 200 and the heading list must be identical in order. This is the measurement SC-003 requires; recording a baseline without comparing to it proves nothing (SC-003, FR-007, FR-007a)
- [x] T053 Run `sh scripts/lint.sh` and confirm it exits zero (SC-012, constitution Development Workflow)
- [x] T054 Run the [quickstart.md](./quickstart.md) scenarios and record the result of each

### T054 result

| Scenario                                   | Result                                                                                                                                                                                                                 |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 — quality gate passes                    | **PASS**, `sh scripts/lint.sh` exits 0, all seven checks                                                                                                                                                               |
| 2 — `CLAUDE.md` satisfies FR-007           | **PASS**, 54 lines, five headings identical in order to `main`, diff touches lines 13 and 20 only                                                                                                                      |
| 3 — rule declares its paths                | **PASS**, all three rule files show `paths:`; the new one is in the format check's collected list and named in no exclusion declaration                                                                                |
| 4 — zero skills carry the field            | **PASS**, frontmatter-scoped check across all six; `user-invocable` absent from all six                                                                                                                                |
| 5 — 42 falsified statements handled        | **PASS**, all four contract greps silent                                                                                                                                                                               |
| 6 — conflict script                        | **PASS** in all four cases, including the interrupted rebase with a clean tree where `git status --porcelain` shows `M  f.txt` and the script correctly reports `conflicted` / `rebase`. `shellcheck --shell=sh` clean |
| 7 — pipeline reachable both ways           | **NOT RUN.** Needs a fresh Claude Code session with the edited skill loaded; this session loaded the skill before the frontmatter changed                                                                              |
| 8 — each phase proposed separately         | **NOT RUN.** Same reason. This run exercised per-phase proposals by hand, which demonstrates the shape but does not test the shipped instructions                                                                      |
| 9 — boundary check at every boundary       | **NOT RUN** as a test of the shipped skill, same reason. The script itself is covered by scenario 6                                                                                                                    |
| 10 — teardown once a review request exists | **NOT RUN.** Needs a completed run under the edited skill                                                                                                                                                              |
| 11 — documentation complete and sourced    | **PASS**, four documents, per-section source citations, "In this repository" paragraphs, "Recorded gaps" section, corrections recorded in a table rather than applied silently                                         |

Scenarios 7 through 10 are deferred, not skipped: they test instructions this feature is editing, and a session cannot test the version of a skill it loaded before the edit. They are the first thing to run in a fresh session.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup. **Blocks every correction task** — T004 re-anchors the enumeration whose line numbers the first edit invalidates
- **US1 (Phase 3)**: depends on Foundational. The MVP
- **US2 (Phase 4)**: depends on Foundational only. Fully independent of US1 — different files entirely
- **US3 (Phase 5)**: depends on Foundational. T031 touches `CLAUDE.md`, which T044 also touches; sequence them
- **US4 (Phase 6)**: depends on Foundational. Touches `ship.md` and `worktree.md`, which no other story touches
- **US5 (Phase 7)**: depends on Foundational. T042 touches `SKILL.md`, which US1 rewrites; run US1 first
- **Polish (Phase 8)**: depends on all five stories

### User story dependencies

- **US1 (P1)**: independent. Ships the frontmatter change and the gates together, for the reason in Phase 3
- **US2 (P2)**: fully independent — `docs/` and `.claude/rules/`, touched by nothing else
- **US3 (P2)**: independent except that T031 and T044 both edit `CLAUDE.md`
- **US4 (P3)**: independent
- **US5 (P3)**: independent except for `SKILL.md`, which US1 rewrites first

### The file-contention map

Four files are touched by more than one phase, and they are where parallel work would collide:

| File                                              | Touched by                                        |
| ------------------------------------------------- | ------------------------------------------------- |
| `skills/ccd-speckit-run/SKILL.md`                 | US1 (T006–T013), US5 (T042)                       |
| `CLAUDE.md`                                       | US3 (T031), Polish (T044)                         |
| `docs/skill-authoring-practices.md`               | US2 (T023, T024), US3 (T032), Polish (T046, T047) |
| `skills/ccd-speckit-run/reference/evaluations.md` | US5 (T043), Polish (T050)                         |

Tasks touching the same file are never both marked `[P]`.

### Parallel opportunities

- T014, T015, T016 within US1 — three different reference files
- T017 and T019 within US2 — a new document and a new rule file
- T021, T022 (`claude-code-practices.md`) can run alongside T023, T024 (`skill-authoring-practices.md`)
- T031 and T032 within US3 — different files
- T042 and T043 within US5 — different files
- T045, T046, T047, T048, T049 in Polish — five different files

With the contention map respected, **US2 and US4 can be built in parallel with US1 by different sessions**; US3 and US5 should follow US1.

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Phase 1 Setup
2. Phase 2 Foundational — **do not skip T004**
3. Phase 3 US1
4. **Stop and validate**: quickstart scenarios 4, 7, 8
5. At this point the pipeline is model-reachable and per-phase gated, which is the feature request's centre of gravity

### Incremental delivery

1. Setup + Foundational → the enumeration is text-anchored
2. US1 → the pipeline changes (MVP)
3. US2 → the documentation completes — independently valuable and independently shippable
4. US3 → conflict detection
5. US4 → teardown
6. US5 → the reader cap
7. Polish → cross-cutting corrections, then T051 through T054

Each story leaves the repository in a state where `sh scripts/lint.sh` passes.

---

## Notes

- `[P]` means different files and no dependency on an incomplete task. Check it against the contention map above before running two in parallel.
- **Every Markdown file written here is reformatted under you** by the committed `PostToolUse` hook — `format`, then `markdown`, then `python`. Re-read a file after editing it when the exact bytes matter.
- **Do not hard-wrap prose.** MD013 is off by design and Prettier's `proseWrap` is unset, so it preserves. One line per paragraph, however long.
- **Do not amend `.specify/memory/constitution.md`.** `scripts/lint-citations.sh` checks three `.github` templates against its lines 167-168 and 189-190 verbatim; an edit there breaks six citation markers at once.
- **Do not edit anything under `specs/005-merge-conflict-resolution/`.** It is superseded by this feature's contract, and T052 checks that it was not touched. A global find-and-replace of "exactly one" is the way this gets broken by accident.
- `skills/ccd-speckit-run/SKILL.md` must stay under 500 lines. If US1's rewrite pushes it over, move material to a reference file rather than accepting a longer body.
- Commit after each logical group. Step 6a dispatches `claude-code-devkit:ccd-commit-push`, which owns the message and the split.
