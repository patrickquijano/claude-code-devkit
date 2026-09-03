# Feature Specification: Format on modification, and one exclusion declaration per check

**Feature Branch**: `004-format-hook-scope`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: automatic formatting of files modified during an agent session, and a single per-check declaration of excluded paths

## Clarifications

### Session 2026-09-03

- Q: Should "modified during an agent session" cover files rewritten by a shell command the session ran, or only files the session edited directly? → A: Direct edits only. Files a shell command rewrites stay covered by the repository's existing whole-repository check, which the constitution already requires before review.
- Q: Should this apply to files modified by a subagent working on the session's behalf, as well as the main session? → A: Include subagents, with no difference in behaviour between them.
- Q: When a formatting tool cannot run at all — neither installed natively nor available as the pinned container — what should happen? → A: Report it plainly once, naming the missing tool and the container that would have run in its place, and continue without failing the modification.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - A modified file is already formatted (Priority: P1)

A contributor working with an agent in this repository asks for a change to a document or a script. The agent makes the change. Without anyone running a formatting command, the file that was changed is already in conformance with the standards this repository holds it to by the time the change is reported as done. If the file is one the repository does not hold to a rewriting standard, or one it excludes from its checks, nothing happens to it and nothing is reported as wrong.

**Why this priority**: This is the value the feature exists for. Today conformance depends on somebody remembering to run the repository's own check, and the failure mode is a review round-trip about whitespace rather than about the change. It is also the half that makes the rest worth doing.

**Independent Test**: Modify one Markdown file so it is deliberately non-conformant, in a session where the behaviour is active. Confirm the file is conformant afterwards without any separate command having been run, and that no other file in the repository changed.

**Acceptance Scenarios**:

1. **Given** a Markdown file the repository holds to a rewriting standard, **When** an agent modifies it into a non-conformant state, **Then** the file is conformant once the modification completes, and no other file has changed.
2. **Given** a file kind the repository has no rewriting standard for, **When** an agent modifies it, **Then** the file is byte-identical to what the agent wrote, and the outcome is reported as "no standard applies" rather than as an error.
3. **Given** a file on a path the repository excludes from its quality checks, **When** an agent modifies it, **Then** the file is byte-identical to what the agent wrote.
4. **Given** a file that an agent has just deleted, **When** the modification completes, **Then** nothing is written anywhere and no failure is reported.
5. **Given** a path that resolves outside this repository, **When** it is offered for formatting, **Then** nothing outside the repository is read or written and no failure is reported.
6. **Given** a file whose content is not text, **When** an agent modifies it, **Then** the file is byte-identical to what the agent wrote.
7. **Given** a file that a standard has just rewritten, **When** that rewrite lands on disk, **Then** it does not cause formatting of that file to be attempted again.
8. **Given** a standard that fails while formatting a file, **When** it fails, **Then** the session is told which file it was, which standard failed, and what the standard itself reported, in enough detail to diagnose the cause, correct it, and try again.
9. **Given** a standard that rewrites a file, **When** it runs, **Then** the contributor can see which file was processed and under which standard.

---

### User Story 2 - An excluded path is declared once (Priority: P2)

A contributor needs to hold a new directory out of the repository's quality checks. They edit the configuration of each check that should skip it, and that is the whole of the work. There is no separate central list to update in step, and no check that fails because two declarations disagree. A contributor who runs one of the tools by hand, outside the repository's own runner, gets the same exclusions the runner applies, because both read the same declaration.

**Why this priority**: Real but secondary to Story 1. Today the same list exists in six places and a seventh check exists only to detect divergence between them, so adding one excluded path is six edits and forgetting one produces a failure about disagreement rather than about the path. Removing the duplication removes the check that policed it.

**Independent Test**: Capture, for every check, the exact list of files that check receives. Make the change. Capture the lists again. Require them to be identical, check for check, path for path. Then add one excluded path to a single check's own configuration and confirm that check skips it, that no other check's list changed, and that no check reports a disagreement.

**Acceptance Scenarios**:

1. **Given** the repository before this change, **When** the exclusion declarations are consolidated, **Then** every check receives exactly the same file list it received before, with no path gaining or losing coverage for any check.
2. **Given** a check whose tool provides a way to declare excluded paths, **When** a contributor looks for that check's exclusions, **Then** they are declared in that check's own configuration and nowhere else.
3. **Given** a check whose tool provides no way to declare excluded paths, **When** a contributor looks for that check's exclusions, **Then** they are declared somewhere reachable from that check alone, and the check excludes the same paths it excluded before.
4. **Given** a contributor adding one excluded path, **When** they make a single edit, **Then** the repository is in a consistent state and no check reports a disagreement between declarations.
5. **Given** a contributor invoking a tool by hand outside the repository's runner, **When** they invoke it, **Then** the tool skips the same paths the runner would have had it skip.

---

### Edge Cases

