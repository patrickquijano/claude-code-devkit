# Feature Specification: Claude Code guidance and pipeline gating

**Feature Branch**: `006-claude-code-guidance`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Research and extract information, rules, guidelines and instructions about making Claude Code effective and efficient, effective and efficient `CLAUDE.md`, `CLAUDE.md` recommended structure, effective and efficient Claude Code skills, and Claude Code recommended structure. Create or update documentation in `docs/` from that research. Create or update the project rules, guidelines and instructions from it. `CLAUDE.md` MUST be thin, MUST be less than 200 lines, MUST implement a lazy loading approach for the rules, and MUST use the recommended structure. Update the `skills/ccd-speckit-run` skill: check, analyze and understand it first; it MUST use multiple agents/subagents (limit 10) to execute the tasks, MUST be model invokable and user invokable, MUST invoke `/ccd-conflict-resolve` after every step or phase, MUST NOT ask or prompt in one go but propose and ask for approval per phase naming the skill to be invoked and the prompt or argument, and once it is done merging the PR/MR MUST ask the user how to leave the workspace — for a branch, switch to the target branch and delete the source branch, switch to the target branch and keep it, or stay on the source branch; for a worktree, exit and delete the worktree and the branch, exit and delete the worktree, exit, or stay — and may propose other options."

## Clarifications

### Session 2026-09-05

- Q: Is `CLAUDE.md` already in "the recommended structure" because it contains what belongs in such a file, or is a specific section order intended? (FR-007) → A: Already satisfied — no authoritative source defines a section order for an instruction file, only what belongs in one, and the file already holds all of it. FR-007 is a proof obligation, not a restructuring task.
- Q: Does the limit of ten parallel readers cap how many run at the same time, or how many the whole run may use in total? (FR-018) → A: Ten at the same time. The limit governs a single batch; a run may have several batches, each bounded independently.

### Session 2026-09-05, cross-artifact analysis

- Q: `research.md` records SC-005 as replaced because "at the same rate as before" cannot be measured, but the spec still carried the original wording. Which is right? → A: The plan. SC-005 is replaced with a criterion observable in a single run, needing no baseline.
- Q: FR-009 gates "every decision that changes the repository outside the pipeline's own working artifacts" without naming them, and FR-009 is what justifies FR-008. → A: Enumerate them exhaustively in FR-009, and treat an unlisted decision as evidence the list is wrong rather than as licence to judge case by case.
- Q: Must a phase proposal say so when nothing changed since the plan? → A: Yes, explicitly. Recorded in FR-013.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Approving each pipeline phase as it happens (Priority: P1)

A maintainer starts the repository's spec-driven pipeline from a task description. Instead of being shown eight prompts at the beginning and then watching every phase run to completion untouched, they are asked before each phase: here is the command about to be invoked, here is the exact argument it will receive, here is what it will write, and here is what changed since the plan. They approve, revise, or stop, one phase at a time. Separately, the pipeline no longer has to be named to start — the model may reach for it when a task calls for it, because the approval that used to live in the skill's reachability now lives in the per-phase gates.

**Why this priority**: This is the behaviour the maintainer asked for first and the one that changes every future run. It also carries the safety argument that makes model reachability acceptable, so the two must ship together or not at all.

**Independent Test**: Start a run and confirm that each phase is preceded by a proposal naming the command and its exact argument, that answering "revise" amends only that phase's argument and re-proposes, and that the pipeline appears in the model's own list of reachable workflows rather than only in the user-invocable menu.

**Acceptance Scenarios**:

1. **Given** a run has passed its planning step, **When** the next phase is about to be invoked, **Then** a proposal is presented naming the command, the verbatim argument, the artifacts the phase will write, and any change since the plan, and nothing is invoked until it is approved.
2. **Given** a phase proposal has been presented, **When** the maintainer answers "revise" with a note, **Then** only that phase's argument is amended, the proposal is presented again, and no other phase's argument changes.
3. **Given** a task that the pipeline covers, **When** no one names the pipeline explicitly, **Then** the pipeline is available to be reached on the model's own judgement.
4. **Given** all eight arguments are drafted together at the planning step, **When** one of them names something that belongs in a later phase, **Then** that leakage is detected before any phase runs.

---

### User Story 2 - Finding the practice while editing the file it governs (Priority: P2)

A contributor opens one of the repository's own documentation or instruction files to edit it. The practices governing how such a file is written — how long it may be, what belongs in an always-loaded file as opposed to a scoped rule or a workflow, and the requirement to cite a source or record the absence of one — reach them at that moment, rather than sitting in a document they would have to know to open. Separately, a contributor who wants to know how a Claude Code project is laid out finds that recorded as its own subject rather than inferring it from scattered mentions.

