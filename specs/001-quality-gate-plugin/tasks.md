---
description: 'Task list for Repository Quality Gate and Plugin Packaging'
---

# Tasks: Repository Quality Gate and Plugin Packaging

**Input**: Design documents from `/specs/001-quality-gate-plugin/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/cli.md](./contracts/cli.md), [quickstart.md](./quickstart.md)

**Tests**: The spec's Assumptions section states that the checks are this repository's tests, and SC-002 requires each check be shown to catch a violation. `scripts/selftest.sh` is that proof and is treated as implementation, not as an optional test task.

**Organization**: Grouped by user story so each is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Every task names its exact file path

## Path Conventions

Repository tooling, not an application: configuration at the repository root, runners in `scripts/`, shared shell code in `scripts/lib/`, plugin manifest in `.claude-plugin/`. No `src/`, no `tests/` — per plan.md's Structure Decision.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: the scope declaration and version-control hygiene that everything else depends on

- [x] T001 Create `.gitignore` at the repository root covering agent-local and machine-local state: `.claude/logs/`, `.claude/settings.local.json`, `.remember/`, `.specify/.speckit-run-state.json`, `.specify/.speckit-dirty-snapshot`, `.specify/feature.json`, `node_modules/`, `.venv/`, `.ruff_cache/`, `.DS_Store` (FR-018)
- [x] T002 Create `.lintignore` at the repository root — one path or glob per line, `#` comments, covering `.git`, `.specify/`, `.claude/logs/`, `.claude/settings.local.json`, `.claude/skills/speckit-*`, `.remember/`, `node_modules/`, `.venv/`; header comment states this is the single declaration of scope per FR-013a (FR-013)
- [x] T003 Create the `scripts/` and `scripts/lib/` directories

**Checkpoint**: scope is declared in exactly one file, and the directory layout exists.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the shared shell layer every check is built on. **No user story can be implemented until this phase is complete** — all six runners call into it.

- [x] T004 Write `scripts/lib/images.sh` declaring the six image references as shell variables, each `name:tag@sha256:digest`, with a comment above each naming its provenance per research.md §9; leave digests as `TODO` placeholders for T005 to fill
- [x] T005 Resolve every digest from the live registry with `docker manifest inspect <name>:<tag>` and write the real values into `scripts/lib/images.sh` — never copy a digest from documentation or from memory (Principle III)
- [x] T006 Write `scripts/lib/common.sh` providing `die()` (message to stderr, exit with a given status), `have()` (wrapping `command -v`, never `which`), `usage()`, and `parse_args()` accepting only `--fix`, `-h`, `--help` and exiting `2` on anything else; `#!/bin/sh`, `set -eu`, POSIX only (contracts/cli.md, Principle II, Principle IV)
- [x] T007 Write `scripts/lib/scope.sh` providing `file_list()` — reads `.lintignore`, prefixes each pattern with `:(exclude)`, and runs `git ls-files -z --cached --others --exclude-standard -- <globs> <exclusions>`; exits `4` when not in a git working tree; emits NUL-separated paths (FR-013a, contracts/cli.md exit `4`)
- [x] T008 Add `run_tool()` to `scripts/lib/common.sh` implementing the three-step resolution from data-model.md: native on `PATH`, else container, else exit `3` naming both; container invocation uses `--rm`, mounts the repository at `/work` **read-only in check mode** and read-write in fix mode, and passes `-u "$(id -u):$(id -g)"` in fix mode (FR-009, FR-011, SC-007)
- [x] T009 Add `LINT_FORCE_CONTAINER` handling to `run_tool()` — any non-empty value skips native resolution entirely (contracts/cli.md Environment)
- [x] T010 Add `NO_COLOR` handling to `scripts/lib/common.sh` so the runners' own `==>` output is plain when it is set; tool output is never modified (contracts/cli.md)
- [x] T011 Write `.shellcheckrc` at the repository root with `shell=sh`, `severity=style`, `external-sources=true`, `source-path=SCRIPTDIR`, and `enable=` for `add-default-case`, `check-extra-masked-returns`, `check-set-e-suppressed`, `deprecate-which`; a comment records why `enable=all` is rejected (research.md §3, Principle IV)

