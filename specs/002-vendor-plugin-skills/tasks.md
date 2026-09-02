---
description: "Task list for distributing the toolkit's own skills"
---

# Tasks: Distribute the Toolkit's Own Skills

**Input**: Design documents from `/specs/002-vendor-plugin-skills/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: No test-task tier is generated. The specification requests none, and this repository's checks _are_ its tests -- `scripts/lint.sh` and `scripts/selftest.sh` appear as verification tasks rather than as a separate suite. Two things that cannot be checked by command are recorded as such in [quickstart.md](./quickstart.md) Scenario 12 and are not disguised as tasks here.

**Organization**: Tasks are grouped by user story so each is independently completable and verifiable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US5)
- Every task names an exact file or an exact command

## Path Conventions

Repository root. Distributed content goes to `skills/<name>/`; the source is `~/.claude/skills/<name>/`. No `src/` or `tests/` directory exists or is created -- see [plan.md](./plan.md) Structure Decision.

---

## Phase 1: Setup

**Purpose**: Establish the destination and confirm the measurements every later task depends on

- [x] T001 Create the destination directories `skills/speckit-run/`, `skills/auto-branch-push/`, `skills/auto-commit-push/`, `skills/auto-github-pr/`, `skills/auto-gitlab-mr/` -- one per distributed skill, at the location plugin auto-discovery reads (FR-001)
- [x] T002 [P] Confirm `.lintignore` needs no entry for `skills/`, by running `sh scripts/lint-scope.sh` before any file is copied and recording the verdict (FR-019, research.md §11)
- [x] T003 [P] Confirm `.claude-plugin/plugin.json` is to remain unchanged, by verifying it declares no component-path field today (plan.md Structure Decision, research.md §3)

**Checkpoint**: destination exists, scope agreement is a recorded baseline rather than an assumption

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Copy the content that every user story then corrects. Nothing here changes a single byte of what was copied -- the copy and the corrections are deliberately separate, so that `git diff` on the correction tasks shows exactly what distribution forced.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Copy `~/.claude/skills/speckit-run/SKILL.md`, `reference/` (all 14 files) and `scripts/` (5 files, excluding `branch-options.sh`) to `skills/speckit-run/`, excluding `.DS_Store` and `.markdownlint-cli2.jsonc` (FR-017, FR-018)
- [x] T005 [P] Copy `~/.claude/skills/auto-branch-push/SKILL.md`, `evaluations.md` and `scripts/branch-options.sh` to `skills/auto-branch-push/`, excluding `.markdownlint-cli2.jsonc` (FR-018, FR-024)
- [x] T006 [P] Copy `~/.claude/skills/auto-commit-push/SKILL.md` and `evaluations.md` to `skills/auto-commit-push/` (FR-024)
- [x] T007 [P] Copy `~/.claude/skills/auto-github-pr/SKILL.md`, `evaluations.md`, `scripts/reviewer-options.sh` and all 7 files under `templates/` to `skills/auto-github-pr/`, excluding `.markdownlint-cli2.jsonc` and `scripts/branch-options.sh` (FR-018, FR-024, FR-027)
- [x] T008 [P] Copy `~/.claude/skills/auto-gitlab-mr/SKILL.md`, `evaluations.md`, `scripts/member-options.sh` and `templates/default-mr-template.md` to `skills/auto-gitlab-mr/`, excluding `.markdownlint-cli2.jsonc` and `scripts/branch-options.sh` (FR-018)
- [x] T009 Verify the copy is exactly 39 files and that every distributed file is byte-identical to its source, with `diff -r` per skill directory ignoring exactly these 8 withheld paths and no others: `speckit-run/.DS_Store`, `speckit-run/.markdownlint-cli2.jsonc`, `speckit-run/scripts/branch-options.sh`, `auto-branch-push/.markdownlint-cli2.jsonc`, `auto-github-pr/.markdownlint-cli2.jsonc`, `auto-github-pr/scripts/branch-options.sh`, `auto-gitlab-mr/.markdownlint-cli2.jsonc`, `auto-gitlab-mr/scripts/branch-options.sh` (SC-008, research.md §8)
- [x] T010 Verify each skill's frontmatter `name` equals its directory basename, for all 5 (data-model.md §1 validation rules)
- [x] T011 Verify 0 files under `skills/` are outside `*.md` and `*.sh`, and that `.DS_Store` and `.markdownlint-cli2.jsonc` are absent (FR-017, SC-007, quickstart Scenario 7)

**Checkpoint**: 39 files distributed, byte-identical to source, nothing withheld leaked in. Every later task's diff is now attributable to a requirement.

---

## Phase 3: User Story 2 - A distributed skill reaches its distributed companions (Priority: P1) 🎯 MVP

**Goal**: Every dispatch and every availability probe works under a plugin install, so the pipeline does not complete successfully having silently produced neither a commit nor a pull request.

**Independent Test**: `grep` the distributed tree for bare companion names in dispatch position and for the personal-path probe; both counts reach 0. Full verification needs a real plugin install, which [quickstart.md](./quickstart.md) Scenario 12 records as not runnable from here.

**Why this is the MVP and not User Story 1**: User Story 1 is satisfied by Phase 2 alone -- copying the files makes them discoverable. This story is where the feature's value actually is, and its defect is the invisible one.

- [x] T012 [US2] Rewrite `skills/speckit-run/reference/preflight.md:40-42` to resolve companion availability from the session's own available-skills listing as authoritative, with a filesystem fallback covering both a plugin install and a personal install; keep the existing degradation text for a missing companion (FR-008, research.md §4)
- [x] T013 [US2] Update the three dispatch sites in `skills/speckit-run/reference/ship.md` (6a's `auto-commit-push`, 6b's two forge targets) to the namespaced form `claude-code-devkit:<name>` (FR-005, contracts/skill-names.md)
- [x] T014 [US2] Update `skills/speckit-run/scripts/forge-detect.sh:104,108` so the `review-skill` value it prints is the namespaced name Step 6b will dispatch (FR-005)
- [x] T015 [US2] Update `skills/speckit-run/reference/run-state.md:17` so `review_skill`'s documented values are the namespaced names (FR-005, FR-006)
- [x] T016 [P] [US2] Update the remaining `speckit-run` prose that names a companion in dispatch position -- `SKILL.md:12,14,208,210,240,244,246,247,249,265` and `ship.md:23,24,52,54,60,78,92,117,124,144,150,151` -- to the namespaced form, leaving "use X instead" pointers and red-flag wording otherwise intact (FR-005, FR-023)
- [x] T017 [P] [US2] Add to `skills/speckit-run/reference/preflight.md` the record that resolution is by namespaced name and therefore deterministic when a personal copy is also present, satisfying FR-006's recording requirement (FR-006, research.md §4)
- [x] T018 [P] [US2] Update the cross-skill pointers in `skills/auto-gitlab-mr/SKILL.md:12,14,58,184`, `skills/auto-github-pr/SKILL.md:12,14,229` and `skills/auto-branch-push/SKILL.md:12` to the namespaced form where they name a skill to invoke (FR-005)
- [x] T019 [US2] Verify 0 bare companion names remain in dispatch position across `skills/`, and that every namespaced name matches one of the 5 in contracts/skill-names.md (SC-002)

**Checkpoint**: dispatch and probing are install-form independent. The silent-success defect is closed.

---

## Phase 4: User Story 3 - A skill finds the files it ships with (Priority: P1)

**Goal**: Every path to a shipped file resolves without naming an install location.

**Independent Test**: `grep -rn '~/\.claude/skills\|/Users/' skills/` returns nothing outside the six deliberate `CLAUDE.md` mentions.

- [x] T020 [US3] Replace the `<skill-dir>` worked example at `skills/speckit-run/SKILL.md:76` with the `${CLAUDE_PLUGIN_ROOT}/skills/speckit-run/scripts/<name>.sh` form (FR-009, FR-010, research.md §3)
- [x] T021 [P] [US3] Replace the same worked example at `skills/auto-gitlab-mr/SKILL.md:29`, `skills/auto-github-pr/SKILL.md:29` and `skills/auto-branch-push/SKILL.md:28` (FR-009, FR-010)
- [x] T022 [US3] Update `skills/speckit-run/reference/preflight.md:7` so the skill-directory resolution names `${CLAUDE_PLUGIN_ROOT}/skills/speckit-run` rather than a personal path (FR-009)
- [x] T023 [US3] Update the `skill_dir` example value at `skills/speckit-run/reference/run-state.md:16` to a plugin-rooted path (FR-009)
- [x] T024 [P] [US3] Update the drift-check commands at `skills/auto-gitlab-mr/evaluations.md:96-97`, `skills/auto-github-pr/evaluations.md:110-112` and `skills/auto-branch-push/evaluations.md:104-105` -- superseded by T029 but their paths must not name a personal install in the interim (FR-009)
- [x] T025 [US3] Verify the six `~/.claude/CLAUDE.md` occurrences at `skills/speckit-run/SKILL.md:131,259`, `reference/claude-md.md:42,178` and `reference/evaluations.md:275,284` are UNCHANGED, and that no other literal install location remains (SC-003, research.md §7)

**Checkpoint**: 16 of 16 install-location instructions corrected, 6 of 6 deliberate ones preserved.

---

## Phase 5: User Story 4 - One helper, not four copies (Priority: P2)

**Goal**: One `branch-options.sh`, the four consumers agreeing by construction, and the record of which behaviour won.

**Independent Test**: `find skills -name branch-options.sh | wc -l` is 1, and all four consumers reference that path.

- [x] T026 [US4] Confirm `skills/auto-branch-push/scripts/branch-options.sh` is the 88-line implementation (`md5 70edb6aeff4841a992b13a0a66ba0ac0`) and is the only copy under `skills/` (FR-011, SC-004)
- [x] T027 [US4] Point `skills/auto-github-pr/SKILL.md:68,201` and `skills/auto-gitlab-mr/SKILL.md:67,172` at `${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh` (FR-012, contracts/branch-options.md)
- [x] T028 [US4] Point `skills/speckit-run/SKILL.md`'s script table and `reference/base-branch.md:16` at the same path, and correct `base-branch.md`'s output-contract prose -- the fourth column is now `default`/`current` tags, and the order is default-branch-first then newest -- recording FR-011 as the requirement that forced it (FR-012, FR-013, FR-023, research.md §6)
- [x] T029 [US4] Replace the three `cmp -s` drift-detection scenarios in `skills/auto-branch-push/evaluations.md`, `skills/auto-github-pr/evaluations.md` and `skills/auto-gitlab-mr/evaluations.md` with an assertion that exactly one implementation exists and that each consumer's reference resolves to it (FR-012, contracts/branch-options.md)
- [x] T030 [US4] Correct the now-false self-assertion at `skills/auto-github-pr/SKILL.md:227` ("byte-identical in ... by design, so each stays self-contained") to describe the single shared copy (FR-011, FR-023, research.md §7, CHK022)
- [x] T031 [US4] Add the reconciliation record as a comment block at the top of `skills/auto-branch-push/scripts/branch-options.sh`, below its existing header comment, naming the three defects in the rejected 48-line fork -- the phantom `origin` row, the unborn-HEAD current-branch loss, the absent default-branch tag. The script rather than the skill document, because that is where someone tempted to "simplify" it back will be reading (FR-013)
- [x] T032 [US4] Run `sh skills/auto-branch-push/scripts/branch-options.sh` and verify no row's first column is `origin`, the first row carries `default`, and the checked-out branch carries `current` (SC-005, quickstart Scenario 5)

**Checkpoint**: 1 implementation, 4 consumers, the rejected behaviour recorded rather than forgotten.

---

## Phase 6: User Story 5 - The entry point stays an entry point (Priority: P2)

**Goal**: The frontmatter asymmetry survives distribution, and the reason is where an editor will meet it.

**Independent Test**: exactly one of the five `SKILL.md` files carries `disable-model-invocation`, and four carry a warning against acquiring it.

- [x] T033 [US5] Verify `skills/speckit-run/SKILL.md` carries `disable-model-invocation: true` and the other four carry no such field (FR-014, SC-009)
- [x] T034 [P] [US5] Verify the warnings at `skills/speckit-run/SKILL.md:265`, `skills/auto-gitlab-mr/SKILL.md:184`, `skills/auto-github-pr/SKILL.md:229` and `skills/auto-branch-push/SKILL.md:149` survived the copy and still name the field (FR-015)
- [x] T035 [US5] Record in `skills/speckit-run/SKILL.md`'s authoring note that the documentation confirms only the automatic-invocation block, so the stricter reading is the binding one (FR-015, research.md §9)

**Checkpoint**: the trap a consistency pass would walk into is closed, and documented as a trap.

---

## Phase 7: User Story 1 - Install the plugin and get the skills (Priority: P1)

**Goal**: The repository's own record stops contradicting the fact that the plugin now distributes components.

**Independent Test**: `grep` for the two contradicting statements in feature 001's record; both are amended. `scripts/lint-citations.sh` still exits 0.

**Why last despite being P1**: Phase 2 satisfied this story's functional half. What remains is the documentation half, and it must come after the other stories so it describes what was actually built.

- [x] T036 [US1] Amend `specs/001-quality-gate-plugin/research.md:210` to record that "create no component directories" was scoped to feature 001, citing that feature's own `spec.md:226` ("its contents grow later") (FR-020, SC-010, research.md §10)
- [x] T037 [US1] Amend `specs/001-quality-gate-plugin/research.md:216` to narrow the prohibition to Spec Kit's generated output by provenance rather than by name pattern, naming that `speckit-run` is authored and is not among the 36 generated `speckit-*` skills (FR-021, SC-010, research.md §10)
- [x] T038 [P] [US1] Update `CLAUDE.md:7`, which states "the commands, agents and MCP servers the toolkit advertises are not built yet" -- true before this feature, false after. Add the five skills to the Build/lint/test orientation only if it stays under the 200-line target
- [x] T039 [P] [US1] Update `README.md` so a reader learns the plugin now distributes five skills, what each does, and that installing the plugin is sufficient (FR-002)
- [x] T040 [P] [US1] Record in `skills/auto-github-pr/SKILL.md`, in the section that already describes `templates/`, which set is the skill's own never-installed fallback and which is the drop-in set for other repositories, and that neither is to be merged with this repository's own `.github/` templates -- which quote the constitution and are policed by `scripts/lint-citations.sh`. That file rather than the repository's record, because the reader who needs the distinction is editing the skill (FR-027, SC-016)

**Checkpoint**: 0 statements in the repository's record contradict the repository.

---

## Phase 8: Polish, Verification & Cross-Cutting Concerns

**Purpose**: Prove the whole thing against the repository's own gate, then hand off

- [x] T041 Run `sh scripts/lint.sh` and confirm exit 0 over the distributed content (FR-016, SC-006)
- [x] T042 [P] Run `sh scripts/lint-scope.sh` and confirm the same verdict as T002's baseline -- five declarations verified, ShellCheck unverifiable (FR-019, SC-013)
- [x] T043 [P] Run `sh scripts/selftest.sh` and confirm exit 0, proving the checks still reject bad input
- [x] T044 Run `LINT_FORCE_CONTAINER=1 sh scripts/lint.sh` and confirm the container path gives the same verdict as the native path
- [x] T045 [P] Walk [quickstart.md](./quickstart.md) Scenarios 1-11 including 9a and record the actual result of each against its success criterion. Scenario 1 is the only check of SC-001 and Scenario 10 the only check of SC-014, so a skipped scenario here leaves a criterion unverified rather than merely unrecorded (SC-001, SC-014)
- [x] T046 [P] Verify every one of the 47 source files has a recorded distribute-or-withhold decision, against research.md §8 and plan.md's Scale/Scope (FR-018, SC-008)
- [x] T047 Verify every change made in Phases 3-7 is traceable to a numbered requirement, and that 0 changes to questions, wording, step order or recorded outcomes lack such a trace. This is also where FR-003 and FR-004 are checked, since neither has a task of its own: confirm that no distributed file's behaviour, questions or step order differs between the two install forms, and that no distributed file branches on how it was installed (FR-003, FR-004, FR-023, SC-012)
- [x] T047a [P] Verify FR-022's research record: `research.md` §1 (general practice), §2 (skill authoring) and §3 (plugin authoring) each carry at least one cited source, and every documentation URL cited across the file resolves to the page it claims. 3 of 3 areas, 0 dead citations (FR-022, SC-011)
- [x] T047b [P] Verify FR-007's premise rather than assuming it: confirm each of the three dispatch targets -- `auto-commit-push`, `auto-github-pr`, `auto-gitlab-mr` -- has a documented rule in its own `SKILL.md` for what happens when it cannot do its work, so that `speckit-run`'s "follows that skill's documented rule for an unavailable companion" names something real. Where one has no such rule, record that FR-007 rests on an assumption for that skill rather than reporting it satisfied (FR-007, CHK029)
- [x] T048 Screen all 39 distributed files for credential-shaped content and for the maintainer's email address before anything is committed

**Checkpoint**: the gate has been run, not reasoned about. Ready to ship.

---

## Phase 9: Post-Ship — the removal (NOT an implementation task)

**⚠️ This phase does not run during `implement`.** It runs after shipping completes, and it deletes files outside the repository.

**Why it is here rather than in Phase 8**: this feature's own delivery executes from the copies it removes. `speckit-run`'s Step 6 invokes `dirty-diff.sh compare` and `cleanup-plan.sh` from the personal install, after implementation finishes. A removal placed among the implementation tasks would delete the tooling that has not finished running ([research.md](./research.md) §12, spec Edge Cases).

- [ ] T049 Confirm all three preconditions: `sh scripts/lint.sh` exits 0; the work is committed and pushed; and all five distributed skills have been confirmed present and invocable under a real plugin install ([quickstart.md](./quickstart.md) Scenario 12) (FR-025)
- [ ] T050 Obtain confirmation immediately before deleting, separate from the specification-time answer that chose removal -- the clarification authorised a requirement, not an executing deletion (FR-026)
- [ ] T051 Remove `~/.claude/skills/speckit-run`, `~/.claude/skills/auto-branch-push`, `~/.claude/skills/auto-commit-push`, `~/.claude/skills/auto-github-pr` and `~/.claude/skills/auto-gitlab-mr`, then verify 0 of 5 remain and that `graphify`, `heroui-react` and `lean-ctx` are untouched (FR-025, SC-015, spec Out of Scope)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies
- **Phase 2 (Foundational)**: depends on Phase 1 — **BLOCKS every user story**, because there is nothing to correct until the files exist
- **Phases 3-7 (User Stories)**: all depend on Phase 2. US2, US3, US4 and US5 are mutually independent and could proceed in parallel. US1's documentation half (Phase 7) is best last, so it describes what was built
- **Phase 8 (Verification)**: depends on every story phase being complete
- **Phase 9 (Removal)**: depends on Phase 8 **and on shipping**. Not part of `implement`

### Task-Level Dependencies Worth Naming

- T009-T011 gate everything after them: an unverified copy makes every later diff unattributable
- T026 must precede T027, T028 and T032 — the consumers cannot be pointed at a copy not yet confirmed
- T028 and T031 are the FR-013 pair: the contract correction and the reconciliation record
- T047 depends on all of Phases 3-7, since it audits their traceability
- T049 depends on T041 and on an event outside this task list

### Parallel Opportunities

- T002 and T003 (Phase 1)
- T005-T008 (four separate skill directories, no shared file)
- T016, T017 and T018 (different files)
- T021 and T024 (different files)
- T034 within US5
- T038, T039 and T040 (Phase 7)
- T042, T043, T045 and T046 (Phase 8, read-only)

---

## Parallel Example: Phase 2

```bash
# The four auto-* copies touch four separate directories:
Task: "Copy auto-branch-push to skills/auto-branch-push/ excluding .markdownlint-cli2.jsonc"
Task: "Copy auto-commit-push to skills/auto-commit-push/"
Task: "Copy auto-github-pr to skills/auto-github-pr/ excluding its config and branch-options.sh"
Task: "Copy auto-gitlab-mr to skills/auto-gitlab-mr/ excluding its config and branch-options.sh"
```

`speckit-run`'s copy (T004) is listed separately because it is the largest and has the most exclusions, not because it conflicts.

---

## Implementation Strategy

### MVP scope

**Phases 1, 2 and 3.** Phase 2 alone makes all five skills discoverable and satisfies User Story 1's functional half, but shipping there would distribute a `speckit-run` that reports success while silently producing neither a commit nor a pull request. Phase 3 closes that, and is the smallest increment worth distributing.

### Incremental delivery

1. Phases 1-2 → the five skills exist where auto-discovery looks
2. Phase 3 → dispatch and probing work under a plugin install **(MVP)**
3. Phase 4 → shipped files are reachable
4. Phase 5 → one helper, and the defective fork is gone
5. Phase 6 → the frontmatter trap is closed
6. Phase 7 → the record stops contradicting the repository
7. Phase 8 → the gate is run
8. Phase 9 → the source is removed, after shipping

### Notes

- `[P]` means different files and no dependency on an incomplete task
- Phase 2 deliberately changes nothing it copies, so every later diff is attributable to a requirement — this is what makes T047 and SC-012 checkable rather than rhetorical
- The repository's checks see `skills/` from the moment files exist, before commit, because the runner's file list comes from `git ls-files --cached --others --exclude-standard`. T041 is therefore meaningful during implementation
- Phase 9 is irreversible and is not covered by any approval given earlier in this feature
