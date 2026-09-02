# Implementation Plan: Repository Quality Gate and Plugin Packaging

**Branch**: `001-quality-gate-plugin` | **Date**: 2026-09-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-quality-gate-plugin/spec.md`

## Summary

Six content standards, each in one committed configuration file, each with one runnable check. Every check resolves its tool the same way — native binary on `PATH` first, digest-pinned container second, hard failure third — so the verdict does not depend on what the caller has installed. One aggregate entry point runs all six and stops at the first failure. Scope is declared once in `.lintignore` and turned into an explicit file list that every check consumes, so no two checks can disagree about what is in scope. Alongside this, `.claude-plugin/plugin.json` makes the repository installable as the Claude Code plugin its README already advertises.

Two decisions carry the design. First, **check mode mounts the repository read-only**: SC-007's guarantee that a no-argument run leaves the tree untouched becomes a property of the container boundary rather than a promise about six tools' behaviour. Second, **the file list is computed once** from a single declaration, which is what makes FR-013a's "all checks agree on scope" verifiable instead of aspirational.

**Amendment, 2026-09-02.** Four changes, and one of them inverts a design property above. (1) Each check now declares its own skipped paths in its own configuration (FR-013a), so a by-hand invocation outside the runner sees the same scope the runner does. The runner still computes the file list once from `.lintignore`, so run-time scope is unchanged — but scope agreement across six declarations is no longer structural, and FR-013b requires a check that verifies it. (2) The formatting standard extends to Markdown, YAML, XML and shell scripts, with the formatting-adjacent rules leaving markdownlint and yamllint so that no file is rewritten twice; the constitution's uniqueness rule became per content kind **and** concern at v1.2.0 to permit it. (3) The formatting configuration now states only settings that differ from Prettier's documented defaults, with the relied-on defaults recorded in `research.md` — permitted by Principle V at v1.2.0, which bars undeclared defaults rather than all defaults. (4) Six Spec Kit capability extensions are installed, with hook execution order set by explicit per-hook rank in `.specify/extensions.yml`.

## Technical Context

**Language/Version**: POSIX `sh` (IEEE Std 1003.1). No bash, no `set -o pipefail`, no arrays. Verified by ShellCheck with `shell=sh`.

**Primary Dependencies**: none at rest. At run time, per check, either the native tool or Docker. `git` is required for file enumeration. Two Prettier add-on plugins, `@prettier/plugin-xml@3.4.2` and `prettier-plugin-sh@0.19.0`, are pinned and fetched by the container path only; neither is a precondition on the native path. `specify` 1.0.2.dev0 installs the six capability extensions.

**Storage**: N/A — no persistent state. Configuration files only.

**Testing**: the checks are the tests. `scripts/lint.sh` from a clean checkout is the verification command. One deliberately non-conforming fixture per check proves the check actually fails, run through a self-test script rather than committed into the tree in a state that would fail the aggregate run. The amendment adds fixtures for the two content kinds the formatter newly covers, and adds `scripts/lint-scope.sh` — the scope-agreement verification FR-013b requires, which is a check in its own right and therefore part of the aggregate.

**Target Platform**: any POSIX shell on macOS or Linux, with or without the tools installed. Container path requires Docker.

**Project Type**: repository tooling plus a Claude Code plugin manifest. No application source.

**Performance Goals**: none stated in the spec, and none invented. The aggregate check is expected to be dominated by container start-up on machines without native tools; that is a cost, not a target.

**Constraints**: POSIX `sh` only (Principle IV); fail fast (Principle II); every image official or upstream and pinned by tag **and** digest (Principle III); no language runtime or package manager required of the caller (FR-010); every configuration committed, and any relied-on tool default declared in `research.md` (Principle V at v1.2.0); one governing configuration per content kind **per concern** (Quality Gate Requirements at v1.2.0).

**Scale/Scope**: 7 configuration files (`.editorconfig-checker.json` is new), 12 shell files (9 runners plus `selftest.sh` and 3 in `lib/`, once `lint-scope.sh` exists), 2 plugin manifests, 1 scope declaration, 1 gitignore, 1 extensions manifest with 6 installed extensions and **28** registered hooks (git 18, token-budget 6, agent-context 2, superb 2, assess 0, bug 0) -- counted from the installed manifest, not from the catalog, which advertises 5 hooks for `superb` where v1.9.0 registers 2. Repository currently holds 1 tracked file; 18 paths are uncommitted on this branch.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Constitution **v1.2.0**, ratified 2026-09-02, last amended 2026-09-02. Two amendments now sit behind this table. v1.1.0 was adopted in the previous run, when `analyze` found Principle III as written at v1.0.0 could not be satisfied by any available option. v1.2.0 was adopted at the start of this run, for two conflicts found before Phase 1: the Quality Gate Requirements clause forbade a content kind having both a formatter and a linter, and Principle V forbade relying on a tool default even where the tool version is pinned exactly.

| Principle                                | Gate                                                                                                | Verdict                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Tooling Independence (NON-NEGOTIABLE) | Does every check produce a verdict with only POSIX `sh` plus either the native tool or a container? | **Pass.** Three-step resolution in every runner. No check requires a package manager or virtual environment of the caller. `git` is required, and is neither.                                                                                                                                                                                                                                                                      |
| II. Fail Fast                            | Does every script exit non-zero on first failure, without masking exit status?                      | **Pass.** `set -eu` in every script; the aggregate stops at the first failing check; `pipefail` is unavailable so pipelines are restructured rather than status-swallowed. ShellCheck's `check-extra-masked-returns` and `check-set-e-suppressed` are enabled to enforce this mechanically.                                                                                                                                        |
| III. Pinned, Official Images             | Is every image official or upstream-published, pinned by tag and digest?                            | **Pass.** Four of six images are the tool author's or vendor's own. yamllint and Prettier publish none, and fall under Principle III's second clause (added at v1.1.0): a Docker **Official** language image pinned by tag and digest, with the tool's own version pinned exactly in the invocation. No floating tag anywhere.                                                                                                     |
| IV. POSIX Shell Only                     | Are all scripts POSIX `sh` and clean under static analysis in POSIX mode?                           | **Pass.** `.shellcheckrc` sets `shell=sh` and `severity=style`, so any bashism fails the check. The runner scripts are themselves in the checked file list (FR-017).                                                                                                                                                                                                                                                               |
| V. Configuration Is Committed            | Is every linter driven by a committed configuration file, with no undeclared default relied on?     | **Pass.** Seven configuration files plus `.lintignore`, the image-reference file and `.specify/extensions.yml`, all committed. Three Prettier keys that restated documented defaults are removed and recorded in `research.md` §14 instead, which is what the v1.2.0 wording permits and requires; the version pin that makes it safe is `prettier@3.9.6`. No editor setting or per-developer configuration is relied on anywhere. |
| VI. Spec-Driven Change                   | Did this work pass through the Spec Kit phases?                                                     | **Pass.** Spec amended in place, a second clarification session, three checklists, this plan; tasks and analyze to follow. The amendment did not skip a phase.                                                                                                                                                                                                                                                                     |

**Quality Gate Requirements section** at v1.2.0: "exactly one governing configuration file" per content kind **and concern** — satisfied. Markdown is formatted by `.prettierrc.json` and linted by `.markdownlint-cli2.jsonc`; YAML is formatted by the former and linted by `.yamllint.yml`; the 22 markdownlint rules and 10 yamllint rules that Prettier rewrites are disabled (upstream's preset lists 23; the 23rd is `line-length`, already disabled here for its own reason), so neither content kind has two configurations governing the same concern and no file is rewritten twice (research.md §16). XML and shell have a formatting configuration and, for shell, a separate linting one. "Runnable from the repository root without arguments" — satisfied; `--fix` is the only accepted argument and is optional. "MUST name the file and location of every violation" — satisfied by every tool's default output; no output format is suppressed beyond markdownlint-cli2's progress banner, which carries no violation information. "Every script MUST itself be subject to the shell static analysis check" — satisfied; `scripts/` is in scope, deliberately.

**Post-design re-check**: passes against v1.2.0. The amendment adds two pinned plugins, one configuration file, two scripts and one extensions manifest — each named by a requirement. Two new costs are recorded in Complexity Tracking rather than waved through: scope agreement is now verified rather than structural, and ShellCheck has no ignore mechanism to declare.

**One requirement the constitution cannot gate.** FR-026's provenance record covers two extensions installed from outside the vetted catalog, at the user's explicit direction after the boundary was flagged. No principle forbids it, and Principle V is satisfied because their configuration is committed — but nothing in the constitution makes an unvetted read-write extension a violation either, which is worth knowing rather than discovering later.

## Project Structure

### Documentation (this feature)

```text
specs/001-quality-gate-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── cli.md           # Phase 1 output — the command-line contract
├── checklists/
│   ├── requirements.md  # spec quality (built-in)
│   ├── spec-review.md   # requirements-quality review
│   └── amendment.md     # requirements-quality review of the 2026-09-02 amendment
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
.claude-plugin/
├── plugin.json                  # Claude Code plugin manifest
└── marketplace.json             # marketplace manifest; `plugin install` resolves a name, not a path

