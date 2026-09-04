# Implementation Plan: Merge Conflict Resolution

**Branch**: `005-merge-conflict-resolution` | **Date**: 2026-09-04 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-merge-conflict-resolution/spec.md`

## Summary

Three deliverables from one research pass. A `docs/` directory carrying three sourced documents — Claude Code practice, skill-authoring practice, and merge-conflict practice — each citing where its claims came from and recording the gaps where nothing authoritative exists. The repository's own instructions brought into line with those documents: durable repo-wide rules in `CLAUDE.md`, area-scoped rules in new `.claude/rules/` files, and every statement this feature falsifies corrected wherever it appears. And a sixth distributed skill, `ccd-conflict-resolve`, that walks a user through resolving conflicts: it probes for `git`, updates the remote, classifies what is conflicted, proposes resolutions with a justified recommendation, applies only what was approved, and iterates until the tree is clean before concluding the interrupted operation.

The technical approach is deliberately unremarkable, because the repository already fixed most of it. Four POSIX `sh` scripts ship inside the skill and do all the deterministic git work; the skill body does the judgment and the asking. Nothing is added to the toolchain, no configuration file is created, and `plugin.json` is not touched — the skill is auto-discovered. The one configuration change is a _narrowing_: three exclusion declarations stop excluding `.claude/rules/`, so the new rule files are governed by the same checks as every other document in the repository.

## Technical Context

**Language/Version**: POSIX `sh` (IEEE Std 1003.1) for all executable content; GitHub-Flavored Markdown for all documentation. No bashisms — no `[[ ]]`, no arrays, no `<<<`, no `set -o pipefail`. Every script opens `#!/bin/sh` then `set -u`, and indents with tabs, because `<<-` heredocs strip leading tabs and nothing else.

**Primary Dependencies**: `git` at run time, required by the new skill and probed before use per FR-009. Nothing else is added. The existing quality gate continues to supply Prettier 3.9.6, markdownlint-cli2, ShellCheck, editorconfig-checker, yamllint and Ruff, each already pinned and already driven by a committed configuration file.

**Storage**: Not applicable. Every artifact is a file in the repository; the skill's only state is the git index and working tree it is operating on, which belongs to the user's repository and not to this feature.

**Testing**: `sh scripts/lint.sh` — the repository's seven checks, in the order `citations editorconfig format markdown yaml shell python`, stopping at the first failure. This is the aggregate check the constitution's Development Workflow section requires to have passed before review. `sh scripts/selftest.sh` proves each check still rejects bad input. The new skill's scripts are verified by the `shell` check with `shell=sh` and `severity=style`, which must report zero findings. There is no separate unit-test runner and this feature does not introduce one.

**Target Platform**: Any POSIX shell environment in which Claude Code runs; developed and verified on macOS and Linux. The skill makes no assumption about which shell is interactive, only that `/bin/sh` can execute its scripts.

**Project Type**: Claude Code plugin and developer toolkit. There is no application code, no `src/`, and no build step.

**Performance Goals**: Not applicable in the usual sense. Each script runs once per workflow step against a repository the user is already sitting in, so its cost is one or two `git` invocations. The one scale consideration is stated under Constraints rather than as a target.

**Constraints**: POSIX `sh` only, zero ShellCheck findings. Exit non-zero on the first failing step, with no status masked behind a pipeline or subshell — ShellCheck's `check-extra-masked-returns` and `check-set-e-suppressed` are enabled, so a violation fails the gate rather than merely being poor style. No new linter or formatter configuration file, because the constitution permits exactly one governing configuration per content kind per concern and each already exists. No `plugin.json` edit. `CLAUDE.md` stays within its 200-line target; it is currently 54 lines. Markdown is one line per paragraph with no hard wrapping, which follows from Prettier's `printWidth: 100` combined with its default `proseWrap: preserve` and markdownlint's `MD013` being off.

**Scale/Scope**: Three new documents under `docs/`. One new skill directory containing a `SKILL.md`, an `evaluations.md`, and four scripts. One or more new files under `.claude/rules/`. One new contract superseding an existing one, plus a banner on the file it supersedes. Six existing files edited: `CLAUDE.md`, `README.md`, `.prettierignore`, `.markdownlint-cli2.jsonc`, `.editorconfig-checker.json`, and `specs/003-ccd-skill-rename/contracts/skill-names.md`.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Evaluated against `.specify/memory/constitution.md` v1.2.0 (ratified 2026-09-02, six principles).

