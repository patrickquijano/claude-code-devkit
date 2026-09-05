# Implementation Plan: Approvals that carry a decision, guided pipeline repair, and a uniform question standard

**Branch**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/011-narrow-gates-pipeline-fix/spec.md`

## Summary

Three behavioural changes to the toolkit's own distributed skills, plus one precondition amendment to the repository's documentation conventions.

`ccd-speckit-run`'s Step 4 gate is **narrowed, not removed**: an approval is requested when the phase's verbatim argument differs from the drafted plan, or when the phase's effect is not readily undone. Otherwise the phase proceeds and prints why it did not ask. This supersedes FR-010/FR-011/FR-013 of feature 006 while leaving FR-012's leakage check untouched, and it preserves the reasoning that keeps `disable-model-invocation` off every skill — the gate remains in the workflow, it is merely no longer uniform.

A new eighth skill, `ccd-pipeline-fix`, carries a maintainer from a failed CI pipeline to a verified fix by **composing a bug report and dispatching `claude-code-devkit:ccd-speckit-bug-run`**. It runs no stage itself and edits no source. Evidence comes from `gh` or `glab` when available, and from the maintainer when not.

The `AskUserQuestion` contract moves into `.claude/rules/skill-authoring.md` as its single normative home, and the roughly twenty untooled ask sites are converted.

Compaction is gated behind an amendment to `.claude/rules/repository-docs.md`, and is made checkable by a new review-aid script, `scripts/compaction-audit.sh`, which is what turns FR-028/FR-029/SC-010 from judgement calls into a command with output.

## Technical Context

**Language/Version**: Markdown (skill definitions, rules, docs) and POSIX `sh` (IEEE Std 1003.1) for helper scripts. No language runtime is introduced.

**Primary Dependencies**: None added. Existing optional externals only — `gh` (GitHub CLI) and `glab` (GitLab CLI) for evidence retrieval, both probed and both degrading to a maintainer-supplied fallback. `shellcheck`, `prettier`, `markdownlint-cli2`, `yamllint`, `ruff` and `editorconfig-checker` already back the quality gate, natively or as digest-pinned containers.

**Storage**: Files in the repository. No datastore.

**Testing**: `sh scripts/lint.sh` — seven checks in the order `citations editorconfig format markdown yaml shell python`, stopping at the first failure. `sh scripts/selftest.sh` proves each check still rejects bad input. New shell scripts get a `selftest.sh` fixture.

**Target Platform**: Any POSIX shell environment where Claude Code runs; macOS and Linux in practice.

**Project Type**: Claude Code plugin — a documentation-and-scripts artifact, not a compiled application.

**Performance Goals**: Not latency-bound. The relevant budget is context: `SKILL.md` under 500 lines, `CLAUDE.md` under 200 lines, `description` plus `when_to_use` under 1,536 characters, and only the first 5,000 tokens of a skill surviving compaction.

**Constraints**: No new runtime dependency. Every distributed skill keeps the `ccd-` prefix in both directory name and frontmatter `name`. Cross-skill dispatch uses the namespaced `claude-code-devkit:<name>`. **No skill carries `disable-model-invocation`.** Shared scripts exist exactly once and are reached through `${CLAUDE_PLUGIN_ROOT}`; a skill's own files through `${CLAUDE_SKILL_DIR}`. No hard-wrapped prose. Two-space indentation inside fences, never tabs.

**Scale/Scope**: Eight distributed skills after this feature (seven today). Roughly 4,750 lines of skill text and 6 rule files in scope for compaction; 2 new files of skill content, 1 new script, 4 contracts.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Checked against `.specify/memory/constitution.md` v1.3.0 (ratified 2026-09-02, last amended 2026-09-05).

| Principle                                    | Applies? | Verdict                                                                                                                                                                                                                                                                                                                                                               |
| -------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **I. Tooling Independence (NON-NEGOTIABLE)** | Partly   | **PASS.** The principle governs _quality checks_. `scripts/compaction-audit.sh` is a review aid, not a check wired into `lint.sh`, but it is written to the same standard anyway: POSIX `sh` plus `git`, no package manager, no virtual environment, no install step. `gh`/`glab` are not quality checks and are optional by FR-011b, so they create no setup ritual. |
| **II. Fail Fast**                            | Yes      | **PASS.** `compaction-audit.sh` exits non-zero on the first failing condition and never masks a status behind a pipeline or subshell.                                                                                                                                                                                                                                 |
| **III. Pinned, Official Images**             | No       | **N/A.** No container image is added or referenced.                                                                                                                                                                                                                                                                                                                   |
| **IV. POSIX Shell Only**                     | Yes      | **PASS.** `compaction-audit.sh` is POSIX `sh`, `#!/bin/sh` then `set -eu`, tab-indented, and must produce zero `shellcheck` findings under `shell=sh` with the four opt-in rules enabled.                                                                                                                                                                             |
| **V. Configuration Is Committed**            | No       | **N/A.** No linter or formatter is added, and none of their configuration changes.                                                                                                                                                                                                                                                                                    |
| **VI. Spec-Driven Change**                   | Yes      | **PASS.** This is feature work — it adds and alters requirements — and it is passing through the Spec Kit phases with `spec.md`, this `plan.md`, and a `tasks.md` to follow, all committed.                                                                                                                                                                           |

