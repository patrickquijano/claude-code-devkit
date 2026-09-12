---
description: 'Task list for feature 012 — one shared library directory for the checking machinery'
---

# Tasks: One shared library directory for the checking machinery

**Input**: Design documents from `/specs/012-scripts-lib-modules/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md` — all present. No `data-model.md`, `contracts/` or `quickstart.md`; `plan.md` says why.

**Status**: Retrospective. Every task below is complete and the boxes record what was done, not what is intended. The order is the order the work actually happened in, across three review rounds, because that order is the useful record — the second and third groups exist because a review found something the first group missed.

**Tests**: The specification does not request TDD, and the work was not done test-first. `scripts/selftest.sh` is this repository's proof-the-checks-can-fail suite rather than a unit-test harness, and the cases added in T014–T016 are regression guards written against defects a review had already identified. That is stated plainly rather than dressed as a TDD phase.

**Organization**: Grouped by user story, in the spec's priority order.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Could have run in parallel (different files, no dependencies)
- **[Story]**: `[US1]`–`[US3]`, mapping to the three user stories in `spec.md`
- Exact file paths in every description

## Path Conventions

A Claude Code plugin, not an application. Real paths: `scripts/` for entry points, `scripts/lib/` for their bodies, `.husky/` for the git dispatchers, `specs/012-scripts-lib-modules/` for this record.

## Two orderings that are load-bearing

1. **`SCRIPT_DIR` is settled before any library is sourced from a nested entry point.** `lib/checks.sh` sources its siblings through it, so a wrapper in `scripts/hooks/` that sets it to its own directory breaks every library that follows. T006 precedes T007.
2. **The invocation is settled before the cases that assert it.** T013 fixes how a check is invoked; T014–T016 assert it. Written the other way round the cases would have been authored against the defective form and would encode it.

---

## Phase 1: Foundational — the move (US1)

**Purpose**: The boundary between `scripts/` and `scripts/lib/`. Everything else depends on it.

- [x] T001 [US1] Move the seven check bodies and their dispatch out of the per-standard entry points into `scripts/lib/checks.sh`, behind `run_standard`, `check_main` and `lint_main`
- [x] T002 [P] [US1] Move `scripts/hooks/commit-msg.sh`'s body to `scripts/lib/commit-msg.sh` as `commit_msg_main`
- [x] T003 [P] [US1] Move `scripts/hooks/pre-push.sh`'s body to `scripts/lib/push-check.sh` as `push_check_main`
- [x] T004 [P] [US1] Move `scripts/install-hooks.sh`'s body to `scripts/lib/hooks-install.sh` as `install_hooks_main`
- [x] T005 [P] [US1] Move `scripts/compaction-audit.sh`'s body to `scripts/lib/compaction.sh` as `compaction_audit_main`
- [x] T006 [US1] Resolve `SCRIPT_DIR` to `scripts/` in every entry point, including `scripts/hooks/commit-msg.sh` and `scripts/hooks/pre-push.sh` (FR-003)
- [x] T007 [US1] Reduce all fourteen entry points to wrapper form: `PROG`, `SCRIPT_DIR`, `REPO_ROOT`, one `.`, one call — `scripts/selftest.sh` excepted (FR-002)
- [x] T008 [US1] Keep `scripts/lib/format-hook.sh` sourcing nothing, so the self-test can substitute `run_standard` and nothing else, and move the recursion guard into `format_hook_main`

## Phase 2: Contracts the move exposed (US1)

- [x] T009 [US1] Pass a trailing `-- PATH...` through from `lint_main` to every check, per `specs/004-format-hook-scope/contracts/check-cli.md` (FR-006)
- [x] T010 [P] [US1] Remove `count_files` from `scripts/lib/scope.sh` — no caller since `collect()` started testing the list file with `-s` (FR-010)
- [x] T011 [P] [US1] Reference each `EX_*` constant at the site that returns it, rather than duplicating the value as a bare literal
- [x] T012 [P] [US1] Update `README.md`, `CLAUDE.md`, `docs/husky-git-hooks.md` and `.claude/rules/husky-git-hooks.md` for the new layout

## Phase 3: The invocation, and the cases that hold it (US2)

