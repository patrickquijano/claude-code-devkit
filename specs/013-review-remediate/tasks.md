---
description: 'Task list for ccd-review-remediate skill implementation'
---

# Tasks: Change-Request Review and Remediation

**Input**: Design documents from `/specs/013-review-remediate/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/gate-decision.md, quickstart.md

**Tests**: Not explicitly requested in spec; test tasks omitted. Validation via quickstart.md scenarios post-implementation.

**Organization**: Tasks grouped by user story (US1 = review-only, US2 = remediation) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Include exact file paths in descriptions

## Path Conventions

All paths relative to repository root. Skill lives under `skills/ccd-review-remediate/`. Shared scripts reached via `${CLAUDE_PLUGIN_ROOT}`.

---

## Phase 1: Setup (Skill Skeleton)

**Purpose**: Create directory structure and entry point so subsequent phases have files to edit.

- [x] T001 Create skill directory structure per plan.md Project Source Code tree in skills/ccd-review-remediate/
- [x] T002 [P] Write SKILL.md frontmatter (name: ccd-review-remediate, description) and thin entry point with reference map table in skills/ccd-review-remediate/SKILL.md
- [x] T003 [P] Write evaluations.md with validation scenarios for skill authors in skills/ccd-review-remediate/evaluations.md

**Checkpoint**: Skill directory exists, SKILL.md loads without error, evaluations.md present.

---

## Phase 2: Foundational (Scripts and Templates)

**Purpose**: Deterministic shell scripts and Markdown templates that all user stories depend on. MUST complete before US1 or US2.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T004 [P] Write preflight.sh: forge detection via forge-detect.sh, CLI auth probe, CR discovery (single/multiple/none), head_sha capture, dirty-tree check in skills/ccd-review-remediate/scripts/preflight.sh
- [x] T005 [P] Write collect-context.sh: gather diff, comments, discussions, approvals, CI status, mergeability, assignees, reviewers via gh/glab CLI in skills/ccd-review-remediate/scripts/collect-context.sh
- [x] T006 [P] Write verify-repository.sh: resolve validation command per CHK005 precedence, execute it, report exit code and output excerpt in skills/ccd-review-remediate/scripts/verify-repository.sh
- [x] T007 [P] Write permission-check.sh: read-only permission probe via gh api / glab api, cache result, report write/admin/skip in skills/ccd-review-remediate/scripts/permission-check.sh
- [x] T008 [P] Write review-findings.md template: finding output format with ID, severity, confidence, category, file, line, evidence, impact, required_outcome, suggested_fix, validation_method in skills/ccd-review-remediate/templates/review-findings.md
- [x] T009 [P] Write approval-summary.md template: pass verdict summary with criteria checked and how each satisfied in skills/ccd-review-remediate/templates/approval-summary.md
- [x] T010 [P] Write remediation-summary.md template: finding-ID-to-resolution mapping with files changed, checks run, commit SHA in skills/ccd-review-remediate/templates/remediation-summary.md
- [x] T011 [P] Write review-checklist.md reference: eleven review dimensions with guidance per dimension in skills/ccd-review-remediate/reference/review-checklist.md
- [x] T012 [P] Write severity-model.md reference: six severities (Critical/High/Medium/Low/Suggestion/Question), three confidences (high/medium/low), blocking rules per CHK003 in skills/ccd-review-remediate/reference/severity-model.md
- [x] T013 [P] Write validation.md reference: validation-command precedence per CHK005, override protocol per FR-048 in skills/ccd-review-remediate/reference/validation.md

**Checkpoint**: All four scripts pass `shellcheck --shell=sh`. All three templates render valid Markdown. All three references load without error. User story implementation can now begin.

---

## Phase 3: User Story 1 — Review and Publish Findings (Priority: P1) 🎯 MVP

**Goal**: Review open CR, produce evidence-backed findings, state verdict against six pass criteria, publish to CR when permitted.

**Independent Test**: On branch with exactly one open CR and clean working tree, invoke skill; confirm findings cite evidence, verdict states per-criterion status, working tree unchanged, no commits pushed.

### Implementation for User Story 1

- [x] T014 [US1] Write github.md reference: verified gh CLI commands for view, diff, review, comment, inline comment, assign, add-reviewer, merge per research.md CLI Syntax Verification in skills/ccd-review-remediate/reference/github.md
- [x] T015 [US1] Write gitlab.md reference: verified glab CLI commands for view, diff, approve, note, inline discussion, resolve, merge, update per research.md CLI Syntax Verification in skills/ccd-review-remediate/reference/gitlab.md
- [x] T016 [US1] Implement Step 0 preflight orchestration in SKILL.md: invoke preflight.sh, parse verdict, record forge/CLI/CR/head_sha/state, stop on unsupported-forge/no-change-request/ambiguous-cr/dirty-tree per contracts/gate-decision.md G1-G3 in skills/ccd-review-remediate/SKILL.md
- [x] T017 [US1] Implement Step 1 context collection orchestration in SKILL.md: invoke collect-context.sh, populate ChangeRequest entity fields, detect self-author (FR-047), cache permission probe result (CHK010) in skills/ccd-review-remediate/SKILL.md
- [x] T018 [US1] Implement Step 2 review logic in SKILL.md: read diff against review-checklist.md dimensions, classify findings per severity-model.md, deduplicate against existing comments (FR-012), produce Finding entities with all required fields in skills/ccd-review-remediate/SKILL.md
- [x] T019 [US1] Implement Step 3 verdict evaluation in SKILL.md: evaluate six G6 criteria, produce ReviewVerdict with per-criterion CriterionStatus, handle override per FR-048, never report unchecked criterion as satisfied (SC-012) in skills/ccd-review-remediate/SKILL.md
- [x] T020 [US1] Implement Step 4 publish logic in SKILL.md: permission pre-check (G4), self-author comment-only path (G5/FR-047), approve/request-changes/comment dispatch via forge-specific reference, audit entry per CHK011, preview-mode suppression (FR-041) in skills/ccd-review-remediate/SKILL.md
- [x] T021 [US1] Implement stopping conditions in SKILL.md: every stop from contracts/gate-decision.md closed outcome vocabulary produces stated reason, never guesses or partially acts (SC-010) in skills/ccd-review-remediate/SKILL.md

**Checkpoint**: User Story 1 fully functional. Invoke on test branch, confirm findings published, verdict stated, working tree clean. Independent of US2.

---

## Phase 4: User Story 2 — Remediate, Re-review, Merge (Priority: P2)

**Goal**: When explicitly authorized, fix findings, validate, re-review up to five cycles, optionally merge with squash/delete options.

**Independent Test**: After US1 produces findings, authorize remediation; confirm fixes applied, validation passes, remediation summary published, re-review confirms resolution, merge executes only when all gates pass.

### Implementation for User Story 2

- [x] T022 [US2] Implement remediation authorization gate in SKILL.md: explicit request required (FR-021), preview mode skips (FR-041), stopped: not-authorized when absent (G8) in skills/ccd-review-remediate/SKILL.md
- [x] T023 [US2] Implement remediation planning in SKILL.md: prioritize open findings by severity, present plan before any code change, minimal root-cause fixes only (FR-023), no unrelated refactoring in skills/ccd-review-remediate/SKILL.md
- [x] T024 [US2] Implement remediation execution in SKILL.md: apply fixes, add/update regression tests (FR-024), run targeted checks then full validation suite (FR-025), inspect final diff for unintended changes and credentials (CHK004/FR-027) in skills/ccd-review-remediate/SKILL.md
- [x] T025 [US2] Implement remediation commit and publish in SKILL.md: commit per repo convention (FR-028), push without force, publish remediation-summary.md mapping finding IDs to resolutions/files/checks/SHA (FR-026), never claim success when validation failed (FR-029) in skills/ccd-review-remediate/SKILL.md
- [x] T026 [US2] Implement partial remediation recovery in SKILL.md: on mid-cycle failure leave working tree as-is, report addressed/remaining findings, record remediation.partial=true with completed finding IDs (CHK008) in skills/ccd-review-remediate/SKILL.md
- [x] T027 [US3] Implement re-review cycle in SKILL.md: review updated diff against target branch, verify previous findings resolved, detect regressions (FR-032), create new Finding for regressions, increment cycle count in skills/ccd-review-remediate/SKILL.md
- [x] T028 [US3] Implement cycle bound enforcement in SKILL.md: stop at cycle 5 (or raised bound per FR-034), list remaining findings with severity/status, ask user to raise bound with stated new limit (G7), cycle count resets between invocations (CHK009) in skills/ccd-review-remediate/SKILL.md
- [x] T029 [US3] Implement merge authorization gate in SKILL.md: explicit merge request required (FR-035), all G6 criteria must pass, head SHA must match reviewed SHA (G9), stale-sha stops with re-review required in skills/ccd-review-remediate/SKILL.md
- [x] T030 [US3] Implement merge execution in SKILL.md: multi-select question for delete-source-branch and squash-commits (both default yes), invoke forge CLI merge command, verify remote result, switch to target branch, fetch, fast-forward only (FR-039), never unspecified rebase in skills/ccd-review-remediate/SKILL.md
- [x] T031 [US3] Implement audit trail in SKILL.md: append AuditEntry for every action (review-published, remediation-committed, merge-executed, permission-denied, cycle-bound-reached, preview-skipped) per CHK011, immutable append-only in skills/ccd-review-remediate/SKILL.md

**Checkpoint**: User Stories 1 AND 2 both functional independently. Full review→remediate→re-review→merge cycle works end-to-end.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Validation, documentation, and quality gates that affect the entire skill.

- [x] T032 Run shellcheck on all four scripts in skills/ccd-review-remediate/scripts/ and fix any violations
- [x] T033 Validate all Markdown files (SKILL.md, evaluations.md, templates/_, reference/_) pass markdownlint
- [x] T034 Verify SKILL.md frontmatter has name and description only, no disable-model-invocation, no user-invocable per authoring note
- [x] T035 Confirm shared scripts (forge-detect.sh, branch-options.sh) referenced via ${CLAUDE_PLUGIN_ROOT}, never copied
- [ ] T036 Run quickstart.md validation scenarios 1-7 against implemented skill and document results
- [ ] T037 Verify preview mode (--dry-run) end-to-end per US4 acceptance scenarios: findings produced, no publish/commit/push/approve/merge executed, working tree and CR byte-identical after run
- [ ] T038 Update evaluations.md with actual test outcomes and any discovered edge cases

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — MVP deliverable
- **User Story 2 (Phase 4)**: Depends on Foundational — may integrate with US1 but independently testable
- **Polish (Phase 5)**: Depends on both user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No dependency on US2. Delivers standalone review capability.
- **US2 (P2)**: Can start after Phase 2. Builds on review findings from US1 but each story independently testable.

### Within Each User Story

- Reference files before SKILL.md orchestration logic
- Preflight and context collection before review logic
- Review logic before verdict evaluation
- Verdict before publish
- Remediation authorization before execution
- Commit before re-review
- Cycle bound before merge

### Parallel Opportunities

- All Phase 1 tasks marked [P] can run in parallel
- All Phase 2 tasks marked [P] can run in parallel (13 independent files)
- T014 and T015 (github.md, gitlab.md) can run in parallel within US1
- US1 and US2 can be worked in parallel once Phase 2 completes (if team capacity allows)

---

## Parallel Example: Phase 2 Foundational

```text
# All 13 foundational files are independent — launch together:
Task: "Write preflight.sh in skills/ccd-review-remediate/scripts/preflight.sh"
Task: "Write collect-context.sh in skills/ccd-review-remediate/scripts/collect-context.sh"
Task: "Write verify-repository.sh in skills/ccd-review-remediate/scripts/verify-repository.sh"
Task: "Write permission-check.sh in skills/ccd-review-remediate/scripts/permission-check.sh"
Task: "Write review-findings.md template in skills/ccd-review-remediate/templates/review-findings.md"
Task: "Write approval-summary.md template in skills/ccd-review-remediate/templates/approval-summary.md"
Task: "Write remediation-summary.md template in skills/ccd-review-remediate/templates/remediation-summary.md"
Task: "Write review-checklist.md reference in skills/ccd-review-remediate/reference/review-checklist.md"
Task: "Write severity-model.md reference in skills/ccd-review-remediate/reference/severity-model.md"
Task: "Write validation.md reference in skills/ccd-review-remediate/reference/validation.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (3 tasks)
2. Complete Phase 2: Foundational (13 tasks, all parallel)
3. Complete Phase 3: User Story 1 (8 tasks)
4. **STOP and VALIDATE**: Run quickstart.md Scenario 1, 2, 3, 7
5. Ship review-only capability if ready

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test independently → Ship review-only (MVP!)
3. Add US2 → Test independently → Ship full review+remediate+merge
4. Polish → Validate all scenarios → Release

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational done:
   - Developer A: US1 (review and publish)
   - Developer B: US2 (remediate, re-review, merge)
3. Stories integrate independently via shared SKILL.md orchestration

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All scripts must pass `shellcheck --shell=sh` (Constitution Principle IV)
- No npm/pip prerequisites (Constitution Principle I)
- No disable-model-invocation in frontmatter (plugin contract)
- Forge detection in preflight.sh only, never re-detected (contracts/gate-decision.md invariant)
