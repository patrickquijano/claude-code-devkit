# Quickstart: validating commit message and signature enforcement

**Feature**: `008-commit-hooks` | **Date**: 2026-09-05

Runnable scenarios that prove the feature works end to end. Details of behaviour live in [`contracts/`](./contracts/) and [`data-model.md`](./data-model.md); this file is the run guide.

## Prerequisites

- git ≥ 2.9 (`core.hooksPath` support)
- a POSIX shell
- **nothing else** — no Node, no npm, no dependency install. That is the point of scenario 1.

Optional, only for scenario 6: Node and npm, if you want to exercise the Husky path.

## Scenario 1 — activate on a fresh clone

```sh
git clone <repo> && cd <repo>
sh scripts/install-hooks.sh
```

Expected: reports `core.hooksPath` set to `.husky`, `commit.gpgsign` set to `true`, the state of `gpg.format` and `user.signingkey`, and a final line reading **active**.

Verify no package manager was involved:

```sh
git config --local --get core.hooksPath # .husky
ls package.json                         # No such file or directory
```

## Scenario 2 — idempotence

```sh
sh scripts/install-hooks.sh
```

Expected: every line reports `already set`; final line **active**; exit `0`. Nothing changed. Proves SC-005.

## Scenario 3 — the message check refuses and accepts

```sh
git commit --allow-empty -m 'add the thing'
```

Expected: refused. stderr names the format rule and reproduces `add the thing`. `git log -1 --format=%s` is unchanged.

```sh
git commit --allow-empty -m "feat: $(printf 'x%.0s' $(seq 1 66))"
```

Expected: refused, naming the 72-character limit and printing the measured length `73`.

```sh
git commit --allow-empty -m 'feat(hooks): enforce the commit message convention'
```

Expected: accepted, silently.

```sh
git commit --allow-empty -m 'feat: short subject' -m "$(printf 'y%.0s' $(seq 1 140))"
```

Expected: accepted. The body line is 140 characters and is not examined — proves the limit governs the first line alone.

## Scenario 4 — the emergency route

```sh
git commit --allow-empty --no-verify -m 'this would otherwise be refused'
```

Expected: accepted. The bypass is visible in the command the contributor typed, and the checks stay armed for the next commit. Reset with `git reset --hard HEAD~1`.

## Scenario 5 — the push check refuses unsigned work

Produce one unsigned commit and attempt to send it:

```sh
git -c commit.gpgsign=false commit --allow-empty -m 'chore: unsigned on purpose'
git push origin HEAD
```

Expected: refused before anything reaches the remote. stderr lists that commit's abbreviated SHA and subject and states the remediation.

Then confirm **nothing was rewritten** — the requirement most at risk of being violated by a well-meaning implementation:

```sh
git rev-parse HEAD # identical to the value before the refused push
```

Proves FR-008 and SC-006.

Re-sign and retry:

```sh
git commit --amend --no-edit -S
git push origin HEAD
```

Expected: proceeds.

## Scenario 6 — the Husky path (optional)

Only if you already work in Node. From a scratch clone, not the repository itself — this repository ships no `package.json` and must not gain one.

```sh
npm install --save-dev husky && npx husky init
sh scripts/install-hooks.sh
git config --local --get core.hooksPath # .husky/_
```

Expected: the installer detects `.husky/_` and leaves Husky owning the arrangement. Both hooks still fire, with the same messages as scenarios 3 and 5 — the hook bodies are the same files either way.

## Scenario 7 — deactivate

```sh
git config --unset core.hooksPath
sh scripts/install-hooks.sh --status
```

Expected: final line reads **inactive**. This is Husky's own documented removal step and works identically on both paths.

## Scenario 8 — the repository's own checks still pass

```sh
sh scripts/lint.sh
sh scripts/selftest.sh
```

Expected: `lint.sh` passes all seven checks with the new shell files included — `scripts/hooks/*.sh` via the existing `*.sh` glob, `.husky/commit-msg` and `.husky/pre-push` via the two paths added to the shell check's glob list. `selftest.sh` passes, including the six new cases proving each new rule can actually reject bad input.
