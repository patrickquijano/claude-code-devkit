# Feature Specification: Approvals that carry a decision, guided pipeline repair, and a uniform question standard

**Feature Branch**: `011-narrow-gates-pipeline-fix`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Maintainers of this toolkit run its guided workflows end to end, and three things about how those workflows behave need to change. First, approvals … Second, failed pipelines … Third, how questions are asked and how much everything costs to read. One thing blocks the third change: the repository's written conventions for maintaining its durable instruction files forbid deliberate whole-file revision."

## Clarifications

### Session 2026-09-05

- Q: When the pipeline capability gathers evidence about a failed run, may it retrieve that run's logs from the forge itself, or must the maintainer supply them? → A: Retrieve automatically from the forge using the maintainer's existing authenticated access, falling back to asking the maintainer for the output when that access is absent, unauthenticated, or fails.
- Q: Does shortening the running output cover only what a workflow prints as it runs, or also the artifacts it writes to disk? → A: Only the workflows' own instruction documents and what they print while running. Artifacts written to disk are out of scope.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Approvals only where a decision is still open (Priority: P1)

A maintainer takes a feature through the eight-phase workflow. Today they are asked to approve every phase, including phases whose proposal repeats what they already approved in the plan and which write nothing but specification artifacts. The repetition trains them to click through, so by the time a phase that really does need reading arrives, they are no longer reading. After this change the workflow asks only where the answer is not already settled — where the step cannot be readily undone, or where what is about to run differs from what they approved — and where it does not ask, it says so and says why.

**Why this priority**: It is the change the maintainer raised first, it affects every run of the toolkit's main workflow, and the failure it fixes is one where an approval that still appears to be happening has stopped functioning as one. Restoring the meaning of the remaining approvals is worth more than adding anything new.

**Independent Test**: Run the eight-phase workflow to completion on any small task. Count the approvals requested and compare each against the two conditions. Fully tested by confirming that every requested approval satisfies at least one condition, that every auto-proceeded phase satisfies neither and announced itself, and that the workflow could not have reached implementation without an approval.

**Acceptance Scenarios**:

1. **Given** a phase whose proposal is identical to the plan the maintainer approved and whose effect is readily undone, **When** the workflow reaches that phase, **Then** it proceeds without asking and prints a line naming the phase and the reason no approval was needed.
2. **Given** a phase whose argument was revised after the plan was presented, **When** the workflow reaches that phase, **Then** it asks for approval and shows what changed.
3. **Given** any step that implements, commits, pushes, raises a review request, or deletes a branch or a workspace, **When** the workflow reaches it, **Then** it asks for approval regardless of whether anything changed since the plan.
4. **Given** a maintainer who declines at any remaining approval, **When** they choose to stop, **Then** the workflow halts leaving accurate recorded state and nothing partially applied.

---

### User Story 2 - From a failed pipeline to a verified fix (Priority: P2)

A maintainer's continuous-integration pipeline has failed. Today the toolkit offers no guided path: they read logs themselves, guess at a cause, and fix it outside any workflow, leaving no record. After this change they start from the failed pipeline and are carried through evidence, a proposed root cause, a choice of remediation approach, the fix, and validation — with the same assessment, fix and verification records on disk that any other defect produces, because the existing guided bug-remediation workflow is what performs the work.

**Why this priority**: It is the only genuinely new capability in this feature, and it closes a gap the toolkit currently leaves entirely open. It ranks below User Story 1 because it adds a path rather than repairing one that has stopped working.

**Independent Test**: Point the capability at a repository whose most recent pipeline run failed. Fully tested by confirming the maintainer is shown the failure's evidence, is offered a root cause with the evidence supporting it, chooses an approach from stated alternatives, and ends with a validated fix and the three usual records — without the capability having edited any source file itself.

**Acceptance Scenarios**:

