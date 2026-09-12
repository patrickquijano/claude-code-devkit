# Feature Specification: Change-Request Review and Remediation

**Feature Branch**: `013-review-remediate`

**Created**: 2026-09-12

**Status**: Draft

**Input**: User description: "Maintainers of this plugin need a guided way to review the one open change request belonging to the current branch and, when they explicitly authorise it, to fix what that review found — without leaving the session and without the reviewer inventing anything it did not observe."

## Clarifications

### Session 2026-09-12

- Q: Is the five review/remediate cycle bound a hard limit within one invocation, or a default the user may raise when it is reached? → A: Raisable, asked at the bound — the run stops at five, states the remaining findings, and asks whether to continue with a stated further bound.
- Q: When the reviewing identity is the author, FR-019 already forbids approving; what happens to the findings themselves? → A: Publish as comments, never approve — the findings go to the change request, and no approval or request-changes verdict is recorded.
- Q: When the repository declares no validation commands at all, what does the validation pass-criterion do? → A: It fails, and the user may explicitly override it — an unchecked criterion is never reported as checked.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Review the open change request and publish findings (Priority: P1)

A maintainer is on a branch that has one open change request. They ask for it to be reviewed. The run works out which change request that is, gathers the facts a reviewer needs from the hosting platform and from the repository itself, reads the change without modifying anything, and produces a set of findings that each quote the evidence they rest on. It states a verdict — pass or fail — against criteria it can show. Where the reviewing identity is allowed to, it publishes that verdict to the change request: a request for changes with the findings attached, or an approval with a short positive summary.

**Why this priority**: This is the whole value on its own. A maintainer who never uses remediation or merging still gets a reviewed change request with evidence-backed findings published where the author will see them. Nothing later in the feature is reachable without it.

**Independent Test**: On a branch with exactly one open change request, invoke the run and confirm it identifies that change request, produces findings that each cite a location and quoted evidence, states a verdict against listed criteria, modifies no file in the working tree, and publishes the verdict to the change request when permitted.

**Acceptance Scenarios**:

1. **Given** a branch with exactly one open change request and a clean working tree, **When** the review runs, **Then** it reports the change request's author, assignees, reviewers, source and target branches, revision under review, automated-check status and mergeability before producing any finding.
2. **Given** a change request whose diff contains a defect the repository's own stated rules forbid, **When** the review runs, **Then** the finding names the rule, quotes the offending line with its location, states the impact and the outcome required, and carries a severity and a confidence.
3. **Given** a change request where every criterion is met, **When** the review runs, **Then** the verdict is pass and the published summary states which criteria were checked and how each was satisfied.
4. **Given** a finding that is already raised in an existing comment on the change request, **When** the review runs, **Then** that finding is not published a second time.
5. **Given** a branch with no open change request, **When** the run starts, **Then** it stops and says so, and reviews nothing.
6. **Given** a branch with more than one open change request, **When** the run starts, **Then** it stops, lists them, and reviews none of them without the user naming one.
7. **Given** a working tree with uncommitted changes, **When** the run reaches any step that would change a branch or a file, **Then** it stops before that step rather than changing anything.
8. **Given** a change request authored by the reviewing identity, **When** the review passes, **Then** the run does not approve it and says why.

---

### User Story 2 - Remediate what the review found (Priority: P2)

Having read the findings, the maintainer explicitly asks for them to be fixed and authorises changes to the source branch. The run works to a plan ordered by severity, fixes root causes without unrelated refactoring, adds or updates the tests that would have caught each defect, validates the result, inspects the final difference for anything it did not intend to change and for credentials, commits in the repository's own convention, and publishes a summary mapping every finding to how it was resolved.

**Why this priority**: It depends on findings existing, so it cannot precede User Story 1. It is the half of the feature that saves the most time, but a review alone is already useful and a remediation with no review is meaningless.

**Independent Test**: Given a completed review with at least one blocking finding, authorise remediation and confirm each finding is either fixed with a corresponding test change or explicitly reported as not fixed, that validation ran and its output is shown, and that nothing was pushed when validation failed.

**Acceptance Scenarios**:

