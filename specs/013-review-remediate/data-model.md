# Data Model: Change-Request Review and Remediation

**Feature**: [spec.md](spec.md) | **Date**: 2026-09-13 | **Branch**: `013-review-remediate`

## Entities

### ChangeRequest

Immutable once captured; re-fetched on stale-SHA check failure.

| Field              | Type                      | Source                | Notes                                                  |
| ------------------ | ------------------------- | --------------------- | ------------------------------------------------------ |
| id                 | string                    | CLI positional or URL | Numeric, URL, or branch name per CHK007                |
| forge              | enum: github, gitlab      | forge-detect.sh       | Set once at Step 0                                     |
| author             | string                    | CLI view              | Login or username                                      |
| assignees          | string[]                  | CLI view              | May be empty                                           |
| reviewers          | string[]                  | CLI view              | Requested reviewers                                    |
| source_branch      | string                    | CLI view              | Head branch                                            |
| target_branch      | string                    | CLI view              | Base branch                                            |
| head_sha           | string                    | CLI view              | Exact revision under review                            |
| diff               | text                      | CLI diff              | Unified diff content                                   |
| comments           | Comment[]                 | CLI list              | Existing comments for dedup check                      |
| discussions        | Discussion[]              | CLI list              | Unresolved threads for blocking check                  |
| approvals          | string[]                  | CLI reviews           | Logins that approved                                   |
| ci_status          | enum: pass, fail, pending | CLI status checks     | Aggregate rollup                                       |
| mergeable          | enum: yes, no, unknown    | CLI view              | Platform-reported mergeability                         |
| is_draft           | boolean                   | CLI view              | Draft CRs reviewed but not approved/merged             |
| approval_rules     | ApprovalRule[]            | CLI or repo config    | Required approvers, count, CODEOWNERS                  |
| validation_command | string or null            | Derived per CHK005    | Null when no source; criterion fails unless overridden |

### Finding

Created during review, updated during remediation.

| Field             | Type                                                                                                                                                     | Constraint                     | Notes                                          |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | ---------------------------------------------- |
| id                | string                                                                                                                                                   | Unique within run              | Format: `F-NNN` sequential                     |
| severity          | enum: Critical, High, Medium, Low, Suggestion, Question                                                                                                  | FR-014                         | First four block; last two do not              |
| confidence        | enum: high, medium, low                                                                                                                                  | CHK001                         | Evidence strength, independent of severity     |
| category          | enum: correctness, security, reliability, performance, maintainability, compatibility, tests, accessibility, observability, configuration, documentation | CHK002                         | Maps 1:1 to FR-010 dimensions                  |
| file              | string or null                                                                                                                                           | Null when no location exists   | Relative path from repo root                   |
| line              | integer or null                                                                                                                                          | Null when no location exists   | 1-indexed                                      |
| evidence          | text                                                                                                                                                     | Required                       | Quoted from diff, config, test, or requirement |
| impact            | text                                                                                                                                                     | Required                       | What breaks or degrades                        |
| required_outcome  | text                                                                                                                                                     | Required                       | What author must achieve                       |
| suggested_fix     | text                                                                                                                                                     | Required                       | Concrete remediation hint                      |
| validation_method | text                                                                                                                                                     | Required                       | How to verify fix                              |
| status            | enum: open, fixed, deferred                                                                                                                              | FR-034, CHK008                 | Deferred requires explicit user reason         |
| cycle_found       | integer                                                                                                                                                  | ≥1                             | Which review cycle produced this finding       |
| cycle_fixed       | integer or null                                                                                                                                          | Null when not yet fixed        | Which remediation cycle fixed it               |
| duplicate_of      | string or null                                                                                                                                           | References existing comment ID | FR-012 dedup against existing CR comments      |

### ReviewVerdict

One per review cycle.

