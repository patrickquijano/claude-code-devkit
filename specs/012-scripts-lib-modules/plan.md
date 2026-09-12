# Implementation Plan: One shared library directory for the checking machinery

**Branch**: `refactor/scripts-lib-modules` | **Date**: 2026-09-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/012-scripts-lib-modules/spec.md`

**Status**: Retrospective. The change was implemented before this plan existed; review required the record, and this file states the decisions as they were actually taken rather than as they would have been proposed. Nothing here is aspirational — every item is on disk and both gates pass against it.

## Summary

No script under `scripts/` executes another script under `scripts/`. Every entry point is a wrapper that resolves the repository root, sources one file from `scripts/lib/` and calls it; the bodies live in `scripts/lib/`, where the aggregate, the seven per-standard entry points, the edit hook and the self-test all reach the same code by name.

One decision carries the change: a check runs in a **separate process**, not a subshell. `( body ) || status=$?` is an AND-OR list, POSIX ignores `-e` for every command of one but the last, and the suppression reaches into the subshell — so a body could run past a failing command and be reported as a pass. `run_standard_isolated` spawns `/bin/sh -c` per check, which is what each check had before the bodies moved.

Two behaviours changed, both toward an existing contract: `lint.sh` now passes a trailing `-- PATH...` through to every check, and four usage headers stopped promising a `--fix` that rewrites nothing. One dead function, `count_files`, was removed.

Two things this feature added after the first review round: fourteen entry-point smoke cases, because removing the sibling execution removed the only thing that ran the wrappers; and an explicit exemption for `scripts/selftest.sh` from the wrapper rule, because the repository otherwise breaks in the same commit that states it.

Round four added the one that mattered most, and it is a deletion. `citations` was not honouring the trailing path list, and a comment in `scripts/lint-citations.sh` said `004/check-cli.md` exempted it. That contract exempts nothing of the kind — it states one command-line shape for every check and names `scripts/format-file.sh` as the single entry point outside it. FR-006, which this feature added, is what made the divergence reachable: before it, `lint.sh` dropped the path list and no caller could see the difference. The check now narrows, and with it go the comment, `USAGE_PATHS`, and the `0 1` status set round three had taught the self-test to accept. Round three's L1 was a wrong diagnosis: those two cases were not impossible to make hermetic, they were reporting this defect.

Round three added one more: FR-009 was satisfied in the file header comments and not at `-h`, which is the surface a user reads. `usage()` now takes its three variable lines from `USAGE_FIX`, `USAGE_PATHS` and `USAGE_EXIT`, whose defaults describe a check that filters a file list and resolves a tool; `check_main` overwrites all three for `citations`, which does neither. Four self-test cases assert both directions.

## Technical Context

**Language/Version**: POSIX `sh` (IEEE Std 1003.1). No language runtime is introduced.

**Primary Dependencies**: None added. `shellcheck`, `prettier`, `markdownlint-cli2`, `yamllint`, `ruff` and `editorconfig-checker` already back the quality gate, natively or as digest-pinned containers, and their resolution order is untouched.

**Storage**: Files in the repository. No datastore.

**Testing**: `sh scripts/lint.sh` — seven checks in the order `citations editorconfig format markdown yaml shell python`, stopping at the first failure. `sh scripts/selftest.sh` proves each check still rejects bad input, and now also that each entry point reaches its library.

**Target Platform**: Any POSIX shell environment where Claude Code runs; macOS and Linux in practice.

**Project Type**: Claude Code plugin — a documentation-and-scripts artifact, not a compiled application.

**Performance Goals**: Not latency-bound. One extra `sh` per check, against a container pull.

**Constraints**: No new runtime dependency. Every documented CLI — arguments, output and all five exit statuses — unchanged, so the contracts under `specs/` still describe what ships. `skills/` is untouched, so `.claude-plugin/plugin.json` needs no version bump.

**Scale/Scope**: 14 entry points under `scripts/`, 9 files under `scripts/lib/`, 7 checks. No file outside `scripts/`, `.husky/`, `README.md`, `CLAUDE.md`, `docs/husky-git-hooks.md` and `.claude/rules/husky-git-hooks.md` changes.

**One change in that list is not part of this feature.** `CLAUDE.md` gains a `## Working rules` section — four instructions to any agent working in this repository, about re-running slow checks, comment length, simplicity and token spend. It rode in on commit `50c92de`, whose message describes the subshell fix and nothing else. It is unrelated to `scripts/lib/`, it is named here rather than left for a reviewer to find in a diff, and it is the one thing in this branch a reader should judge on its own merits. Review round three raised it (M2); the decision was to disclose it rather than strip it, because it is correct and already in force.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Checked against `.specify/memory/constitution.md` v1.3.0 (ratified 2026-09-02, last amended 2026-09-05).