1. **Given** unresolved findings and an explicit authorisation to modify the source branch, **When** remediation runs, **Then** it addresses findings in severity order and reports the order before starting.
2. **Given** a remediation that changes behaviour, **When** it completes, **Then** a regression test covering that behaviour was added or updated.
3. **Given** a remediation whose validation fails, **When** the run reaches the point where it would publish or transmit, **Then** it publishes nothing, transmits nothing, reports the failure with the validation output, and does not describe the work as successful.
4. **Given** a remediation whose final difference contains a change no finding called for, **When** the run inspects that difference, **Then** it reports the unintended change and does not transmit the work until the user decides.
5. **Given** a remediation whose final difference contains something shaped like a credential, **When** the run inspects that difference, **Then** it stops and reports the location without reproducing the value.
6. **Given** a completed remediation, **When** the summary is published, **Then** every finding identifier appears in it against the resolution, the files changed, the checks run and the resulting commit.
7. **Given** no explicit authorisation to modify the source branch, **When** the run finishes reviewing, **Then** it changes no file and makes no commit.

---

### User Story 3 - Re-review, then approve and merge the reviewed revision (Priority: P3)

After a remediation the maintainer wants the whole updated change examined again — not just the part that changed — to confirm the earlier findings are genuinely resolved and that the fixes introduced nothing new. When the result passes and the maintainer explicitly asks for it, the run merges, but only the exact revision it reviewed, and only with merge options the maintainer chose.

**Why this priority**: It is the least of the three in isolation — a maintainer can merge by hand — and it carries the most risk, so it is the right thing to defer when scope must be cut.

**Independent Test**: After a remediation, confirm the re-review examines the full change against its target rather than only the remediation diff, re-checks each earlier finding by identifier, re-runs validation, and that a merge is refused when the revision has moved since the review.

**Acceptance Scenarios**:

1. **Given** a completed remediation, **When** the re-review runs, **Then** it examines the entire change against its target branch and reports the status of every earlier finding by identifier.
2. **Given** a re-review that finds a defect introduced by the remediation, **When** it reports, **Then** that defect is recorded as a new finding with its own identifier rather than folded into the finding whose fix caused it.
3. **Given** review and remediation alternating without reaching a pass, **When** the cycle limit is reached, **Then** the run stops, states which findings remain, and does not begin another cycle.
4. **Given** a passing re-review and an explicit request to merge, **When** the run prepares to merge, **Then** it asks once, in a single question accepting more than one answer, which of the hosting platform's merge options to apply.
5. **Given** a merge request where the revision has changed since the review, **When** a merge is requested, **Then** the run refuses, reports the revision it reviewed and the revision now current, and does not merge.
6. **Given** a merge that the hosting platform's own protections would block, **When** a merge is requested, **Then** the run reports the blocking protection and does not attempt to bypass or force it.
7. **Given** a completed merge, **When** the run finishes, **Then** it confirms the outcome at the hosting platform, moves to the target branch and brings it up to date without rewriting history.

---

### User Story 4 - Preview every action without taking any (Priority: P3)

A maintainer who has not used the run before, or who is pointing it at an unfamiliar repository, asks it to report what it would do instead of doing it. Every action that would reach the hosting platform, the working tree or the remote is described and none is performed.

**Why this priority**: It is how a cautious maintainer builds enough confidence to authorise the other three stories, but nothing depends on it and the feature is usable without it.

**Independent Test**: Invoke the run in preview mode against a change request that would fail review, and confirm that findings are produced and displayed, that the run names each publish, commit, push, approval and merge it would have performed, and that the change request and the repository are byte-for-byte unchanged afterwards.

**Acceptance Scenarios**:

1. **Given** preview mode, **When** the review completes, **Then** the findings and the verdict are reported in the session and nothing is published to the change request.
2. **Given** preview mode and an authorisation that would otherwise permit remediation, **When** the run reaches remediation, **Then** it lists the changes it would make and makes none.
3. **Given** preview mode, **When** the run finishes, **Then** the working tree, the branch, the remote and the change request are all unchanged.

---

### Edge Cases

