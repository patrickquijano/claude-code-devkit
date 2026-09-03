# Feature Specification: Unambiguous skill names and a standards-conforming front page

**Feature Branch**: `003-ccd-skill-rename`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "Users address this plugin's five skills by name. Each of those names is also the name a user may already have installed as a personal skill, so the bare name a user types does not say which copy answers. Every skill this plugin distributes must be addressable by a name that is unambiguous on its own, without depending on the plugin's namespace to disambiguate it. The five are renamed: speckit-run becomes ccd-speckit-run; auto-branch-push becomes ccd-branch-push; auto-commit-push becomes ccd-commit-push; auto-github-pr becomes ccd-github-pr; auto-gitlab-mr becomes ccd-gitlab-mr. After the change: a user invoking any of the five by its new name reaches that skill; every place where one skill names another reaches the renamed skill rather than a missing one; the pipeline skill still successfully hands work to the commit skill and to both forge skills; and nowhere in the plugin's live content is an old name still presented as current. Someone who has never seen this repository must be able to read its front page and learn, in this order, what the plugin is, how to install it, how to use each of the five skills, how to propose a change, and what licence it is under. The licence statement must point at a licence document that exists in the repository. The record published with this change must cite, for every external rule it relies on, the authoritative source of that rule and whether the rule is enforced by tooling or is only a convention. Non-goals: the plugin's own name does not change; the bookkeeping filenames the pipeline skill writes do not change; the shipped records under specs/001-quality-gate-plugin and specs/002-vendor-plugin-skills are not rewritten, although a reader of the two superseded interface records there must be able to tell they are superseded; no contributing, security or code-of-conduct document is added; and no skill's behaviour, wording, question order or recorded outcomes change apart from the names themselves."

## Clarifications

### Session 2026-09-03

- Q: When someone invokes one of the five old skill names after this change, what should happen? → A: Nothing — immediate retirement. No alias, no stub skill, no deprecation period. The front page is what tells a user the new name.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - A name that says which copy answers (Priority: P1)

Someone has this plugin installed and also keeps their own personal copy of one or more of the same skills. They type a skill name to start it. Today the name they type is the same word in both places, so which copy answers depends on how the session resolves the collision rather than on anything the user chose. After this change every skill the plugin distributes answers to a name that no personal copy is using, so the name the user types picks the copy they meant.

**Why this priority**: This is the whole point of the feature. Every other story is either a consequence of the rename or the documentation that makes it usable. Without it the plugin's skills stay unaddressable in the one situation the plugin is most likely to be in — installed alongside the personal skills it was built from.

**Independent Test**: Install the plugin alongside a personal skill of one of the old names, invoke each of the five new names in turn, and confirm each reaches the plugin's copy. Delivers the disambiguation on its own, with no documentation change needed.

**Acceptance Scenarios**:

1. **Given** the plugin is installed and a personal skill named `speckit-run` also exists, **When** the user invokes `ccd-speckit-run`, **Then** the plugin's pipeline skill runs and the personal skill does not.
2. **Given** the plugin is installed, **When** the user invokes any of `ccd-branch-push`, `ccd-commit-push`, `ccd-github-pr` or `ccd-gitlab-mr`, **Then** that skill runs.
3. **Given** the plugin is installed, **When** the user lists the skills the plugin provides, **Then** all five appear under their new names and none appears under an old one.

---

### User Story 2 - The pipeline still reaches the skills it hands work to (Priority: P1)

The pipeline skill hands work to three of the other four at the end of a run: to the commit skill when the run's output needs committing, and to whichever forge skill matches the repository's remote when it raises a review request. Each of those handoffs names the skill it is calling. A rename that moves the directories without moving the names in those calls leaves the pipeline calling skills that no longer exist — and it fails at the very end of a long run, which is the most expensive place for it to fail.

**Why this priority**: Equal to Story 1. A rename that breaks the handoffs has not renamed the skills, it has broken them. The failure is silent until the last step of a full pipeline run.

**Independent Test**: Run the pipeline skill through to its shipping step in a repository with a supported remote and confirm the commit handoff and the review-request handoff both reach a skill that exists. Testable without any documentation change.

**Acceptance Scenarios**:

1. **Given** a run reaches the point where its output needs committing, **When** the user chooses to commit, **Then** the commit skill is reached under its new name and runs.
2. **Given** a run reaches the point where it raises a review request and the remote is a GitHub repository, **When** the request is raised, **Then** the GitHub skill is reached under its new name and runs.
3. **Given** the same run on a GitLab remote, **When** the request is raised, **Then** the GitLab skill is reached under its new name and runs.
4. **Given** any of the five skills tells the user that a different one of the five is the right skill for their situation, **When** the user follows that pointer, **Then** the name it gave them reaches a skill that exists.

---

### User Story 3 - The shared helper still resolves (Priority: P1)

