# Tasks: Format on modification, and one exclusion declaration per check

**Input**: Design documents from `/specs/004-format-hook-scope/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: This repository's test suite is `scripts/selftest.sh`, which proves each check rejects deliberately bad input. Spec.md makes it the verification vehicle for SC-005, SC-010 and SC-002, so its fixtures are **required** tasks here, not optional ones. There is no separate unit-test framework and none is introduced.

**Organization**: Tasks are grouped by user story so each can be implemented and tested independently. US1 (P1, the hook) and US2 (P2, per-check exclusions) are genuinely independent — see plan.md's Build order, which corrects an earlier claim that they were not.

## Format: `[ID] [P?] [Story] Description`

- **[P]** — parallelizable: touches files no other incomplete task touches.
- **[US1]** / **[US2]** — the user story this task serves. Setup, Foundational and Polish tasks carry no story label.

## Path Conventions

Repository root is the working directory for every command. All paths are repository-relative. Shell is POSIX `sh`, tab-indented, and every script under `scripts/` is subject to `lint-shell.sh` — that is a constitutional requirement, not a style preference.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: build the mechanism that compares each check's file list before and after half one, **without storing anything in the tree it measures**.

An earlier draft of this phase committed baseline snapshots into `specs/004-format-hook-scope/baseline/` and put the harness in `scripts/`. Both were defects, found by `/speckit-analyze` as finding F1, and the reason is worth keeping: `scripts/lint-editorconfig.sh:19` is `collect '*'` — **every file** — and `lint-format.sh` and `lint-shell.sh` both match `*.sh`. So the snapshots and the harness would each enter the after-lists, and the equality proof would fail for reasons that are not defects. research.md §14 already prescribed the fix and the draft contradicted it.

- [x] T001 Read `specs/004-format-hook-scope/research.md` §10–§14 and `contracts/exclusion-declaration.md` before touching `scripts/lib/`. Every non-obvious decision in half one, including the two hardening fixes and the three properties of the equality comparison, is recorded there rather than in the code.
- [x] T002 Write the scope-snapshot harness **outside the repository tree** — in the session scratch directory, never under `scripts/` and never anywhere `git ls-files` enumerates. It takes a working-tree path and a check name, sources that tree's `scripts/lib/scope.sh`, and prints the file list that check's `collect` would receive: one repository-relative path per line, sorted. It reads each check's globs from that check's own script rather than duplicating them. Because it lives outside the tree it is exempt from the Quality Gate clause on scripts under `scripts/` — which is the point; a harness inside `scripts/` would have to be linted, and would perturb the very lists it measures.
- [x] T003 Prove the harness is deterministic before trusting it: run it twice against the unmodified tree for each of `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python` and require byte-identical output. `git ls-files` order is exactly the kind of thing that varies between runs, so this is what makes the sort in T002 load-bearing rather than cosmetic. A harness that is not deterministic makes T037 a test of nothing — **and T037 would still pass**.
- [x] T004 Establish how the "before" side is obtained at proof time: create a detached worktree of the base commit (`git worktree add --detach <scratch path> main`), run the harness against **that** tree, and remove the worktree afterwards. Nothing is stored in the working tree, so nothing perturbs it, and the baseline cannot drift from what the code actually did — research.md §14's requirement. Record the exact command sequence in `specs/004-format-hook-scope/research.md` so T037 does not have to rediscover it.

**Checkpoint**: the comparison mechanism exists, is deterministic, and leaves no trace in the tree. No baseline files are committed. Half one may now proceed at any point.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the optional `-- <path>...` argument. Blocking for US1 only; US2 does not depend on it.

**⚠️ CRITICAL for US1**: the hook has nothing to call until T005–T008 are done.

- [x] T005 Extend `parse_args()` in `scripts/lib/common.sh` to accept an optional trailing `--` followed by any number of paths, setting a NUL-separated `REQUESTED_PATHS` and leaving `MODE` untouched. Arguments before `--` keep today's rules exactly: `--fix`, `-h`, `--help`, anything else is exit 2 with usage on stderr. POSIX `sh`, no arrays — the paths accumulate in a NUL-separated string, the same technique `exclude_pathspecs` already uses in `scripts/lib/scope.sh`.
- [x] T006 Extend `collect()` in `scripts/lib/common.sh` so that when `REQUESTED_PATHS` is non-empty it **filters** `file_list`'s output down to those paths, resolving each against the repository root first so relative and absolute forms behave identically. Filter the computed list; never validate the requested paths and pass them through — the second form would let a caller reach an excluded or out-of-glob file, breaking FR-006 and FR-007. Empty result keeps today's `no files in scope` message and exit 0.
- [x] T007 Update `usage()` in `scripts/lib/common.sh` to document `[-- PATH...]`, keeping the existing exit-status line unchanged. The set of exit statuses does not grow; `contracts/check-cli.md` explains why a path list matching nothing is 0 rather than a new code.
- [x] T008 [P] Amend `specs/001-quality-gate-plugin/contracts/cli.md`: the Common shape's "accepts at most one argument, `--fix`" and "Any other argument is a usage error", to admit the trailing path list. Reference `specs/004-format-hook-scope/contracts/check-cli.md` as the amending document rather than restating it.
- [x] T009 Confirm backward compatibility mechanically: `scripts/lint.sh` and each `scripts/lint-<check>.sh` with no arguments, and with bare `--fix`, produce the same verdict and the same file list as before T005. Compare against Phase 1's baseline. This is FR-017 and it is checked here rather than assumed, because Phase 2 is the only phase that touches argument parsing for all seven checks at once.

**Checkpoint**: every check accepts `--fix -- <path>` and behaves identically without it. US1 can begin.

---

## Phase 3: User Story 1 — A modified file is already formatted (Priority: P1) 🎯 MVP

**Goal**: a file the session edits is conformant by the time the edit is reported done, with no command run by hand, and nothing else touched.

**Independent Test**: quickstart.md scenario 5 — modify one Markdown file into a non-conformant state in a session where the hook is active; the file is conformant afterwards and `git status --porcelain` names that file and no other.

### Implementation for User Story 1

- [x] T010 [US1] Create `scripts/format-file.sh`: shebang `#!/bin/sh`, `set -eu`, `PROG`/`SCRIPT_DIR`/`REPO_ROOT` computed exactly as the existing scripts compute them, and the recursion guard tested first — `CCD_FORMAT_FILE_ACTIVE` set on entry means exit 0 silently. Do not source `lib/common.sh`: this script is a hook entry point with a different contract, and `common.sh`'s `parse_args` would reject the arguments the hook runner does not send.
- [x] T011 [US1] Implement stdin extraction in `scripts/format-file.sh`: read the payload, pull `tool_input.file_path` with the `sed` expression from research.md §4, take the first match only. Empty or absent → exit 0 silently. Write the comment explaining why this is not `jq` — Principle I — and why the one blind spot is safe: a truncated path fails the regular-file test and is refused.
- [x] T012 [US1] Implement the six path rules in `scripts/format-file.sh`, in the order data-model.md fixes them: extractable, directory enterable, `pwd -P`-resolved and prefixed by `$REPO_ROOT/` **including the trailing slash**, exists, is a regular file, no NUL byte in the first 8 KiB. Every rejection is exit 0 with no output and no write. Use `pwd -P` rather than `realpath` or `readlink -f`; research.md §5 records why neither is portable enough.
- [x] T013 [US1] Implement the three check invocations in `scripts/format-file.sh`: `lint-format.sh`, then `lint-markdown.sh`, then `lint-python.sh`, each `--fix -- "$resolved"`. Take the order from `scripts/lint.sh`'s `CHECKS` and say so in a comment — Markdown is governed by two rewriting checks and the result depends on which ran first (FR-005). Carry **no** extension-to-check mapping: each check self-filters by its own globs, which is what keeps that mapping in one place.
- [x] T014 [US1] Implement the outcome mapping in `scripts/format-file.sh` per data-model.md's Check invocation table: exit 0 with files in scope → status line; exit 0 with `no files in scope` → no message, continue; exit 1, 2 or 4 → stop, exit 2, stderr carrying the path, the check and the check's **unmodified** output; exit 3 → visible skip naming the missing native tool and the image, then continue. Stop at the first stopping status; do not run the remaining checks (Principle II).
- [x] T015 [US1] Implement the two output channels in `scripts/format-file.sh`: `systemMessage` JSON on stdout with the `==>` prefix from `common.sh`'s `say()`, and the failure detail on stderr. Escape backslashes and double quotes in the path before interpolating it into the JSON — the reference warns that a malformed payload produces a parse notice even on exit 0.
- [x] T016 [US1] Export `CCD_FORMAT_FILE_ACTIVE=1` in `scripts/format-file.sh` before the first check invocation, and comment that the guard is the _second_ of two independent guarantees: `PostToolUse` fires on tool calls and the formatters write to disk without one, so the loop cannot form through the designed path. Say why it is a variable and not a lock file — a stale lock disables formatting silently.
- [x] T017 [US1] `chmod +x scripts/format-file.sh`.
- [x] T018 [US1] Create `.claude/settings.json` with the `PostToolUse` block from `contracts/format-file-cli.md`: matcher `Edit|Write|MultiEdit|NotebookEdit`, `type: command`, `command` referencing the script through the literal `${CLAUDE_PROJECT_DIR}` placeholder, and `args: []` for exec form. Never a hardcoded absolute path — correct on one machine, silently broken everywhere else. Never `Bash` in the matcher.
- [x] T019 [US1] Confirm `.claude/settings.json` is committable: it is not covered by `.gitignore`'s three `.claude` entries (`logs/`, `settings.local.json`, `prompt.md`). `git check-ignore -v .claude/settings.json` must find no match.
- [x] T020 [US1] Run `scripts/lint-shell.sh` and confirm zero findings for `scripts/format-file.sh`. Constitutional, per Principle IV and the Quality Gate clause putting every script under the script directory in the shell check.

