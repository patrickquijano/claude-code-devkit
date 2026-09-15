# Feature Specification: ccd-readme

**Feature Branch**: `014-ccd-readme`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "WHAT: A Claude Code plugin skill named ccd-readme that inspects a project directory and either creates a new README.md or improves an existing one, using only verified repository information. It determines whether licensing information is missing or inconsistent and, if a license decision is needed, lazy-loads standard templates from authoritative sources, presents options with a recommendation and non-legal-advice notice, and creates or updates LICENSE.md only after explicit user selection. WHY: Projects often lack README files or have outdated ones; generating them from verified repo data avoids hallucination and preserves accurate existing content. The skill must never infer unsupported project details, silently select a license, overwrite valuable content, or output unrelated information."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Generate README for Uninitialized Project (Priority: P1)

A developer invokes `/ccd-readme` in a project directory that has no README.md. The skill inspects the repository structure, package manifests, CI configuration, and existing documentation to produce a complete README covering project purpose, installation, usage, and architecture — all derived solely from verified files on disk. If no license file exists, the skill asks the developer to choose one before writing.

**Why this priority**: This is the primary value proposition — bootstrapping documentation where none exists. Without this flow the skill has no entry point.

**Independent Test**: Invoke `/ccd-readme` in a fresh clone with no README.md and verify a complete, accurate README.md is produced containing only information traceable to repository files.

**Acceptance Scenarios**:

1. **Given** a project directory with no README.md and no LICENSE file, **When** the user invokes `/ccd-readme`, **Then** the skill inspects verified artifacts, presents license options via AskUserQuestion with a recommendation and non-legal-advice notice, and after selection produces a README.md and LICENSE.md whose content is fully traceable to repository files.
2. **Given** a project directory with no README.md but an existing LICENSE file, **When** the user invokes `/ccd-readme`, **Then** the skill produces a README.md that references the existing license without prompting for license selection.
3. **Given** a project directory with no recognizable project artifacts (empty directory), **When** the user invokes `/ccd-readme`, **Then** the skill reports that insufficient verified information exists to generate a README and asks a focused question rather than producing speculative content.

---

### User Story 2 - Improve Existing README (Priority: P2)

A developer invokes `/ccd-readme` in a project that already has a README.md. The skill compares the existing content against verified repository state, identifies gaps or inaccuracies, preserves accurate sections, and proposes additions or corrections. Nothing accurate is removed or overwritten.

**Why this priority**: Many projects have stale READMEs. Improving existing content without destroying accurate material is the second most common use case.

**Independent Test**: Invoke `/ccd-readme` in a project with a partial or outdated README.md and verify the output preserves accurate existing sections while adding or correcting content based on current repository state.

**Acceptance Scenarios**:

1. **Given** a project with an existing README.md that is partially accurate, **When** the user invokes `/ccd-readme`, **Then** the skill preserves all accurate existing content and adds or corrects sections based on verified repository artifacts.
2. **Given** a project with an existing README.md that is fully accurate and complete, **When** the user invokes `/ccd-readme`, **Then** the skill reports no changes needed and does not modify the file.
3. **Given** a project with an existing README.md containing inaccurate information, **When** the user invokes `/ccd-readme`, **Then** the skill flags the specific inaccuracies with evidence and proposes corrections without silently overwriting.

---

### User Story 3 - License Decision Flow (Priority: P3)

A developer invokes `/ccd-readme` in a project where licensing information is missing or inconsistent. The skill detects this condition, lazy-loads standard license templates from authoritative sources, presents options through AskUserQuestion with a recommendation and justification, includes a non-legal-advice notice, and creates or updates LICENSE.md only after explicit user selection.

**Why this priority**: License handling is a safety-critical sub-flow governed by Principle VII. It must work correctly but is secondary to the core README generation.

**Independent Test**: Invoke `/ccd-readme` in a project with no license file and verify the skill presents options via AskUserQuestion, includes a non-legal-advice notice, and writes LICENSE.md only after the user selects an option.

**Acceptance Scenarios**:

1. **Given** a project with no LICENSE file and no license metadata in package manifests, **When** the user invokes `/ccd-readme`, **Then** the skill presents at least three standard license options via AskUserQuestion with a recommendation, justification, and non-legal-advice notice, and creates LICENSE.md only after explicit selection.
2. **Given** a project where package.json declares MIT but no LICENSE file exists, **When** the user invokes `/ccd-readme`, **Then** the skill flags the inconsistency and offers to create a matching LICENSE.md or let the user choose differently.
3. **Given** a project with an existing LICENSE file that matches declared metadata, **When** the user invokes `/ccd-readme`, **Then** the skill does not prompt for license selection.

