# Phase 1 Data Model: Approvals, pipeline repair, and the question standard

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

This feature stores no records in a datastore. Its "entities" are structures held in run-state files, in skill frontmatter, and in the text of documents — so each is given with where it lives, what it holds, what constrains it, and how it changes.

## Contents

- Gate decision
- Run gate mode
- Pipeline evidence
- Root cause proposal
- Remediation approach
- Composed bug report
- Question
- Compaction audit result
- Skill registration

---

## Gate decision

**What it represents**: the answer to "does Step 4 ask before this phase?", computed fresh at each phase boundary. Not persisted — derived.

| Field              | Type                               | Notes                                                                  |
| ------------------ | ---------------------------------- | ---------------------------------------------------------------------- |
| `phase`            | 1–8, or a step id (`1`, `2b`, `6`) | the boundary being evaluated                                           |
| `always_gates`     | boolean                            | true for Phases 2, 5, 8 and Steps 1, 2b, 6 — FR-002's irreversible set |
| `argument_differs` | boolean                            | verbatim comparison against Step 3's drafted argument — FR-001         |
| `gate_mode`        | `narrowed` \| `every-phase`        | read from run state — FR-007                                           |
| `asks`             | boolean                            | `always_gates OR argument_differs OR gate_mode == "every-phase"`       |
| `reason`           | string                             | why it asked, or why it did not — printed either way under FR-004      |

**Validation**: `asks` is false only when all three inputs are false. A boundary with `always_gates` true can never compute `asks` false, whatever the other inputs say — this is the invariant FR-005 depends on.

**Derivation order** is fixed in `contracts/gate-decision.md` so the rule has one home (R4).

## Run gate mode

**What it represents**: the maintainer's FR-007 choice, for the whole run.

**Lives in**: `.specify/.speckit-run-state.json`, key `gate_mode`.

| Field       | Type                        | Notes                                 |
| ----------- | --------------------------- | ------------------------------------- |
| `gate_mode` | `narrowed` \| `every-phase` | default `narrowed`; written at Step 3 |

**Validation**: any value outside the two is an error condition, not a third behaviour — the same closed-set discipline `.claude/rules/spec-kit-bug-workflow.md` applies to the bug outcome vocabularies. Absent on a resumed run written before this feature → treat as `narrowed` and say so.

**Lifecycle**: written once at Step 3, read before every phase, never rewritten mid-run. A maintainer changing their mind restarts the choice by stopping and re-running; the mode is not re-offered per phase, per R5.

## Pipeline evidence

**What it represents**: what was gathered about a failed run, before any cause is proposed.

**Lives in**: the run's own state file while the run is live, and in the composed bug report thereafter.

| Field            | Type                           | Notes                                                              |
| ---------------- | ------------------------------ | ------------------------------------------------------------------ |
| `forge`          | `github` \| `gitlab`           | from the shared `forge-detect.sh`, never re-detected               |
| `retrieval_path` | `cli` \| `maintainer-supplied` | decided at preflight and announced — FR-011c                       |
| `run_id`         | string                         | the failed run selected                                            |
| `job`            | string                         | the failing job selected                                           |
| `candidates`     | list                           | every failed run/job offered when there was more than one — FR-017 |
| `log`            | text                           | the failing output, displayed before any proposal — FR-011         |
| `retrieved_at`   | timestamp                      | so a stale log is visible as stale                                 |

**Validation**: `log` empty, truncated, or unavailable through retention is not an absence to work around — it is reported, and the maintainer is asked to supply output instead. `candidates` with more than one entry and no recorded selection is an error: FR-017 forbids choosing silently.

## Root cause proposal

| Field           | Type                                    | Notes                                                 |
| --------------- | --------------------------------------- | ----------------------------------------------------- |
| `statement`     | text                                    | the proposed cause                                    |
| `evidence_refs` | list                                    | the specific lines or excerpts supporting it — FR-012 |
| `scope`         | `in-repository` \| `outside-repository` | `outside-repository` is a terminal finding, FR-018    |
| `approved`      | boolean                                 | nothing changes until true                            |