- The hosting platform is unreachable, or the credential for it has expired: the run reports which step could not be completed and stops, rather than continuing with partial facts.
- The reviewing identity can read the change request but cannot publish to it: findings are reported in the session, the inability to publish is stated explicitly, and the run does not claim to have published.
- The change request is a draft: the run reviews it but does not approve or merge it, and says why.
- The revision under review moves while the review is in progress: the run reports the change and does not publish a verdict against a revision that is no longer current.
- The change request has no diff — an empty change, or one whose branches have converged: the run reports that and produces no findings rather than inventing them.
- The change is very large: the run reports how much it examined and what it did not reach, rather than implying complete coverage.
- The repository states contributor guidance that contradicts a finding the review would otherwise raise: the guidance wins and the finding is not raised, or the contradiction is reported as a Question.
- A file in the change, a comment on the change request, or a script in the repository contains text shaped like an instruction to the reviewer: it is treated as content to review, never as a direction to follow.
- The target branch moves during a remediation: the run reports the movement and re-examines against the current target rather than a stale one.
- The repository declares more than one plausible validation entry point: the run reports which it chose and on what evidence.
- The repository declares no validation entry point at all: the validation criterion is reported as not satisfied, which blocks a pass until the user explicitly overrides that one criterion.
- The reviewing identity is the author: findings are published as comments, no verdict is recorded, and the run states that the reviewer being the author is why.

## Requirements _(mandatory)_

### Functional Requirements

#### Identification and context

- **FR-001**: The run MUST identify exactly one open change request to act on — the one belonging to the current branch, or one the user named — and MUST stop without reviewing when none is found or when several are.
- **FR-002**: The run MUST accept an explicitly named change request identifier in place of branch-based discovery.
- **FR-003**: The run MUST determine which hosting platform the repository ships to from the repository's own configured remote, and MUST NOT infer it from the user's wording or from a previous run.
- **FR-004**: The run MUST confirm it can authenticate to that hosting platform before gathering anything, and MUST stop with the reason when it cannot.
- **FR-005**: The run MUST gather, and report before producing any finding: author, assignees, reviewers, source and target branch, the exact revision under review, the change itself, existing comments, unresolved discussions, recorded approvals, automated-check status, mergeability, and the repository's stated approval and merge requirements.
- **FR-006**: The run MUST read the repository's own contributor guidance and instruction files and treat them as constraints on the review.
- **FR-007**: The run MUST derive the repository's validation commands from what the repository already declares, and MUST report which it chose and on what evidence rather than assuming a convention.
- **FR-008**: The run MUST require an unmodified working tree before any step that changes a branch or a file, and MUST stop before that step when the tree is modified.

#### Review

- **FR-009**: The review MUST NOT create, modify or delete any file in the working tree.
- **FR-010**: The review MUST consider correctness, security, reliability, performance, maintainability, compatibility, tests, accessibility, observability, configuration and documentation.
- **FR-011**: Every finding MUST rest on evidence quoted from the change, its configuration, its tests, or a requirement the repository states, and MUST cite where that evidence is.
- **FR-012**: The run MUST NOT report a finding that rests on speculation, that duplicates a finding already raised on the change request, or that expresses a style preference the repository does not state.
- **FR-013**: Every finding MUST carry an identifier, a severity, a confidence, a category, a location where one exists, the evidence, the impact, the outcome required of the author, a suggested remediation, and how to validate that remediation.
- **FR-014**: Severity MUST be one of exactly six values — Critical, High, Medium, Low, Suggestion, Question — of which the first four are blocking and the last two are not.
- **FR-015**: The review MUST pass only when every one of these holds: no blocking finding is unresolved; the repository's validation passes; the hosting platform's automated checks pass; discussions that block are resolved; the revision reviewed is still the current one; and the repository's approval and merge requirements are met. The run MUST report each criterion's status individually, and MUST mark a criterion it could not check as not satisfied rather than as satisfied.
- **FR-016**: Where permitted, the run MUST publish a request for changes carrying the findings when the review fails, and an approval with a concise positive summary when it passes.
- **FR-017**: The run MUST prefer a comment attached to the specific location a finding concerns over a comment on the change request as a whole, where the hosting platform supports it and the finding has a location.
- **FR-018**: The run MUST assign the author to the change request only when it has no assignee, and MUST add the reviewing identity as a reviewer only when that identity is eligible and is not the author.
- **FR-019**: The run MUST NOT approve a change request authored by the reviewing identity, and MUST state that this is why when a review of such a change request passes.
- **FR-020**: Where the reviewing identity lacks the permission to publish, the run MUST report the findings in the session, state the missing permission, and MUST NOT report that it published.