- A path offered for formatting that has been deleted, was never created, or points outside the repository: nothing is written and nothing fails.
- A path that is a symbolic link, a directory, a device node, or anything other than a regular file: left alone, no failure.
- A file that is in scope for two rewriting standards: both apply, in an order fixed by the repository rather than by the order the standards happened to be discovered, so two runs on the same content give the same result.
- A file already conformant: nothing is rewritten, and this is not reported as an error.
- A standard's tooling that cannot run at all in this environment: the modification still succeeds, and the gap is reported plainly rather than passed over in silence.
- A file rewritten as a side effect of a command the session ran, rather than edited directly: out of scope here, and left to the whole-repository check.
- A file modified by a subagent rather than by the main session: handled identically.
- Several files modified in quick succession: each is handled on its own, and none of them causes another file to be formatted.
- A file modified while the repository has pre-existing violations in files this change never touched: those violations are not reported and do not cause a failure, because the modification did not cause them.

## Requirements _(mandatory)_

### Functional Requirements

Two notes on how to read them.

**Terminology.** "Check" is the canonical word for one of the repository's quality checks, and the planning artifacts use it throughout. This section also says "standard" in places, meaning the same thing — the property a check enforces, spoken of from the content's side rather than the tool's. Where the distinction does not matter, the two are interchangeable.

**Numbering.** FR-030 belongs to the automatic-formatting half despite its number, and appears below with that half rather than at the end. It was added after the exclusion requirements were already numbered, and renumbering would invalidate every reference in `plan.md`, `research.md`, `data-model.md`, the contracts and `tasks.md`. The topical grouping is the one to trust.

#### Automatic formatting

- **FR-001**: When a file inside this repository is modified during an agent session, the repository MUST bring that file into conformance with the standards it already holds that file to, without any separate command being run.
- **FR-002**: The repository MUST format only the file that was modified. Formatting one file MUST NOT read or write any other file's content.
- **FR-003**: The repository MUST NOT introduce any new formatting standard, MUST NOT change what any existing standard requires of a file, and MUST NOT change the set of paths any standard excludes. Relocating where a standard's exclusions are _declared_, which the second half of this feature does, is not a change to that set; FR-024 states the equivalence that must hold when it happens.
- **FR-004**: The repository MUST apply only standards that can rewrite a file. A standard that can only report a verdict MUST NOT be applied to a modified file, because it cannot be satisfied automatically and would report violations the modification did not cause.
- **FR-005**: Where two rewriting standards both govern a modified file, the repository MUST apply them in a fixed, declared order, so that the same content produces the same result on every run.
- **FR-006**: A modified file that the repository excludes from its quality checks MUST be left byte-identical.
- **FR-007**: A modified file of a kind no rewriting standard governs MUST be left byte-identical, and the outcome MUST be reported as no standard applying rather than as a failure.
- **FR-008**: A path that does not resolve to an existing regular file inside this repository — deleted, never present, outside the repository, or not a regular file — MUST result in nothing being read or written and no failure being reported.
- **FR-009**: A file whose content is not text MUST be left byte-identical.
- **FR-010**: A rewrite performed by this feature MUST NOT cause formatting of that file to be attempted again as a consequence.
- **FR-011**: When formatting a file cannot be completed, the repository MUST report to the session the file, the standard that failed, and the standard's own output, unmodified, in enough detail to diagnose the cause, correct it, and try formatting again.
- **FR-012**: While a standard is applied to a file, the repository MUST show the contributor which file is being processed and under which standard.
- **FR-013**: Nothing outside this repository MUST be read or written at any point.
- **FR-014**: This behaviour MUST be configured in a way that is stored in the repository and shared with everyone who works in it, rather than depending on any one machine's settings.
- **FR-015**: This behaviour MUST NOT be delivered to consumers of this repository as part of the package it publishes.
- **FR-016**: A contributor MUST be able to bring one named file into conformance without formatting the rest of the repository, using the repository's existing checks rather than a second mechanism.
- **FR-017**: Each check that survives this feature MUST, when invoked with no arguments, behave exactly as it does today: same file list, same verdict, same output. The aggregate MUST continue to run every surviving check, stop at the first failure, and return that check's status unchanged. The one intended difference is that the check FR-028 removes is no longer among them.
- **FR-018**: When a standard's tooling cannot run at all in the current environment — neither present natively nor available through the fallback the repository already defines — the repository MUST report that plainly, naming the tool that is missing and the fallback that would have run in its place, and MUST NOT fail the modification. The report MUST be visible rather than silent, so that formatting cannot stop working unnoticed.
- **FR-019**: A file counts as "modified during an agent session" when the session wrote it through a file-editing action. A file rewritten as a side effect of a command the session ran is out of scope for this feature, and remains covered by the repository's existing whole-repository check.
- **FR-020**: This behaviour MUST apply to modifications made by a subagent acting on the session's behalf exactly as it applies to the main session. There MUST be no difference in behaviour between the two. Verified **by inspection**, not by a test fixture: subagent modifications are covered because the configuration is repository-scoped and nothing in it distinguishes the two cases, so a passing test would exercise the platform's documented default rather than anything this feature writes. What must be checked is the absence of a special case, and that is what inspection establishes.