.specify/
└── extensions.yml               # six installed extensions, and the per-hook ranks of FR-025

scripts/
├── lint.sh                      # aggregate entry point; runs all seven, stops at first failure
├── lint-markdown.sh             # markdownlint-cli2
├── lint-yaml.sh                 # yamllint
├── lint-shell.sh                # shellcheck
├── lint-python.sh               # ruff (lint + format)
├── lint-format.sh               # prettier
├── lint-editorconfig.sh         # editorconfig-checker
├── lint-scope.sh                # FR-013b: the six ignore declarations agree with .lintignore
├── selftest.sh                  # proves each check fails on non-conforming input
└── lib/
    ├── common.sh                # die(), have(), run_tool(), usage
    ├── scope.sh                 # .lintignore -> git pathspec -> file list
    └── images.sh                # the six image references, tag@digest

.editorconfig                    # whitespace and line endings
.editorconfig-checker.json       # whitespace check's own Exclude list (regexes)
.gitignore                       # agent-local and machine-local state
.lintignore                      # the runner's file list; still one declaration for run time
.markdownlint-cli2.jsonc         # Markdown lint, plus its own `ignores`
.prettierignore                  # Prettier's own scope declaration
.prettierrc.json                 # formatting: md, yaml, xml, sh, json
.shellcheckrc                    # shell lint. No ignore mechanism exists (FR-013c)
.yamllint.yml                    # YAML lint, plus its own `ignore`
ruff.toml                        # Python, plus its own `exclude`
```

**Structure Decision**: flat configuration at the repository root, because that is where every one of these tools looks by default and moving them would mean passing a config path from each runner — configuration about configuration. Runners in `scripts/` with shared code in `scripts/lib/`, sourced rather than duplicated; `.shellcheckrc` sets `source-path=SCRIPTDIR` and `external-sources=true` so ShellCheck follows the sourced helpers instead of reporting it cannot. No `src/`, no `tests/`: there is no application code, and inventing either would be scaffolding for its own sake.

### Design detail: tool resolution

One function, `run_tool`, used by all six runners. Its contract:

1. `command -v <native>` succeeds → run the native tool with the computed file list. No container, no network.
2. Otherwise `command -v docker` succeeds → run the pinned image, repository mounted at `/work`, **read-only in check mode**, read-write in fix mode, `--rm`, and `-u "$(id -u):$(id -g)"` in fix mode so rewritten files are not left root-owned.
3. Otherwise → `die` with a message naming both the native command and the image that were unavailable, exit non-zero. Per FR-011, the aggregate stops here.

`--fix` is passed through to the tools that support it (`markdownlint-cli2 --fix`, `ruff check --fix` plus `ruff format`, `prettier --write`). For the tools with no automatic fix — `shellcheck`, `yamllint`, `editorconfig-checker` — `--fix` reports that no automatic fix exists and leaves the files untouched, per FR-012a, and does **not** fail.

### Design detail: scope

`.lintignore` holds one path or glob per line. `scope.sh` reads it, emits `:(exclude)<pattern>` pathspecs, and calls `git ls-files -z --cached --others --exclude-standard` with a type glob plus those exclusions. Every runner gets its file list from this one function. **Run-time scope is therefore unchanged by the amendment.**

What the amendment changes is the by-hand case. FR-013a now requires each check to declare its own skipped paths in its own configuration, so that a contributor running `markdownlint-cli2 '**/*.md'` directly gets the same scope the runner would give them. Each mechanism is the tool's own and each was verified against a fixture tree (research.md §13): `ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `.prettierignore`, and `Exclude` in `.editorconfig-checker.json` — regexes there, not globs. `.prettierignore` stops being a by-hand courtesy and becomes Prettier's declaration proper.

