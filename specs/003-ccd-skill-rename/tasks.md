---
description: 'Task list for feature 003-ccd-skill-rename'
---

# Tasks: Unambiguous skill names and a standards-conforming front page

**Input**: Design documents from `/specs/003-ccd-skill-rename/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: No test tasks. The specification requests none, and this repository's checks _are_ its tests — `scripts/lint.sh` plus the counting checks in `quickstart.md`. Those appear as verification tasks, not as authored tests.

## Read this before starting

Two facts decide whether this task list can be followed mechanically, and both are easy to get wrong:

1. **The names are a lookup, not a pattern.** Four of the five drop `auto-` while gaining `ccd-`. A global `s/^/ccd-/`, or any regex that derives the new name from the old, produces `ccd-auto-branch-push` and three siblings like it. Use the table in [contracts/skill-names.md](./contracts/skill-names.md) every time.
2. **Three strings contain an old name and must NOT change**: `.specify/.speckit-run-state.json`, `.specify/.speckit-dirty-snapshot`, and the stash message `speckit-run-base-switch`. `.gitignore` line 11 stays exactly as it is. A blind tree-wide substitution fails T044.

The tree is deliberately broken between Phase 2 and the end of Phase 4: the directories move first, and the references that point into them are fixed after. Do not run the quickstart scenarios until Phase 5.

## Phase 1: Setup

- [x] T001 Confirm the working tree is clean apart from this feature's own artifacts, and that `HEAD` is on branch `003-ccd-skill-rename`, by running `git status --short` and `git symbolic-ref --short HEAD` at the repository root
- [x] T002 Record the pre-change reference inventory as a file list, by running `grep -rl -e 'speckit-run' -e 'auto-branch-push' -e 'auto-commit-push' -e 'auto-github-pr' -e 'auto-gitlab-mr' skills/ README.md CLAUDE.md` and saving the output. Expect 23 files. This is the worklist Phases 3 to 5 must exhaust; it is not comparable to Scenario 4's post-change count, whose exclusions are meaningless before the rename
- [x] T003 Confirm `.claude-plugin/plugin.json` declares no `skills` field and no other component-path field, so Phase 6 can assert it is unchanged rather than merely unmodified

## Phase 2: Foundational — the directory moves and the frontmatter names

**Blocking.** Every user story below depends on the directories being at their new paths. Each task moves one directory and rewrites that skill's own frontmatter `name` in the same step, because a directory moved without its `name` field is FR-002's silent failure.

These are not `[P]`: `git mv` operations against the same index are serialised, and one failing part-way through is far easier to recover from a known sequence.

- [x] T004 `git mv skills/speckit-run skills/ccd-speckit-run`, then set `name: ccd-speckit-run` in `skills/ccd-speckit-run/SKILL.md` frontmatter, leaving `disable-model-invocation: true` in place
- [x] T005 `git mv skills/auto-branch-push skills/ccd-branch-push`, then set `name: ccd-branch-push` in `skills/ccd-branch-push/SKILL.md` frontmatter
- [x] T006 `git mv skills/auto-commit-push skills/ccd-commit-push`, then set `name: ccd-commit-push` in `skills/ccd-commit-push/SKILL.md` frontmatter
- [x] T007 `git mv skills/auto-github-pr skills/ccd-github-pr`, then set `name: ccd-github-pr` in `skills/ccd-github-pr/SKILL.md` frontmatter
- [x] T008 `git mv skills/auto-gitlab-mr skills/ccd-gitlab-mr`, then set `name: ccd-gitlab-mr` in `skills/ccd-gitlab-mr/SKILL.md` frontmatter
- [x] T009 Verify all five moves registered as renames rather than delete-plus-add by running `git status --short` and confirming every affected path shows `R`, so `git log --follow` still reaches each skill's history
- [x] T010 Verify directory basename equals frontmatter `name` for all five by running [quickstart.md](./quickstart.md) Scenario 2, expecting no output

---

## Phase 3: User Story 1 — A name that says which copy answers (Priority: P1)

**Goal**: each of the five is addressable under its new name, and the plugin presents no old name as current.

**Independent test**: with the plugin installed alongside a personal skill of an old name, invoke each of the five new names and confirm each reaches the plugin's copy — [quickstart.md](./quickstart.md) Scenario 11.

- [x] T011 [P] [US1] Rewrite the slash-command invocation forms in the frontmatter `description` and body of `skills/ccd-speckit-run/SKILL.md` from `/speckit-run` to `/ccd-speckit-run`
- [x] T012 [P] [US1] Rewrite every `/speckit-run` invocation in `skills/ccd-speckit-run/reference/evaluations.md` to `/ccd-speckit-run`
- [x] T013 [P] [US1] Rewrite every `/auto-branch-push` invocation in `skills/ccd-branch-push/evaluations.md` to `/ccd-branch-push`, including the "would take away the `/<name>` invocation" sentence in `skills/ccd-branch-push/SKILL.md`
- [x] T014 [P] [US1] Rewrite every `/auto-commit-push` invocation in `skills/ccd-commit-push/evaluations.md` to `/ccd-commit-push`, and the same sentence in `skills/ccd-commit-push/SKILL.md`
- [x] T015 [P] [US1] Rewrite every `/auto-github-pr` invocation in `skills/ccd-github-pr/evaluations.md` to `/ccd-github-pr`, and the same sentence in `skills/ccd-github-pr/SKILL.md`
- [x] T016 [P] [US1] Rewrite every `/auto-gitlab-mr` invocation in `skills/ccd-gitlab-mr/evaluations.md` to `/ccd-gitlab-mr`, and the same sentence in `skills/ccd-gitlab-mr/SKILL.md`
- [x] T017 [P] [US1] Rewrite the skill names in the header comments of `skills/ccd-speckit-run/scripts/cleanup-plan.sh`, `copy-env-files.sh`, `dirty-diff.sh` and `resume-state.sh`, changing only comment text and leaving every line of logic byte-for-byte as it is
- [x] T018 [US1] Update the five skill names and the three load-bearing bullets in `CLAUDE.md`'s `## The distributed skills` section, preserving the `ccd-` rationale bullet added before this feature's phases began and making no other edit to the file
- [x] T019 [US1] Confirm exactly one `disable-model-invocation` remains in the tree and it is on `skills/ccd-speckit-run/SKILL.md`, per [quickstart.md](./quickstart.md) Scenario 6

