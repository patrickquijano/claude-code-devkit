# Feature Specification: Update an existing review request instead of refusing

**Feature Branch**: `007-forge-review-request-update`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Both forge review-request skills stop when the current branch already has an open review request, because each one only creates. Each skill must always establish whether the current branch already has a review request on its forge before it does anything else, and must be able to bring an existing one up to date instead of refusing."

## User Scenarios & Testing _(mandatory)_

The two skills in scope are the repository's GitHub pull-request skill and its GitLab merge-request skill. Throughout this specification, **review request** means whichever of the two the forge in question calls it, and **the skill** means whichever of the two is being run.

### User Story 1 - Re-running after amending the branch (Priority: P1)

Someone opens a review request, gets a comment, amends the branch, and runs the skill again to bring the review request in line with the new work. Today the skill establishes that a review request already exists and stops, because it can only create. The person is left to open the forge in a browser and edit the fields by hand — which is exactly the work they invoked the skill to avoid, and it is the second and every subsequent run, not the first, that this costs.

**Why this priority**: It is the failure that occurs on every repeat run, which is the majority of runs once a branch is under review. Without it, the skill is useful once per branch.

**Independent Test**: On a branch that already has one open review request, run the skill. It must reach an approval summary describing an update, and on approval the existing review request must carry the new values while its identifier and its comment history are unchanged. No second review request exists afterwards.

**Acceptance Scenarios**:

1. **Given** a branch with exactly one open review request, **When** the skill is run, **Then** it reports that review request's identifier and state and continues in update mode rather than stopping.
2. **Given** the skill is in update mode, **When** it reaches its approval summary, **Then** every field it would change is listed with its current value and its proposed value, and every field it would leave alone is either listed as unchanged or explicitly named as untouched.
3. **Given** the approval summary is displayed, **When** the user declines, **Then** nothing has been sent to the forge and the existing review request is byte-for-byte as it was.
4. **Given** the user approves, **When** the update is applied, **Then** the same review request identifier and URL are reported back, and no new review request has been created.

---

### User Story 2 - The description survives (Priority: P1)

A review request description is not disposable. It carries what the author wrote, what reviewers asked to be recorded there, and checklist items someone has ticked. Every mechanism available for updating a description on either forge replaces the whole field; none of them merges. A skill that regenerates the description and writes it is therefore a skill that silently destroys work, and it does so on the run the user thought was routine.

**Why this priority**: It is the only irreversible loss this feature can cause. Everything else a wrong update does can be undone by running it again correctly; a replaced description cannot be recovered from the forge.

**Independent Test**: Put a hand-written paragraph and a ticked checklist item into an existing review request's description, then run the skill and approve. The hand-written paragraph and the tick must still be there unless the user explicitly chose to replace them.

**Acceptance Scenarios**:

1. **Given** an existing review request whose description differs from what the skill would generate, **When** the skill reaches the description, **Then** it presents the difference and offers to leave it alone, replace it, or append to it — with leaving it alone as the default.
2. **Given** the user chooses to append, **When** the update is applied, **Then** the existing description text is unchanged and the new content is added below it in a delimited section.
3. **Given** a previous run already appended a section, **When** a later run appends again, **Then** the later run replaces its own previous section rather than accumulating a third copy, and text outside that section is untouched.
4. **Given** the user's invoking instruction contained a blanket instruction to skip confirmation, **When** the skill would replace a description that a person has written, **Then** it still asks, and says why the skip was not honoured.

---

### User Story 3 - A review request that is not open (Priority: P2)

The branch's review request may be closed or merged rather than open. These are different situations with different correct answers, and picking one silently is wrong in both directions: opening a second review request when the first was merely closed by accident abandons its review history, and trying to revive a merged one cannot work at all.

**Why this priority**: Less frequent than the open case but reached without warning, and the wrong choice loses review history that nobody can restore.

**Independent Test**: Close a review request, run the skill, confirm both options are offered. Merge a review request, run the skill on the same branch, confirm the skill says reopening is impossible and opens a new one after approval.