### Self-test fixtures for User Story 1

- [x] T021 [P] [US1] Add a `scripts/selftest.sh` fixture for each of the six rejection paths from quickstart.md scenario 6: outside the repository, non-existent, a directory, a missing `file_path` field, non-JSON input, and a symlink inside the repository resolving outward. Each must exit 0, print nothing, and leave the tree unchanged. The symlink case is the one a naive string-prefix test passes by formatting the wrong file — assert on the link target being unchanged, not just on the exit status.
- [x] T022 [P] [US1] Add a `scripts/selftest.sh` fixture for the failure path: a file a rewriting check cannot fix, asserting exit 2 and that stderr names the file, the check, and the check's own output. Follow the existing `verdict()` convention, which already asserts that output names the fixture file.
- [x] T023 [P] [US1] Add a `scripts/selftest.sh` fixture for the unavailable-tooling skip (FR-018, SC-010): a check forced to exit 3, asserting the hook exits 0 and the message names both the missing native tool and the pinned image. Not exit 2 — that would make a container runtime a precondition for editing, which Principle I forbids.
- [x] T024 [P] [US1] Add `scripts/selftest.sh` fixtures for the three byte-identical cases from quickstart.md scenario 10: an excluded path, an unsupported file kind, and binary content. Assert byte equality with `cmp`, and for the first two assert that no status line was printed.
- [x] T025 [P] [US1] Add a `scripts/selftest.sh` fixture for the recursion guard: invoke with `CCD_FORMAT_FILE_ACTIVE=1` and assert exit 0, no output, no write.

