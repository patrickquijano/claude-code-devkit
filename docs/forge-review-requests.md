# Forge review requests: GitHub pull requests, GitLab merge requests, and their CLIs

What `gh` and `glab` actually do, written down so a change to `ccd-github-pr` or `ccd-gitlab-mr` can be checked against something rather than re-derived from a browser.

**Verified against `gh` 2.100.0 (released 2026-09-03) and `glab` 1.116.0**, both installed and authenticated, on 2026-09-05. Every claim below holds for those versions. Where a claim is version-sensitive it says so where it is made. Sources are listed at the end and cited inline where a specific page settles a point.

A note on vocabulary. GitHub calls it a **pull request**, GitLab a **merge request**. Where a statement is true of both, this document says **review request**; where the forges differ, it names them. The two skills use each forge's own word in everything a user reads.

## Contents

- The one difference most likely to break something
- Finding an existing review request
- Identity: whose branch is this
- Updating: the two commands
- The description is replaced, never merged
- Draft state
- Reopening, and what merging forecloses
- What each server does with a duplicate
- Permissions, scopes and roles
- Rewriting a branch that is under review
- The GitLab MCP fallback and its inverted flag
- Scripting: output, exit codes, environment
- Recorded gaps
- Sources

## The one difference most likely to break something

**`glab` replaces the reviewer set by default. `gh` does not.**

`gh pr edit` has separate `--add-reviewer` and `--remove-reviewer` flags, so adding is additive by construction and there is no way to strip reviewers by accident.

`glab mr update --reviewer alice,bob` **replaces the entire reviewer set** with those two. To add, each username takes a `+` prefix; to remove, a `-` or `!` prefix:

```sh
glab mr update 42 --reviewer '+carol' # adds carol, keeps everyone else
glab mr update 42 --reviewer 'carol'  # carol is now the ONLY reviewer
glab mr update 42 --reviewer '-carol' # removes carol, keeps everyone else
```

`--assignee` behaves the same way, and `--unassign` clears assignees outright.

This is the difference to state twice rather than once. An instruction written naturally — "add the reviewer the user picked" — is correct on GitHub and silently destroys the existing reviewer list on GitLab, on a command that reports success. Any shared phrasing covering both forges is wrong for one of them.

**In this repository.** It is why `ccd-github-pr` and `ccd-gitlab-mr` are two skills rather than one with a forge switch, and why feature 007's plan rejected a shared detection script: an abstraction over this difference has to carry it rather than hide it. `ccd-gitlab-mr`'s Step 4 states the prefix rule with the consequence named, its Step 9 passes `+` on every username, and `skills/ccd-gitlab-mr/evaluations.md` E6 is the scenario to walk first after any edit that touches both skills in one pass.

## Finding an existing review request

Both CLIs list by source branch, and **both default to open only**.

GitHub:

```sh
gh pr list --head "$branch" --state all \
  --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author
```

`gh pr list --help`: "By default, this only lists open PRs." `--state` takes `open`, `closed`, `merged` or `all`.

GitLab:

```sh
glab mr list --source-branch "$branch" --all --output json
```

`--source-branch`/`-s` filters by source branch. `-A`/`--all` covers every state; `-M`/`--merged` and `-c`/`--closed` narrow instead. `--output json` is the scriptable form, and `--jq` filters it.

Both `gh pr view` and `glab mr view` with no argument resolve to the current branch's review request, which is shorter and wrong for this purpose: each resolves to exactly one, and cannot express "there are three".

Zero matches is not an error on either. `gh pr list` exits 0 with empty output.

**In this repository.** Both skills already ran a narrower form of this call at their Step 1, to stop when a review request existed. Feature 007 widened the state filter and turned the result into a mode rather than a stop, so the call site is the same one and no new dependency was added. The widening flag is the whole difference, and it is invisible in the common case — a branch whose only review request is open behaves identically with or without it, which is why `evaluations.md` E2 checks the command that was issued rather than only the outcome.

## Identity: whose branch is this

A review request belongs to this branch only when its head is this branch **in this repository**. A branch name is not an identity — forks routinely carry a branch with the same name as the parent's.

**GitHub**: `gh pr list --head` does **not** accept the qualified `owner:branch` form. Its own flag help says so verbatim: `Filter by head branch ("<owner>:<branch>" syntax not supported)`. This is a trap worth knowing about because the REST API it wraps _does_ accept `user:ref-name` on its `head` parameter, so the qualified form looks like it ought to work. Filter the returned JSON on `isCrossRepository` and the head repository's owner instead.

**GitLab**: `glab mr list` searches the current project, or the one `--repo` names — never across forks automatically. An MR opened from a fork still appears in the target project's list, so a match must be checked against its source project rather than accepted on a source-branch name match.

