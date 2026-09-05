# Quickstart: validating feature 011

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

How to prove this feature works. Each scenario names its prerequisites, what to run, and what should happen. Details live in [`contracts/`](./contracts/) and [`data-model.md`](./data-model.md) rather than being repeated here.

## Prerequisites

```sh
git rev-parse --show-toplevel # inside the repository
sh scripts/lint.sh            # baseline: passes before you start
```

The plugin must be installed for the skill scenarios, so that `claude-code-devkit:<name>` resolves. Scenarios 4 and 5 additionally need `gh` or `glab` authenticated; both state what to do when it is not.

## Scenario 1 — The gate narrows, and says when it does not ask

**Proves**: FR-001 – FR-006, SC-001, SC-002, SC-004.

Run `/claude-code-devkit:ccd-speckit-run` on any small task. Accept the plan at Step 3 without revising anything.

Expected:

- Approvals requested at exactly six boundaries — Steps 1, 2b, 6 and Phases 2, 5, 8.
- Phases 1, 3, 4, 6, 7 each print one line naming the phase and why no approval was needed, then proceed.
- Six approvals against eight phases satisfies SC-001.
- Every boundary in the run is accountable as either approved or announced. **A phase that neither asked nor printed is the defect this scenario exists to catch.**

Then run again, revising one phase's argument at Step 3.

Expected: that phase now gates, and its proposal's delta row says what changed.

## Scenario 2 — Irreversible steps still always ask

**Proves**: FR-002, FR-005, SC-003.

During a run, decline at Step 6.

Expected: nothing is committed, pushed, or opened as a pull request, and no branch or worktree is deleted. Then confirm no earlier approval was treated as covering Step 6 — the Step 1 approval must not have satisfied it.

Attempt the reverse check by inspection: read [`contracts/gate-decision.md`](./contracts/gate-decision.md) and confirm every member of the always-gate set is reachable only through an `AskUserQuestion`.

## Scenario 3 — The override restores every-phase gating

**Proves**: FR-007, R5.

Start a run and choose the every-phase option when it is offered at Step 3.

```sh
grep gate_mode .specify/.speckit-run-state.json
```

Expected: `"gate_mode": "every-phase"` in run state, and all thirteen boundaries gate — the run behaves exactly as feature 006 specified. The mode is read from the file, not remembered, so it survives a compaction mid-run.

## Scenario 4 — Pipeline repair, retrieval path

**Proves**: FR-009 – FR-015, FR-017, SC-005, SC-006, SC-007, SC-012.

Prerequisites: a repository with a failed run, and `gh` or `glab` authenticated.

Run `/claude-code-devkit:ccd-pipeline-fix`.

Expected, in order:

1. Preflight names the forge and announces that this run retrieves evidence — **before** anything else.
2. Where more than one failed run or job exists, it asks rather than choosing.
3. The failing log is displayed **before** any cause is proposed.
4. A root cause arrives with the specific evidence supporting it, and nothing has changed yet.
5. At least two remediation approaches are offered, one recommended with a reason.
6. The composed bug report is shown verbatim and can be revised.
7. `claude-code-devkit:ccd-speckit-bug-run` is dispatched — visible as a skill invocation, not as prose naming it.

Afterwards:

```sh
ls .specify/bugs/ < slug > / # assessment.md, fix.md, test.md
git log --oneline -1         # the fix came from the dispatched workflow
```

Expected: the three defect records exist (SC-006), and `ccd-pipeline-fix` itself changed no source file (SC-007).

## Scenario 5 — Pipeline repair, fallback path

**Proves**: FR-010, FR-011b, FR-011c.

Prerequisites: no authenticated forge CLI. Simulate with `PATH= gh` unavailable, or run in a repository whose remote is neither GitHub nor GitLab.

Run `/claude-code-devkit:ccd-pipeline-fix`.

Expected: preflight says which of the four cases applies — no CLI, not authenticated, call failed, unsupported forge — asks for the failing output, and **continues**. It does not stop, and it does not report a failure.

## Scenario 6 — Terminal diagnoses

