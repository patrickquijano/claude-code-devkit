# Husky and this repository's git hooks

How commit messages and commit signatures are enforced here, why Husky is optional rather than required, and what to do when a hook refuses you.

The decision record — what was chosen, what was rejected and why — is [`specs/008-commit-hooks/research.md`](../specs/008-commit-hooks/research.md). This document does not repeat those arguments; it states the conclusions and cites them.

## Contents

- What Husky is, and what it is not
- Why Husky is optional here
- Activating the checks
- The commit-message rule
- The signature rule
- Bypassing a check
- Deactivating
- In this repository
- Recorded gaps

## What Husky is, and what it is not

Husky is a Node package whose whole job is to point git at a directory of hook scripts and keep that pointer working after every `npm install`. It is not a validator, a linter, or a commit-message parser. It runs whatever shell you put in `.husky/<hook-name>`; the content of those files is yours.

The mechanism, from the package's own source and documentation:

| Fact                                                                                                                       | Source                                      |
| -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `husky init` writes `"prepare": "husky"` into `package.json`, creates `.husky/`, and seeds `.husky/pre-commit`             | `typicode/husky` `bin.js`; `docs/how-to.md` |
| Running `husky` sets `core.hooksPath` to `.husky/_`, and git executes hooks from there instead of `.git/hooks`             | `typicode/husky` `docs/troubleshoot.md`     |
| `.husky/_` holds generated shims plus a `.gitignore` whose entire content is `*`                                           | `typicode/husky` `index.js`                 |
| Uninstalling is `git config --unset core.hooksPath`                                                                        | `typicode/husky` `docs/troubleshoot.md`     |
| `HUSKY=0` in the environment disables hook installation and execution                                                      | `typicode/husky` `docs/how-to.md`           |
| The `add`, `set` and `uninstall` subcommands were removed in v9 and exit non-zero; `install` is deprecated but still works | `typicode/husky` `bin.js`                   |

The consequence that matters is in the third row. **`.husky/_` is generated and gitignored.** A fresh clone contains the hook files and not the shims, and `core.hooksPath` is unset — so with Husky alone, nothing runs until someone executes `npm install`.

## Why Husky is optional here

The repository's constitution, Principle I, is marked NON-NEGOTIABLE:

> Every repository quality check MUST produce its verdict using only POSIX `sh` plus either the tool installed natively or a container runtime. No check MAY require a language package manager, a virtual environment, or a global install step as a precondition for running it.

A commit-message check is a quality check, and Husky's activation is a package-manager install step. This repository also has no `package.json` at all.

So the hooks here are committed POSIX `sh`, and they are activated by a committed shell script. Husky is supported as a second path for contributors who already work in Node — the hook bodies are the same files either way — and is never required by anything. See [`research.md` §2](../specs/008-commit-hooks/research.md).

|                  | Husky present                                    | Husky absent                               |
| ---------------- | ------------------------------------------------ | ------------------------------------------ |
| `core.hooksPath` | `.husky/_`                                       | `.husky`                                   |
| Who sets it      | `husky`, on every `npm install`                  | `scripts/install-hooks.sh`, once           |
| What git runs    | `.husky/_/<hook>`, which sources `.husky/<hook>` | `.husky/<hook>` directly                   |
| Re-arms itself   | yes                                              | no — re-run the script after a fresh clone |

`scripts/install-hooks.sh` **detects** which case it is in rather than assuming. Writing `.husky` unconditionally would break a Husky user on their next `npm install`, when `husky` sets the value back to `.husky/_` and the two disagree about which file git actually runs.

## Activating the checks

From the repository root:

```sh
sh scripts/install-hooks.sh
```

It sets `core.hooksPath`, sets repository-local `commit.gpgsign true` so commits are signed when they are created, makes the hook files executable, and reports where the signing identity stands. It is idempotent: run it twice and the second run reports `already set` on every line and changes nothing.

To ask without changing anything:

```sh
sh scripts/install-hooks.sh --status
```

The last line of either invocation reads `state: active` or `state: inactive`. That line is the answer; you never need to read a script to find out whether the checks are on.

