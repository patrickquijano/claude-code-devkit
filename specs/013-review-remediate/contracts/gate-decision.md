# Contract: Gate Decision for Review and Remediation Skill

**Feature**: [spec.md](../spec.md) | **Date**: 2026-09-13 | **Branch**: `013-review-remediate`

## Purpose

Closed set of outcomes and decision gates for `ccd-review-remediate`. Gates evaluated in order; first match decides. No gate skipped silently.

## Gate Evaluation Order

### G1 — Forge Detection (Step 0)

Evaluated once at preflight. Never re-evaluated.

| Condition                                    | Outcome                    | Action                                   |
| -------------------------------------------- | -------------------------- | ---------------------------------------- |
| `forge-detect.sh` verdict = `ready`          | proceed                    | Record forge, CLI, review_skill in state |
| `forge-detect.sh` verdict = `skip: <reason>` | stopped: unsupported-forge | Report reason, stop                      |
| No git repository                            | stopped: not-a-repo        | Report, stop                             |

### G2 — Change Request Discovery (Step 0)

| Condition                                  | Outcome                    | Action                       |
| ------------------------------------------ | -------------------------- | ---------------------------- |
| Exactly one open CR for current branch     | proceed                    | Record CR ID, head_sha       |
| Zero open CRs, no explicit ID provided     | stopped: no-change-request | Report, stop                 |
| Multiple open CRs, no explicit ID provided | stopped: ambiguous-cr      | List CRs, ask user to select |
| Explicit ID provided, resolves to one CR   | proceed                    | Record CR ID, head_sha       |
| Explicit ID provided, resolves to zero CRs | stopped: cr-not-found      | Report, stop                 |

### G3 — Working Tree Cleanliness (before any write action)

| Condition          | Outcome             | Action                         |
| ------------------ | ------------------- | ------------------------------ |
| Working tree clean | proceed             | Continue                       |
| Working tree dirty | stopped: dirty-tree | Report uncommitted paths, stop |

### G4 — Permission Pre-Check (before publish/approve/merge)

| Condition                                        | Outcome                     | Action                        |
| ------------------------------------------------ | --------------------------- | ----------------------------- |
| Authenticated user has write or admin permission | proceed                     | Cache result, continue        |
| Authenticated user lacks write permission        | skipped: no-permission      | Report, skip this action only |
| Permission probe fails                           | skipped: permission-unknown | Report, skip this action only |

### G5 — Self-Author Check (before approve)

| Condition            | Outcome      | Action                                                   |
| -------------------- | ------------ | -------------------------------------------------------- |
| Reviewer ≠ CR author | proceed      | Publish approve or request-changes per verdict           |
| Reviewer = CR author | comment-only | Publish findings as comments, record no verdict (FR-047) |

### G6 — Verdict Pass Criteria (after review)

All six criteria MUST be satisfied or explicitly overridden.

| Criterion                | Satisfied When                                    | Override Allowed |
| ------------------------ | ------------------------------------------------- | ---------------- |
| no-blocking-findings     | Zero unresolved Critical/High/Medium/Low findings | No               |
| ci-pass                  | CI status = pass                                  | Yes (FR-048)     |
| discussions-resolved     | Zero unresolved blocking discussions (CHK003)     | No               |
| head-sha-unchanged       | Current head_sha = reviewed head_sha              | No               |
| approval-rules-satisfied | Platform-reported approval requirements met       | No               |
| validation-pass          | Repository validation command exits 0             | Yes (FR-048)     |

Verdict = `pass` when all criteria satisfied or overridden. Verdict = `fail` otherwise.

### G7 — Cycle Bound (after verdict = fail)

| Condition     | Outcome              | Action                                                 |
| ------------- | -------------------- | ------------------------------------------------------ |
| cycle < bound | proceed              | Enter remediation if authorized                        |
| cycle = bound | stopped: cycle-bound | Report remaining findings, ask to raise bound (FR-034) |

### G8 — Remediation Authorization (before code changes)

| Condition                              | Outcome                 | Action                                     |
| -------------------------------------- | ----------------------- | ------------------------------------------ |
| User explicitly authorized remediation | proceed                 | Enter remediation phase                    |
| Preview mode active                    | preview                 | Skip remediation, report what would change |
| No authorization                       | stopped: not-authorized | Report findings, stop                      |

### G9 — Merge Authorization (before merge)

| Condition                                       | Outcome                  | Action                           |
| ----------------------------------------------- | ------------------------ | -------------------------------- |
| User explicitly requested merge AND all G6 pass | proceed                  | Ask squash/delete options, merge |
| Any G6 criterion unsatisfied                    | stopped: merge-gate-fail | Report failing criteria, stop    |
| Head SHA changed since last review              | stopped: stale-sha       | Re-review required, stop         |

## Closed Outcome Vocabulary

Every run ends with exactly one outcome. A value outside this set is a defect.

| Outcome                       | Meaning                                              |
| ----------------------------- | ---------------------------------------------------- |
| `review-published`            | Findings and verdict published to CR                 |
| `remediation-complete`        | All findings addressed, validation passed, committed |
| `merged`                      | CR merged, source branch handled per user choice     |
| `stopped: unsupported-forge`  | Forge not GitHub or GitLab                           |
| `stopped: not-a-repo`         | Not inside a git repository                          |
| `stopped: no-change-request`  | No open CR found for branch                          |
| `stopped: ambiguous-cr`       | Multiple CRs, user did not select                    |
| `stopped: cr-not-found`       | Explicit ID resolved to nothing                      |
| `stopped: dirty-tree`         | Uncommitted changes prevent safe operation           |
| `stopped: cycle-bound`        | Five cycles exhausted, user declined to raise        |
| `stopped: not-authorized`     | Remediation not authorized                           |
| `stopped: merge-gate-fail`    | Pass criteria not met for merge                      |
| `stopped: stale-sha`          | Head SHA changed since review                        |
| `skipped: no-permission`      | Write action skipped due to missing permission       |
| `skipped: permission-unknown` | Write action skipped due to failed permission probe  |
| `preview`                     | Dry-run completed, no external state changed         |

## Invariants

- Forge decided at G1, never re-detected
- Permission probe cached per invocation, never re-probed within same action batch
- Cycle count resets between invocations (CHK009)
- Audit entry written for every outcome except `preview` (which writes `preview-skipped`)
- Self-author check (G5) cannot be overridden
- Override requires explicit user reason recorded in CriterionStatus.override_reason

<!-- token-budget: compacted (level=medium) on 2026-09-13T09:59:00Z; original at gate-decision.full.md -->
