# Feature Specification: Distribute the Toolkit's Own Skills

**Feature Branch**: `002-vendor-plugin-skills`

**Created**: 2026-09-02

**Status**: Draft

**Input**: User description: "This repository is a Claude Code plugin that advertises itself as a toolkit for building skills, and today distributes none of its own. Five skills the maintainer currently keeps only as a personal, machine-local install are to become part of what the plugin distributes, so that installing the plugin is enough to get them: a spec-driven-development pipeline runner, and four git-workflow skills covering branch creation, commit grouping, GitHub pull requests, and GitLab merge requests."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Install the plugin and get the skills (Priority: P1)

Someone installs this plugin because its description promises a toolkit for building custom agents, commands, skills and MCP servers. Today they get a quality gate and two manifests, and none of the skills the maintainer actually uses. They want the five skills the maintainer relies on to arrive with the plugin, invocable immediately, with nothing to copy into a personal directory and nothing to configure per machine.

**Why this priority**: This is the feature. Every other story is a condition on this one being true rather than merely appearing true.

**Independent Test**: Fully testable by installing the plugin into a checkout that has no personal copy of any of the five skills, listing the available skills, and confirming all five are present and each can be invoked. Delivers value on its own.

**Acceptance Scenarios**:

1. **Given** a machine with no personal copy of any of the five skills, **When** the plugin is installed and the available skills are listed, **Then** all five appear.
2. **Given** the plugin is installed, **When** each of the five is invoked, **Then** it begins its own documented first step rather than reporting a missing file or an unresolved reference.
3. **Given** the plugin is installed, **When** the repository's own quality gate is run, **Then** it passes with no exception added and no rule relaxed for the newly distributed content.

---

### User Story 2 - A distributed skill reaches its distributed companions (Priority: P1)

The pipeline runner does not do its own committing or its own change-proposal raising: it hands that work to three of the other four skills. Whoever installed the plugin expects those hand-offs to reach the copies the plugin distributes. Today they cannot: the runner names its companions in a form that resolves only for one particular install location, and it decides whether they exist at all by testing for a directory that a plugin install does not create. The failure is silent and arrives at the very end of a full eight-phase run, which is the most expensive place in the pipeline to discover it.

**Why this priority**: Equal to Story 1, because a skill that installs and then fails at its last step is worse than one that does not install. Nothing about the failure is visible until the work is done.

**Independent Test**: Fully testable by installing the plugin with no personal copy present, running the pipeline runner to the point where it hands off, and confirming the hand-off reaches the distributed copy; and separately by confirming the runner's own capability check reports the three companions present rather than missing.

**Acceptance Scenarios**:

1. **Given** the plugin is installed and no personal copy of any of the five exists, **When** the pipeline runner reaches a step that hands work to another of the five, **Then** the distributed copy of that skill runs.
2. **Given** the same conditions, **When** the pipeline runner performs its start-of-run capability check, **Then** it reports the three skills it can hand off to as available, and records which.
3. **Given** a machine that has both a personal copy and the plugin installed, **When** the pipeline runner hands off, **Then** which copy runs is stated in the run's own record rather than being left to whichever the host resolves first.
4. **Given** a hand-off target that genuinely cannot be resolved, **When** the pipeline runner reaches that step, **Then** it reports the target it could not reach and continues or stops according to its own documented rule for a missing companion, rather than failing without naming what was missing.

---

### User Story 3 - A skill finds the files it ships with (Priority: P1)

Four of the five skills carry helper scripts, and one carries change-proposal templates. Each reaches those files by a path. Today every worked example of that path names a personal install location, so a reader following the example — human or agent — constructs a path that does not exist under any other install form.

**Why this priority**: Equal to the first two. A helper script that cannot be found turns a documented deterministic step into an improvised one, which is the specific failure the scripts exist to prevent.

**Independent Test**: Fully testable by installing the plugin, invoking each skill that owns helper scripts, and confirming each script is located and run; and by grepping the distributed content for any remaining literal install location.

**Acceptance Scenarios**:

1. **Given** the plugin is installed, **When** a skill runs a helper script it ships with, **Then** the script is found and executed without the skill having been told where the skill itself was installed.
2. **Given** the distributed content, **When** it is searched for literal personal-install locations, **Then** none remains in any instruction a reader is meant to follow.
3. **Given** a skill that ships templates, **When** it needs one, **Then** it resolves it the same way it resolves its scripts.

---

### User Story 4 - One helper, not four copies (Priority: P2)

Four of the five skills need to offer the same branch choice, and today each carries its own copy of the script that computes it. Three copies are byte-identical; the fourth has diverged and is roughly half the size. A maintainer changing that behaviour must find and change every copy, and the drift-detection the skills already document compares only three of the four — so the divergent one is the copy nobody is watching.

