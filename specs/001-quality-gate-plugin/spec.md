# Feature Specification: Repository Quality Gate and Plugin Packaging

**Feature Branch**: `001-quality-gate-plugin`

**Created**: 2026-09-02

**Status**: Draft (amended 2026-09-02 -- per-check ignore declarations, formatting scope and defaults policy, spec-tooling capability extensions)

**Input**: User description: "Anyone working in this repository — maintainer, contributor, or coding agent — needs one dependable way to check that the repository's own content meets a consistent, written quality standard, and the repository needs to be usable as a Claude Code plugin so the toolkit it advertises can actually be installed."

## Clarifications

### Session 2026-09-02

- Q: When a check can reach neither the locally installed tool nor its fallback, is that a hard failure that fails the whole run, or a reported skip that lets remaining checks continue? → A: Hard failure, run stops.
- Q: May a check rewrite files into conformance, or only report violations — and if both, is rewriting a separate command or a flag on the same one? → A: Both, one command with a fix flag.
- Q: Is the scope of checked content the entire repository, or the repository minus generated, vendored and agent-local state? → A: Repository minus generated, vendored and agent-local state.

### Session 2026-09-02 (amendment)

- Q: When a formatting add-on component is absent on the machine running the check, does the check warn and continue, or fail? → A: Neither — that content kind falls back to the container path, where the add-ons are pinned, and the check reports that it did so.
- Q: What is the declared hook execution order ordered by? → A: An explicit numeric rank in committed configuration, with the numbers assigned by effect: observational and read-only hooks first, hooks that mutate the repository last.
- Q: Are per-assessment and per-bug artifacts committed as project history, or excluded as working state? → A: Committed, on the same footing as `specs/`.

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Check the repository against its own standard (Priority: P1)

A contributor has edited documentation, a configuration file, or a script. Before proposing the change they want to know, without reading a style guide, whether what they wrote conforms to what this repository expects. They run one command from the repository root and get a plain pass or fail, with every violation named by file and location.

**Why this priority**: This is the whole point of the feature. Without it there is no standard, only opinions expressed at review time. Every other story is a refinement of this one.

**Independent Test**: Fully testable by introducing a known violation of each content standard, running the check, and confirming it fails naming that location; then correcting the violation and confirming it passes. Delivers value on its own even if nothing else in this feature ships.

**Acceptance Scenarios**:

1. **Given** a documentation file that violates the documentation standard, **When** the contributor runs the check, **Then** the check exits with a failure status and names the offending file and line.
2. **Given** every file in scope conforms to its standard, **When** the contributor runs the check, **Then** the check exits with a success status and reports no violations.
3. **Given** a violation exists in the first content type checked, **When** the aggregate check runs, **Then** it stops at that failure rather than reporting a mixed or partial result.

---

### User Story 2 - Get the same verdict without installing anything (Priority: P1)

A contributor, or an automated environment, has none of the checking tools installed. They run the same command and get the same verdict as a maintainer whose machine has every tool installed natively. Nothing about the result depends on which of the two ran it.

**Why this priority**: Equal priority to Story 1 because a standard that only the maintainer can evaluate is not a shared standard. It is also what makes the check usable from an automated environment with no setup step.

**Independent Test**: Testable by running the check on a machine or container with the tools absent and comparing the verdict, violation list and exit status against a run on a machine with the tools present.

**Acceptance Scenarios**:

1. **Given** a checking tool is not installed locally, **When** the contributor runs that check, **Then** the check still produces a verdict, using the same configuration and reporting the same violations.
2. **Given** a checking tool is installed locally, **When** the contributor runs that check, **Then** the locally installed tool is used in preference to any fallback.
3. **Given** two runs of the same check on the same content at different times, **When** their results are compared, **Then** the verdict and the violation list are identical.

---

### User Story 3 - Understand why each standard is set the way it is (Priority: P2)

A future maintainer opens a configuration and finds a setting that differs from the tool's default. They want to know whether that was a deliberate decision or an accident, without asking the person who wrote it.

**Why this priority**: Lower than the checks themselves — the repository is usable without it — but without it, every non-default setting eventually gets "corrected" by someone who assumed it was a mistake.

**Independent Test**: Testable by picking any non-default setting in any committed configuration and confirming a written record states what it does and why it was chosen.

**Acceptance Scenarios**:

1. **Given** a configuration setting that departs from the tool's documented default, **When** a reader consults the written record, **Then** they find the reason that setting was chosen.
2. **Given** a reader wants to know where a standard came from, **When** they consult the written record, **Then** they find a citation to the upstream documentation it was based on.

---

### User Story 4 - Install the repository as a Claude Code plugin (Priority: P2)

A user wants the toolkit this repository advertises. They install the repository as a Claude Code plugin and Claude Code recognises it under the name `claude-code-devkit`.