**Checkpoint**: the five skills are addressable and self-consistent. Cross-skill dispatch is still broken until Phase 4.

---

## Phase 4: User Story 2 — The pipeline still reaches the skills it hands work to (Priority: P1)

**Goal**: every namespaced dispatch string and cross-skill pointer names a skill that exists.

**Independent test**: [quickstart.md](./quickstart.md) Scenario 8 resolves every `claude-code-devkit:<name>` occurrence against `skills/`, expecting no unresolvable name.

- [x] T020 [US2] Rewrite the two `skill=claude-code-devkit:<name>` string literals and the `review-skill` comment in `skills/ccd-speckit-run/scripts/forge-detect.sh` to the new names. This script **prints** these values, so this is a behaviour change and not a comment edit; it MUST remain POSIX `sh` with zero shell static-analysis findings
- [x] T021 [P] [US2] Rewrite every `claude-code-devkit:<name>` occurrence in `skills/ccd-speckit-run/reference/ship.md`, including the forge routing table, the dispatch table and the `Skill(skill: …)` examples
- [x] T022 [P] [US2] Rewrite every `claude-code-devkit:<name>` occurrence and every bare old name in `skills/ccd-speckit-run/reference/preflight.md`, including the three `ls "${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md"` probes
- [x] T023 [P] [US2] Rewrite the `review_skill` example values and the `ship.subskill_calls` prose in `skills/ccd-speckit-run/reference/run-state.md`, and the `skill_dir` example path
- [x] T024 [P] [US2] Rewrite every old name in `skills/ccd-speckit-run/reference/evaluations.md`, covering the scenario setups, the expected `tooling.review_skill` values and the regression notes
- [x] T025 [P] [US2] Rewrite the `${CLAUDE_PLUGIN_ROOT}` script paths and the state-file prose in `skills/ccd-speckit-run/reference/worktree.md`, leaving `.specify/.speckit-run-state.json` and `.specify/.speckit-dirty-snapshot` spelled exactly as they are
- [x] T026 [P] [US2] Rewrite the dispatch names, the `${CLAUDE_PLUGIN_ROOT}` script paths, the red-flag table rows and the authoring note in `skills/ccd-speckit-run/SKILL.md`
- [x] T027 [P] [US2] Rewrite the cross-skill pointer in `skills/ccd-branch-push/SKILL.md` that names `claude-code-devkit:auto-commit-push`
- [x] T028 [P] [US2] Rewrite the two cross-skill pointers in `skills/ccd-github-pr/SKILL.md` — to the branch skill and to the GitLab skill — and the dispatch names in its authoring note
- [x] T029 [P] [US2] Rewrite the two cross-skill pointers in `skills/ccd-gitlab-mr/SKILL.md`, its wrong-forge guard naming the GitHub skill, and the dispatch names in its authoring note
- [x] T030 [P] [US2] Rewrite the cross-skill mentions in `skills/ccd-github-pr/evaluations.md` and `skills/ccd-gitlab-mr/evaluations.md`
- [x] T031 [US2] Confirm every namespaced dispatch resolves, per [quickstart.md](./quickstart.md) Scenario 8, expecting no output

