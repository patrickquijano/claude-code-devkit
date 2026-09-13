# Tasks: ccd-readme

**Input**: Design documents from `/specs/014-ccd-readme/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested; validation scenarios are covered by quickstart.md and executed during implement verification.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Skill Scaffold)

**Purpose**: Create skill directory structure and placeholder files per plan.md project structure.

- [X] T001 Create skill directory structure: `skills/ccd-readme/`, `skills/ccd-readme/scripts/`, `skills/ccd-readme/templates/`, `skills/ccd-readme/references/`
- [X] T002 [P] Create empty `skills/ccd-readme/SKILL.md` with frontmatter placeholder
- [X] T003 [P] Create empty `skills/ccd-readme/scripts/inspect-project.sh` with shebang and POSIX header
- [X] T004 [P] Create empty `skills/ccd-readme/scripts/validate-readme.sh` with shebang and POSIX header
- [X] T005 [P] Create empty `skills/ccd-readme/templates/readme-base.md`
- [X] T006 [P] Create empty `skills/ccd-readme/templates/license-MIT.md`
- [X] T007 [P] Create empty `skills/ccd-readme/templates/license-Apache-2.0.md`
- [X] T008 [P] Create empty `skills/ccd-readme/templates/license-ISC.md`
- [X] T009 [P] Create empty `skills/ccd-readme/templates/license-GPL-3.0.md`
- [X] T010 [P] Create empty `skills/ccd-readme/references/readme-best-practices.md`
- [X] T011 [P] Create empty `skills/ccd-readme/references/license-guide.md`
- [X] T012 [P] Create empty `skills/ccd-readme/references/skill-structure.md`

---

## Phase 2: Foundational (Scripts & Templates)

**Purpose**: Deterministic inspection and validation logic, plus structural templates. MUST complete before any user story tasks. FR-008 requires all deterministic logic in scripts, not SKILL.md.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T013 Implement `scripts/inspect-project.sh`: detect package manifests (package.json, Cargo.toml, pyproject.toml, go.mod, Gemfile, composer.json), extract project_name, description, languages, dependencies, ci_systems, existing_docs, license_state, readme_exists, readme_language, has_nested_projects; output JSON to stdout; exit non-zero on unreadable directory (data-model.md §ProjectInspectionResult)
- [X] T014 [P] Implement `scripts/validate-readme.sh`: accept README.md path as argument; check section presence (title, install, usage, license if applicable); verify no broken markdown links; validate SKILL.md line count ≤500; validate zero inline shell control-flow keywords in SKILL.md; exit non-zero on first failure (SC-005, SC-006, quickstart.md VS-006, VS-007)
- [X] T015 [P] Populate `templates/readme-base.md` with Standard Readme structural skeleton: title+badges placeholder, description, install, usage, API/docs, contributing, license sections with HTML comment markers for provenance tracking (research.md R-002)
- [X] T016 [P] Populate `templates/license-MIT.md` with SPDX-standard MIT text from authoritative source (research.md R-003)
- [X] T017 [P] Populate `templates/license-Apache-2.0.md` with SPDX-standard Apache-2.0 text
- [X] T018 [P] Populate `templates/license-ISC.md` with SPDX-standard ISC text
- [X] T019 [P] Populate `templates/license-GPL-3.0.md` with SPDX-standard GPL-3.0-only text
- [X] T020 [P] Populate `references/readme-best-practices.md` with citations to Standard Readme spec, GitHub README guidance, and section-to-artifact mapping table (research.md R-002)
- [X] T021 [P] Populate `references/license-guide.md` with decision criteria for each supported license, recommendation rationale template, and mandatory non-legal-advice notice text (FR-005, Constitution VII)
- [X] T022 [P] Populate `references/skill-structure.md` with links to `.claude/rules/skill-authoring.md`, progressive disclosure rules, and line-budget enforcement reference (FR-009, FR-010)

**Checkpoint**: All scripts executable (`chmod +x`), all templates populated, all references cited. User story implementation can now begin.

---

## Phase 3: User Story 1 — Generate README for Uninitialized Project (Priority: P1) 🎯 MVP

**Goal**: Skill inspects project without README.md, presents license options if needed, generates complete README from verified artifacts.

**Independent Test**: Invoke `/ccd-readme` in fresh clone with no README.md; verify complete, accurate README.md produced containing only traceable information (spec.md §US1 Independent Test).

### Implementation for User Story 1

- [X] T023 [US1] Implement SKILL.md trigger condition: detect absence of README.md via `inspect-project.sh` output field `readme_exists`; route to generation workflow (FR-001, spec.md §US1 Acceptance Scenario 1)
- [X] T024 [US1] Implement SKILL.md license decision flow: when `license_state` is `missing` or `present-inconsistent`, invoke `AskUserQuestion` with recommended option, justification, and non-legal-advice notice; block README generation until selection received or user declines (FR-005, FR-006, FR-007)
- [X] T025 [US1] Implement SKILL.md README assembly: read `templates/readme-base.md`; populate sections from `inspect-project.sh` JSON output; map each section to source artifact path; write README.md to target directory (FR-001, FR-014, data-model.md §ReadmeSection VR-001)
- [X] T026 [US1] Implement SKILL.md LICENSE.md creation: after explicit user selection, read corresponding `templates/license-{SPDX}.md`; write LICENSE.md to target directory; skip if user declines and note in output (FR-006, spec.md §Edge Cases)
- [X] T027 [US1] Implement SKILL.md insufficient-information guard: when `inspect-project.sh` reports no recognizable artifacts, invoke `AskUserQuestion` with focused question instead of generating speculative content (FR-002, FR-011, spec.md §US1 Acceptance Scenario 3)
- [X] T028 [US1] Run quickstart.md VS-001 validation scenario; verify README.md created, LICENSE.md created after selection, no hallucinated content

**Checkpoint**: User Story 1 fully functional. Invoke `/ccd-readme` in empty project → README + LICENSE generated from verified artifacts only.

---

## Phase 4: User Story 2 — Improve Existing README (Priority: P2)

**Goal**: Skill preserves accurate existing README content, adds or corrects sections based on verified repository state.

**Independent Test**: Invoke `/ccd-readme` in project with partial/outdated README.md; verify accurate sections preserved, missing sections added, inaccurate sections flagged with evidence (spec.md §US2 Independent Test).

### Implementation for User Story 2

- [X] T029 [US2] Implement SKILL.md existing-README detection: when `readme_exists` is true, parse existing README into sections; classify each as accurate (matches verified artifacts), inaccurate (contradicts artifacts), or unverifiable (no corresponding artifact) (FR-003, data-model.md §ReadmeSection `preserved_from_existing`)
- [X] T030 [US2] Implement SKILL.md content preservation: carry forward all accurate sections byte-identical; flag inaccurate sections with evidence citation and proposed correction; never remove accurate content (FR-003, SC-003, data-model.md VR-003)
- [X] T031 [US2] Implement SKILL.md gap filling: add missing sections (install, usage, license, contributing) from verified artifacts when absent in existing README; preserve existing language detected by `readme_language` field (spec.md §Edge Cases language handling)
- [X] T032 [US2] Implement SKILL.md no-change report: when existing README is fully accurate and complete, report no changes needed and do not modify file (spec.md §US2 Acceptance Scenario 2)
- [X] T033 [US2] Run quickstart.md VS-002 validation scenario; verify custom section preserved, author content preserved, version traced from manifest

**Checkpoint**: User Stories 1 and 2 both independently functional.

---

## Phase 5: User Story 3 — License Decision Flow (Priority: P3)

**Goal**: Safety-gated license selection with recommendation, justification, and non-legal-advice notice; LICENSE.md created only after explicit user choice.

**Independent Test**: Invoke `/ccd-readme` in project with no license; verify AskUserQuestion presents ≥3 options with recommendation and notice; LICENSE.md created only after selection (spec.md §US3 Independent Test).

### Implementation for User Story 3

- [X] T034 [US3] Implement SKILL.md license-state routing: when `license_state` is `present-consistent`, skip license flow entirely; when `present-inconsistent`, offer reconciliation; when `missing` or `ambiguous`, present full selection (FR-004, data-model.md §LicenseState)
- [X] T035 [US3] Implement SKILL.md AskUserQuestion license prompt: present ≥3 SPDX options with exactly one recommended; include concise justification per research.md R-003; include mandatory non-legal-advice notice from `references/license-guide.md` (FR-005, Constitution VII)
- [X] T036 [US3] Implement SKILL.md license-template lazy load: read `templates/license-{selected}.md` only after user selection; never load unused templates (FR-007)
- [X] T037 [US3] Implement SKILL.md decline handling: when user declines license selection, proceed with README generation omitting license section; note in output that licensing was skipped (spec.md §Edge Cases)
- [X] T038 [US3] Run quickstart.md VS-003 validation scenario; verify LICENSE created after selection, license section omitted when declined

**Checkpoint**: All three user stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Idempotency, non-destructiveness, monorepo handling, final validation.

- [X] T039 [P] Implement idempotency safeguards: exclude timestamps from all generated content; use sorted glob expansion for file ordering; verify byte-identical output on re-run (FR-012, SC-007, research.md R-005)
- [X] T040 [P] Implement non-destructiveness guard: before overwriting any existing file, create `.bak` backup or confirm recoverable content preservation; log what was preserved (FR-013)
- [X] T041 [P] Implement monorepo/nested-project detection: when `has_nested_projects` is true, invoke `AskUserQuestion` to clarify scope before generating any content (data-model.md VR-004, spec.md §Edge Cases)
- [X] T042 Run quickstart.md VS-004 idempotency check; verify `diff` produces no output on re-run
- [X] T043 Run quickstart.md VS-005 insufficient-information scenario; verify focused question asked, no speculative content
- [X] T044 Run quickstart.md VS-006 and VS-007 structural checks; verify SKILL.md ≤500 lines and zero inline shell logic
- [X] T045 Final constitution compliance review: verify all 7 principles satisfied post-implementation; document any deviations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 directory structure — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2 scripts and templates
- **User Story 2 (Phase 4)**: Depends on Phase 2; may integrate with US1 but independently testable
- **User Story 3 (Phase 5)**: Depends on Phase 2; integrates with US1 license flow but independently testable
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (P2)**: Can start after Phase 2 — independently testable
- **US3 (P3)**: Can start after Phase 2 — integrates with US1 license routing but independently testable

### Parallel Opportunities

- All Phase 1 tasks marked [P] can run in parallel (T002–T012)
- All Phase 2 script/template tasks marked [P] can run in parallel (T014–T022) after T013 completes
- Within each user story, tasks are sequential (orchestration depends on prior steps)
- Phase 6 polish tasks marked [P] can run in parallel (T039–T041)

---

## Parallel Example: Phase 1 Setup

```bash
# Launch all placeholder file creations together:
Task: T002 Create empty SKILL.md
Task: T003 Create empty inspect-project.sh
Task: T004 Create empty validate-readme.sh
Task: T005-T012 Create empty templates and references
```

## Parallel Example: Phase 2 Foundational

```bash
# After T013 (inspect-project.sh) completes, launch all parallel tasks:
Task: T014 Implement validate-readme.sh
Task: T015 Populate readme-base.md
Task: T016-T019 Populate license templates
Task: T020-T022 Populate reference documents
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run VS-001; test independently
5. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Validate VS-001 → MVP!
3. Add US2 → Validate VS-002 → Improvement flow
4. Add US3 → Validate VS-003 → License safety
5. Polish → Validate VS-004–VS-007 → Ship

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All scripts must pass ShellCheck in POSIX mode (Constitution IV)
- SKILL.md must remain under 500 lines throughout (FR-009, SC-005)