| Principle                                    | Applies? | Verdict                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **I. Tooling Independence (NON-NEGOTIABLE)** | Yes      | **PASS.** No new dependency and no setup ritual. The native-then-container resolution order and the pinned digests are untouched in `lib/common.sh` and `lib/images.sh`.                                                                                                                                                                                                                                                                                                                                       |
| **II. Fail Fast**                            | Yes      | **PASS, and it is the point of the change.** The subshell form masked a status behind a subshell, which the principle names explicitly. `run_standard_isolated` restores a live `set -eu` per check, and `lint_main` stops at the first failing check and returns its status unchanged.                                                                                                                                                                                                                        |
| **III. Pinned, Official Images**             | No       | **N/A.** `lib/images.sh` is unmodified.                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **IV. POSIX Shell Only**                     | Yes      | **PASS.** Every file is `#!/bin/sh` then `set -eu`, tab-indented, zero `shellcheck` findings under `shell=sh` with the four opt-in rules. The child is spawned as `/bin/sh`, not through `PATH`, so a check cannot run under a shell the entry point did not declare.                                                                                                                                                                                                                                          |
| **V. Configuration Is Committed**            | No       | **N/A.** No linter or formatter is added and none of their configuration changes. The six exclusion declarations and `.claude/settings.json` are untouched.                                                                                                                                                                                                                                                                                                                                                    |
| **VI. Spec-Driven Change**                   | Yes      | **PASS, retrospectively.** The change adds requirements — FR-001 and FR-002 are new rules and `README.md` states the `scripts/lib/` boundary as binding — so it is feature work and the defect path is not available. `spec.md`, this `plan.md`, `tasks.md` and `research.md` are the record. They were written after implementation, at review's request, and that sequence is a real departure from the principle rather than a satisfied one; what the principle requires on disk before review is present. |

**Quality Gate Requirements**: PASS. No new content-kind/concern pairing, so the one-governing-config-file rule is untouched. Every new file lives under `scripts/`, so `lint-shell.sh`'s existing `'*.sh'` glob picks it up — and the two extensionless hook paths in that glob still matter, unchanged.

**Development Workflow**: PASS, with one deviation recorded. The branch is `refactor/scripts-lib-modules` rather than `012-scripts-lib-modules`: it was cut before this feature was numbered, and renaming it would orphan the open pull request. Artifacts live under `specs/012-scripts-lib-modules/`, and both gates pass before review.

**Result: one process deviation, recorded above. Complexity Tracking is empty.**

### Post-design re-check

Re-evaluated after the first review round, which found six issues and then a second round which found seven. Two gates moved and both moved toward compliance:

- Principle II is satisfied by `run_standard_isolated` rather than claimed by a comment. The comment above `run_standard` no longer says errexit is preserved by a subshell.
- Principle VI moved from "left to the reviewer" to satisfied on disk, then from "spec and research only" to the full four artifacts.

The one design decision that could have introduced a violation was exempting `scripts/selftest.sh` from FR-002 rather than moving its body under `scripts/lib/`. It was taken deliberately and is argued in `research.md` section 9: the rule exists to make shared components declared and testable, and the self-test shares nothing and is the thing that would test its own wrapper.

## Project Structure

### Documentation (this feature)

```text
specs/012-scripts-lib-modules/
├── plan.md       # This file
├── spec.md       # Requirements
├── research.md   # The eleven decisions, with their reasons
└── tasks.md      # What was done, in the order it was done
```

