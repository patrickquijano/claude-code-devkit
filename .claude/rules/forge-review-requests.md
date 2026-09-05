---
paths:
  - 'skills/ccd-github-pr/**'
  - 'skills/ccd-gitlab-mr/**'
---

# Authoring the two forge review-request skills

Reasoning, sources and the verified tool versions:
[`docs/forge-review-requests.md`](../../docs/forge-review-requests.md).

## Never write one instruction covering both forges

- `gh` and `glab` disagree on the shape of every operation these skills perform on an existing
  review request. A sentence that covers both is wrong for one of them, and the wrong one succeeds
  rather than erroring.
- Write each forge's rule in its own skill, in that forge's own vocabulary. `ccd-github-pr` says
  pull request; `ccd-gitlab-mr` says merge request. Neither says "review request" in anything a
  user reads.

## Reviewers and assignees

- **`glab mr update --reviewer alice,bob` replaces the whole reviewer set.** Adding takes a `+`
  prefix per username, removing takes `-` or `!`. The same holds for `--assignee`.
- `gh pr edit` has separate `--add-reviewer` and `--remove-reviewer` flags, so it cannot strip
  anyone by accident.
- Naming a reviewer or an assignee adds them. Removal is always an explicit user choice, never a
  consequence of naming a different set. If an edit to either skill makes "add" and "replace"
  read the same way, the edit is wrong.

## Descriptions

- Both CLIs replace the description outright. Neither appends, and neither server merges.
  Checklist ticks live in that text and are not recoverable.
- Read the live description, diff it, and default to leaving it alone. Replacing and appending are
  the user's choices, made with the difference shown.
- A machine-maintained section is fenced by a begin and an end HTML comment naming the skill.
  Anything other than exactly one well-formed pair means not-found: append a fresh region, never
  infer a boundary, never delete a region the skill did not write.
- Pass the description with `--body-file` or `--description-file`, never inline. A generated
  description contains backticks and `$`, which a double-quoted argument executes.

## Detection

- Both CLIs list open review requests by default. Pass `--state all` on `gh pr list` and `-A` on
  `glab mr list` when closed and merged ones matter.
- `gh pr list --head` does **not** accept `owner:branch`. Filter `isCrossRepository` and the head
  owner in the returned JSON instead. On GitLab, check the source project rather than trusting a
  source-branch name match.
- A review request's head branch cannot be changed after creation on either forge. One whose head
  is a different branch is not this branch's, and is never something to fix by editing.
- A detection call that fails stops the run with its reason. It is never read as "none exists".

## Updating an existing review request

- Exactly five fields may change: title, description, target branch, reviewers, assignees. Not
  draft state, not merge options, not labels, not milestone — on either forge, whether or not the
  flag exists.
- Do not ask a question in update mode whose answer update mode cannot act on.
- The target branch defaults to the value the review request already holds.
- When no field would change, say so and issue no edit.
- A blanket skip-approval phrase never covers replacing a non-empty description, removing a
  reviewer or an assignee, or changing the target branch.

## Rewriting a branch under review

- Rebasing and force-pushing detaches review threads from the commits they point at.
- Anchored activity — a submitted review, an approval, or a thread on a line of the diff —
  suppresses the rewrite. A conversation comment or a bot comment does not: neither is anchored to
  a commit, and treating them as anchored disables the rebase on nearly every run.
- A suppressed rewrite is reported with its reason and its alternatives, in the approval summary
  rather than only in passing output.

## Merged is terminal

- A closed review request can be reopened with `gh pr reopen` or `glab mr reopen`. A merged one
  cannot be reopened on either forge; the only action is a new review request.

## The GitLab MCP fallback

- `save_merge_request` decides create versus update solely by `merge_request_iid`: omitted creates,
  supplied updates. Each direction fails silently into the other.
- Verify with `get_merge_request` rather than trusting the response, and check the tool name against
  the session's exposed tools before calling it.
