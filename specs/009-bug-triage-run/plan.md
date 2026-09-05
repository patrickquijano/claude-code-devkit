# Implementation Plan: Guided Bug Triage Run

**Branch**: `009-bug-triage-run` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-bug-triage-run/spec.md`

## Summary

Ship a seventh Claude Code plugin skill, `ccd-speckit-bug-run`, that drives the installed Spec Kit `bug` extension's three commands — `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` — from one bug report, gating each stage separately and branching exhaustively on the outcome each stage records. Ship with it the research record the repository's documentation rules require, a path-scoped rule file, a superseding skill-names contract, and the count and version updates a seventh skill forces.

The technical shape follows `.claude/rules/skill-authoring.md` rather than the older `ccd-speckit-run`: `${CLAUDE_SKILL_DIR}` for bundled files, `SKILL.md` under 500 lines with reference siblings, an `evaluations.md`, and no frontmatter beyond `name` and `description`. Two POSIX `sh` scripts carry the deterministic parts — a preflight that answers "is the capability here, is the tree dirty, does this bug already exist", and an outcome reader that extracts the three stages' recorded verdicts from their Markdown reports. Everything the run must still know at its last stage lives in a gitignored state file, because only the first 5,000 tokens of a skill survive compaction.

## Technical Context

**Language/Version**: Markdown (skill bodies) and POSIX `sh` for the two bundled scripts. No compiled language, no runtime.

**Primary Dependencies**: The installed Spec Kit `bug` extension v1.0.0 (Spec Kit 1.0.2.dev0), reached through the `Skill` tool by the bare names `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test`. `git` for the dirty-path check. Nothing else; per Principle I no package manager may be required.

**Storage**: Files only. The `bug` extension owns `.specify/bugs/<slug>/{assessment,fix,test}.md`; this feature adds `.specify/.speckit-bug-run-state.json`, gitignored.

**Testing**: The repository has no test runner. The regression instrument is `skills/ccd-speckit-bug-run/evaluations.md`; the check is `sh scripts/lint.sh` plus `sh scripts/selftest.sh`.

**Target Platform**: Any POSIX environment running Claude Code with this plugin installed. macOS and Linux; no Windows-specific path handling is introduced.

**Project Type**: Claude Code plugin skill — a Markdown workflow with bundled shell helpers. Not a library, service or application.

**Performance Goals**: None meaningful. The two scripts are a handful of `grep`/`test`/`git status` calls each and must not scan the working tree.

**Constraints**: `SKILL.md` under 500 lines. `description` under 1,536 characters with the trigger in its first sentence. Only the first 5,000 tokens of a skill survive compaction, so nothing the last stage needs may live in prose alone. Scripts must be POSIX `sh`, pass `shellcheck -s sh` with zero findings, and fail fast.

**Scale/Scope**: One new skill directory (SKILL.md, evaluations.md, 2 reference files, 2 scripts), one new `docs/` page, one new `.claude/rules/` file, one new contract, and edits to four existing files (`.gitignore`, `.claude-plugin/plugin.json`, `README.md`, `CLAUDE.md`).

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Checked against `.specify/memory/constitution.md` **v1.3.0** (ratified 2026-09-02, last amended 2026-09-05 by Phase 1 of this run).

| Principle                                    | Verdict            | Basis                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **I. Tooling Independence** (NON-NEGOTIABLE) | **PASS**           | The two bundled scripts are POSIX `sh` using only `git`, `grep`, `sed` and `test`. No package manager, virtual environment or install step is a precondition for anything this feature adds. The skill itself is Markdown and needs no tooling at all.                                                                       |
| **II. Fail Fast**                            | **PASS**           | Both scripts `set -e` and exit non-zero on the first failing condition, with no pipeline or subshell masking a status. Neither continues after a failure.                                                                                                                                                                    |
| **III. Pinned, Official Images**             | **PASS (vacuous)** | This feature references no container image. The existing checks' pinned images are untouched.                                                                                                                                                                                                                                |
| **IV. POSIX Shell Only**                     | **PASS**           | Both scripts are `sh`-compatible with no bashisms, and are covered by the existing `scripts/lint-shell.sh` glob `'*.sh'`, which runs ShellCheck in POSIX mode with zero findings required.                                                                                                                                   |
| **V. Configuration Is Committed**            | **PASS**           | No new configuration file. The one configuration change is a committed `.gitignore` entry for the state file, beside the existing entry for `ccd-speckit-run`'s. New Markdown falls under the already-committed Prettier, markdownlint and editorconfig-checker configurations, none of which excludes `skills/` or `docs/`. |
| **VI. Spec-Driven Change**                   | **PASS**           | This feature is itself passing through the Spec Kit phases with a spec, a plan and a task list on disk. It also builds the tooling for the amended principle's second path: a defect fix that leaves an assessment, a change record and a verification result on disk.                                                       |

Quality Gate Requirements — "each combination of content kind and concern MUST have exactly one governing configuration file": **PASS**. This feature adds Markdown and shell, both already governed by exactly one formatter configuration and one linter configuration each. It adds no configuration file and therefore cannot create a second governor.

Development Workflow — branch cut from the default branch: **PASS** (`009-bug-triage-run` off `main` at `c9701fc`). Artifacts under `specs/<NNN-slug>/`: **PASS**. Aggregate check run and passing before review: **deferred to Step 5 of this run**, which is where it is enforced.

**Result: no violations. Complexity Tracking is empty and stays empty.**

### Post-design re-check

Re-evaluated after Phase 1 produced `data-model.md`, `contracts/` and `quickstart.md`. No verdict changed. The design added two scripts and two reference files, none of which introduces a dependency, an image, a configuration file, or a bashism. The one thing worth noting: the design deliberately does **not** add a third script for the closing report, because that would be logic the skill body can carry in prose, and Principle-adjacent simplicity is better served by two scripts that answer factual questions than by three that also draw conclusions.

## Project Structure

### Documentation (this feature)

```text
specs/009-bug-triage-run/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── skill-names.md          # supersedes specs/006-.../contracts/skill-names.md
│   ├── bug-preflight-cli.md    # output contract for the preflight script
│   └── bug-outcome-cli.md      # output contract for the outcome reader
├── checklists/
│   ├── requirements.md  # built-in spec-quality checklist, 16/16
│   └── consistency.md   # custom instrument, 26 items
├── design-review.md     # FR-026: risks, options weighed, resolutions chosen (written after implementation)
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
skills/ccd-speckit-bug-run/          # the seventh skill
├── SKILL.md                         # the workflow: preflight, three gated stages, closing report
├── evaluations.md                   # the regression instrument for this skill
├── reference/
│   ├── stages.md                    # the three stages, their outcome vocabularies, the branch table
│   └── run-state.md                 # state file shape, who writes what, precondition rule
└── scripts/
    ├── bug-preflight.sh             # capability present? tree dirty? slug already taken?
    └── bug-outcome.sh               # read verdict / status / result out of the three reports

docs/spec-kit-extensions.md          # the research record, in this repo's documented docs shape
.claude/rules/spec-kit-bug-workflow.md  # path-scoped rule, globs the skill and the bug artifacts

.gitignore                           # + .specify/.speckit-bug-run-state.json
.claude-plugin/plugin.json           # version 0.2.0 -> 0.3.0, description "six" -> "seven"
README.md                            # "The six skills" -> seven, table row, TOC anchor
CLAUDE.md                            # skill count, the seventh skill's role, its dispatch targets
```

**Structure Decision**: The skill follows the layout `.claude/rules/skill-authoring.md` prescribes and that five of the six existing skills already use — `SKILL.md` plus `evaluations.md` at the skill root, `scripts/` for shell helpers, `reference/` only where `SKILL.md` would otherwise exceed its budget. Two reference files rather than `ccd-speckit-run`'s fourteen: this workflow has three stages, not eight phases, and splitting further would put a file's worth of prose behind a table of contents nobody needs to consult. `evaluations.md` sits at the skill root, matching the five smaller skills, **not** at `reference/evaluations.md` where `ccd-speckit-run` alone puts it.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified.

No violations. This section is intentionally empty.
