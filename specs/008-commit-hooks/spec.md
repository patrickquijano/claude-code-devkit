# Feature Specification: Commit Message and Signature Enforcement

**Feature Branch**: `008-commit-hooks`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "Contributors to this repository need every commit they produce to meet the repository's stated message convention and to carry a verifiable authorship signature, enforced automatically rather than by review, so that a malformed or unattributable commit is caught by the contributor before it reaches the shared remote."

## Clarifications

### Session 2026-09-05

- Q: Does the 72-character limit apply to the first line of the message only, to every line of the message, or to the message as a whole? → A: First line only. Body and trailer lines are unconstrained.
- Q: Which commit types are permitted, and is a scope qualifier required, optional, or forbidden? → A: The Angular type set — build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test — with a scope qualifier optional.
- Q: Should the send also be refused when a signature is present but cannot be verified against a known key, or only when a signature is absent? → A: Refuse only an absent signature or a bad one. A signature that is present but unverifiable is accepted.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Message convention enforced locally (Priority: P1)

A contributor writes a commit message. Before the commit is recorded, the message is checked against the repository's stated convention. A message that breaks the convention is refused, and the refusal names the rule that was broken and shows the text that broke it. A conforming message is recorded with no interruption.

**Why this priority**: It is the only story that changes what enters the repository's history. Every other story either protects that history at a later point, describes it, or reviews something else. Shipped alone it already delivers the feature's core value: a history whose messages are uniformly readable and machine-parsable.

**Independent Test**: Attempt three commits — one with a non-conforming subject, one with an over-length subject, one conforming — and confirm the first two are refused with a rule-naming message and the third succeeds.

**Acceptance Scenarios**:

1. **Given** the checks are active, **When** a contributor commits with a subject that does not match the convention, **Then** the commit is refused and the refusal names the convention rule and reproduces the offending subject.
2. **Given** the checks are active, **When** a contributor commits with a subject longer than the stated limit, **Then** the commit is refused and the refusal states the limit and the measured length.
3. **Given** the checks are active, **When** a contributor commits with a conforming message, **Then** the commit is recorded and nothing is printed that could be mistaken for a warning.
4. **Given** the checks are active, **When** a contributor deliberately bypasses the check by the documented emergency route, **Then** the commit is recorded and the bypass is the contributor's recorded choice rather than a silent skip.

---

### User Story 2 - Unsigned work stopped before it is shared (Priority: P2)

A contributor sends commits to the shared remote. Every commit in the outgoing range is examined for a verifiable authorship signature. If any lacks one, the send is refused and the contributor is told which commits are at fault and what to do about them. No commit that already exists is altered by this check.

**Why this priority**: It protects attribution at the last moment the contributor can still act cheaply, and it is second because an unsigned commit is a recoverable problem where a malformed history is not. It depends on nothing in Story 1.

**Independent Test**: Produce one signed and one unsigned commit on a branch, attempt to send, and confirm the send is refused naming only the unsigned commit; re-attempt with all commits signed and confirm the send proceeds.

**Acceptance Scenarios**:

1. **Given** an outgoing range containing at least one commit with no verifiable signature, **When** the contributor sends, **Then** the send is refused and every offending commit is listed by its short identifier and subject.
2. **Given** an outgoing range in which every commit carries a verifiable signature, **When** the contributor sends, **Then** the send proceeds unmodified.
3. **Given** any outgoing range, **When** the check runs, **Then** no existing commit's identifier, content, message or signature is altered by it.
4. **Given** a refused send, **When** the contributor reads the refusal, **Then** it states the action that would make the commits acceptable.

---

### User Story 3 - Enforcement works on a fresh clone (Priority: P1)

A contributor clones the repository and installs no additional tooling. One documented command, run from the repository root, activates both checks. Running it again changes nothing. The contributor can determine at any time whether the checks are currently active.

**Why this priority**: Equal to Story 1, because a check that only runs for contributors who first performed a setup ritual with extra tooling is a check that silently stops running — which is the failure the repository's governing principles exist to prevent. Stories 1 and 2 have no value they can be relied on for without it.

**Independent Test**: In a clone with no additional tooling installed, run the activation command and confirm both checks then fire; run it a second time and confirm it reports no change; run the state query and confirm it reports the checks active.

**Acceptance Scenarios**:

1. **Given** a freshly cloned repository with no additional tooling installed, **When** the contributor runs the documented activation command from the repository root, **Then** both checks become active without any language package manager, virtual environment or dependency install step being required.
2. **Given** the checks are already active, **When** the activation command is run again, **Then** it completes successfully and reports that nothing changed.
3. **Given** any state, **When** the contributor asks whether the checks are active, **Then** the answer is available from the documented command's own output rather than by inspecting the repository's internals.
4. **Given** a contributor who does have the optional third-party hook manager installed, **When** they use it instead, **Then** the same checks run and the behaviour is identical.

