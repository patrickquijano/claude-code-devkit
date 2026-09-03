# Implementation Plan: Format on modification, and one exclusion declaration per check

**Branch**: `004-format-hook-scope` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-format-hook-scope/spec.md`

## Summary

Two halves, built in this order because the second depends on the first.

**Half one** replaces the repository's single central exclusion list with one declaration per check. `.lintignore` and `scripts/lint-scope.sh` are deleted; the six POSIX extractors that `lint-scope.sh` already contains are promoted into `scripts/lib/scope.sh` and become the _source_ of each check's file list rather than a cross-check against a sixth copy of it. `lint.sh` drops from eight checks to seven. The correctness claim — that no check's coverage changes — is proved by comparing each check's file list before and after, and the comparison survives as a self-test fixture.

**Half two** adds a project-scoped `PostToolUse` hook, configured in a committed `.claude/settings.json`, that runs `scripts/format-file.sh` after each `Edit`, `Write`, `MultiEdit` or `NotebookEdit`. That script resolves and contains the path, then invokes the three rewriting checks — `lint-format.sh`, `lint-markdown.sh`, `lint-python.sh` — each with `--fix -- <file>`. Reaching the formatters through the existing checks is the whole design: the native-or-container resolution, the digest-pinned images, the per-check globs and the per-check exclusions all stay in exactly one place, and the hook carries no extension-to-tool mapping of its own. The enabling change is an optional trailing `-- <path>...` on every check, parsed in `common.sh` and intersected with the scope `collect()` already computes.

Full reasoning for every decision, including the alternatives rejected, is in [research.md](./research.md).

## Technical Context

**Language/Version**: POSIX `sh` only. No bashisms — no `[[ ]]`, no arrays, no `<<<`, no `set -o pipefail`. Tabs for indentation, because `<<-` heredocs strip leading tabs and nothing else.

**Primary Dependencies**: `git` (file enumeration; not a language runtime, so Principle I is untouched), plus each check's existing native tool or its digest-pinned container. No new dependency is introduced. Notably **not** `jq` — see research.md §4.

**Storage**: N/A. The feature reads and rewrites files in place; it holds no state between invocations beyond one environment variable within a single process tree.

**Testing**: `scripts/selftest.sh`, which proves each check rejects deliberately bad input, extended with fixtures for the hook's refusal cases, the unavailable-tooling skip, and the before/after file-list equality. Plus `scripts/lint.sh` over the repository itself.

**Target Platform**: any POSIX shell environment with `git`. Developed on macOS (Darwin 25.6.0); `editorconfig-checker` is absent natively there, so that check exercises the container path in normal use.

**Project Type**: repository tooling — shell scripts plus tool configuration. No application source tree.

**Performance Goals**: the hook runs after every file edit in an agent session, so its own overhead must be negligible against the formatter it invokes. Concretely: at most one process per rewriting check, no repository-wide enumeration beyond the `git ls-files` the check already runs, and no container pull on the common path where the native tool is present.

**Constraints**: exactly one file is read or written per invocation (FR-002). Nothing outside the repository root is touched (FR-013). No invocation may cause another (FR-010). The whole-repository checks keep today's behaviour when invoked with no arguments (FR-017).

**Scale/Scope**: 234 tracked files; 146 Markdown, 37 shell, 16 YAML, 11 JSON, 5 Python (all currently outside lint scope), 7 PowerShell (outside scope). Seven checks after this feature, six of which consume a file list.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Constitution v1.2.0, ratified 2026-09-02, 6 principles. Not amended by this feature.

| Gate | Verdict | How this design satisfies it |
| **I. Tooling Independence (NON-NEGOTIABLE)** — verdict from POSIX `sh` plus native tool or container; no package manager, virtual environment or global install as a precondition | **PASS** | The hook reaches every formatter through the existing check scripts, so `common.sh`'s three-step native → container → exit-3 resolution is preserved rather than re-implemented. The one new external need — reading one field from the hook's stdin JSON — is met with `sed`, not `jq`, precisely because `jq` would be a global install on the path that runs after every edit (research.md §4). Exit 3 is surfaced as a visible non-fatal skip, which is the behaviour this principle's own rationale asks for (research.md §8). |
| **II. Fail Fast** — non-zero on first failure; no masked exit status behind a pipeline, subshell or ignored error; no continuing after a failure | **PASS** | `format-file.sh` stops at the first check that fails and reports that check's own status; it does not run the remaining checks. Every pipeline whose exit status matters is restructured so the status is the one that is tested. Half one adds a specific obligation here: an extractor that cannot find its configuration file or its declaration block exits non-zero naming the file, rather than returning an empty list that would silently mean "exclude nothing" (research.md §13). |
| **III. Pinned, Official Images** — every image pinned by tag **and** `sha256` digest; no floating tag | **PASS** | No image is added, removed or re-pinned. `scripts/lib/images.sh` is untouched. The hook inherits the existing pins by construction, because it invokes the checks rather than the tools. |
| **IV. POSIX Shell Only** — POSIX `sh`-compatible, zero findings from shell static analysis in POSIX mode, no bashisms | **PASS** | `format-file.sh` and the new extractor are POSIX `sh` with tab indentation, and `scripts/` is inside the shell check's scope, so the constraint is enforced rather than asserted. `pwd -P` is used for path resolution because `realpath` is not POSIX and `readlink -f` is a GNU extension (research.md §5). |
| **V. Configuration Is Committed** — every linter and formatter driven by a configuration file committed at a documented path; no dependence on an undeclared default, editor settings, or per-developer configuration | **PASS** | Half one strengthens this: each check's exclusions move _into_ the configuration file that already drives that check, so the declaration and the tool's own behaviour cannot diverge. The hook's own configuration is `.claude/settings.json`, committed, not the gitignored `settings.local.json` and not a user-level file (research.md §3). The one check whose tool offers no exclusion mechanism declares its exclusions in `.shellcheckrc`, which is a committed configuration file at a documented path — the alternative of a list inside `lint-shell.sh` was rejected on this principle (research.md §12). |
| **VI. Spec-Driven Change** — through the Spec Kit phases; no implementation without spec, plan and task list on disk | **PASS** | `spec.md` and this file exist; `tasks.md` is Phase 2's output and precedes implementation. |
| **Quality Gate: exactly one governing configuration file per content kind **per concern**; never two of either** | **PASS**, and improved | The hazard the clause names — "two tools rewriting the same file, where the verdict depends on the order they ran in" — is exactly the Markdown case, governed by Prettier for formatting and markdownlint for linting. FR-005 and research.md §7 fix the order to `lint.sh`'s own, in one place, so both the aggregate and the hook converge identically. No content kind gains a second formatting or a second linting configuration. |
| **Quality Gate: each check runnable from the repository root without arguments** | **PASS** | The path list is optional and trailing. No-argument and bare `--fix` invocations are byte-identical in behaviour to today (FR-017), which is also what makes the before/after file-list comparison meaningful. |
| **Quality Gate: a check MUST name the file and location of every violation it reports** | **PASS** | The hook passes each check's own output through unmodified, which is where the file and location already are. The hook adds the file and the check name to its own failure report (FR-011). |
| **Quality Gate: every script under the script directory subject to the shell check** | **PASS** | `scripts/format-file.sh` lands in `scripts/`, which `lint-shell.sh`'s `collect '*.sh'` covers. Half one must keep it covered: the shell check's new exclusion declaration must not exclude `scripts/`. |
| **Development Workflow: branch cut from the default branch; artifacts under `specs/<NNN-slug>/`** | **PASS** | `004-format-hook-scope`, cut from `main`; artifacts in `specs/004-format-hook-scope/`. |
| **Development Workflow: the aggregate check MUST have been run and MUST have passed before review** | **PASS** by construction | Step 5 of this run resolves and executes `scripts/lint.sh` and `scripts/selftest.sh` before anything is proposed for review. |
| **Development Workflow: machine-local and agent-local state excluded from version control** | **PASS** | `.claude/settings.json` is shared project configuration, not machine-local state — the reference's own scope table marks it committable, and `.gitignore` already isolates the three machine-local `.claude` paths (`logs/`, `settings.local.json`, `prompt.md`). No new state file is introduced. |

**No violations. Complexity Tracking is therefore empty and the section is retained only to say so.**

One constitutional point is worth stating rather than leaving implicit, because it reads at first like a violation and is not. Principle V's second clause permits relying on a tool's documented default "provided ... the tool's version is pinned exactly, and the relied-on default is recorded in the repository's written record of chosen settings". This feature relies on two such defaults: that Prettier and markdownlint-cli2 each discover their own configuration from the repository root, and that each honours its own ignore file for an explicitly named path. Both are recorded in research.md §11 and neither is restated in a configuration file, exactly as that clause allows.

## Project Structure

### Documentation (this feature)

```text
specs/004-format-hook-scope/
├── plan.md                     # This file
├── research.md                 # Phase 0 output — 16 decisions with alternatives
├── data-model.md               # Phase 1 output — the entities the scripts operate on
├── quickstart.md               # Phase 1 output — runnable validation scenarios
├── contracts/
│   ├── check-cli.md            # The amended check-script CLI, incl. `-- <path>...`
│   ├── format-file-cli.md      # scripts/format-file.sh — stdin, stdout, stderr, exits
│   └── exclusion-declaration.md # Where each check declares exclusions, and the syntax
├── checklists/
│   ├── requirements.md         # Built-in spec-quality checklist (16/16)
│   └── safety-and-scope.md     # Requirements-quality review, 44 items
└── tasks.md                    # Phase 2 output — NOT created by /speckit-plan
```

### Source Code (repository root)

```text
.claude/
└── settings.json               # NEW. PostToolUse hook, exec form, committed