Four of the five skills read their branch candidates from a single helper that ships with exactly one of them. Every one of those four names the location of that helper. Moving the directory that owns it, without moving the four references, leaves four skills reading a path that is not there.

**Why this priority**: Equal to Stories 1 and 2 — it is the same class of breakage, and it breaks the first question every one of those four skills asks.

**Independent Test**: Invoke each of the four consuming skills and confirm each one lists branch candidates rather than reporting a missing helper.

**Acceptance Scenarios**:

1. **Given** the rename is complete, **When** any of the four consuming skills asks the user to choose a branch, **Then** it presents the candidate list rather than an error.
2. **Given** the rename is complete, **When** the repository is searched for the helper, **Then** exactly one copy exists and it belongs to the renamed branch skill.

---

### User Story 4 - A front page a newcomer can act on (Priority: P2)

Someone who has never seen this repository opens its front page. Today that page tells them what the plugin contains and how its quality checks run, but never how to install it, never how to start any of the skills it describes, and states no licence — while the plugin's own manifest claims one. They cannot get from reading to using without going and reading the source.

**Why this priority**: Below the rename stories because the plugin works without it, and above nothing else because a renamed skill nobody can find out how to install is not much better than an ambiguous one. It also carries the licence gap, which is a correctness problem rather than a presentation one.

**Independent Test**: Give the front page to a reader who has not seen the repository and ask them to install the plugin and start one skill using only that page. Testable independently of the rename.

**Acceptance Scenarios**:

1. **Given** a reader who has never seen the repository, **When** they read the front page top to bottom, **Then** they encounter what the plugin is, how to install it, how to use it, how to propose a change, and its licence, in that order.
2. **Given** the front page, **When** the reader looks for how to install the plugin, **Then** they find the steps and can follow them without opening another file.
3. **Given** the front page, **When** the reader looks up any one of the five skills, **Then** they learn its new name and what it does.
4. **Given** the front page's licence statement, **When** the reader follows it, **Then** they reach a licence document that exists in this repository, and it names the same licence the plugin's manifest declares.

---

### User Story 5 - A reader of the superseded records is not misled (Priority: P3)

Two records published by an earlier change state the five names and the helper's location as they were before this change. Those records describe what shipped at the time and are not rewritten. A reader who reaches one of them, and does not know a later change happened, will take a stale name for a current one.

**Why this priority**: Lowest of the five. It misleads a reader rather than breaking anything, and only a reader who goes looking in the historical record.

**Independent Test**: Open each of the two records and confirm a reader can tell from the record itself that a later change supersedes it.

**Acceptance Scenarios**:

1. **Given** a reader opens either superseded record, **When** they read it, **Then** the record itself tells them a later change supersedes it and where to find that change.
2. **Given** the two records, **When** they are compared with what they said before this change, **Then** nothing has changed except the addition of that pointer.

---

### Edge Cases

- What happens when a user invokes one of the five **old** names after the change? The plugin no longer answers to it (FR-016). On a machine that still has the personal copy the name came from, that copy answers — which is the correct outcome, because the user typed the name that belongs to it. On a machine without one, nothing answers, and the front page carries the new name.
- What happens when a personal copy of a skill also carries a new name — for example a user who has already made their own `ccd-github-pr`? The plugin's copy remains reachable by its namespaced form, which is what that form is for; the bare name is ambiguous again, and this feature does not claim to solve a collision a user creates deliberately.
- What happens when only some of the references are updated? Every partial state is a failure state: a skill that resolves but hands work to a missing one is worse than a skill that does not resolve at all, because the failure arrives at the end of the work rather than the start. FR-005 and FR-006 exist to make the partial state detectable.
- What happens to a pipeline run that was already in progress, holding bookkeeping written under the old arrangement? Its bookkeeping filenames do not change (FR-014), so the run's own state is still found. Any dispatch it has not yet made will use the new names.
- What happens when the front page is read by someone who has the plugin already installed? They should still be able to find the skill they want by name, so the usage section is organised by skill and not only as a narrative.

## Requirements _(mandatory)_

### Functional Requirements

#### The names

- **FR-001**: Each of the five distributed skills MUST be addressable under its new name: `ccd-speckit-run`, `ccd-branch-push`, `ccd-commit-push`, `ccd-github-pr`, `ccd-gitlab-mr`.
- **FR-002**: Each skill's declared name and the name of the container it ships in MUST agree. A skill whose two names disagree MUST NOT be shipped.
- **FR-003**: The set of new names MUST NOT collide with the names of the personal skills this plugin's contents were derived from, so that the bare name a user types identifies the plugin's copy without relying on the plugin's namespace.
- **FR-004**: Exactly one of the five MUST remain reachable only when a user asks for it by name, and it MUST be the pipeline skill. The other four MUST remain reachable both by a user and automatically.

#### The references