**Checkpoint**: dispatch is whole. The shared helper's path is still wrong until Phase 5.

---

## Phase 5: User Story 3 — The shared helper still resolves (Priority: P1)

**Goal**: exactly one `branch-options.sh`, at its new path, reached by all four consumers.

**Independent test**: [quickstart.md](./quickstart.md) Scenario 5 — one copy found, four references to the new path, zero to the old.

- [x] T032 [US3] Rewrite the consumer list and the `${CLAUDE_PLUGIN_ROOT}` invocation line in the header comment of `skills/ccd-branch-push/scripts/branch-options.sh`, changing comment text only and leaving the script's logic and output byte-for-byte unchanged
- [x] T033 [P] [US3] Rewrite the two `auto-branch-push/scripts/branch-options.sh` path references in `skills/ccd-branch-push/SKILL.md` to the `ccd-branch-push` path
- [x] T034 [P] [US3] Rewrite the two path references in `skills/ccd-github-pr/SKILL.md`, and the count assertion in `skills/ccd-github-pr/evaluations.md` that greps for the old path
- [x] T035 [P] [US3] Rewrite the two path references in `skills/ccd-gitlab-mr/SKILL.md`, and the count assertion in `skills/ccd-gitlab-mr/evaluations.md`
- [x] T036 [P] [US3] Rewrite the path reference and the surrounding prose in `skills/ccd-speckit-run/reference/base-branch.md`, and the script table row in `skills/ccd-speckit-run/SKILL.md`
- [x] T037 [P] [US3] Rewrite the single-copy assertion commands in `skills/ccd-branch-push/evaluations.md` so they grep for the new path
- [x] T038 [US3] Confirm one copy and four consumers, per [quickstart.md](./quickstart.md) Scenario 5

**Checkpoint**: all three P1 stories complete. The rename is functionally whole; every remaining phase is documentation.

---

## Phase 6: User Story 4 — A front page a newcomer can act on (Priority: P2)

**Goal**: `README.md` follows the Standard Readme section order and its licence statement resolves.

**Independent test**: [quickstart.md](./quickstart.md) Scenario 13.

- [x] T039 [P] [US4] Create `LICENSE` at the repository root containing the MIT licence text, copyright Patrick Quijano, matching the `"license": "MIT"` field already declared in `.claude-plugin/plugin.json`
- [x] T040 [US4] Rewrite `README.md` to the Standard Readme section order — title, a description under 120 characters, table of contents, Install, Usage, Contributing, License — where Install covers adding the marketplace and installing the plugin, Usage presents the five skills under their new names with `ccd-speckit-run` as the entry point and retains the existing quality-checks content, Contributing points at the three templates in `.github/`, and License names MIT, the copyright holder and the `LICENSE` file. Markdown is one line per paragraph with no hard wrapping
- [x] T041 [US4] Confirm the licence statement resolves and matches the manifest, per [quickstart.md](./quickstart.md) Scenario 13

---

## Phase 7: User Story 5 — A reader of the superseded records is not misled (Priority: P3)

**Goal**: both superseded contracts say so, and differ by that alone.

**Independent test**: [quickstart.md](./quickstart.md) Scenario 14.

