# Implementation Plan: Bug triage run ships its own work

**Branch**: `010-bug-run-ship` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-bug-run-ship/spec.md`

## Summary

`ccd-speckit-bug-run` currently drives the three Spec Kit bug stages and stops, naming a commit obligation it is forbidden to discharge. This feature gives it a workspace step before Stage 1, a shipping step and a teardown step after Stage 3, and a maintainer-chosen loop back from validation to assessment. Every added step delegates rather than performs: commits go to `claude-code-devkit:ccd-commit-push`, the review request to whichever of `ccd-github-pr` / `ccd-gitlab-mr` the remote actually calls for. Separately, `ccd-github-pr` splits its bundled `PR opts` option so that removing the source branch on merge is a choice of its own rather than a rider on auto-merge.

The design is deliberately derivative: option sets, guards, dispatch rules and state-file discipline are mirrored from `skills/ccd-speckit-run/reference/ship.md`, which already solved these problems for the eight-phase pipeline. Nothing here invents a second way to ask the same question.

## Technical Context

**Language/Version**: Markdown (CommonMark as linted by markdownlint-cli2), plus POSIX `sh` for any new script

**Primary Dependencies**: None at runtime. The artifacts are instruction files read by Claude Code. Authoring-time dependencies are the repository's existing quality gate (`scripts/lint.sh`) and the Spec Kit `bug` extension, which supplies the three stages this run drives.

**Storage**: One gitignored JSON run-state file, `.specify/.speckit-bug-run-state.json`, already established by feature 009 and extended here.

**Testing**: No test framework. The repository's own statement is that "the checks are the tests" — `sh scripts/lint.sh` runs seven checks and exits non-zero at the first failure. Each skill additionally carries a hand-run `evaluations.md` of scenarios.

**Target Platform**: Claude Code, any OS where POSIX `sh` and `git` exist.

**Project Type**: Claude Code plugin — a documentation and instruction artifact, not an executable.

**Performance Goals**: N/A. No runtime, no user-perceptible latency to govern.

**Constraints**: `SKILL.md` under 500 lines; frontmatter `description` under 1,536 characters; a skill body that survives compaction only up to a token budget, which is why durable facts live in the state file rather than in prose.

**Scale/Scope**: Two skills modified, one research document, one or two rule files, one manifest version bump. No new skill; the count stays at seven.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Checked against `.specify/memory/constitution.md` v1.3.0.

| Principle                     | Applies           | Verdict                                                                                                                                                                                                                    |
| ----------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Tooling Independence       | To any new script | **PASS** — any script added is POSIX `sh` invoked as `sh <path>`, needing no package manager, virtualenv or global install. Most of this feature adds no script at all.                                                    |
| II. Fail Fast                 | To any new script | **PASS** — new scripts exit non-zero on first failure and never mask a status behind a pipeline or subshell.                                                                                                               |
| III. Pinned, Official Images  | Not engaged       | **PASS** — this feature references no container image.                                                                                                                                                                     |
| IV. POSIX Shell Only          | To any new script | **PASS** — `sh` dialect, no bashisms, must pass `sh scripts/lint-shell.sh` with zero findings.                                                                                                                             |
| V. Configuration Is Committed | Not engaged       | **PASS** — adds no linter or formatter, and changes no tool configuration.                                                                                                                                                 |
| VI. Spec-Driven Change        | To this feature   | **PASS** — this change alters requirements, so it is feature work and is running the full phase pipeline, producing spec, plan and tasks on disk. It is not taking the bug-remediation path, which would be the violation. |

**Quality Gate Requirements**: no new content kind and no second governing configuration are introduced, so the one-config-per-kind rule is untouched. Any script added lives under `scripts/` and is therefore subject to the shell check like every other, per the constitution's explicit statement that "the tooling is not exempt from the standards it enforces."

**Development Workflow**: the work is on `010-bug-run-ship`, cut from the default branch. `sh scripts/lint.sh` must pass before review. The run-state file and dirty snapshot are machine-local and stay gitignored rather than being committed and cleaned up later.

**Post-design re-check**: **PASS, unchanged.** Phase 1 introduced no container, no configuration file, no second config per content kind, and no new dependency. The one design decision that could have engaged a principle — whether to add a helper script — resolves to adding at most one small POSIX `sh` script, already covered above.

### A note on Principle VI and this feature's own subject

This feature makes the bug-remediation path able to commit and raise a review request. Principle VI already required both paths' artifacts to be committed; what it did not say was who commits them. Feature 009 read that gap as "not the run", leaving the maintainer to satisfy an obligation the run created. This feature closes it without amending the constitution, because the principle's requirement is met either way — only the actor changes. No constitution amendment is therefore proposed, and Phase 1 was skipped for that reason.

## Project Structure

### Documentation (this feature)

```text
specs/010-bug-run-ship/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── bug-run-state.md         # the extended run-state file's shape and write rules
│   ├── workspace-options.md     # the two question shapes and both guards
│   └── skill-names.md           # supersedes 009's contract; the seven skills and their dispatch forms
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
skills/
├── ccd-speckit-bug-run/
│   ├── SKILL.md                 # MODIFIED — Step 1 workspace, Stage 3 loop-back, Steps 4a/4b/4c ship and teardown
│   ├── evaluations.md           # MODIFIED — scenarios for every added branch
│   ├── reference/
│   │   ├── stages.md            # MODIFIED — the three prohibitions become the delegation rules
│   │   ├── run-state.md         # MODIFIED — new blocks and their write rules
│   │   ├── workspace.md         # NEW — mode choice, creation, entry, verification, teardown
│   │   └── ship.md              # NEW — commit dispatch, review-request routing, branch cleanup
│   └── scripts/
│       ├── bug-preflight.sh     # MODIFIED — reports workspace facts the new Step 1 needs
│       └── bug-outcome.sh       # unchanged
├── ccd-github-pr/
│   ├── SKILL.md                 # MODIFIED — PR opts split into independent choices
│   └── evaluations.md           # MODIFIED — scenario for delete-without-auto-merge
├── ccd-gitlab-mr/               # NOT MODIFIED — verified only, per FR-029a
├── ccd-branch-push/             # unchanged; supplies branch-options.sh
├── ccd-commit-push/             # unchanged; dispatched by the new shipping step
├── ccd-conflict-resolve/        # unchanged
└── ccd-speckit-run/             # unchanged; supplies cleanup-plan.sh and forge-detect.sh

