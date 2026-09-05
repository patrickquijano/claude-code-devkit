---
description: 'Task list for feature 011 — narrowed approvals, guided pipeline repair, uniform question standard'
---

# Tasks: Approvals that carry a decision, guided pipeline repair, and a uniform question standard

**Input**: Design documents from `/specs/011-narrow-gates-pipeline-fix/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md` — all present

**Tests**: The specification does not request TDD. The only test tasks below are the `selftest.sh` fixtures that `contracts/compaction-audit-cli.md` makes mandatory for the new script, and they are implementation obligations rather than a TDD phase.

**Organization**: Grouped by user story, in the spec's priority order, so each is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: `[US1]`–`[US4]`, mapping to the four user stories in `spec.md`
- Exact file paths in every description

## Path Conventions

This is a Claude Code plugin, not an application. Real paths: `skills/<name>/` for distributed skills, `scripts/` for repository shell, `.claude/rules/` for path-scoped instructions, `docs/` for cited reasoning, `.claude-plugin/plugin.json` for the manifest.

## Three orderings that are load-bearing

1. **`.claude/rules/repository-docs.md` is amended before any document is compacted.** FR-026. Until T005 lands, every compaction task violates the convention this feature exists to change. This is why the amendment is Foundational and not part of User Story 4.
2. **`skills/ccd-pipeline-fix/` exists before anything that counts or names it.** The manifest, `CLAUDE.md` and the count contract all assert there are eight skills; asserting that before the eighth exists makes the repository briefly self-contradictory.
3. **A document's content edits land before it is compacted, without exception.** Compacting a file that is then edited invalidates its audit and can drop it back under the 15% floor with nobody re-checking. Three documents — `CLAUDE.md`, `.claude/rules/skill-authoring.md` and `.claude/rules/spec-kit-bug-workflow.md` — are edited in Phase 7, so **their compaction happens in Phase 7 too**, after those edits. This is why Phase 6 does not contain every compaction task.

---

## Phase 1: Setup

**Purpose**: Nothing is scaffolded or installed. These are the reads that make the rest correct.

- [x] T001 Read `specs/011-narrow-gates-pipeline-fix/contracts/gate-decision.md`, `contracts/pipeline-fix-interface.md`, `contracts/skill-names.md` and `contracts/compaction-audit-cli.md` in full before editing anything under `skills/`
- [x] T002 [P] Record the pre-compaction baseline commit by running `git rev-parse HEAD` and noting it in this file's Notes section
- [x] T003 [P] Confirm the working tree is clean apart from `specs/011-narrow-gates-pipeline-fix/` and the run's own bookkeeping, so the audit baseline is uncontaminated

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The convention amendment, the audit tool, and the question contract. Every later phase depends on at least one of these.

**⚠️ CRITICAL**: No user story work begins until T005 and T011 are complete.

- [x] T004 Read `.claude/rules/repository-docs.md` in full and identify the exact lines that forbid a deliberate revision pass (currently the "no prescribed section order" and "Grows by the entry, not by the pass" bullets)
- [x] T005 Amend `.claude/rules/repository-docs.md` to add the compaction carve-out: a deliberate, reviewed revision pass is permitted; incidental reformatting during unrelated work stays forbidden; a compaction pass MUST be audited per `scripts/compaction-audit.sh` and MUST NOT drop normative content (FR-025)
- [x] T006 Add to `.claude/rules/repository-docs.md` the R1 definition of normative content and the R2 15% floor with its exemption path, referencing `specs/011-narrow-gates-pipeline-fix/research.md` for the reasoning (FR-028, FR-031)
- [x] T007 Write `scripts/compaction-audit.sh` per `contracts/compaction-audit-cli.md`: POSIX `sh`, `#!/bin/sh` then `set -eu`, tab-indented, two positional arguments, tab-separated `key<TAB>value` output, the four verdicts and their exit codes
- [x] T008 Implement the prose-stream reduction in `scripts/compaction-audit.sh` — strip YAML frontmatter, extract then remove fenced code blocks, drop blank lines — identically for the baseline and working-tree versions
- [x] T009 Implement R1 normative extraction and byte-for-byte code-block comparison in `scripts/compaction-audit.sh`, comparing by normalized line content so re-indentation and reordering are not reported as loss
- [x] T010 Add five `compaction-audit.sh` fixtures to `scripts/selftest.sh` per the contract: removed `MUST` line → `fail-lost`; blank-lines-only removal → `fail-short`; 20% non-normative removal → `pass`; altered code block → `fail-lost`; missing path → `unreadable`
- [x] T011 Add the `AskUserQuestion` contract to `.claude/rules/skill-authoring.md` as its single normative home: every ask goes through the tool; options with per-option effect and cost; exactly one `(Recommended)`; the reason stated; and the FR-023 escape requiring an explicit statement when no recommendation is defensible (FR-020–FR-024)
- [x] T012 [P] Add the reasoning behind T011 to `docs/skill-authoring-practices.md` with its source citations, per `.claude/rules/repository-docs.md`'s requirement that every claim of fact names its source

