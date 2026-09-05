# Quickstart: validating the Guided Bug Triage Run

Phase 1 output for [plan.md](./plan.md). How to prove this feature works, end to end, once it is implemented.

This repository has no test runner. Its check is `sh scripts/lint.sh` plus `sh scripts/selftest.sh`, and its regression instrument for a skill is that skill's `evaluations.md` — see `specs/007-forge-review-request-update/tasks.md:11`. So "validation" here means: the checks pass, the two scripts behave as their contracts say against a fixture, and the written scenarios in `evaluations.md` have been walked.

## Contents

- [Prerequisites](#prerequisites)
- [1. The repository checks](#1-the-repository-checks)
- [2. The two scripts, against a fixture](#2-the-two-scripts-against-a-fixture)
- [3. The contract verifications](#3-the-contract-verifications)
- [4. The skill, end to end](#4-the-skill-end-to-end)
- [What "done" looks like](#what-done-looks-like)

## Prerequisites

- This repository, on branch `009-bug-triage-run`.
- The Spec Kit `bug` extension installed. Confirm with `ls .specify/extensions/bug/extension.yml` and `ls -d .claude/skills/speckit-bug-*` — the second matters more, because the compiled skills are what gets dispatched.
- `git`. Nothing else: per Principle I no step here may require a package manager.
- For step 4 only: Claude Code with this plugin installed, since a skill cannot be exercised from a shell.

## 1. The repository checks

```sh
sh scripts/lint.sh
sh scripts/selftest.sh
```

Both must exit `0`. `lint.sh` runs seven checks in order — citations, editorconfig, format, markdown, yaml, shell, python — and stops at the first failure, so a green run means all seven passed.

The new files are all governed: neither `skills/` nor `docs/` nor `.claude/rules/` is excluded by `.prettierignore`, `.markdownlint-cli2.jsonc`'s `ignores`, or `.editorconfig-checker.json`'s `Exclude`. The two new scripts are picked up by `scripts/lint-shell.sh`'s `'*.sh'` glob.

Then confirm both paths agree, which is what the container fallback is for:

```sh
LINT_FORCE_CONTAINER=1 sh scripts/lint.sh
```

## 2. The two scripts, against a fixture

Build a throwaway bug directory rather than triaging a real defect. One fixture exercises most of both contracts.

```sh
cd "$(mktemp -d)"
git init -q -b main scratch && cd scratch
git config user.email t@e.st && git config user.name Test
mkdir -p .specify/bugs/fixture-bug
```

Write an `assessment.md` carrying `**Verdict**: invalid` and `**Severity**: low`, commit nothing, then modify a tracked file so the tree is dirty.

**`bug-preflight.sh`** — expect, per [its contract](./contracts/bug-preflight-cli.md): `capability absent` and three `stage-* missing` lines in this scratch repo (the extension is not installed there), `slug-taken yes` for `fixture-bug`, `dirty yes` with one `dirty-path` line per modified file, and `verdict blocked: …`. Run it again from a non-git directory and expect `dirty unknown` rather than `dirty no` — the two are different and the closing report must not conflate them.

**`bug-outcome.sh`** — expect `assessment present`, `fix absent`, `test absent`, `verdict invalid`, `severity low`, and `status`/`result` both `unknown`. Then break it deliberately: change the label to `**Verdict:**` (colon inside the bold) and confirm the script reports `verdict unknown` rather than guessing. That is the behaviour [G3](./research.md#recorded-gaps) depends on.

Both scripts must exit `0` in every case above except a missing or unreadable `$1` to `bug-outcome.sh`. Exit status reports whether the check ran, never what it found.

## 3. The contract verifications

Run the six checks in [`contracts/skill-names.md`](./contracts/skill-names.md) from the repository root. Expected: no output from checks 1, 2, 3 and 5; `7` from check 4; `0` from check 6.

Check 5 carries an exclusion for `speckit-bug-` and it is load-bearing: the three stage dispatches are Spec Kit project skills, not this plugin's, so they are correctly bare. A run of check 5 without that exclusion reports three false positives, and "fixing" them produces a dispatch that resolves to nothing.

## 4. The skill, end to end

Three scenarios, each proving a different branch of [the branch table](./data-model.md#the-branch-table). They belong in `skills/ccd-speckit-bug-run/evaluations.md`; this is what they must establish.

**Scenario A — the straight path.** A real defect, assessed `valid`, remediated `applied`, validated `verified`. Expect: three gates, each stating command, verbatim wording and artifacts before asking; three reports on disk; a closing report naming all three paths, each outcome, and the commit obligation. Expect **no** branch, **no** commit, **no** review request (FR-020).

**Scenario B — the early exit.** A bug report that is not a defect — unrelated text, or a support question. Expect: assessment records `invalid`; the Stage 2 boundary announces a **skip** with its reason rather than invoking anything; Stage 3 likewise; the closing report distinguishes skipped from run. Expect exactly one report on disk. This is the scenario that proves SC-002 — that no stage is invoked which the capability would refuse.

**Scenario C — the unresolved defect.** A defect whose remediation is insufficient, validated `failed` or `partial`. Expect: the run stops, states what validation found, and puts the choice to the maintainer; it invokes nothing further; and its report does **not** describe the run as successful (SC-006, FR-028).

Two more worth walking because they are where a wrapper skill usually goes wrong:

- **The dirty tree.** Modify a file, then start a run. Expect the already-modified paths named before Stage 2, and the run continuing anyway (FR-029). Expect no stash and no refusal.
- **The URL.** Supply a bug report that is a URL. Expect the run to hand it to Stage 1 verbatim and to fetch nothing itself, so that the assess stage's own host allowlist is what decides (D9, FR-022). A run that reports page contents before Stage 1 has failed this.

## What "done" looks like

- [ ] `sh scripts/lint.sh` exits 0, natively and under `LINT_FORCE_CONTAINER=1`
- [ ] `sh scripts/selftest.sh` exits 0
- [ ] Both scripts match their contracts against the fixture, including the deliberate-drift case
- [ ] The six checks in `contracts/skill-names.md` give their expected output, check 4 returning `7`
- [ ] `skills/ccd-speckit-bug-run/evaluations.md` carries scenarios A, B and C plus the two above, and they have been walked
- [ ] `.claude-plugin/plugin.json` reads `0.3.0` and its description no longer says six
- [ ] `README.md` and `CLAUDE.md` describe seven skills, and `README.md`'s TOC anchor still resolves
- [ ] `docs/spec-kit-extensions.md` carries a Contents list, per-section citations, an "In this repository" paragraph, a Recorded gaps section and a corrections table
- [ ] `design-review.md` records the risks weighed and the resolutions chosen (FR-026)