scripts/
├── format-file.sh              # NEW. The hook entry point
├── lint.sh                     # CHANGED. CHECKS drops `scope`; eight → seven
├── lint-scope.sh               # DELETED. Nothing left to compare
├── lint-format.sh              # unchanged
├── lint-markdown.sh            # unchanged
├── lint-python.sh              # unchanged
├── lint-editorconfig.sh        # unchanged
├── lint-yaml.sh                # unchanged
├── lint-shell.sh               # unchanged
├── lint-citations.sh           # unchanged — no file list, no declaration (research.md §15)
├── selftest.sh                 # CHANGED. Scope-divergence fixture out; six new fixtures in
└── lib/
    ├── common.sh               # CHANGED. parse_args gains `-- <path>...`; collect intersects
    ├── scope.sh                # CHANGED. Six extractors promoted in; per-check exclude source
    └── images.sh               # unchanged. No image touched (Principle III)

.lintignore                     # DELETED
.shellcheckrc                   # CHANGED. Gains the marked exclusion block (research.md §12)
.prettierignore                 # unchanged — becomes format's single declaration
.markdownlint-cli2.jsonc        # unchanged — `ignores` becomes markdown's single declaration
.yamllint.yml                   # unchanged — `ignore` becomes yaml's single declaration
ruff.toml                       # unchanged — `exclude` becomes python's single declaration
.editorconfig-checker.json      # unchanged — `Exclude` becomes editorconfig's single declaration
.gitignore                      # CHANGED. One comment referencing .lintignore
CLAUDE.md                       # CHANGED. Four false claims; plus a line about the hook
README.md                       # CHANGED if it repeats any of the same claims