**ShellCheck is the exception, and FR-013c is why it is written down.** `.shellcheckrc` has no path-exclusion directive; `--exclude` takes warning codes, not paths. The shell check's by-hand scope is whatever the caller passes. Filtering its input from a wrapper was rejected: that would be a second scope source with no configuration behind it, which is the drift FR-013b exists to catch.

### Design detail: verifying that six declarations agree (FR-013b)

Six declarations can disagree; one could not. `scripts/lint-scope.sh` closes that by construction rather than by review. For each check it computes two sets — the files `.lintignore` puts in scope for that content kind, and the files the tool itself reports it would visit — and fails, naming the paths, when they differ. Where a tool can be asked what it would visit, it is asked: markdownlint-cli2 prints its resolved `Finding:` line, `ruff check --show-files` enumerates, `prettier --check` reports per file. Where it cannot be, the declaration is compared textually against `.lintignore` instead, and the weaker guarantee is stated in the output rather than hidden.

The shell check has neither, so `lint-scope.sh` reports it as unverifiable and says so on every run. That is the honest reading of FR-013c: a check that cannot be verified is reported as such, not silently counted as agreeing.

A check whose file list is empty reports success and says so, per the spec's Edge Cases section, rather than failing on an empty input set.

### Design detail: formatting, plugins, and what happens when one is missing