**It never writes `gpg.format` or `user.signingkey`.** Those identify a signing scheme and a person's key, and guessing either produces commits signed by the wrong identity — which is worse than no signature, because an unsigned commit is visibly unattributed while a wrongly signed one is confidently misattributed. The installer reports them and stops there.

### An authentication key is not a signing key

The installer also reports a `forge signing key` line, because a correctly signed commit can still read **Unverified** on the forge and no local check can tell.

GitHub keeps two separate key lists. `user/keys` holds the keys that may **push**; `user/ssh_signing_keys` holds the keys whose **signatures** it will verify. Adding a key to the first does not add it to the second, and only the second is consulted when a commit is verified. A key in the first list alone pushes perfectly and produces commits the API reports as `verified: false`, `reason: unknown_key`.

Nothing on this machine sees that. `git verify-commit` resolves the signature against `allowed_signers` here and says `Good signature`; the `pre-push` check reads `%G?`, which is that same local answer. The gap is only visible from the forge's side, which is why the installer asks it rather than the hook.

This repository had it: eighteen commits' worth of authored history read `Unverified` while `main` looked clean, because squash-merge replaces the author's commit with one GitHub signs itself. Registering the key repaired the history retroactively — the forge recomputes verification when it is read, so no rebase and no rewrite were needed.

The line reports `github: registered`, `github: NOT registered` with the `gh ssh-key add --type signing` remedy, or `not checked` with the reason it could not judge. It never fails the run, and `gh` is optional: without it the script still needs nothing but POSIX `sh` and git.

## The commit-message rule

The first line must be:

```text
<type>[(<scope>)][!]: <description>
```

and at most **72 characters**. Lines after the first are not length-checked at all.

The permitted types, the scope policy and the limit live in one committed file, [`.commit-msg.conf`](../.commit-msg.conf), which both the hook and this document draw from. Editing that file changes the rule for every contributor at their next commit — no code change, no reinstall.

As committed today: types are `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style` and `test`; a scope is optional; the limit is 72.

Machine-generated messages are exempt — a subject beginning with `Merge`, `Revert`, `fixup!`, `squash!` or `amend!` **followed by a space** is accepted unexamined, because its shape was fixed by the tool that wrote it and you cannot reword it. The trailing space is part of the test and is spelled out here because Markdown formatting silently strips it from a code span.

A reverting commit is therefore acceptable in **either** shape: the generated `Revert "..."` form, via that exemption, or a hand-written `revert: ...`, via the permitted type. Neither excludes the other.

Every refusal names the rule it broke and reproduces the offending subject, and a length refusal prints the measured length as well as the limit — being told "too long" without the number leaves you counting the line yourself.

## The signature rule

Before a push, every commit in the outgoing range is examined. Git reports one status character per commit:

| `%G?` | Meaning                               | Verdict     |
| ----- | ------------------------------------- | ----------- |
| `G`   | good signature                        | accepted    |
| `U`   | good signature, unknown validity      | accepted    |
| `X`   | good signature that has expired       | accepted    |
| `Y`   | good signature made by an expired key | accepted    |
| `R`   | good signature made by a revoked key  | accepted    |
| `E`   | signature present, cannot be checked  | accepted    |
| `B`   | bad signature                         | **refused** |
| `N`   | no signature                          | **refused** |

`E` is accepted deliberately, and it is the row most likely to look wrong. It is the ordinary status of a correctly SSH-signed commit when `gpg.ssh.allowedSignersFile` is unset — which is the default. Refusing it would block contributors who have configured signing correctly, with an error about verification they cannot act on, and would train them to reach for `--no-verify` as routine. Checking signers against a key list is a separate control, not this one. See [`research.md` §6](../specs/008-commit-hooks/research.md).

**The hook rewrites nothing.** It does not amend, rebase or re-sign. A signature is part of the commit object, so producing one changes the commit's identifier — and git has already computed the ref updates it is about to send by the time the hook runs, so a rewrite there would push the pre-rewrite objects and move your branch out from under you. There is no correct version of "sign it during the push"; signing happens at commit time. See [`research.md` §7](../specs/008-commit-hooks/research.md).