**Why this priority**: Below the first three because the current arrangement works; it is a maintenance defect rather than a functional one. Above nothing, because committing a known three-way duplicate and a silent fork into a repository whose stated purpose is to model good practice undercuts the repository.

**Independent Test**: Fully testable by counting distributed copies of that helper, and by confirming every skill that needs the behaviour produces the same output for the same repository state.

**Acceptance Scenarios**:

1. **Given** the distributed content, **When** copies of that helper are counted, **Then** there is one.
2. **Given** the same repository state, **When** each skill that needs the branch choice obtains it, **Then** all of them present the same candidates in the same order.
3. **Given** the divergence between the previous copies, **When** the single distributed copy is compared against each, **Then** the record states which behaviour was kept and why the other was not.

---

### User Story 5 - The entry point stays an entry point (Priority: P2)

One of the five is meant to be started by a person; the other four are meant to be started by it. That distinction is carried today by a single frontmatter field, present on one skill and absent on four, and it is load-bearing in both directions: adding the field to a companion makes it undispatchable and breaks the pipeline's final step, while removing it from the runner makes the runner start itself unbidden. Whoever packages the five for distribution will be tempted to make their frontmatter uniform.

**Why this priority**: Below the functional stories because nothing is broken today. Recorded as a requirement because the failure mode is invisible, arrives at the end of a long run, and is exactly what a well-meaning consistency pass would introduce.

**Independent Test**: Fully testable by inspecting the distributed frontmatter of all five and confirming the asymmetry, and by confirming the distributed content states why it must not be normalised.

**Acceptance Scenarios**:

1. **Given** the distributed content, **When** the five skills' frontmatter is inspected, **Then** exactly one carries the field that makes a skill user-invoked-only, and it is the pipeline runner.
2. **Given** the distributed content, **When** the reason for that asymmetry is looked for, **Then** it is written down where a person editing the frontmatter would encounter it.

---

### Edge Cases