**Checkpoint**: `sh scripts/lint.sh` passes; `sh scripts/selftest.sh` passes including the five new fixtures. Compaction is now permitted and auditable, and the question standard has a home.

---

## Phase 3: User Story 1 — Approvals only where a decision is still open (Priority: P1) 🎯 MVP

**Goal**: `ccd-speckit-run` asks only where the approval carries an open decision, and says so when it does not.

**Independent Test**: run the pipeline on a small task without revising anything; count approvals against `contracts/gate-decision.md`'s always-gate set, and confirm every unasked boundary printed its reason.

- [x] T013 [US1] Rewrite the Step 4 "per-phase proposal" section of `skills/ccd-speckit-run/SKILL.md` to state the narrowed rule briefly and point at the gate-decision contract rather than restating it (FR-001–FR-003, R4)
- [x] T014 [US1] Add the FR-004 announcement line format to `skills/ccd-speckit-run/SKILL.md` — one line naming the boundary and the reason, printed before the phase runs, never suppressed
- [x] T015 [US1] Add the always-gate set to `skills/ccd-speckit-run/SKILL.md` as a short table — Steps 1, 2b, 6 and Phases 2, 5, 8 — noting that no comparison, mode or skip phrase reaches it (FR-002, FR-005)
- [x] T016 [US1] Add the `gate_mode` question to Step 3 of `skills/ccd-speckit-run/SKILL.md`, offered with the plan, defaulting to `narrowed` (FR-007, R5)
- [x] T017 [US1] Add `gate_mode` to the state shape in `skills/ccd-speckit-run/reference/run-state.md`, with the closed-set rule, the `narrowed` default for a resumed pre-011 run, and the instruction to read it rather than remember it
- [x] T018 [US1] Update the Step 4 skip handling in `skills/ccd-speckit-run/SKILL.md` so a skip whose reason was not in the Step 3 plan gates, while a planned skip is announced (FR-008)
- [x] T019 [US1] Update the "Proposal discipline" section of `skills/ccd-speckit-run/SKILL.md` so it names the always-gate set as its scope instead of "each of Phases 1–8"
- [x] T020 [US1] Rewrite the "On the objection this design used to make" passage in `skills/ccd-speckit-run/SKILL.md` — the click-through objection is now answered by narrowing, not only by the delta row; keep the recorded history rather than deleting it
- [x] T021 [US1] Update the Authoring note in `skills/ccd-speckit-run/SKILL.md` to record the R9 re-examination: the gates are narrowed, not removed, so `disable-model-invocation` stays off; the pairing is satisfied, not discharged (FR-034)
- [x] T022 [US1] Update the red-flags table in `skills/ccd-speckit-run/SKILL.md` — replace "The plan was approved at Step 3, so the phases can run" with entries for the two new failure modes: suppressing the FR-004 line, and treating an always-gate boundary as auto-proceedable
- [x] T023 [US1] Update `skills/ccd-speckit-run/reference/evaluations.md` with scenarios for the narrowed gate: the six-approval run, the revised-argument run, the `every-phase` override run, and the defect case of a boundary that neither asked nor printed
- [x] T024 [US1] Update the progress checklist in `skills/ccd-speckit-run/SKILL.md` so it reflects gated versus announced boundaries rather than "each of Phases 1–8 proposed and approved"
- [x] T025 [US1] Re-read `skills/ccd-speckit-run/reference/prompt-rules.md`'s leakage check and Step 3 of `SKILL.md`, and confirm the cross-phase leakage check still runs over all eight drafted arguments after T013–T024 (FR-006). Feature 006 kept this check alive specifically so that narrowing could not remove it; **this is the task that proves narrowing did not**

**Checkpoint**: User Story 1 is complete and independently testable via `quickstart.md` scenarios 1–3.

---

## Phase 4: User Story 2 — From a failed pipeline to a verified fix (Priority: P2)

**Goal**: a maintainer starting from a failed CI pipeline reaches a validated fix through the existing bug workflow.

**Independent Test**: `quickstart.md` scenarios 4–6, run against a repository that has a failed pipeline. **Not runnable against this repository**, which has no CI.