1. **Given** a repository whose most recent pipeline run failed, **When** the maintainer starts the capability, **Then** it retrieves the failing evidence from the forge itself and displays it before proposing anything.
1. **Given** a maintainer with no working authenticated access to the forge, **When** they start the capability, **Then** it says so before beginning, asks them to supply the failing output, and continues from there rather than stopping.
1. **Given** gathered evidence, **When** a root cause is proposed, **Then** the proposal cites the specific evidence supporting it, and the maintainer approves or rejects it before any change is made.
1. **Given** an approved root cause, **When** remediation is proposed, **Then** the maintainer is offered stated alternatives and chooses one before any file is changed.
1. **Given** an applied fix, **When** validation does not show the defect resolved, **Then** the maintainer is offered a return to diagnosis, and may take it as many times as they choose without the capability deciding to stop or to continue on their behalf.
1. **Given** a repository with no failed pipeline run, or hosted where the capability has no support, **When** the maintainer starts it, **Then** it reports that plainly and stops without inventing work.
1. **Given** any run of the capability, **When** it completes, **Then** the defect's assessment, fix and verification records exist on disk in the same form any other defect produces.

---

### User Story 3 - Every question asked the same way (Priority: P3)

A maintainer moving between the toolkit's workflows meets questions in inconsistent shapes: some offer choices with a recommendation and a reason, some offer choices with neither, and some are prose asking them to decide with nothing laid out. They cannot tell, before reading, whether a question will help them decide. After this change every question in every workflow presents its choices, explains what each does and costs, names one as recommended, and says why.

**Why this priority**: It improves every interaction in the toolkit but changes no capability, and a maintainer can work without it. It also depends on nothing else in this feature.

**Independent Test**: Enumerate every point at which any workflow asks the maintainer something. Fully tested by confirming each one presents choices, per-choice explanations, exactly one recommendation, and a stated reason for that recommendation, with no remaining question posed as prose alone.

**Acceptance Scenarios**:

1. **Given** any point where a workflow needs a decision from the maintainer, **When** the question is put, **Then** it presents the available choices rather than asking in prose.
2. **Given** a question with choices, **When** the maintainer reads it, **Then** each choice explains what it does and what it costs, exactly one is marked as recommended, and the reason for that recommendation is stated.
3. **Given** a question where recommending a choice would be wrong — because the answer is the maintainer's alone and no default is defensible — **When** the question is put, **Then** it says so explicitly rather than silently omitting a recommendation.

---

### User Story 4 - Instructions and output that cost less to read (Priority: P4)

The toolkit's own workflow instructions and durable instruction files have grown, and both the maintainer and the workflows themselves pay to read them on every run. After this change they are shortened, and every behavioural rule, constraint, warning, prohibition and recorded rationale in them survives — with the shortening reviewable, so a maintainer can establish for each document that nothing normative was lost. Because the repository's own conventions currently permit only additions to these files and forbid deliberate whole-file revision, those conventions are amended first.

**Why this priority**: It is the highest-risk item and the one whose benefit is least visible, so it goes last. Nothing else in this feature depends on it.

**Independent Test**: For each shortened document, compare it against its previous version. Fully tested by confirming the document is shorter and that every normative statement in the previous version is present in the new one, either verbatim or in a form the comparison shows to be equivalent.

**Ordering caveat**: this story is independently _testable_ but not independently _schedulable_. Shortening a document that User Story 1 or User Story 3 is about to rewrite wastes the work and invalidates the comparison, so this story's work follows theirs. That is a content dependency, not a functional one — nothing in this story needs either of those stories to have shipped.

**Acceptance Scenarios**:

1. **Given** the repository's conventions forbidding deliberate whole-file revision, **When** the shortening work begins, **Then** those conventions have already been amended to permit a reviewed, intentional revision pass while still forbidding incidental tidying during unrelated work.
2. **Given** a document selected for shortening, **When** it is shortened, **Then** every behavioural rule, constraint, warning, prohibition and recorded rationale it previously carried is still present.
3. **Given** a shortened document, **When** a maintainer reviews the change, **Then** the comparison makes it establishable that nothing normative was dropped, rather than requiring them to take it on trust.
4. **Given** a shortening that cannot be made without losing a normative statement, **When** that is discovered, **Then** the document is left unshortened and the reason is reported.

---

### Edge Cases