**Checkpoint**: US1 is complete and independently shippable. Every scenario in quickstart.md 5–10 passes, `scripts/lint.sh` and `scripts/selftest.sh` both exit 0. Half one has not started.

---

## Phase 4: User Story 2 — An excluded path is declared once (Priority: P2)

**Goal**: each check declares its excluded paths in exactly one place — the configuration that already drives it — with no central list and no check policing agreement between copies.

**Independent Test**: quickstart.md scenario 2 — for each of the seven checks, the file list is byte-identical to Phase 1's baseline. Then add one excluded path to a single check's own configuration and confirm only that check's list changes.

### Implementation for User Story 2

- [x] T026 [US2] Promote the six extractors from `scripts/lint-scope.sh:55-100` into `scripts/lib/scope.sh` verbatim — `extract_plain`, `extract_markdownlint`, `extract_yamllint`, `extract_prettier`, `extract_ruff`, `extract_editorconfig` — keeping their comments, which record why the editorconfig one deletes every backslash and why the sets are sorted. Do not rewrite them; they already emit exactly the normalised form `exclude_pathspecs` consumes.
- [x] T027 [US2] Harden `extract_ruff` in `scripts/lib/scope.sh`: make the trailing comma optional, as `extract_markdownlint` already does. As a cross-check a dropped last element failed loudly; as the source of a file list it is a silent scope hole (research.md §13).
- [x] T028 [US2] Make every extractor in `scripts/lib/scope.sh` fail loudly when its configuration file is absent or its declaration block is not found — exit non-zero naming the file, via `die`. Keep "file present, block present, no paths declared" as a distinct legal state returning an empty list. This inversion is the main risk half one carries: what used to be a loud mismatch would otherwise become a silent "exclude nothing" (Principle II).
- [x] T029 [US2] Add the marked exclusion block to `.shellcheckrc` — `# lint-exclude-begin` … `# lint-exclude-end`, one commented path per line, carrying exactly the paths `.lintignore` excluded. Document above it that the block is the single declaration for the shell check, that ShellCheck itself ignores it as a comment, and that a hand-run `shellcheck` therefore does **not** get these exclusions because the tool offers no mechanism for it. **Must not exclude `scripts/`** — the constitution requires every script there to be checked.
- [x] T030 [US2] Add `extract_shellcheck` to `scripts/lib/scope.sh`, modelled on `extract_plain`: strip the leading `#` from lines between the markers, drop blanks, sort. Missing markers is the T028 failure, not an empty list.
- [x] T031 [US2] Rework `exclude_pathspecs()` and `file_list()` in `scripts/lib/scope.sh` to take the check's exclusion source rather than reading `LINTIGNORE`. Each check passes its own; `file_list` emits the `:(exclude)` pathspecs from that extractor's output. Rewrite the file's header comment, which currently states that `.lintignore` is "the only place exclusions live" — the exact claim this task inverts.
- [x] T032 [US2] Update each of the six file-list-consuming check scripts to name its own exclusion source when calling `collect`: `lint-editorconfig.sh`, `lint-format.sh`, `lint-markdown.sh`, `lint-yaml.sh`, `lint-shell.sh`, `lint-python.sh`. Leave `lint-citations.sh` alone — it consumes no file list, so it has no exclusions to declare (research.md §15).
- [x] T033 [US2] Delete `.lintignore`.
- [x] T034 [US2] Delete `scripts/lint-scope.sh`. Its extractors live in `scripts/lib/scope.sh` after T026; nothing else in it survives, because with one declaration per check there is no second copy to compare against.
- [x] T035 [US2] Remove `scope` from `CHECKS` in `scripts/lint.sh:33`, leaving seven, and delete the paragraph of the preceding comment explaining why `scope` led. Keep the `citations`-leads rationale, which still holds.
- [x] T036 [US2] Remove every live reference to `scripts/lint-scope.sh` from code and code comments. Four sites, found by `/speckit-analyze` as finding F4 and named here because a search for "the scope-divergence fixture" finds only one of them: `scripts/selftest.sh:293` (comment), `scripts/selftest.sh:305` (**copies the script into a fixture root**), `scripts/selftest.sh:318` (**executes it**), and `scripts/lint-citations.sh:31` (comment citing the scope agreement it verified). Confirm whether `selftest.sh:293-318` is one fixture or two before deleting; `.shellcheckrc:51` is handled by T029.

