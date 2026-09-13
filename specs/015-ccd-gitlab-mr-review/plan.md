# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: POSIX sh (shell scripts), Markdown (templates)

**Primary Dependencies**: glab CLI (GitLab interactions), git (repository state)

**Storage**: N/A — read-only skill; no persistent storage beyond posted MR comments

**Testing**: Manual validation against live GitLab MRs per quickstart.md scenarios

**Target Platform**: Any platform with glab CLI and git installed (macOS, Linux)

**Project Type**: Claude Code plugin skill

**Performance Goals**: Preflight completes within seconds; review analysis bounded by diff size

**Constraints**: No source code modification; no MR metadata changes; POSIX-compliant scripts

**Scale/Scope**: Single MR per invocation; one structured comment posted per review

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- [x] **I. Testable Requirements**: All FRs in spec.md have acceptance scenarios; SCs are measurable.
- [x] **II. Single Source of Truth**: Review findings format defined once in contracts/skill-interface.md; spec references it.
- [x] **III. Technology-Agnostic Spec**: spec.md names glab as the interface (per user clarification) but no shell syntax, script bodies, or template content.
- [x] **IV. Quality Gates**: checklists/review-quality.md validates spec quality; quickstart.md defines manual validation scenarios.
- [x] **V. Configuration Is Committed**: Skill ships scripts/ and templates/ inside the plugin directory; no runtime-generated config.
- [x] **VI. Spec-Driven Change**: This plan implements spec.md FR-001 through FR-016 with no added requirements.
- [x] **VII. Verified Content Only**: FR-012 and FR-013 prohibit hallucination; contract requires every finding traceable to diff content.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Skill Directory: `skills/ccd-gitlab-mr-review/`

```text
skills/ccd-gitlab-mr-review/
├── SKILL.md                    # Skill instructions and workflow
├── evaluations.md              # Regression scenarios
├── scripts/
│   ├── preflight.sh            # Environment validation and MR detection
│   ├── post-comment.sh         # Safe comment posting via temp file
│   └── add-reviewer.sh         # Reviewer addition with + prefix safety
└── templates/
    ├── review-summary.md       # Change-request summary comment template
    └── approval-comment.md     # Approval comment template
```

**Structure Decision**: Follows `ccd-gitlab-mr` skill layout per R-003. Scripts are POSIX sh, invoked via `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/<name>.sh"`. Templates referenced by scripts and SKILL.md for output formatting. No source code directories — this is a plugin skill, not an application.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation                  | Why Needed         | Simpler Alternative Rejected Because |
| -------------------------- | ------------------ | ------------------------------------ |
| [e.g., 4th project]        | [current need]     | [why 3 projects insufficient]        |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient]  |