**Quality Gate Requirements**: PASS. No new content-kind/concern pairing is introduced, so the one-governing-config-file rule is untouched. `compaction-audit.sh` lives under `scripts/` and is therefore picked up by `lint-shell.sh`'s existing `'*.sh'` glob, satisfying "every script committed under the repository's script directory MUST itself be subject to the shell static analysis check."

**Development Workflow**: PASS. Branch `011-narrow-gates-pipeline-fix` is cut from the default branch, artifacts live under `specs/011-narrow-gates-pipeline-fix/`, and `sh scripts/lint.sh` must pass before review.

**Result: no violations. Complexity Tracking is empty and stays empty.**

### Post-design re-check

Re-evaluated after Phase 1. Unchanged — no gate moved. The one design decision that could have introduced a violation was making the compaction audit an eighth `lint.sh` check; it was rejected precisely because it would have created a new governing-configuration obligation under the Quality Gate Requirements for a concern that is a one-off review aid. See `research.md` decision R3.

## Project Structure

### Documentation (this feature)

```text
specs/011-narrow-gates-pipeline-fix/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── skill-names.md            # the eight-skill count; supersedes 010's
│   ├── gate-decision.md          # when Step 4 asks and when it does not
│   ├── pipeline-fix-interface.md # ccd-pipeline-fix's inputs, dispatch and outcomes
│   └── compaction-audit-cli.md   # the audit script's argument and output contract
├── checklists/
│   ├── requirements.md  # built-in spec-quality checklist, 16/16
│   └── quality.md       # requirements-quality review, 45 items
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
skills/
├── ccd-branch-push/         # ask-site conversion + compaction
├── ccd-commit-push/         # ask-site conversion + compaction
├── ccd-conflict-resolve/    # ask-site conversion + compaction
├── ccd-github-pr/           # ask-site conversion + compaction
├── ccd-gitlab-mr/           # ask-site conversion + compaction
├── ccd-speckit-bug-run/     # ask-site conversion + compaction
├── ccd-speckit-run/         # narrowed Step 4 gate + ask-site conversion + compaction
│   ├── SKILL.md
│   ├── reference/           # prompt-rules, ship, verify, findings, … all in scope
│   └── scripts/
└── ccd-pipeline-fix/        # NEW — the eighth skill
    ├── SKILL.md
    ├── evaluations.md
    ├── reference/
    │   ├── evidence.md      # per-forge retrieval, the fallback, the report it composes
    │   └── dispatch.md      # handing off to ccd-speckit-bug-run, and what it must not do
    └── scripts/
        └── pipeline-evidence.sh

scripts/
├── lint.sh                  # unchanged — still seven checks
├── compaction-audit.sh      # NEW — review aid, not a gate check
└── selftest.sh              # gains a fixture for compaction-audit.sh

.claude/rules/
├── skill-authoring.md       # gains the AskUserQuestion contract (single normative home)
├── repository-docs.md       # gains the compaction carve-out — MUST land first
└── …                        # the other four: compaction only

CLAUDE.md                    # "seven skills" → eight; disable-model-invocation bullet; compaction
.claude-plugin/plugin.json   # 0.4.0 → 0.5.0; description "seven skills" → "eight skills"
docs/
├── skill-authoring-practices.md   # reasoning behind the AskUserQuestion contract
└── spec-kit-extensions.md         # unchanged unless the pipeline skill adds a gap record
```