### Self-test fixtures for User Story 2

- [x] T037 [US2] Add the scope-equality fixture to `scripts/selftest.sh`. It obtains the "before" side at proof time by the mechanism T004 established — a detached worktree of the base commit, run through T002's out-of-tree harness — and compares, for each of the **six** file-list-consuming checks, against the current tree's list after sorting. Nothing is read from a committed snapshot: there is none, deliberately (F1). **Per check, not in aggregate** — a path lost by one check and gained by another sums to zero and is a defect. This is FR-025 and SC-002, and it is the fixture to disbelieve last.
- [x] T038 [P] [US2] Add `scripts/selftest.sh` fixtures for T028's loud failures: a check whose declaration file is missing, and one whose declaration block is absent. Each must exit non-zero and name the file. Without these two fixtures the inversion T028 guards against is untested.
- [x] T039 [US2] Run the equality proof and record the result in `specs/004-format-hook-scope/research.md` §14: **six** comparable lists, zero paths gained, zero lost, plus `citations`, which has no file list and is therefore not comparable (research.md §15). Six, not seven — an earlier draft said seven, which `/speckit-analyze` flagged as F7. A difference is a defect in this change, never grounds for amending FR-024.

**Checkpoint**: both stories complete and independently verified. `scripts/lint.sh` names seven checks and exits 0; six of them have a comparable file list and all six are unchanged.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: the documentation obligations, and the stale claims half one creates. FR-029 makes these requirements, not tidying.

