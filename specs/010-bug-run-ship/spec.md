# Feature Specification: Bug triage run ships its own work

**Feature Branch**: `010-bug-run-ship`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "A maintainer taking one bug report through the guided triage run must be able to see it through to a raised review request in that same run, instead of stopping at three uncommitted reports and being told which other workflow to invoke next. The run must first ask where the work should happen, offering only the choices that apply to the situation it finds: starting fresh, a new isolated workspace or a new line of work in the current one; already isolated, staying put; and in every case the option to leave the workspace exactly as it is. It must then carry out the chosen answer before any stage runs. Where validation records that the defect is not resolved, or only partly resolved, the maintainer must be able to choose to send the run back to the assessment stage carrying the new evidence, and that choice must actually re-enter the run rather than end it; the run must still never take that decision by itself. Where validation records the defect resolved, the run must commit and push the work, and then raise a review request, in that order, by handing each job to the workflow that already owns it rather than performing it. Once a review request exists, the run must ask where to leave the maintainer's workspace, offering the choices that match how the work was set up: for a line of work, moving to the review request's target and discarding the finished line, moving to the target and keeping it, or staying; for an isolated workspace, leaving and discarding it along with the line of work, leaving and discarding the workspace, leaving it in place, or staying. A raised review request must also carry the option for the source line of work to be removed once it is accepted, offered as a decision in its own right and not welded to any other merge setting. This supersedes the earlier prohibition on the run creating a line of work, committing, or raising a review request, and the earlier requirement that it leave its reports uncommitted; the earlier prohibition on the run acting on its own initiative is unchanged and still binds. The repository must also carry a written record of the researched standards this rests on, every claim naming its source and every unsettled question recorded as an open gap, and any durable working rule that record establishes must be written exactly once. Non-goals: changing what the three triage stages themselves do; handling more than one bug report per run; merging the review request."

## Clarifications

### Session 2026-09-05

- Q: When a maintainer chooses to send the run back to assessment after a failed validation, may they keep doing that as many times as they like, or should the run stop itself after a set number of attempts and hand the problem back? → A: No cap. Each return is the maintainer's explicit choice, and the run reports how many cycles have happened so far so the decision is informed.
- Q: Should the GitLab merge-request workflow also be changed to offer branch removal as its own choice, or does only the GitHub one need it? → A: Only the GitHub one. The GitLab workflow already offers it as a free-standing choice; parity is verified and recorded rather than assumed, and no second workflow is reworked.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - The run reaches a review request without changing tools (Priority: P1)

A maintainer pastes a bug report and asks for it to be triaged. The run assesses the defect, applies the remediation, validates it, and — because validation says the defect is resolved — commits the work and raises a review request, then reports the URL. The maintainer approves each of those steps as it comes, and at no point is told to go and invoke a different workflow to finish the job.

**Why this priority**: This is the whole of the feature's value. Today the run stops with three reports on disk and names a workflow the maintainer must invoke themselves, which is where the evidence trail is most often abandoned. Governance already requires those artifacts committed before the change is proposed for review, so a run that cannot commit them leaves the maintainer to satisfy a requirement the run created.

**Independent Test**: Run the whole triage on a real defect whose fix validates cleanly, and confirm a review request exists at the end, carrying commits that include all three reports, with no other workflow invoked by hand.

**Acceptance Scenarios**:

1. **Given** validation has recorded the defect resolved, **When** the run reaches its shipping step, **Then** the maintainer is asked to approve committing the work, and on approval the commit job is handed to the workflow that owns commits rather than performed by the run.
2. **Given** the work has been committed and pushed, **When** the run continues, **Then** the review-request job is handed to the workflow that owns review requests for the forge this repository actually ships to, and the resulting URL is reported.
3. **Given** the commit step has been declined, **When** the run continues, **Then** it does not raise a review request on work that was never committed, and says why.
4. **Given** no review-request workflow applies to this repository's remote, **When** the run reaches that step, **Then** it reports the reason, skips only that step, and still finishes.

---

### User Story 2 - The maintainer chooses where the work happens (Priority: P1)

Before anything is assessed, the maintainer is asked where this triage should happen — set up somewhere isolated so the tree they have open is untouched, start a fresh line of work where they are, or carry on exactly as they are. The run then does what they chose, and every later step behaves consistently with that answer.

