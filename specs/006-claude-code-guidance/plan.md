# Implementation Plan: Claude Code guidance and pipeline gating

**Branch**: `006-claude-code-guidance` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-claude-code-guidance/spec.md`

## Summary

Two independent halves. The first completes the repository's recorded Claude Code practices: a new document covering project structure — the one subject the existing three do not treat — a path-scoped rule that puts the authoring practices in front of an author while they edit a governed file, and corrections to the two existing practice documents where the current documentation no longer supports what they say. The second reworks `skills/ccd-speckit-run`: it becomes reachable by the model as well as by the user, gates each phase separately instead of once up front, may dispatch up to ten concurrent evidence readers, detects a conflicted working tree after each step and phase and hands off when it finds one, and asks where to leave the workspace once a review request exists.

The two halves share one obligation: 42 statements across the repository become false, and each is corrected in place or superseded by a new record according to a stated criterion.

## Technical Context

**Language/Version**: Markdown, YAML frontmatter, and POSIX `sh` (constitution Principle IV). No programming language runtime is introduced.

**Primary Dependencies**: None added. The one new executable artifact is a POSIX `sh` script depending only on `git` and shell builtins.

**Storage**: Files on disk. The pipeline's run state is a JSON file at `.specify/.speckit-run-state.json`, gitignored, already existing.

**Testing**: `sh scripts/lint.sh` — seven checks, first failure stops the run. There is no separate test runner and none is added; `specs/001-quality-gate-plugin/plan.md:128` rejected inventing `src/` or `tests/` for this repository and nothing here changes that.

**Target Platform**: Any POSIX shell environment with `git`. The quality gate additionally requires either each tool natively or a container runtime, per Principle I.

**Project Type**: Documentation and agent-workflow toolkit. No application code.

**Performance Goals**: One only, and it is why the conflict check is affordable at every boundary: two filesystem tests plus one `git` plumbing call, no network, no working-tree scan.

**Constraints**: `CLAUDE.md` under 200 lines and its section order unchanged (FR-007, FR-007a). `SKILL.md` under 500 lines. `.specify/memory/constitution.md` must not be amended — `scripts/lint-citations.sh` checks three `.github` templates against its lines 167-168 and 189-190 verbatim, and any edit there breaks six citation markers at once. Prose is not hard-wrapped: MD013 is off by design and Prettier's `proseWrap` is unset, so it defaults to preserve.

**Scale/Scope**: 3 new files, 9 modified files, 42 enumerated statement corrections across two buckets, 6 skills of which 1 changes frontmatter.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Evaluated against `.specify/memory/constitution.md` **v1.2.0**, ratified 2026-09-02, six principles.

| Principle                                    | Verdict | Evidence                                                                                                                                                                                                                                                                   |
| -------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **I. Tooling Independence (NON-NEGOTIABLE)** | PASS    | The one new script uses only POSIX `sh`, `git` and shell builtins. It introduces no language package manager, no virtual environment and no global install step. No quality check is added or altered.                                                                     |
| **II. Fail Fast**                            | PASS    | `conflict-state.sh` exits non-zero on the first failing condition, masks no exit status behind a pipeline or subshell, and continues no further work after a failure. Its `git ls-files -u` invocation is checked, not piped into a counter that would swallow the status. |
| **III. Pinned, Official Images**             | PASS    | No container image is referenced, added or changed.                                                                                                                                                                                                                        |
| **IV. POSIX Shell Only**                     | PASS    | `conflict-state.sh` is POSIX `sh`, indented with tabs, and lands under `skills/` which no exclusion declaration names — so the `shell` check reaches it and must report zero findings in POSIX mode.                                                                       |
| **V. Configuration Is Committed**            | PASS    | No linter or formatter configuration changes. No behaviour is made to depend on an undeclared default, an editor setting, or per-developer configuration. Every file this feature writes falls under configuration already committed.                                      |
| **VI. Spec-Driven Change**                   | PASS    | `spec.md`, this `plan.md` and a `tasks.md` are all on disk before implementation begins.                                                                                                                                                                                   |

**Quality Gate Requirements section** — PASS. Each new file's content kind already has exactly one governing formatting configuration and one linting configuration: Markdown by `.prettierrc.json` and `.markdownlint-cli2.jsonc`, shell by `.prettierrc.json` and `.shellcheckrc`. No second governing file is introduced for either concern. The new script is subject to the shell static analysis check, satisfying "The tooling is not exempt from the standards it enforces."

**Development Workflow section** — PASS. `006-claude-code-guidance` is cut from `main`, the repository's default branch. Artifacts live under `specs/006-claude-code-guidance/`. `sh scripts/lint.sh` runs and must pass before the change is proposed for review. Machine-local state — the run-state file and the dirty snapshot — is gitignored rather than committed.

**Post-design re-check**: re-run after Phase 1. Result recorded at the end of this section.

**Post-design result**: PASS, unchanged. The Phase 1 artifacts add two contract documents and a quickstart, none of which introduce a tool, an image, a configuration file or a script. No violation arose during design.

## Project Structure

### Documentation (this feature)

```text
specs/006-claude-code-guidance/
├── plan.md                          # This file
├── spec.md                          # Phase 2 output, clarified in Phase 3
├── research.md                      # Phase 0 output
├── data-model.md                    # Phase 1 output
├── quickstart.md                    # Phase 1 output
├── checklists/
│   ├── requirements.md              # speckit-specify's own quality gate
│   └── requirements-quality.md      # Phase 4 output, 46 items
├── contracts/
│   ├── skill-names.md               # supersedes specs/005-.../contracts/skill-names.md
│   ├── falsified-statements.md      # the 42-item enumeration FR-028 is checked against
│   └── conflict-state-cli.md        # the new script's output contract
└── tasks.md                         # Phase 6 output
```

### Source Code (repository root)

There is no `src/` and no `tests/`. This repository is a Claude Code plugin and a quality gate; it holds no application code, and inventing either directory would be scaffolding for its own sake — the decision at `specs/001-quality-gate-plugin/plan.md:128`, restated at `specs/005-merge-conflict-resolution/plan.md:110`, and unchanged here.

```text
CLAUDE.md                                        # CHANGED — 2 statements corrected; section order untouched (FR-007a)
README.md                                        # CHANGED — 1 statement about the phase-prompt review