**Why this priority**: The README already promises this, so the gap is a correctness problem rather than a new capability — but nothing in Stories 1 to 3 depends on it, so it can ship separately.

**Independent Test**: Testable by installing the repository as a plugin and confirming Claude Code lists it by name, with no reference to the quality checks at all.

**Acceptance Scenarios**:

1. **Given** the repository is installed as a Claude Code plugin, **When** the user lists their installed plugins, **Then** `claude-code-devkit` appears.
2. **Given** the plugin manifest is malformed or missing a required field, **When** installation is attempted, **Then** the failure is reported rather than the plugin loading in a partial state.

---

### Edge Cases

- A content type has no files present in the repository yet: the check for that type reports success rather than failing on an empty input set.
- A file is in a directory that is excluded from scope: the check does not report violations for it, and does not fail because it could not read it.
- Neither the tool nor its fallback is available on the machine running the check: the check fails with a non-zero status naming both, and the aggregate run stops (FR-011).
- A file is unreadable or malformed to the point that the tool cannot parse it: this is a failure with a named location, not a silent skip.
- Two content standards both claim a file (for example a structured-data file that is also whitespace-governed): the file is checked by both, and both must pass.
- A content kind is formatted by one check and linted by another: both run, and neither's rewrite may undo the other's, so the two rule sets must not overlap (FR-022).
- A formatting add-on component cannot be resolved on the machine running the check: that content kind falls back to the mechanism that carries the add-on pinned, and the check says so in its output. Coverage is not reduced, and the verdict is the same as on a machine where the add-on was present (FR-023, FR-008).
- Neither the add-on nor the fallback is reachable: this is FR-011's hard failure, naming both, and the aggregate run stops.
- The per-check ignore declarations disagree about a file both checks govern: the verification required by FR-013b fails, rather than the disagreement surfacing later as a file nobody checks.
- A capability extension is installed but disabled: FR-024 is unmet, because it requires the capabilities be enabled and not merely present.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: The repository MUST carry one committed, documented standard for each of the following kinds of content it holds: documentation text, structured configuration data, shell scripts, Python sources, and repository-wide whitespace and line-ending conventions.
- **FR-002**: Each standard MUST be expressed in a committed configuration file at a documented location, so that the verdict does not depend on an undeclared tool default, on editor settings, or on per-developer configuration. A tool's documented default MAY be relied on without being restated in that file, provided the tool's version is pinned exactly and the relied-on default appears in the written record required by FR-014.
- **FR-003**: Each content type MUST be checkable by a single command run from the repository root, taking no arguments.
- **FR-004**: The repository MUST provide one aggregate command that runs every check.
- **FR-005**: A check MUST exit with a non-zero status when it finds a violation, and a zero status when it does not.
- **FR-005a**: A fix invocation that rewrote one or more files into conformance MUST exit with a zero status. The non-zero rule in FR-005 governs violations left unresolved, not violations corrected.
- **FR-006**: A check MUST name the file and, where the content type has line granularity, the line of every violation it reports.
- **FR-007**: The aggregate command MUST stop at the first failing check rather than continuing and reporting a combined result.
- **FR-008**: A check MUST produce the same verdict and the same violation list whether or not the corresponding tool is installed on the machine running it.
- **FR-009**: Where a tool is installed locally, a check MUST use it in preference to any fallback mechanism.
- **FR-010**: A check MUST NOT require the person running it to install a language runtime, package manager, or dependency set beforehand, beyond what the fallback mechanism itself needs.
- **FR-011**: When a check can reach neither the locally installed tool nor its fallback, it MUST exit with a non-zero status naming both the tool and the fallback that were unavailable, and the aggregate command MUST stop there. A check MUST NOT report success, and MUST NOT silently skip itself, when it did not evaluate the content.
- **FR-012**: A command MUST report violations without modifying any file when invoked with no arguments, and MUST rewrite files into conformance when invoked with an explicit fix flag. Reporting is the default; rewriting is never implicit.
- **FR-012a**: Where a content standard has no automatic fix available, invoking the fix flag MUST report that fact and leave the file untouched, rather than failing as though the flag were invalid.
- **FR-013**: The scope of content checked MUST be the repository minus version-control internals, generated content, vendored dependencies, and agent-local state. Excluded at minimum: the version-control directory, the spec-tooling directory's own generated scripts and templates, agent-local logs and machine-local settings, agent memory directories, and any dependency directory fetched rather than authored.
- **FR-013a**: Each check MUST declare, in its own committed configuration, which paths it does not examine. A check whose tool offers a mechanism for declaring skipped paths MUST use it rather than relying on the caller to pass a filtered file list.
- **FR-013b**: All checks MUST nonetheless agree on scope. Because FR-013a distributes the declaration across several configurations, this agreement is a property that MUST be verified rather than one that holds by construction, and the repository MUST carry a means of verifying it that fails when two checks disagree about a file both govern.
- **FR-013c**: Where a check's tool offers no mechanism for declaring skipped paths, that absence MUST be recorded in the written record required by FR-014, together with what the check relies on instead. It MUST NOT be worked around silently.
- **FR-014**: The repository MUST carry a written record of each standard's chosen settings, stating for every setting that departs from the tool's documented default what it does and why it was chosen.
- **FR-015**: That written record MUST cite the upstream documentation each standard was derived from.
- **FR-016**: The repository MUST be installable as a Claude Code plugin and MUST be recognised under the name `claude-code-devkit`.
- **FR-017**: The scripts that run the checks MUST themselves be subject to the shell-script standard they enforce.
- **FR-018**: Machine-local and agent-local state MUST be excluded from version control rather than committed. This MUST cover the state created by the spec-tooling extensions of FR-024 in addition to what is already excluded.
- **FR-019**: The formatting standard's committed configuration MUST state only those formatting option values that differ from its tool's documented default. An option whose value equals the default MUST be omitted, and the fact that the default is relied on MUST be recorded in the written record required by FR-014. This rule governs option values only: the declaration binding a content kind to the code that formats it MAY be stated explicitly even where the tool would infer the same binding, because omitting it defers to an add-on component's own registry rather than to a documented default, and because the content kinds FR-021 names must be legible in the configuration that governs them.
- **FR-020**: Two formatting decisions are fixed, and both differ from the tool's documented default: multi-line literals MUST carry no trailing separator, and string literals MUST use single quotes wherever the format being written permits them.
- **FR-021**: The formatting standard MUST cover four content kinds: prose markup, data serialization, markup-tree documents, and shell scripts. Prose markup, data serialization and shell scripts exist in the repository today; markup-tree documents do not, and the standard governs them from the point the first one is added.
- **FR-022**: Prose markup and data serialization are each governed today by a linting standard that also carries formatting-adjacent rules. Those rules MUST move out of the linting standard, so that each of those content kinds ends with exactly one configuration governing its formatting and exactly one governing its linting, and no file is rewritten by two checks. A file MAY still be _examined_ by two or more checks -- the pre-existing edge case where a structured-data file is also whitespace-governed is unaffected. What this requirement forbids is two checks _rewriting_ one file, where the result depends on which ran last.
- **FR-023**: Where a content kind's formatting requires an add-on component that is not part of the base formatting tool, the check MUST still run with no installation as a precondition, and MUST report which add-on components resolved, so that an absent component cannot be mistaken for a clean result. An absent add-on component MUST be treated exactly as an absent tool: that content kind falls back to the mechanism of FR-008, where the add-on is available at a pinned version, and the check MUST report that it fell back. A check MUST NOT continue with reduced coverage, and MUST NOT fail merely because an add-on component was absent while a fallback was reachable.
- **FR-024**: The repository's spec-tooling MUST have installed and enabled a set of capability extensions covering all of: coding-agent context management, pre-specification idea assessment, bug triage, git branch workflow, evidence-first discipline gates, and token budgeting.
- **FR-025**: The order in which the extensions' hooks execute at any given lifecycle point MUST be deterministic and MUST be declared in committed configuration as an explicit numeric rank per extension, rather than left to the order in which extensions happen to be discovered.
- **FR-025a**: Those ranks MUST be assigned on a stated principle rather than arbitrarily: hooks that only observe run before hooks that modify the repository, and the principle MUST be written down where the ranks are, so that the rank for a later extension can be derived rather than guessed.
- **FR-026**: Any extension obtained from outside the vetted catalog MUST have its provenance recorded in the written record required by FR-014: where it came from, which version was installed, and what it is permitted to change.
- **FR-027**: The per-item artifacts the assessment and bug-triage extensions write MUST be committed, on the same footing as the feature artifacts under the specification directory, and MUST therefore be in scope for the checks. FR-018's exclusion covers the extensions' machine-local run state, not their output.

