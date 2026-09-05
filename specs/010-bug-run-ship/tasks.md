---
description: 'Task list for feature 010: bug triage run ships its own work'
---

# Tasks: Bug triage run ships its own work

**Input**: Design documents from `/specs/010-bug-run-ship/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No test tasks. This repository has no test framework — the quality gate is the test, and each skill carries a hand-run `evaluations.md`. Scenario tasks appear in each story's phase as evaluation entries, and the gate itself is Phase 7.

**Organization**: Tasks are grouped by user story so each can be implemented and evaluated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Include exact file paths in descriptions

## Path Conventions

This is a Claude Code plugin. The deliverable is `skills/`, with reasoning in `docs/` and imperative rules in `.claude/rules/`. All paths are repository-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the files the later phases write into, so no story phase has to create scaffolding mid-flight.

- [x] T001 Create `skills/ccd-speckit-bug-run/reference/workspace.md` as an empty stub with its `# Workspace modes` heading, so US2 and US4 can both write into it without racing
- [x] T002 Create `skills/ccd-speckit-bug-run/reference/ship.md` as an empty stub with its `# Shipping` heading, so US1 can fill it
- [x] T003 [P] Bump the minor version in `.claude-plugin/plugin.json` from `0.3.0` to `0.4.0`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Remove the prohibitions and extend the state contract. **Every user story is blocked on this phase** — the skill currently forbids in six places what US1, US2 and US4 add, and each story's state writes need the extended shape to exist first.

- [x] T004 Rewrite the frontmatter `description` in `skills/ccd-speckit-bug-run/SKILL.md` to drop "not for committing, branching, or opening a review request" and describe the run reaching a review request, keeping the whole field under 1,536 characters
- [x] T005 Rewrite `skills/ccd-speckit-bug-run/SKILL.md:200` (the closing-report "commit obligation" item) so the run discharges the obligation rather than naming it
- [x] T006 Rewrite the two red-flag rows at `skills/ccd-speckit-bug-run/SKILL.md:220` and `:224` so they forbid only what is still forbidden — acting without being asked, and performing a sub-skill's work inline
- [x] T007 Rewrite `skills/ccd-speckit-bug-run/reference/stages.md:96` ("Never create a branch, commit, or open a review request") into the delegation rules that replace it
- [x] T008 Extend `skills/ccd-speckit-bug-run/reference/run-state.md` with the `tooling`, `workspace`, `worktree`, `branch`, `cycles` and `ship` blocks and their write rules, per `contracts/bug-run-state.md`
- [x] T009 Extend `skills/ccd-speckit-bug-run/scripts/bug-preflight.sh` to report the workspace facts Step 1 needs — whether this is a git repository, whether `git worktree` works, whether the session is already inside a worktree, and whether submodules are present — as tab-separated key/value lines matching its existing output style, POSIX `sh`, fail-fast
- [x] T010 Add the forge probe to Step 0 of `skills/ccd-speckit-bug-run/SKILL.md`, invoking `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh"` and recording `tooling.forge`, `tooling.review_skill`, `tooling.forge_cli` and `tooling.forge_cli_status`
- [x] T011 Add the companion-skill probe to Step 0 of `skills/ccd-speckit-bug-run/SKILL.md`, resolving `claude-code-devkit:ccd-commit-push` and the review skill from the session's own skills listing, recording each as found, missing or undetermined, and treating undetermined as present

**Checkpoint**: The skill no longer forbids what the feature adds, and the state file's shape is documented. User stories may now proceed.

---

## Phase 3: User Story 1 — The run reaches a review request without changing tools (Priority: P1)

**Goal**: A run whose validation succeeds commits its work and raises a review request, delegating both.

**Independent test**: Run the full triage on a defect that validates cleanly; a review request exists at the end carrying commits that include all three reports, with no workflow invoked by hand. (quickstart scenario 1.)