#### Remediation

- **FR-021**: Remediation MUST run only on an explicit request that also authorises modifying the source branch, and MUST otherwise leave every file unchanged.
- **FR-022**: Remediation MUST work to a plan ordered by severity and MUST report that order before changing anything.
- **FR-023**: Remediation MUST fix root causes with the smallest change that resolves the finding, and MUST NOT refactor code no finding concerns.
- **FR-024**: Remediation MUST add or update a regression test for each behavioural change it makes.
- **FR-025**: Remediation MUST run validation scoped to what it changed, then the repository's full applicable validation, and MUST show the actual output of each rather than describing it.
- **FR-026**: Remediation MUST inspect the final difference for changes no finding called for, and MUST report any it finds and stop before transmitting.
- **FR-027**: Remediation MUST inspect the final difference for credentials and secret material, and on finding any MUST stop and report the location without reproducing the value.
- **FR-028**: Remediation MUST commit in the repository's own stated convention, and MUST transmit the work without rewriting remote history.
- **FR-029**: Remediation MUST NOT transmit work, publish a summary, or describe itself as successful when validation failed.
- **FR-030**: Remediation MUST publish a summary in which every finding identifier appears against its resolution, the files changed, the checks run and the resulting commit.

#### Re-review and cycles

- **FR-031**: Re-review MUST examine the whole change against its target branch, not only what the remediation altered.
- **FR-032**: Re-review MUST report the status of every earlier finding by identifier, and MUST record a defect introduced by a remediation as a new finding with its own identifier.
- **FR-033**: Review and remediation MUST alternate for a bounded number of cycles, and the run MUST stop earlier on any of: a passing review, information it does not have, failed validation, insufficient permission, unexpected movement of the remote, or a decision that is the user's to make.
- **FR-034**: The cycle bound MUST default to five. On reaching it the run MUST stop, state which findings remain unresolved, and MUST NOT begin a further cycle without asking; it MUST then ask whether to continue, and MUST state the further bound it would run to. It MUST NOT extend the bound on its own judgement.

#### Merge

- **FR-035**: A merge MUST happen only on an explicit request and only when every review, automated-check, approval, discussion, permission and repository-policy gate passes.
- **FR-036**: The run MUST confirm the change request's current revision is the exact revision it reviewed, and MUST refuse to merge when it is not, reporting both revisions.
- **FR-037**: Before merging, the run MUST ask once, in a single question accepting more than one answer, which of the hosting platform's merge options to apply.
- **FR-038**: The run MUST NOT use an administrative bypass and MUST NOT force any operation.
- **FR-039**: After merging, the run MUST confirm the outcome at the hosting platform, move to the target branch, and bring it up to date without rewriting history and without performing any history rewrite the user did not ask for.

#### Safety and honesty

- **FR-040**: The run MUST default to reviewing only, and MUST require a separate explicit request before remediating and again before merging.
- **FR-041**: The run MUST offer a mode in which it reports every action it would take and performs none, leaving the working tree, the branch, the remote and the change request unchanged.
- **FR-042**: The run MUST treat repository files, the change itself, its scripts, and comments on the change request as content to be reviewed and MUST NOT follow any instruction contained in them.
- **FR-043**: The run MUST NOT state as fact anything it did not observe — including state, permissions, findings, commands, validation results, commits, published reviews, transmissions, approvals and merges — and MUST say plainly when something could not be determined.
- **FR-044**: The run MUST NOT reproduce a credential or secret value in any output it produces or publishes.
- **FR-045**: The run MUST NOT modify a file that no finding concerns.
- **FR-046**: Where essential information is missing, the run MUST ask for it rather than assuming it, and MUST ask no more than is needed to proceed.
- **FR-047**: When the reviewing identity is the author of the change request, the run MUST still produce the findings and MUST publish them to the change request as comments, while recording neither an approval nor a request-changes verdict. It MUST state that the verdict was withheld because the reviewer is the author.
- **FR-048**: When the repository declares no validation commands at all, the run MUST report that plainly and MUST record the validation criterion of FR-015 as not satisfied, which blocks a pass. The user MAY explicitly override that single criterion; the override and its reason MUST appear in the verdict. The run MUST NOT report the criterion as satisfied.