- [x] T040 [P] Update `CLAUDE.md`'s "Build, lint, test" section: "all eight checks" → seven; drop `scope` from the list of per-standard scripts; rewrite the bullet stating that `.lintignore` drives the runner's file list while each check also declares its own — the new arrangement is one declaration per check, read by the runner and by the tool alike; and correct the sentence naming `scope` and `citations` as the two checks needing no tool.
- [x] T041 [P] Add one line to `CLAUDE.md` about the hook: a future session needs to know its own edits are rewritten under it, and which three checks do the rewriting. Additive and minimal — do not restructure the file, and keep it well under the 200-line target.
- [x] T042 [P] Mark FR-013, FR-013a, FR-013b and FR-013c in `specs/001-quality-gate-plugin/spec.md` as superseded by feature 004, following how `specs/003-ccd-skill-rename/` superseded 002's two interface contracts. Do not delete them — the record of what was decided and why is what makes the supersession legible.
- [x] T043 [P] Update `specs/001-quality-gate-plugin/contracts/cli.md`: delete the `scripts/lint-scope.sh` section; replace the "reads its scope from `.lintignore` and nothing else" clause; and correct the aggregate's check list, which already disagrees with the code (it names six where `lint.sh` runs eight) and becomes seven. That pre-existing error is in scope because this task edits the same line for the same reason.
- [x] T044 [P] Correct the `.gitignore` comment on `.lint-selftest-tmp/` claiming it must be "Also in `.lintignore` -- both are required". The fixtures are excluded through each check's own declaration now.
- [x] T045 [P] Correct `README.md`: line 7 says "one command, eight checks", and it references `.lintignore` and `lint-scope`. Confirmed present, not conditional.
- [x] T045a Sweep the whole repository for live references to the deleted file and the deleted check, and correct every one. `git grep -l '\.lintignore'` matches **28** tracked files and `git grep -l 'lint-scope'` matches **25**; `/speckit-analyze` raised the narrow task list as finding F2. **Live** means: the six exclusion configs' own header comments — `.prettierignore:11`, `.markdownlint-cli2.jsonc:4,8,18`, `.yamllint.yml:5,12,19`, `ruff.toml:9`, `.editorconfig-checker.json:8`, `.shellcheckrc:50` — plus `README.md`, `CLAUDE.md`, `scripts/lib/scope.sh`, `scripts/lint.sh`, and this feature's own contracts. The six config comments matter most: they are what a contributor reads to understand the new arrangement, and each currently explains that the runner computes the file list from `.lintignore` while the config merely mirrors it. That is now backwards — the config **is** the declaration.
- [x] T045b Leave `specs/001-quality-gate-plugin/`, `specs/002-vendor-plugin-skills/` and `specs/003-ccd-skill-rename/` historical artifacts unedited, except for T042's supersession markers. SC-009 was narrowed to live documents for exactly this reason (`/speckit-analyze` finding F3): rewriting three features' records would contradict T042's own approach and produce a large diff of changes to decisions nobody is revisiting. Confirm that after T045a, the only remaining matches are in those historical artifacts, and record the count.
- [x] T045c Assert FR-015 mechanically: `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` contain no `hooks` key, and no `hooks/` directory exists at the repository root. `/speckit-analyze` raised FR-015 as having zero coverage (finding F5); feature 001 tasked the same assertion as its T042, so there is precedent for checking rather than assuming. A `hooks` key or a `hooks/` directory would distribute this behaviour to every consumer of the plugin, which spec.md names a non-goal.
- [x] T046 Document the hook in the repository's own docs: behaviour, dependencies, supported file kinds, failure handling, and how to extend it to a new file kind. The extension answer is the interesting one and is short: add the kind to a check's globs, or add a rewriting check to `format-file.sh`'s list — there is no mapping table in the hook to edit.
- [x] T047 Document the single-authority obligation (FR-030, SC-012): the one-line stand-down test `[ -x "$WORKSPACE_REAL/scripts/format-file.sh" ] && exit 0`, where it goes in an externally configured formatter, and why this repository does not apply it itself — FR-030 forbids editing configuration outside its own root. State plainly that this is a documentation obligation rather than an enforceable property: until the line is applied, both formatters run, and the repository can neither detect nor fix that from inside.
- [x] T048 Record every setting in this feature that departs from a tool's or platform's default, with its reason, in `specs/004-format-hook-scope/research.md` — the convention `specs/001-quality-gate-plugin/research.md` established. Audit the implemented code against research.md's 17 sections and add anything the implementation decided that the research did not.
- [x] T049 Confirm the tree carries no residue of the comparison mechanism: no harness under `scripts/`, no `specs/004-format-hook-scope/baseline/` directory, no leftover detached worktree from T004 (`git worktree list` shows only this run's). An earlier draft made this a conditional "delete it, or move it into `scripts/lib/` and lint it", which `/speckit-analyze` flagged twice — as F8 (a task with two mutually exclusive outcomes) and F9 (a script living unlinted in `scripts/` between T002 and here, while T009 and T020 each run `scripts/lint.sh`). T002's out-of-tree placement dissolves both; this task verifies it held.
- [x] T050 Run the full gate: `scripts/lint.sh`, `scripts/selftest.sh`, and `LINT_FORCE_CONTAINER=1 scripts/lint.sh`. All three exit 0, and the native and container paths agree. `editorconfig-checker` is absent natively on the development machine, so that check runs containerised in both.
- [x] T051 Walk every scenario in `specs/004-format-hook-scope/quickstart.md` and confirm each passes as written. A self-test that passes while a scenario fails means the self-test is missing a fixture — a defect in the self-test, not a reason to ship. Scenarios 4 and 11 are the two whose only coverage is this task: scenario 4 verifies FR-016 and SC-003, and scenario 11 verifies FR-020 and SC-011 by inspection, per the spec note added for `/speckit-analyze` finding F6. Record the outcome of both explicitly rather than folding them into a blanket pass.
- [x] T052 Update `specs/004-format-hook-scope/quickstart.md` scenarios 1 and 2 to match T002–T004 and T037: the baseline is obtained from a detached worktree of the base commit at proof time, not from files captured in advance and committed. Scenario 1 as written still describes the committed-snapshot approach that finding F1 rejected.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)** — no dependencies. **Must complete before Phase 4**; the baseline is unrecoverable once half one lands.
- **Phase 2 (Foundational)** — no dependencies. Blocks **Phase 3 only**.
- **Phase 3 (US1)** — needs Phase 2. Independent of Phase 4.
- **Phase 4 (US2)** — needs Phase 1. Independent of Phases 2 and 3.
- **Phase 5 (Polish)** — needs both stories, except T045 which can run any time.