---

### User Story 4 - The conventions are written down where they are read (Priority: P3)

The commit convention, the length limit, the signature requirement, the activation command and the emergency bypass routes are recorded in the repository's public documentation, and the same rules are recorded in its agent-facing instruction files, scoped so they load when the relevant files are open. A human contributor and an automated agent are held to the same rule from the same source.

**Why this priority**: The checks work without it, but an enforced rule nobody can read is a rule contributors discover only by being refused. It is third because it documents behaviour that must exist first.

**Independent Test**: Read the documentation cold and confirm a contributor could activate the checks, satisfy them and bypass them in an emergency without reading any script.

**Acceptance Scenarios**:

1. **Given** the public documentation, **When** a contributor reads it, **Then** it states the convention, the limit, the signature requirement, the activation command and each bypass route with the circumstances under which each is legitimate.
2. **Given** the agent-facing instruction files, **When** an agent opens a file the rules govern, **Then** the rules load for that file and not for unrelated ones.
3. **Given** both records, **When** they are compared, **Then** they state the same convention and limit, with the reasoning held in one place rather than duplicated.

---

### User Story 5 - The toolkit's own skills reviewed (Priority: P3)

Maintainers need the defects, risks and improvement opportunities in this repository's distributed skills identified with evidence, presented with options and a justified recommendation, and only the approved ones applied.

**Why this priority**: It is independent of the commit checks entirely and delivers value on its own, but it improves an existing working system rather than closing a gap.

**Independent Test**: Produce the enumerated findings with evidence and options, obtain a decision on each, and confirm that the repository changed in exactly the ways approved and in no other way.

**Acceptance Scenarios**:

1. **Given** the distributed skills, **When** the review completes, **Then** every finding is stated with the evidence that supports it, located precisely enough to check.
2. **Given** a finding, **When** it is presented, **Then** it carries at least two options with their costs, a stated recommendation and the justification for that recommendation.
3. **Given** a presented finding, **When** no approval is given, **Then** nothing in the repository changes on account of it and the finding is recorded as declined.
4. **Given** an approved finding, **When** the work completes, **Then** the change was applied and is attributable to that finding.

---

### Edge Cases