- [x] T012 [US1] Write the commit sub-step into `skills/ccd-speckit-bug-run/reference/ship.md`: the three-option `Commit?` question mirrored from `ccd-speckit-run/reference/ship.md` 6a, the explicit path list handed over, the credential-shaped exclusion, and the rule that option 1 disappears when `ccd-commit-push` is absent rather than falling back to an inline commit
- [x] T013 [US1] Write the review-request sub-step into `skills/ccd-speckit-bug-run/reference/ship.md`: the routing table keyed on `tooling.review_skill`, the facts-not-answers rule, the skip table for unsupported forge / no remote / missing skill / missing or unauthenticated CLI, and the rule that the target branch is learned from the skill and never supplied to it
- [x] T014 [US1] Add "dispatch is a tool call, not a phrase" to `skills/ccd-speckit-bug-run/reference/ship.md`, stating that prose naming a skill loads nothing and the sub-skill's gates then do not exist for that run
- [x] T015 [US1] Add Step 4a and Step 4b to `skills/ccd-speckit-bug-run/SKILL.md`, each with its per-step proposal and `AskUserQuestion` gate, delegating to `reference/ship.md` for the detail
- [x] T016 [US1] Add the re-check after the commit dispatch returns to `skills/ccd-speckit-bug-run/SKILL.md` Step 4a — re-partition the dirty tree and re-read the commit range rather than assuming the dispatch succeeded
- [x] T017 [US1] Add the skip paths to `skills/ccd-speckit-bug-run/SKILL.md`: a skipped or not-applied remediation skips both shipping steps with that reason, and a declined commit skips only the review request
- [x] T018 [US1] Extend the closing report in `skills/ccd-speckit-bug-run/SKILL.md` to state the commit range, the forge, the review request's URL under that forge's own name for it, and `ship.subskill_calls` for both dispatches
- [x] T019 [P] [US1] Add quickstart scenarios 1, 2, 5 and 6 to `skills/ccd-speckit-bug-run/evaluations.md`, and rewrite `evaluations.md:56` ("**No** branch created, **no** commit, **no** review request") into its replacement

**Checkpoint**: US1 is independently deliverable — a successful run now ships, even with no workspace choice and no loop.

---

## Phase 4: User Story 2 — The maintainer chooses where the work happens (Priority: P1)

**Goal**: The workspace question precedes every stage, offers only applicable choices, and is carried out and verified.

**Independent test**: Start runs from a clean tree, a dirty tree, and inside a worktree; each offers only the choices that make sense and honours the pick. (quickstart scenarios 7 and 9.)

- [x] T020 [US2] Write the mode-choice section of `skills/ccd-speckit-bug-run/reference/workspace.md`: the four options, which conditions withhold each, and the rule that a withheld option's absence is explained rather than silent, per `contracts/workspace-options.md`
- [x] T021 [US2] Write the worktree create/exclude/enter/verify sequence into `skills/ccd-speckit-bug-run/reference/workspace.md`, including `--detach` and why, the `info/exclude` append, `EnterWorktree(path:)` and the mandatory `git rev-parse --show-toplevel` verification
- [x] T022 [US2] Write the branch-mode and stay-put paths into `skills/ccd-speckit-bug-run/reference/workspace.md`, using `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh"` for base candidates and never enumerating branches by hand
- [x] T023 [US2] Add Step 1 to `skills/ccd-speckit-bug-run/SKILL.md` with its proposal and gate, placed before Stage 1, writing `workspace` to state the moment the answer returns
- [x] T024 [US2] Add the not-a-git-repository path to `skills/ccd-speckit-bug-run/SKILL.md` Step 1 — skip the step, record the reason, continue, never `git init`
- [x] T025 [US2] Add the Stage 1 precondition that `workspace` is non-null to `skills/ccd-speckit-bug-run/reference/run-state.md` and to the Step 1 → Stage 1 boundary in `SKILL.md`
- [x] T026 [P] [US2] Add quickstart scenarios 7 and 9 to `skills/ccd-speckit-bug-run/evaluations.md`, including the created-but-not-entered failure

**Checkpoint**: US2 is independently deliverable — the workspace is chosen and honoured whether or not anything ships.

---

## Phase 5: User Story 3 — A failed validation can send the run back to assessment (Priority: P2)

**Goal**: Choosing to reassess re-enters Stage 1 carrying validation's findings, rather than ending the run.

**Independent test**: Drive a defect whose first remediation fails; choose to reassess; the run re-enters assessment with the findings and `cycles` reads 2. (quickstart scenarios 3 and 4.)