**Checkpoint**: the shared layer resolves tools, computes the file list, and is itself governed by a committed ShellCheck configuration. Every user story can now proceed.

---

## Phase 3: User Story 1 — Check the repository against its own standard (Priority: P1)

**Goal**: six content standards, each with one committed configuration and one runnable check that names the file and line of every violation.

**Independent test**: introduce a known violation of each standard, run that standard's check, confirm it exits non-zero naming the location; correct it and confirm it passes. Delivers value even if nothing else ships.

- [x] T012 [P] [US1] Write `.editorconfig` with `root = true`; `[*]` setting `charset = utf-8`, `end_of_line = lf`, `insert_final_newline = true`, `trim_trailing_whitespace = true`, `indent_style = space`, `indent_size = 2`; `[*.{py,sh}] indent_size = 4`; `[*.md] trim_trailing_whitespace = false`; `[Makefile] indent_style = tab` (research.md §6, FR-001, FR-002)
- [x] T013 [P] [US1] Write `.markdownlint-cli2.jsonc` with `noProgress: true` and a `config` object disabling `MD013`, setting `MD024.siblings_only: true`; no `globs`, no `ignores`, no `gitignore` key — scope belongs to `.lintignore` (research.md §1, FR-002, FR-013a)
- [x] T014 [P] [US1] Write `.yamllint.yml` with `extends: default`, `line-length: disable`, `document-start: disable`, `truthy: {level: error, check-keys: false}`; no `ignore` or `ignore-from-file` key (research.md §2, FR-002, FR-013a)
- [x] T015 [P] [US1] Write `ruff.toml` with `line-length = 100`, `target-version = "py39"`, `[lint] select` naming the default categories plus `I`, `SIM`, `PTH`, `S`, and `[format]` with `line-ending = "lf"` and `docstring-code-format = true` (research.md §5, FR-002)
- [x] T016 [P] [US1] Write `.prettierrc.json` with `endOfLine: "lf"`, `printWidth: 100`, `proseWrap: "preserve"`, and an `overrides` entry setting `tabWidth: 2` for `*.json`/`*.jsonc` (research.md §4, FR-002)
- [x] T017 [P] [US1] Write `.prettierignore` excluding `*.md`, `*.yml`, `*.yaml` — Markdown and YAML belong to their own standards; a header comment states this file protects a contributor invoking Prettier directly and is **not** the scope declaration (research.md §4, FR-013a)
- [x] T018 [P] [US1] Write `scripts/lint-editorconfig.sh` — sources the lib, file list is every in-scope file, native `editorconfig-checker` else `mstruebing/editorconfig-checker`; `--fix` prints that no automatic fix exists and changes nothing (FR-003, FR-012a)
- [x] T019 [P] [US1] Write `scripts/lint-format.sh` — globs `*.json`, `*.jsonc`; native `prettier` else the pinned `node` image running `npx --yes prettier@<version>`; `--check` in check mode, `--write` under `--fix` (FR-003, FR-012, research.md §9)
- [x] T020 [P] [US1] Write `scripts/lint-markdown.sh` — globs `*.md`, `*.markdown`; native `markdownlint-cli2` else `davidanson/markdownlint-cli2`; `--fix` passes `--fix` through (FR-003, FR-012)
- [x] T021 [P] [US1] Write `scripts/lint-yaml.sh` — globs `*.yml`, `*.yaml`; native `yamllint` else the pinned `python` image installing `yamllint==<version>`; `--fix` prints that no automatic fix exists (FR-003, FR-012a, research.md §9)
- [x] T022 [P] [US1] Write `scripts/lint-shell.sh` — glob `*.sh`; native `shellcheck` else `koalaman/shellcheck`; `--fix` prints that no automatic fix exists (FR-003, FR-012a, FR-017)
- [x] T023 [P] [US1] Write `scripts/lint-python.sh` — globs `*.py`, `*.pyi`; native `ruff` else `ghcr.io/astral-sh/ruff`; check mode runs `ruff check` then `ruff format --check`, `--fix` runs `ruff check --fix` then `ruff format` (FR-003, FR-012)
- [x] T024 [US1] Make every script under `scripts/` executable (`chmod +x`) and confirm each begins `#!/bin/sh` followed by `set -eu` (Principle II, Principle IV)
- [x] T025 [US1] Add the empty-file-list case to each runner: exit `0` printing `no files in scope` rather than failing or staying silent (spec Edge Cases, contracts/cli.md)
- [x] T026 [US1] Write `scripts/lint.sh` — the aggregate entry point; runs `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python` in that declared order, prints one `==>` line per check naming how its tool resolved, stops at the first non-zero and returns that status unchanged (FR-004, FR-007, contracts/cli.md)
- [x] T027 [US1] Run `scripts/lint-shell.sh` against the repository and fix every finding in the runners themselves until it exits `0` — the tooling is not exempt from the standard it enforces (FR-017, constitution Quality Gate Requirements)
- [x] T028 [US1] Run `scripts/lint.sh` and bring the repository's existing content into conformance until it exits `0`; where a violation reveals a wrong configuration rather than wrong content, fix the configuration and record the reason in research.md (SC-006)