- **FR-030**: This repository MUST be the single rewriting authority for files inside it. Where a formatter configured outside the repository would also rewrite a modified file, the repository MUST NOT rewrite that file concurrently with it, and MUST document how the external formatter is made to stand down for this repository. The repository MUST NOT edit configuration outside its own root to achieve this.

#### Exclusion declarations

- **FR-021**: Each check MUST declare the paths it excludes in exactly one place.
- **FR-022**: A check whose tool provides a mechanism for declaring excluded paths MUST use that mechanism as its single declaration.
- **FR-023**: A check whose tool provides no such mechanism MUST still exclude the same paths, declared in a place a reader can find from that check alone, and documented as the declaration for that check.
- **FR-024**: Consolidating the declarations MUST NOT change the file list any check receives. Every path excluded for a given check before the change MUST be excluded for that same check afterwards, and no path MUST become excluded that was not excluded before.
- **FR-025**: Equality of the before and after file lists MUST be demonstrated mechanically, per check, rather than asserted.
- **FR-026**: Adding or removing an excluded path MUST be a single edit, and MUST NOT be able to leave the repository in a state where two declarations disagree.
- **FR-027**: A contributor invoking a tool by hand, outside the repository's own runner, MUST get the same exclusions the runner applies.
- **FR-028**: The check that exists solely to detect disagreement between duplicate declarations MUST be removed, along with the duplicate list it compared against, since with one declaration per check there is nothing left for it to compare.
- **FR-029**: Every document that describes the removed list or the removed check MUST be corrected, and any earlier requirement this feature supersedes MUST be marked as superseded rather than left standing.

### Key Entities

- **Modified file**: a single path inside the repository whose content an agent session has just written. Carries a kind, which determines which standards govern it, and a location, which determines whether the repository holds it in scope at all.
- **Standard**: one of the repository's existing quality checks. Has a kind of content it governs, a concern it governs it for, a set of excluded paths, and a property this feature depends on — whether it can rewrite a file or only report on it.
- **Exclusion declaration**: the statement of which paths a given check skips. After this feature there is exactly one per check.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A contributor can make a non-conformant change to a governed file in an agent session and find the file conformant afterwards, with zero commands run by hand.
- **SC-002**: For every check, the list of files it receives is byte-for-byte identical before and after the exclusion change — zero paths gained, zero paths lost.
- **SC-003**: Holding a new path out of a given check requires editing exactly one file, and no check can fail because two declarations of that check's exclusions disagree — because each check has only one. Stated as a property of the declarations rather than as a count of a contributor's keystrokes: a path that should be excluded from three checks is three edits, one per check, and that is correct rather than a regression. Verified by adding one excluded path to one check's configuration and observing that only that check's file list changes.
- **SC-004**: Formatting a modified file touches exactly one file: the one that was modified. Measured by comparing the repository's state before and after.
- **SC-005**: Every one of the seven safety cases — excluded path, unsupported kind, deleted file, non-existent file, path outside the repository, non-regular file, non-text content — leaves the repository byte-identical and reports no failure. All seven are exercised by the repository's own self-test.
- **SC-006**: When a standard fails on a modified file, the report names the file, the standard, and the standard's own message, and a reader can act on it without consulting anything else.
- **SC-007**: The repository's own aggregate check and self-test both pass after the change.
- **SC-008**: The repository's whole-repository checks, invoked as they are today, produce the same verdict on the same tree as they did before the change.
- **SC-009**: No **live** document in the repository still describes the removed list or the removed check as present. Live means: each check's own configuration file, including its header comments; the repository's front page and its project instructions; code and code comments; and this feature's own contracts. It explicitly excludes the artifacts of features 001, 002 and 003, which are historical records of what was decided at the time — those are corrected by marking the superseded requirements as superseded, not by rewriting them. Measured as zero live matches for the removed filename and the removed check name, with the remaining historical matches counted and stated.
- **SC-010**: With a governing standard's tooling made unavailable, a modification still completes and the report names both the missing tool and the fallback that would have run. Verified by the repository's own self-test.
- **SC-011**: A file modified by a subagent ends up in the same state as the same file modified by the main session. Verified by comparing the two outcomes on identical input.
- **SC-012**: No file inside the repository is rewritten by two formatting authorities at once. The documentation states, in one copy-pasteable line, how an externally configured formatter is made to stand down for this repository.

## Assumptions

- The per-file status message is shown only when a standard actually processed the file, not on every modification. Showing a line for every edit, including the many that no standard governs, would be noise rather than status. This was one of four open questions in the request; it is resolved here as a default because a reasonable one exists, and it is cheap to reverse. The other three are left as FR-018, FR-019 and FR-020 for clarification.
- The repository's existing definition of what conformance means, and of which paths are in scope, is correct and stays as it is. This feature changes where exclusions are declared, never what they are.
- The standards that can rewrite a file, and those that can only report, are already known from the repository's existing checks. This feature discovers nothing new about them.
- Contributors and agents work from the repository root, as the repository's existing checks already require.
- Formatting happens on a single file at a time and is expected to complete quickly enough not to be noticeable as part of making a change; no batching or scheduling is introduced.
- The repository has no continuous integration configured today, and this feature adds none. Nothing here depends on a build service existing.
