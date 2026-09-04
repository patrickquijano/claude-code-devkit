# Feature Specification: Merge Conflict Resolution

**Feature Branch**: `005-merge-conflict-resolution`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Research and extract information, rules, guidelines and instructions about Claude Code best practices and standards, developing or updating effective and efficient Claude Code skills, and solving merge conflicts effectively and efficiently. Create or update a documentation based on the extracted information from the research in `docs/`. Create or update the project rules, guidelines and instructions from the research extracted rules, guidelines and instructions. Create an effective and efficient Claude Code plugin skill that will guide the user in solving merge conflicts."

## Clarifications

### Session 2026-09-04

- Q: Should the skill initiate the operation that produces the conflicts, and should it conclude that operation once no conflicts remain? (FR-017) → A: Adaptive and gated — resolve an operation already in progress; where none is in progress and the branch is behind after the fetch, propose the integration options with a recommendation and initiate only on approval; conclude the operation once the tree is conflict-free.
- Q: Which instruction files should this feature update so they agree with the new documentation? (FR-006) → A: The repository-wide agent instruction file for rules that hold everywhere, plus newly created path-scoped rule files for rules that apply to only one area. The shared cross-agent file and the governance document are out of scope.
- Q: Should the merge-conflict skill be reachable automatically when a conflict is detected, or only when the user names it? (FR-018) → A: Reachable both ways — it is not marked user-invocable-only, because every mutation it makes is already gated on the user's approval, so automatic reach cannot produce automatic resolution.
- Q: The agent-configuration directory is excluded from every quality check, so path-scoped rule files placed there would be the only repository-owned documentation nothing governs. How should that be settled? (FR-005, FR-006) → A: Narrow the exclusion so the rule-file directory is checked by the three checks that govern documentation text, leaving the rest of the agent-configuration directory excluded. Narrowing an exclusion is the opposite of widening one, so the prohibition on widening is satisfied.
- Q: Concluding the operation records a commit, but the requirement forbidding the discarding of uncommitted work says nothing about committing it. What may concluding record? (FR-016, FR-017b) → A: Only the paths that were conflicted and the resolution the user approved; any unrelated uncommitted work must still be uncommitted afterwards. Recorded as FR-017c.
- Q: One requirement limits the files in scope to the instruction files, another requires correcting the skill count everywhere in the repository. Which governs? (FR-006, FR-021a) → A: They govern different kinds of change — writing a new rule is confined to the instruction files, while correcting a statement this feature makes untrue reaches any file carrying it. Both requirements were amended to say so.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Resolve a conflicted working tree under guidance (Priority: P1)

A contributor's working tree is carrying conflicts. Rather than reading conflict markers and guessing, they invoke the guided skill. It confirms the version-control tool is present, brings the remote's state up to date, and reports exactly which paths are conflicted and what kind of conflict each one is. For those conflicts it lays out the candidate resolutions, explains what each would do to the content, recommends one, and says why. The contributor picks one and approves it. The skill applies that and nothing else, then looks again — and if conflicts remain, it reports the new state and asks again rather than declaring itself finished.

**Why this priority**: This is the deliverable the rest exists to support. It is the only part that changes what a contributor can do rather than what they can read, and it is independently valuable even if no documentation were written at all.

**Independent Test**: Fully testable by creating a conflicted working tree, invoking the skill, and confirming the contributor reaches a conflict-free tree having been shown an explanation and a justified recommendation at every decision point. Delivers a resolved tree and an auditable record of why it was resolved that way.

**Acceptance Scenarios**:

1. **Given** a working tree carrying conflicts in three paths, **When** the contributor invokes the skill, **Then** all three paths are reported with the nature of each conflict before any resolution is proposed.
2. **Given** the skill has proposed resolutions, **When** the contributor has not yet approved one, **Then** no file in the working tree has been modified.
3. **Given** the contributor approves one proposed resolution, **When** the skill applies it, **Then** only what that resolution described is changed, and the skill re-examines the tree afterwards.
4. **Given** conflicts remain after an approved resolution is applied, **When** the skill re-examines the tree, **Then** it reports the remaining conflicts and proposes again rather than reporting success.
5. **Given** the version-control tool is not available, **When** the contributor invokes the skill, **Then** the skill stops, says which tool is missing, and has changed nothing.
6. **Given** the same conflicted state is presented on two separate occasions, **When** the skill identifies the conflicts each time, **Then** both runs report the same set of conflicted paths and the same classification for each.