**Checkpoint**: `scripts/lint.sh` exits `0` on a clean tree, each check runs standalone, and quickstart.md Scenarios 1, 2 and 9 pass.

---

## Phase 4: User Story 2 — Get the same verdict without installing anything (Priority: P1)

**Goal**: the container path produces the same verdict as the native path, and a missing tool fails loudly rather than silently.

**Independent test**: run the aggregate check with `LINT_FORCE_CONTAINER=1` and compare verdict and violation list against the native run; then run with an empty `PATH` and no Docker and confirm exit `3` naming both.

- [x] T029 [US2] Verify each image reference in `scripts/lib/images.sh` resolves and runs: for all six, `docker run --rm <ref> --version` (or the tool's equivalent) succeeds (Principle III)
- [x] T030 [US2] Run `LINT_FORCE_CONTAINER=1 scripts/lint.sh` and reconcile its output against the native run until verdict and violation set match, the `==>` resolution lines being the only permitted difference (FR-008, SC-003, quickstart Scenario 4)
- [x] T031 [US2] Verify the read-only mount is real: with `LINT_FORCE_CONTAINER=1` and no `--fix`, confirm `git status --porcelain` is byte-identical before and after (SC-007, quickstart Scenario 2)
- [x] T032 [US2] Verify the unavailable path: `PATH=/nonexistent scripts/lint-markdown.sh` with Docker also unreachable exits `3` and names both the missing command and the image; confirm no check ever reports success without evaluating content. In the same task, assert FR-010: the container run required no language runtime, package manager, virtual environment or install step on the host — the only host-side prerequisites are a POSIX shell, `git` and Docker (FR-010, FR-011, quickstart Scenario 6)
- [x] T033 [US2] Verify fix-mode file ownership: run a `--fix` through the container path and confirm rewritten files are owned by the calling user, not root (plan.md tool resolution)
- [x] T034 [US2] Write `scripts/selftest.sh` — for each of the six standards, materialise a deliberately non-conforming fixture under `$(mktemp -d)` outside the repository, run that check against it, assert non-zero exit and that the fixture path appears in the output; `EXIT` trap removes the directory; exits `0` only if every check failed as it should (SC-002, FR-006, contracts/cli.md)
- [x] T035 [US2] Run `scripts/selftest.sh` and fix any check that passes bad input — a check that cannot fail is not a check (SC-002, quickstart Scenario 3)

**Checkpoint**: quickstart Scenarios 3, 4 and 6 pass. The verdict is independent of what the caller has installed.

---

## Phase 5: User Story 3 — Understand why each standard is set the way it is (Priority: P2)

**Goal**: every setting that departs from its tool's documented default has a written, cited reason.

**Independent test**: pick any non-default setting in any committed configuration and find the reason and the upstream citation in the written record.

- [x] T036 [US3] Audit every committed configuration against the defaults recorded in research.md and confirm each departure appears in that file's non-default table; add any that is missing (FR-014, SC-004)
- [x] T037 [US3] Confirm every standard's section in research.md cites the upstream documentation it was derived from, with a working link (FR-015)
- [x] T038 [P] [US3] Add a `## Quality checks` section to `README.md` naming `scripts/lint.sh`, the `--fix` flag, the per-standard scripts, and where the rationale lives — the commands a reader cannot guess, per the Claude Code best-practices "include" column (research.md §11)
- [x] T039 [P] [US3] Add the check commands to `CLAUDE.md` under a `## Build, lint, test` heading, replacing the current "None yet" text; keep it to the commands themselves and a pointer, not a tutorial (research.md §11)

**Checkpoint**: SC-004 is verifiable by comparison rather than by trust.

---

## Phase 6: User Story 4 — Install the repository as a Claude Code plugin (Priority: P2)

**Goal**: Claude Code recognises the repository as `claude-code-devkit`.

**Independent test**: install the repository as a plugin and confirm it is listed by name — no dependency on any check.

- [x] T040 [US4] Create `.claude-plugin/plugin.json` with `name: "claude-code-devkit"`, plus `displayName`, `description` drawn from `README.md`, `version: "0.1.0"`, `author`, `homepage`, `repository`, `license`, `keywords`; declare **no** component-path field (research.md §10, FR-016)
- [x] T041 [US4] Confirm the manifest is valid JSON and passes `scripts/lint-format.sh` — it is in scope and is not exempt (data-model.md validation rules)
- [x] T042 [US4] Confirm no component directory (`skills/`, `commands/`, `agents/`, `hooks/`, `.mcp.json`) was created and that `.claude/skills/speckit-*` was not vendored into the plugin (research.md §10, spec Out of Scope)
- [x] T043 [US4] Install the plugin locally and confirm `claude-code-devkit` is listed; record the exact command used in quickstart.md Scenario 8 if it differs from what is written there (SC-005)

**Checkpoint**: quickstart Scenario 8 passes.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T044 Verify scope has exactly one source: `grep` the six tool configurations for `.specify`, `node_modules` and `.remember` and confirm no hit (SC-008, FR-013a, quickstart Scenario 7)
- [x] T045 Verify every configuration file is itself inside the checked scope — a configuration exempt from its own standard is a standard nobody checks (data-model.md validation rules)
- [x] T046 Verify every image reference matches `^[a-z0-9./-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$`; a reference missing either the tag or the digest fails Principle III
- [x] T047 Run every scenario in [quickstart.md](./quickstart.md) end to end and correct any that does not behave as written — the quickstart is a contract with the reader, not a sketch
- [x] T048 Re-read [contracts/cli.md](./contracts/cli.md) against the implementation and confirm every documented exit status (`0`, `1`, `2`, `3`, `4`) is actually produced by the code; specifically assert FR-005 (non-zero when a violation is found, zero when none is) and FR-005a (a `--fix` run that rewrote files exits zero, because rewriting is success and not a violation left standing) (FR-005, FR-005a)
- [x] T049 Review the `spec-review.md` checklist items CHK017 and CHK018 against the finished implementation and record the outcome in that file's Notes section
- [x] T050 Verify SC-001 by counting rather than by impression: `README.md`'s quality-checks section names exactly one command; that command needs no preceding install step; and it runs with no arguments. Any of the three failing means SC-001 is unmet (SC-001)

---

## Dependencies

**Phase order**: Setup (T001–T003) → Foundational (T004–T011) → user stories → Polish.

**Blocking**: Phase 2 blocks every user story. Nothing in Phases 3–6 can start before T011.

**Story dependencies**:

- **US1 (P1)** depends on Phase 2 only. It is the MVP.
- **US2 (P1)** depends on US1 — there must be checks before their container path can be compared. T029 is the exception and can run any time after T005.
- **US3 (P2)** depends on US1 (the configurations must exist to be audited). Independent of US2 and US4.
- **US4 (P2)** depends on nothing but Phase 1. T041 needs `scripts/lint-format.sh` from US1; the rest of US4 does not.

**Within US1**: T012–T023 are all `[P]` — twelve different files, no shared state. T024–T028 are sequential and depend on all of them.

## Parallel execution examples

**Phase 3, the twelve independent files** — six configurations and six runners, all different paths:

```text
T012 .editorconfig          T018 scripts/lint-editorconfig.sh
T013 .markdownlint-cli2.jsonc  T019 scripts/lint-format.sh
T014 .yamllint.yml          T020 scripts/lint-markdown.sh
T015 ruff.toml              T021 scripts/lint-yaml.sh
T016 .prettierrc.json       T022 scripts/lint-shell.sh
T017 .prettierignore        T023 scripts/lint-python.sh
```

**Phase 5**: T038 (`README.md`) and T039 (`CLAUDE.md`) touch different files and can run together.

**Across stories**: once Phase 2 is complete, US4's T040 and T042 can proceed alongside US1 — they share no file.

## Implementation strategy

**MVP is US1 alone.** Six standards, six checks, one aggregate command that exits `0` on a clean tree. That is a repository with a working quality gate, and everything after it is a strengthening of a thing that already works.

**Then US2**, because it is the story that makes the gate trustworthy to someone other than its author — until the container path is verified, "the same verdict without installing anything" is a claim rather than a property.

**US3 and US4 are independent** and can land in either order, or in parallel. US4 is the smallest and closes the gap between what `README.md` promises and what the repository does.

**Stop condition**: `scripts/lint.sh` exits `0`, `scripts/selftest.sh` exits `0`, and every quickstart scenario behaves as written. Anything beyond that — CI wiring, a `PostToolUse` hook, marketplace publication — is out of scope for this feature and named as such in the spec.

## Amendment 2026-09-02 — Phases A1 to A7, tasks T051 onward

T001 to T050 delivered the original spec and are complete. The tasks below cover the amendment only: per-check ignore declarations (FR-013a/b/c), the formatting standard's scope and defaults policy (FR-019 to FR-023), and the six capability extensions (FR-024 to FR-027). Numbering continues rather than restarting, so a task ID identifies one piece of work across the whole feature.

### Phase A1: Setup — spec-tooling extensions

- [x] T051 Install the four vetted extensions from the default catalog: `specify extension add agent-context`, `assess`, `bug`, `git`. Confirm each reports installed and enabled in `specify extension list` (FR-024)
- [x] T052 Install the two community extensions by pinned archive URL, which `specify extension add <id>` cannot resolve by name: `superb` from `https://github.com/RbBtSn0w/spec-kit-extensions/releases/download/superpowers-bridge-v1.9.0/superpowers-bridge.zip` and `token-budget` from `https://github.com/tinesoft/spec-kit-token-budget/archive/refs/tags/v1.1.0.tar.gz`. Record the installed version of each — the catalog's v1.6.0 and v1.0.1 are stale (FR-024, FR-026, research.md §17)
- [x] T053 Set explicit hook ranks in `.specify/extensions.yml`: `superb` 10, `token-budget` 20, `agent-context` 30, `assess` and `bug` 40, `git` 50. Edit the per-hook `priority` values directly — `specify extension set-priority` sets resolution priority, not hook order. Write the ordering principle and the re-registration warning into the file as comments beside the numbers (FR-025, FR-025a, research.md §18)
- [x] T054 [P] Classify every path the six extensions create, per research.md §19: narrow `.lintignore`'s wholesale `.specify` exclusion so `.specify/assessments/` and `.specify/bugs/` are in scope while the generated scripts and templates stay out, and add the extensions' machine-local run state to `.gitignore` (FR-018, FR-027)

### Phase A2: Foundational — blocking prerequisites for the story phases

- [x] T055 Rewrite `.prettierrc.json`: remove `endOfLine`, `proseWrap` and the JSON override's `tabWidth` as restated Prettier 3.9.6 defaults, which empties that override; keep `printWidth: 100`; add `trailingComma: "none"` and `singleQuote: true` (FR-019, FR-020, research.md §14)
- [x] T056 [P] Add the two pinned plugin versions to `scripts/lib/images.sh`: `@prettier/plugin-xml@3.4.2` and `prettier-plugin-sh@0.19.0`, each with a comment naming the content kind it serves and its peer requirement (FR-021)
- [x] T057 Teach `scripts/lint-format.sh` and `scripts/lib/common.sh` plugin resolution: resolve each declared plugin on the native path, print which resolved, route a content kind whose plugin is absent to the container path, and install prettier plus both plugins in one `npx --yes --package …` invocation there. Absent plugin **and** no container is FR-011's existing hard failure (FR-023 as clarified, FR-008)

### Phase A3: User Story 1 — each check declares its own scope (Priority: P1)

**Goal**: a contributor invoking a tool by hand, outside `scripts/`, gets the same scope the runner gives them.

**Independent test**: run each tool directly against the repository and confirm its own output shows it skipped the paths `.lintignore` excludes.

- [x] T058 [P] [US1] Add the `ignores` array to `.markdownlint-cli2.jsonc` — the property, not a separate `.markdownlintignore` file (FR-013a)
- [x] T059 [P] [US1] Add the `ignore` block scalar to `.yamllint.yml` (FR-013a)
- [x] T060 [P] [US1] Add the `exclude` array to `ruff.toml` (FR-013a)
- [x] T061 [US1] Rewrite `.prettierignore` as Prettier's own scope declaration rather than a by-hand courtesy, and remove the `*.md`, `*.markdown`, `*.yml` and `*.yaml` entries, which FR-022 makes wrong (FR-013a, FR-022)
- [x] T062 [P] [US1] Create `.editorconfig-checker.json` with an `Exclude` list. These are **regexes**, not globs, combined with `|` — different syntax from every other declaration here (FR-013a)
- [x] T063 [P] [US1] Record ShellCheck's absent exclusion mechanism where a reader of `.shellcheckrc` will find it: a comment in that file pointing at research.md §13, stating that `--exclude` takes warning codes rather than paths (FR-013c)
- [x] T064 [US1] Write `scripts/lint-scope.sh`: for each check, compare the files `.lintignore` puts in scope against the files the tool reports it would visit; exit `1` naming the differing paths on a mismatch; ask the tool where it can be asked and compare declarations textually where it cannot; report the shell check as unverifiable on every run rather than counting it as agreement (FR-013b, FR-013c, SC-008)
- [x] T065 [US1] Add `scope` to `CHECKS` in `scripts/lint.sh` so a divergence fails the aggregate run rather than waiting to be noticed (FR-013b, FR-004)

### Phase A4: User Story 1 — one configuration per concern (Priority: P1)

- [x] T066 [US1] Inline the rules from `markdownlint/style/prettier.json` into `.markdownlint-cli2.jsonc` as `false`, with a comment citing the upstream file. Do **not** use `"extends": "markdownlint/style/prettier"` — it resolves through Node module lookup and this repository has no `node_modules`, so it would work on some machines and not others (FR-022, SC-009, research.md §16)
- [x] T067 [US1] Disable the ten yamllint rules Prettier rewrites — `braces`, `brackets`, `colons`, `commas`, `hyphens`, `indentation`, `empty-lines`, `new-line-at-end-of-file`, `new-lines`, `trailing-spaces` — with a written reason. Leave `comments` and `comments-indentation` **enabled**: Prettier preserves YAML comments and enforces nothing about them, so disabling those would delete a check rather than relocate it (FR-022, SC-009, research.md §16)
- [x] T068 [US1] Add the formatting overrides to `.prettierrc.json` for the four content kinds in FR-021 — Markdown and YAML on core Prettier, XML through the XML plugin, shell through the sh plugin (FR-021, SC-009)

### Phase A5: User Story 2 — the verdict still does not depend on what is installed (Priority: P1)

- [x] T069 [P] [US2] Add self-test fixtures for the two content kinds the formatter newly covers, on the same terms as the existing six: a deliberately misformatted XML file and shell script in `scripts/selftest.sh`, each asserted to be rejected and named (SC-002, FR-006)
- [x] T070 [US2] Add a self-test case proving `lint-scope.sh` fails when two declarations disagree, by writing a fixture ignore file that excludes a path `.lintignore` does not (FR-013b, SC-002)
- [x] T071 [US2] Verify format parity with the plugins absent natively and present in the container: identical verdict and identical violation list, and the native run states which content kinds it routed to the container (FR-008, FR-023, SC-013)

### Phase A6: User Story 3 — the written record covers the amendment (Priority: P2)

- [x] T072 [P] [US3] Verify research.md §14 records every Prettier default this repository now relies on without restating, which is the condition both amended FR-002 and constitution v1.2.0 attach to omitting it (FR-002, FR-019, SC-004, SC-010)
- [x] T073 [US3] Correct `CLAUDE.md`: the bullet stating scope is declared once in `.lintignore` and forbidding per-tool exclusions is made false by T058 to T063. Replace it with what becomes true — `.lintignore` drives the runner's file list, each check declares its own skipped paths, and `scripts/lint-scope.sh` verifies they agree (FR-013a)
- [x] T074 [US3] Update `README.md`'s quality-checks table: the format row now governs Markdown, YAML, XML, shell and JSON; add the `scripts/lint-scope.sh` row. Keep the section naming exactly one whole-repository command, which SC-001 counts (FR-014, SC-001)

### Phase A7: Polish & verification

- [x] T075 [P] Verify SC-009 by counting: every content kind in FR-021 has exactly one configuration governing formatting and at most one governing linting, and 0 have two of either
- [x] T076 [P] Verify SC-010 by comparing each key in `.prettierrc.json` against Prettier 3.9.6's documented defaults: 0 keys equal to a default
- [x] T077 [P] Verify SC-011 and SC-012: `specify extension list` twice with 0 ordering differences, all six enabled, and every hook rank derivable from the written principle with 0 mutating hooks ranked before observing ones at the same event
- [x] T078 Run `scripts/lint.sh` and `scripts/selftest.sh` on both the native and `LINT_FORCE_CONTAINER=1` paths; all four must exit `0`
- [x] T079 Run quickstart Scenarios 10 to 15 as written and correct any inaccuracy in `quickstart.md` from the actual output, the way T047 did for Scenarios 1 to 9
- [x] T080 [P] Verify SC-014: the written record names every check whose tool has no path-exclusion mechanism, and `scripts/lint-scope.sh` reports 0 of them as agreeing (FR-013c, SC-014)
- [x] T081 [P] Verify SC-015: both community-catalog extensions have their source URL, installed version and declared effect in research.md §17 -- 2 of 2 (FR-026, SC-015)

### Amendment dependencies

- T051 and T052 block T053: ranks can only be set on hooks that are registered.
- T053 blocks T077.
- T055 blocks T068 — the override array is emptied and rebuilt in that order, so doing them out of order reintroduces the `tabWidth` default.
- T056 blocks T057, and T057 blocks T071.
- T058 to T063 block T064: there must be six declarations before anything can compare them.
- T064 blocks T065 and T070.
- T061 and T066 and T067 together satisfy FR-022; T075 verifies the result, so all three block it.
- T058 to T063 block T073, which describes what they made true.
- Everything blocks T078 and T079.

### Amendment parallel opportunities

- T058, T059, T060, T062, T063 — five different configuration files, no shared state.
- T054 with any of Phase A2 — different files.
- T075, T076, T077 — three independent verifications, all read-only.