**Acceptance Scenarios**:

1. **Given** the branch has exactly one candidate and it is closed, **When** the skill runs, **Then** it offers reopening and updating it, or leaving it closed and opening a fresh one, and makes no change until the user picks.
2. **Given** the branch's candidates are all merged, **When** the skill runs, **Then** it states that reopening a merged review request is not possible on this forge, and continues towards creating a new one.
3. **Given** the branch has one open candidate and also closed or merged ones, **When** the skill runs, **Then** it goes into update mode against the open one and reports the others as present without offering them.
4. **Given** the branch has no review request in any state, **When** the skill runs, **Then** it behaves exactly as it does today and creates one.

---

### User Story 4 - Several candidates (Priority: P2)

A branch can carry more than one review request: several closed ones from earlier attempts, or on one forge two open ones aimed at different target branches. Choosing among them is the user's, not the skill's — a skill that picks the newest, or the first the forge returned, updates the wrong one without ever saying it had a choice.

**Why this priority**: Rarer than the single-candidate case, but silent when wrong, which makes it worse per occurrence.

**Independent Test**: Arrange two review requests for one branch, run the skill, confirm both are presented with enough detail to tell them apart and nothing is written before a pick.

**Acceptance Scenarios**:

1. **Given** the branch has more than one open candidate, or no open candidate and more than one in another state, **When** the skill runs, **Then** it lists each with its identifier, state, target branch and title, and asks which one to act on.
2. **Given** more candidates exist than the question can display, **When** the skill asks, **Then** it says how many were found and how many are shown.

---

### User Story 5 - Not rewriting history under a review (Priority: P2)

The skill brings the branch up to date with its target before raising a review request, which rewrites the branch's published history. On a first run nobody is looking at that history. On an update run, review comments may already be anchored to the commits being rewritten, and rewriting them detaches those comments from the code they were about.

**Why this priority**: It damages someone else's work rather than the user's own, and it is invisible until a reviewer returns to a thread that no longer points anywhere.

**Independent Test**: Add a review comment to an existing review request, run the skill in update mode, and confirm the branch's published history is unchanged and the skill said so.

**Acceptance Scenarios**:

1. **Given** an existing review request that already carries review activity, **When** the skill runs in update mode, **Then** it does not rewrite the branch's published history, and it reports that it did not, why, and what the user can do instead.
2. **Given** an existing review request with no review activity, **When** the skill runs in update mode, **Then** it brings the branch up to date exactly as it does when creating.
3. **Given** the skill skipped bringing the branch up to date, **When** it presents its approval summary, **Then** the skip and its reason appear in that summary rather than only in passing output.

---

### User Story 6 - Checking a claim without leaving the repository (Priority: P3)

Both skills encode a large number of specific claims about how the two forges and their command-line tools behave. Someone changing a skill has no way to tell a deliberate rule from a guess, so they either trust it or go and re-derive it from external documentation. The rules that matter most are the ones where the two forges differ, because a change that looks correct against one is wrong against the other.

**Why this priority**: It prevents future regressions rather than fixing a present failure, so it ranks below the behaviour changes — but it is what keeps them from being undone.

**Independent Test**: Pick three specific behavioural claims made in the changed skills, and find each one stated, with its source, in the repository's own documentation without opening a browser.

**Acceptance Scenarios**:

1. **Given** the repository after this feature, **When** a maintainer looks for the practice behind a rule in either skill, **Then** the documentation states it, cites where it came from, and names the tool version it was checked against.
2. **Given** a maintainer opens either skill for editing, **When** the durable authoring rules for these skills load, **Then** they load because the file being edited is in scope, not because a repository-wide instruction file grew.
3. **Given** the two forges behave differently on the same operation, **When** the documentation covers that operation, **Then** the difference is stated as a difference rather than described once and left to generalise.

### Edge Cases

