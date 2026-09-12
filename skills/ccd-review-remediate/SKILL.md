---
name: ccd-review-remediate
description: Use when the user wants a GitHub PR or GitLab MR reviewed, remediated, re-reviewed, or merged — e.g. "review this PR", "fix what the review found", "re-review after fixes", "merge this MR". Not for opening or updating change requests (use ccd-github-pr or ccd-gitlab-mr), and not for pipeline failures (use ccd-pipeline-fix).
---

# Change-Request Review and Remediation

Reviews the current branch's open change request, publishes evidence-backed findings, remediates when explicitly authorized, re-reviews up to five cycles, and optionally merges. Every action is gated; nothing changes without explicit permission.

## When NOT to use

- Opening or updating a PR/MR → `claude-code-devkit:ccd-github-pr` or `claude-code-devkit:ccd-gitlab-mr`
- Diagnosing a failed CI pipeline → `claude-code-devkit:ccd-pipeline-fix`
- Pushing a branch with no change request → `claude-code-devkit:ccd-branch-push`

## Three standing rules

**Forge is decided once.** `forge-detect.sh` runs at Step 0 and the verdict is stored. Never re-detected, never inferred from argument wording or log content.

**No action without explicit authorization.** Review runs read-only by default. Remediation requires `--remediate`. Merge requires `--merge`. Preview mode (`--dry-run`) suppresses all external state changes.

**Findings cite evidence.** Every finding quotes the diff, config, test, or requirement it rests on. A finding without evidence is not published.

## Scripts

Invoke as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"`. Shared scripts reached via `${CLAUDE_PLUGIN_ROOT}`.

| Script                                                                 | Prints                                                          |
| ---------------------------------------------------------------------- | --------------------------------------------------------------- |
| `${CLAUDE_SKILL_DIR}/scripts/preflight.sh`                             | forge, CLI auth, CR ID, head_sha, dirty-tree verdict            |
| `${CLAUDE_SKILL_DIR}/scripts/collect-context.sh`                       | diff, comments, discussions, approvals, CI status, mergeability |
| `${CLAUDE_SKILL_DIR}/scripts/verify-repository.sh`                     | validation command chosen, exit code, output excerpt            |
| `${CLAUDE_SKILL_DIR}/scripts/permission-check.sh`                      | write/admin/skip verdict for authenticated user                 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh` | forge, CLI, review_skill, ready/skip verdict                    |

Read the `verdict` line, never the exit status. `exit 0` means the check ran.

## Reference map

| File                            | Covers                                                |
| ------------------------------- | ----------------------------------------------------- |
| `reference/review-checklist.md` | Eleven review dimensions with guidance                |
| `reference/severity-model.md`   | Six severities, three confidences, blocking rules     |
| `reference/validation.md`       | Validation-command precedence, override protocol      |
| `reference/github.md`           | Verified `gh` CLI commands for review/publish/merge   |
| `reference/gitlab.md`           | Verified `glab` CLI commands for review/publish/merge |

## Templates

| File                               | Purpose                    |
| ---------------------------------- | -------------------------- |
| `templates/review-findings.md`     | Finding output format      |
| `templates/approval-summary.md`    | Pass verdict summary       |
| `templates/remediation-summary.md` | Fix mapping per finding ID |

## Step 0 — Preflight

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"
```

Record: `forge`, `cli_status`, `cr_id`, `head_sha`, `dirty_tree`.

Gate G1–G3 from `contracts/gate-decision.md`: stop on unsupported-forge, no-change-request, ambiguous-cr, or dirty-tree with stated reason. Never proceed past a failed gate.

## Step 1 — Context Collection

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/collect-context.sh"
```

Populate ChangeRequest entity fields per `data-model.md`. Detect self-author (FR-047). Cache permission probe result via `permission-check.sh` (CHK010).

## Step 2 — Review

Read diff against `reference/review-checklist.md` dimensions. Classify findings per `reference/severity-model.md`. Deduplicate against existing comments (FR-012). Produce Finding entities with all required fields per `data-model.md`.

## Step 3 — Verdict Evaluation

Evaluate six G6 criteria from `contracts/gate-decision.md`. Produce ReviewVerdict with per-criterion CriterionStatus. Handle override per FR-048. Never report unchecked criterion as satisfied (SC-012).

## Step 4 — Publish

Permission pre-check (G4). Self-author comment-only path (G5/FR-047). Dispatch approve/request-changes/comment via forge-specific reference. Write audit entry per CHK011. Suppress all external actions in preview mode (FR-041).

## Step 5 — Remediation (requires `--remediate`)

Authorization gate (G8). Prioritize findings by severity. Present plan before any code change. Apply minimal root-cause fixes (FR-023). Add/update regression tests (FR-024). Run targeted checks then full validation (FR-025). Inspect final diff for unintended changes and credentials (CHK004/FR-027). Commit per repo convention (FR-028). Publish remediation-summary.md mapping. On mid-cycle failure, leave working tree as-is and record partial state (CHK008).

## Step 6 — Re-review and Merge (requires `--merge`)

Re-review updated diff against target branch. Verify previous findings resolved. Detect regressions (FR-032). Cycle bound enforcement at 5 (G7/FR-034). Merge authorization gate (G9): all G6 criteria must pass, head SHA must match reviewed SHA. Multi-select question for delete-source-branch and squash-commits. Invoke forge CLI merge. Verify remote result. Switch to target branch, fetch, fast-forward only (FR-039).

## Stopping conditions

Every stop from `contracts/gate-decision.md` closed outcome vocabulary produces a stated reason. Never guesses or partially acts (SC-010).

## Red flags

| Rationalization                                        | Correction                                                                                         |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| "The log mentions github.com, so use gh"               | Forge came from remote at Step 0. Log content says nothing about where this repository lives.      |
| "No CLI, so this run cannot proceed"                   | Missing CLI is a reported skip of retrieval path, not a failure. Ask for output and continue.      |
| "Only one finding looks relevant, so skip dedup"       | Dedup checks all existing comments. Skipping produces duplicate findings.                          |
| "Validation failed but the fix looks right"            | Never claim success when validation failed (FR-029). Report failure with output.                   |
| "This needs a new config option, but it is only small" | Change adding or altering a requirement is feature work. Stop and name `/ccd-speckit-run`.         |
| "Reviewer is the author but findings are minor"        | Self-author always gets comment-only output, no verdict (FR-047). Severity does not override this. |

## Authoring note

Do not hard-wrap long lines when editing this skill or its reference files. One line per paragraph, bullet or table row, however long. Script bodies are code — never compress them. After editing, re-run `evaluations.md`.

Never add `disable-model-invocation` to this skill. Zero of the eight in this plugin carry it, and that is a committed contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`.

Never add `user-invocable`. Its absence is what leaves the skill invocable; `false` would hide it from the `/` menu.

Keep the forge in one place. `forge-detect.sh` decides it, Step 0 records it, references read it. A second detection gives the run two answers that can disagree.