---

### User Story 2 - Learn the practices from published documentation (Priority: P2)

Someone about to write or revise a skill in this toolkit, or about to resolve a conflict without the skill's help, opens the repository's documentation and finds the practices written down: how to work with Claude Code, how to build and revise a skill so it is actually loaded and actually followed, and how to approach a merge conflict so the resolution is defensible. Each practice says where it came from, and where no authoritative source exists the documentation says so instead of inventing one.

**Why this priority**: Documentation outlives any one skill and is what makes the next skill in this toolkit good. It ranks below the skill because a contributor blocked by a conflict today is not helped by prose, but it ranks above rule alignment because the rules are derived from it.

**Independent Test**: Testable by reading the published documentation and confirming each of the three subjects is covered, that every recorded practice is either sourced or explicitly marked as unsourced, and that a reader who has never seen this repository can act on it.

**Acceptance Scenarios**:

1. **Given** the published documentation, **When** a reader looks for guidance on any of the three subjects, **Then** each subject is covered.
2. **Given** any single recorded practice, **When** a reader asks where it came from, **Then** the documentation names the source, or records that no authoritative source was found.

---

### User Story 3 - Repository instructions that agree with the documentation (Priority: P3)

An agent working in this repository reads its instruction content and gets guidance consistent with what the documentation tells a human. Nothing an agent is told contradicts what a contributor would read, and no instruction that this feature made untrue is left standing.

**Why this priority**: Least urgent of the three and the most easily deferred, but leaving it undone is what turns the documentation into a second, competing source of truth.

**Independent Test**: Testable by reading the repository's instruction content against the published documentation and confirming no statement in one contradicts the other, and that every statement made false by this feature has been corrected.

**Acceptance Scenarios**:

1. **Given** the published documentation and the repository's instruction content, **When** the two are compared, **Then** no instruction contradicts the documentation.
2. **Given** an instruction that this feature rendered untrue, **When** the change is reviewed, **Then** that instruction has been corrected in the same change.

---

### Edge Cases

- What happens when the skill is invoked and the working tree carries no conflicts at all? Where the branch is also up to date with the remote, it reports that there is nothing to do rather than proposing resolutions for an empty set. Where the branch is behind, it proposes integrating the remote work and waits for approval rather than either integrating silently or reporting nothing to do.
- What happens when the remote cannot be reached — no network, or credentials rejected? The remote update fails, and the skill must say so and let the contributor decide whether to continue against what is already on disk rather than silently proceeding as if the remote had been read.
- What happens when a conflict is not a content conflict — the same path deleted on one side and modified on the other, or a directory replaced by a file? These cannot be resolved by choosing lines, so they must be reported as their own kind and their candidate resolutions must reflect that.
- What happens when a conflicted file is not text at all? Choosing lines is meaningless, so the candidate resolutions must be whole-file ones.
- What happens when the contributor rejects every proposed resolution? The skill leaves the tree as it found it and does not fall back to a resolution nobody approved.
- What happens when an approved resolution turns out not to resolve the conflict it targeted? The re-examination detects that the conflict survives, and the iteration reports it rather than looping silently.
- What happens when the contributor has uncommitted work unrelated to the conflict? It must survive the resolution untouched.
- What happens when the same conflict has been resolved before in this repository? A previously recorded resolution is a candidate worth surfacing rather than re-deriving.

## Requirements _(mandatory)_

### Functional Requirements

#### Documentation

- **FR-001**: The repository MUST publish documentation under `docs/` recording the practices and standards for working with Claude Code.
- **FR-002**: The repository MUST publish documentation under `docs/` recording the practices and standards for developing and revising Claude Code skills.
- **FR-003**: The repository MUST publish documentation under `docs/` recording the practices for resolving merge conflicts effectively.
- **FR-004**: Every practice the documentation records MUST name the source it was established from; where no authoritative source exists for a practice, the documentation MUST record that gap explicitly rather than presenting an unsourced claim as established.
- **FR-005**: The published documentation MUST satisfy every documentation standard this repository already enforces, and no existing check's declared scope MAY be widened to accommodate it.
- **FR-005a**: The path-scoped rule files FR-006 introduces MUST also be governed by the checks that apply to documentation text. Where they would fall inside an existing exclusion, that exclusion MUST be narrowed so the rule files are checked, rather than the rule files being left ungoverned; narrowing an exclusion is permitted where widening one is not, because it subjects more repository-owned content to the standards rather than less.

