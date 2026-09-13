# Evaluations: ccd-gitlab-mr-review

Regression scenarios for the GitLab MR review skill. Run these after editing SKILL.md, scripts, or templates to verify no regressions.

## Preflight Failures

| Scenario               | Setup                               | Expected Behavior                                                             |
| ---------------------- | ----------------------------------- | ----------------------------------------------------------------------------- |
| No glab installed      | Remove glab from PATH               | Script exits 1 with "glab CLI not found" message; skill stops                 |
| glab not authenticated | Run `glab auth logout` first        | Script exits 1 with "glab not authenticated" message; skill stops             |
| No open MR on branch   | Check out branch without MR         | Script exits 1 with "No open merge request for branch X" message; skill stops |
| Not a git repo         | Run from `/tmp` or non-repo dir     | Script exits 1 with "Not inside a git repository" message; skill stops        |
| Detached HEAD          | `git checkout --detach`             | Script exits 1 with "Detached HEAD state" message; skill stops                |
| MR closed mid-review   | Close MR between preflight and post | `post-comment.sh` fails; error displayed; skill stops                         |

## Reviewer Self-Add

| Scenario              | Setup                              | Expected Behavior                                                                                           |
| --------------------- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| User already reviewer | MR has current user as reviewer    | Step 2 skipped silently; no AskUserQuestion call                                                            |
| User not reviewer     | MR does not list current user      | AskUserQuestion with "Add me (Recommended)" / "Skip"; selecting Add me runs add-reviewer.sh with `+` prefix |
| Reviewer add fails    | Network error or permission denied | Error displayed; review continues (non-fatal)                                                               |
| Reviewer add succeeds | Normal case                        | Confirmation shown; existing reviewers preserved                                                            |

## Verdict Workflows

| Scenario                | Setup                                  | Expected Behavior                                                                                      |
| ----------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Approve verdict         | User selects Approve at verdict prompt | Approval comment rendered from template and posted via post-comment.sh                                 |
| Request changes verdict | User selects Request changes           | Summary comment rendered with severity-grouped findings and posted                                     |
| Empty diff              | MR with zero changed files             | "No issues found" reported at Step 3; verdict still offered; approval or change request posts normally |
| Post fails (network)    | Simulate network failure               | post-comment.sh exits 1; error displayed; temp file remains for manual retry                           |

## Template Rendering

| Scenario                              | Expected Behavior                                                             |
| ------------------------------------- | ----------------------------------------------------------------------------- |
| Approval template variables populated | `{{DATE}}`, `{{REVIEWER}}`, `{{SUMMARY}}` replaced correctly                  |
| Review summary variables populated    | All six variables replaced; findings grouped by severity with line references |
| Shell expansion safety                | Comment body containing backticks and `$` passed safely via `$(cat)` pattern  |

## Output Format

| Scenario                           | Expected Behavior                                                    |
| ---------------------------------- | -------------------------------------------------------------------- |
| Structured output sections present | Preflight, Review Findings, Verdict Decision, Result all displayed   |
| Only necessary output shown        | No verbose logs, no internal state dumps, no redundant confirmations |
| MR URL included in result          | Final output includes clickable web_url from preflight               |

## Anti-Patterns (must NOT happen)

- Individual line-level comments posted instead of single summary (FR-016 violation)
- Reviewer added without `+` prefix (replaces entire reviewer list)
- Comment body passed inline to `-m` flag (shell expansion risk)
- Skill scans files outside project directory (FR-014 violation)
- Findings reference lines not in the diff (FR-012 hallucination)
- Assumptions about code intent not evidenced in changes (FR-013 violation)
- `disable-model-invocation` added to frontmatter (breaks dispatch contract)