- [x] T042 [P] [US5] Add one superseded-by line to `specs/002-vendor-plugin-skills/contracts/skill-names.md` naming `specs/003-ccd-skill-rename/contracts/skill-names.md`, and change nothing else in that file
- [x] T043 [P] [US5] Add one superseded-by line to `specs/002-vendor-plugin-skills/contracts/branch-options.md` naming `specs/003-ccd-skill-rename/contracts/branch-options.md`, and change nothing else in that file

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T044 Confirm the three deliberate exclusions survived, per [quickstart.md](./quickstart.md) Scenario 9: `.gitignore` line 11 unchanged, both bookkeeping filenames unchanged, and the `speckit-run-base-switch` stash message still spelled as it was. **This is the task that catches an over-applied rename**, and every other check in this list would pass without it
- [x] T045 Confirm no old name survives in live content, per [quickstart.md](./quickstart.md) Scenario 4, expecting no output
- [x] T046 Confirm every `${CLAUDE_PLUGIN_ROOT}` bundled path resolves to a file that exists, per [quickstart.md](./quickstart.md) Scenario 7
- [x] T047 Confirm the skill inventory: five directories, all `ccd-`-prefixed, with exactly the five names listed in [contracts/skill-names.md](./contracts/skill-names.md) — [quickstart.md](./quickstart.md) Scenarios 1 and 3
- [x] T048 Run `sh scripts/lint.sh` and confirm exit `0`. If it fails, fix the file — never add a path to `.lintignore`, which would make `scripts/lint-scope.sh` fail because the other five ignore declarations no longer match
- [x] T049 Run `claude plugin validate . --strict` and confirm it passes, which also asserts no stray field was added to `.claude-plugin/plugin.json`
- [x] T050 Confirm `specs/001-quality-gate-plugin/` is untouched and `specs/002-vendor-plugin-skills/` differs by exactly two added lines, per [quickstart.md](./quickstart.md) Scenario 14
- [x] T051 Confirm no behaviour, wording, question order or recorded outcome changed beyond the names, by reviewing `git diff main -- skills/` and checking that every hunk is a name, a path containing a name, or a comment naming a skill (FR-015)
- [x] T052 Confirm `specs/003-ccd-skill-rename/research.md` cites an authoritative source and a `HARD`/`SOFT` classification for every external rule it relies on, with no uncited claim (FR-018, SC-009)
- [x] T053 Confirm `README.md` presents its sections in the Standard Readme order — title, description, table of contents, Install, Usage, Contributing, License — and that a reader could install the plugin from the Install section alone, per [quickstart.md](./quickstart.md) Scenario 13 (SC-006)

### Manual verification — cannot be completed unattended

These two need a live plugin install and are the only tasks in this list that a tooling run cannot tick. Leaving them unchecked at the end of an automated run is the expected outcome, not a failure; they are recorded so the gap is visible rather than silent.

- [ ] T054 With the plugin installed, invoke all five skills by their namespaced names and confirm 5 of 5 load, per [quickstart.md](./quickstart.md) Scenario 11 (SC-001)
- [ ] T055 Take a pipeline run through to its shipping step and confirm both the 6a commit handoff and the 6b review-request handoff reach a skill that exists (SC-004)

## Dependencies

```text
Phase 1 (Setup)
   └─> Phase 2 (Foundational: git mv + frontmatter) ── BLOCKS EVERYTHING
          ├─> Phase 3 (US1: user-facing names)
          ├─> Phase 4 (US2: dispatch)          ── independent of Phase 3
          ├─> Phase 5 (US3: shared helper)     ── independent of Phases 3 and 4
          ├─> Phase 6 (US4: README + LICENSE)  ── independent of all three P1 stories
          └─> Phase 7 (US5: superseded records) ── independent of everything above
                 └─> Phase 8 (Polish: whole-tree verification)
```

Phase 2 is the only hard blocker: every later phase edits files at their new paths. The five story phases are mutually independent and could be done in any order, or concurrently by different people. Phase 8 must be last, because every check in it is a count over the whole tree.

**Story independence caveat, stated plainly**: US1, US2 and US3 are independently _testable_ but not independently _shippable_. Between the end of Phase 2 and the end of Phase 5 the plugin is in a broken intermediate state — that is inherent to a rename with no alias (FR-016), not a defect in the sequencing. The first shippable point is the Phase 5 checkpoint.

## Parallel execution

Within Phase 3, T011–T017 touch seven disjoint sets of files and can run together. T018 and T019 are serialised after them.

Within Phase 4, T021–T030 are all `[P]`. T020 is not — it is the only script edit in the phase and the only one that changes behaviour. T031 is the phase's verification and runs last.

Within Phase 5, T033–T037 are `[P]`; T032 edits the helper itself and T038 verifies.

Phases 6 and 7 can run alongside Phases 3–5 entirely, since they touch `README.md`, `LICENSE` and two files under `specs/002-vendor-plugin-skills/` and nothing else.

## Implementation strategy

**MVP scope**: Phases 1, 2 and 3 — the five directories moved, their frontmatter names matching, and their user-facing invocations rewritten. That alone satisfies FR-001 and FR-002 and makes every skill addressable under its new name.

It is not, however, a safe stopping point: dispatch and the shared helper are still broken. Treat the MVP as a review checkpoint, not a release.

**Incremental delivery**: Phase 2 → 3 → 4 → 5 restores function in dependency order, with the tree whole at the Phase 5 checkpoint. Phases 6, 7 and 8 are documentation and verification and can follow at any pace.