docs/
├── claude-code-practices.md                     # CHANGED — hook list, paths budget, 5 additions
├── claude-code-project-structure.md             # NEW — FR-001
├── merge-conflict-practices.md                  # unchanged
└── skill-authoring-practices.md                 # CHANGED — description-drop mechanism, the narrowed gap, 8 fields

.claude/rules/
├── repository-docs.md                           # NEW — FR-004, FR-005; paths: docs/**, CLAUDE.md
├── shell-scripts.md                             # unchanged
└── skill-authoring.md                           # CHANGED — the disable-model-invocation count

skills/ccd-conflict-resolve/
└── SKILL.md                                     # CHANGED — the contract pointer at :194

skills/ccd-speckit-run/
├── SKILL.md                                     # CHANGED — frontmatter, Steps 3 and 4, checklist, red flags
├── scripts/
│   └── conflict-state.sh                        # NEW — FR-014
└── reference/
    ├── subagents.md                             # CHANGED — cap of ten, per-batch; Phase 8 prohibition verbatim
    ├── conflicts.md                             # CHANGED — the boundary check and its handoff
    ├── ship.md                                  # CHANGED — Step 6e, folding in 6d
    ├── worktree.md                              # CHANGED — 6d now points at 6e
    ├── run-state.md                             # CHANGED — conflict_checks[], the not-gated sentence
    ├── constitution.md                          # CHANGED — the not-gated sentence
    ├── tooling.md                               # CHANGED — "two points" becomes the current count
    ├── prompt-rules.md                          # CHANGED — the leakage check moves to the plan presentation
    └── evaluations.md                           # CHANGED — 6 scenarios, plus new ones for each change
```

**Structure Decision**: the repository's existing layout is used unchanged. Documentation goes to `docs/`, path-scoped rules to `.claude/rules/`, skill logic to the owning skill's own directory, and feature artifacts to `specs/006-claude-code-guidance/`. The only new directories are the ones Spec Kit creates for this feature's own artifacts.

## Design notes carried from research

The full reasoning is in [research.md](./research.md). The decisions this plan commits to:

1. **`docs/claude-code-project-structure.md`** is new rather than a section of the existing practices document, which is already 127 lines over seven subjects.
2. **The `disable-model-invocation` field is removed** from `ccd-speckit-run`, taking the plugin's count of skills carrying it from one to zero. The safety property moves into the per-phase gates — the argument `specs/005-.../contracts/skill-names.md:47` already makes for `ccd-conflict-resolve`.
3. **Step 3 keeps the leakage check and loses the approval.** The check only works with all eight arguments visible at once; the approval moves to the phase it governs.
4. **The subagent cap is ten concurrent per batch**, not ten per run. **The Phase 8 prohibition is kept verbatim** — its argument is about reimplementing `implement` and racing writers, which no cap changes.
5. **The conflict check reads git's own state**, not `git status` prose, because porcelain wording is not a contract and an interrupted rebase may leave no conflict in the working tree.
6. **Step 6e absorbs 6d** so there is one teardown question, triggered when the review request is created. Two guards, not one: branch deletion is guarded on unpushed commits, worktree removal on any uncommitted path in that directory.
7. **42 falsified statements** are enumerated in `contracts/falsified-statements.md`. Live content is corrected in place; a `specs/` record of a completed feature is superseded; an already-superseded record is left alone.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

The Constitution Check records no violations at either evaluation, so nothing here requires justification. This section is intentionally empty.