- A phase auto-proceeds under User Story 1 and then fails. The workflow must make clear that the failure occurred in a phase nobody approved individually, and must not treat the earlier plan approval as covering the failure's consequences.
- The two conditions for asking disagree with a maintainer's expectation — they wanted to be asked about a phase that auto-proceeded. There must be a way to raise the workflow's asking back to every phase for a run.
- The pipeline capability finds several failed runs, or a run with several failing jobs. It must not silently pick one.
- The pipeline capability's evidence points at a cause outside the repository — an outage, a credential expiry, a runner fault. That is a real diagnosis, and it must be reportable as one rather than forced into a code change.
- A pipeline failure and the fix for it turn out to require a requirement change. That is feature work, not defect work, and must be reported as such rather than pushed through the defect path.
- A question genuinely has only one viable answer. Presenting a single choice with a recommendation is degenerate; the workflow must state the fact rather than manufacture alternatives.
- Shortening removes a passage that is not normative but is load-bearing as context — the reason an odd-looking rule exists. Losing it invites a later contributor to "fix" the rule.

## Requirements _(mandatory)_

### Functional Requirements

#### Approvals in the eight-phase workflow

- **FR-001**: The eight-phase workflow MUST request an approval before a phase when that phase's proposal differs in any way from what the maintainer approved in the plan.
- **FR-002**: The eight-phase workflow MUST request an approval before any step whose effect is not readily undone, and MUST treat implementing, committing, pushing, raising a review request, deleting a branch, and creating or removing a workspace as such steps.
- **FR-003**: The eight-phase workflow MUST proceed without requesting an approval when neither FR-001 nor FR-002 applies.
- **FR-004**: When the workflow proceeds under FR-003, it MUST state that it did so, naming the phase and the reason no approval was required. Silence MUST NOT be used to indicate an unrequested approval.
- **FR-005**: The workflow MUST remain incapable of reaching implementation, or any step named in FR-002, without an approval given for that specific step. An approval given for an earlier step MUST NOT satisfy a later one.
- **FR-006**: The workflow MUST continue to draft every phase's argument before the first phase runs and MUST continue to check across all of them for content belonging to a different phase. Reducing the number of approvals MUST NOT remove that check.
- **FR-007**: A maintainer MUST be able to require an approval before every phase for a run, overriding FR-003.
- **FR-008**: Where a phase is skipped rather than run, the workflow MUST report the skip and its reason at the point the phase would have run, whether or not an approval was requested for it.

#### Guided pipeline repair

- **FR-009**: The toolkit MUST offer a capability that takes a maintainer from a failed continuous-integration pipeline to a verified fix.
- **FR-010**: The capability MUST support pipelines on both forges the toolkit already supports, and MUST report a plain, non-failing skip for a repository hosted elsewhere, having no remote, or lacking the means to read its pipeline.
- **FR-011**: The capability MUST gather the failing run's evidence and display it to the maintainer before proposing a cause.
- **FR-011a**: The capability MUST retrieve the failing run's evidence from the forge itself, using access the maintainer already holds. It MUST NOT require the maintainer to obtain, store, or supply any additional credential.
- **FR-011b**: Where that retrieval is not possible — the means of reading the forge is absent, the maintainer is not authenticated, or the attempt fails — the capability MUST report which of those occurred and MUST ask the maintainer to supply the failing output instead. It MUST NOT stop the run for this reason alone.
- **FR-011c**: The capability MUST determine before it begins whether forge retrieval is available, and MUST tell the maintainer which path this run will take rather than discovering it partway through.
- **FR-012**: The capability MUST propose a root cause accompanied by the specific evidence supporting it, and MUST obtain the maintainer's approval of that root cause before anything is changed.
- **FR-013**: The capability MUST offer the maintainer stated alternative remediation approaches and MUST obtain their choice before anything is changed.
- **FR-014**: The capability MUST deliver the fix by invoking the toolkit's existing guided bug-remediation workflow, MUST NOT duplicate that workflow's stages, and MUST NOT edit source files itself.
- **FR-015**: The capability MUST leave the same assessment, fix and verification records on disk that the bug-remediation workflow produces for any other defect.
- **FR-016**: Where validation does not show the defect resolved, the capability MUST offer the maintainer a return to diagnosis, MUST NOT take that return on its own initiative, MUST NOT cap how many times it may be taken, and MUST state how many cycles have already occurred when it offers.
- **FR-017**: Where more than one failed run, or more than one failing job within a run, could be the subject, the capability MUST ask the maintainer which rather than choosing.
- **FR-018**: Where the evidence indicates a cause outside the repository's own content, the capability MUST be able to report that as its finding rather than proceeding to a code change.
- **FR-019**: Where the fix would add or alter a requirement, the capability MUST report that the work is feature work rather than defect work, and MUST NOT carry it through the defect path.

