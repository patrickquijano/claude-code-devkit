# Feature Specification: Guided Bug Triage Run

**Feature Branch**: `009-bug-triage-run`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "A maintainer working in a repository that has bug-triage capability installed needs to take one bug report from raw description to a verified fix in a single guided run, instead of remembering three separate commands, their argument forms and their ordering constraints."

## Clarifications

### Session 2026-09-05

- Q: When the run's validation stage says the fix worked only partly, should the run stop and ask what to do, or finish and record the partial result? → A: Stop and ask, exactly as for an unresolved result. A `partial` result can mean a listed reproduction was never actually exercised, so it can mean "nobody checked".
- Q: When a run starts and the working tree already carries uncommitted edits, should the run refuse to start, warn and continue, or say nothing? → A: Warn, naming the already-modified paths, and continue. Not a hard refusal: fixing a bug mid-task is ordinary, and the remediation stage's own change record lists what the fix touched, so naming what was dirty beforehand gives both halves of the subtraction.
- Q: The assessment verdict can say a defect is real but not reproduced. FR-007 only handled "not a real defect". What should the run do with that middle verdict? → A: Proceed to remediation, and state at that boundary that the defect was not reproduced. Do not raise the run's own question about it — the remediation stage asks that itself, and duplicating it puts one decision to the maintainer twice.
- Q: The remediation stage can record that a change was applied only in part. FR-008 only skipped validation on "skipped" or "no change applied". What should the run do? → A: Proceed to validation, and carry the partial remediation status into the closing report alongside the validation result. Validation is the stage best placed to say whether the applied part was enough.
- Q: Who commits the three reports a run produces — the run itself, or the maintainer? → A: Not the run. It leaves them uncommitted and its closing report names their paths, states that governance requires them committed before the change is proposed for review, and names the toolkit's existing commit workflow as the way to do it. This keeps FR-020 and the non-goals intact rather than amending them.

### Session 2026-09-05 (post-analysis)

Raised by `/speckit-analyze` after task generation, and resolved before implementation.

- Q: FR-019 forbids anything happening without approval, but never says what counts as "happening" — does reading the repository qualify? → A: "Happening" is invoking a stage or writing a file. Reads and the read-only preflight are outside the requirement and may precede the first approval; without them the first boundary would have nothing to state.
- Q: SC-001 ("without reading any other document") cannot be verified from a completed run's artifacts. Restate it or keep it? → A: Restated as a checkable proxy — every fact needed to decide is present in the run's own output — with the original goal kept explicitly as what the proxy approximates, and the observed trial named as what would actually establish it.
- Q: Terminology alternates between "maintainer" and "caller". → A: "maintainer" throughout; "caller" removed.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - One report, one guided run (Priority: P1)

A maintainer has a bug report in front of them — a pasted stack trace, an issue link, or both. They start one guided run and hand it that report. The run assesses the defect, shows them what it found, applies the remediation, and validates that the symptom is gone. At each boundary they see exactly what is about to happen and decide whether it happens. At the end they are told what each stage concluded and where each report was written.

**Why this priority**: This is the whole feature. Without it there is nothing; with it alone the maintainer already stops having to remember three commands, their argument forms, and which one refuses until which other has run.

**Independent Test**: Can be fully tested by starting a run against a real defect in a repository with the capability installed, approving each stage, and confirming that three reports exist afterwards and that the reported outcomes match what those reports actually say.

**Acceptance Scenarios**:

1. **Given** a repository with the bug-triage capability installed and a bug report as pasted text, **When** the maintainer starts a run and approves each stage, **Then** assessment, remediation and validation each run once in that order, and the run's closing report names each stage's recorded outcome and the location of each report.
2. **Given** a run at a stage boundary, **When** the maintainer chooses to stop, **Then** no further stage is invoked, and what has already been written stays on disk and is reported.
3. **Given** a run at a stage boundary, **When** the maintainer revises the wording that stage will be given, **Then** only that stage's wording changes, and the boundary is presented again with the revision shown.