**Purpose**: Review round one found that a check ran in a subshell, which does not preserve errexit. This phase is the correction and its regression guard.

- [x] T013 [US2] Replace the subshell with `run_standard_isolated`, spawning one `sh` per check, and pass `MODE` and `REQUESTED_PATHS` as arguments rather than in the environment (FR-004, `research.md` §2–4)
- [x] T014 [US2] Add `lint/errexit` to `scripts/selftest.sh`: a probe body whose non-final command fails must end the body and the aggregate (FR-004, FR-008)
- [x] T015 [P] [US2] Add `lint/pass`, the positive control without which `lint/errexit` proves nothing
- [x] T016 [P] [US2] Add `lint/stops`: the first failure stops the run and its own status survives, not a flattened 1 (FR-005)
- [x] T017 [US2] Build the probe tree by symlinking the real libraries and substituting `run_standard` only, so `lint_main` and `run_standard_isolated` under test are the committed code (FR-008, US3)
- [x] T018 [US2] Rewrite `run_standard`'s comment to state what the separate process actually holds, and stop claiming a subshell preserves errexit
- [x] T019 [US2] Correct the four report-only usage headers to `accepted, but this check rewrites nothing` (FR-009)
- [x] T020 [US2] Write `spec.md` and `research.md` — the record Principle VI requires, which review round one required after the change had been made

## Phase 4: Review round two (US1, US3)

**Purpose**: Seven findings. The two structural ones are M1 and M2; the rest are single-site corrections.

- [x] T021 [US3] Add the entry-point smoke cases to `scripts/selftest.sh`: one per wrapper, fourteen in all, enumerating `scripts/lint-*.sh` by glob so an eighth is covered when it is added (FR-011, `research.md` §10)
- [x] T022 [US3] Add `EP_FAILURES` to the verdict block and the entry-point count to the summary line, so a failing wrapper names itself
- [x] T023 [US1] Exempt `scripts/selftest.sh` from the wrapper rule explicitly, in `README.md` and in FR-001/FR-002, with the reason (`research.md` §9)
- [x] T024 [P] [US1] Correct `scripts/lint-citations.sh`'s header: the path list is accepted and ignored, because the check reads one fixed directory (FR-009)
- [x] T025 [P] [US1] Repoint `.husky/commit-msg` and `.husky/pre-push` comments at `scripts/lib/`, naming `commit_msg_main` and `push_check_main`
- [x] T026 [P] [US1] Rename `check_main`'s locals from `_cm_*` to `_chk_*`, the one collision with `scripts/lib/commit-msg.sh`'s prefix
- [x] T027 [P] [US1] Spawn the check as `/bin/sh -c` rather than through `PATH`, and say why (FR-012, `research.md` §11)
- [x] T028 [US3] Write `plan.md` and this `tasks.md`, completing Principle VI's four artifacts (review round two, H1)

## Phase 5: Verification

- [x] T029 Run `sh scripts/lint.sh` — all seven checks pass (SC-001)
- [x] T030 Run `sh scripts/selftest.sh` — 17 standards, 3 aggregate cases, 13 format-hook, 20 git-hook, 5 compaction-audit, 14 entry-point (SC-001)
- [x] T031 Run `LINT_FORCE_CONTAINER=1 sh scripts/lint.sh` — the container path returns the same verdict (SC-001)
- [x] T032 Demonstrate SC-002: reinstating the subshell form makes `lint/errexit` fail, and restoring it makes it pass
- [x] T033 Demonstrate SC-004: `check_main markdwon` in `scripts/lint-markdown.sh` passes `scripts/lint-shell.sh` and fails `scripts/selftest.sh` at `entry/lint-markdown.sh`
- [x] T034 Confirm SC-003: no `scripts/` path is executed from another `scripts/` file outside `scripts/selftest.sh`'s smoke cases

## Notes

- `skills/` is untouched throughout, so `.claude-plugin/plugin.json` correctly needs no version bump. That is the one case where not bumping is right, and it is worth stating because the repository's default is to bump.
- The branch is `refactor/scripts-lib-modules`, not `012-scripts-lib-modules`. It was cut before the feature was numbered; renaming it would orphan the open pull request. Recorded in `plan.md` under Development Workflow.