**Neither forge lets the head branch be changed after creation.** `gh pr edit` has no flag for it and `glab mr update` has no equivalent. A review request whose head is a different branch is therefore not this branch's, permanently, and is not something to correct by editing.

**In this repository.** Both skills call this admissibility, and both apply it before any candidate reaches a question. `ccd-github-pr` filters `isCrossRepository` and the head owner; `ccd-gitlab-mr` checks the source project, because a merge request opened from a fork into this project appears in this project's own listing. Neither skill has ever switched branch or acted on another working tree, and admissibility is the same rule applied to the forge's side of that boundary.

## Updating: the two commands

GitHub, one call, passing only the flags whose field actually changed:

```sh
gh pr edit 42 \
  --title 'feat(api): add pagination' \
  --body-file "$tmp" \
  --base main \
  --add-reviewer alice \
  --add-assignee bob
```

Full surface: `--title`, `--body`, `--body-file`, `--base`, `--add-assignee`, `--remove-assignee`, `--add-reviewer`, `--remove-reviewer`, `--add-label`, `--remove-label`, `--add-project`, `--remove-project`, `--milestone`, `--remove-milestone`. Re-adding a reviewer who is already requested is the documented way to re-request a review; `gh pr edit --help` shows exactly that under "Re-request review".

GitLab, one call:

```sh
glab mr update 42 \
  --title 'feat(api): add pagination' \
  --description-file "$tmp" \
  --target-branch main \
  --reviewer '+alice' \
  --assignee '+bob' \
  --yes
```

Full surface: `--title`, `--description`, `--description-file`, `--target-branch`, `--assignee`, `--reviewer`, `--unassign`, `--label`, `--unlabel`, `--milestone`, `--draft`/`--wip`, `--ready`, `--lock-discussion`, `--unlock-discussion`, `--remove-source-branch`, `--squash-before-merge`, `--fill`, `--yes`.

Use the file-taking flag rather than an inline argument in both cases. A generated description contains backticks and `$`, and a double-quoted shell argument runs them as command substitution.

**In this repository.** Both skills pass **only** the flags whose field actually changed, and both restrict what may change to five fields: title, description, target branch, reviewers, assignees. `glab mr update` offers flags for draft state, squash, delete-source-branch, labels and milestone, and the skill deliberately passes none of them — the flag existing is not a reason to pass it. The file-taking flag rule is older than feature 007: both skills already used it on their create path, for the same quoting reason.

## The description is replaced, never merged

Neither tool appends. `gh pr edit --body`/`--body-file` sets the body; `glab mr update --description`/`--description-file` sets the description. There is no append mode on either CLI and no merge on either server.

That matters more than it sounds. A review request description holds whatever a person put there — a note a reviewer asked for, and checklist items that reviewers tick as they go. Checkbox state lives in the description text on both forges. Regenerating and writing destroys all of it, silently, on a call that succeeds.

The practice that follows: read the live description first, diff it against what you would write, and default to leaving it alone. Where a section must be machine-maintained, fence it in HTML comments naming the writer — both forges render Markdown, so the markers are invisible to readers, and the pair gives an exact region to replace. Treat anything other than exactly one well-formed pair as "region not found" and append a fresh one, rather than guessing at a boundary and deleting text you did not write.

Adding a comment is a different operation and does not touch the description: `gh pr comment` and `glab mr note` (the latter marked EXPERIMENTAL in 1.116.0).

**In this repository.** This is the only irreversible thing either skill can do, which is why the specification for feature 007 ranks it alongside the feature's main purpose rather than below it. Both skills read the live description at Step 7, show the difference, and default to leaving it alone; the fences are `<!-- ccd-github-pr:begin -->` and `<!-- ccd-gitlab-mr:begin -->` with matching `:end` markers. A blanket skip-approval phrase in the user's invocation does not reach that question when the description is non-empty — the one place in either skill where an explicit instruction to stop asking is deliberately not honoured.

## Draft state

Not an edit field on either forge, and reached differently on each.

- GitHub: `gh pr ready` marks a pull request ready; `gh pr ready --undo` converts it back to draft. There is no `gh pr edit` flag for it.
- GitLab: `glab mr update --draft` (or `--wip`) and `--ready`. Draft is a first-class attribute of the merge request, not the `Draft:` title prefix — the prefix historically toggled it in the web UI and is not the authority.

Draft state matters for more than presentation on GitHub: a draft pull request does not trigger the CODEOWNERS auto-request, and it cannot auto-merge.

**In this repository.** Both skills ask about draft state when creating and neither touches it when updating — it is outside the five fields. `ccd-github-pr` therefore drops its whole `PR opts` question in update mode, and `ccd-gitlab-mr` drops `Merge opts`: a question whose answer the run cannot act on implies a change that will not happen, which is worse than not asking.