- A machine has both a personal copy and the plugin-distributed copy of the same skill. Both are offered to the user by the host; which one a hand-off reaches must be determined by the skill, not by resolution order, and must be recorded. On the maintainer's own machine this state is transient, because FR-025 removes the personal copies; on anyone else's it may be permanent, so the requirement is not made redundant by the removal.
- The delivery of this feature itself runs from the personal copies it is going to remove. Removal must come after everything that depends on them, or the work removes its own tooling before it is finished.
- The plugin is installed but the host does not support one of the mechanisms a skill depends on to locate its own files. The skill reports what it could not resolve rather than constructing a path that happens to be wrong.
- One of the five is invoked directly by a user rather than reached through the pipeline runner. It must behave exactly as it does today; being distributed changes how it is found, not what it does.
- The pipeline runner is mid-run when the plugin is upgraded. The run's own record already survives interruption; nothing in this feature may make an in-progress run depend on content that changed underneath it.
- A skill's helper script is invoked by a contributor by hand, from the repository rather than from an install. The path that works for the skill must also be constructible by a person reading the instruction.
- The distributed content includes a file that only makes sense inside this repository — a test-scenario document, a lint configuration. Whether such a file is distributed is decided per file, and the decision recorded, rather than following from the fact that it sits in the source directory.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The repository MUST distribute five skills as part of its plugin: a spec-driven-development pipeline runner, and four git-workflow skills covering branch creation, commit grouping, GitHub pull-request creation, and GitLab merge-request creation.
- **FR-002**: Each distributed skill MUST be discoverable and invocable after the plugin is installed, with no manual copying and no per-machine configuration step.
- **FR-003**: Each distributed skill MUST behave identically whether it was reached through the plugin or through a personal install: the same questions in the same order, the same recorded outcomes, and the same documented steps. This is the **observable outcome**, verified by comparing behaviour across the two install forms.
- **FR-004**: No distributed skill's behaviour MAY be conditional on where that skill was installed from. This is the **structural prohibition** that guarantees FR-003, verified by inspecting the distributed files for any branch on install form. The two are deliberately kept apart, and are not the same requirement stated twice: FR-003 can hold by luck across the cases anyone happens to test while a conditional sits unexercised in the content, and FR-004 is what forbids that conditional existing at all. A file that branches on install form violates FR-004 on the day it is written and FR-003 only on the day someone runs the other branch.
- **FR-005**: Every reference by which one of the five names another MUST resolve to a copy the plugin distributes when the plugin is the only source present.
- **FR-006**: Where both a distributed copy and a personal copy of a named skill are present, the distributed skills MUST resolve the reference deterministically, and the resolution MUST be recorded by the skill that made it rather than inferred by the reader.
- **FR-007**: A reference to a companion skill that cannot be resolved MUST be reported naming the unresolved target, and MUST follow that skill's existing documented rule for an unavailable companion rather than failing without explanation.
- **FR-008**: The pipeline runner's start-of-run capability check MUST determine the availability of the companion skills it hands off to by a test that holds under every install form, not by testing for one install location.
- **FR-009**: Every path by which a distributed skill locates a file it ships alongside itself MUST resolve without naming an install location.
- **FR-010**: Every worked example of such a path in the distributed content MUST be one a reader can follow under the install form the plugin produces.
- **FR-011**: The distributed content MUST contain exactly one implementation of the branch-choice helper that four of the five skills require.
- **FR-012**: Every skill needing the branch choice MUST obtain it from that single implementation and MUST present the same candidates in the same order for the same repository state.
- **FR-013**: The written record MUST state, for the reconciliation in FR-011, which of the previous copies' behaviour was kept and why the others were not.
- **FR-014**: Exactly one of the five distributed skills MUST carry the frontmatter field that marks a skill as user-invoked-only, and it MUST be the pipeline runner.
- **FR-015**: The distributed content MUST record why that field must not be added to the four companion skills, positioned where someone editing frontmatter would encounter it.
- **FR-016**: Every file the repository distributes for these skills MUST pass the repository's existing quality checks, with no check excluded, no path newly exempted, and no rule relaxed.
- **FR-017**: The repository MUST NOT distribute machine-local, generated, or binary files belonging to the source of these skills.
- **FR-018**: Each file present in the source of these skills MUST be distributed or not by an explicit recorded decision, and the record MUST state the reason for each file or class of file not distributed.
- **FR-019**: The repository's existing agreement between its scope declarations MUST still hold after the distributed content exists, and whether any declaration required an entry MUST be recorded either way.
- **FR-020**: The repository's own written record MUST be amended where it currently states that this plugin distributes no components and creates no component directories, so that the record does not contradict the repository.
- **FR-021**: The repository's written record MUST distinguish the skills this repository authors from the spec-tooling skills generated into it, so that a prohibition on distributing the generated ones is not read as covering an authored one whose name resembles them.
- **FR-022**: The written record MUST capture the researched practice this feature rests on, with sources: general practice for working with the host tool, practice for authoring and updating skills, and practice for authoring plugins.
- **FR-023**: No distributed skill's questions, wording, step order, or recorded outcomes MAY be changed except where distribution requires it, and each such change MUST be recorded with the requirement that forced it.
- **FR-024**: Each skill's test-scenario document MUST be distributed alongside that skill, and the reference each skill's instruction document already makes to it MUST continue to resolve.
- **FR-025**: The maintainer's personal copies of the five skills MUST be removed once distribution is verified, where verified means the repository's aggregate quality check has passed and the distributed copies have been confirmed present and invocable.
- **FR-026**: The removal in FR-025 MUST NOT be performed while any part of this feature's own delivery still depends on the personal copies, and MUST be confirmed immediately before it is performed rather than only when it was specified.
- **FR-027**: The change-proposal templates belonging to the GitHub pull-request skill MUST be distributed with their content, structure and prompts intact, and the written record MUST state which of them is that skill's own fallback, which is a set offered to other repositories, and that neither is to be merged with this repository's own templates. Each acquires a top-level heading, and nothing else: all seven began at a second-level heading, which the repository's Markdown check rejects under `MD041` (first-line-heading), and FR-016 requires that check to pass. This requirement originally read "unchanged" and was narrowed during implementation when the two requirements met -- see [research.md](./research.md) §7.

### Key Entities