`.prettierrc.json` keeps `printWidth: 100` and gains `trailingComma: "none"` and `singleQuote: true`; `endOfLine`, `proseWrap` and the JSON override's `tabWidth` are removed as restated defaults, which empties that override entirely (research.md §14). Overrides then cover five content kinds: JSON and JSONC on core Prettier, Markdown and YAML on core Prettier, XML through `@prettier/plugin-xml@3.4.2`, and shell through `prettier-plugin-sh@0.19.0`.

The container path installs all three in one `npx --yes --package prettier@3.9.6 --package @prettier/plugin-xml@3.4.2 --package prettier-plugin-sh@0.19.0 prettier` invocation, so the tool and its plugins can never be fetched at mismatched versions. The native path resolves whichever plugins the contributor happens to have and **prints which ones resolved**. A content kind whose plugin is absent is routed to the container path — not warned past, and not failed on — because FR-023 as clarified treats a missing add-on exactly as a missing tool, and that is the only handling under which FR-008's identical-verdict guarantee survives. Neither plugin nor container reachable falls through to FR-011's existing hard failure.

### Design detail: extensions and hook order

Six extensions, four by name from the vetted `default` catalog and two by pinned archive URL from the `community` catalog, which is discovery-only by design (research.md §17). Hook order is **not** set by `specify extension set-priority` — that governs template and command resolution — but by the per-hook `priority` inside `.specify/extensions.yml`, which `get_hooks_for_event()` sorts ascending with a stable tie-break. No extension in the set ships a priority, so all 23 hooks would otherwise register at the default 10 and tie on install order, which is precisely the discovery-order dependence FR-025 forbids.

Ranks, and the principle they follow (FR-025a): lower runs first; observe before mutate; commit last. `superb` 10, `token-budget` 20, `agent-context` 30, `assess` and `bug` 40, `git` 50. Gaps of ten leave room to insert without renumbering. The principle is written into `.specify/extensions.yml` beside the numbers, together with the warning that `register_hooks()` rewrites an extension's entries from its manifest on every install — so `specify extension update` restores the tie unless the ranks are re-applied.

## Complexity Tracking