#### How questions are asked

- **FR-020**: Every point at which any of the toolkit's workflows requires a decision from the maintainer MUST present the available choices. A question posed as prose alone MUST NOT be used.
- **FR-021**: Every such question MUST explain, for each choice, what it does and what it costs.
- **FR-022**: Every such question MUST identify exactly one choice as recommended and MUST state the reason for that recommendation.
- **FR-023**: Where recommending a choice would be inappropriate because the decision is the maintainer's alone and no default is defensible, the question MUST say so explicitly rather than omitting the recommendation without comment.
- **FR-024**: This standard MUST be recorded once, in a single place governing all of the toolkit's workflows, rather than restated in each workflow.

#### Conventions, and shortening what must be read

- **FR-025**: The repository's written conventions for maintaining its durable instruction files MUST be amended to permit a deliberate, reviewed revision pass, while continuing to forbid incidental reformatting during unrelated work.
- **FR-026**: The amendment required by FR-025 MUST be in place before any document is shortened.
- **FR-027**: Each of the toolkit's workflow instruction documents, the repository's durable instruction files, and what the workflows print while running MUST be shortened.
- **FR-027a**: The artifacts the workflows write to disk are out of scope for shortening. They MUST NOT be compacted by this feature.
- **FR-028**: Shortening MUST preserve every behavioural rule, constraint, warning, prohibition and recorded rationale the document previously carried.
- **FR-029**: For each shortened document it MUST be establishable, by comparison against the previous version, that nothing normative was dropped.
- **FR-030**: Where a document cannot be shortened without losing a normative statement, it MUST be left unshortened and the reason reported.
- **FR-031**: Shortening MUST NOT breach the length, structure and formatting limits the repository already places on these documents.

#### Records and supersession

- **FR-032**: The requirements of feature `006-claude-code-guidance` that mandate an approval before every phase MUST be recorded as superseded by FR-001 through FR-005, with feature 006's own specification left intact as the record of what it shipped.
- **FR-033**: Feature 006's requirement that all phase arguments be drafted together and checked for cross-phase leakage MUST be recorded as surviving unchanged, per FR-006.
- **FR-034**: The recorded reasoning that ties the removal of per-phase approvals to a change in how the workflow may be invoked MUST be re-examined and its outcome recorded, since this feature narrows those approvals rather than removing them.
- **FR-035**: The committed record of how many workflows the toolkit distributes MUST be updated to include the capability added by FR-009, superseding the previous count.
- **FR-036**: Every place the repository states how many workflows it distributes MUST agree with FR-035 after this feature.

### Key Entities

- **Approval point**: A place where a workflow stops for the maintainer's decision. Carries the step it guards, whether that step is readily undone, and whether what is about to run differs from what was approved.
- **Pipeline failure evidence**: What was gathered about a failed run — which run, which job, and the failing output — and which is shown to the maintainer before a cause is proposed.
- **Root cause proposal**: A stated cause together with the specific evidence supporting it, awaiting the maintainer's approval.
- **Remediation approach**: One of several stated alternatives for addressing an approved root cause, chosen by the maintainer.
- **Question**: A request for a maintainer decision, carrying its choices, each choice's effect and cost, one recommendation, and the reason for it.
- **Shortened document**: A workflow instruction or durable instruction file, its previous version, and the comparison establishing that no normative statement was lost.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: On a run where nothing is revised after the plan, the number of approvals the eight-phase workflow requests is strictly fewer than the number of phases it runs.
- **SC-002**: Every approval the workflow requests satisfies at least one of the two stated conditions, and every phase that proceeds unasked satisfies neither — verifiable by inspecting a completed run's record.
- **SC-003**: No run reaches implementation, a commit, a push, a review request, or the deletion of a branch or workspace without an approval recorded for that specific step. Zero exceptions.
- **SC-004**: Every phase that proceeds without an approval announces itself with a reason, so a maintainer reading a run's output can account for every phase as either approved or announced. Zero unaccounted phases.
- **SC-005**: A maintainer starting from a failed pipeline reaches either a validated fix or a stated reason why one is not possible, without leaving the guided path.
- **SC-006**: Every completed pipeline-repair run leaves the same three defect records on disk that any other defect produces. Zero runs complete without them.
- **SC-007**: The pipeline capability makes no source-file change of its own; every change originates from the bug-remediation workflow it invokes.
- **SC-008**: Every question in every workflow presents choices, per-choice explanations, exactly one recommendation, and the reason for it — or states explicitly why no recommendation is given. Zero questions posed as prose alone.
- **SC-009**: The standard governing questions is stated in exactly one place. Zero restatements.
- **SC-010**: Every shortened document is shorter than its previous version and retains every normative statement from it. Zero normative statements lost.
- **SC-010a**: No artifact written by a workflow is compacted by this feature. Zero artifact files shortened.
- **SC-011**: Every statement in the repository of how many guided workflows it distributes agrees with every other. The repository's own word for one of these is a **skill**, so the statements to compare are the ones using that word. Zero disagreements.
- **SC-012**: A maintainer with working forge access reaches displayed failing evidence without supplying any output by hand; one without it is told so before the run begins rather than partway through. Zero runs discover the missing access late.

