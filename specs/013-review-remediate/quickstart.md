# Quickstart: Change-Request Review and Remediation Validation

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Branch**: `013-review-remediate`

## Prerequisites

- Git repo with GitHub or GitLab `origin` remote
- `gh` or `glab` CLI installed and authenticated
- Claude Code session with `claude-code-devkit` plugin
- Clean working tree on branch with ≥1 open change request

## Validation Scenarios

### Scenario 1: Review-only on branch with one open PR/MR

```sh
/ccd-review-remediate
```

Expected:

- Preflight reports forge, CLI status, CR ID, head SHA, author, assignees, reviewers, CI, mergeability
- Findings published with severity, confidence, category, file, line, evidence quote, impact, required outcome, suggested fix, validation method
- Verdict against six pass criteria with per-criterion status
- Working tree unchanged (`git status`)
- No commits pushed (`git log --oneline origin/<branch>..HEAD`)

### Scenario 2: Dry-run preview mode

```sh
/ccd-review-remediate --dry-run
```

Expected:

- Same findings and verdict as Scenario 1
- No comments published, no approval/request-changes recorded
- Audit entries show `preview-skipped` for publish actions
- Working tree, branch, remote, CR byte-identical before and after

### Scenario 3: Self-authored CR produces comment-only output

```sh
/ccd-review-remediate
```

Expected (authenticated user authored open CR):

- Findings published as comments only
- No approval or request-changes verdict recorded
- Output states "comment-only: reviewer is author" per FR-047

### Scenario 4: Remediation cycle with verification

```sh
/ccd-review-remediate --remediate
```

Expected:

- Prioritized plan shown before code changes
- Minimal root-cause fixes, regression tests added/updated
- Targeted checks then full validation suite
- Final diff inspected for unintended changes and credentials
- Committed per repo conventions, pushed without force
- Remediation summary maps every finding ID to resolution, files, checks, commit SHA
- Re-review confirms findings resolved or reports regressions

### Scenario 5: Cycle bound enforcement

Expected (after five cycles with unresolved findings):

- Run stops at cycle 5
- Remaining findings listed with severity and status
- User asked whether to raise bound with stated new limit
- No further cycles without explicit answer

### Scenario 6: Merge with squash and branch deletion

```sh
/ccd-review-remediate --merge
```

Expected (all six criteria pass):

- Head SHA confirmed matching reviewed SHA
- Multi-select: delete source branch (default yes), squash commits (default yes)
- Merge executed via forge CLI with chosen options
- Remote result verified
- Switched to target branch, fetched, fast-forwarded
- Source branch deleted locally and remotely if selected

### Scenario 7: Stopping conditions

| Condition          | Invocation                                        | Expected stop message                        |
| ------------------ | ------------------------------------------------- | -------------------------------------------- |
| No open CR         | `/ccd-review-remediate` on branch with no CR      | `stopped: no-change-request`                 |
| Multiple open CRs  | `/ccd-review-remediate` on branch with 2+ CRs     | `stopped: ambiguous-cr` with CR list         |
| Dirty working tree | `/ccd-review-remediate --remediate` with changes  | `stopped: dirty-tree` with uncommitted paths |
| Unsupported forge  | `/ccd-review-remediate` with Bitbucket remote     | `stopped: unsupported-forge`                 |
| Missing permission | `/ccd-review-remediate` as read-only collaborator | `skipped: no-permission` for publish/approve |
| Stale head SHA     | `/ccd-review-remediate --merge` after force push  | `stopped: stale-sha`                         |

## Contracts Reference

- Gate decision: [contracts/gate-decision.md](contracts/gate-decision.md)
- Data model: [data-model.md](data-model.md)
- Testability gaps: [research.md](research.md)

## What This Guide Does Not Contain

Implementation code, test suites, migration scripts, service configurations belong in `tasks.md` and implementation phase. This guide validates end-to-end feature behavior once implemented.
<!-- token-budget: compacted (level=medium) on 2026-09-13T09:59:00Z; original at quickstart.full.md -->
