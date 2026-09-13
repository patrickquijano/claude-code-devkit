# Tasks: GitLab MR Review Skill

**Input**: Design documents from `/specs/015-ccd-gitlab-mr-review/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/skill-interface.md, quickstart.md

**Tests**: Not requested — manual validation via quickstart.md scenarios only.

**Organization**: Tasks grouped by user story (US1: core review flow, US2: preflight validation).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Skill Directory Structure)

**Purpose**: Create the skill directory layout per plan.md Project Structure.

- [x] T001 Create skill directory structure: `skills/ccd-gitlab-mr-review/`, `scripts/`, `templates/` subdirectories
- [x] T002 [P] Create empty `skills/ccd-gitlab-mr-review/evaluations.md` placeholder for regression scenarios

---

## Phase 2: Foundational (Shared Scripts and Templates)

**Purpose**: Core infrastructure that both user stories depend on — POSIX sh scripts and markdown templates.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 [P] Create `skills/ccd-gitlab-mr-review/scripts/preflight.sh` implementing environment validation and MR detection per contracts/skill-interface.md PreflightResult entity; script MUST be POSIX sh, use `set -e`, output key-value pairs on stdout (MR_IID, MR_TITLE, MR_STATE, MR_SOURCE_BRANCH, MR_TARGET_BRANCH, CURRENT_USER, IS_REVIEWER, WEB_URL), exit 1 with stderr message on any failure; follow glab command sequence from research.md R-001
- [x] T004 [P] Create `skills/ccd-gitlab-mr-review/scripts/post-comment.sh` implementing safe comment posting per contracts/skill-interface.md Script Interface Contract; accepts two positional args `<mr-iid>` `<comment-file-path>`; uses `$(cat "$2")` pattern to avoid shell expansion; exits 0 on success printing note ID, exits 1 on failure; MUST be POSIX sh with `set -e`
- [x] T005 [P] Create `skills/ccd-gitlab-mr-review/scripts/add-reviewer.sh` implementing reviewer addition per contracts/skill-interface.md Script Interface Contract; accepts two positional args `<mr-iid>` `<username>`; always uses `+<username>` prefix per research.md R-001 caveat; reads current reviewer list before modifying to verify no accidental removal; exits 0 on success, exits 1 on failure; MUST be POSIX sh with `set -e`
- [x] T006 [P] Create `skills/ccd-gitlab-mr-review/templates/review-summary.md` implementing the change-request summary comment template per contracts/skill-interface.md Template Interface Contract; includes variables `{{VERDICT}}`, `{{DATE}}`, `{{FINDINGS_CRITICAL}}`, `{{FINDINGS_SUGGESTION}}`, `{{FINDINGS_POSITIVE}}`, `{{REVIEWER}}`; structured with severity-grouped sections per research.md R-004 format
- [x] T007 [P] Create `skills/ccd-gitlab-mr-review/templates/approval-comment.md` implementing the approval comment template per contracts/skill-interface.md Template Interface Contract; includes variables `{{DATE}}`, `{{REVIEWER}}`, `{{SUMMARY}}`

**Checkpoint**: All scripts and templates exist; user story implementation can now begin.

---

## Phase 3: User Story 2 - Preflight Validation (Priority: P2)

**Goal**: Developer receives immediate feedback about environment readiness including CLI availability and open MR existence.

**Independent Test**: Invoke skill without glab installed → reports missing tool and stops. Invoke without auth → reports auth failure and stops. Invoke on branch with no MR → reports absence and stops.

### Implementation for User Story 2

- [x] T008 [US2] Document preflight workflow steps in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-001 (glab check), FR-002 (open MR check), and edge cases (not a git repo, detached HEAD); reference `scripts/preflight.sh` invocation as `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/preflight.sh"` per research.md R-003 pattern; specify fail-fast behavior and user-facing error messages per contracts/skill-interface.md Error Handling Contract

**Checkpoint**: Preflight validation documented and testable independently via quickstart.md Scenario 4.

---

## Phase 4: User Story 1 - Review an Open Merge Request (Priority: P1) 🎯 MVP

**Goal**: Developer invokes skill, receives thorough code review of open MR, confirms verdict, and skill posts result to MR.