**Proves**: FR-018, FR-019.

Point the skill at a failure caused by an expired token or a provider outage.

Expected: reported as a finding, the run stops, nothing is dispatched, and the report does not apologise for producing no code change.

Then point it at a failure whose fix would add a requirement.

Expected: reported as feature work, `/ccd-speckit-run` named as the path, and the defect path not entered — Constitution Principle VI is what makes this hard rather than advisory.

## Scenario 7 — Every question carries its shape

**Proves**: FR-020 – FR-024, SC-008, SC-009.

```sh
grep -rn "ask" skills/ --include=SKILL.md --include='*.md' | grep -v AskUserQuestion
```

Expected: no remaining site instructs an ask without the tool. Then read a sample of the converted sites and confirm each has options, per-option effect and cost, exactly one `(Recommended)`, and a stated reason.

```sh
grep -rn "Every question in this skill goes through" skills/
grep -c "AskUserQuestion" .claude/rules/skill-authoring.md
```

Expected: **zero** hits for the first — the four local restatements are gone. Non-zero for the second — the rule has exactly one home (SC-009).

## Scenario 8 — Compaction lost nothing

**Proves**: FR-025, FR-026, FR-027a, FR-028 – FR-031, SC-010, SC-010a.

**FR-027 is withdrawn, so this scenario validates the mechanism, not the corpus.** It asks whether a compaction — when one is done — lands after the carve-out, drops nothing normative, and is audited. It does **not** assert that the toolkit's documents were compacted; exactly one was. Read every "each compacted document" below against a set of one: `skills/ccd-speckit-run/reference/tooling.md`. Reasoning in `research.md` R2, withdrawal in `spec.md`.

The amendment lands first:

```sh
git log --oneline -- .claude/rules/repository-docs.md
```

Expected: the carve-out commit precedes every compaction commit (FR-026).

Then, for each compacted document:

```sh
sh scripts/compaction-audit.sh <base-commit> <path>
```

Expected: `verdict pass` — `normative-lost 0` and `reduction-pct` ≥ 15, measured in **characters** — or a recorded exemption with its reason and actual percentage. **A `fail-lost` verdict is never waivable.**

Actual, for the one document: `fail-short` at 8% with `normative-lost 0`, recorded exempt under FR-030 in `tasks.md`. That is the expected shape here and not a failure — an exemption covers missing the floor and never covers losing a rule.

Confirm the exclusion held:

```sh
git diff --stat specs/ < base-commit > -- | grep -v '011-narrow-gates-pipeline-fix'
```

Expected: empty. No artifact outside this feature's own directory was compacted (FR-027a, SC-010a).

And prove the audit itself rejects bad input:

```sh
sh scripts/selftest.sh
```

Expected: the five `compaction-audit.sh` fixtures pass, including the two that matter — a removed `MUST` line and an altered code block both produce `fail-lost`.

## Scenario 9 — The count agrees everywhere

**Proves**: FR-035, FR-036, SC-011.

```sh
ls -d skills/*/ | wc -l
grep -c '"version": "0.5.0"' .claude-plugin/plugin.json
grep -n "eight skills" .claude-plugin/plugin.json CLAUDE.md
grep -rn "seven skills" . --include='*.md' --include='*.json' | grep -v specs/0
```

Expected: eight directories; version `0.5.0`; "eight skills" in both the manifest and `CLAUDE.md`; and no surviving "seven skills" outside superseded specs, which keep their original wording as the record of what they shipped.

## The whole gate

```sh
sh scripts/lint.sh
```

Expected: passes. Seven checks in the order `citations editorconfig format markdown yaml shell python`, stopping at the first failure.

## Known limit

**Scenarios 4, 5 and 6 cannot be run against this repository.** It has no CI pipeline of its own — no `.github/workflows/`, no `.gitlab-ci.yml` — so `ccd-pipeline-fix`'s forge behaviour has to be validated against a different repository. This is stated rather than papered over: the quality gate passing here is not evidence that the pipeline skill works, and no scenario above should be read as claiming otherwise.
