# Contract: ccd-gitlab-mr-review Skill Interface

**Feature**: 015-ccd-gitlab-mr-review
**Date**: 2026-09-13
**Source**: [spec.md](../spec.md), [research.md](../research.md), [data-model.md](../data-model.md)

## Invocation Contract

The skill is invoked as `claude-code-devkit:ccd-gitlab-mr-review` with no arguments. All context is derived from the current working directory and its git state.

### Preconditions

| Precondition                                | Verification Method                                   | Failure Behavior                                                     |
| ------------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------- |
| Current directory is inside a git work tree | `git rev-parse --is-inside-work-tree`                 | Stop with error: "Not inside a git repository"                       |
| `glab` CLI is installed and on PATH         | `command -v glab`                                     | Stop with error: "glab CLI not found"                                |
| `glab` is authenticated                     | `glab auth status`                                    | Stop with error: "glab not authenticated; run `glab auth login`"     |
| Current branch has an open MR               | `glab mr list --source-branch <branch> --output json` | Stop with message: "No open merge request found for branch <branch>" |

### Postconditions

| Postcondition                                           | Verification Method                                                      |
| ------------------------------------------------------- | ------------------------------------------------------------------------ |
| If user approved: approval comment posted to MR         | `glab mr view <iid> --comments --output json` contains approval note     |
| If user requested changes: summary comment posted to MR | `glab mr view <iid> --comments --output json` contains review summary    |
| Current user is listed as reviewer on MR                | `glab mr view <iid> --output json` reviewers array contains current user |
| No source code files modified                           | `git diff --name-only` shows no changes to tracked files outside specs/  |

## User Interaction Contract

### AskUserQuestion Calls

The skill makes exactly two `AskUserQuestion` calls in the happy path:

1. **Review Verdict** (after AI analysis completes)
   - Header: `"Verdict"`
   - Options: 2–4, first option recommended with `(Recommended)` suffix
   - Each option description states what posting action follows and why
   - MultiSelect: false

2. **Approval Gate** (only when review verdict is approve)
   - Header: `"Post?"`
   - Options: `Yes` / `No`
   - Yes posts the approval comment; No stops without posting
   - MultiSelect: false

A third call occurs only when the current user is not already a reviewer:

3. **Add Self as Reviewer** (preflight, conditional)
   - Header: `"Reviewer"`
   - Options: `Add me (Recommended)` / `Skip`
   - Add me runs `glab mr update <iid> --reviewer '+<username>'`; Skip proceeds without adding
   - MultiSelect: false

### Output Format

All user-facing output follows this structure:

```text
## Preflight
- glab: ✓
- Auth: ✓
- Branch: <branch-name>
- MR: !<iid> — <title>
- Reviewer: <already listed | added | skipped>

## Review Findings
[structured findings table or "No issues found"]

## Verdict Decision
[AskUserQuestion rendered by harness]

## Result
[Posted approval | Posted change request | Stopped without posting]
MR: <web_url>
```

## Script Interface Contract

Scripts live in `skills/ccd-gitlab-mr-review/scripts/` and are invoked as `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/<name>.sh"`.

### preflight.sh

**Purpose**: Validate environment and locate the target MR.

**Input**: None (reads git state and glab config from environment).

**Output** (stdout, POSIX-compliant): Exit 0 on success, exit 1 on any failure. On success, prints key-value pairs:

```text
MR_IID=<integer>
MR_TITLE=<string>
MR_STATE=<opened|closed|merged>
MR_SOURCE_BRANCH=<string>
MR_TARGET_BRANCH=<string>
CURRENT_USER=<string>
IS_REVIEWER=<true|false>
WEB_URL=<string>
```

On failure, prints a single error line to stderr and exits non-zero.

### post-comment.sh

**Purpose**: Post a structured review comment to the MR.

**Input**: Two positional arguments: `<mr-iid>` `<comment-file-path>`. The comment file contains the rendered markdown body.

**Output**: Exit 0 on success, exit 1 on failure. Prints the created note's ID to stdout on success.

**Safety**: Uses `$(cat "$2")` pattern to avoid shell expansion of backticks and `$` in the comment body. Never passes comment content as an inline double-quoted argument.

### add-reviewer.sh

**Purpose**: Add the current user as a reviewer without removing existing reviewers.

**Input**: Two positional arguments: `<mr-iid>` `<username>`.

**Output**: Exit 0 on success, exit 1 on failure. Prints confirmation to stdout.

**Safety**: Always uses `+<username>` prefix. Reads current reviewer list before modifying to verify no accidental removal.

## Template Interface Contract

Templates live in `skills/ccd-gitlab-mr-review/templates/`.

### review-summary.md

**Purpose**: Render the change-request summary comment.

**Variables** (passed via environment or sed substitution):

| Variable                  | Source          | Example                |
| ------------------------- | --------------- | ---------------------- |
| `{{VERDICT}}`             | User decision   | `Changes Requested`    |
| `{{DATE}}`                | System clock    | `2026-09-13`           |
| `{{FINDINGS_CRITICAL}}`   | AI analysis     | Rendered markdown list |
| `{{FINDINGS_SUGGESTION}}` | AI analysis     | Rendered markdown list |
| `{{FINDINGS_POSITIVE}}`   | AI analysis     | Rendered markdown list |
| `{{REVIEWER}}`            | `glab api user` | `username`             |

### approval-comment.md

**Purpose**: Render the approval comment.

**Variables**:

| Variable       | Source          | Example                |
| -------------- | --------------- | ---------------------- |
| `{{DATE}}`     | System clock    | `2026-09-13`           |
| `{{REVIEWER}}` | `glab api user` | `username`             |
| `{{SUMMARY}}`  | AI analysis     | Brief positive summary |

## Error Handling Contract

| Error Condition             | User-Facing Message                                                   | Recovery                   |
| --------------------------- | --------------------------------------------------------------------- | -------------------------- |
| glab not installed          | "glab CLI not found. Install it: <https://gitlab.com/gitlab-org/cli>" | None; stop                 |
| glab not authenticated      | "glab not authenticated. Run `glab auth login`"                       | None; stop                 |
| No open MR on branch        | "No open merge request for branch <branch>"                           | None; stop                 |
| MR closed/merged mid-review | "MR !<iid> was <state> during review. Stopping."                      | None; stop                 |
| Network failure on post     | "Failed to post comment: <error>. Comment saved to <temp-file>"       | User can retry manually    |
| Reviewer add fails          | "Could not add reviewer: <error>. Continuing review."                 | Non-fatal; review proceeds |

## Invariants

1. The skill never modifies source code, git history, or MR metadata (title, description, branch, labels).
2. Every finding references a file and line present in the MR diff. No speculative findings.
3. The `+` prefix is always used when adding reviewers via `glab mr update`.
4. Comment bodies are passed via file, never inline, to prevent shell expansion.
5. The skill makes no API calls beyond those documented in this contract.
6. All scripts are POSIX sh compliant and fail fast (`set -e`).