#### Repository instructions

- **FR-006**: The repository's own rules, guidelines and instructions MUST be updated so that no instruction contradicts the published documentation. This requirement governs **where new rules are written**: the files in scope for receiving a rule are the repository-wide agent instruction file, for rules that hold everywhere in the repository, and newly created path-scoped rule files, for rules that apply to only one area of it. No rule this feature records MAY be written into the shared cross-agent instruction file or the governance document. Correcting a statement this feature makes untrue is a different kind of change, governed by FR-007 and FR-021a, and is not limited to these files.
- **FR-006a**: Each path-scoped rule file MUST declare the paths it governs, so that it is read when those paths are being worked on and not otherwise.
- **FR-006b**: The repository-wide agent instruction file MUST remain within its documented length target; content that would push it past that MUST be placed in a path-scoped rule file instead of lengthening it, because instruction adherence falls as that file grows.
- **FR-006c**: Every rule this feature records MUST be a durable working rule rather than a requirement of this feature; a statement that ceases to be true once this feature ships belongs in this specification and not in an instruction file.
- **FR-007**: Any existing instruction that this feature renders untrue MUST be corrected as part of this feature, not left for a later change.

#### The guided skill

- **FR-008**: The plugin MUST distribute an additional skill, carrying the same name prefix every skill in this plugin carries, that guides a user through resolving merge conflicts.
- **FR-009**: Before taking any other action, the skill MUST establish that the version-control tool it depends on is available; where it is absent the skill MUST stop, tell the user which tool is missing, and leave the working tree unchanged.
- **FR-010**: The skill MUST bring the remote's state up to date as the first step of its workflow after the availability check.
- **FR-011**: The skill MUST identify which conflicts exist and report every conflicted path together with the kind of conflict it is, before proposing any resolution.
- **FR-012**: The skill MUST present, for the conflicts it found, the candidate resolutions with an explanation of what each one would do, a recommendation among them, and the justification for that recommendation; and it MUST NOT modify any file until the user has approved a resolution.
- **FR-013**: The skill MUST apply only the resolution the user approved, and nothing beyond it.
- **FR-014**: After applying an approved resolution the skill MUST re-identify the conflicts, and where any remain it MUST report the remaining state and propose again rather than reporting completion.
- **FR-015**: The skill's identification and application steps MUST be carried out by deterministic procedures distributed with the skill itself, such that the same conflicted state yields the same report on every run, and a reader can audit what the skill will do before invoking it.
- **FR-016**: The skill MUST NOT discard uncommitted work, and MUST NOT resolve a conflict on its own judgment without the user's approval, under any circumstance including a resolution that appears obvious.
- **FR-017**: The skill MUST determine, after the remote update, whether a conflict-producing operation is already in progress, and act accordingly: where one is in progress it MUST resolve that operation's conflicts, and where none is in progress it MUST NOT assume one.
- **FR-017a**: Where no operation is in progress and the branch is behind the remote, the skill MUST present the available ways of integrating the remote work as candidate options with an explanation of each, a recommendation, and its justification, and MUST NOT begin integrating until the user has approved one.
- **FR-017b**: Once no conflicts remain, the skill MUST conclude the operation it resolved, so that the user is not left holding an operation still in progress. Where concluding fails, the skill MUST report why and leave the resolved content in place rather than reverting it.
- **FR-017c**: Concluding the operation MUST record only the paths that were conflicted and the resolution the user approved for them. It MUST NOT record any other modified path, and any uncommitted work the user had that was unrelated to the conflict MUST still be uncommitted once the operation has been concluded.
- **FR-018**: The skill MUST be reachable both when the user names it and when a conflicted state is detected without the user having named it. It MUST NOT be marked as reachable only by explicit user invocation, because its every mutation is already gated on the user's approval by FR-012 and FR-016, so being reached automatically cannot cause anything to be resolved automatically.
- **FR-019**: Where a conflicted path cannot be resolved by selecting content — because the path was removed on one side, because its type changed, or because its content is not text — the skill MUST report it as that kind and MUST offer candidate resolutions appropriate to it rather than line-level ones.
- **FR-020**: Where the remote cannot be reached, the skill MUST report the failure and let the user decide whether to continue against the state already on disk, rather than proceeding as though the remote had been read.