---

### Edge Cases

- What happens when the project directory contains no recognizable artifacts (no package manifest, no CI config, no source files)? The skill MUST report insufficient information and ask a focused question rather than hallucinate.
- How does the skill handle a README.md written in a language other than English? The skill preserves the existing language and generates new content in the same language when detectable, falling back to English otherwise.
- What happens when the user declines to select a license when prompted? The skill proceeds with README generation, omits the license section, and notes in output that licensing was skipped.
- How does the skill handle symlinks, monorepos, or nested project directories? The skill inspects only the top-level project directory and reports when nested structures are detected, asking the user to clarify scope.

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: System MUST inspect the target project directory and extract project metadata exclusively from verified repository artifacts (files, manifests, configuration, existing documentation).
- **FR-002**: System MUST NOT infer, assume, or hallucinate project details that are not present in verified repository artifacts.
- **FR-003**: System MUST preserve all accurate existing content when modifying an existing README.md.
- **FR-004**: System MUST detect whether licensing information is missing or inconsistent across repository artifacts.
- **FR-005**: System MUST present license options through `AskUserQuestion` with exactly one recommended option, a concise justification, and a non-legal-advice notice when a license decision is needed.
- **FR-006**: System MUST create or update LICENSE.md only after explicit user selection via `AskUserQuestion`.
- **FR-007**: System MUST lazy-load license templates from authoritative sources only when the license decision flow is triggered.
- **FR-008**: System MUST delegate deterministic inspection, validation, and formatting logic to scripts under `scripts/` rather than embedding it in SKILL.md prose.
- **FR-009**: System MUST keep SKILL.md thin (under 500 lines), containing only triggers, workflow steps, safeguards, resource routing, and output requirements.
- **FR-010**: System MUST place detailed guidance, checklists, and source citations in `references/` and reusable structural templates in `templates/`.
- **FR-011**: System MUST ask a focused question via `AskUserQuestion` when essential project information cannot be verified from repository artifacts, rather than producing speculative content.
- **FR-012**: System MUST produce idempotent output — re-running on an unchanged repository produces the same result.
- **FR-013**: System MUST be non-destructive — no file is deleted or overwritten without preserving recoverable content.
- **FR-014**: System MUST NOT output information unrelated to the project's verified repository state.
- **FR-015**: System MUST follow the `ccd-` prefix naming convention and resolve as `claude-code-devkit:ccd-readme`.

### Key Entities

- **ProjectInspectionResult**: Structured representation of verified repository metadata extracted by inspection scripts — project name, description, language, dependencies, CI status, existing docs paths, license state.
- **LicenseDecision**: Record of the user's license selection including chosen SPDX identifier, recommendation presented, justification shown, and non-legal-advice notice displayed.
- **ReadmeSection**: A discrete section of the README (title, install, usage, architecture, contributing, license) with provenance tracking indicating which verified artifact each section derives from.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: 100% of README content sections are traceable to at least one verified repository artifact.
- **SC-002**: Zero instances of hallucinated or inferred project details in generated output across test suite.
- **SC-003**: Existing accurate README content is preserved in 100% of improvement runs.
- **SC-004**: License files are created or modified only after explicit user selection in 100% of runs where licensing is addressed.
- **SC-005**: SKILL.md remains under 500 lines after implementation.
- **SC-006**: All deterministic inspection and validation logic resides in scripts, with zero inline shell logic in SKILL.md.
- **SC-007**: Re-running the skill on an unchanged repository produces byte-identical output in 100% of cases.
- **SC-008**: Users can complete the full README generation flow (including license selection) in under 5 minutes for a typical project.

## Assumptions

- The target project directory is accessible and readable by the Claude Code session.
- Standard project artifacts (package.json, Cargo.toml, pyproject.toml, Makefile, Dockerfile, .github/, etc.) follow conventional structures that inspection scripts can parse.
- Authoritative license templates are available from SPDX or OSI sources and can be fetched at runtime.
- The user has permission to write files in the target project directory.
- The Claude Code `AskUserQuestion` tool is available in the session.
- Existing README content in non-English languages can be detected via simple heuristics (character set, common phrases) without requiring a translation API.
- The `ccd-` prefix convention and skill-authoring rules in `.claude/rules/skill-authoring.md` remain stable during implementation.
