# GitHub CLI Reference

Verified `gh` commands for review, publish, and merge operations. All syntax confirmed via `gh --help` on 2026-09-13.

## View PR

```sh
gh pr view [ --json author,assignees,reviewers,headRefOid,statusCheckRollup,mergeable,reviews,comments < number > ]
```

Returns JSON with all fields needed for ChangeRequest entity per data-model.md.

## Diff

```sh
gh pr diff [ < number > ]
```

Returns unified diff content. Empty output means branches have converged.

## Review (verdict)

```sh
# Approve
gh pr review [ --approve --body "<summary>" < number > ]

# Request changes
gh pr review [ --request-changes --body "<findings>" < number > ]

# Comment only (no verdict)
gh pr review [ --comment --body "<text>" < number > ]
```

Use `--body-file -` to read body from stdin for large payloads.

## Inline comment

No CLI shorthand; use REST API:

```sh
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f path=<file> \
  -f line=<line> \
  -f body=<text>
```

For multi-line comments on a range, add `-f start_line=<line>` and `-f start_side=LEFT|RIGHT`.

## List PRs for branch

```sh
gh pr list --head number,title,author < branch > --json
```

Returns array; empty array means no open PR for that branch.

## Merge

```sh
gh pr merge [ --squash --delete-branch < number > ]
```

Flags: `--merge`, `--rebase`, `--squash` (mutually exclusive). `--delete-branch` removes remote branch after merge. Always verify with `gh pr view` after merge.

## Assign and reviewers

```sh
gh pr edit [<number>] --add-assignee <user>
gh pr edit [<number>] --add-reviewer <user>
```

## Permission probe

```sh
gh api repos/{owner}/{repo}/collaborators/{user}/permission --jq '.permission'
```

Returns `admin`, `write`, `read`, or `none`. Used by permission-check.sh.

## Auth status

```sh
gh auth status --show-token
```

Exit 0 = authenticated. Non-zero = unauthenticated or token expired.

## Exit codes

- 0: success
- 1: general error
- 4: authentication failure
- 22: resource not found

Always check exit code AND output; some commands return 0 with empty results when the resource exists but has no matching data.