- The branch has no review request at all — the existing create path runs unchanged, and this is the case that must not regress.
- The branch exists locally but not on the remote — the skill pushes it first, as it does today, before any detection can be meaningful.
- Detection cannot run because the forge tool is missing or unauthenticated — the skill stops for that reason, as it does today, rather than assuming there is no review request.
- The head branch of the existing review request is not the branch the user is on. The head of a review request cannot be changed after creation, so an existing review request whose head is a different branch is not this branch's review request and must not be updated.
- A review request was found and displayed, but was closed, merged or edited by someone else between the display and the approval. The values shown at approval were true when read.
- Nothing at all would change. Issuing an update that changes no field still produces activity on the forge that reviewers see.
- The user chooses to update a review request whose target branch differs from the target they selected in this run.
- The person running the skill lacks permission to edit the existing review request, though they could create a new one.
- A previous run's appended section has had one of its two markers deleted by a person editing the description around it.
- The description already contains the skill's marker text because a person pasted it there, or because the description was copied from another review request.

## Requirements _(mandatory)_

### Functional Requirements

#### Detection

- **FR-001**: Each skill MUST determine, before it does any work that a stop would waste, whether the current branch already has a review request on the forge.
- **FR-002**: Detection MUST cover open, closed and merged review requests, not open ones alone.
- **FR-003**: Detection MUST NOT treat a review request whose head is a branch other than the current branch as a candidate, even when the two branches share a name.
- **FR-004**: When detection cannot be performed, the skill MUST stop and say why, and MUST NOT continue as though no review request exists.

#### Choosing what to act on

- **FR-005**: Exactly one **open** candidate MUST put the skill into update mode against that candidate, whatever closed or merged candidates also exist. Those others MUST be reported as present and MUST NOT be offered as alternatives, because an open review request is unambiguously the live one for the branch.
- **FR-006**: More than one **open** candidate MUST be presented to the user with each candidate's identifier, state, target branch and title, and the skill MUST NOT choose for them. The same applies when there is no open candidate and more than one closed or merged candidate exists.
- **FR-007**: When the candidate list is longer than the question can show, the skill MUST state the total found and the number shown.
- **FR-008**: Exactly one candidate, closed, and no open candidate, MUST produce a choice between reopening and updating it, or leaving it closed and creating a new one.
- **FR-009**: Candidates that are all merged, with none open and none closed, MUST produce a statement that reopening a merged review request is not possible on that forge, and the skill MUST continue towards creating a new review request.
- **FR-010**: No candidate in any state MUST leave today's create behaviour unchanged.
- **FR-010a**: Detection MUST run after the branch is known to exist on the remote and before any work that a stop would waste, and MUST NOT be bounded to a time window or a number of recent review requests.

#### Updating

- **FR-011**: In update mode the skill MUST NOT create a second review request.
- **FR-012**: The skill MUST present, before anything is written, every field it would change with that field's current value and its proposed value. The fields in scope for an update are exactly: title, description, target branch, reviewers, assignees. No other attribute of an existing review request is within this feature's scope to change.
- **FR-012a**: The approval summary MUST state which mode the run is in, so that a reader can tell an update from a creation without inspecting the fields.
- **FR-012b**: The values presented for approval MUST be the values read during this run. Where the review request changed on the forge between being read and being approved, the skill MUST NOT silently apply the update against the newer state; it MUST re-read, report the difference, and ask again.
- **FR-013**: The skill MUST NOT write anything to the forge before the user approves that summary.
- **FR-014**: The description of an existing review request MUST default to being left as it is. Replacing it and appending to it MUST both be available, and both MUST be chosen by the user with the difference in front of them.
- **FR-015**: An appended section MUST be delimited by a begin marker and an end marker that name the skill that wrote them and are invisible when the description is rendered. A later run MUST replace the region between its own pair and leave every other part of the description untouched.
- **FR-015a**: When the two markers are not present as exactly one well-formed pair — one marker without its partner, or more than one pair — the skill MUST treat the region as not found, MUST report what it found, and MUST append a fresh delimited section. It MUST NOT infer a missing boundary from surrounding content and MUST NOT delete a region it did not write.
- **FR-016**: Reviewers and assignees MUST be added to those already on the review request. The skill MUST NOT replace the existing set as a side effect of adding to it.
- **FR-017**: Removing a reviewer or an assignee MUST be available as an explicit choice and MUST NOT occur as a consequence of naming a different set.
- **FR-018**: On an existing review request the skill MUST NOT change any attribute outside FR-012's five fields — in particular the draft or ready state and the merge options — even where the create path would have asked about it. A question the create path asks and the update path cannot act on MUST NOT be asked in update mode.
- **FR-018a**: A field within FR-012's five that the user selects during this run — the target branch being the case that arises — counts as the user asking for that change. Its default MUST be the value the existing review request already holds. A selection that differs MUST appear in the approval summary as a change with both values, and MUST NOT be applied on the strength of the selection alone.
- **FR-019**: When no field in FR-012's set would change, the skill MUST say so and MUST NOT issue an update that produces forge activity for no reason. Pushing the branch and bringing it up to date are governed by FR-021 to FR-024 and are unaffected by this requirement.
- **FR-020**: A blanket instruction to skip confirmation MUST NOT cover replacing a description that already contains content, removing a reviewer or an assignee, or changing the target branch of an existing review request. The skill MUST ask anyway and say why the skip was not honoured.
- **FR-020a**: Where the user can create a review request but lacks permission to edit the one that exists, the skill MUST report that specifically rather than presenting a generic failure, and MUST NOT fall back to creating a second review request without asking.

