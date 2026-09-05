---
paths:
  - '.husky/**'
  - 'scripts/hooks/**'
  - 'scripts/install-hooks.sh'
  - '.commit-msg.conf'
---

# Editing this repository's git hooks

Reasoning and sources: [`docs/husky-git-hooks.md`](../../docs/husky-git-hooks.md). Decision record:
[`specs/008-commit-hooks/research.md`](../../specs/008-commit-hooks/research.md). Contracts:
[`specs/008-commit-hooks/contracts/`](../../specs/008-commit-hooks/contracts/).

These files are also shell scripts, so [`shell-scripts.md`](shell-scripts.md) applies in full — POSIX
`sh`, tabs, `set -eu`, zero ShellCheck findings in `sh` mode. What follows is only what is specific
to the hooks.

## The four things that are load-bearing

- **Husky is optional and must stay optional.** Never add `package.json`, a dependency, a `prepare`
  script, `commitlint`, or any `npm`/`npx`/`node` invocation to a hook body. Constitution
  Principle I forbids a check that requires a package manager, and this whole design exists to
  satisfy it rather than to be excused from it.
- **The logic lives in `scripts/hooks/*.sh`, never in `.husky/`.** Git names hooks by filename, so
  `.husky/commit-msg` cannot end in `.sh`, and `scripts/lint-shell.sh` collects `*.sh` — logic
  written directly into `.husky/` is skipped by the shell check silently and still reports success.
  The dispatchers stay three lines.
- **`scripts/lint-shell.sh` names the two extensionless paths explicitly.** Removing
  `'.husky/commit-msg'` and `'.husky/pre-push'` from its `collect` call stops checking the hooks
  with no error. It looks like redundancy next to `'*.sh'` and is not.
- **`pre-push.sh` rewrites nothing.** No `commit --amend`, no `rebase`, no re-signing, ever. Git has
  already computed the ref updates before the hook runs, so a rewrite pushes the pre-rewrite objects
  and moves the contributor's branch. Signing happens at commit time via `commit.gpgsign`.

## Changing the rules

The permitted types, the scope policy and the length limit are **data**, in `.commit-msg.conf`.
Never move any of them into a hook: Principle V requires a linter be driven by a committed
configuration file, and a value embedded in a script is a value nobody can find.

A missing or invalid `.commit-msg.conf` is fatal — exit 2, naming the file. Never add a fallback to
built-in defaults; a silent default is indistinguishable from a value somebody chose, which is the
same rule `scripts/lib/scope.sh` applies to a missing exclusion declaration.

Widening `COMMIT_MSG_TYPES` is backward-compatible. Narrowing it, or lowering
`COMMIT_MSG_MAX_SUBJECT`, refuses messages that were previously fine — propose that rather than
merging it quietly.

## Exit statuses are a contract

| Code | Meaning                                             |
| ---- | --------------------------------------------------- |
| `0`  | accepted                                            |
| `1`  | refused — a rule was broken                         |
| `2`  | nothing was judged — a usage or configuration error |

`1` and `2` must stay distinct. A contributor whose configuration file is missing must not read that
as "my message was bad".

## Signature verdicts

Refuse exactly `N` (no signature) and `B` (bad signature). Accept `G`, `U`, `X`, `Y`, `R` and `E`.

`E` is the ordinary status of a correctly SSH-signed commit when `gpg.ssh.allowedSignersFile` is
unset, which is the default. Tightening this to "`G` only" blocks contributors who have done nothing
wrong and trains them to use `--no-verify` routinely.

## Never write a signing identity

`scripts/install-hooks.sh` may write `core.hooksPath` and `commit.gpgsign`, both `--local`. It must
never write `gpg.format` or `user.signingkey`, and never anything `--global`. Guessing a key produces
commits signed by the wrong identity, which is worse than an unsigned commit: one is visibly
unattributed, the other is confidently misattributed.

## Prove every rule can fail

Every rule these files enforce has a case in `scripts/selftest.sh`, asserting on the exit status
**and** on the message naming the violation. Adding a rule without a case ships a rule nobody has
shown can reject anything. Assert on the message too: a right failure for the wrong reason is
indistinguishable from a right one on exit status alone.

The message cases need no repository — `commit-msg.sh` takes a message-file path, so a fixture file
is enough. Keep it that way; a case that needs a temporary git repository is a case that gets
deleted the first time it is slow.

## Never

- Never make a hook depend on the network, on a package manager, or on a tool outside POSIX `sh` and
  git.
- Never let a hook write to the repository, the index, or any ref.
- Never invent a repository-specific bypass. `--no-verify` and `HUSKY=0` are the two that exist and
  contributors already know them.
- Never point `core.hooksPath` at `.husky` unconditionally — detect `.husky/_` first, or a Husky
  user breaks on their next `npm install`.