## Reopening, and what merging forecloses

- `gh pr reopen <number>` reopens a closed pull request and takes an optional `--comment`.
- `glab mr reopen <iid>...` reopens one or more closed merge requests.

**Neither works on a merged review request.** GitHub treats merge as terminal. GitLab's inability to reopen a merged merge request is long-standing and still open upstream as `gitlab-org/gitlab#9428` (also filed as #26372 and #61482) — it is reported behaviour rather than documented design, which is worth knowing if the error text ever changes.

Both forges allow a **new** review request from a branch whose previous one was merged. That is the only route once merge has happened.

**In this repository.** Both skills offer the reopen and never take it silently: a closed review request produces a question with reopen recommended, because reopening keeps the review history a fresh one abandons. A merged one produces a statement rather than a question, since there is nothing left to choose. Both say the merged review request exists rather than passing over it — a branch whose review request was already merged usually should have been deleted or restarted.

## What each server does with a duplicate

Detect first; do not rely on the rejection. By the time a create call fails you have already generated a title and a description and asked the user several questions.

- GitHub: HTTP 422, message `A pull request already exists for <owner>:<branch>.`, under the generic `custom` error code — not a distinct machine-readable code.
- GitLab: HTTP 409, message `Cannot Create: This merge request already exists`.

The scoping differs and it matters:

- GitHub forbids two open pull requests with the same head **and base**. Two open pull requests from one branch to two different bases are legal.
- GitLab permits one open merge request per source-and-target pair, which is the same rule, and therefore also permits two open merge requests from one branch to two different targets.

So "several open review requests for one branch" is a real state on both forges, not a theoretical one.

**In this repository.** Neither skill parses these messages. Detection at Step 1 is what prevents the duplicate, and it runs before a title, a description, or four questions have been paid for. The scoping matters more than the wording: because both forges scope the rule to a source-and-target pair, one branch can legitimately carry two open review requests aimed at different targets, which is why both skills list the candidates and ask rather than assuming there is one.

## Permissions, scopes and roles

**GitHub** is scope-based. The `repo` scope grants read and write on repository content and covers creating and editing pull requests, including title, body, base, reviewers, assignees, labels and milestones. `public_repo` is the public-only equivalent. One exception is called out in `gh pr edit --help`: editing a pull request's **projects** requires the `project` scope, added with `gh auth refresh -s project`.

Separately from scope, a user with only `READ` permission on the base repository cannot set assignees, labels or milestones — GitHub rejects those from a user without triage or write access, and `gh pr create` fails the whole call rather than dropping the field.

**GitLab** is scope **and** role. The `api` scope grants full API access, but creating or updating a merge request additionally requires the **Developer** role or above; merging requires Maintainer. A Reporter holding a full-scope token is refused. The two failures look alike from the command line and have different remedies, so report which one it was.

`gh auth status` exits 1 when any host has an authentication problem — except with `--json`, where it always exits 0. `glab auth status` checks the host resolved from the git remote, `GITLAB_HOST`, or `glab config`, in that order; `--all` checks every configured instance.

**In this repository.** Both skills probe their CLI's authentication before any other call to that CLI, so an unauthenticated tool fails as itself rather than as a confusing error from the first real command. Feature 007 added one requirement on top: a user who can create but cannot edit the existing review request is told exactly that, and the skill does not quietly fall back to opening a second one — someone who cannot edit an existing review request is very often someone who should not be opening another.

## Rewriting a branch that is under review

Rebasing and force-pushing a branch that already has review threads detaches those threads from the code they point at. The comments survive; the anchor does not.

The distinction that matters when deciding whether to rewrite:

- **Anchored**: a submitted review, an approval, or a comment thread attached to a line of the diff. These are what a rewrite breaks.
- **Not anchored**: a plain conversation comment on the review request, and anything a bot posted. These are attached to the review request rather than to a commit, and survive a rewrite intact.

Treating any comment as a reason not to rebase suppresses the rebase on nearly every review request, and on a repository with commenting automation it suppresses it from the first push. Anchored activity is the useful line.

When a rewrite is declined, the alternatives worth naming are: let the forge report any conflict on the review request itself; merge the target into the branch rather than replaying the branch onto it; or rewrite deliberately once the threads are resolved.

**In this repository.** Both skills rebase onto the target and force-push with lease before opening a review request, and feature 007 left that untouched on the create path. In update mode they probe first and skip the rewrite when anchored activity exists, reporting the skip and its alternatives in the approval summary rather than only in passing output. The success criterion is reachability rather than equality: commits may be added on top — a user who amended their branch expects exactly that — but none of the existing ones is replaced.

## The GitLab MCP fallback and its inverted flag

`ccd-gitlab-mr` falls back to the GitLab MCP server when `glab` is absent. Its `save_merge_request` tool decides create-versus-update **solely** by whether `merge_request_iid` is present:

- Creating: `merge_request_iid` **omitted**. Passing it turns the create into an edit of an existing merge request.
- Updating: `merge_request_iid` **supplied**. Omitting it opens a second merge request.

One field, two directions, and each direction fails silently into the other rather than erroring. Verify the result with `get_merge_request` rather than trusting the create response, and check the tool name against the session's exposed tools before calling it — that server's surface has changed at least once.

`gh` has no MCP fallback in this environment. When `gh` is missing, stop and say so; a hand-rolled `curl` path hides an authentication problem behind a second failure.

**In this repository.** Only `ccd-gitlab-mr` has this fallback, and it states the rule in both directions at its Step 9 — because each direction fails silently into the other, and reading only one of them is how the mistake gets made.

## Scripting: output, exit codes, environment

**`gh`**: `--json <fields>` with `--jq <expr>` or `--template` for output shaping; `gh help formatting` documents it. `-R`/`--repo [HOST/]OWNER/REPO` targets a repository without changing directory, and is available on `pr list`, `view`, `edit`, `create`, `merge`, `comment` and `reopen`. Exit codes, from `gh help exit-codes`: `0` success, `1` command failed, `2` cancelled while running, `4` authentication required — with the caveat that a particular command may define more. Environment: `GH_TOKEN`/`GITHUB_TOKEN`, `GH_HOST`, `GH_REPO`, `GH_PROMPT_DISABLED` (any value disables interactive prompting), `GH_DEBUG=api` to log HTTP traffic.

**`glab`**: `-F`/`--output json` plus `--jq`; `-y`/`--yes` skips confirmation on `mr create`, `mr update` and `mr merge`; `-R`/`--repo` targets a project. Token from `GITLAB_TOKEN`, or `glab config` under `token` (also accepted as `gitlab_token` and `oauth_token`).

**In this repository.** Both skills are Markdown instructions rather than programs, so these matter for what the instructions tell an agent to run: JSON output with an explicit field list, so nothing depends on parsing human-readable formatting; and `--yes` on `glab mr update`, since the skill's own approval gate has already run by then and a second confirmation prompt would stall a step nobody is watching.

## Recorded gaps

- Neither CLI exposes a documented, machine-readable way to tell a bot's comment from a person's. It does not arise for the anchored kind, which both forges do expose; it would arise for any rule that counted conversation comments.
- GitLab's published rate limits for gitlab.com name issue creation and note creation but state no separate limit for merge request creation or update. Nothing here loops, so no limit is assumed.
- `glab mr note` and `glab mr create --recover` are marked **EXPERIMENTAL** in 1.116.0. Do not build on either until that marking changes.
- `glab mr merge --auto-merge` defaults to **true** while a pipeline is running — "Pass `--auto-merge=false` to merge immediately." Surprising, and worth knowing before any future work touches merging.
- `gh pr edit --help` does not document what happens when `--add-reviewer` names a reviewer who is already requested. The documented re-request example implies it is accepted rather than an error, but this was not verified against a live repository.
- The exact GitHub 422 and GitLab 409 message strings above come from issue trackers and forum reports rather than from reference documentation. They are recorded so the failures are recognisable, and should not be parsed.

## Sources

- `gh pr list`, `gh pr edit`, `gh pr ready`, `gh pr reopen`, `gh pr merge`, `gh pr comment`, `gh auth status`, `gh help exit-codes`, `gh help environment`, `gh help formatting` — help output of the installed `gh` 2.100.0
- <https://cli.github.com/manual/> — the `gh` manual
- <https://docs.github.com/en/rest/pulls/pulls> — the REST `head` parameter's `user:ref-name` support, which `gh pr list --head` does not expose
- <https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps> — the `repo` and `public_repo` scopes
- <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-auto-merge-for-pull-requests-in-your-repository> — auto-merge, write permission, and why it appears only on a pull request that cannot merge immediately
- `glab mr list`, `glab mr update`, `glab mr view`, `glab mr create`, `glab mr reopen`, `glab mr merge`, `glab mr note`, `glab auth status`, `glab config` — help output of the installed `glab` 1.116.0
- <https://docs.gitlab.com/cli/> — the `glab` documentation
- <https://docs.gitlab.com/user/permissions/> — Developer to create and update a merge request, Maintainer to merge
- <https://docs.gitlab.com/security/tokens/access_token_scopes/> — the `api` scope
- <https://gitlab.com/gitlab-org/gitlab/-/issues/9428> — reopening a merged merge request
- <https://forum.gitlab.com/t/409-this-merge-request-already-exists-api/21212> — the duplicate merge request response
- <https://gitlab.com/gitlab-org/cli> — the CLI's home, after migration from the archived `profclems/glab`