| Violation                                                                                                                                                                                                                                                                                                                       | Why Needed                                                                                                                                                                                                                                                                                | Simpler Alternative Rejected Because                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| yamllint and Prettier run in Docker Official **language** images (`python`, `node`) with the tool version pinned in the invocation, rather than in the tool's own image. **No longer a violation** — Principle III's second clause, added at constitution v1.1.0, permits exactly this. Retained here because the cost is real. | Neither project publishes an official or upstream image — Prettier's request for one is still open upstream, and the most-cited yamllint image has not been pushed in over two years. FR-008 requires a verdict without a native install, so the container path cannot simply be dropped. | (a) A third-party image would make "official" a claim the configuration cannot support, and puts an unaudited party in the execution path. (b) Requiring a native install for those two breaks FR-008, the feature's core promise. The residual cost, and the reason this row stays: those two containers fetch the tool at run time, so they need network access and start more slowly than the four that do not.                                                                                                                                                                        |
| `git` required for file enumeration                                                                                                                                                                                                                                                                                             | FR-013a requires every check to agree on scope, which requires computing the list once. `git ls-files` with `:(exclude)` pathspecs does this correctly in POSIX `sh`; hand-rolling gitignore-syntax matching in `sh` would not.                                                           | Re-implementing pattern matching in POSIX `sh` is more code and more bugs than the guarantee is worth, and per-tool ignore files were rejected outright — six syntaxes cannot be kept in agreement by review, which is the failure FR-013a names. `git` is not a language runtime or package manager, so FR-010 is untouched, and the repository is a git repository by construction.                                                                                                                                                                                                     |
| A ninth script, `scripts/selftest.sh`, beyond the eight the requirements imply                                                                                                                                                                                                                                                  | SC-002 requires that an introduced violation is caught for all content types, and a check that has never been shown to fail is a check nobody has tested. The fixtures must live outside the checked tree, or the aggregate run would fail on its own test data.                          | Committing non-conforming fixtures into the repository would make the aggregate check fail by design. Testing the checks manually satisfies nobody after the first month.                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Scope agreement is verified rather than structural.** Six ignore declarations replace one, and `scripts/lint-scope.sh` exists solely to compare them.                                                                                                                                                                         | FR-013a, as amended at the user's direction, requires each check to declare its own skipped paths so that a by-hand invocation matches the runner. The property FR-013b then asks for — all checks agree — cannot hold by construction once the declaration is distributed.               | Keeping the single declaration was the previous design and was rejected deliberately: it left a contributor invoking a tool directly with a different scope from the runner, silently. Generating the six files from `.lintignore` was considered and rejected as a generator plus a staleness check plus six generated files, where a comparison script is one script. The residual cost is real and is the reason this row exists: a guarantee that used to be impossible to break is now merely checked.                                                                               |
| ShellCheck participates in FR-013a with no mechanism to participate through.                                                                                                                                                                                                                                                    | FR-013c requires the absence be recorded rather than worked around. Every alternative introduces a second scope source.                                                                                                                                                                   | Wrapping ShellCheck to pre-filter its input would put scope logic in a script rather than a configuration file, which is what Principle V and FR-013a both push against, and it would make the shell check the one case where the declaration is invisible. Recording the gap keeps it visible in `lint-scope.sh`'s output on every run.                                                                                                                                                                                                                                                  |
| Two Prettier plugins are fetched at run time by the container path.                                                                                                                                                                                                                                                             | FR-021 extends formatting to XML and shell, and Prettier's core handles neither. Both plugins are pinned by exact version and installed in the same invocation as Prettier itself.                                                                                                        | Vendoring `node_modules` into the repository would make the tree carry a dependency set it otherwise has none of, and would still not help a contributor whose native Prettier lacks the plugins. Declaring them in a committed `package.json` and requiring `npm ci` was offered and rejected by the user: it makes an install a precondition, which Principle I forbids without amendment. The cost that remains: the format check's container path now needs network for three packages instead of one, and a plugin's own release could change the formatting of files nobody edited. |
| Two extensions are installed from a catalog whose discovery-only flag is stated to be the vetting boundary.                                                                                                                                                                                                                     | Requested explicitly, and reaffirmed after the boundary, the read-write effect, and the 11 commands and 11 hooks were shown. FR-026 requires the provenance be recorded, which research.md §17 does including the weaker pin on the tag tarball.                                          | Installing only the four vetted extensions was recommended and declined. Nothing was found to make the two safe rather than merely recorded; what is recorded is the exact URL, the version, the effect, and that a re-tagged release would change the bytes at the same URL for `token-budget`.                                                                                                                                                                                                                                                                                          |