When a push is refused, every offending commit is listed by short SHA and subject, with the remediation:

```sh
git commit --amend --no-edit -S                                    # the most recent commit
git rebase --exec "git commit --amend --no-edit -S" <base-ref>     # a run of commits
```

## Bypassing a check

Two routes exist and they are not equivalent.

**`git commit --no-verify`, `git push --no-verify`** — git's own flag. Skips the hook for that one invocation. This is the contributor-facing emergency route: it is per-invocation, it is visible in the command you typed, and it leaves the checks armed for next time. Legitimate when you need the commit now and will fix the message or the signature in the same session.

**`HUSKY=0`** — Husky's environment variable, documented for CI and Docker images where hooks should not run at all. It is only meaningful on the Husky path; on the fallback path git runs `.husky/<hook>` directly and never consults it. Legitimate in automation, not at a keyboard.

There is deliberately no third, repository-specific bypass. A bypass a repository invents is one no contributor already knows.

## Deactivating

```sh
git config --unset core.hooksPath
```

This is Husky's own documented removal step and it works identically on both paths. `sh scripts/install-hooks.sh --status` will then report `state: inactive`.

## In this repository

The hooks are two thin dispatchers and two scripts:

| Path                                   | What it is                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------ |
| `.husky/commit-msg`, `.husky/pre-push` | dispatchers; each resolves the repository root from git and `exec`s the script below |
| `scripts/hooks/commit-msg.sh`          | wrapper; sources the library below and calls it                                      |
| `scripts/hooks/pre-push.sh`            | wrapper; sources the library below and calls it                                      |
| `scripts/lib/commit-msg.sh`            | the message rules; takes a message-file path                                         |
| `scripts/lib/push-check.sh`            | the signature rules; reads ref updates on stdin                                      |
| `scripts/install-hooks.sh`             | activation and the state report                                                      |
| `.commit-msg.conf`                     | the rule set                                                                         |

The split is not decoration. Git decides which hook to run from the filename alone, so `.husky/commit-msg` cannot be called `commit-msg.sh` — and `scripts/lint-shell.sh` collects `*.sh`, so hooks written directly in `.husky/` would have been **skipped by the shell check silently**: scripts the constitution requires be checked, that nothing checked, with no error to notice. Putting the logic under `scripts/` puts it inside the existing glob, and the two extensionless dispatcher paths are named explicitly in the shell check's `collect` call alongside it. Removing those two paths stops checking the hooks and still reports success, so do not tidy them away.

The rules themselves sit one level further in, in `scripts/lib/`, so that `scripts/selftest.sh` can reach them without executing a sibling script — the same arrangement every entry point under `scripts/` now uses. It calls `commit_msg_main` with a fixture file exactly as git invokes the hook, so twenty cases run with no temporary repository and no real commit. Run them with:

```sh
sh scripts/selftest.sh
```

Two of those cases are conditional and say so when they skip: the signed-commit case needs a `user.signingkey` on the machine, because a fixture cannot manufacture a signature.

`.husky/_/` is in `.gitignore` here as well as being gitignored by Husky itself, which covers the case where the directory exists without Husky's own file.

## Recorded gaps

- **Whether `git config --get` falling back to global configuration is the intended reading for a repository-local activation script.** `scripts/install-hooks.sh` reports `gpg.format` and `user.signingkey` with `git config --get`, which consults the global configuration, so a contributor who signs everything sees `already set` even in a repository where nothing local is configured. That is the useful answer — the identity that will actually sign — but no authoritative source settles whether a repository-scoped installer should report scope-resolved or local-only values. Recorded rather than decided.
- **Whether an explicit `Skill`-tool dispatch counts as automatic invocation for `disable-model-invocation`.** Unrelated to hooks and recorded here only because it surfaced during this feature's review; the authoritative documentation is ambiguous, and `skills/ccd-speckit-run/SKILL.md` records the repository's reading. No authoritative source was found.
