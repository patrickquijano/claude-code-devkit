# Contract: forge commands

**Feature**: 007-forge-review-request-update
**Verified against**: `gh` 2.100.0, `glab` 1.116.0, on 2026-09-05

The exact commands each skill runs for update mode. [update-mode.md](./update-mode.md) is the behaviour; this is how each forge performs it. Reasoning and sources are in [research.md](../research.md).

## Detection

GitHub:

```sh
gh pr list --head "$branch" --state all \
  --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author
```

`--state` defaults to `open`, so it is passed explicitly. `--head` does **not** accept `owner:branch` — the flag's own help says that syntax is unsupported — so a fork's branch is separated from the parent's by filtering `isCrossRepository` and the head owner in the returned JSON, never by qualifying the flag.

GitLab:

```sh
glab mr list --source-branch "$branch" --all --output json
```

`--source-branch` alone returns open merge requests only; `-A`/`--all` widens it, and `-M`/`--closed` narrow to merged or closed where that is wanted. `mr list` searches the current project, or the one `--repo` names.

## Update

GitHub, one call, only the flags whose field actually changes:

```sh
gh pr edit "$number" \
  --title "$title" \
  --body-file "$tmp" \
  --base "$target" \
  --add-reviewer "$login" \
  --add-assignee "$login"
```

`--remove-reviewer` and `--remove-assignee` exist and are used only on an explicit removal. There is **no** flag for the head branch; it cannot be edited.

GitLab, one call:

```sh
glab mr update "$iid" \
  --title "$title" \
  --description-file "$tmp" \
  --target-branch "$target" \
  --reviewer "+$username" \
  --assignee "+$username" \
  --yes
```

**The `+` prefix is not optional.** `glab mr update --reviewer a,b` replaces the entire reviewer set; `+user` adds and `-user` or `!user` removes. The same holds for `--assignee`. This is the difference most likely to be undone by an edit that reads naturally, and C6 of the behaviour contract is what it violates.

Both tools replace the description outright. `--body-file` and `--description-file` are used rather than an inline argument, because a generated description contains backticks and `$` that a double-quoted shell argument would execute.

## Reopen

```sh
gh pr reopen "$number"
glab mr reopen "$iid"
```

Neither works on a merged review request. GitHub treats merge as terminal; GitLab's inability is tracked upstream as `gitlab-org/gitlab#9428`.

## Not used by this feature

Recorded so that a later change does not have to rediscover them, and so that nobody reaches for them here:

- `gh pr ready` / `gh pr ready --undo` — draft state on GitHub. Not an `edit` flag. Outside the five fields.
- `glab mr update --draft` / `--ready` — draft state on GitLab, a first-class attribute rather than a `Draft:` title prefix. Outside the five fields.
- `gh pr merge`, `glab mr merge` — merging. Explicitly a non-goal. Note that `glab mr merge --auto-merge` defaults to **true** while a pipeline is running.
- `glab mr note` — marked EXPERIMENTAL in 1.116.0.

## The MCP fallback, and its inverted trap

`ccd-gitlab-mr` falls back to the GitLab MCP server when `glab` is absent. `save_merge_request` decides create versus update **solely** by whether `merge_request_iid` is present.

- Creating: `merge_request_iid` **omitted**. Passing it turns the create into an edit of an existing merge request.
- Updating: `merge_request_iid` **supplied**. Omitting it opens a second merge request.

The rule is one field in two directions, and each direction fails silently into the other. Verify the result with `get_merge_request` rather than trusting the response, and check the tool name against the session's exposed tools before calling it — that server's surface has changed before.

`ccd-github-pr` has no MCP fallback and gains none. `gh` absent stops the run, as it does today.

## Permissions

- GitHub: the `repo` scope covers creating and editing pull requests, including title, body, base, reviewers and assignees. Only `--add-project`/`--remove-project` needs the extra `project` scope, and projects are outside the five fields.
- GitLab: the `api` scope is not sufficient on its own. Creating or updating a merge request needs the Developer role or above, so a Reporter with a full-scope token is refused. That failure and an insufficient scope look alike from the command line and have different remedies, which is why C11 requires the report to be specific.

## Duplicate rejection, for reference only

Detection is what prevents a duplicate; these are recorded so the messages are recognisable, not to be parsed.

- GitHub: HTTP 422, `A pull request already exists for <owner>:<branch>.`, under the generic `custom` error code. Two open pull requests with the same head and **different** bases are legal.
- GitLab: HTTP 409, `Cannot Create: This merge request already exists`. One open merge request per source-and-target pair.