**Why this priority**: The practices already exist and are already correct; what is missing is that they arrive too late to act on, and that one subject is absent. Valuable, but nothing is broken today.

**Independent Test**: Open one of the repository's documentation files and confirm the authoring practices are in scope for that edit; then confirm the documentation set answers "how is a Claude Code project laid out" from a document devoted to that question, with each claim carrying a source or a recorded gap.

**Acceptance Scenarios**:

1. **Given** a contributor is editing one of the repository's own documentation or instruction files, **When** they begin that edit, **Then** the practices governing how such a file is authored are in scope for it.
2. **Given** a contributor asks how a Claude Code project is laid out, **When** they consult the documentation set, **Then** a document covers it as its own subject, naming a source for each claim or recording that no authoritative source settles it.
3. **Given** an existing recorded practice that the authoritative source no longer supports, **When** the documentation is reviewed as part of this work, **Then** the correction is recorded rather than the original claim being silently replaced.

---

### User Story 3 - Not walking past a conflicted working tree (Priority: P2)

Something during a run leaves the working tree with unmerged paths or an interrupted integration. Rather than the run continuing on top of it, the pipeline notices at the next boundary between steps or phases and hands the maintainer to the repository's conflict-resolution workflow. When the tree is clean — which is the ordinary case — it says so rather than saying nothing, so a maintainer can tell a check that passed from a check that never ran.

**Why this priority**: Protects every later phase from building on a broken tree, and costs nothing when there is nothing wrong. Lower than P1 only because the condition is rare.

**Independent Test**: Leave the tree with unmerged paths, reach a step or phase boundary, and confirm the conflict-resolution workflow is reached; then repeat with a clean tree and confirm a clean verdict is reported explicitly and nothing is dispatched.

**Acceptance Scenarios**:

1. **Given** the working tree has unmerged paths or an interrupted integration, **When** a step or phase completes, **Then** the maintainer is handed to the repository's conflict-resolution workflow before the run continues.
2. **Given** the working tree is clean, **When** a step or phase completes, **Then** the clean result is reported and no conflict-resolution workflow is reached.
3. **Given** a run that has been summarized and resumed, **When** it reports what happened, **Then** the outcome of each boundary check is still available to report.

---

### User Story 4 - Choosing where to be left once the review request exists (Priority: P3)

The pipeline finishes creating the review request. Instead of leaving the maintainer wherever the run happened to be, it asks where they want to be left, offering the choices that make sense for how the run was set up, and recommending the one that destroys nothing — because the review has not happened yet and the work is what a reviewer will need.

**Why this priority**: Convenience at the end of a run that has already delivered its value. Real, but nothing is lost without it.

**Independent Test**: Complete a run to the point where a review request exists, in each workspace mode, and confirm the offered choices match that mode and that no choice that discards work is offered while anything is uncommitted or unpushed.

**Acceptance Scenarios**:

1. **Given** a run on a branch in the maintainer's own working directory and a review request that now exists, **When** the run reaches its end, **Then** the maintainer is offered: move to the review request's target branch and delete the branch the work was done on; move to the target branch and keep it; or stay on the branch the work was done on.
2. **Given** a run in a separate working directory and a review request that now exists, **When** the run reaches its end, **Then** the maintainer is offered: leave and remove that directory and its branch; leave and remove the directory; leave it in place; or stay.
3. **Given** anything in the workspace is uncommitted or unpushed, **When** the choices are offered, **Then** no choice that would discard it is among them, and the reason is stated.
4. **Given** a blanket approval was given earlier in the run, **When** a choice that deletes a branch or a directory is reached, **Then** it is still asked.

---

### User Story 5 - Gathering evidence without filling the run's context (Priority: P3)

A run needs to read widely to answer a question — what the repository already does, what its governance constrains, what its existing artifacts settle. It dispatches parallel readers that read in their own context and return only findings, and it may dispatch up to ten of them where that many independent questions genuinely exist.

**Why this priority**: An efficiency improvement to something that already works at a smaller number.

**Independent Test**: Give a run enough independent read-only questions to justify a wide fan-out and confirm that more than the previous number may run at once, that each returns evidence rather than a decision, and that none of them writes anything.

**Acceptance Scenarios**:

1. **Given** several independent read-only questions, **When** the run gathers evidence, **Then** it may dispatch up to ten readers at once.
2. **Given** a reader has finished, **When** its report is used, **Then** it contributes evidence and the decision is taken by the run itself.
3. **Given** implementation work is to be carried out, **When** the run performs it, **Then** it is not distributed across parallel readers.

---

### Edge Cases

