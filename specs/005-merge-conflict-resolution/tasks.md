---
description: 'Task list for 005-merge-conflict-resolution'
---

# Tasks: Merge Conflict Resolution

**Input**: Design documents from `/specs/005-merge-conflict-resolution/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: This repository has no unit-test runner; the quality checks are the tests, and `specs/001-quality-gate-plugin/plan.md` records that decision. The specification requested no TDD approach, so no test-framework tasks are generated. Verification tasks instead run the repository's own gate and the numbered scenarios in [quickstart.md](./quickstart.md), which is what SC-001 through SC-009 are actually measured by.

**Organization**: Tasks are grouped by user story so each can be implemented and verified independently. US1 alone is a viable increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: US1, US2 or US3, mapping to the user stories in [spec.md](./spec.md)
- Every task names an exact path

## Path Conventions

This repository holds no application code, so there is no `src/` or `tests/`. Paths are as [plan.md](./plan.md)'s Structure Decision records them: documentation under `docs/`, the new skill under `skills/ccd-conflict-resolve/`, path-scoped rules under `.claude/rules/`, configuration at the repository root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Make the quality gate govern the content this feature is about to add, before any of it exists. Doing this first means every later task is checked as it lands rather than retrofitted.

- [x] T001 [P] Narrow the `.claude` exclusion in `.prettierignore` so `.claude/rules/` is checked while the rest of `.claude/` stays excluded (FR-005a)
- [x] T002 [P] Narrow the `.claude` exclusion in the `ignores` array of `.markdownlint-cli2.jsonc`, using the `/**` directory form that file's other entries use (FR-005a)
- [x] T003 [P] Narrow the `.claude` exclusion in the `Exclude` array of `.editorconfig-checker.json`, which holds anchored regexes rather than globs (FR-005a)
- [x] T004 Create `docs/` and `.claude/rules/` directories
- [x] T005 Run `sh scripts/lint.sh` and confirm it still exits 0 with the three narrowed declarations and two empty directories (SC-007)

**Checkpoint**: The three documentation checks now reach `.claude/rules/`. `.yamllint.yml`, `ruff.toml` and `.shellcheckrc` are deliberately untouched — no rule file is YAML, Python or shell, and widening those would be scope creep the constitution's one-declaration-per-check rule does not need.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The committed record of what the plugin ships must be corrected in the same change that changes it. These tasks block nothing technically, but leaving them until last is how a repository ends up asserting a skill count it does not have.

- [x] T006 Add a "Superseded by" banner to `specs/003-ccd-skill-rename/contracts/skill-names.md` pointing at `specs/005-merge-conflict-resolution/contracts/skill-names.md`, leaving that file's body intact as the record of what feature 003 shipped (FR-021)
- [x] T007 Create the skill directory `skills/ccd-conflict-resolve/scripts/`

**Checkpoint**: The superseding contract at `contracts/skill-names.md` is already on disk from the plan phase; T006 is the other half of the pair. The count it states becomes true when T008 lands.

---

## Phase 3: User Story 1 — Resolve a conflicted working tree under guidance (Priority: P1) 🎯 MVP

**Goal**: A contributor with a conflicted tree reaches a resolved one, having been shown an explanation and a justified recommendation at every decision, with nothing modified before they approved it.

**Independent test**: Build the scratch repository from [quickstart.md](./quickstart.md), create a conflict, invoke the skill, and confirm the contributor reaches a conflict-free tree through it. Delivers the whole of the feature's user-facing value even if no documentation were written.

### The scripts

- [x] T008 [P] [US1] Write `skills/ccd-conflict-resolve/scripts/conflict-preflight.sh` emitting the ten `key<TAB>value` lines and exit codes 0/1/2/3 in [contracts/conflict-scripts-cli.md](./contracts/conflict-scripts-cli.md); probe `git` before anything else, detect the operation from the pseudorefs in the documented `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `REBASE_HEAD` order, and report `operation` and `conflicts` as independent facts (FR-009, FR-010, FR-017, FR-020)
- [x] T009 [P] [US1] Write `skills/ccd-conflict-resolve/scripts/conflict-list.sh` emitting `path<TAB>kind<TAB>stages<TAB>text` from `git status --porcelain=v2`, sorted by path so the output is deterministic where git's ordering is undefined, classifying the seven documented `XY` codes and deriving `type-changed` and `binary` (FR-011, FR-015, FR-019, SC-005)
- [x] T010 [P] [US1] Write `skills/ccd-conflict-resolve/scripts/conflict-apply.sh` taking `<mechanism> <path>` and accepting all five mechanisms — `ours`, `theirs`, `union`, `staged` and `remove` — staging with `git add -- <path>` one path per invocation, using `git rm -- <path>` for `remove`, rejecting an invalid mechanism-for-kind pairing with exit 3, and refusing with exit 4 when a `staged` apply would stage a file still carrying conflict markers (FR-013, FR-015, FR-017c)
- [x] T010a [US1] Confirm `conflict-apply.sh` resolves a `both-deleted` path through `remove`, since that kind has neither stage 2 nor stage 3 and every content-selecting mechanism is invalid for it — without `remove` the kind is reportable but unresolvable (FR-019)
- [x] T011 [P] [US1] Write `skills/ccd-conflict-resolve/scripts/conflict-conclude.sh` dispatching on the detected operation, refusing with exit 4 when staged paths outside the resolution are present, and never reverting resolved content when concluding fails (FR-017b, FR-017c)
- [x] T012 [US1] Confirm all four scripts open `#!/bin/sh` then `set -u`, indent with tabs, and pass `shellcheck --shell=sh --severity=style` with zero findings (Constitution II and IV)

### The skill

- [x] T013 [US1] Write `skills/ccd-conflict-resolve/SKILL.md` with frontmatter carrying `name: ccd-conflict-resolve` and a description that opens with the triggering use case and states what the skill is not for; **no** `disable-model-invocation` and **no** `user-invocable` field (FR-008, FR-018)
- [x] T014 [US1] In `skills/ccd-conflict-resolve/SKILL.md`, write the workflow: availability check, remote update, identification, proposal with explanation and justified recommendation, approval, application, re-identification, and conclusion — invoking each script as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"` (FR-010 through FR-014, FR-017a)
- [x] T015 [US1] In `skills/ccd-conflict-resolve/SKILL.md`, require candidate resolutions to name the branch and whose change is discarded in concrete terms, never the bare words "ours" and "theirs", because those reverse under rebase (FR-012, research §3.5)
- [x] T016 [US1] In `skills/ccd-conflict-resolve/SKILL.md`, write the safety boundaries: never `git reset --hard`, `git checkout --force`, `git stash drop`, `git clean` or `git add -A`; never resolve without approval; never enable `rerere.enabled` or set `merge.conflictStyle` (FR-016)
- [x] T017 [US1] In `skills/ccd-conflict-resolve/SKILL.md`, handle the non-content conflict kinds — modify/delete, both-deleted, type change and binary — with whole-file candidates rather than line-level ones, offering `remove` where the resolution is to accept the deletion (FR-019)
- [x] T017a [US1] In `skills/ccd-conflict-resolve/SKILL.md`, offer abandoning the operation as a skill-body action alongside the per-path candidates — never as a `conflict-apply.sh` mechanism, since it acts on the whole operation — running the `--abort` matching the detected operation, always available, never the recommendation, and stated with research §3.8.3's caveat that reconstruction may be incomplete where uncommitted changes were present (FR-016)
- [x] T018 [US1] In `skills/ccd-conflict-resolve/SKILL.md`, handle an unreachable remote by reporting and asking whether to continue against on-disk state (FR-020)
- [x] T019 [US1] Confirm `skills/ccd-conflict-resolve/SKILL.md` is under 500 lines, per the documented guidance in research §2.4.3, moving reference material to supporting files if it is not
- [x] T020 [P] [US1] Write `skills/ccd-conflict-resolve/evaluations.md` with the scenarios to re-run after editing the skill, matching the convention the four sibling skills already use

### Verify US1

- [x] T021 [US1] Run quickstart Scenario 3 and confirm exit 2, `no-git:` on stderr, no other output, and zero modified paths (FR-009, SC-004)
- [x] T022 [US1] Run quickstart Scenario 4 twice and confirm the two reports are byte-identical, which is what makes the distributed procedures deterministic rather than merely present (FR-011, FR-015, SC-005)
- [x] T023 [US1] Run quickstart Scenario 5 and confirm nothing is modified before approval, and that declining every option leaves the tree untouched (FR-012, FR-016, SC-006)
- [x] T024 [US1] Run quickstart Scenario 6 against a **rebase** conflict and confirm the options describe effects concretely rather than surfacing "ours"/"theirs" (FR-012)
- [x] T025 [US1] Run quickstart Scenario 7 both ways and confirm a staged unrelated path blocks concluding, and an unstaged one survives it uncommitted (FR-017c, SC-006a)
- [x] T026 [US1] Run quickstart Scenarios 8 and 9 and confirm iteration reports lack of progress, and that a modify/delete conflict is offered whole-file candidates only (FR-014, FR-019)
- [x] T027 [US1] Run quickstart Scenario 10 and confirm six skills, all `ccd-`-prefixed, and zero `disable-model-invocation` in the new skill (FR-018, FR-021)

**Checkpoint**: US1 is independently shippable here. The skill resolves conflicts under guidance; no documentation or instruction change is required for it to work.

---

## Phase 4: User Story 2 — Learn the practices from published documentation (Priority: P2)

**Goal**: A contributor finds the three subjects documented with their sources, and can act on any of them without reading source code.

**Independent test**: Read `docs/` and confirm each subject is covered and every practice is either sourced or explicitly marked as having no authoritative source.

- [x] T028 [P] [US2] Write `docs/claude-code-practices.md` from research §1: memory precedence and the 200-line target, `@path` imports and their four-hop limit, path-scoped rules with the `paths:` key and the trap that omitting it loads the file unconditionally, settings precedence and list-merging, hook events, and the plugin manifest's additive `skills` field (FR-001, FR-004)
- [x] T029 [P] [US2] Write `docs/skill-authoring-practices.md` from research §2: the frontmatter field set, the 1,536-character description budget and further truncation with many skills, the 500-line body target, compaction keeping the first 5,000 tokens, `${CLAUDE_SKILL_DIR}` versus `${CLAUDE_PLUGIN_ROOT}`, invoking scripts through `sh`, and the documented evaluation route (FR-002, FR-004)
- [x] T030 [P] [US2] Write `docs/merge-conflict-practices.md` from research §3: detecting the operation, listing and classifying conflicts, the three conflict styles with `zdiff3`'s 2.35.0 floor, the ours/theirs reversal under rebase, resolution mechanisms including `rerere`, what concluding actually commits, and the commands that destroy work (FR-003, FR-004)
- [x] T031 [US2] Record every gap found in research as a gap in the relevant document rather than filling it — the `disable-model-invocation` silence, the undocumented rebase state directories, the undocumented stage-presence mapping, the absent executable-bit guarantee (FR-004, SC-002)
- [x] T032 [US2] Record in `docs/skill-authoring-practices.md` the three corrections research made to this repository's own earlier artifacts: the basename claim in `specs/002/data-model.md:25`, the absent length guidance, and `argument-hint` (FR-004)
- [x] T033 [US2] Run quickstart Scenario 11 and confirm three documents exist and every practice carries a source or a recorded gap (SC-002, SC-009)

**Checkpoint**: The documentation stands on its own and is the source the next phase aligns the repository's instructions to.

---

## Phase 5: User Story 3 — Repository instructions that agree with the documentation (Priority: P3)

**Goal**: Nothing an agent is told in this repository contradicts what a contributor reads, and no statement this feature made untrue is left standing.

**Independent test**: Read `CLAUDE.md`, the rule files and `docs/` against each other and find no contradiction; confirm every statement of the old skill count has been corrected.

- [x] T034 [US3] Update `CLAUDE.md`'s five-skill statements to six and add `ccd-conflict-resolve` to the distributed-skills description, keeping the file's existing voice and structure (FR-007, FR-021a)
- [x] T035 [US3] Update `CLAUDE.md`'s `disable-model-invocation` sentence so it states the invariant against six skills — still exactly one, still `ccd-speckit-run` — rather than being silently falsified by the sixth (FR-007, FR-021a)
- [x] T036 [US3] Correct `README.md:43`'s "The five skills" heading and any surrounding count, as a factual correction under FR-021a rather than a rule placement under FR-006
- [x] T037 [P] [US3] Write two path-scoped rule files under `.claude/rules/`, each with YAML frontmatter carrying a `paths:` key and glob patterns (FR-006, FR-006a): `skill-authoring.md` scoped to `skills/**` for the conventions in T040, and `shell-scripts.md` scoped to `**/*.sh` for the POSIX dialect, tab indentation and fail-fast rules the constitution already mandates. Any further rule file is a deliberate addition, not an implied one.
- [x] T038 [US3] Add to `CLAUDE.md` only rules that are repo-wide, durable, not already recorded, and not derivable from the codebase; route anything area-scoped to a rule file instead (FR-006, FR-006c)
- [x] T039 [US3] Confirm `CLAUDE.md` remains under 200 lines; move content to a rule file rather than exceeding it (FR-006b)
- [x] T040 [US3] Record the `${CLAUDE_SKILL_DIR}` convention for a skill's own scripts, and `${CLAUDE_PLUGIN_ROOT}` for genuinely shared ones, so the next skill follows it without rediscovering research §1.6 (FR-006)
- [x] T041 [US3] Record that Markdown in this repository uses spaces inside fenced code blocks even though `.sh` files use tabs, since `.editorconfig`'s `[*.md]` block overrides only `indent_size` and `trim_trailing_whitespace` (FR-006)
- [x] T042 [US3] Run quickstart Scenario 12 and confirm no stale count survives, `CLAUDE.md` is under 200 lines, and every rule file declares `paths:` (FR-006a, FR-006b, SC-003, SC-008)

**Checkpoint**: Instructions and documentation agree, and the repository's counting verification reports the intended state.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T043 Run `sh scripts/lint.sh` and confirm exit 0 across all seven checks (SC-007, Constitution Development Workflow)
- [x] T044 Run `sh scripts/selftest.sh` and confirm each check still rejects deliberately bad input, including through the three narrowed exclusion declarations
- [x] T045 Run quickstart Scenario 2 and confirm `.claude/rules/` is genuinely governed while the rest of `.claude/` is still excluded (FR-005, FR-005a)
- [x] T046 Run the verification block in [contracts/skill-names.md](./contracts/skill-names.md) and confirm six skills, zero non-`ccd-` directories, basenames matching frontmatter names, exactly one `disable-model-invocation`, and no `user-invocable: false`
- [x] T047 Run the verification block in [contracts/conflict-scripts-cli.md](./contracts/conflict-scripts-cli.md) and confirm the shebang and `set -u` preamble, zero ShellCheck findings, no forbidden staging or destructive command, and `CLAUDE_SKILL_DIR` rather than `CLAUDE_PLUGIN_ROOT` in the skill body
- [x] T048 Read `docs/`, `CLAUDE.md` and `.claude/rules/` against each other one final time and confirm no contradiction (SC-003)

---

## Dependencies

**Phase order**: Phase 1 → Phase 2 → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6.

**What actually blocks what**, as distinct from the phase numbering:

- T001–T003 block T037 and T042 in a way that matters: a rule file written before the exclusions are narrowed is a rule file nothing checks, and the omission is invisible because the gate stays green. This is the one ordering constraint in the feature that fails silently if ignored.
- T007 blocks T008–T011 and T013 — the directory must exist.
- T008–T011 block T014, because the skill body invokes the scripts and their exit codes are what it branches on.
- T013 blocks T014 through T019, all of which edit the same file.
- T028–T030 block T034 through T041: US3 aligns instructions to the documentation, so the documentation has to say something first.
- T006 pairs with the already-written `contracts/skill-names.md`, and both describe a count that only becomes true once T013 lands.
- Phase 6 depends on everything.

**Story independence**: US1 is genuinely independent — it needs Phase 1 and Phase 2 only. US2 is independent of US1. US3 depends on US2 by construction, since aligning instructions to documentation requires the documentation.

## Parallel execution

Within Phase 1, T001, T002 and T003 touch three different configuration files and can run together.

Within US1, T008 through T011 are four separate script files and can run together; T020 is independent of all of them. T014 through T019 all edit `SKILL.md` and must be sequential.

Within US2, T028, T029 and T030 are three separate documents and can run together.

Within US3, T037 is separable from the `CLAUDE.md` edits; T034, T035, T038, T039, T040 and T041 all touch `CLAUDE.md` and must be sequential.

## Implementation strategy

**MVP is US1.** Phases 1 through 3 deliver a working skill that resolves conflicts under guidance, and the feature is worth shipping at that point even if the documentation and instruction alignment followed later.

**Increment order** is the priority order, and it is also the dependency order, which is not a coincidence: the skill is the thing that changes what a contributor can do, the documentation records why it behaves the way it does, and the instructions align the repository to the documentation.

**Stop points**: after T027, after T033, and after T042 the tree is in a coherent, shippable state. T043 through T048 are verification rather than construction and add no new behaviour.