- **FR-005**: Every place where one skill names another MUST name the renamed skill. After the change, no reference from any of the five to any of the five may resolve to a name that does not exist.
- **FR-006**: Every place in the plugin's **live content** — everything the plugin ships or presents as current, which for this repository means `skills/`, `README.md`, `CLAUDE.md` and `.claude-plugin/`, and specifically excludes the historical records under `specs/` covered by FR-017 — that refers to one of the five — whether as an invocation a user types, a location a skill reads from, a name one skill dispatches, or a mention in prose — MUST refer to it by its new name. No old name may remain anywhere in the live content presented as current.
- **FR-007**: The pipeline skill MUST still successfully hand work to the commit skill at its commit step, and to the matching forge skill at its review-request step, under the new names.
- **FR-008**: The shared branch-candidate helper MUST continue to exist exactly once, MUST belong to the renamed branch skill, and MUST be reachable by all four of its consumers under the new location.

#### The front page

- **FR-009**: The repository's front page MUST present, in this order: what the plugin is; how to install it; how to use it; how to propose a change; and its licence.
- **FR-010**: The front page MUST let a reader who has never seen the repository install the plugin without opening another file.
- **FR-011**: The front page MUST name all five skills under their new names and state what each one does.
- **FR-012**: The front page MUST state the plugin's licence and point at a licence document, and that document MUST exist in the repository and name the same licence the plugin's manifest declares.
- **FR-013**: The front page MUST keep telling a reader how the repository's quality checks are run, which it does today.

#### Boundaries

- **FR-014**: The plugin's own name, and the names of the bookkeeping files the pipeline skill writes during a run, MUST NOT change.
- **FR-015**: No skill's behaviour, wording, question order, or recorded outcomes may change, except for the names themselves and the references to them.
- **FR-016**: The change MUST be immediate. The five previous names are retired at once: the plugin MUST NOT ship an alias, a redirect, or a stub under any of them, and MUST NOT declare a deprecation period. A user who invokes an old name reaches whatever else on their machine answers to it, or nothing; the front page is what tells them the new name.
- **FR-017**: The two superseded records MUST each carry a pointer telling a reader that this change supersedes them and where to find it, and MUST otherwise be unchanged.

#### The record

- **FR-018**: The record published with this change MUST cite, for every external rule it relies on, the authoritative source of that rule and whether that rule is enforced by tooling or is only a convention.

### Key Entities

- **Distributed skill**: one of the five things this plugin ships that a user can start by name. Has a name a user types, a container it lives in, a statement of what it is for, and — for some — bundled helpers and templates it reads at run time.
- **Reference**: any place one skill names another, or names a helper's location. The unit that a rename breaks, and the unit FR-005 and FR-006 are counted over.
- **Shared helper**: the single branch-candidate lister that four of the five read from. Owned by one skill, addressed by four.
- **Front page**: the repository's entry document, read by someone deciding whether and how to use the plugin.
- **Superseded record**: a published statement of the five names, or of the helper's location, as they stood before this change.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: All five skills are reachable under their new names; 5 of 5 succeed.
- **SC-002**: Zero references anywhere in the plugin's live content resolve to a name that no longer exists.
- **SC-003**: Zero occurrences of any of the five old names remain in the plugin's live content presented as a current name.
- **SC-004**: A pipeline run taken end to end reaches its commit handoff and its review-request handoff without either failing to find the skill it names; both handoffs succeed.
- **SC-005**: Exactly one copy of the shared helper exists, and all four consumers reach it.
- **SC-006**: A reader who has never seen the repository can install the plugin and start one named skill using only the front page, with no other file opened.
- **SC-007**: The front page's licence statement resolves to a licence document that exists and matches the licence the manifest declares; today it resolves to nothing.
- **SC-008**: The repository's existing aggregate quality check passes on the changed tree.
- **SC-009**: Every external rule the published record relies on carries a source and a statement of whether it is enforced or conventional; 100 per cent of them, with no uncited claim.
- **SC-010**: Both superseded records tell their reader they are superseded, and differ from their previous content by that pointer alone.
- **SC-011**: The plugin ships exactly five skills, all under new names. Zero stubs, aliases or redirects under an old name exist.

## Assumptions

- The plugin's namespace continues to work as it does today, so the namespaced form of each name stays available. The rename is about making the **bare** name unambiguous, not about replacing the namespace.
- The five skills' current content is the authoritative version. Nothing older is reconciled, and no upstream copy is tracked.
- Users who had been invoking the old names are reachable through the front page; no separate migration notice is published.
- The personal copies these skills were derived from may still be installed on a given machine. This feature does not remove them, and does not depend on them being removed.
- The repository's existing quality checks and their configuration are correct as they stand, and this change is expected to pass them without relaxing any of them.
- The licence to be documented is the one the plugin's manifest already declares; this feature records it rather than choosing it.