---

### User Story 2 - The run refuses to waste a stage (Priority: P2)

The assessment concludes the report is not a real defect, or the remediation concludes it changed nothing. The maintainer is told which stage will not run and why, rather than watching a stage be invoked that would refuse anyway.

**Why this priority**: The underlying capability already refuses in these cases. A run that invokes anyway produces a confusing failure at the end of a sequence the maintainer has been approving in good faith, and teaches them to distrust the boundaries.

**Independent Test**: Can be tested by giving the run a report that assessment will judge not to be a defect, and confirming that the remediation stage is announced as skipped with its reason and is never invoked.

**Acceptance Scenarios**:

1. **Given** an assessment whose recorded verdict says the report is not a real defect, **When** the run reaches the remediation boundary, **Then** the run states that remediation will be skipped and why, invokes nothing, and proceeds to its closing report.
2. **Given** a remediation whose recorded outcome says no change was applied, **When** the run reaches the validation boundary, **Then** validation is announced as skipped with that reason rather than invoked.
3. **Given** any skipped stage, **When** the run makes its closing report, **Then** the skip and its reason appear there, distinguished from a stage that ran.

---

### User Story 3 - An unresolved defect is a question, not a verdict (Priority: P2)

Validation reports the symptom still reproduces. The run does not declare success, and does not quietly start over. It tells the maintainer what validation found and asks what to do.

**Why this priority**: This is the case where an automated run is most tempted to lie or to loop. Both failures are expensive: one ships an unfixed defect believing it fixed, the other burns turns re-deriving an assessment nobody asked for.

**Independent Test**: Can be tested by running against a defect whose remediation is deliberately insufficient, and confirming the run neither reports success nor re-invokes a stage without being told to.

**Acceptance Scenarios**:

1. **Given** a validation whose recorded result says the defect is not resolved, **When** the run reaches its end, **Then** it presents the maintainer with a choice of what to do next and invokes nothing until answered.
2. **Given** the same situation, **When** the run makes its closing report, **Then** the run is not described as successful.
3. **Given** a validation whose recorded result says the defect is only partly resolved, **When** the run reaches its end, **Then** it behaves exactly as in scenario 1, and additionally states why the result was partial.

---

### Edge Cases

- The bug-triage capability is not installed in this repository. The run reports that and stops, rather than attempting the stages by hand.
- The maintainer supplies an identifier that is already in use by an earlier bug. The run must not silently overwrite an existing report.
- The maintainer supplies no identifier at all.
- The bug report is a URL to a host the underlying capability will not fetch from.
- The bug report is empty, or is unrelated to this repository.
- A stage is invoked and writes nothing, or reports an error.
- The maintainer stops the run after remediation has already edited source files.
- The session is long enough that the run can no longer rely on recalling what an earlier stage concluded.

## Requirements _(mandatory)_

### Functional Requirements

**Input and identity**

- **FR-001**: The run MUST accept one bug report supplied as pasted text, as a URL, or as both together, and MUST accept an optional maintainer-supplied identifier for that bug.
- **FR-002**: Where the maintainer supplies no identifier, the run MUST let the underlying capability derive one rather than inventing its own.
- **FR-003**: The run MUST NOT cause an existing bug's report to be overwritten without the maintainer being asked first.
- **FR-004**: The run MUST pass the bug report to the assessment stage unaltered, and MUST NOT itself retrieve the contents of a URL contained in it.

**Stages and ordering**

- **FR-005**: The run MUST consist of exactly three stages — assessment, then remediation, then validation — in that order, and MUST NOT add a fourth stage.
- **FR-006**: The run MUST NOT perform any stage's own work itself. Each stage's work happens only by invoking that stage.
- **FR-007**: The run MUST branch on the assessment's recorded verdict, and MUST cover every value that verdict can take:
  - Verdict says the report is **not a real defect** → the run MUST skip the remediation stage, stating the reason.
  - Verdict says the defect is **real but not reproduced** → the run MUST proceed to the remediation stage, and MUST state at that stage's boundary that the defect was not reproduced, so the maintainer approves in view of it. The run MUST NOT ask its own question about whether to proceed on unreproduced evidence: the remediation stage asks that itself, and duplicating it would put the same decision to the maintainer twice.
  - Verdict says the defect is **real and established** → the run MUST proceed to the remediation stage.