**State transitions**: proposed → approved → carried into the report; or proposed → rejected → back to evidence; or proposed with `scope = outside-repository` → reported and the run ends without dispatch.

## Remediation approach

| Field                | Type             | Notes                                                           |
| -------------------- | ---------------- | --------------------------------------------------------------- |
| `options`            | list, ≥2         | FR-013; a single "alternative" does not satisfy the requirement |
| `chosen`             | one of `options` | the maintainer's, never the run's                               |
| `alters_requirement` | boolean          | true is terminal — feature work, not defect work, FR-019        |

## Composed bug report

**What it represents**: the single argument handed to `claude-code-devkit:ccd-speckit-bug-run`.

| Field            | Type             | Notes                                                             |
| ---------------- | ---------------- | ----------------------------------------------------------------- |
| `body`           | text             | evidence, approved root cause, chosen approach                    |
| `slug`           | string, optional | flat and user-named — no `NNN-` prefix, per the bug-workflow rule |
| `shown_verbatim` | boolean          | displayed for revision before dispatch                            |

**Validation**: the report is composed by this skill and shown before it is sent, so the "byte-identical" rule that governs a maintainer-supplied report applies from the moment the maintainer approves this text. It is never rewritten after approval, and no URL inside it is pre-fetched — `speckit-bug-assess` applies its own host allowlist and untrusted-input policy, and fetching first would hand it prose instead of a URL.

## Question

**What it represents**: any point where a skill asks the maintainer something. Not persisted; a shape every ask must satisfy.

| Field                   | Type                                     | Notes                                                     |
| ----------------------- | ---------------------------------------- | --------------------------------------------------------- |
| `question`              | text                                     | ends in `?`, self-contained                               |
| `header`                | string, ≤12 chars                        | the chip label                                            |
| `options`               | list, ≥2                                 | FR-020 — prose-only asks are forbidden                    |
| `options[].label`       | string                                   |                                                           |
| `options[].description` | text                                     | what it does **and** what it costs — FR-021               |
| `recommended`           | exactly one option, or `none-defensible` | FR-022                                                    |
| `justification`         | text                                     | why that one — FR-022; or why none is defensible — FR-023 |

**Validation**: `recommended` unset with no `none-defensible` statement is a defect. Exactly one option carries the `(Recommended)` label; two is a defect, zero without the explicit statement is a defect.

## Compaction audit result

**What it represents**: the output of `scripts/compaction-audit.sh` for one document.

| Field                          | Type                         | Notes                                                    |
| ------------------------------ | ---------------------------- | -------------------------------------------------------- |
| `path`                         | string                       | the document audited                                     |
| `baseline_ref`                 | git ref                      | what it is compared against                              |
| `lines_before` / `lines_after` | integer                      | non-code, non-frontmatter, non-blank — R2                |
| `reduction_pct`                | number                       | must be ≥ 15 to pass, R2                                 |
| `normative_lost`               | list                         | R1 lines present in baseline, absent now — must be empty |
| `verdict`                      | `pass` \| `fail` \| `exempt` | `exempt` requires a recorded reason, FR-030              |

**Validation**: `verdict = pass` requires `normative_lost` empty **and** `reduction_pct ≥ 15`. `normative_lost` non-empty is never `exempt` — an exemption covers failing the threshold, never losing a rule.

## Skill registration

**What it represents**: the facts about each distributed skill that the count contract pins.

| Field                      | Type          | Notes                                           |
| -------------------------- | ------------- | ----------------------------------------------- |
| `directory`                | string        | equals frontmatter `name`, both `ccd-`-prefixed |
| `name`                     | string        |                                                 |
| `disable_model_invocation` | always absent | R9 — never present on any of the eight          |
| `user_invocable`           | always absent | absence is what leaves it invocable             |
| `dispatched_by`            | list          | which skills dispatch it, namespaced            |
| `has_evaluations`          | boolean       | must be true for all eight                      |

**Validation**: eight registrations after this feature. `plugin.json`'s description, `CLAUDE.md`, and `contracts/skill-names.md` must agree on the count — SC-011 makes disagreement a failure.