No `data-model.md`, no `quickstart.md` and no `contracts/`: the change introduces no entity, no user-facing entry point and no new CLI. The contracts it must satisfy already exist — `specs/001-quality-gate-plugin/contracts/cli.md`, `specs/004-format-hook-scope/contracts/check-cli.md` and `format-file-cli.md`, `specs/008-commit-hooks/contracts/*` and `specs/011-narrow-gates-pipeline-fix/contracts/compaction-audit-cli.md` — and FR-007 requires every one of them to keep describing what ships.

### Source Code (repository root)

```text
scripts/
├── lint.sh                  # wrapper -> lib/checks.sh: lint_main
├── lint-<standard>.sh × 7   # wrapper -> lib/checks.sh: check_main <standard>
├── format-file.sh           # wrapper -> lib/checks.sh + lib/format-hook.sh
├── install-hooks.sh         # wrapper -> lib/hooks-install.sh
├── compaction-audit.sh      # wrapper -> lib/compaction.sh
├── selftest.sh              # EXEMPT: holds its own body, executes the wrappers
├── hooks/
│   ├── commit-msg.sh        # wrapper -> lib/commit-msg.sh
│   └── pre-push.sh          # wrapper -> lib/push-check.sh
└── lib/
    ├── checks.sh            # the seven checks, run_standard, run_standard_isolated,
    │                        # check_main, lint_main
    ├── common.sh            # unchanged
    ├── images.sh            # unchanged
    ├── scope.sh             # dead count_files removed
    ├── format-hook.sh       # sources nothing, so the self-test can substitute one name
    ├── commit-msg.sh        # moved from scripts/hooks/
    ├── push-check.sh        # moved from scripts/hooks/
    ├── hooks-install.sh     # moved from scripts/
    └── compaction.sh        # moved from scripts/

.husky/
├── commit-msg               # comment repointed at scripts/lib/
└── pre-push                 # comment repointed at scripts/lib/

README.md                        # the wrapper rule, and the self-test's exemption
CLAUDE.md                        # the hook-logic pointer, plus four working rules
docs/husky-git-hooks.md          # the file table
.claude/rules/husky-git-hooks.md # the allowed-paths list
```

**Structure Decision**: The repository is a Claude Code plugin, so none of the template's application layouts apply. `scripts/` holds entry points, `scripts/lib/` holds their bodies, and the boundary between the two is the rule this feature adds.

## Approach

### 1. Move the bodies, leave wrappers (FR-001, FR-002, FR-003)

Each entry point keeps `PROG`, `SCRIPT_DIR`, `REPO_ROOT`, one `.` and one call. `SCRIPT_DIR` means `scripts/` everywhere, including the two entry points nested in `scripts/hooks/`, because `lib/checks.sh` sources its siblings through it. `scripts/selftest.sh` is exempt and says so.

### 2. Invoke a check as its own process (FR-004, FR-005, FR-012)

`run_standard_isolated` spawns `/bin/sh -c`, sources `lib/checks.sh` and calls `check_main`. `MODE` and `REQUESTED_PATHS` go as `[--fix] [-- PATH...]` arguments rather than in the environment, because `lib/common.sh` assigns both as it is sourced and the child would overwrite them — so the child is the contract's invocation rather than an equivalent of it.

### 3. Restore the contracts the move exposed (FR-006, FR-007, FR-009, FR-010)

The `-- PATH...` passthrough, four over-promising usage headers, one that promised a path narrowing `standard_citations` does not do, and the dead `count_files`.

### 4. Test the invocation and the wrappers (FR-008, FR-011)

Three aggregate cases over a probe tree assert FR-004 and FR-005 against the committed `lint_main` and `run_standard_isolated`; the probe tree substitutes `run_standard` only, because standing in for its caller would reproduce the blind spot these cases exist to close. Fourteen entry-point cases execute each wrapper — `research.md` section 10 says why `-h` is not enough.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

No violations. One process deviation — the branch name and the retrospective ordering — is recorded under Development Workflow rather than here, because neither adds complexity to the artifact.