docs/
└── spec-kit-extensions.md       # MODIFIED — hook-event corrections, config-path correction, git-and-review-request section

.claude/rules/
├── spec-kit-bug-workflow.md     # MODIFIED — the run may now branch, commit and ship; how
└── skill-authoring.md           # MODIFIED — stale pointer to 006's contract corrected

CLAUDE.md                        # MODIFIED — the ccd-speckit-bug-run paragraph becomes false without this
.claude-plugin/plugin.json       # MODIFIED — minor version bump
```

**Structure Decision**: The repository is a Claude Code plugin whose deliverable is `skills/`, with reasoning in `docs/` and imperative rules in `.claude/rules/`. This feature adds no new top-level directory and no new skill. `ccd-speckit-bug-run` gains two reference files because its `SKILL.md` is already 235 lines and the added material — two option sets, two guards, a routing table, a dispatch discipline — would push it past the 500-line ceiling and, worse, past the compaction budget that made feature 009 externalise its run state in the first place. `workspace.md` and `ship.md` mirror the names their counterparts carry in `ccd-speckit-run/reference/`, so a reader who knows one finds the other.

## Design decisions

### Delegation, not reimplementation

Every added capability already exists somewhere in this plugin. The shipping step dispatches `claude-code-devkit:ccd-commit-push` and one of the two review-request skills through the `Skill` tool; the workspace step invokes `branch-options.sh` from `ccd-branch-push` and `forge-detect.sh` from `ccd-speckit-run`; teardown consults `cleanup-plan.sh` from `ccd-speckit-run`. No script is forked. This is the rule `CLAUDE.md` records about `branch-options.sh` existing exactly once, applied to four more files.

The one thing that is _not_ delegated is the workspace question itself, because `ccd-speckit-run`'s Step 1 is embedded in that skill's own numbered spine rather than exposed as something another skill can call. The option sets and guards are therefore mirrored — copied in shape, with the reasoning left in `ccd-speckit-run/reference/worktree.md` and cited rather than restated.

### Why the loop-back is an edge, not a fourth stage

FR-005 of feature 009 forbids a fourth stage, and that requirement is not superseded here. Returning to assessment re-enters Stage 1; it does not add a stage. The cycle counter distinguishes the second visit from the first for reporting purposes only — the stage itself behaves identically, and its own precondition (an existing `assessment.md`) is what asks about overwriting.

### Why `ccd-github-pr` needs a probe, not just a new option

GitHub has no create-time flag for deleting the source branch. It is either the repository's `deleteBranchOnMerge` setting or the `--delete-branch` flag on `gh pr merge`. Step 1 of that skill already queries `deleteBranchOnMerge`, so the split option keys off a fact the skill has in hand: where the repository already deletes by default, FR-030 requires saying so rather than offering a choice that changes nothing.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The table is intentionally empty.
