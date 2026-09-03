# Evaluations — ccd-gitlab-mr

Four scenarios exercising what fails first. Run against a scratch repo and a scratch GitLab project before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — 20 members, 15 branches, one batched call
- E2 — Branch already has an open MR
- E3 — `glab` unavailable, MCP fallback
- E4 — invoked from inside a git worktree
- E5 — a GitHub remote, which this skill must refuse rather than attempt
- Re-test after editing the skill

## E1 — 20 members, 15 branches, one batched call

**Setup**: GitLab project with 20 members at mixed access levels, 15 branches, `origin/HEAD` → `main`. Current branch `feat/audit-pagination` pushed, several commits, two of the project members appear as commit authors on it.

**Invoke**: `/ccd-gitlab-mr open an MR for this branch`

**Expect**:

- Step 1 establishes the source branch from `git rev-parse`, confirms it is on the remote, and finds no existing MR.
- Step 4 issues **one** `AskUserQuestion` call carrying **four** questions. Not six calls, not four calls — this is the efficiency regression to catch.
- Source branch is never asked about.
- Every option set has **at most four** options, never 15 branches or 20 members.
- `Target`: `main` first with `(Recommended)`, source branch absent from the list.
- `Assignee`: exactly four options — the current user from `glab api user` first with `(Recommended)`, two more members, then `Unassigned`.
- `Reviewers`: `multiSelect: true`, exactly four options — the top three excluding the current user, the two recent committers first as `(Recommended)`, then `No reviewers`.
- `Merge opts`: `multiSelect: true`, exactly two options, both `(Recommended)`.
- Every `header` is ≤ 12 characters (`Target`, `Assignee`, `Reviewers`, `Merge opts`).
- Step 7 asks Yes/No with `header: "Open MR?"`. Nothing is created before that `Yes`.
- Step 8 is a **single** `glab mr create` with assignee and reviewers passed as usernames — no numeric-ID resolution step, no follow-up PUT.

## E2 — Branch already has an open MR

**Setup**: same project. `feat/audit-pagination` already has MR `!42` open against `main`.

**Invoke**: `/ccd-gitlab-mr create a merge request`

**Expect**:

- Step 1's `glab mr list --source-branch` finds `!42` and the run **stops**, reporting the MR URL.
- The stop happens before Step 3, so the paginated 20-member fetch never runs. This is the ordering regression to catch — the old skill fetched members at Step 3 of 13, long before anything could abort.
- No second MR is created, and no attempt is made to edit `!42` — this skill only creates.

## E3 — `glab` unavailable, MCP fallback

**Setup**: same project, `glab` not on `PATH`. GitLab MCP server active.

**Invoke**: `/ccd-gitlab-mr push this and make an MR to main`

**Expect**:

- `scripts/member-options.sh` exits 1 with `glab-missing`, and the skill falls back to the MCP server rather than failing the run. A missing `jq` instead gives exit 2, same fallback.
- Step 9 uses MCP `save_merge_request` with `merge_request_iid` **omitted** — that field alone decides create versus update, and passing it edits an existing MR instead of creating one. Assignees and reviewers go by **username**, straight from the Step 3 listing; squash and remove-source-branch ride in the same call, with no follow-up request and no iid to interpolate.
- The tool name is checked against the session's exposed tools before it is called, not recalled. That server's surface has changed once already: a run that calls a remembered `create_merge_request` fails as "tool not found" at the final step, after every question has been answered.

## E4 — Invoked from inside a git worktree

**Setup**: same project. The main checkout has `main` out with uncommitted edits. A linked worktree at `.claude/worktrees/audit` has `feat/audit-pagination` checked out and pushed, several commits over `main`. **Invoke from inside the worktree** — this is how `ccd-speckit-run` reaches this skill in worktree mode.

**Invoke**: `/ccd-gitlab-mr open an MR for this branch`

**Expect**:

- Step 1's `git rev-parse --abbrev-ref HEAD` returns `feat/audit-pagination` — the worktree's branch, not the main checkout's `main`. Reading `main` here is the headline regression: the MR would be raised from the wrong branch entirely.
- `git rev-parse --git-dir --git-common-dir` returns two **different** paths, and the skill reports the worktree path in its Step 8 summary. Reporting nothing is a lesser regression but a real one: with several parallel worktrees, an MR that does not say which tree it came from is an MR the user cannot place.
- `command -v glab` and `glab auth status` run **before** `glab mr list`. A `glab mr list` error standing in for the auth check is the ordering regression to catch.
- `branch-options.sh` and `member-options.sh` are invoked as `sh <skill-dir>/scripts/…`. Invoking them as bare `scripts/…` is a regression that only shows up outside this skill's own directory — which is every real run — and it is the bug this scenario was added alongside.
- `member-options.sh`'s `git log -n 200` reads the **worktree's** branch history, so the recent-committer ranking reflects `feat/audit-pagination`.
- Nothing switches branch, nothing `cd`s to the main checkout, and the main checkout's uncommitted edits are untouched and unmentioned — they are not this branch's and not this MR's.
- The MR is created from `feat/audit-pagination` exactly as it would be from a plain checkout. Worktree mode changes what is _reported_, never what is _done_.

**The regression this catches**: a skill that reads the wrong tree's branch. Every command here is already worktree-local, so the failure mode is not breakage but silence — the run succeeds against the wrong branch, or succeeds without saying where from.

## E5 — A GitHub remote, which this skill must refuse rather than attempt

**Setup**: a repo whose `origin` is `git@github.com:org/repo.git`, branch `feat/x` pushed, `gh` and `glab` both installed and authenticated.

**Invoke**: `/ccd-gitlab-mr open an MR for this branch`

**Expect**:

- Step 1 reads `git remote get-url origin`, sees a GitHub host, and **stops before any `glab` call**. It names `ccd-github-pr` as the skill for this repo.
- No `glab mr list`, no `glab mr create`, no push, no rebase. Nothing is created and nothing is force-pushed.
- The reason given is the remote host, not a `glab` error. A run that lets `glab` fail on its own and reports that output has technically stopped, but the user is left reading a message about GitLab hosts that never mentions the actual problem or the actual fix.
- **Variant — self-hosted GitLab.** `origin` at `git@git.acme.internal:org/repo.git`, `glab auth status` listing `git.acme.internal`. The run proceeds normally: a hostname without `gitlab` in it is not evidence of anything, and a CLI configured for that host is. With **neither** CLI configured for it, the run stops and says the forge could not be established rather than guessing.

**The regression this catches**: a skill invoked on the wrong forge. `ccd-speckit-run` routes by remote before dispatching, but a user typing `/ccd-gitlab-mr` in a GitHub repo does not, and the guard has to live here. Its absence costs a rebase and a force-push before anything reveals that the MR was never possible.

## Re-test after editing the skill

`branch-options.sh` is not this skill's file. It exists **once**, in `ccd-branch-push`, and this skill reaches it through `${CLAUDE_PLUGIN_ROOT}`. There is nothing to compare, so the check is that the single implementation is still single and that this skill's reference still resolves to it:

```bash
test "$(find skills -name branch-options.sh | wc -l)" -eq 1 || echo "MORE THAN ONE IMPLEMENTATION"
grep -c 'ccd-branch-push/scripts/branch-options\.sh' skills/ccd-gitlab-mr/SKILL.md # expect 2
```

Editing it means editing `ccd-branch-push`'s copy, and its contract — the four columns and the ordering — is in that skill's own header comment. A copy reappearing under this skill is the regression to catch.

After any edit to `SKILL.md`: walk E1–E5 against the changed text. Any edit touching Step 1's remote check or the forge guard: walk E5 including its self-hosted variant — the GitHub half fails loudly, the self-hosted half fails by refusing a repo it should have accepted. Any edit touching Step 1's probes, the script invocation paths, or the Boundaries tree rules: walk E4 specifically, from inside a real worktree. Assert the Step 4 call is still one call of four questions, and that every option set is still bounded at four.

After any edit to the scripts: `sh -n` both, then run `scripts/branch-options.sh` in a work tree, in a commit-less repo (silent exit 0), detached (no `current` tag), and outside a repo (exit 1). Run `scripts/member-options.sh` with a stub `glab` on `PATH` emitting 20 ndjson members and confirm recent committers sort first, then access level descending, then username; confirm exit 1 with no `glab` and exit 2 with no `jq`. With a stub emitting more than 500 records, confirm the listing stops at 500 and a `truncated:` note reaches stderr — a silent cap would misreport coverage.

E1 and E2 need a real GitLab project for a true end-to-end run. When that is unavailable, walk them against the text and report them as walked, not passed. Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.
