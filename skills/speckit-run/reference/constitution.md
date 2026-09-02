# Phase 1 — Constitution handling

Repo-wide durable governance at `.specify/memory/constitution.md`, versioned with semver plus `RATIFICATION_DATE` and `LAST_AMENDED_DATE`. The plan phase's gates (Simplicity, Anti-Abstraction, Integration-First) read it at runtime. Not per-feature — never regenerate it on every run.

## Classify the file

- **absent** — no file.
- **stub** — exists but still carries unresolved `[ALL_CAPS_IDENTIFIER]` placeholder tokens, or a `TODO` ratification date.
- **ratified** — placeholders resolved, version and dates populated.

## absent or stub

Draft principles from, in priority order: explicit non-negotiables in the task; evidence already in the repo (test framework, linter or formatter config, CI workflow, `CLAUDE.md`); the principle count if the user named one.

`CLAUDE.md` is **evidence**, not source text. Read it for what the repo already holds itself to and draw a testable principle from that; never copy a bullet across. The two files answer different questions — `CLAUDE.md` is operational, this file is normative governance that the `plan` phase's gates read at runtime — and `reference/claude-md.md` draws that line from the other side. A rule living in both agrees on the day it is written and drifts silently afterwards, and because the two never contradict at any single moment, no conflict check will ever catch it.

This writes governance binding every future feature, so report the drafted principles before invoking the phase and report the Sync Impact Report after. Phase 1 is not gated — the constitution prompt was approved at Step 3 with the other seven.

## ratified

Do not re-run the command. Read the file, extract principle names and version, carry them as constraints into the specify and plan prompts. Report `constitution vX.Y.Z, N principles, unchanged` at the prompt-review gate, mark Phase 1 skipped with that reason.

## Conflict with a ratified principle

Hand off to `reference/conflicts.md`. Never resolve it silently.

## Amendment mode

When the user chooses to amend:

- Pick the semver bump: MAJOR for a backward-incompatible governance removal, MINOR for a new or expanded principle, PATCH for a clarification.
- Set `LAST_AMENDED_DATE` from `date +%Y-%m-%d`. Never guess a date.
- Leave `RATIFICATION_DATE` untouched.
- Read the command's Sync Impact Report before accepting.
- Never hand-edit `constitution.md` outside the command.

A constitution change alters the gates the `plan` phase checks against, so Phase 1's result is reported before Phase 2 runs — the principles Phase 5 will be measured against are settled facts by then, not something still in flight.