specs/001-quality-gate-plugin/
├── spec.md                     # CHANGED. FR-013, FR-013a, FR-013b, FR-013c marked superseded
└── contracts/cli.md            # CHANGED. Scope source, the new argument, the check list,
                                #   and the removed lint-scope.sh section
```

**Structure Decision**: the repository has no application source tree — its deliverable _is_ `scripts/` plus the tool configuration at the root. The plan therefore adds one script beside the existing ten, one configuration file in `.claude/`, and changes three library and configuration files. No new directory is created, and no `src/`, `tests/` or component directory is introduced; `specs/001-quality-gate-plugin/research.md` §10 already decided that this repository's authored plugin content lives in top-level `skills/`, `commands/` and `agents/`, and this feature adds no component of that kind.

**Build order**: the two halves are **independent**, and half two (the hook, US1, P1) ships first.

An earlier draft of this plan asserted the reverse — half one first, because the hook depends on the scope mechanism half one rewrites. That is wrong, and the error is worth recording because it is the kind that survives review. `format-file.sh` invokes each check through its **command-line interface**, not through `collect()`, and that interface is unchanged by half one: `lint-format.sh --fix -- <path>` means the same thing before and after the exclusions move. So the hook works against `.lintignore`-based scope and against per-check scope alike, and US1 is independently implementable, testable and shippable — which is what the P1 priority already claimed.

What genuinely orders the work is smaller and different:

1. **The baseline capture precedes any half-one change.** Each check's file list must be recorded from the code as it stands, because the equality proof (FR-024, FR-025, SC-002) compares against it and it is unrecoverable afterwards except from git history. This is the one hard sequencing constraint in the feature, and it belongs in Setup rather than inside either story.
2. **The `-- <path>...` CLI extension precedes US1**, since the hook has nothing to call without it. It does not precede US2, which is unaffected by it. So it is foundational to one story, not to both.

Both halves then proceed in priority order: US1, then US2.

## Complexity Tracking

No constitutional violations, so nothing to justify. The section is kept, empty, so that a reader can tell "no violations" from "this section was never filled in".

| Violation | Why Needed | Simpler Alternative Rejected Because |
| _none_ | — | — |

Two design choices are worth naming here even though neither is a violation, because both add surface and a reviewer is entitled to see them weighed:

- **Extending seven scripts' CLI rather than writing one standalone formatter.** The standalone script is fewer lines and touches nothing existing. It was rejected at Step 2 of this run because it would re-implement the native-or-container resolution, the digest pins, the extension-to-tool mapping and the exclusions — four facts that would then exist twice and could drift, with Principle I's container fallback the first casualty of hook latency. The CLI extension is backward compatible and additive; the duplication is not recoverable once shipped.
- **A stand-down marker instead of an enforced single authority.** A formatter configured in the developer's own `~/.claude/settings.json` already rewrites `Edit|Write` files in this repository, and hooks for one event run in parallel, so a project hook runs beside it rather than replacing it. FR-030 forbids this repository from editing configuration outside its own root, so the resolution is a documented one-line stand-down test on the existence of `scripts/format-file.sh`, applied by the developer. Weighed in research.md §17, including the two rejected alternatives (remove the external hook; accept concurrent writers). The residual limitation is real and is recorded there and in SC-012: until the line is applied, both run, and the repository can neither detect nor fix that from inside.

- **A repository convention for ShellCheck's exclusions.** Six checks read a tool mechanism and one reads a marked comment block, which is an asymmetry. The alternative — a list in `lint-shell.sh` — is a worse asymmetry and fails Principle V. Weighed in research.md §12, including the FR-027 cost that is unsatisfiable for this one check because the tool provides no way to satisfy it.