| Field             | Type                                                                              | Notes                                               |
| ----------------- | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| cycle             | integer                                                                           | 1–5 (or raised bound)                               |
| verdict           | enum: pass, fail                                                                  | pass only when all criteria satisfied or overridden |
| criteria          | CriterionStatus[]                                                                 | One entry per FR-015 criterion                      |
| findings_summary  | {critical: int, high: int, medium: int, low: int, suggestion: int, question: int} | Counts by severity at verdict time                  |
| published         | boolean                                                                           | False in preview mode or when permission missing    |
| publish_type      | enum: approve, request-changes, comment-only, none                                | comment-only when reviewer is author (FR-047)       |
| head_sha_reviewed | string                                                                            | Must match current head before merge                |

### CriterionStatus

| Field           | Type                                       | Notes                                            |
| --------------- | ------------------------------------------ | ------------------------------------------------ |
| name            | string                                     | e.g., "no-blocking-findings", "ci-pass"          |
| status          | enum: satisfied, not-satisfied, overridden | FR-015, SC-012                                   |
| override_reason | text or null                               | Non-null only when status=overridden (FR-048)    |
| evidence        | text                                       | Command output or API response supporting status |

### RemediationRecord

Maps findings to fixes within one remediation cycle.

| Field         | Type                                                      | Notes                                            |
| ------------- | --------------------------------------------------------- | ------------------------------------------------ |
| cycle         | integer                                                   | Matches ReviewVerdict.cycle                      |
| finding_id    | string                                                    | References Finding.id                            |
| resolution    | text                                                      | What was changed                                 |
| files_changed | string[]                                                  | Relative paths                                   |
| checks_run    | string[]                                                  | Validation commands executed                     |
| check_results | {command: string, exit_code: int, output_excerpt: text}[] | Actual output per FR-025                         |
| commit_sha    | string or null                                            | Null when validation failed (FR-029)             |
| partial       | boolean                                                   | True when remediation stopped mid-cycle (CHK008) |

### AuditEntry

Immutable. Appended, never modified.

| Field     | Type                                                                                                                   | Notes                            |
| --------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| timestamp | ISO 8601                                                                                                               | UTC                              |
| action    | enum: review-published, remediation-committed, merge-executed, permission-denied, cycle-bound-reached, preview-skipped | CHK011                           |
| target    | string                                                                                                                 | CR ID, finding ID, or branch     |
| outcome   | enum: success, failure, skipped                                                                                        | Skipped for preview mode actions |
| evidence  | text                                                                                                                   | Command output or API response   |

## State Transitions

### Finding lifecycle

```text
open → fixed      (remediation verified)
open → deferred   (user explicitly defers with reason)
fixed → open      (re-review finds regression; new finding created per FR-032)
```

No other transitions. Deferred never moves directly to fixed without re-entering open.

### Review cycle progression

```text
cycle N review → verdict(fail) → remediation authorized → remediation record → cycle N+1 review
cycle N review → verdict(pass) → [stop or merge if requested]
cycle 5 verdict(fail) → stop, ask to raise bound (FR-034)
```

### Preview mode effect

Suppresses external state transitions:

- `ReviewVerdict.published` = false
- `RemediationRecord.commit_sha` = null
- `AuditEntry.action` = `preview-skipped`
- Working tree, branch, remote, CR byte-identical (SC-006)

## Validation Rules

- Finding.id unique within run scope
- Finding.severity ∈ {Critical, High, Medium, Low, Suggestion, Question}
- Finding.confidence ∈ {high, medium, low}
- Finding.category ∈ eleven enumerated values
- Finding.evidence non-empty
- ReviewVerdict.verdict = pass ⇒ all criteria satisfied or overridden
- CriterionStatus.override_reason non-null ⇔ status = overridden
- RemediationRecord.commit_sha non-null ⇒ all checks passed
- AuditEntry appended only, never deleted or modified
- Cycle count resets between invocations (CHK009)

<!-- token-budget: compacted (level=medium) on 2026-09-13T09:59:00Z; original at data-model.full.md -->
