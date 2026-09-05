# Phase 0 Research: Commit Message and Signature Enforcement

**Feature**: `008-commit-hooks` | **Date**: 2026-09-05

Every decision below is recorded with what was chosen, why, and what was rejected. Sections 1–4 are the Husky research the task asked for; sections 5–11 are the decisions that research forced.

## 1. What Husky is, and what it is not

**Finding**: Husky is a Node package whose entire job is to point git at a directory of hook scripts and to keep that pointer working after every `npm install`. It is not a validator, a linter, or a commit-message parser. It runs whatever shell you put in `.husky/<hook-name>`; the content of those files is yours.

Mechanism, from the package's own source and docs:

- `husky init` writes `"prepare": "husky"` into `package.json`, creates `.husky/`, and seeds `.husky/pre-commit`. (`typicode/husky`, `bin.js`; `docs/how-to.md`)
- Running `husky` sets `core.hooksPath` to `.husky/_`. Git then executes hooks from that directory instead of `.git/hooks`. (`docs/troubleshoot.md`: "check that `git config core.hooksPath` is set to `.husky/_` or your custom hooks directory")
- `.husky/_` holds generated shims, one per hook name, plus a `.gitignore` whose entire content is `*`. (`index.js`: `w(_('.gitignore'), '*')`)
- Uninstalling is `git config --unset core.hooksPath`. (`docs/troubleshoot.md`)
- `HUSKY=0` in the environment disables hook installation and execution — the documented answer for CI and Docker. (`docs/how-to.md`)
- The `add`, `set` and `uninstall` subcommands are removed in v9 and exit non-zero; `install` is deprecated but still functions. (`bin.js`)

**Consequence, and it is the decisive one**: `.husky/_` is generated and gitignored. A fresh clone contains `.husky/<your hooks>` but not `.husky/_`, and `core.hooksPath` is unset. **Nothing runs until someone executes `npm install`.** Husky's value proposition is precisely that `npm install` re-arms the hooks; a repository with no `package.json` gets none of that value and inherits the whole precondition.

## 2. Why that collides with this repository

Constitution Principle I (NON-NEGOTIABLE), `.specify/memory/constitution.md`:

> Every repository quality check MUST produce its verdict using only POSIX `sh` plus either the tool installed natively or a container runtime. No check MAY require a language package manager, a virtual environment, or a global install step as a precondition for running it.

A commit-message check is a quality check. Husky's activation is a package-manager install step. The two cannot both hold, and the principle is marked non-negotiable.