- **FR-008**: The run MUST branch on the remediation stage's recorded status, and MUST cover every value that status can take:
  - Remediation was **skipped**, or records that **no change was applied** → the run MUST skip the validation stage, stating the reason.
  - Remediation records that the change was **applied in part** → the run MUST proceed to the validation stage, and its closing report MUST state both the partial remediation status and the validation result. A partial remediation is the case validation is best placed to characterise, and is not grounds to skip it.
  - Remediation records that the change was **applied in full** → the run MUST proceed to the validation stage.
- **FR-009**: A stage that is going to be skipped MUST still be announced at its boundary, with its reason, before the run moves past it.
- **FR-010**: Where the validation stage's recorded result says the defect is not resolved **or is only partly resolved**, the run MUST put the choice of what happens next to the maintainer, MUST NOT re-invoke any stage on its own initiative, and MUST NOT describe the run as successful. The two results are treated identically; neither is an ending the run may reach on its own.

**Boundaries and approval**

- **FR-011**: Before invoking a stage, the run MUST state what will be invoked, the exact wording that stage will receive, and the artifacts that stage will write.
- **FR-012**: At each stage boundary the maintainer MUST be able to proceed, revise the wording that stage will receive, or stop the run.
- **FR-013**: Revising MUST change only the wording of the stage being approved, and MUST re-present that boundary rather than proceeding.
- **FR-014**: Stopping MUST leave every artifact already written in place, and MUST NOT invoke a further stage.

**Truthfulness of reporting**

- **FR-015**: The run MUST NOT record a stage as complete until that stage's artifact has been confirmed to exist.
- **FR-016**: The run MUST take each stage's outcome from what that stage recorded, not from recollection of the conversation, so that the closing report stays accurate in a session long enough for earlier detail to be lost.
- **FR-017**: The run's closing report MUST state, for every stage, whether it ran or was skipped, its recorded outcome, its reason if skipped, and the location of the report it wrote.

**Reachability and scope**

- **FR-018**: The run MUST be startable both by the maintainer naming it and by an assistant judging it relevant to the request at hand.
- **FR-019**: Being started without being named MUST NOT cause anything to happen that the maintainer was not asked to approve first. "Happen", here, means invoking a stage or writing a file. Reading the repository and running the read-only preflight are not covered by this requirement and MAY occur before the first approval — they are how the run assembles the facts the first boundary must state, and requiring approval to gather them would leave the maintainer approving a boundary with nothing in it.
- **FR-020**: The run MUST NOT create a branch, MUST NOT commit, and MUST NOT open a review request.
- **FR-021**: One run MUST handle exactly one bug report.
- **FR-022**: The run MUST NOT weaken, bypass or duplicate any safety rule the underlying capability applies to untrusted bug-report content.
- **FR-023**: Where the bug-triage capability is not available in the repository, the run MUST report that and stop, rather than carrying out the stages by other means.

**What the repository gains**

- **FR-024**: The repository MUST carry a written record of the researched standards and behaviour this feature is built on, in which every claim of fact names the source it came from, and every question the sources do not settle is recorded as an open gap rather than answered by guess.
- **FR-025**: Any durable working rule established by that research MUST be recorded exactly once, in the location this repository already uses for rules of that scope, and MUST NOT be duplicated into a second location.
- **FR-026**: The repository MUST carry a written review of the resulting run's own design, naming the risks, gaps and improvements identified, the options weighed for each, and which resolution was chosen.
- **FR-027**: The published record of which skills this repository distributes, and how each may be reached, MUST be accurate once this feature is complete.

**Settled by clarification** (see the Clarifications section)