**Structure Decision**: The repository is a Claude Code plugin, so none of the template's application layouts apply. The real structure is the one above: `skills/` holds the distributed skills, one directory each, with `reference/` and `scripts/` subdirectories where a skill needs them; `scripts/` holds repository-level shell; `.claude/rules/` holds path-scoped instructions; `docs/` holds the cited reasoning behind the rules. The new skill follows the shape `ccd-speckit-bug-run` established — `SKILL.md` plus `reference/` plus `scripts/` plus `evaluations.md` — because it is the closest sibling in both size and behaviour, and because it is the one skill already addressing its own files as `${CLAUDE_SKILL_DIR}`, which `.claude/rules/skill-authoring.md` requires and which `ccd-speckit-run` predates.

## Approach

### 1. The narrowed gate (FR-001 – FR-008)

`ccd-speckit-run`'s Step 4 keeps its four-row proposal, but the proposal is followed by an `AskUserQuestion` only when the gate condition holds. The condition and its evaluation order are fixed in `contracts/gate-decision.md` so that the rule is one artifact rather than prose scattered through `SKILL.md`.

Always-gate steps, independent of any comparison: Phase 2 (`specify`, cuts a branch), Phase 5 (`plan`), Phase 8 (`implement`), Step 1 (creates a workspace or moves a tree), Step 2b (writes a repo-wide instruction file), Step 6 (commits, pushes, opens a review request, deletes branches and worktrees). These are FR-002's irreversible set.

Auto-proceed candidates: Phases 1, 3, 4, 6, 7. Each still auto-proceeds only when its argument is byte-identical to Step 3's draft. Any revision, any conflict resolution that changed an argument, and the phase gates again.

FR-007's override is a run-level switch, asked at Step 3 alongside the plan presentation and recorded in state as `gate_mode`, so a compacted run can still read it.

### 2. `ccd-pipeline-fix` (FR-009 – FR-019)

Preflight resolves the forge from the **shared** `forge-detect.sh` — no fork — then probes the matching CLI and records whether this run retrieves evidence or asks for it (FR-011c). It enumerates candidate failed runs and jobs, asks when there is more than one (FR-017), retrieves the failing log, and displays it (FR-011).

It then composes a bug report from that evidence, shows it verbatim for revision, and dispatches `claude-code-devkit:ccd-speckit-bug-run` through the `Skill` tool. Everything after that point — assessment, fix, validation, the loop-back offer, the commit and the review request — belongs to that skill and its three stages. The pipeline skill's root cause proposal (FR-012) and approach choice (FR-013) are carried **into the composed report**, so that `speckit-bug-assess` receives them as content rather than having them re-litigated.

FR-018 and FR-019 are exits taken before dispatch: evidence pointing outside the repository, or a fix that would add or alter a requirement, is reported and the run stops rather than entering the defect path.

### 3. The question standard (FR-020 – FR-024)

One new section in `.claude/rules/skill-authoring.md`. Every skill's own text loses any local restatement of the rule, keeping only what is specific to that question. The four skills already carrying _"Every question in this skill goes through `AskUserQuestion`"_ lose that sentence too — it becomes redundant once the rule is repository-wide, and `repository-docs.md` already says recording a rule in two places is worse than recording it in neither.

### 4. Compaction, and what makes it checkable (FR-025 – FR-031)

`.claude/rules/repository-docs.md` is amended first (FR-026 sequences this), then `scripts/compaction-audit.sh` is written, then documents are compacted one at a time with the audit run against each.

The three definitions the checklist demanded are settled in `research.md` (R1, R2, R3) and encoded in `contracts/compaction-audit-cli.md`:

- **Normative content** is defined by extraction rule, not by judgement.
- **Shortened** has a numeric floor, with a documented exemption path.
- **Establishable by comparison** is a command a reviewer runs, with pass/fail output.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

No violations. This table is intentionally empty.