The repository has no `package.json`, and `CLAUDE.md` states "There is no build step and no separate test runner. The checks are the tests." Adding one would also require excluding `node_modules` from five separate exclusion declarations (`.prettierignore`, `ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `Exclude` in `.editorconfig-checker.json`).

**Decision**: Husky is supported but never required. Hook bodies are committed; activation has a POSIX-shell path that needs no package manager.

**Rationale**: This keeps Principle I intact without discarding the tool the requester named. A contributor who already works in Node gets Husky's re-arming behaviour; a contributor who does not gets working hooks from one shell command. The hook files are the same in both cases.

**Alternatives rejected**:

- _Amend Principle I to exempt git hooks._ Rejected: the principle is non-negotiable and is not wrong here — a hook that silently stops running for contributors without npm is exactly the failure it describes.
- _Standard `husky init` and record the violation in Complexity Tracking._ Rejected: a permanent documented breach of the repository's own non-negotiable governance, in exchange for convenience already available another way.
- _Drop Husky entirely, use `.githooks/`._ Rejected: it discards a named requirement for no gain the chosen design does not already provide. `.husky/` as the directory name costs nothing and keeps the Husky path open.

## 3. The two activation paths, and why they differ

|                   | Husky present                                         | Husky absent                              |
| ----------------- | ----------------------------------------------------- | ----------------------------------------- |
| `core.hooksPath`  | `.husky/_`                                            | `.husky`                                  |
| Who sets it       | `husky` (via `prepare`, on every install)             | `scripts/install-hooks.sh`, once          |
| What git executes | `.husky/_/<hook>` shim, which sources `.husky/<hook>` | `.husky/<hook>` directly                  |
| Re-arms itself    | yes, on `npm install`                                 | no; re-run the script after a fresh clone |

`install-hooks.sh` must therefore **detect** rather than assume: if `.husky/_` exists and holds shims, point at it and let Husky own the arrangement; otherwise point at `.husky`. Writing `.husky` unconditionally would break a Husky user's setup on their next `npm install`, when `husky` rewrites `core.hooksPath` back to `.husky/_` and the two disagree about which file git runs.

**Decision**: `install-hooks.sh` reads the current `core.hooksPath`, chooses the correct value for the environment it finds, and reports both what it set and what was already set.

## 4. Bypass routes

Two exist and they are not equivalent.

- **`git commit --no-verify` / `git push --no-verify`** — git's own flag. Skips `commit-msg`, `pre-commit` and `pre-push` for that one invocation. This is the legitimate emergency route: it is per-invocation, visible in the command the contributor typed, and leaves the checks armed.
- **`HUSKY=0`** — Husky's environment variable. Only meaningful on the Husky path; on the fallback path git runs `.husky/<hook>` directly and never consults it. Documented for CI and Docker images, where hooks should not run at all.

**Decision**: document both, and state that `--no-verify` is the contributor-facing emergency route while `HUSKY=0` is an environment-level switch for automation. Do not implement a third, repository-specific bypass — a bypass the repository invents is one no contributor already knows.

## 5. Conventional Commits grammar and the length limit

The Conventional Commits v1.0.0 specification defines the first line as `<type>[optional scope][optional !]: <description>` and mandates only `feat` and `fix` as types, leaving the vocabulary open. The Angular convention supplies the commonly used eleven.

**Decision**: permitted types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Scope is optional. `!` before the colon marks a breaking change and is accepted. First line at most 72 characters; no length rule on any other line.

**Rationale**: The repository's own history already uses this shape both ways — `feat: distribute five authored skills with the plugin` unscoped, `refactor(skills): rename the five plugin skills to a ccd- prefix` scoped. Requiring a scope would retroactively invalidate four of the last five commits on `main`; forbidding one would invalidate the fifth. The 72-character limit governs the first line alone because the repository's own commit trailers carry URLs, and a whole-message or per-line rule would make its existing convention illegal.

**Alternatives rejected**: the six-type minimal set (leaves `ci`, `build` and `perf` with no correct type, which pushes them into `chore`); the specification minimum of `feat`/`fix` plus anything (no vocabulary control at all).

## 6. Which signature states refuse a push

`git log --format=%G?` reports one character per commit:

| Code | Meaning |
| `G` | good signature |
| `B` | bad signature |
| `U` | good signature, unknown validity |
| `X` | good signature that has expired |
| `Y` | good signature made by an expired key |
| `R` | good signature made by a revoked key |
| `E` | signature present, cannot be checked |
| `N` | no signature |

**Decision**: refuse `N` and `B`. Accept `G`, `U`, `X`, `Y`, `R` and `E`.

**Rationale**: `E` is the ordinary state for a correctly SSH-signed commit when `gpg.ssh.allowedSignersFile` is unset — which is the default. Refusing anything that is not `G` would block contributors who have configured signing correctly, with an error about verification they cannot act on, and would push them toward `--no-verify` as routine. `N` and `B` are the two states that actually indicate the problem the requirement exists to catch: nothing signed, or something tampered with.

**Alternatives rejected**: `G` only (breaks the default SSH setup); `N` only (lets a demonstrably bad signature through); adding `R` to the refused set (revocation is rarely tracked for SSH signing, and a false refusal here is the same failure as `E`).

## 7. Signing at commit time rather than at push time

The task asked for the push to sign unsigned commits. A signature is part of the commit object, so producing one changes the commit's identifier. `pre-push` runs **after** git has computed the ref updates it is about to send, so a hook that rewrote commits would send the pre-rewrite objects and leave the contributor's branch pointing somewhere else. There is no correct version of "sign it during the push".

**Decision**: `install-hooks.sh` sets repository-local `commit.gpgsign true`, so commits are signed when created; `pre-push` verifies and refuses, and rewrites nothing.

**Rationale**: it delivers the intent — nothing unsigned reaches the remote — with no history rewriting. It is also already the requester's configuration: `commit.gpgsign=true`, `gpg.format=ssh`, `user.signingkey` set.

**Alternatives rejected**: rewriting unpushed commits with `git rebase --exec 'git commit --amend -S'` and aborting the push (silently changes SHAs of work the contributor already made, catastrophic if any were shared); a `Signed-off-by:` trailer instead (a different guarantee — an assertion, not a signature — and the requester's setup already provides the stronger one).

`install-hooks.sh` deliberately does **not** write `gpg.format` or `user.signingkey`: those identify a person and a key, and guessing either produces commits signed by the wrong identity. It reports their absence instead.

## 8. Where the logic lives, so that it is both checked and testable

`scripts/lint-shell.sh` calls `collect shell '*.sh'`. Hook files are named `commit-msg` and `pre-push` with **no extension**, so a hook implemented directly in `.husky/` would never be seen by the shell check — a script the constitution requires be checked, silently skipped.

**Decision**: the logic lives in `scripts/hooks/commit-msg.sh` and `scripts/hooks/pre-push.sh`. `.husky/commit-msg` and `.husky/pre-push` are three-line dispatchers that `exec` them. The shell check's glob list gains the two extensionless dispatcher paths so they are checked too.

**Rationale**: three properties at once. The logic sits in `*.sh` files the existing check already finds. It can be invoked directly by `selftest.sh` with a message file argument — no git plumbing, no temporary repository — which is what makes the proof cheap. And the dispatcher is small enough that its correctness is visible by reading it.

**Alternatives rejected**: putting the logic in `.husky/` and widening the glob (the check would run, but selftest would have to drive it through a real `git commit`, and `.husky/` would then hold two files the repository's script conventions do not otherwise reach); a symlink from `.husky/commit-msg` to the script (git preserves symlinks, but the mode bits and the Windows story are both worse than a three-line file).

## 9. Where the rule set lives

Constitution Principle V requires every linter to be driven by a committed configuration file at a documented path, and the Quality Gate Requirements allow exactly one linting configuration per content kind. Commit messages are a content kind this repository does not yet govern.

**Decision**: `.commit-msg.conf` at the repository root — a POSIX `sh`-sourceable file declaring `COMMIT_MSG_TYPES`, `COMMIT_MSG_SCOPE_POLICY` and `COMMIT_MSG_MAX_SUBJECT`.

**Rationale**: it is one file, at the root, documented, and readable by the hook with `.` and by a human at a glance. A shell-sourceable file rather than JSON or YAML because the consumer is POSIX `sh` and Principle I forbids requiring a parser that is not already present.

**Alternatives rejected**: embedding the values in the hook (violates Principle V); a `.commitlintrc` (implies a tool that is not installed and never will be); adding a section to an existing config file (each of them is the declaration for a different content kind, and the Quality Gate Requirements' one-config rule is about not doubling up, not about consolidating).

## 10. Proving the checks can fail

`scripts/selftest.sh` exists to prove each check rejects bad input; `CLAUDE.md` describes it as exactly that. A new check with no selftest case is a check nobody has shown can fail.

**Decision**: extend `selftest.sh` with six cases: a non-conventional subject rejected; a 73-character subject rejected; a 72-character conforming subject accepted; a conforming subject with an over-length body line accepted; an unsigned commit refused by the push check; a present-but-unverifiable signature accepted. Each asserts on exit status **and** on the message naming the violated rule, because Principle II makes a wrong-reason failure indistinguishable from a right one.

## 11. The plugin version, and the stale copy this run was served

Not a hooks question. It belongs here because this feature's user story 5 found it, and because `CLAUDE.md` now carries a rule that cites this section.

**Finding**: `.claude-plugin/plugin.json` has read `"version": "0.1.0"` since the plugin was created, across features 002 through 007 — the six that added the skills, renamed them, added the format hook, added a sixth skill, and rewrote the pipeline's gating. The recorded install is older still: `~/.claude/plugins/installed_plugins.json` shows `version 0.1.0`, `gitCommitSha 3c3d204`, `installedAt 2026-09-02T05:58:56Z`, and the cache directory at that version — `~/.claude/plugins/cache/claude-code-devkit/claude-code-devkit/0.1.0/` — holds `AGENTS.md`, `CLAUDE.md`, `LEAN-CTX.md`, `README.md`, `ruff.toml`, `scripts` and `specs`, with **no `skills/` directory at all**.

**Observed consequence**: this feature's own run was started twice, once through the `Skill` tool and once through `/claude-code-devkit:ccd-speckit-run`. The two delivered materially different copies of `skills/ccd-speckit-run/SKILL.md` — one gate at Step 3 versus a gate per phase, `6d` versus `6e`, no `conflict_checks[]` versus one element per boundary, and an authoring note whose `disable-model-invocation` reasoning contradicted the current one. The file on disk is byte-identical in the main checkout and the worktree, and is the newer version; the slash command served the older text.

**Decision**: bump `version` in any feature that changes `skills/` — minor for a behaviour change, patch for wording — and record that rule in `CLAUDE.md`. This feature bumps it to `0.2.0`.

**Rationale**: the version string is the only cache key a consumer has. A workflow that changes its gating without changing its version can be executed in its old form indefinitely, and the failure is silent — nothing reports that the copy being run is not the copy on disk. This run happened to notice because both copies were loaded in one session, which is not a thing to rely on.

**Alternatives rejected**: bumping once now with no rule (the next six features drift identically, because nothing says to bump); documenting a `/plugin marketplace update` step in the README instead (puts the burden on every consumer and does nothing for a marketplace install from GitHub).

The same review also reworded the plugin's description, which promised "agents, commands, skills, and MCP servers" while `CLAUDE.md` conceded that three of those four are not built. It now describes what ships.

## 12. What is deliberately not built

- No eighth check in `scripts/lint.sh`. A commit message is not a file in the tree; the aggregate check enumerates files.
- No `package.json`, no dependency, no `prepare` script.
- No server-side or CI enforcement — a stated non-goal.
- No key issuance, distribution or rotation — a stated non-goal.
- No repository-invented bypass beyond the two that already exist.
