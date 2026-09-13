# Quickstart: GitLab MR Review Skill Validation

**Feature**: 015-ccd-gitlab-mr-review
**Date**: 2026-09-13
**Source**: [spec.md](spec.md), [contracts/skill-interface.md](contracts/skill-interface.md)

## Prerequisites

- `glab` CLI installed and authenticated (`glab auth status` passes)
- Current directory is inside a git repository with a GitLab remote
- Current branch has an open merge request on GitLab
- Claude Code session with this plugin installed

## Validation Scenario 1: Happy Path — Approve

**Goal**: Verify the skill completes a full review cycle and posts an approval comment.

1. Check out a feature branch with an open MR where you are already a reviewer.
2. Invoke `claude-code-devkit:ccd-gitlab-mr-review`.
3. Confirm preflight output shows all checks passing and your username listed as reviewer.
4. Wait for AI analysis to complete and findings to display.
5. Select the approval option at the verdict prompt.
6. Confirm the approval gate prompt appears; select `Yes`.
7. Verify on GitLab that an approval comment was posted to the MR.

**Expected outcome**: MR has a new approval comment; no source files modified locally.

## Validation Scenario 2: Happy Path — Request Changes

**Goal**: Verify the skill posts a structured summary comment when changes are requested.

1. Check out a feature branch with an open MR containing known issues.
2. Invoke `claude-code-devkit:ccd-gitlab-mr-review`.
3. Confirm preflight passes.
4. Wait for AI analysis; confirm findings are displayed with severity labels and line references.
5. Select the request-changes option at the verdict prompt.
6. Verify on GitLab that a single structured summary comment was posted, grouped by severity.

**Expected outcome**: MR has one new comment with critical/suggestion/positive sections; no individual line comments.

## Validation Scenario 3: Self-Add as Reviewer

**Goal**: Verify the skill adds the current user as reviewer when not already listed.

1. Check out a feature branch with an open MR where you are NOT a reviewer.
2. Invoke `claude-code-devkit:ccd-gitlab-mr-review`.
3. At the "Reviewer" prompt, select `Add me (Recommended)`.
4. Confirm preflight output shows "Reviewer: added".
5. Continue through review and post a verdict.
6. Verify on GitLab that your username now appears in the MR reviewers list.

**Expected outcome**: User added as reviewer via `+` prefix; existing reviewers preserved.

## Validation Scenario 4: Preflight Failures

**Goal**: Verify each preflight failure mode stops cleanly with a clear message.

| Failure              | Setup                            | Expected Message                              |
| -------------------- | -------------------------------- | --------------------------------------------- |
| Not a git repo       | Run from `/tmp`                  | "Not inside a git repository"                 |
| glab missing         | Rename `glab` binary temporarily | "glab CLI not found"                          |
| glab unauthenticated | Run `glab auth logout` first     | "glab not authenticated"                      |
| No open MR           | Check out a branch with no MR    | "No open merge request for branch \<branch\>" |

**Expected outcome**: Each failure stops before any review work begins; no partial state left behind.

## Validation Scenario 5: Empty Diff

**Goal**: Verify the skill handles an MR with no changes gracefully.

1. Create or find an MR with zero changed files.
2. Invoke the skill.
3. Confirm AI analysis reports "No issues found" or equivalent.
4. Proceed to verdict and post.

**Expected outcome**: Skill completes without error; posted comment reflects no findings.

## What This Guide Does NOT Cover

- Full implementation code or script bodies — those live in `tasks.md` and the implementation phase.
- Test suites or automated test commands — this skill is validated manually against live GitLab MRs.
- Migration or setup of `glab` itself — see [glab documentation](https://gitlab.com/gitlab-org/cli).