- A commit message produced by the tooling rather than the contributor — a merge, a revert, a fixup or a squash — is exempt from the format and length rules, because its shape is fixed by the tool that wrote it and refusing it would block an operation the contributor cannot reword.
- An outgoing range that deletes a branch, or that contains no new commits, has nothing to check and the send proceeds.
- A commit that is already present on the remote is outside the outgoing range and is not re-examined, so a rule introduced today does not retroactively refuse yesterday's history.
- A contributor who has never configured a signing identity is told what is missing rather than being shown a verification failure they cannot interpret.
- The checks are inactive because activation was never run: this state is reported when asked, and it is not silently indistinguishable from a passing check.
- A message whose first line conforms but whose body contains lines over 72 characters — a URL, a pasted stack frame, a long trailer — is accepted, because the length rule governs the first line alone.
- A commit signed correctly by a contributor who has configured no allowed-signers list reports as unverifiable rather than good, and is accepted; only an absent or failing signature refuses the send.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The system MUST examine every commit message at the moment the commit is created and refuse the commit when the message does not satisfy the repository's stated convention.
- **FR-002**: The system MUST refuse a commit whose first message line exceeds 72 characters. Lines after the first — body and trailers — MUST NOT be length-checked.
- **FR-003**: Every refusal MUST name the rule that was broken and reproduce the value that broke it, including the measured length where a length rule was broken.
- **FR-004**: The permitted set of message categories, the scope policy and the length limit MUST be recorded in one committed location that both the check and the documentation draw from. The permitted categories are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style` and `test`; a scope qualifier is optional; a category outside the set MUST be refused.
- **FR-004a**: The system MUST accept a message whose first line is a well-formed category, an optional parenthesised scope, an optional `!` breaking-change marker, a colon, a space, and a non-empty description; and MUST refuse one that is not.
- **FR-005**: The system MUST exempt machine-generated commit messages — merge, revert, fixup and squash — from the format and length rules.
- **FR-005a**: A reverting commit MUST be acceptable in either shape: the generated form the tooling writes, which FR-005 exempts, or a hand-written message using the `revert` category, which satisfies FR-004a like any other. The two reach acceptance by different routes and neither excludes the other.
- **FR-006**: The system MUST examine every commit in an outgoing range before it is sent to the shared remote and refuse the send when any of them carries no signature at all, or carries a signature that fails validation. A signature that is present and structurally valid but cannot be checked against a known key — the ordinary state when a contributor has configured signing but no allowed-signers list — MUST be accepted.
- **FR-007**: A refused send MUST list every offending commit by short identifier and subject, and MUST state the action that would make them acceptable.
- **FR-008**: The system MUST NOT alter, amend, re-sign, reorder or otherwise rewrite any commit that already exists.
- **FR-009**: The system MUST provide a single command, runnable from the repository root with no arguments, that activates both checks.
- **FR-010**: Activation MUST NOT require a language package manager, a virtual environment, or any dependency install step.
- **FR-011**: The activation command MUST be idempotent and MUST report what it changed and what was already in place.
- **FR-012**: The activation command MUST arrange for commits to be signed at the moment they are created, so that the outgoing check has nothing to refuse under normal use.
- **FR-013**: A contributor MUST be able to determine whether the checks are currently active from the activation command's own output.
- **FR-014**: Both checks MUST exit non-zero whenever any rule was broken, and MUST NOT report success in that case. Reporting every violation found within a single check before exiting is required where the requirements say so — FR-007 for the outgoing range — and is not a departure from failing fast, which governs whether a later check runs after an earlier one failed, not whether one check finishes enumerating what it found.
- **FR-015**: Each check MUST remain bypassable by the documented emergency route, and each bypass route MUST be documented alongside the circumstances under which using it is legitimate.
- **FR-016**: The repository's public documentation MUST record the convention, the limit, the signature requirement, the activation command, the state query and every bypass route.
- **FR-017**: The repository's agent-facing instruction files MUST record the same rules, scoped so they apply when the governed files are open and not otherwise.
- **FR-018**: The two records MUST NOT restate each other's reasoning; the reasoning MUST live in one of them and be referenced from the other.
- **FR-019**: Every defect, risk and improvement opportunity found in the repository's distributed skills MUST be enumerated with locating evidence.
- **FR-020**: Each such finding MUST be presented with at least two options, their costs, a recommendation and the justification for it, and MUST NOT be acted on without explicit approval.
- **FR-021**: A finding that is not approved MUST be recorded as declined and MUST leave the repository unchanged.

### Key Entities

- **Commit message convention**: the eleven permitted categories, the optional-scope policy and the 72-character first-line limit that together decide whether a message is acceptable. Held in one committed location; read by the check and by the documentation.
- **Outgoing range**: the set of commits a send would add to the shared remote. Derived per send; the unit the signature check operates on.
- **Activation state**: whether the checks are currently in force for this working copy. Queryable; changed only by the activation command.
- **Skill review finding**: a single identified defect, risk or improvement in a distributed skill, carrying its evidence, its options, its recommendation and its final disposition of approved or declined.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of commits added to the repository after activation satisfy the stated convention and length limit, measured over the branch's own history.
- **SC-002**: 100% of commits sent to the shared remote after activation carry a verifiable signature.
- **SC-003**: A contributor with a fresh clone and no additional tooling can activate both checks in one command and under one minute.
- **SC-004**: Every refusal a contributor sees identifies the broken rule and the offending value, so that no contributor needs to read a script to understand why their commit or send was refused.
- **SC-005**: Re-running activation on an already-active clone reports no change and alters nothing, verified on a second consecutive run.
- **SC-006**: Zero pre-existing commits are altered by the feature, verified by comparing commit identifiers before and after a send that the check refused and then permitted.
- **SC-007**: Every finding raised against the distributed skills reaches a recorded disposition of applied or declined, with none left open.

## Assumptions

- "Signed" means a cryptographic authorship signature that the version control system itself can verify, not a textual trailer asserting authorship. This follows from the repository owner's existing configuration, in which commits are already signed at creation.
- Machine-generated messages — merge, revert, fixup and squash — are exempt from the format and length rules, per FR-005. This is the near-universal convention among commit-message checkers and no reasonable alternative default exists: the shapes of these messages are fixed by the tool that writes them.
- The convention referred to throughout is the Conventional Commits convention, named by the requester. Its permitted categories were settled in clarification as the Angular set, with an optional scope, because that is what the repository's existing history already uses: both scoped and unscoped commits are present on the default branch, so requiring a scope or forbidding one would retroactively invalidate part of it.
- Accepting a present-but-unverifiable signature is a deliberate trade. It admits a commit whose signer cannot be confirmed against a key list, and in exchange it does not block contributors who sign correctly but keep no allowed-signers list — which is the default state. Confirming signers against a key list is a separate control, not this feature's.
- Enforcement is local to each contributor's working copy. Server-side and continuous-integration enforcement are non-goals, so the guarantee is "caught before it is shared", not "impossible to introduce".
- The repository's existing quality-gate scripts, documentation conventions and agent instruction files are the ones this feature extends; it introduces no parallel structure alongside them.
- Contributors have a signing identity available, or are willing to configure one. The feature reports its absence clearly but does not issue, distribute or rotate keys.

## Non-Goals

- Enforcing the convention on the server side or in continuous integration.
- Rewriting, amending or re-signing any commit that already exists.
- Validating commit message bodies for content beyond the stated format and length rules.
- Issuing, distributing or rotating signing keys.
- Enforcing anything on branches that have already been pushed.