- **Distributed skill**: one of the five, as the plugin ships it. Carries its instruction document, and may carry helper scripts, templates, and a test-scenario document. Identified by a name that the host resolves, and that the other distributed skills use to reach it.
- **Companion reference**: a place where one distributed skill names another in order to hand work to it. Has a target skill and a resolution outcome, and is the unit FR-005 through FR-007 govern.
- **Own-file path**: a path by which a distributed skill reaches a file it ships alongside itself. Has a form that must not name an install location, and a worked example that a reader follows.
- **Shared helper**: behaviour more than one of the five requires. Has exactly one distributed implementation, and a record of how the previous copies were reconciled into it.
- **Distribution decision**: the recorded verdict on one file, or one class of file, in the source of these skills: distributed, or not, with a reason.
- **Install form**: how a skill came to be present — distributed with the plugin, or copied into a personal location. Determines how names and paths resolve, and must not determine behaviour.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: On a machine with no personal copy of any of the five, installing the plugin yields all five available: 5 of 5 listed, 0 additional steps taken.
- **SC-002**: Every reference by which one of the five names another resolves under the distributed install: 74 such references exist at the start of this feature, 0 of which resolve today; 74 of 74 resolve at the end.
- **SC-003**: Literal personal-install locations remaining in instructions a reader is meant to follow: 16 exist at the start of this feature, 0 remain at the end. The figure was 22 when this criterion was first written, which counted every literal occurrence; 6 of those name the user's own machine-wide instructions file, which the skills name deliberately in order to forbid touching it. Those 6 are correct, install-independent, and out of this criterion's scope -- rewriting them would break the prohibition they carry. Corrected during planning.
- **SC-004**: Distributed copies of the branch-choice helper: 4 exist at the start of this feature, 3 identical and 1 divergent; 1 exists at the end.
- **SC-005**: For the same repository state, the branch candidates each of the four skills presents are identical: 0 differences in candidate set or order across the four.
- **SC-006**: The repository's aggregate quality check passes over the distributed content: exit status 0, with 0 checks skipped, 0 paths newly exempted and 0 rules relaxed relative to the state before this feature.
- **SC-007**: Machine-local, generated, and binary files distributed: 0. At least one such file, of 6,148 bytes, exists in the source at the start of this feature.
- **SC-008**: Files in the source of these skills lacking a recorded distribute-or-not decision: 0 of 47.
- **SC-009**: Skills carrying the user-invoked-only frontmatter field: exactly 1 of 5, and it is the pipeline runner.
- **SC-010**: Statements in the repository's written record that contradict the existence of distributed plugin components: 2 exist at the start of this feature, 0 remain at the end.
- **SC-011**: Research areas required by FR-022 recorded with at least one cited source each: 3 of 3.
- **SC-012**: Changes to a distributed skill's questions, wording, step order or recorded outcomes that are not traceable to a requirement in this specification: 0.
- **SC-013**: Scope declarations in the repository that disagree with each other after the distributed content exists: 0, verifiable by the repository's own scope check.
- **SC-014**: Test-scenario documents distributed: 5 of 5, and references to them from their own instruction documents that fail to resolve: 0 of 7. The figure was 6 when this criterion was written, which was a miscount rather than a change: two of the five instruction documents name their scenario file twice -- once in a reference map or maintenance note and once in prose -- so five documents carry seven references.
- **SC-015**: Personal copies of the five skills remaining after removal: 0 of 5, and removals performed before the aggregate check passed or before the distributed copies were confirmed invocable: 0.
- **SC-016**: Template files belonging to the GitHub pull-request skill that differ from their source by anything other than an added top-level heading: 0 of 7, and statements in the record identifying which set is which: 1. The heading is exempted because `MD041` forced it under FR-016; any other difference is a violation.

## Assumptions

- The host resolves a plugin-distributed skill by a name that differs in form from the name a personally installed skill resolves by. This is what makes FR-005 necessary; it is taken as given rather than proposed by this feature.
- The host provides distributed content some means of referring to its own install location without hard-coding one. FR-009 depends on this existing; the edge case where it does not is handled by reporting rather than guessing.
- The four git-workflow skills are correct as they behave today. This feature changes how they are found and how they find each other, not what they do.
- The five skills' current source is the authoritative version. Nothing older is reconciled, and no upstream is tracked. Since FR-025 removes that source once distribution is verified, the distributed copies become the only copies, which is why FR-016's check and FR-002's confirmation are preconditions of the removal rather than follow-ups to it.
- The repository's existing quality gate is the test for this feature. No new checking machinery is introduced, and the checks are run rather than reasoned about.
- The pipeline runner's own record of a run already survives interruption and compaction, so nothing in this feature needs to add durability to it.

## Out of Scope

- Writing any new skill, command, agent, output style, or MCP server.
- Redesigning any of the five skills' behaviour, questions, wording, or step order beyond what distribution requires.
- Establishing a mechanism to keep a personal install and the distributed copies reconciled over time. FR-025 removes the personal copies instead, which is what makes such a mechanism unnecessary rather than merely deferred.
- Removing, altering, or reading any personally installed skill other than the five this feature distributes.
- Extending the repository's checking machinery to content kinds it does not already check.
- Publishing the plugin to a marketplace, or changing how it is fetched.
- Distributing any of the spec-tooling skills generated into this repository.

## Clarifications

### Session 2026-09-02

- Q: Are the five skills' test-scenario documents part of what is distributed, or repository-only material kept out of the installed package? → A: Distributed. All five instruction documents already link to their own, so excluding them would break a documented reference in five places, and they cost nothing to carry because only the instruction document loads automatically.
- Q: After distribution, is the personal install expected to be removed, kept as-is, or kept and periodically reconciled against the distributed copies? → A: Removed, once distribution is verified. This ends drift and the both-copies-present case rather than managing them.
- Q: One of the five ships change-proposal templates of its own, and this repository already has its own set for its own use — should the distributed skill's templates stay that skill's material, be reconciled with the repository's, or be dropped in favour of them? → A: They stay that skill's own material, unchanged. One of them is the skill's own fallback and the skill does not work without it; the other is a generic set offered to any repository, which reconciling with this repository's constitution-quoting templates would make useless elsewhere.