#### Published history

- **FR-021**: Before bringing the branch up to date with its target in update mode, the skill MUST establish whether the existing review request already carries review activity. **Review activity** means a submitted review, an approval, or a comment thread attached to a line of the diff. A plain conversation comment on the review request, and any comment written by automation, are not review activity, because neither is anchored to a commit and neither is detached by rewriting history.
- **FR-022**: Review activity present MUST suppress rewriting the branch's published history. The skill MUST report that it was suppressed and why, and MUST name at least these alternatives: letting the forge report any conflict on the review request itself, merging the target into the branch rather than replaying the branch onto it, and rewriting deliberately once the review threads are resolved.
- **FR-023**: No review activity MUST leave the existing bring-up-to-date behaviour unchanged.
- **FR-024**: A suppressed rewrite MUST appear in the approval summary, not only in transient output.

#### Documentation and rules

- **FR-025**: The repository MUST carry a single combined reference documenting GitHub pull-request practice, GitLab merge-request practice, and the two command-line tools that drive them. It is sufficient when every command and every flag either skill relies on appears in it, which is the condition SC-007 states and a reviewer can check by listing them.
- **FR-026**: That documentation MUST cite a source for each claim, and MUST state once, at the top, the exact version of each tool against which the whole document was verified. A claim that does not hold for that version MUST say so where it is made.
- **FR-027**: Where the two forges differ on the same operation, the documentation MUST state the difference in one place that names both forges, rather than describing one forge in one section and the other elsewhere.
- **FR-028**: The durable authoring rules drawn from that documentation MUST be recorded in a file that declares which paths it governs, and those paths MUST cover both skills' directories. They MUST NOT be added to an instruction file that every session loads regardless of subject.
- **FR-029**: Every statement elsewhere in the repository that this feature makes untrue MUST be corrected. The set is: each skill's stated exclusion of updating, each skill's stated boundary that it only creates, each skill's stop on finding an existing review request, and each skill's regression scenario asserting that no attempt is made to edit the existing one.

#### Preservation

- **FR-030**: Each of these existing guarantees MUST continue to hold, and they are the enumeration this requirement is checked against: questions are asked through the structured question mechanism and never in prose; a question carries at most four options and a call carries at most four questions; related questions are batched into one call rather than asked one per call; the recommended option comes first and carries its justification and the cost of not taking it; nothing is written to the forge before the approval gate returns yes; neither skill switches branch, changes directory, or acts on a working tree other than the one it was invoked in; and neither skill fabricates a branch, handle, team, or label that a live listing did not return.

#### Non-goals

Stated so that adjacent work is excluded rather than assumed. This feature does not:

- merge, close, reopen-and-merge, review, approve, or comment on a review request;
- change the draft or ready state of an existing review request, nor its merge options such as squashing or deleting the source branch on merge, nor its labels or milestone;
- arm or disarm automatic merging on a review request that already exists;
- add support for any forge beyond GitHub and GitLab;
- introduce a shared implementation, script, or abstraction between the two skills;
- change how either skill behaves when the branch has no review request, beyond FR-010a's placement of the detection step.

### Key Entities

- **Review request**: the forge's record of a proposed change from one branch into another. Identified by a number and a URL, and carrying a title, a description, a state, a draft flag, a target branch, assignees, reviewers, and a history of comments and reviews. Its head branch is fixed at creation.
- **Candidate**: a review request the skill has found whose head is the current branch. Zero, one or many exist.
- **Mode**: which of create or update the run is in. Decided by the candidates found and, where more than one answer is possible, by the user.
- **Review activity**: evidence that someone other than the author has engaged with the review request, used to decide whether the branch's published history may be rewritten.
- **Field change**: a single proposed difference between a candidate's current value and what this run would set, with the two values, presented for approval.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Running the skill a second time on a branch that already has an open review request produces an updated review request and no second one, in a single run and with no manual editing on the forge.
- **SC-002**: In every run that applies an update to an existing review request, the number of review requests for the branch after the run equals the number before it. Runs that create — no candidate, or a merged-only candidate — add exactly one.
- **SC-003**: No description content that a person wrote is lost in any run where the user did not explicitly choose to replace it — verified by comparing the description before and after.
- **SC-004**: No reviewer or assignee already on a review request is absent from it after a run in which the user did not explicitly remove them.
- **SC-005**: In every run against a review request that already carries review activity, the commit that was at the tip of the branch on the remote before the run is still reachable from the tip after it, and the run's summary states that the published history was left alone and why. New commits may be added on top; none of the existing ones is replaced.
- **SC-006**: Each of the branch states — no candidate, one open, several open, one closed with none open, several candidates none open, all merged — reaches an outcome stated in the requirements, and each can be exercised against the written scenarios without reading the skill's implementation.
- **SC-007**: Every claim either skill makes about what its forge tool does — each command it names and each flag whose behaviour it relies on — is stated in the repository's own documentation with a cited source and the tool version it was verified against.
- **SC-008**: The rules this feature adds are reachable when either skill is opened for editing, and the repository-wide instruction file gains no lines.

## Assumptions

- The two skills remain separate, with no shared implementation. The two forges differ enough on the operations this feature adds that a shared layer would have to be re-specialised at every call site.
- Update mode is a branch within each skill's existing workflow rather than a new skill, so a user needs to learn no new entry point and every existing guarantee continues to apply.
- The existing question style, option caps, and single approval gate are kept; this feature adds branches within that shape rather than a second style of interaction.
- "Review activity" is the diff-anchored kind only, per the Clarifications section. A branch whose review request carries nothing but conversation comments is still brought up to date exactly as it would be on a first run.
- Both forge command-line tools are already treated as required for their respective skill; this feature does not change that, and adds no new external dependency.
- The repository has no automated way to exercise either skill end-to-end against a live forge, so the written regression scenarios are the acceptance instrument, as they are for every existing skill here.

## Clarifications

### Session 2026-09-05

- Q: What counts as "review activity" — the thing whose presence stops the skill from rewriting the branch's published history? → A: Diff-anchored reviews only — submitted reviews, approvals, and comment threads attached to lines of the diff. Plain conversation comments and bot comments do not count, because they are not anchored to commits and survive a rewrite intact.
- Q: Is the required documentation one combined reference covering both forges, or one per forge? → A: One combined reference. FR-027 requires differences to be stated as differences, which a combined document does structurally where two separate ones can only cross-reference and drift.
- Q: How should an appended description section be delimited, so a later run can find and replace its own previous append? → A: A begin/end pair of HTML comments naming the skill. Both forges render Markdown, so the markers are invisible to readers. A surviving marker without its partner means the region is not found, and a fresh section is appended rather than a boundary guessed.