**Why this priority**: Remediation edits source files. Doing that in a tree the maintainer has open, on whatever line of work they happened to be on, is the failure that costs them their own uncommitted work — and it happens before they have seen a single finding. The choice has to come first, not after the edits.

**Independent Test**: Start a run from a clean tree, from a tree with uncommitted changes, and from inside an already-isolated workspace, and confirm each offers only the choices that make sense there and then honours the one picked.

**Acceptance Scenarios**:

1. **Given** the run starts in an ordinary working tree, **When** the maintainer is asked where the work should happen, **Then** the choices include a fresh isolated workspace, a new line of work in the current tree, and staying exactly as they are.
2. **Given** the run starts in a workspace that is already isolated, **When** the same question is asked, **Then** it does not offer to create another isolated workspace inside it, and says why.
3. **Given** a choice has been made, **When** the run continues, **Then** it carries that choice out and confirms it took effect before any stage runs.
4. **Given** isolating the work is impossible in this repository, **When** the question is asked, **Then** that choice is not offered and the reason is stated rather than the option silently missing.

---

### User Story 3 - A failed validation can send the run back to assessment (Priority: P2)

Validation records that the defect is not resolved, or only partly resolved. The run stops and puts the choice to the maintainer, as it already does. What is new is that choosing to reassess actually returns the run to the assessment stage, carrying what validation just found, instead of ending the run and requiring it to be started again from the beginning.

**Why this priority**: The loop is the common case for a defect whose first remediation misses, and the value is that the evidence from validation reaches assessment rather than being retyped. It depends on nothing in the other stories and can ship after them.

**Independent Test**: Drive a defect whose first remediation fails validation, choose to reassess, and confirm the run re-enters assessment with validation's findings available to it rather than terminating.

**Acceptance Scenarios**:

1. **Given** validation records the defect unresolved, **When** the run stops and offers the choices, **Then** reassessing is one of them, alongside accepting the result and stopping.
2. **Given** the maintainer chooses to reassess, **When** the run continues, **Then** it re-enters the assessment stage carrying validation's findings, and the stage boundary is approved as any other is.
3. **Given** validation records the defect only partly resolved, **When** the run stops, **Then** it offers the same choices as for an unresolved defect and describes neither as success.
4. **Given** validation records any result at all, **When** the run decides what happens next, **Then** it never re-enters a stage without the maintainer having chosen it.

---

### User Story 4 - The maintainer chooses where to be left (Priority: P2)

Once a review request exists, the run asks where to leave the maintainer's workspace. The choices match how the work was set up, and the least destructive one is the default, because nobody has reviewed the change yet.

**Why this priority**: Without it a run ends leaving the maintainer wherever the work happened to put them — often inside an isolated workspace they now have to find and clean up by hand. It is real value but it is the last thing that happens, so it ships after the steps that produce the review request.

**Independent Test**: Finish two runs, one set up in an isolated workspace and one on a line of work in the current tree, and confirm each offers the matching set of choices and honours the one picked.

**Acceptance Scenarios**:

1. **Given** the work happened on a line of work in the maintainer's own tree, **When** the question is asked, **Then** the choices are to stay, to move to the review request's target keeping the line of work, or to move to the target and discard it.
2. **Given** the work happened in an isolated workspace this run created, **When** the question is asked, **Then** the choices are to stay, to leave it in place, to leave and discard it, and to leave and discard it along with the line of work.
3. **Given** the workspace was already isolated before the run started, **When** the run finishes, **Then** it does not offer to discard a workspace it did not create.
4. **Given** anything in the workspace is uncommitted, or the line of work has commits that exist nowhere else, **When** the choices are offered, **Then** the destructive ones are withheld and the reason is stated.
5. **Given** no review request was raised, **When** the run finishes, **Then** this question is not asked and the run says why.

---

### User Story 5 - The review request can retire its own source line of work (Priority: P3)

When a review request is raised, the maintainer can choose to have its source line of work removed once the change is accepted — as a decision of its own, separate from any other setting about how the change is merged.

**Why this priority**: It is a small correction to an existing choice rather than new capability. Today the two are welded together, so a maintainer who does not want the change merged automatically also cannot ask for the finished line of work to be tidied up.

**Independent Test**: Raise a review request choosing source-line removal without choosing automatic merging, and confirm both settings took the values chosen.

**Acceptance Scenarios**:

