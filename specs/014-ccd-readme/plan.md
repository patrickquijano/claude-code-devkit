# Implementation Plan: ccd-readme

**Branch**: `014-ccd-readme` | **Date**: 2026-09-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/014-ccd-readme/spec.md`

## Summary

A Claude Code plugin skill that generates or improves README.md files using only verified repository artifacts, with a safety-gated license decision flow. Architecture separates orchestration (thin SKILL.md) from computation (POSIX shell scripts) and content (templates/references), satisfying Constitution Principle VII's verified-content and script-delegation requirements.

## Technical Context

**Language/Version**: POSIX sh (IEEE Std 1003.1-2017) + Markdown

**Primary Dependencies**: Claude Code plugin system, AskUserQuestion tool, SPDX license list (fetched at runtime)

**Storage**: Filesystem only — reads project artifacts, writes README.md and optionally LICENSE.md in target directory

**Testing**: ShellCheck in POSIX mode, manual validation via quickstart scenarios, idempotency verification through re-run comparison

**Target Platform**: Any platform where Claude Code runs (macOS, Linux, Windows via WSL)

**Project Type**: Claude Code plugin skill (Markdown + shell scripts, no runtime dependencies)

**Performance Goals**: Full README generation flow completes in under 5 minutes for typical projects (SC-008)

**Constraints**: SKILL.md under 500 lines (FR-009); zero inline shell logic in SKILL.md (FR-008); all inspection/validation in scripts (FR-008); POSIX sh only (Constitution IV); no hallucination (FR-002); no silent license selection (FR-005–FR-006)

**Scale/Scope**: Single-project directories; monorepos detected and deferred to user clarification

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

| Principle                     | Status | Notes                                                                                                                                      |
| ----------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| I. Tooling Independence       | PASS   | Scripts use POSIX sh only; no package managers or global installs required                                                                 |
| II. Fail Fast                 | PASS   | All scripts exit non-zero on first failure; no masked errors                                                                               |
| III. Pinned, Official Images  | N/A    | No container images used                                                                                                                   |
| IV. POSIX Shell Only          | PASS   | All scripts target POSIX sh; ShellCheck validation in CI                                                                                   |
| V. Configuration Is Committed | PASS   | No runtime configuration; all templates and references committed                                                                           |
| VI. Spec-Driven Change        | PASS   | This plan is the spec-driven artifact for feature work                                                                                     |
| VII. Verified Content Only    | PASS   | All output derived from verified artifacts; license flow gated by AskUserQuestion; deterministic logic delegated to scripts; SKILL.md thin |

No violations. Complexity tracking section not needed.

## Project Structure

### Documentation (this feature)

```text
specs/014-ccd-readme/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (skill deliverable)

```text
skills/ccd-readme/
├── SKILL.md                          # Thin orchestrator (<500 lines)
├── scripts/
│   ├── inspect-project.sh            # Deterministic repo inspection
│   └── validate-readme.sh            # Post-generation validation
├── templates/
│   ├── readme-base.md                # Structural skeleton
│   ├── license-MIT.md
│   ├── license-Apache-2.0.md
│   ├── license-ISC.md
│   └── license-GPL-3.0.md
└── references/
    ├── readme-best-practices.md      # Authoritative source citations
    ├── license-guide.md              # Decision criteria + non-legal-advice notice
    └── skill-structure.md            # Links to .claude/rules/skill-authoring.md
```

**Structure Decision**: Single skill directory under `skills/ccd-readme/` following the `ccd-` prefix convention (FR-015). Three subdirectories enforce progressive disclosure (FR-010): `scripts/` for deterministic computation, `templates/` for reusable structural content, `references/` for guidance and citations. SKILL.md remains thin (FR-009) containing only triggers, workflow steps, safeguards, resource routing, and output format.

## Complexity Tracking

No violations to justify.