### User Story Dependencies

**None.** US1 and US2 are independent. The hook reaches the checks through their CLI, which half one does not change, so US1 works against `.lintignore`-based scope and against per-check scope alike. plan.md's Build order records that an earlier draft claimed otherwise and why that was wrong.

### Within Each User Story

US1: script skeleton and guard (T010) → extraction (T011) → path rules (T012) → invocations (T013) → outcomes (T014) → output (T015) → guard export (T016) → executable (T017) → configuration (T018–T019) → shell check (T020) → fixtures (T021–T025).

US2: promote (T026) → harden (T027–T028) → shell declaration (T029–T030) → rework the list (T031) → per-check sources (T032) → delete (T033–T036) → prove (T037–T039). T031 is the pivot: nothing before it changes behaviour, and everything after it depends on it.

### Parallel Opportunities

- T008 runs alongside T005–T007 — different file.
- T021 through T025 are five independent fixtures; only T021 and T022 touch overlapping regions of `scripts/selftest.sh`, so treat that file as one writer at a time even where the tasks are marked `[P]`.
- T038 alongside T037.
- T040 through T045 are six independent documents.
- **Across stories**: all of Phase 3 can run alongside all of Phase 4, given Phase 1 is done and the two do not share a file. They do share `scripts/selftest.sh` and `scripts/lib/common.sh` — sequence those.

## Parallel Example: User Story 1

```text
# After T020, the five fixture tasks are independent in intent.
# scripts/selftest.sh is a single file, so run them as one writer:
T021  six rejection paths
T022  the failure path
T023  the unavailable-tooling skip
T024  the three byte-identical cases
T025  the recursion guard
```

## Implementation Strategy

**MVP is US1 alone.** It is what was asked for, it is independently shippable, and Phases 1–3 plus T040–T041 and T046–T047 deliver it complete with its documentation. US2 can follow in the same branch or a later one.

**The riskiest task is T028**, and it is worth naming. Promoting a comparison to a source inverts every failure mode: an extractor that used to return an empty list and cause a loud mismatch would now return an empty list and mean "exclude nothing", quietly widening a check's scope to include `.git`, Spec Kit's vendored scripts, and the self-test fixtures. T037 catches it against the baseline; T038 catches it directly. Neither is optional.

**The task most likely to be skipped is T004.** A baseline that is not reproducible makes T037 a test of nothing, and the failure is invisible — T037 would pass.
