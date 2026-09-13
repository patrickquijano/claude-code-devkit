---
name: ccd-gitlab-mr-review
description: Use when the user wants a GitLab merge request reviewed end-to-end — e.g. "review this MR", "check my merge request", "do a code review on this branch". Not for opening or updating an MR (use ccd-gitlab-mr), and not for GitHub pull requests (use ccd-github-pr).
---

# GitLab MR Review

Performs a thorough code review of the open merge request on the current branch, applying established code review best practices. Validates the environment, ensures the current user is listed as a reviewer, analyzes the diff, asks the user for a pass/fail verdict, and posts the result as a single structured comment on the MR.

## When NOT to use

- User wants to open or update an MR — use `claude-code-devkit:ccd-gitlab-mr` instead.
- Target is a GitHub repository — use `claude-code-devkit:ccd-github-pr` instead.
- User wants to merge, close, or reopen an MR — this skill only reviews and posts comments.

## Asking the user

Questions in this skill follow the repository-wide standard in [`.claude/rules/skill-authoring.md`](../../.claude/rules/skill-authoring.md).

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters.
- **Batch** related questions into one call rather than one call per question.

Bundled `scripts/` and `templates/` paths below are relative to **this SKILL.md's own directory**. Invoke them as `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/<name>.sh"` — quoted variable, explicit `sh`.

## Workflow

### Step 1 — Preflight

Run the preflight script to validate the environment and locate the target MR:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/preflight.sh"
```

The script outputs key-value pairs on stdout: `MR_IID`, `MR_TITLE`, `MR_STATE`, `MR_SOURCE_BRANCH`, `MR_TARGET_BRANCH`, `CURRENT_USER`, `IS_REVIEWER`, `WEB_URL`. Parse these for subsequent steps.

On any failure (exit code ≠ 0), the script prints a user-facing error message to stderr. Display it and stop. Do not attempt recovery.

Display preflight results to the user:

```text
## Preflight
- glab: ✓
- Auth: ✓
- Branch: <source_branch>
- MR: !<iid> — <title>
- Reviewer: <already listed | see Step 2>
```

### Step 2 — Reviewer self-add (conditional)

If `IS_REVIEWER=false` from preflight output, ask the user whether to add themselves as a reviewer:

- Header: `"Reviewer"`
- Options: `Add me (Recommended)` / `Skip`
- `Add me` description: "Adds you as a reviewer on this MR so your review is tracked; uses safe append that preserves existing reviewers."
- `Skip` description: "Proceeds without adding you; your review comment will still post but you won't appear in the reviewer list."

If the user selects `Add me`, run:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/add-reviewer.sh" "<MR_IID>" "<CURRENT_USER>"
```

Report the result. If the script fails, display the error and continue with the review — reviewer addition is non-fatal.

If `IS_REVIEWER=true`, skip this step silently.

### Step 3 — AI review analysis

Read the MR diff and analyze it against established code review best practices.

**Reading the diff:**

```sh
glab mr diff < MR_IID > --color=never
```

**Review dimensions** (from Google engineering practices, research R-002):

1. **Design fit** — does the change belong in the system as designed?
2. **Functionality** — does it do what the author intended, including edge cases?
3. **Complexity** — is it more complex than necessary? Over-engineered for speculative futures?
4. **Tests** — correct, sensible, useful? Clear naming?
5. **Naming** — clear, descriptive, consistent with codebase conventions?
6. **Comments** — explain "why", not "what"? Updated when code changes?
7. **Style guide compliance** — formatting follows project standards?
8. **Documentation** — updated when behavior changes?
9. **System health** — does the change improve overall code health?

**Generating findings:**

For each observation, produce a ReviewFinding with:

- `severity`: `critical` (must fix), `suggestion` (consider), `nit` (minor), or `fyi` (informational)
- `file_path`: relative to repo root, must exist in the diff
- `line_number`: line in the new file (post-image), must exist in the diff
- `description`: what the issue is and why it matters
- `rationale`: the engineering principle behind the finding

**Hard rules:**

- MUST NOT hallucinate content not present in the MR diff or repository artifacts (FR-012).
- MUST NOT make assumptions about code intent or behavior not evidenced in the changes (FR-013).
- MUST NOT scan files outside the project directory (FR-014).
- Only issues with clear, unambiguous evidence in the diff receive `critical` severity. Ambiguous issues get `suggestion` at most.
- Where uncertainty exists, flag it explicitly rather than guessing.

**Empty diff:** If the MR has no changed files, report "No issues found" and proceed to Step 4.

Display findings to the user grouped by severity:

```text
## Review Findings
### Critical (must fix)
- `path/to/file.ext:42` — [finding with rationale]
### Suggestions (consider)
- `path/to/file.ext:15` — Nit: [minor observation]
### Positive observations
- [something done well]
```

### Step 4 — Verdict decision

Ask the user whether the review has passed:

- Header: `"Verdict"`
- Options (recommended first):
  - `Approve (Recommended)` — "Posts an approval comment to the MR; use when findings are minor or absent and the change improves code health."
  - `Request changes` — "Posts a structured summary comment with all findings grouped by severity; use when critical issues must be addressed before merge."
- MultiSelect: false

Each option description states what posting action follows and why, per the repository-wide asking standard.

### Step 5a — Post approval (if verdict = approve)

Render the approval comment template:

```sh
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/templates/approval-comment.md"
```

Populate variables:

- `{{DATE}}`: today's date in YYYY-MM-DD format
- `{{REVIEWER}}`: `CURRENT_USER` from preflight
- `{{SUMMARY}}`: brief positive summary of the review (one to three sentences noting what was reviewed and that no critical issues were found)

Write the rendered content to a temporary file, then post:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/post-comment.sh" "<MR_IID>" "<temp-file-path>"
```

Optional approval gate: ask the user to confirm posting with header `"Post?"`, options `Yes` / `No`. If `No`, stop without posting.

### Step 5b — Post change request (if verdict = request_changes)

Render the review summary template:

```sh
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/templates/review-summary.md"
```

Populate variables:

- `{{VERDICT}}`: `Changes Requested`
- `{{DATE}}`: today's date in YYYY-MM-DD format
- `{{REVIEWER}}`: `CURRENT_USER` from preflight
- `{{FINDINGS_CRITICAL}}`: markdown list of critical findings with `file:line` references
- `{{FINDINGS_SUGGESTION}}`: markdown list of suggestion/nit/fyi findings with `file:line` references
- `{{FINDINGS_POSITIVE}}`: markdown list of positive observations

Write the rendered content to a temporary file, then post:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/post-comment.sh" "<MR_IID>" "<temp-file-path>"
```

This posts a single structured summary comment (FR-016). No individual line-level comments.

### Step 6 — Report result

Display the final outcome:

```text
## Result
[Posted approval | Posted change request | Stopped without posting]
MR: <WEB_URL>
```

## Edge cases

- **MR closed/merged mid-review**: If the MR state changes between preflight and posting, `post-comment.sh` will fail. Display the error and stop. Do not retry.
- **Network failure on post**: `post-comment.sh` exits non-zero with the error. Display it. The rendered comment temp file remains for manual retry.
- **Reviewer add failure**: Non-fatal. Display the error and continue with the review.
- **Empty diff**: Report "No issues found" at Step 3, proceed to verdict. An empty diff can still receive approval.
- **Detached HEAD**: Caught at preflight. Stop with error.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** No skill in this plugin carries it, and none may — the count is a contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`.