- The repository-wide instruction file is already within every constraint this feature asserts about it. The feature must prove that rather than change it, and must not manufacture a change to appear to have done work.
- A statement this feature renders untrue may live in a document that is itself a committed record of an earlier decision. Correcting such a record in place would falsify the history it exists to preserve.
- A conflict check that runs at every boundary will report clean on almost every boundary of almost every run. Reported badly it becomes noise the maintainer learns to skip, which is indistinguishable from the check not running.
- Adding a proposal before every phase multiplies the number of approvals in a run. Approvals that carry nothing new train the reader to approve without reading, which is worse than fewer approvals that are read.
- A run in a separate working directory keeps its own record of what it has done inside that directory. A choice that removes the directory removes that record too.
- The workspace choices are offered when the review request has been created, which is before anyone has reviewed it.

## Requirements _(mandatory)_

### Functional Requirements

#### Recorded practices

- **FR-001**: The repository's documentation MUST cover how a Claude Code project is laid out as its own subject, including which locations the tool discovers without being told and how a plugin's declared paths relate to those defaults.
- **FR-002**: Every practice this feature records MUST name the source it was established from; where no authoritative source settles a question, the documentation MUST record that gap explicitly rather than assert an answer.
- **FR-003**: The practices already recorded for working with Claude Code and for authoring skills MUST be re-checked against their authoritative sources as part of this work, and any claim no longer supported MUST be corrected with the correction recorded, not silently replaced.
- **FR-004**: The practices governing how the repository's own documentation and instruction files are authored MUST reach an author at the time they are editing one of those files, rather than only when someone chooses to read the documentation.
- **FR-005**: The scoped rule introduced by FR-004 MUST declare the files it governs, so that it is read when those files are worked on and not at every other time.
- **FR-006**: The scoped rule introduced by FR-004 MUST be subject to the same checks that already apply to the repository's other documentation text.
- **FR-007**: The repository-wide instruction file MUST remain under two hundred lines, MUST continue to reach its detailed rules on demand rather than loading them into every session, and MUST contain what belongs in such a file and nothing that belongs elsewhere. This feature MUST demonstrate that these three properties hold, and MUST NOT restructure the file in order to appear to satisfy them.
- **FR-007a**: "The recommended structure" for the repository-wide instruction file means containing what belongs in such a file, not a prescribed order of sections. No authoritative source defines a section order for one, so this feature MUST NOT invent an order and MUST NOT reorder the file's existing sections. Edits to that file are limited to correcting statements this feature renders untrue, per FR-028.

#### Reaching the pipeline

- **FR-008**: The spec-driven pipeline MUST be reachable both when a user names it and when the model judges it relevant, and MUST NOT be marked as reachable only by explicit user invocation.
- **FR-009**: Every decision that changes the repository outside the pipeline's own working artifacts MUST remain gated on the maintainer's approval, so that reaching the pipeline without being asked cannot cause anything to be done without being asked. Those decisions are, exhaustively: choosing the workspace and the base branch; creating or amending the repository-wide instruction file; invoking each phase; committing; creating the review request; deleting a branch; and removing a working directory. A decision not on this list either does not change the repository outside the pipeline's own artifacts, or the list is wrong and MUST be corrected rather than read loosely.

#### Approving phases

- **FR-010**: Each phase of the pipeline MUST be proposed on its own before it is invoked, and the proposal MUST state the command to be invoked, the exact argument it will receive, and the artifacts it will write.
- **FR-011**: Each phase proposal MUST be approved before that phase runs, and MUST offer proceeding, revising, and stopping. Revising MUST amend only that phase's argument and re-propose it.
- **FR-012**: The pipeline MUST continue to draft every phase's argument together before the first phase runs, and MUST continue to check across all of them for content that belongs to a different phase. Splitting approval across phases MUST NOT remove that check.
- **FR-013**: Each phase proposal MUST state what changed since the drafted plan, so that an unchanged proposal is distinguishable from a revised one. Where nothing changed, that MUST be stated explicitly rather than left to silence — an absent statement is indistinguishable from an omitted one.

#### Conflicted working tree

- **FR-014**: After each step and each phase, the pipeline MUST determine whether the working tree has unmerged paths or an interrupted integration.
- **FR-015**: When the tree is conflicted, the pipeline MUST hand the maintainer to the repository's conflict-resolution workflow before continuing, and MUST NOT resolve the conflict itself.
- **FR-016**: When the tree is clean, the pipeline MUST report that the check ran and found nothing, and MUST NOT reach the conflict-resolution workflow.
- **FR-017**: The outcome of each check MUST be recorded durably enough that a run which has been summarized can still report it.

#### Parallel evidence readers

- **FR-018**: The pipeline MAY dispatch up to ten parallel readers at the same time, when that many genuinely independent read-only questions exist. The limit governs a single batch and not the run as a whole: a run MAY have several such batches, and each one is bounded independently of how many readers earlier batches used.
- **FR-019**: A parallel reader MUST return evidence, MUST NOT make a decision on the run's behalf, MUST NOT modify anything, and MUST NOT ask the maintainer a question.
- **FR-020**: Executing the pipeline's implementation work MUST NOT be distributed across parallel readers.