Every gate passes. The basis for each is recorded below rather than in a table, because the reasoning does not fit in a table cell and a 400-character cell is unreadable in source.

**I. Tooling Independence (NON-NEGOTIABLE) — Pass.** The four new scripts require POSIX `sh` and `git` and nothing else: no language package manager, no virtual environment, no global install step. `git` is probed before use per FR-009, so its absence produces a stated refusal rather than a partial failure, which is the degradation this principle exists to guarantee.

**II. Fail Fast — Pass.** Every new script exits non-zero at its first failing step, and no exit status is masked behind a pipeline, a subshell, or an ignored error. The two optional ShellCheck checks that detect exactly those mistakes — `check-extra-masked-returns` and `check-set-e-suppressed` — are already enabled in `.shellcheckrc`, so the gate enforces this rather than review having to catch it.

**III. Pinned, Official Images — Pass.** No container image is referenced by anything this feature adds. The existing pinned set in `scripts/lib/images.sh` is untouched, so the principle is satisfied unchanged.

**IV. POSIX Shell Only — Pass.** All executable content is POSIX `sh`, checked at `shell=sh` with `severity=style` and required to report zero findings. Neither `skills/` nor the new skill's `scripts/` is excluded by `.shellcheckrc`'s declaration, so the new scripts are in scope by construction rather than by someone remembering to add them.

**V. Configuration Is Committed — Pass.** No new configuration file, and no reliance on an undeclared default. Three committed declarations are edited, each at its documented path, and each edit narrows an exclusion rather than introducing behaviour. The one default relied on, Prettier's `proseWrap: preserve`, is already recorded in `specs/001-quality-gate-plugin/research.md`.

**VI. Spec-Driven Change — Pass.** `spec.md` and this `plan.md` are on disk, and `tasks.md` follows before any implementation. The feature is on `005-merge-conflict-resolution`, cut from the default branch, with artifacts under `specs/005-merge-conflict-resolution/`.

**Quality Gate Requirements (§140–158) — Pass.** No configuration is added, so the limit of one governing configuration per content kind per concern is unchanged. Every new script is subject to the shell check, satisfying §156. The three narrowing edits keep each check's exclusions declared in exactly one place, which is what `specs/004-format-hook-scope/contracts/exclusion-declaration.md` requires.

**Development Workflow (§160–171) — Pass.** The aggregate check must pass before review, and the baseline was confirmed green before any file was written — so a later failure is attributable to this feature rather than inherited. Machine-local state stays excluded; the run's own bookkeeping is already in `.gitignore`.

**Governance (§189–190) — Pass.** The only added complexity is the sixth skill, which the feature exists to add, and the four scripts, which FR-015 requires. Both are justified against the principles rather than in spite of them.

**Post-design re-check**: re-evaluated after Phase 1 with the contracts and data model written. No verdict changed. The design added no dependency, no configuration file, and no container image, and the script count settled at four rather than the six an earlier sketch had — recorded under Complexity Tracking so the reduction is visible rather than silent.

## Project Structure

### Documentation (this feature)

```text
specs/005-merge-conflict-resolution/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── skill-names.md            # supersedes specs/003-ccd-skill-rename/contracts/skill-names.md
│   └── conflict-scripts-cli.md   # the four scripts' invocation, output and exit-code contract
├── checklists/
│   ├── requirements.md           # built-in spec-quality checklist
│   └── requirements-quality.md   # custom requirements-quality review
└── tasks.md             # Phase 2 output (/speckit-tasks, not created here)
```

### Source Code (repository root)

There is no application code in this repository, so there is no `src/` and no `tests/`. The layout below is the real tree this feature writes into.