- [x] T027 [US3] Add the loop-back edge to `skills/ccd-speckit-bug-run/SKILL.md` Stage 3, so the existing "re-run the assessment with the new evidence" choice re-enters Stage 1 instead of ending the run
- [x] T028 [US3] Add `cycles` handling to `skills/ccd-speckit-bug-run/SKILL.md` and `reference/run-state.md` — starts at 1, increments on entry to a re-run assessment, never reset, never capped
- [x] T029 [US3] Require the cycle count to be stated at every such choice in `skills/ccd-speckit-bug-run/SKILL.md`, per FR-011b
- [x] T030 [US3] Update the branch table at `skills/ccd-speckit-bug-run/reference/stages.md:69` so the `partial or failed` row shows the loop-back as an outcome alongside stopping
- [x] T031 [US3] State in `skills/ccd-speckit-bug-run/SKILL.md` that a re-entered stage is proposed and approved on the same terms as a first-pass one, and that `partial` and `failed` remain identical and neither is success
- [x] T032 [P] [US3] Add quickstart scenarios 3 and 4 to `skills/ccd-speckit-bug-run/evaluations.md`, keeping the existing check that the run never re-invokes assessment on its own initiative

**Checkpoint**: US3 is independently deliverable — the loop works whether or not the run can ship.

---

## Phase 6: User Story 4 — The maintainer chooses where to be left (Priority: P2)

**Goal**: After a review request exists, one question offers the option set matching the arrangement, with both guards enforced.

**Independent test**: Finish one worktree run and one branch run; each offers the matching set and honours the pick. (quickstart scenarios 7 and 9.)

- [x] T033 [US4] Write the teardown section of `skills/ccd-speckit-bug-run/reference/workspace.md`: both option sets, the least-destructive default and why, and the `worktree.created: false` skip
- [x] T034 [US4] Write both guards into `skills/ccd-speckit-bug-run/reference/workspace.md` — branch deletion on commits being pushed, worktree removal on no uncommitted path whatever its origin — plus the bans on `--force`, `branch -D`, and `ExitWorktree(action: "remove")` for a path-entered worktree
- [x] T035 [US4] State in `skills/ccd-speckit-bug-run/reference/workspace.md` that no skip-approval phrase reaches either guarded choice
- [x] T036 [US4] Add Step 4c to `skills/ccd-speckit-bug-run/SKILL.md` with its gate, reading `workspace` to pick the option set, and skipping with a reason when no review request was raised
- [x] T037 [US4] Add the outcome verification to `skills/ccd-speckit-bug-run/SKILL.md` Step 4c — confirm with `git worktree list` and `git branch --list` rather than trusting the action, and record `worktree.teardown` or `branch.teardown`
- [x] T038 [US4] Consult `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/cleanup-plan.sh"` for the branch verdict in `skills/ccd-speckit-bug-run/reference/workspace.md` rather than re-deriving deletion rules
- [x] T039 [P] [US4] Add the teardown scenarios to `skills/ccd-speckit-bug-run/evaluations.md`, including the guarded-out case and the already-in-a-worktree case

**Checkpoint**: US4 is independently deliverable.

---

## Phase 7: User Story 5 — The review request can retire its own source line of work (Priority: P3)

**Goal**: `ccd-github-pr` offers source-branch deletion independently of auto-merge.

**Independent test**: Raise a PR choosing deletion but not auto-merge; both settings take the chosen values. (quickstart scenarios 10–12.)

- [x] T040 [US5] Split the `PR opts` question at `skills/ccd-github-pr/SKILL.md:125` into independent options — auto-merge, squash, delete source branch on merge, open as draft — keeping `multiSelect: true` and stating which are selected by default
- [x] T041 [US5] Update `skills/ccd-github-pr/SKILL.md:127` so the `deleteBranchOnMerge: true` case reports the repository default rather than offering a choice that changes nothing, and the `squashMergeAllowed: false` case drops only the squash option
- [x] T042 [US5] Update the `gh pr merge` invocation at `skills/ccd-github-pr/SKILL.md:277` so each flag is passed only when its own option was selected, and state what happens when deletion is wanted but auto-merge is not
- [x] T043 [US5] Confirm `skills/ccd-github-pr/SKILL.md:135` and `:308` still hold — update mode does not ask the merge options and changes none of them
- [x] T044 [P] [US5] Add quickstart scenarios 10, 11 and 12 to `skills/ccd-github-pr/evaluations.md`
- [x] T045 [P] [US5] Verify `skills/ccd-gitlab-mr/SKILL.md:121` already offers `Delete source branch on merge` independently, record the verification in `specs/010-bug-run-ship/research.md`, and make no edit to that skill (FR-029a)