#### Leaving the workspace

- **FR-021**: Once a review request has been created, the pipeline MUST ask the maintainer where to be left, offering the choices appropriate to how the run was set up.
- **FR-022**: For a run on a branch in the maintainer's own working directory, the choices MUST include moving to the review request's target branch and deleting the branch the work was done on, moving to the target branch and keeping that branch, and staying on it.
- **FR-023**: For a run in a separate working directory, the choices MUST include leaving and removing that directory together with its branch, leaving and removing the directory, leaving it in place, and staying in it.
- **FR-024**: Further choices MAY be offered where they serve the maintainer better than those listed.
- **FR-025**: The choice that discards least MUST be the recommended one, on the ground that the review has not happened and the work is what a reviewer will need.
- **FR-026**: A choice that would discard work MUST NOT be offered while anything in the workspace is uncommitted or unpushed, and the reason MUST be stated when it is withheld.
- **FR-027**: A choice that deletes a branch or removes a working directory MUST be asked explicitly and MUST NOT be covered by any blanket approval given earlier in the run.

#### Keeping the record true

- **FR-028**: Every statement anywhere in this repository that this feature renders untrue MUST be corrected as part of this feature, not left for a later change.
- **FR-029**: Where this feature overrides a decision recorded as a committed contract of an earlier feature, that contract MUST be marked superseded by a new one rather than edited in place, so the earlier record remains an accurate account of what that feature decided.

### Key Entities

- **Recorded practice**: A statement about how to work with Claude Code, carrying either the source it was established from or an explicit note that no authoritative source settles it.
- **Scoped rule**: A set of instructions that declares which files it governs and is read when those files are worked on.
- **Phase proposal**: The statement made before a phase runs — the command, its exact argument, the artifacts it will write, and what changed since the plan.
- **Boundary check**: The determination, made after each step and each phase, of whether the working tree is conflicted, together with its recorded outcome.
- **Workspace choice**: The decision of where the maintainer is left once a review request exists, drawn from the set appropriate to how the run was set up.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A contributor can answer "how is a Claude Code project laid out" from a single document, and every claim in it either names its source or is marked as an unsettled question.
- **SC-002**: Editing any of the repository's own documentation or instruction files brings the practices governing that authoring into scope, without the author having to know which document to open.
- **SC-003**: The repository-wide instruction file is under two hundred lines, this is demonstrated by measurement rather than asserted, and the file's section order is unchanged by this feature.
- **SC-004**: In a full run, no phase is invoked without a preceding proposal that names the command and its exact argument, and this holds for all eight phases.
- **SC-005**: Every phase's argument is drafted before the first phase runs, the check for content belonging to another phase is applied to all of them together, and its result is reported at the plan presentation.
- **SC-006**: Every boundary between steps and phases in a run produces a recorded conflict verdict, and the count of verdicts equals the count of boundaries.
- **SC-007**: A run left with a conflicted working tree reaches the conflict-resolution workflow before running its next phase, in every workspace mode.
- **SC-008**: A single batch may gather evidence from up to ten independent read-only questions at the same time, a run may contain more than one such batch, and no parallel reader modifies any file.
- **SC-009**: Every run that creates a review request ends by asking where the maintainer is to be left, with the choices matching the workspace mode.
- **SC-010**: No run offers a choice that discards uncommitted or unpushed work.
- **SC-011**: After this feature, no statement in the repository asserts the reachability, dispatch relationships, or contract counts that this feature changed, in their previous form.
- **SC-012**: The repository's aggregate quality check passes on the finished work.

## Assumptions

- The maintainer is the same person who runs the pipeline and reviews its output, so proposals may assume familiarity with the pipeline's own vocabulary.
- The existing recorded practices are correct as of when they were written; FR-003 is a re-check, not a presumption that they are wrong.
- The repository has no application code and no separate test runner, so "the check" means the repository's own aggregate quality check.
- The conflict-resolution workflow already exists in this repository and needs no change to be reached; only the reaching of it is new.
- The review request is created by the pipeline and merged by a person, so "once a review request has been created" is the latest point at which the pipeline can still ask anything.
- Workspace choices are offered before review has occurred, which is why FR-025 recommends the least destructive one.
- "The recommended structure" for the repository-wide instruction file means containing what belongs in one, not a prescribed section order — resolved in the Clarifications session above and recorded as FR-007a.
- The ten-reader limit is a concurrency cap on a single batch, not a budget for the whole run — resolved in the Clarifications session above and recorded in FR-018.