1. **Given** a review request is being raised, **When** the maintainer is asked how it should be handled, **Then** removing the source line of work once accepted is offered as its own choice.
2. **Given** the maintainer picks source-line removal and declines automatic merging, **When** the review request is raised, **Then** it is not set to merge automatically and it is set to retire its source line of work.
3. **Given** the repository already retires source lines of work by default, **When** the question is asked, **Then** the run says so rather than offering a choice that changes nothing.

---

### Edge Cases

- The maintainer chooses to reassess after a failed validation, and the reassessment reaches the same result. The loop must remain the maintainer's to continue or end, and the run must not present repetition as progress.
- The commit step is approved but the workflow that owns commits stops partway or is declined at its own gate. The run must re-check what is actually committed rather than assuming its request succeeded.
- Assessment finds the report is not a real defect. Nothing has been remediated, so there is nothing to commit and nothing to review; the shipping steps must be skipped with that reason.
- Remediation records that nothing was applied. Validation is skipped, and the shipping steps have no change to carry.
- The workspace is discarded while the reports it produced are the only copy. Any choice that discards work must be withheld until that work exists somewhere else.
- The repository's remote is at neither supported forge. The review-request step is skipped with the host named, and the run still finishes.
- The maintainer stops the run at any boundary. Everything already written stays where it is.

## Requirements _(mandatory)_

### Functional Requirements

#### Workspace selection

- **FR-001**: Before any stage runs, the run MUST ask the maintainer where the work is to happen, and MUST NOT assume an answer.
- **FR-002**: The choices offered MUST be only those that apply to the situation the run finds. A choice that cannot be carried out in this repository MUST NOT be offered, and its absence MUST be explained rather than left silent.
- **FR-003**: The choices MUST always include leaving the workspace exactly as it is.
- **FR-004**: The run MUST carry out the chosen answer, and MUST confirm it took effect, before the first stage runs.
- **FR-005**: Where the run is already in an isolated workspace, it MUST NOT offer to create another one inside it.
- **FR-006**: The run MUST record which arrangement was chosen, in a form later steps read rather than recall, so that the closing steps behave consistently with it after a session long enough for earlier detail to be lost.

#### Returning to assessment

- **FR-007**: Where validation records the defect unresolved or only partly resolved, the run MUST offer returning to the assessment stage as one of the maintainer's choices, alongside accepting the result and stopping.
- **FR-008**: Where the maintainer chooses to return, the run MUST re-enter the assessment stage rather than end, and MUST carry validation's recorded findings into it.
- **FR-009**: The run MUST NOT return to any stage except on the maintainer's explicit choice. This requirement restates an existing one and does not supersede it.
- **FR-010**: A stage re-entered this way MUST be approved at its boundary on the same terms as any other stage.
- **FR-011**: The run MUST NOT describe a repeated cycle as progress, and MUST NOT describe an unresolved or partial result as success.
- **FR-011a**: The run MUST NOT cap the number of times the maintainer may return to assessment. Each return is an explicit choice, and the run MUST NOT stop the loop on its own.
- **FR-011b**: When offering the choice to return, the run MUST state how many cycles have already happened, so that the choice is made in view of the loop's own history rather than blind.

#### Shipping the work

- **FR-012**: Where validation records the defect resolved, the run MUST offer to commit and push the work, and on approval MUST hand that job to the workflow that already owns commits rather than performing it.
- **FR-013**: After the commit job returns, the run MUST re-establish what is actually committed rather than assume its request succeeded, and MUST report the result.
- **FR-014**: The run MUST then offer to raise a review request, and on approval MUST hand that job to the workflow that owns review requests for the forge this repository's remote actually points at.
- **FR-015**: The two MUST happen in that order, and the review request MUST NOT be raised on work that was never committed.
- **FR-016**: The run MUST hand the review-request workflow facts rather than answers, leaving that workflow's own decisions to it.
- **FR-017**: Where no review-request workflow applies — an unsupported forge, no remote, or the workflow not installed — the run MUST record the reason, skip only that step, and still finish.
- **FR-018**: Where a stage was skipped or recorded that nothing was applied, the run MUST skip the shipping steps with that reason.
- **FR-019**: This supersedes the earlier requirements that the run create no line of work, perform no commit, raise no review request, and leave its reports uncommitted. The supersession MUST be recorded where the earlier requirements are recorded, and the earlier record MUST NOT be rewritten to pretend it always said this.