```text
docs/                                    # NEW directory
├── claude-code-practices.md             # NEW — FR-001
├── skill-authoring-practices.md         # NEW — FR-002
└── merge-conflict-practices.md          # NEW — FR-003

skills/ccd-conflict-resolve/             # NEW skill, auto-discovered
├── SKILL.md                             # NEW — FR-008, FR-018 (no disable-model-invocation)
├── evaluations.md                        # NEW — matches the four sibling skills
└── scripts/
    ├── conflict-preflight.sh            # NEW — FR-009, FR-017, FR-017a, FR-020
    ├── conflict-list.sh                 # NEW — FR-011, FR-019
    ├── conflict-apply.sh                # NEW — FR-013, FR-017c
    └── conflict-conclude.sh             # NEW — FR-017b, FR-017c

.claude/rules/                           # NEW directory — FR-006, FR-006a
└── <topic>.md                            # NEW — area-scoped rules with paths: globs

CLAUDE.md                                # EDIT — FR-006, FR-007, FR-021a
README.md                                # EDIT — FR-021a only (a factual correction, not a rule)
.prettierignore                          # EDIT — FR-005a, narrow the .claude exclusion
.markdownlint-cli2.jsonc                 # EDIT — FR-005a, narrow the .claude exclusion
.editorconfig-checker.json               # EDIT — FR-005a, narrow the .claude exclusion
specs/003-ccd-skill-rename/contracts/skill-names.md   # EDIT — superseded banner only, body intact
```

**Structure Decision**: flat, matching what the repository already is. Configuration stays at the root, distributed skills stay one-directory-per-skill under `skills/`, and feature artifacts stay under `specs/NNN-slug/` as §165 requires. The two new directories, `docs/` and `.claude/rules/`, are the only structural additions, and each exists because a requirement names it — `docs/` in FR-001 through FR-003, `.claude/rules/` in FR-006 as clarified. No `src/` or `tests/` is invented; `specs/001-quality-gate-plugin/plan.md:128` already rejected both for this repository, and nothing here changes that.

The new skill's scripts live in its own `scripts/` directory rather than being shared. This is the opposite of the `branch-options.sh` decision, and deliberately so: that script is consumed by four skills, which is why it has exactly one home and is reached through `${CLAUDE_PLUGIN_ROOT}`. These four have exactly one consumer, so a shared location would create a dependency nothing needs.

They are invoked as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"`, not through `${CLAUDE_PLUGIN_ROOT}`. This departs from what the four existing skills do, and research §2.6 is why: the documentation assigns the two variables to exactly this distinction — `${CLAUDE_SKILL_DIR}` is "the directory containing the skill's `SKILL.md` file", for "scripts or files bundled with the skill", while `${CLAUDE_PLUGIN_ROOT}` is for "resources shared between the plugin's skills". Own scripts are the first case. The practical argument is this repository's own history: feature 003 renamed five skills and had to touch 328 references across 40 files, because every path spelled out the skill's own directory name. `${CLAUDE_SKILL_DIR}` does not, so a future rename of this skill touches its frontmatter and its directory and nothing else. `sh` stays explicit in every invocation, because the executable bit is not documented to survive installation (research §2.6 records that as a gap), and `${CLAUDE_SKILL_DIR}` is quoted so a path containing a space does not split.

The four existing skills are **not** migrated to `${CLAUDE_SKILL_DIR}` by this feature. Three of them reach `branch-options.sh`, which genuinely is a shared resource and must keep `${CLAUDE_PLUGIN_ROOT}`, and rewriting the remainder is a change to four shipped skills that no requirement here asks for. The new convention is recorded in `docs/skill-authoring-practices.md` so the next skill follows it; converting the existing ones is left as a separate, deliberate change.

## Complexity Tracking

The Constitution Check records no violations, so nothing here requires justification. Two notes are kept because they are decisions a later reader would otherwise re-litigate.

**Four scripts rather than one.** Each maps to a distinct workflow step with a distinct contract — probing, listing, applying, concluding — and the skill body calls them at different points and branches on different exit codes. One script taking a subcommand was considered and rejected: it would put four unrelated output formats behind one entry point, and each step's exit-code contract is precisely what the skill branches on. Six scripts were also sketched and then reduced to four, by folding stage-detail into `conflict-list.sh` and state-reporting into `conflict-preflight.sh`.

**A new `docs/` directory rather than extending `README.md`.** FR-001 to FR-003 require three subjects documented with sources. `README.md` is bound to the Standard Readme structure adopted at `specs/003-ccd-skill-rename/research.md:118` and has no slot for them; appending three long sections would break that structure and put contributor reference material in the file a first-time reader meets. `docs/` was previously considered and rejected in this repository, but only as a location for pull-request templates — a different question with a different answer.
