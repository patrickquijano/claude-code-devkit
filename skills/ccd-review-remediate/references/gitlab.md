# GitLab CLI Reference

Verified `glab` commands for review, publish, and merge operations. All syntax confirmed via `glab --help` on 2026-09-13.

## View MR

```sh
glab mr view [ < id > ]
```

Text output; parse author, assignees, reviewers, pipeline status from formatted text. For structured data, use `glab api projects/{id}/merge_requests/{mr_iid}`.

## Diff

```sh
glab mr diff [ < id > ]
```

Returns unified diff content. Empty output means branches have converged.

## Approve

```sh
glab mr approve [ < id > ]
```

No body parameter; approval is binary. Revoke with `glab mr revoke [<id>]`.

## Comment

```sh
# Top-level comment
glab mr note create [<id>] --message "<text>"

# Inline discussion on a diff line
glab mr note create [<id>] --message "<text>" --path <file> --line <line>
```

Creates a new discussion thread. To reply to an existing thread, use `glab mr note create [<id>] --message "<text>" --discussion-id <did>`.

## Resolve discussion

```sh
glab mr note resolve [<id>] --discussion-id <did>
```

Marks a discussion thread as resolved. Unresolve with `glab mr note unresolve`.

## List MRs for branch

```sh
glab mr list --source-branch <branch>
```

Returns formatted list; parse MR IID from first column. Empty output means no open MR for that branch.

## Merge

```sh
glab mr merge [ --squash --delete-source-branch < id > ]
```

Flags: `--merge`, `--rebase`, `--squash` (mutually exclusive). `--delete-source-branch` removes remote branch after merge. Always verify with `glab mr view` after merge.

## Update assignee

```sh
glab mr update [<id>] --assignee <user>
```

## Permission probe

```sh
glab api projects/{project_id}/members/all/{user} --jq '.access_level'
```

Returns numeric access level: 10=Guest, 20=Reporter, 30=Developer, 40=Maintainer, 50=Owner. Used by permission-check.sh.

## Auth status

```sh
glab auth status
```

Exit 0 = authenticated. Non-zero = unauthenticated or token expired.

## Exit codes

- 0: success
- 1: general error
- 4: authentication failure

Always check exit code AND output; some commands return 0 with empty results when the resource exists but has no matching data.