**Independent Test**: Invoke skill on branch with open MR → review completes → user selects verdict → comment or approval appears on MR. Verified via quickstart.md Scenarios 1, 2, 3, 5.

### Implementation for User Story 1

- [x] T009 [US1] Document reviewer-self-add workflow in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-003; conditional AskUserQuestion call when IS_REVIEWER=false from preflight output; options "Add me (Recommended)" and "Skip" per contracts/skill-interface.md User Interaction Contract; references `scripts/add-reviewer.sh` invocation
- [x] T010 [US1] Document AI review analysis workflow in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-004, FR-012, FR-013, FR-014; instructs reading MR diff via `glab mr diff`; applies Google engineering practices from research.md R-002 (design fit, functionality, complexity, tests, naming, comments, style, documentation, system health); generates ReviewFinding entities per data-model.md with severity labels (critical, suggestion, nit, fyi); prohibits hallucination and assumptions; scopes analysis to project directory only
- [x] T011 [US1] Document verdict decision workflow in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-005; AskUserQuestion call with header "Verdict", 2-4 options, first option recommended with `(Recommended)` suffix; each option description states what posting action follows and why; multiSelect false per contracts/skill-interface.md User Interaction Contract
- [x] T012 [US1] Document approval posting workflow in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-006; renders `templates/approval-comment.md` with variables populated; optional approval gate AskUserQuestion (header "Post?", Yes/No); invokes `scripts/post-comment.sh` with rendered temp file
- [x] T013 [US1] Document change-request posting workflow in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-007 and FR-016; renders `templates/review-summary.md` with findings grouped by severity per research.md R-004 format; invokes `scripts/post-comment.sh` with rendered temp file; single summary comment only, no individual line comments
- [x] T014 [US1] Document structured output format in `skills/ccd-gitlab-mr-review/SKILL.md` covering FR-011; output sections: Preflight, Review Findings, Verdict Decision, Result; shows only what is necessary per SC-005

**Checkpoint**: Full review flow documented and testable independently via quickstart.md Scenarios 1, 2, 3, 5.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Regression scenarios, frontmatter, and final validation.

- [x] T015 Write `skills/ccd-gitlab-mr-review/evaluations.md` with regression scenarios covering: preflight failures (no glab, no auth, no MR, not git repo), reviewer self-add when already listed vs not, approve vs request-changes verdict, empty diff handling, MR closed mid-review, network failure on post, reviewer add failure recovery
- [x] T016 Add SKILL.md frontmatter with `name: ccd-gitlab-mr-review` and `description` following convention from research.md R-003; do NOT include `disable-model-invocation` or `user-invocable` fields per contract at specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md
- [ ] T017 Run quickstart.md validation scenarios manually against a live GitLab MR to verify end-to-end functionality

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 2 / Preflight (Phase 3)**: Depends on Foundational (T003 preflight.sh must exist)
- **User Story 1 / Review (Phase 4)**: Depends on Foundational (all scripts and templates must exist) AND benefits from Phase 3 (preflight workflow documented first)
- **Polish (Phase 5)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 2 (P2)**: Can start after Foundational — no dependency on US1
- **User Story 1 (P1)**: Can start after Foundational — integrates with US2's preflight but independently testable

### Within Each User Story

- Scripts before SKILL.md documentation that references them
- Templates before SKILL.md documentation that references them
- Core workflow before polish

### Parallel Opportunities

- T003, T004, T005, T006, T007 are all [P] — different files, no dependencies
- T008 (US2) and T009-T014 (US1) can proceed in parallel after Phase 2
- T015 and T016 are [P] — different files

---

## Parallel Example: Foundational Phase

```text
# Launch all scripts and templates together:
Task T003: Create preflight.sh
Task T004: Create post-comment.sh
Task T005: Create add-reviewer.sh
Task T006: Create review-summary.md template
Task T007: Create approval-comment.md template
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 4: User Story 1 (core review flow)
4. **STOP and VALIDATE**: Test via quickstart.md Scenarios 1 and 2
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → full preflight coverage
4. Polish → regression scenarios and final validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All scripts MUST be POSIX sh with `set -e` per FR-010
- All glab commands follow research.md R-001 patterns
- Reviewer addition always uses `+` prefix per research.md R-001 caveat
- Comment bodies passed via file, never inline, per contracts/skill-interface.md invariant 4
