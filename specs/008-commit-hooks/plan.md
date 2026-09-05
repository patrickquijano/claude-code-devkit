# Implementation Plan: Commit Message and Signature Enforcement

**Branch**: `008-commit-hooks` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-commit-hooks/spec.md`

## Summary

Two committed POSIX `sh` git hooks enforce the repository's commit conventions locally: `commit-msg` refuses a message whose first line is not a permitted Conventional Commits subject of at most 72 characters, and `pre-push` refuses a send containing a commit with no signature or a bad one. Both are activated by one argument-free shell command that needs no package manager, and both work identically under Husky for contributors who already have Node.

The design turns on one fact established in research: Husky sets `core.hooksPath` to `.husky/_`, and `.husky/_` is gitignored by Husky itself, so a fresh clone with no `npm install` has no hooks at all. That precondition is exactly what Constitution Principle I forbids for a quality check, which is why Husky here is supported and never required.

## Technical Context

**Language/Version**: POSIX `sh` (IEEE Std 1003.1), checked by ShellCheck in `sh` dialect

**Primary Dependencies**: git ≥ 2.9 (`core.hooksPath` support). Husky 9.1.7 optional and additive. No runtime dependency on Node, npm, commitlint or any package.

**Storage**: `.commit-msg.conf` — one committed, `sh`-sourceable configuration file at the repository root

**Testing**: `scripts/selftest.sh` — the repository's existing prove-each-check-can-fail harness. Hook logic is invoked directly with fixture inputs; no temporary repository needed for the message check.

**Target Platform**: any POSIX shell environment with git; contributor workstations, not CI

**Project Type**: shell tooling inside an existing single-repository toolkit

**Performance Goals**: each hook completes fast enough to be invisible on a commit or push. `commit-msg` reads one file; `pre-push` runs one `git log` per ref update.

**Constraints**: no language package manager, virtual environment, or install step may be a precondition (Principle I). POSIX `sh` only, zero ShellCheck findings in `sh` mode, tab indentation (Principle IV, `.claude/rules/shell-scripts.md`). Non-zero exit whenever any rule was broken (Principle II). Rule set in a committed configuration file (Principle V).

**Scale/Scope**: 2 hooks, 2 dispatchers, 1 installer, 1 configuration file, 6 selftest cases, 1 documentation page, 1 path-scoped rule file, 1 line added to `CLAUDE.md`.

## Constitution Check

_GATE: passed before Phase 0 research; re-checked after Phase 1 design — see the second column._

| Principle                                             | Requirement                                                                 | Pre-design                            | Post-design                                                                                                                                                                                                                                                                         |
| ----------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Tooling Independence (NON-NEGOTIABLE)              | No check may require a package manager, virtual environment or install step | **At risk** — Husky is an npm package | **PASS** — hooks are committed POSIX `sh`; `scripts/install-hooks.sh` activates them with git alone. Husky is one of two supported paths, never the required one.                                                                                                                   |
| II. Fail Fast                                         | Exit non-zero on failure; never mask a status behind a pipeline or subshell | Applies                               | **PASS** — `set -eu`; both hooks exit non-zero whenever any rule was broken. `pre-push` enumerates every offending commit before exiting, which FR-007 requires; failing fast governs whether a later check runs after an earlier failed, not whether one check finishes reporting. |
| III. Pinned, Official Images                          | Every referenced container image pinned by tag and digest                   | N/A                                   | **PASS** — this feature references no image.                                                                                                                                                                                                                                        |
| IV. POSIX Shell Only                                  | POSIX `sh`, zero findings in POSIX mode, no bashisms                        | Applies                               | **PASS** — every new file is `sh`. The two extensionless dispatchers are added to the shell check's glob list so they are checked rather than skipped; the logic itself lives in `*.sh` files the existing glob already finds.                                                      |
| V. Configuration Is Committed                         | Behaviour must not depend on an undeclared default or per-developer setting | Applies                               | **PASS** — `.commit-msg.conf` holds the types, the scope policy and the limit. No value is embedded in a hook.                                                                                                                                                                      |
| VI. Spec-Driven Change                                | Spec, plan and task list on disk before implementation                      | Applies                               | **PASS** — `spec.md`, this file, and `tasks.md` to follow.                                                                                                                                                                                                                          |
| Quality Gate: one config per content kind and concern | Exactly one formatting and one linting configuration per content kind       | Applies                               | **PASS** — commit messages are a content kind this repository did not previously govern; `.commit-msg.conf` is its first and only linting configuration, and it has no formatter.                                                                                                   |
| Quality Gate: violations name file and location       | A check reporting a failure without a location does not satisfy the section | Applies                               | **PASS** — `commit-msg` names the rule, the offending line and its measured length; `pre-push` names every offending commit by short SHA and subject.                                                                                                                               |
| Quality Gate: scripts are themselves checked          | Every script under the script directory is subject to the shell check       | Applies                               | **PASS** — `scripts/hooks/*.sh` and `scripts/install-hooks.sh` match `*.sh`; the dispatchers are added explicitly.                                                                                                                                                                  |

**Result: no violations. Complexity Tracking is empty and stays empty.**

### One clause worth settling in writing, so it is not re-opened

The Quality Gate Requirements say "Each check MUST be runnable from the repository root without arguments." `scripts/hooks/commit-msg.sh` takes a message-file path, and `scripts/hooks/pre-push.sh` reads ref updates on stdin, so a reader could take either for a violation.

They are not. That clause governs the repository's **aggregate** checks — the seven `scripts/lint-*.sh` that `scripts/lint.sh` drives, every one of which stays argument-free and is unchanged by this feature. A git hook is not one of them: it is invoked by git, with git's own arguments, at git's own moment, and there is no useful sense in which "run the commit-message check with no arguments" names an operation. What the clause exists to prevent — a check whose verdict depends on how the caller invoked it — is instead guaranteed here by the two hooks having exactly one caller each, and by `contracts/commit-msg-hook.md` requiring that `selftest.sh` invoke the script the same way git does.

Recorded here rather than left implicit because `speckit-analyze` raised it (finding C1) and the next reader will raise it again.

### Two findings from the same pass, resolved rather than deferred

- **I1** — `contracts/install-hooks-cli.md` gives `install-hooks.sh` a `--status` flag that `spec.md` never mentions. **No change required**: FR-009 requires the command _work_ with no arguments, which it does; `--status` is how FR-013's "answerable from the command's own output" is served without side effects. Recorded so the absence of a change is a decision rather than an oversight.
- **G2** — `tasks.md` T003, T043 and T054 map to no functional requirement. **No change required**: they are repository-convention work — a gitignore entry, a note in `CLAUDE.md`, and the container-parity run `CLAUDE.md` itself prescribes. A task list that carried only requirement-derived tasks would omit them and the feature would ship worse.

The one place a violation was possible — Husky's npm precondition — was resolved at Step 2 of the run by changing the design, not by amending the constitution and not by justifying an exception. That is recorded as conflict C1.

## Project Structure

### Documentation (this feature)

```text
specs/008-commit-hooks/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output — the Husky research and every decision it forced
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── commit-msg-hook.md
│   ├── pre-push-hook.md
│   ├── install-hooks-cli.md
│   └── commit-msg-conf.md
├── checklists/
│   ├── requirements.md  # built-in spec-quality checklist, 16/16
│   └── spec-quality.md  # requirements-quality review, CHK001–CHK040
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
.commit-msg.conf                 # NEW  the rule set: types, scope policy, subject limit
.husky/
├── commit-msg                   # NEW  3-line dispatcher, exec's scripts/hooks/commit-msg.sh
└── pre-push                     # NEW  3-line dispatcher, exec's scripts/hooks/pre-push.sh
scripts/
├── hooks/
│   ├── commit-msg.sh            # NEW  the message rules; takes a message-file path
│   └── pre-push.sh              # NEW  the signature rules; reads ref updates on stdin
├── install-hooks.sh             # NEW  sets core.hooksPath + commit.gpgsign; reports state
├── lint-shell.sh                # EDIT one line: add the two dispatcher paths to collect
├── selftest.sh                  # EDIT six new cases
└── lib/                         # unchanged
.gitignore                       # EDIT ignore .husky/_ so a Husky user's generated dir stays out
docs/husky-git-hooks.md          # NEW  the research, written for contributors
.claude/rules/husky-git-hooks.md # NEW  path-scoped agent rule
CLAUDE.md                        # EDIT one line in the build/lint/test section
```

**Structure Decision**: the feature extends the existing shell toolkit in place. `scripts/hooks/` is the one new directory, and it exists so the hook logic sits in `*.sh` files the shell check already finds and `selftest.sh` can invoke directly with a fixture — research §8. Nothing parallel to the existing quality-gate structure is introduced.

## Design decisions carried from research

Each of these is argued in [research.md](./research.md); they are listed here because the task list depends on them.

1. **Husky supported, never required** (§2). Two activation paths, detected rather than assumed (§3).
2. **Refuse `N` and `B` signature states only** (§6). `E` is the ordinary state for correct SSH signing with no allowed-signers file; refusing it would block contributors who did nothing wrong.
3. **Sign at commit, verify at push** (§7). No hook rewrites a commit. `install-hooks.sh` sets `commit.gpgsign` but never `gpg.format` or `user.signingkey` — those identify a person.
4. **Angular type set, optional scope, 72-character first line** (§5), because that is what the repository's own history already uses.
5. **Logic in `scripts/hooks/*.sh`, dispatchers in `.husky/`** (§8).
6. **`.commit-msg.conf`, `sh`-sourceable, at the root** (§9).
7. **Six selftest cases, asserting on exit status and on the message** (§10).

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

None. The Constitution Check passes on every principle both before and after design.