#### Leaving the workspace

- **FR-020**: Once a review request exists, the run MUST ask the maintainer where to leave the workspace, in a single question whose choices match the arrangement recorded at the start.
- **FR-021**: Where the work happened on a line of work in the maintainer's own tree, the choices MUST be staying, moving to the review request's target while keeping that line of work, and moving to the target while discarding it.
- **FR-022**: Where the work happened in an isolated workspace, the choices MUST be staying, leaving it in place, leaving and discarding it, and leaving and discarding it together with the line of work.
- **FR-023**: The least destructive choice MUST be the recommended one, because the change has not been reviewed at the point the question is asked.
- **FR-024**: A choice that would discard work not recorded anywhere else MUST NOT be offered, and the reason MUST be stated rather than the choice quietly missing.
- **FR-025**: The run MUST NOT offer to discard an isolated workspace it did not create.
- **FR-026**: Where no review request was raised, this question MUST be skipped and the reason stated.
- **FR-027**: No blanket approval given earlier in the run MUST be read as covering any choice that discards work.
- **FR-028**: The run MUST confirm what actually happened to the workspace rather than trusting that the action it requested took effect, and MUST report it.

#### The review request's own option

- **FR-029**: Raising a review request MUST offer removing its source line of work once the change is accepted, as a choice in its own right, not conditional on any other setting about how the change is merged.
- **FR-029a**: This feature MUST change only the review-request workflow for the forge where the choice is currently welded to another setting. The other supported forge's workflow already offers it independently; that MUST be verified and the verification recorded, and that workflow MUST NOT otherwise be reworked for cosmetic alignment.
- **FR-030**: Where the repository already removes source lines of work by default, that MUST be reported rather than offered as a choice that changes nothing.
- **FR-031**: Bringing an existing review request up to date MUST NOT change this setting, consistently with the existing rule that such an update touches a fixed set of fields and no others.

#### What the repository gains

- **FR-032**: The repository MUST carry a written record of the researched standards and behaviour this feature rests on, in which every claim of fact names the source it came from and every question the sources do not settle is recorded as an open gap rather than answered by guess.
- **FR-033**: Any durable working rule that record establishes MUST be written exactly once, in the location this repository already uses for rules of that scope, and MUST NOT be duplicated into a second location.
- **FR-034**: The published record of what this repository distributes and how each part may be reached MUST be accurate once this feature is complete.
- **FR-035**: Where existing records point at a superseded record, those pointers MUST be corrected.

### Key Entities

- **Workspace arrangement**: how and where this run's work is happening — whether isolated or not, whether this run set it up, where it was started from, and what the closing question should therefore offer.
- **Stage outcome**: what each of the three stages recorded, taken from the stage's own report rather than from recollection, and the basis for every branch the run takes.
- **Shipping result**: what was committed, what the review request carries, where it is, and the reason for any step that did not run.
- **Finding carried back**: what validation recorded, in a form the assessment stage can receive when the maintainer chooses to return to it.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A maintainer can take one bug report from raw text to a raised review request without invoking any workflow by hand, in a single run.
- **SC-002**: 100% of runs that edit source files do so in a workspace the maintainer explicitly chose, with the choice made before the first stage runs.
- **SC-003**: 100% of the reports a successful run produces are committed by the time the review request is raised.
- **SC-004**: No run re-enters a stage, discards a line of work, or discards a workspace without the maintainer having chosen it in that run.
- **SC-005**: A maintainer whose first remediation fails validation can continue in the same run, without re-supplying the original bug report, for as many cycles as they choose, with the cycle count visible at every such choice.
- **SC-006**: Every step that does not run reports why, and no run reports success for an unresolved or partial result.
- **SC-007**: Every factual claim in the feature's written record names its source, and every unsettled question is recorded as an open gap.

## Assumptions

- The three triage stages themselves are unchanged; this feature adds what happens before the first and after the last, and the route between the last and the first.
- One run still handles exactly one bug report.
- Merging the review request is out of scope. The run's involvement ends once the request exists and the workspace question is answered.
- The workflows that own commits and review requests already exist and already gate their own decisions; this feature hands work to them rather than reimplementing any part of it.
- The forge is determined from the repository's own remote, not from what the maintainer says or what a previous run used.
- Reports written by earlier stages of an interrupted run remain on disk and are not rolled back.