### Key Entities

- **Content standard**: the rule set governing one kind of content. Has a name, a committed configuration location, a documented rationale, and exactly one check that evaluates it.
- **Check**: a runnable evaluation of one content standard against the repository. Produces a verdict, an exit status, and a list of located violations.
- **Aggregate check**: the single entry point that runs every check in a defined order and stops at the first failure.
- **Plugin manifest**: the declaration that makes this repository installable and identifiable to Claude Code under its name.
- **Concern**: what a check evaluates about a content kind -- its formatting, or its linting. A content kind may have one configuration per concern and no more; the two concerns evaluate disjoint properties, and neither substitutes for the other.
- **Add-on component**: a unit that extends the formatting tool to a content kind its base does not handle. Has a pinned version, and a resolution state at run time that the check reports.
- **Capability extension**: a unit that adds commands and lifecycle hooks to the repository's spec-tooling. Has an identifier, a version, a provenance, a declared effect on the repository, and a position in the hook order.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: A contributor who has never worked in this repository can determine whether their change conforms in 1 command, 0 setup steps and 0 arguments, where that command is named in `README.md`'s quality-checks section. Verifiable by counting: one documented command, no install step preceding it, no argument required.
- **SC-002**: For every content standard in FR-001 and every formatting kind in FR-021, an introduced violation is caught: 8 of 8 report a failure naming the offending location when given non-conforming content.
- **SC-003**: The same content produces the same verdict on a machine with all tools installed and on a machine with none installed: 0 differences in verdict or violation list across the two.
- **SC-004**: Every non-default setting across all committed standards has a written rationale: 100% coverage, verifiable by comparing each configuration against the tool's documented defaults.
- **SC-005**: The repository is recognised by Claude Code under the name `claude-code-devkit` on a first-time install, with no manual repair step.
- **SC-006**: The aggregate check, run against the repository's own conforming content, completes and reports success without human interpretation of its output.
- **SC-007**: Running any command with no arguments leaves the working tree byte-for-byte unchanged: 0 files modified, verifiable by comparing the tree before and after.
- **SC-008**: Every check agrees on which files are in scope: 0 files reported by one check and ignored by another where both govern that file type. Since FR-013a distributes the scope declaration, this is verified by comparison rather than assumed, and the comparison is repeatable.
- **SC-009**: Every content kind named in FR-021 has exactly one configuration governing its formatting and, where it is also linted, exactly one governing its linting: 0 content kinds with two of either.
- **SC-010**: The formatting configuration contains no formatting option value equal to its tool's documented default: 0 redundant values, verifiable by comparing each against the pinned tool version's documented defaults. Content-kind bindings are excluded from the count, per FR-019, and the written record states which of them the tool would have inferred.
- **SC-011**: All six capabilities in FR-024 are present and enabled, and the hook order at every lifecycle point is the same on two consecutive inspections: 6 of 6 capabilities enabled, 0 ordering differences between inspections.
- **SC-012**: Every hook rank is derivable from the written principle: 0 ranks that place a modifying hook before an observing one at the same lifecycle point.
- **SC-013**: A machine with the base formatting tool but no add-on components produces the same verdict and violation list as one with all of them: 0 differences, and the output states which content kinds fell back.
- **SC-014**: The written record names every check whose tool offers no mechanism for declaring skipped paths, and the scope-agreement verification counts 0 of those as agreeing: every such check is reported as unverifiable on every run.
- **SC-015**: Every extension installed from outside the vetted catalog has its source URL, installed version and declared effect in the written record: 2 of 2.

