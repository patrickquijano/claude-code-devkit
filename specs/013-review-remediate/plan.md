# Implementation Plan: Change-Request Review and Remediation

**Branch**: `013-review-remediate` | **Date**: 2026-09-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/013-review-remediate/spec.md`

## Summary

Claude Code plugin skill (`ccd-review-remediate`) reviews current GitHub PR or GitLab MR, publishes evidence-based findings with severity/confidence/category classification, remediates when authorized, re-reviews up to five cycles, optionally merges. Tech stack: POSIX sh scripts for deterministic discovery/validation/formatting; Markdown templates for findings, approval and remediation summaries; lazy-loaded reference files for platform-specific commands and review checklists. Forge detection via existing `forge-detect.sh`; context collection via `gh` and `glab` CLIs verified at preflight. Validation uses repository's own `scripts/lint.sh` and `scripts/selftest.sh`.

## Technical Context

- **Language/Version**: POSIX sh (IEEE Std 1003.1-2017), Markdown
- **Primary Dependencies**: `gh` CLI (GitHub), `glab` CLI (GitLab), git
- **Storage**: Filesystem only — state file (`.specify/.speckit-run-state.json`), finding register, audit entries
- **Testing**: `scripts/lint.sh` (seven checks including shellcheck), `scripts/selftest.sh` (rejection proofs)
- **Target Platform**: macOS, Linux (any POSIX-compliant shell environment with git and forge CLI)
- **Project Type**: Claude Code plugin skill
- **Performance Goals**: Preflight under 5 seconds; full review context collection under 30 seconds on typical PR/MR
- **Constraints**: No npm/pip prerequisites; no container images required; all scripts pass `shellcheck --shell=sh`; no bashisms
- **Scale/Scope**: Single change request per invocation; up to five review/remediate cycles; findings unbounded but typically under 50 per review

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

| Principle                  | Application                                                                              | Status    |
| -------------------------- | ---------------------------------------------------------------------------------------- | --------- |
| I. Tooling Independence    | All scripts use POSIX sh + native CLI (`gh`, `glab`, `git`). No npm/pip prerequisites.   | Compliant |
| II. Fail Fast              | Every script exits non-zero on first failure. No masked exit codes.                      | Compliant |
| III. Pinned Images         | No container images needed for this skill. If added later, pin tag+digest per principle. | N/A       |
| IV. POSIX Shell Only       | All scripts pass `shellcheck --shell=sh`. No bashisms.                                   | Compliant |
| V. Configuration Committed | Severity model, review checklist, templates all committed. No runtime defaults.          | Compliant |
| VI. Spec-Driven Change     | This feature has spec, plan, tasks. Implementation follows task list.                    | Compliant |

No violations. Complexity Tracking section empty.

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

### Source Code (repository root)

```text
skills/ccd-review-remediate/
├── SKILL.md                          # Thin entry point; lazy-loads references
├── evaluations.md                    # Validation scenarios for skill authors
├── templates/
│   ├── review-findings.md            # Finding output format
│   ├── approval-summary.md           # Pass verdict summary
│   └── remediation-summary.md        # Fix mapping per finding ID
├── reference/
│   ├── review-checklist.md           # Eleven review dimensions
│   ├── severity-model.md             # Six severities, three confidences
│   ├── github.md                     # gh CLI commands for review/publish/merge
│   ├── gitlab.md                     # glab CLI commands for review/publish/merge
│   └── validation.md                 # Validation-command precedence (CHK005)
└── scripts/
    ├── preflight.sh                  # Forge detect, CLI auth, CR discovery
    ├── collect-context.sh            # Gather diff, comments, CI, approvals
    ├── verify-repository.sh          # Run repo validation command
    └── permission-check.sh           # Pre-write permission probe (CHK010)
```

**Structure Decision**: Follows resolved conflicts from Step 2 — `reference/` singular, no README.md (evaluations.md instead), no skill-local validator (repo `scripts/lint.sh` gates all skills). Shared scripts (`forge-detect.sh`, `branch-options.sh`) reached via `${CLAUDE_PLUGIN_ROOT}` rather than copied.
<!-- token-budget: compacted (level=medium) on 2026-09-13T09:59:00Z; original at plan.full.md -->