- **FR-028**: Where the validation stage records that the defect is only partly resolved, the run MUST treat that result exactly as it treats an unresolved one under FR-010 — stop, state what validation found including why the result was partial, and put the choice to the maintainer. The run MUST NOT complete on a partial result of its own accord, because a partial result can mean a listed reproduction was never exercised rather than that the fix fell short.
- **FR-029**: Where the working tree already carries uncommitted changes when the run starts, the run MUST report which paths are already modified, before the remediation stage runs, and MUST then continue. The run MUST NOT refuse to start on that basis, and MUST NOT set the maintainer's existing work aside on their behalf.
- **FR-030**: The reports a run produces MUST be left uncommitted, consistent with FR-020. The run's closing report MUST name the path of each report it produced, MUST state that governance requires those artifacts to be committed before the change is proposed for review, and MUST name the toolkit's existing commit workflow as the means. The run MUST NOT perform that commit itself.

### Key Entities

- **Bug report**: what the maintainer supplies — free text, a link, or both. Untrusted content; its origin is outside this repository.
- **Bug identifier**: the short name distinguishing one bug's artifacts from another's. Supplied by the maintainer or derived by the capability.
- **Assessment report**: what the assessment stage records — whether the report is a real defect, how serious it is, where the cause is suspected to be, and what remediation is proposed. Consumed by the remediation stage.
- **Change record**: what the remediation stage records — what was changed, whether it was applied fully, partly or not at all, and any departure from what the assessment proposed.
- **Verification report**: what the validation stage records — which checks were run, what each returned, and whether the defect is resolved, partly resolved, or not resolved.
- **Run record**: what the run itself keeps so that its closing report is drawn from fact rather than recall — which stages ran, which were skipped and why, and what each recorded.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Every fact a maintainer needs in order to decide is present in the run's own output: each stage boundary names what will be invoked, the wording it will receive and the artifacts it will write; each skip names the recorded value that caused it; and the closing report names every report's path and the outstanding commit obligation. Verified by reading a completed run's output and confirming that no decision it asked for required information from outside it. This is a checkable proxy for the underlying goal — that a maintainer who has never used the bug-triage capability can complete a run unaided — and does not replace it: establishing the goal itself needs an observed trial with such a maintainer, which no artifact review can substitute for.
- **SC-002**: Across runs, the number of stage invocations that the underlying capability refuses because a precondition was unmet is zero.
- **SC-003**: 100% of runs end with a closing report that names every stage's status, outcome and report location, including for stages that were skipped.
- **SC-004**: 100% of runs that result in a source change leave an assessment, a change record and a verification report on disk.
- **SC-005**: No run advances past a stage boundary without an explicit decision from the maintainer.
- **SC-006**: In runs where the defect is not resolved or is only partly resolved, the number that describe themselves as successful is zero.
- **SC-007**: Every factual claim in the repository's new written record of this research is traceable to a named source, and every unsettled question is listed as an open gap.

## Assumptions

- The repository the run executes in already has the bug-triage capability installed and enabled. Installing it is out of scope; FR-023 covers the case where it is absent.
- A maintainer is present and able to answer at each stage boundary. The run is interactive by design; there is no unattended mode.
- This repository has no automated test runner, so "verification" of this feature means its own quality checks passing and its written run scenarios being exercised, not a test suite.
- One bug per run is sufficient. Batch triage across several reports is out of scope and is stated as a non-goal.
- The artifacts the stages write are project history in this repository rather than disposable working state, following the disposition this repository already settled for such artifacts.
- The run is guided rather than autonomous: it is acceptable and expected for it to stop and ask, and stopping is not a failure.

## Non-Goals

- Changing the underlying bug-triage capability, its stages, its artifact formats, or its safety rules.
- Changing the existing eight-phase feature pipeline this repository already distributes.
- Adding commands, agents or MCP servers to the distributed toolkit.
- Creating a branch, committing, or opening a review request as part of a run.
- Handling more than one bug report in a single run.
- Deciding for the maintainer whether an unresolved or partly resolved defect is acceptable.