**Checkpoint**: All five user stories delivered.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: The written record, the durable rules, and the corrections the contracts require.

- [x] T046 [P] Add a "Working efficiently" section to `docs/claude-code-practices.md` covering the context constraint, explore-plan-code-commit, subagent delegation, the two-failed-corrections rule and verification criteria, each claim citing `code.claude.com/docs/en/best-practices.md`
- [x] T047 [P] Update `docs/spec-kit-extensions.md` with the hook-event count correction (18 documented, 20 in the installed core skills), the config-path correction (`.specify/extensions.yml`, not the API reference's stale path), and a new section recording that no hook event or CLI command exists for review requests and that the bug workflow is therefore the caller's to wire
- [x] T048 [P] Add the open gaps from `specs/010-bug-run-ship/research.md` §11 to the `## Recorded gaps` section of `docs/spec-kit-extensions.md` and `docs/claude-code-practices.md` as appropriate
- [x] T049 Update `.claude/rules/spec-kit-bug-workflow.md` — the run may now branch, commit and ship; state the delegation rules and both guards, hard-wrapped near 100 columns, no tables, no URLs, delegating reasoning to its `docs/` counterpart
- [x] T050 [P] Correct the stale contract pointer in `.claude/rules/skill-authoring.md` from `specs/006-claude-code-guidance/contracts/skill-names.md` to this feature's contract
- [x] T051 [P] Correct the stale contract pointer at `skills/ccd-github-pr/SKILL.md:364` to this feature's contract
- [x] T052 Update the `ccd-speckit-bug-run` paragraph in `CLAUDE.md`, which states the run is "not for committing, branching, or opening a review request" and becomes false with this feature; keep the file under 200 lines and add no section order
- [x] T053 Confirm `skills/ccd-speckit-bug-run/SKILL.md` is under 500 lines and its frontmatter `description` under 1,536 characters; move material into the two reference files if either budget is breached
- [x] T054 Run the verification block in `specs/010-bug-run-ship/contracts/skill-names.md`; all seven checks must pass, including check 6 which fails today and check 7 which requires an empty diff for `ccd-gitlab-mr`
- [x] T055 Run `sh scripts/lint.sh` and fix every finding until it exits zero

---

## Dependencies

```text
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKS every user story
    ↓
    ├─→ Phase 3 (US1, P1) ─┐
    ├─→ Phase 4 (US2, P1) ─┤
    ├─→ Phase 5 (US3, P2) ─┼─→ Phase 8 (Polish)
    ├─→ Phase 7 (US5, P3) ─┘
    └─→ Phase 6 (US4, P2) — additionally depends on Phase 3
```

**Story dependencies**: US1, US2, US3 and US5 are mutually independent. **US4 depends on US1**, because the teardown question is entered only once a review request exists and its switch target is learned from the review skill. US5 touches a different skill entirely and can be done at any point after Phase 1.

**Within Phase 2**: T004–T007 are the prohibition rewrites and may proceed together; T008 is the state contract; T009 is a script change; T010–T011 are Step 0 probes that depend on T008 for where to record their results.

**Sequential within a file**: tasks touching the same file are not marked `[P]` even where they are logically independent, because `SKILL.md` and each reference file are single files and concurrent edits collide.

## Parallel execution examples

**Phase 2**: T009 (script) runs alongside T004–T007 (SKILL.md prose) — different files.

**Across stories after Phase 2**: US1's T012–T014 (`reference/ship.md`), US2's T020–T022 (`reference/workspace.md`) and US5's T040–T042 (`ccd-github-pr/SKILL.md`) touch three disjoint files and can proceed in parallel.

**Phase 8**: T046, T047, T048, T050, T051 are all `[P]` — five different files. T049 and T052 are sequential against their own files, and T054–T055 must come last.

## Implementation strategy

**MVP** is Phase 1 + Phase 2 + Phase 3 (US1). That alone closes the gap the feature exists for: the run stops naming a commit obligation it cannot discharge, and reaches a review request. Everything after is real but additive.

**Incremental delivery**: US2 next, since it is the other P1 and protects the maintainer's own tree during remediation. Then US3, then US4 (which needs US1), then US5. Phase 8 must not be deferred past the branch — FR-032 through FR-035 are requirements, not polish, and the contract checks in T054 gate the review request.