#### Committed records

- **FR-021**: The repository's committed record of how many skills the plugin distributes MUST be updated to match what this feature ships, and its record of which skills are marked as reachable only by explicit user invocation MUST state that exactly one still is, and which one — a count that FR-018 leaves unchanged in substance but restates against a larger set. The record being replaced MUST remain readable as an accurate account of what it originally described rather than being rewritten in place.
- **FR-021a**: Every statement anywhere in the repository that asserts the previous number of distributed skills MUST be corrected, so that the repository's own counting verification reports the intended state rather than a discrepancy. This is a factual correction rather than the recording of a rule, so it reaches any file carrying such a statement — reader-facing documentation included — and is not confined to the files FR-006 names.

### Key Entities

- **Conflicted path**: A single path the version-control tool reports as unmerged, together with the kind of conflict — competing content, removed on one side, changed type, or non-text.
- **Candidate resolution**: One way a given conflict could be settled, carrying the explanation of what it would do to the content and whether it is the recommended one.
- **Conflict report**: The set of conflicted paths found in one identification pass, which is what the iteration compares against to decide whether to propose again.
- **Practice entry**: One recorded practice in the documentation, carrying its statement and either its source or an explicit note that no authoritative source was found.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A contributor starting from a conflicted working tree reaches a conflict-free one through the skill, having been shown an explanation and a justified recommendation for every decision they were asked to make — zero decisions presented without both.
- **SC-002**: 100% of the practices recorded in the published documentation carry either a named source or an explicit record that none was found.
- **SC-003**: Zero statements in the repository's instruction content contradict the published documentation, verifiable by reading the two against each other.
- **SC-004**: Invoked where the version-control tool is unavailable, the skill stops before changing anything and names the missing tool — verified by zero modified paths and a message identifying the tool.
- **SC-005**: The same conflicted state, presented on two separate runs, produces identical sets of conflicted paths and identical classifications.
- **SC-006**: No resolution is applied that the user did not approve — zero unapproved modifications across every scenario, including where the skill's own recommendation was the obvious one.
- **SC-006a**: Where the user had uncommitted work unrelated to the conflict, that work is still uncommitted after the operation has been concluded — zero unrelated paths recorded in the concluding commit.
- **SC-007**: The repository's aggregate quality check passes on the change, with no check's exclusions widened to let any new content through, and with every file this feature adds — the documentation and the path-scoped rule files alike — inside the scope of the checks that govern its content kind.
- **SC-008**: The committed count of distributed skills matches the number actually shipped, so the repository's own counting verification reports the intended state rather than a failure.
- **SC-009**: A contributor who has never opened this repository can act on any one of the three documented subjects without reading source code.

## Assumptions

- The set of conflict-producing operations in scope is every operation that can leave the working tree in a conflicted state, rather than a single named one. Identification is uniform across them, so narrowing the set would be a deliberate restriction rather than a simplification. FR-017's clarification confirms this: the skill detects whichever operation is in progress rather than assuming a particular one, which only works if all of them are recognised.
- The documentation under `docs/` is written primarily for contributors to this repository, and secondarily so that a user of the installed plugin can read it without repository access. The two audiences want the same content at different depths, so one document per subject serves both; where they genuinely diverge, the contributor's need wins.
- The three research subjects become three separate documents rather than one combined document, because they have different audiences and different lifetimes, and because this repository's documentation convention of one line per paragraph makes a single combined file impractical to review.
- Practices are drawn from the vendor's own published documentation for anything concerning Claude Code and skills, and from the version-control tool's own documentation for anything concerning conflicts. Where those sources are silent, the gap is recorded rather than filled from a third-party opinion — the same treatment this repository's earlier research artifacts already apply.
- The user invoking the skill has the authority to modify the working tree they are in; the skill does not need to establish permission beyond confirming the tool is present.
- Nothing in this feature requires network access at the moment the documentation is read, only at the moment the skill updates the remote.