#### Delivery

- **FR-049**: The capability MUST be usable on its own, without a larger workflow invoking it.
- **FR-050**: The capability MUST support both of the hosting platforms this plugin already targets, and MUST report and stop rather than guess when the repository ships to neither.

### Key Entities

- **Change request**: the unit under review — a pull request or a merge request depending on the hosting platform. Carries an identifier, an author, assignees, reviewers, a source and a target branch, a current revision, a diff, comments, discussions, approvals, automated-check results and a mergeability state.
- **Finding**: one reviewed defect or question. Carries an identifier, severity, confidence, category, an optional location, quoted evidence, an impact, a required outcome, a suggested remediation, a validation method, and a status that is open, fixed or explicitly not fixed.
- **Review verdict**: pass or fail, together with the individual status of each of the criteria in FR-015.
- **Remediation record**: the mapping from each finding identifier to its resolution, the files changed, the checks run and the commit that carried it.
- **Cycle**: one review-then-remediate pass, numbered, bounded, and ending in a verdict or a stated stopping reason.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: On a branch with exactly one open change request, a maintainer obtains a complete set of evidence-backed findings and a stated verdict in a single invocation, with no manual gathering of change-request facts.
- **SC-002**: Every published finding cites a location and quoted evidence; a reviewer auditing a completed run finds zero findings that cite neither.
- **SC-003**: Across runs against change requests with no defects, zero findings are published — the run reports a pass rather than manufacturing something to say.
- **SC-004**: A maintainer can determine, from the run's own output alone, which of the six pass criteria in FR-015 were met and which were not, without consulting the hosting platform.
- **SC-005**: No invocation modifies a file, produces a commit, transmits work, publishes an approval, or merges without an explicit request from the user covering that specific action.
- **SC-006**: In preview mode, a byte-for-byte comparison of the working tree and a fetch of the change request before and after the run show no difference.
- **SC-007**: Every remediation that changes behaviour is accompanied by a test change; a maintainer auditing a completed remediation finds zero behavioural changes with no corresponding test.
- **SC-008**: Zero remediations that failed validation result in a transmission, a published summary, or a claim of success.
- **SC-009**: Zero merges occur against a revision other than the one reviewed.
- **SC-010**: Every one of the run's stopping conditions — no change request, several change requests, failed authentication, modified working tree, missing permission, moved revision, cycle bound reached — produces a stop with a stated reason rather than a guess or a partial action.
- **SC-012**: Zero verdicts report a pass-criterion as satisfied when the run did not check it; a maintainer auditing any verdict finds every criterion marked satisfied, not satisfied, or explicitly overridden with a recorded reason.
- **SC-011**: A maintainer new to the capability can complete a review and understand the verdict without reading anything beyond the run's own output.

## Assumptions

- The default mode is review-only. Remediation and merging each require their own explicit request; a review that completes may offer to continue, but never continues without an explicit answer. This follows the stated requirement that each run only when explicitly requested, and resolves the ambiguity about whether one invocation may span all three stages.
- "The reviewing identity" means whichever account the run is authenticated as at the hosting platform, which may or may not be the maintainer operating the session.
- The repository being reviewed is the one the session is working in; reviewing a change request in a different repository is out of scope.
- Both hosting platforms expose, through their own supported interfaces, everything FR-005 requires. Where one does not expose a particular fact, that fact is reported as undetermined rather than substituted.
- Validation is whatever the repository itself declares; this feature defines no validation of its own and introduces no new test framework.
- Findings are produced by reading the change; no separate static-analysis tooling is introduced by this feature beyond what the repository already runs.
- The cycle bound defaults to five and is raisable only by an explicit answer at the moment it is reached, per FR-034.

## Out of Scope

- Reviewing a change request on a branch other than the current one, unless the user names its identifier.
- Reviewing more than one change request in a single run.
- Authoring the change request, or writing or editing its title and description.
- Managing labels, milestones, or planning boards on the change request.
- Running unattended, with no user present to answer the questions the run must ask.
- Reviewing a change request in a repository other than the one the session is working in.
- Introducing new analysis, testing or formatting tooling into the repository under review.