## Supersession record

This feature supersedes part of feature `006-claude-code-guidance` and the count contract of feature `010-bug-run-ship`. Both of those specifications stay on disk unchanged, as the record of what they shipped.

| Superseded                                                     | By                                 | Why                                                                                                                            |
| -------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| 006 FR-010 — every phase proposed before it runs               | FR-001 – FR-004                    | A proposal is still made at every boundary, but only a boundary that gates presents the four-row form; the rest announce.      |
| 006 FR-011 — every phase approved before it runs               | FR-001 – FR-003, FR-005            | Approval is now required where the step is irreversible or its argument changed, not uniformly.                                |
| 006 FR-013 — every proposal states what changed since the plan | FR-001, FR-004                     | The delta row survives on gated proposals and is now the reason the gate fired; unasked boundaries state their reason instead. |
| 010 `contracts/skill-names.md` — seven skills                  | FR-035, `contracts/skill-names.md` | An eighth skill exists, and `ccd-speckit-bug-run` gained a second caller.                                                      |

**006 FR-012 is not superseded and survives verbatim.** All eight phase arguments are still drafted together at Step 3 and still checked across each other for cross-phase leakage, whatever `gate_mode` says and however few boundaries end up asking. FR-006 restates that obligation, and T025 exists solely to verify it survived the Step 4 rewrite — because the specify prompt sits in the auto-proceed set and is the prompt most often corrupted.

**The `disable-model-invocation` pairing is satisfied, not discharged.** 006 recorded that removing the per-phase gates would revive the argument for restoring that field. This feature narrows them instead, and the property the pairing depended on is intact: no run reaches implementation or any irreversible step without an approval for that step. If a future feature removes the always-gate set, the argument returns and the field should return with it. Recorded at `research.md` R9 and `contracts/skill-names.md`.

## Assumptions

- The maintainer running these workflows is the repository's own maintainer, working locally, and is the person whose approvals the workflows seek. There is no second role.
- "Readily undone" means undone by the maintainer without recovering data or contacting a remote service. Writing a specification artifact is readily undone; pushing is not.
- The pipeline capability is used against repositories other than this one, since this repository runs no continuous-integration pipeline of its own. Its forge behaviour therefore cannot be exercised end to end by this repository's own checks, and this feature does not treat that as a gap to close.
- The existing guided bug-remediation workflow is fit to receive pipeline defects unchanged. This feature adds a caller, not a stage.
- Shortening is judged against the previous committed version of each document, and the comparison a reviewer reads is the change itself.
- The two forges the toolkit supports today are the two the pipeline capability supports. No third is added.
- Feature 006's specification remains on disk unchanged; supersession is recorded in this feature, in keeping with how earlier supersessions in this repository were handled.
- The maintainer's access to their own forge already exists and is what the capability reads through. This feature introduces no credential of its own, stores nothing, and grants the capability no access the maintainer does not already have.
- Compaction of the artifacts a workflow writes is already served by tooling the repository has installed, so leaving artifacts out of scope removes duplication rather than leaving a need unmet.