## Assumptions

Chosen as reasonable defaults where the feature description did not specify. Each is a real decision and can be revisited.

- **Whitespace and line-ending conventions are a deliverable of this feature**, not research only. The description listed them among the things to investigate but omitted them from the list of things to produce; producing them costs little and leaving them out would make FR-001's coverage incomplete.
- **Both a per-content-type command and one aggregate command are provided.** The description asked for scripts, plural, in a scripts directory; a per-type command is what makes a single failing check re-runnable in isolation, and the aggregate is what FR-004 requires.
- **Installing the plugin directly from this repository is sufficient for the first version.** Publication to a plugin marketplace is not assumed and is treated as out of scope.
- **The first version of the plugin ships the manifest and whatever the repository already contains.** The repository currently holds no commands, agents, skills or MCP servers of its own, so none are invented for this feature; the plugin becomes installable, and its contents grow later.
- **The checks are the repository's tests.** No separate test framework is assumed; the aggregate check run from a clean checkout is the verification step.
- **Markup-tree documents are governed before any exist.** The repository holds none today. Writing the standard now costs one configuration block and means the first such file added is governed on arrival rather than after someone notices.
- **The formatting and linting concerns are separated per content kind, not merged into one tool.** Each tool keeps the concern it is good at; the alternative -- one tool taking a content kind wholesale -- would lose checks the other performs and that the first does not replace.
- **A container runtime is an acceptable fallback dependency.** FR-010 excludes language runtimes and package managers from what a contributor must install, but the fallback mechanism itself is permitted its own single prerequisite.

## Out of Scope

- Checking or reformatting content this repository does not own.
- Enforcing these standards on other repositories.
- Publishing the plugin to a marketplace.
- Adding commands, agents, skills or MCP servers to the plugin beyond making it installable.
- Wiring the checks into a continuous integration service.
- Adopting the workflows the newly installed capability extensions provide. This feature installs, enables and orders them; using them is later work.
- Adding any content standard beyond the four formatting kinds in FR-021.
- Changing the tool-resolution order, the behaviour when nothing is available, the exit statuses, or the plugin manifest.
- Changing which parts of the repository are in scope for checking. Only where that scope is declared changes.
