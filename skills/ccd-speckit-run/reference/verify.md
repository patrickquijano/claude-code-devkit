# Step 5 — Verify and resolve

Phase 8 writes code. Step 6 ships it. No check between → "looks done" is the run's only signal, and the reviewer is first to read a broken build.

Running a check is half the job. Several things report on this feature after Phase 8 and only one of them fails loudly; the rest — hook findings, warnings on a zero exit, markers, unchecked tasks — used to reach the merge request untouched. 5e–5g close that: read `reference/findings.md`.

After Phase 8 completes. State precondition: `phases.8` is `done`.

Phase 8 skipped or stopped early → there is no implementation to check. A **scope-limited** Phase 8 is not this case: it implemented what it was asked to, `phases.8` reads `done: scope-limited to <what>`, and Step 5 checks that work normally. The partial-ship decision belongs to Step 6. Record `steps.5 = "skipped: phase 8 <reason>"`, `verify.result = "none"` and an empty `findings[]`, say so, and go to Step 6 — the partial-ship decision is its, not this step's. Never run a check against work that was never written and report the result as this feature's.

## 5a — Resolve the check

Priority order, first hit wins:

1. A command the constitution mandates — `.specify/memory/constitution.md` naming a test framework, coverage floor, or required check.
2. Verification tasks in `tasks.md` — Spec Kit often emits them explicitly.
3. Repo config: `package.json` scripts (`test`, `lint`, `build`), `Makefile` targets, `pyproject.toml`, `Cargo.toml`, `go.mod`, `justfile`.
4. CI workflow — `.github/workflows/*`, `.gitlab-ci.yml` — run the job's own command locally.

Prefer the narrowest check covering the feature. Record it as `verify.command`.

## 5b — Run it and show the evidence

Run the command. Report the command line and its **actual output** — exit status, failing test names, error text. Never summarize a run as "tests pass" without the output saying so.

## 5c — Fix loop, bounded

Failing → fix the cause, re-run, **three consecutive failures** max. Two counters, and they are not the same number:

- `verify.attempts` — the **total** executions of the check in this step, 5c and 5f together. It is a record, not a limit.
- `verify.consecutive_failures` — what the cap actually governs. Increment on each failing run, **reset to `0` on a green one**, so a fix that turns the check green restores the budget.

The cap is three on `consecutive_failures`, never on `attempts`. Once 5f has re-run the check even once, `attempts` no longer answers "how many times has this failed in a row" — and after a compaction the conversation cannot answer it either, which is why the counter is in state. 5f's per-finding re-runs are bounded separately, three attempts per finding. At three consecutive failures, stop offering a re-run.

- Fix root causes. Never make a test pass by weakening it, skipping it, or deleting it.
- A failure tracing to the spec or plan rather than the code is a conflict — route through `reference/conflicts.md` instead of patching around it.
- Three consecutive failures → stop, report the last output, then `AskUserQuestion`, `header: "Check failing"`: keep fixing, ship anyway with the failure recorded as `verify.override`, or stop the run. **Recommend keeping the fix loop open** and say why — three attempts is a cap on unattended retries, not evidence the check is unfixable, and shipping red puts the failure in front of a reviewer instead. Where the three failures are all the same error with no progress between them, say instead that no recommendation is defensible: that pattern means the run has learned nothing new to try, and whether to keep going is a judgement about the code that only the user can make.
- **Ship anyway is an override, and it is recorded, not remembered.** Set `verify.result = "fail"` and `verify.override` to that decision in the user's own words, with the command and both counters. Step 6 reads `verify.override`; absent it, Step 6 refuses to ship a red branch and sends the run back here.

## 5d — No runner found

Say so plainly at the gate: `verify.result = none`, plus what was searched. Never claim verification that did not happen, never invent a test command the repo does not define.

Offer once: proceed unverified, or name a command to run.

Proceed unverified is the same override. Set `verify.override` to that decision plus what was searched — Step 6 will not ship a `none` result without it.

## 5e — Collect the findings

A green check is not an empty register. Read `reference/findings.md` and sweep all four sources: the `after_implement` hooks in `.specify/extensions.yml` — which this skill dispatches, and which is where `speckit.superb.critique` reports — Step 5b's own non-fatal output, surviving `[NEEDS CLARIFICATION]` markers, and unchecked `tasks.md` items. Write `findings[]` to state as you collect.

The marker sweep and the `tasks.md` sweep are read-only and independent, so `reference/subagents.md` allows dispatching them as one batch while you run the hooks yourself. The hooks are not delegable — they execute commands and can write files. Neither is the check output, which is already in context. Severity, status, and every `findings[]` write stay in the main run whoever did the reading.

## 5f — Resolve them

Severity order, root causes only, three attempts per finding, re-running the check after each fix. A finding that resists three attempts becomes a deferral question, never a silent pass. Deferral takes an explicit user answer, recorded in the user's own words.

## 5g — Register gate

Every finding reads `fixed` or `deferred`. One `open` entry and Step 6 does not run.

## Gate

Report command, result, both counters, evidence, and the register from 5g — every finding's source, severity, statement and status, plus which of the four sources returned nothing. Write `verify`, `findings[]` and `steps.5` to state, then ask with `AskUserQuestion`: proceed to Step 6, re-run the check (only while `verify.consecutive_failures` is under three), keep working the register, or stop.

`steps.5` is `done` whatever the result — Step 5 ran. Whether the branch may ship is `verify.result` plus `verify.override`, and every `findings[]` entry being `fixed` or `deferred`. That is what Step 6 reads. A failing check is a completed step, not an unfinished one; an open finding is not.