- [x] T026 [P] [US2] Create `skills/ccd-pipeline-fix/` with `SKILL.md` frontmatter carrying `name: ccd-pipeline-fix` matching the directory, a `description` whose first sentence is the triggering use case, and neither `disable-model-invocation` nor `user-invocable`
- [x] T027 [US2] Write the three standing rules into `skills/ccd-pipeline-fix/SKILL.md`: it runs no stage, it edits no source, and nothing changes before the root cause is approved and an approach chosen
- [x] T028 [US2] Write Step 0 preflight into `skills/ccd-pipeline-fix/SKILL.md`: forge from the shared `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh`, CLI probe, `ccd-speckit-bug-run` probe from the session listing, and the rule to read the `verdict` line rather than the exit status
- [x] T029 [US2] Write the `retrieval_path` announcement into `skills/ccd-pipeline-fix/SKILL.md` — decided at preflight, stated before Step 1, never discovered partway (FR-011c)
- [x] T030 [US2] Write the stop-on-missing-dispatch-target rule into `skills/ccd-pipeline-fix/SKILL.md`, distinguishing it from a missing CLI, which falls back rather than stopping
- [x] T031 [P] [US2] Create `skills/ccd-pipeline-fix/reference/evidence.md` with the GitHub section — `gh run list --status failure`, `gh run view <id>`, `gh run view <id> --log-failed` — in GitHub's own vocabulary
- [x] T032 [US2] Add the GitLab section to `skills/ccd-pipeline-fix/reference/evidence.md` — `glab ci list --status failed`, `glab ci get`, `glab ci trace` — in GitLab's own vocabulary, as a separate section, never one instruction covering both forges
- [x] T033 [US2] Add the ambiguity rule to `skills/ccd-pipeline-fix/reference/evidence.md`: more than one failed run or failing job means ask, never choose; several jobs may be selected together (FR-017)
- [x] T034 [US2] Add the fallback and degenerate-evidence rules to `skills/ccd-pipeline-fix/reference/evidence.md`: name which of the four cases occurred, ask for pasted output, continue; empty, truncated or retention-expired logs take the same path (FR-011b)
- [x] T035 [US2] Write `skills/ccd-pipeline-fix/scripts/pipeline-evidence.sh` — POSIX `sh`, `set -eu`, tabs — printing forge, CLI status, candidate failed runs and jobs, and a `verdict` line; invoked as `sh "${CLAUDE_SKILL_DIR}/scripts/pipeline-evidence.sh"`
- [x] T036 [US2] Write the root-cause step into `skills/ccd-pipeline-fix/SKILL.md`: proposed with its supporting evidence, approved before anything changes (FR-012)
- [x] T037 [US2] Write the two terminal exits into `skills/ccd-pipeline-fix/SKILL.md` — cause outside the repository (FR-018) and fix that would alter a requirement (FR-019), the latter naming `/ccd-speckit-run` and Constitution Principle VI
- [x] T038 [US2] Write the approach step into `skills/ccd-pipeline-fix/SKILL.md`: at least two alternatives, effect and cost each, exactly one recommended with its reason (FR-013, and T011's standard)
- [x] T039 [P] [US2] Create `skills/ccd-pipeline-fix/reference/dispatch.md` covering the composed report, the verbatim display, `Skill(skill: "claude-code-devkit:ccd-speckit-bug-run")`, and that writing the name in prose invokes nothing
- [x] T040 [US2] Add to `skills/ccd-pipeline-fix/reference/dispatch.md` what must never happen: dispatching the three `speckit-bug-*` stages directly, pre-fetching a URL in the report, restating assessment content in a stage argument, or editing source (FR-014, R6)
- [x] T041 [US2] Write the outcome vocabulary into `skills/ccd-pipeline-fix/SKILL.md` — `dispatched`, `stopped: outside-repository`, `stopped: feature-work`, `stopped: no-failed-run`, `stopped: no-dispatch-target`, `stopped: declined` — as a closed set
- [x] T042 [US2] Write `skills/ccd-pipeline-fix/evaluations.md` stating what a correct run looks like and which regressions to re-check after editing the skill (required of every skill by `.claude/rules/skill-authoring.md`)
- [x] T043 [US2] Verify `skills/ccd-pipeline-fix/SKILL.md` is under 500 lines and its `description` under 1,536 characters, and that everything a late step needs is in a file it writes rather than in prose past the 5,000-token compaction budget
- [x] T044 [US2] Record in `skills/ccd-pipeline-fix/reference/dispatch.md` that FR-015 (the three defect records on disk) and FR-016 (the uncapped loop-back offer on a `partial` or `failed` result) are **discharged by the dispatch**, not implemented here — `ccd-speckit-bug-run` owns both, per `research.md` R6. **Reimplementing either in this skill would breach FR-014**

**Checkpoint**: the eighth skill exists. The manifest, `CLAUDE.md` and count-contract tasks in Phase 7 may now run.

---

## Phase 5: User Story 3 — Every question asked the same way (Priority: P3)

**Goal**: every ask in every skill carries choices, explanations, one recommendation and its reason.

**Independent Test**: `quickstart.md` scenario 7 — no ask site without the tool, and zero surviving local restatements of the rule.

**Note**: T011 already placed the rule. This phase converts the sites and removes the duplicates.

- [x] T045 [P] [US3] Convert the three untooled ask sites in `skills/ccd-conflict-resolve/SKILL.md` (remote unreachable, unchanged conflict set, staged paths outside the resolution) to `AskUserQuestion` with options, effect and cost, one recommendation and its reason
- [x] T046 [P] [US3] Convert the untooled ask sites in `skills/ccd-speckit-bug-run/SKILL.md` — empty report, `slug-taken`, existing run state, assessment absent, `partial`, `failed`, and the three loop-back choices
- [x] T047 [P] [US3] Convert the untooled ask sites in `skills/ccd-speckit-run/SKILL.md` (failed phase retry/revise/stop) and in `reference/verify.md` (three consecutive failures) and `reference/preflight.md` (state-file absent but spec directory exists)
- [x] T048 [P] [US3] Convert the untooled ask sites in `skills/ccd-branch-push/SKILL.md` (base named but absent, switch conflicts with base) and `skills/ccd-commit-push/SKILL.md`
- [x] T049 [P] [US3] Convert the untooled ask sites in `skills/ccd-github-pr/SKILL.md` (script failure naming assignees, multiple closed PRs, re-ask on moved remote state) to the tooled form
- [x] T050 [P] [US3] Convert the untooled ask sites in `skills/ccd-gitlab-mr/SKILL.md` (script failure naming assignees, multiple closed MRs, re-ask on moved remote state) to the tooled form
- [x] T051 [US3] Add the missing recommendation and justification to the tooled asks that lack them: `ccd-branch-push` remote choice, `ccd-github-pr` "Which PR", `ccd-gitlab-mr` "Which MR" — or state explicitly that no recommendation is defensible, per FR-023
- [x] T052 [US3] Add a recommendation and reason, or the FR-023 statement, to the `Proceed`/`Revise`/`Stop` gates in `skills/ccd-speckit-run/SKILL.md` and `skills/ccd-speckit-bug-run/SKILL.md`, and to the four-option gates in `reference/verify.md`, `reference/ship.md` and `reference/findings.md`
- [x] T053 [US3] Remove the sentence "Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled 'confirm?'." from `skills/ccd-branch-push/SKILL.md`, `skills/ccd-commit-push/SKILL.md`, `skills/ccd-github-pr/SKILL.md` and `skills/ccd-gitlab-mr/SKILL.md` — the rule is now repository-wide and a second copy is drift (FR-024, R8)
- [x] T054 [US3] Verify no `.claude/rules/` file other than `skill-authoring.md` states the question standard, and that `skill-authoring.md` states it exactly once (SC-009)
- [x] T055 [P] [US3] Update each affected skill's `evaluations.md` with the converted-ask regression check
- [x] T056 [US3] Run `grep -rn "ask" skills/ --include='*.md' | grep -v AskUserQuestion` and confirm no remaining site instructs an ask without the tool (SC-008)

**Checkpoint**: User Story 3 complete and independently verifiable.

---

## Phase 6: User Story 4 — Instructions and output that cost less to read (Priority: P4)

**Goal**: the instruction documents are shorter and provably lost nothing.

**Independent Test**: `quickstart.md` scenario 8 — every compacted document audits `pass`, or is recorded exempt with its reason and actual percentage.

**⚠️ T005 and T007 must be complete.** Compacting before the amendment breaks FR-026; compacting before the audit exists means no task below can be verified.

**Three documents are deliberately absent from this phase** — `CLAUDE.md`, `.claude/rules/skill-authoring.md` and `.claude/rules/spec-kit-bug-workflow.md`. Phase 7 edits all three, so compacting them here would audit a version that is about to change. They are compacted in Phase 7, after their edits.

Every task below follows the same shape: compact, then run `sh scripts/compaction-audit.sh <baseline> <path>`, then record `pass` or the exemption. **A `fail-lost` verdict is fixed, never waived.**

- [x] T057 [P] [US4] Compact `skills/ccd-speckit-run/reference/evaluations.md` (379 lines) and audit
- [~] T058 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/ship.md` (246 lines) and audit
- [~] T059 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/worktree.md` (186 lines) and audit
- [~] T060 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/claude-md.md` (186 lines) and audit
- [~] T061 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/run-state.md` (155 lines) and audit — after T017's `gate_mode` addition
- [~] T062 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/prompt-rules.md` (142 lines) and audit
- [~] T063 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/subagents.md` (127 lines) and audit
- [~] T064 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/preflight.md` (105 lines) and audit
- [~] T065 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/reference/base-branch.md`, `findings.md`, `conflicts.md`, `verify.md`, `tooling.md` and `constitution.md` and audit each; expect exemptions on `tooling.md` and `constitution.md`
- [~] T066 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-bug-run/reference/workspace.md`, `run-state.md`, `ship.md` and `stages.md` and audit each
- [~] T067 [US4] **WON'T DO** — Compact `skills/ccd-speckit-run/SKILL.md` (297 lines) and audit — after all of Phase 3
- [~] T068 [P] [US4] **WON'T DO** — Compact `skills/ccd-github-pr/SKILL.md` (384 lines) and audit — after T049 and T053
- [~] T069 [P] [US4] **WON'T DO** — Compact `skills/ccd-speckit-bug-run/SKILL.md` (351 lines) and audit — after T046
- [~] T070 [P] [US4] **WON'T DO** — Compact `skills/ccd-gitlab-mr/SKILL.md` (333 lines) and audit — after T050 and T053
- [~] T071 [P] [US4] **WON'T DO** — Compact `skills/ccd-conflict-resolve/SKILL.md` (196 lines) and audit — after T045
- [~] T072 [P] [US4] **WON'T DO** — Compact `skills/ccd-branch-push/SKILL.md` (149 lines) and `skills/ccd-commit-push/SKILL.md` (133 lines) and audit each — after T048 and T053
- [~] T073 [P] [US4] **WON'T DO** — Compact the seven `evaluations.md` files at the skill roots and audit each — after T055 and T042
- [~] T074 [P] [US4] **WON'T DO** — Compact `.claude/rules/husky-git-hooks.md`, `.claude/rules/forge-review-requests.md` and `.claude/rules/shell-scripts.md` and audit each — the three rule files Phase 7 does not edit

**Checkpoint**: all four user stories complete. Three documents remain to be compacted, in Phase 7, after their content edits.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: the records that name the eighth skill, the three deferred compactions, and the final gate. **All of these depend on Phase 4.**

### Content edits

- [x] T075 Bump `version` in `.claude-plugin/plugin.json` from `0.4.0` to `0.5.0` and change its `description` from "seven skills" to "eight skills" (FR-035, R10)
- [x] T076 Update `CLAUDE.md`: "seven skills" → eight in the repository summary and the distributed-skills section; add `ccd-pipeline-fix` to the skill inventory; update the `disable-model-invocation` bullet to record that the gates are narrowed rather than removed; add feature 011 to the supersession history (FR-036)
- [x] T077 [P] Add the feature-011 supersession record to `specs/011-narrow-gates-pipeline-fix/spec.md`'s own history, noting that 006's FR-010, FR-011 and FR-013 are superseded and FR-012 survives (FR-032, FR-033)
- [x] T078 [P] Update `.claude/rules/skill-authoring.md`'s shared-script list and dispatch count to include `ccd-pipeline-fix` as a consumer of `forge-detect.sh` and a caller of `ccd-speckit-bug-run`
- [x] T079 [P] Update `.claude/rules/spec-kit-bug-workflow.md` to record that `ccd-speckit-bug-run` now has a second caller, and that a pipeline defect arrives as an ordinary bug report
- [x] T080 [P] Add `ccd-pipeline-fix` to `docs/spec-kit-extensions.md` where it records what drives the bug extension, with its source citations

### The three deferred compactions

**Each runs only after the task that edits its file.** This is ordering constraint 3.

- [~] T081 [US4] **WON'T DO** — Compact `CLAUDE.md` and audit — **after T076**, keeping it under 200 lines
- [~] T082 [US4] **WON'T DO** — Compact `.claude/rules/skill-authoring.md` and `.claude/rules/repository-docs.md` and audit each — **after T078**, and after T005, T006 and T011 which both files gained content from
- [~] T083 [US4] **WON'T DO** — Compact `.claude/rules/spec-kit-bug-workflow.md` and audit — **after T079**
- [x] T084 [US4] Record every compaction exemption in this file's Notes section with its path, actual percentage and reason (FR-030), and confirm no artifact outside `specs/011-narrow-gates-pipeline-fix/` was touched (FR-027a, SC-010a)

### The gate

- [x] T085 Run `sh scripts/lint.sh` and fix every finding until it passes — seven checks, `citations editorconfig format markdown yaml shell python`, stopping at the first failure
- [x] T086 Run `sh scripts/selftest.sh` and confirm all fixtures pass, including the five added by T010
- [x] T087 Walk `specs/011-narrow-gates-pipeline-fix/quickstart.md` scenarios 1, 2, 3, 7, 8 and 9 against this repository and record the results
- [x] T088 Record that quickstart scenarios 4, 5 and 6 could not be run here — this repository has no CI pipeline — rather than reporting them as passed

### Quickstart results (T087, T088)

| Scenario                              | Result                                                                                                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| S1–S3 — the narrowed gate             | **Not run.** Requires invoking the pipeline on a fresh task; this run is itself that pipeline and cannot re-enter it. Deferred to first use.                                                                             |
| S4–S6 — pipeline repair               | **Cannot run here.** This repository has no CI pipeline. Recorded, never claimed.                                                                                                                                        |
| S7 — every question carries its shape | **Pass.** Zero restatements in any `SKILL.md`; the rule is stated once, in `.claude/rules/skill-authoring.md`.                                                                                                           |
| S8 — compaction lost nothing          | **Partial.** The carve-out precedes the one compaction; `tooling.md` audits `normative-lost 0` at 8% and is recorded exempt. 27 files not attempted.                                                                     |
| S9 — the count agrees                 | **Pass.** 8 skill directories, all `ccd-` prefixed, `name` matching directory, 8 `evaluations.md`; `plugin.json` at `0.5.0` saying "eight skills"; `CLAUDE.md` and `README.md` agree; zero forbidden frontmatter fields. |
| The whole gate                        | **Pass.** All seven lint checks; selftest 17 standards, 13 format-hook, 20 git-hook, 5 compaction-audit cases.                                                                                                           |

---

## Phase 9: Unit consistency (T089–T092, resumed run)

Discovered at the preflight of a resumed run, after the work above had already shipped in PR #11. Not a compaction task and not part of User Story 4.

**The defect.** The lines-to-characters change approved during Phase 8 reached `scripts/compaction-audit.sh` and its comments, but not the three documents that specify it. The rule stated the floor in lines, `research.md` R2 recorded the decision in lines, and `contracts/compaction-audit-cli.md` documented nine of the eleven keys the script emits — omitting `chars-before` and `chars-after`, the pair the verdict actually turns on, while calling its own output "machine-readable and stable".

- [x] T089 State the floor in `.claude/rules/repository-docs.md` § The length floor as at least 15% of non-code, non-frontmatter, non-blank **characters**, with the reason the unit is characters
- [x] T090 Amend `specs/011-narrow-gates-pipeline-fix/research.md` decision R2 to characters, recording the Phase 5 → Phase 8 amendment rather than deleting the original, and correcting the rationale paragraph, whose prediction that size predicts compressibility the measurements contradicted
- [x] T091 Add `chars-before` and `chars-after` to the documented output block in `specs/011-narrow-gates-pipeline-fix/contracts/compaction-audit-cli.md` in emit order, and state that `reduction-pct` is computed from characters
- [x] T092 Verify the four agree by reading them side by side, and record the check here

### T092 result

Read against `scripts/compaction-audit.sh` at `THRESHOLD=15` (line 15), `REDUCTION=$(((CHARS_BEFORE - CHARS_AFTER) * 100 / CHARS_BEFORE))` (line 249) and the emit block (lines 263–273):

| Artefact                            | Unit                           | Keys                                 | Agrees            |
| ----------------------------------- | ------------------------------ | ------------------------------------ | ----------------- |
| `scripts/compaction-audit.sh`       | characters                     | emits 11                             | — (the authority) |
| `.claude/rules/repository-docs.md`  | characters                     | names both pairs, says which decides | yes               |
| `research.md` R2                    | characters, amendment recorded | names both pairs                     | yes               |
| `contracts/compaction-audit-cli.md` | characters, stated explicitly  | documents all 11 in emit order       | yes               |

The number 15 is unchanged in all four, so nothing already audited needs re-auditing.

**What this pass deliberately did not do.** No document was compacted. FR-027, T058–T074 and T081–T083 are untouched — whether to compact the remaining 27 files is a separate decision, deferred to after this fix, and `research.md` R2 now records the open question about whether 15% is the right number given that no file in this corpus has reached it.

---

## Phase 10: Closing the requirements-quality gaps (T099–T106)

The review recorded at `checklists/quality.md` left 33 items open. This phase closes all of them. 18 needed an existing requirement amended; 12 needed a new requirement **and** the behaviour that satisfies it; 3 closed as unvalidated, moot, or a spec gap the shipped skill already handled.

- [x] T099 Amend 18 existing requirements and criteria in `spec.md` — FR-001, FR-002, FR-007, FR-009, FR-010, FR-011b, FR-013, FR-018, FR-019, FR-020, FR-023, FR-027a, FR-031, FR-032, FR-034, SC-001, SC-009, SC-010
- [x] T100 Add FR-037 in `spec.md` recording what this feature cannot verify about itself — no pipeline here, and the bug-workflow-fitness assumption unvalidated
- [x] T101 Add FR-038 – FR-049 in `spec.md`, each naming the checklist item that produced it
- [x] T102 Add SC-013, SC-014 and SC-015 in `spec.md` for the new failure paths, the per-phase record, and approvals not surviving interruption
- [x] T103 Implement FR-039, FR-040, FR-042, FR-046, FR-047 and FR-049 in `skills/ccd-pipeline-fix/SKILL.md` — including a new Step 5, which implements FR-016's loop-back the skill never had
- [x] T104 Implement FR-038, FR-044 and FR-048 in `skills/ccd-speckit-run/SKILL.md`, and add the `gates` field to `skills/ccd-speckit-run/reference/run-state.md`
- [x] T105 Implement FR-043 and FR-045 in `.claude/rules/repository-docs.md`
- [x] T106 Mark all 45 checklist items satisfied, keeping each item's `**Open**:` line alongside its `**Closed**:` line

### What changed in behaviour, not only in prose

Eleven of the twelve new requirements demanded something the skills did not do. The largest is **FR-039 with FR-016**: `ccd-pipeline-fix` dispatched to the bug workflow and stopped, so FR-016's required return to diagnosis existed in the specification and nowhere else. Step 5 now reads what came back and branches three ways — the workflow stopped (report it, never call it a verified fix, never run its remaining stages here), validation failed (offer a return, uncapped, never taken unprompted), or it verified.

The second is **FR-048**: an approval given before an interruption was implicitly still held when a run resumed. The `gates` field's `approved` flag is written when the approved step _completes_, not when the approval is given, so an interrupted boundary reads as unapproved and is proposed again.

**One item was a specification gap rather than a behaviour gap.** CHK031 — evidence retrieved but empty, truncated or expired — was already handled at Step 1; FR-041 makes the requirement match what ships rather than adding anything.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1 (Setup)**: no dependencies
- **Phase 2 (Foundational)**: blocks everything. T005 blocks every compaction task; T011 blocks all of Phase 5
- **Phase 3 (US1)**: after Phase 2. Independent of US2, US3, US4
- **Phase 4 (US2)**: after Phase 2. Independent of US1, US3. **Blocks all of Phase 7**
- **Phase 5 (US3)**: after T011. Touches the same files as Phase 6, so its edits land first
- **Phase 6 (US4)**: after T005, T007, and after Phase 3 and Phase 5 have finished editing the files being compacted
- **Phase 7**: content edits T075–T080 after Phase 4; compactions T081–T083 each after their own content edit; T084 after all compaction; T085–T088 last

### User story dependencies

- **US1 (P1)**: no dependencies on other stories — the MVP
- **US2 (P2)**: no dependencies on other stories
- **US3 (P3)**: no dependencies on other stories; T011 is Foundational precisely so this stays true
- **US4 (P4)**: independently testable, not independently schedulable. Its content depends on US1 and US3 having finished their edits, and three of its tasks (T081–T083) sit in Phase 7 because Phase 7 edits their files. `spec.md` §US4 records this caveat.

### Parallel opportunities

- T002, T003 together
- T012 alongside T007–T010
- T026, T031, T039 together at the start of Phase 4
- T045–T050 all together — six different files, no overlap
- T057–T066 all together — different files
- T068–T074 together, each after its story's edits
- T077–T080 together
- **T081, T082, T083 are not parallel with T076, T078, T079** — each is that task's successor

---

## Parallel Example: User Story 3

```bash
# Six ask-site conversions, one per file, no overlap:
Task: "Convert untooled asks in skills/ccd-conflict-resolve/SKILL.md"
Task: "Convert untooled asks in skills/ccd-speckit-bug-run/SKILL.md"
Task: "Convert untooled asks in skills/ccd-speckit-run/SKILL.md and its reference files"
Task: "Convert untooled asks in skills/ccd-branch-push/SKILL.md and skills/ccd-commit-push/SKILL.md"
Task: "Convert untooled asks in skills/ccd-github-pr/SKILL.md"
Task: "Convert untooled asks in skills/ccd-gitlab-mr/SKILL.md"
```

---

## Implementation Strategy

### MVP (User Story 1 only)

1. Phase 1, then Phase 2 tasks T004–T006 and T011
2. Phase 3 entire, T025 included
3. **STOP and VALIDATE** with quickstart scenarios 1–3
4. The narrowed gate is shippable on its own; nothing else in this feature depends on it

### Incremental delivery

1. Foundational → compaction permitted and auditable, question standard homed
2. US1 → narrowed gate → validate → shippable
3. US2 → the eighth skill → validate elsewhere → then Phase 7's records
4. US3 → converted asks → validate
5. US4 → compaction → audit every file
6. T085–T088 → the gate and the quickstart walk

### Ordering hazards worth naming

- Compacting a file **before** US1 or US3 rewrites it wastes the work and invalidates the audit baseline. Phase 6 is last among the user stories for this reason, not by preference.
- Compacting `CLAUDE.md`, `skill-authoring.md` or `spec-kit-bug-workflow.md` **before** Phase 7 edits them is the same error with a longer fuse — the audit passes, then the content grows, and nothing re-checks the floor. T081–T083 exist to prevent it.
- Updating the count records **before** T026 creates a repository that claims eight skills and ships seven.
- Running `compaction-audit.sh` against `HEAD` instead of the recorded baseline from T002 will report every Phase 3 and Phase 5 edit as compaction loss.

---

## Notes

- `[P]` = different files, no dependencies
- Baseline commit for all audits (filled by T002): `a96e95feffb113c98e3c7c0b9d90e5a188ea624a` (`a96e95f`)
- Working tree at T003: clean apart from `specs/011-narrow-gates-pipeline-fix/` — confirmed
- Compaction exemptions and outcomes (filled by T084):
  - **Audit baseline re-set.** Phase 6 audits against `9383a6a`, a `git stash create` snapshot of the tree after Phase 5, not against `a96e95f`. Against the original baseline every file this feature deliberately reworded reported `fail-lost` — 40 lines across 8 files, all of them rules Phases 3 and 5 rewrote rather than dropped. `contracts/compaction-audit-cli.md` describes the audit as comparing "two versions of one file during one deliberate pass", and the re-baseline is what makes that true here. `git stash create` writes a commit object without touching the branch, the stash stack or the remote, so Step 6a still owns every real commit.
  - `skills/ccd-speckit-run/reference/tooling.md` — **compacted, 8%, exempt from the 15% floor.** `normative-lost 0`; 4,233 → 3,864 prose characters. Reaching 15% would have meant cutting the delegation rationale or the "nothing named here is a dependency" paragraph, both of which R1 protects and both of which exist to stop a future contributor treating the tools as required. FR-030 covers this: the document is left as compacted and the reason recorded.
  - **Every other file listed in Phase 6 and in T081–T083 is NOT compacted.** They are not exempt — they were not attempted. See the scope limit below.

## Scope limit — FR-027 withdrawn

**User Story 4 is closed, not outstanding.** T058–T074 and T081–T083 are marked `[~]` won't-do above, and FR-027 is withdrawn in `spec.md`. This section previously described the work as deferred; that was accurate when it was written and is not accurate now, so it is rewritten rather than appended to.

### What was delivered

- The carve-out in `.claude/rules/repository-docs.md` (T005, T006) permitting a deliberate reviewed compaction pass while drive-by reformatting stays forbidden.
- `scripts/compaction-audit.sh` (T007–T009) and its five `selftest.sh` fixtures (T010) — `removed-must`, `blank-only`, `prose-trimmed`, `altered-code`, `missing-path`.
- R1's mechanical definition of normative content, R2's floor, R3's comparison procedure. CHK004, CHK005, CHK011, CHK012 and CHK013 all found the original wording uncheckable; all three are now checkable by a command.
- One document compacted and audited end to end: `skills/ccd-speckit-run/reference/tooling.md`, 8%, `normative-lost 0`, recorded exempt under FR-030.
- The unit correction (T089–T092), after the lines-to-characters switch was found to have reached the script but not the three documents specifying it.

Three real defects surfaced during the script's development, each caught by a fixture and each recorded in a comment beside its fix: a BSD `sed` bracket-expression bug where `[ \t]` matched a literal `t` and deleted every `t` from the compared text; a line-granularity loss check that reported every reworded rule as deleted, 40 false positives across 8 files; and an `awk` `NR == FNR` bug that mistook the first baseline record for a survivor whenever the after-set was empty, letting a real deletion report clean.

### Why the remaining 27 files were not compacted

Measured, not estimated. Two documents were compacted by hand and audited: `tooling.md` at **8%** and `skills/ccd-speckit-run/reference/verify.md` at **6%**, neither reaching the 15% floor, neither dropping anything normative. `/caveman-compress` was then tried at the maintainer's direction and reached 10% — better than either — but returned `fail-lost` and rewrote a distributed skill's prose into a register that made normative sentences ambiguous, so it was reverted.

The maintainer's decision, taken on that evidence: **the floor stays at 15% and FR-027 is withdrawn.** A threshold nothing in a corpus reaches is evidence about the corpus, not about the threshold — these documents are dense because this repository's own rules forbid padding and require a rationale beside anything surprising. Reasoning in `research.md` R2; withdrawal recorded in `spec.md` under "Withdrawn within this feature".

**FR-028 through FR-031 are not withdrawn.** They govern any compaction that does happen, and the whole mechanism is in place for the next genuinely padded document. Nothing here needs rebuilding to use it: `sh scripts/compaction-audit.sh <baseline-ref> <path>`.
