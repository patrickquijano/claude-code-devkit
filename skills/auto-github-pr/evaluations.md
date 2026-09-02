# Evaluations — auto-github-pr

Six scenarios exercising what fails first. Run against a scratch repo and a scratch GitHub repo before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — 25 assignable users, 15 branches, one batched call
- E2 — Branch already has an open PR
- E3 — PR from a fork
- E4 — Multiple templates in `.github/PULL_REQUEST_TEMPLATE/`
- E5 — Invoked from inside a git worktree
- E6 — Auto-merge cannot be armed
- Re-test after editing the skill

## E1 — 25 assignable users, 15 branches, one batched call

**Setup**: GitHub repo with 25 assignable users, 15 branches, default branch `main`, `.github/CODEOWNERS` naming three of the users and one `@acme/platform` team, squash merge and delete-branch-on-merge both enabled. Current branch `feat/audit-pagination` pushed, several commits, two CODEOWNERS entries appear as commit authors on it.

**Invoke**: `/auto-github-pr open a PR for this branch`

**Expect**:

- Step 1 establishes the head branch from `git rev-parse`, confirms it is on the remote, and finds no existing PR.
- Step 4 issues **one** `AskUserQuestion` call carrying **four** questions. Not six calls, not four calls — this is the efficiency regression to catch.
- Head branch is never asked about.
- Every option set has **at most four** options, never 15 branches or 25 users.
- `Base`: `main` first with `(Recommended)`, head branch absent from the list.
- `Assignee`: exactly four options — the current user from `gh api user` first with `(Recommended)`, two more `user` rows, then `Unassigned`. **No `team` row appears here** — `gh pr create --assignee` rejects teams, so a team option is a guaranteed create failure.
- `Reviewers`: `multiSelect: true`, exactly four options — the top three **excluding the current user**, the two committer-CODEOWNERS first as `(Recommended)`, then `No reviewers`. The current user appearing as a reviewer option is the headline regression: GitHub rejects a review request from the PR author and fails the entire `gh pr create`.
- The Reviewers question text says CODEOWNERS will auto-request path owners on a non-draft PR.
- `PR opts`: `multiSelect: true`, exactly two options, auto-merge first with `(Recommended)`, draft unselected.
- Every `header` is ≤ 12 characters (`Base`, `Assignee`, `Reviewers`, `PR opts`).
- Step 8 asks Yes/No with `header: "Open PR?"`. Nothing is created before that `Yes`.
- Step 9 is a **single** `gh pr create` using `--body-file`. A `--body "$(cat …)"` form is a regression — a description containing backticks runs them as command substitution.

## E2 — Branch already has an open PR

**Setup**: same repo. `feat/audit-pagination` already has PR `#42` open against `main`.

**Invoke**: `/auto-github-pr create a pull request`

**Expect**:

- Step 1's `gh pr list --head` finds `#42` and the run **stops**, reporting the PR URL and whether it is a draft.
- The stop happens before Step 3, so the reviewer fetch never runs.
- No second PR is created, and no attempt is made to edit `#42` — this skill only creates.

## E3 — PR from a fork

**Setup**: `contributor/cli` is a fork of `cli/cli`. The user has `READ` on `cli/cli` and write on the fork. Branch `fix/flag-parsing` pushed to the fork. The fork's copy of `trunk` is 40 commits behind the parent's.

**Invoke**: `/auto-github-pr open a PR to trunk`

**Expect**:

- Step 1 reads `isFork: true` and records `parent.nameWithOwner` as `cli/cli`.
- Step 2's base candidates come from the **parent's** branches. Offering the fork's stale `trunk` is a real regression, just an invisible one.
- Step 5 rebases onto the **parent's** base (`git fetch upstream trunk` / `git rebase upstream/trunk`), not `origin/trunk`. Rebasing onto the fork's 40-commits-behind copy succeeds and produces a PR whose diff includes commits the parent already has — the failure this step exists to prevent.
- `viewerPermission: READ` on the base repo → the `Assignee` question is **omitted** and the skill says why. Assignees, labels, and milestones from a read-only user are rejected by GitHub and fail the whole `gh pr create`.
- Step 9 passes `--head contributor:fix/flag-parsing`. A bare `--head fix/flag-parsing` is the regression: it resolves against the base repo, which has no such branch.

## E4 — Multiple templates in `.github/PULL_REQUEST_TEMPLATE/`

**Setup**: same repo as E1, plus `.github/PULL_REQUEST_TEMPLATE/` containing `feature.md`, `bugfix.md`, and `hotfix.md`, and **no** single-file `pull_request_template.md`. Branch `fix/session-npe`, every commit prefixed `fix:`.

**Invoke**: `/auto-github-pr create a PR`

**Expect**:

- Step 6 finds the directory and issues **one extra** `AskUserQuestion` call, `header: "Template"`, with `bugfix.md` first as `(Recommended)` and the match named against the branch's actual commits.
- Silently taking the first file alphabetically, or falling through to the bundled default while three repo templates sit unused, are both regressions — the repo split its templates on purpose.
- Step 7 fills the chosen template's prompts. No HTML comment and no italic placeholder survives into the submitted body, and no heading the template supplied is deleted — a section with nothing to say gets one honest line.
- Nothing is written into `.github/` — Step 6 reads templates, it does not install them. A template written onto the feature branch would not take effect for this PR anyway (templates apply only from the default branch) and would widen the diff.
- Total calls: three (Step 4, Step 6 template, Step 8 gate).

## E5 — Invoked from inside a git worktree

**Setup**: same repo as E1. The main checkout has `main` out with uncommitted edits. A linked worktree at `.claude/worktrees/audit` has `feat/audit-pagination` checked out and pushed, several commits over `main`. **Invoke from inside the worktree.**

**Invoke**: `/auto-github-pr open a PR for this branch`

**Expect**:

- Step 1's `git rev-parse --abbrev-ref HEAD` returns `feat/audit-pagination` — the worktree's branch, not the main checkout's `main`. Reading `main` here is the headline regression: the PR would be raised from the wrong branch entirely.
- `git rev-parse --git-dir --git-common-dir` returns two **different** paths, and the skill reports the worktree path in its Step 8 summary. Reporting nothing is a lesser regression but a real one: with several parallel worktrees, a PR that does not say which tree it came from is a PR the user cannot place.
- `command -v gh` and `gh auth status` run **before** `gh repo view`. A `gh repo view` error standing in for the auth check is the ordering regression to catch.
- `branch-options.sh` and `reviewer-options.sh` are invoked as `sh <skill-dir>/scripts/…`. Invoking them as bare `scripts/…` is a regression that only shows up outside this skill's own directory — which is every real run.
- `reviewer-options.sh`'s `git log -n 200` reads the **worktree's** branch history, so the recent-committer ranking reflects `feat/audit-pagination`.
- Nothing switches branch, nothing `cd`s to the main checkout, and the main checkout's uncommitted edits are untouched and unmentioned.
- The PR is created from `feat/audit-pagination` exactly as it would be from a plain checkout. Worktree mode changes what is _reported_, never what is _done_.

## E6 — Auto-merge cannot be armed

**Setup**: same repo as E1, but auto-merge disabled in repo settings. User selects auto-merge at Step 4 and approves at Step 8.

**Invoke**: `/auto-github-pr open a PR and enable auto-merge`

**Expect**:

- `gh pr create` succeeds. `gh pr merge --auto --squash --delete-branch` fails.
- The PR **URL is reported first**, then the auto-merge failure with its reason. Reporting the run as failed, or worse retrying the create, is the regression: the PR exists and re-creating is impossible anyway.
- Nothing is merged. `--auto` arms; it does not merge.
- Same expectation when the user picked draft: a draft cannot auto-merge, so the skill says so rather than issuing a call it knows will fail.

## Re-test after editing the skill

`branch-options.sh` is not this skill's file. It exists **once**, in `auto-branch-push`, and this skill reaches it through `${CLAUDE_PLUGIN_ROOT}`. There is nothing to compare, so the check is that the single implementation is still single and that this skill's reference still resolves to it:

```bash
test "$(find skills -name branch-options.sh | wc -l)" -eq 1 || echo "MORE THAN ONE IMPLEMENTATION"
grep -c 'auto-branch-push/scripts/branch-options\.sh' skills/auto-github-pr/SKILL.md # expect 2
```

Editing it means editing `auto-branch-push`'s copy, and its contract — the four columns and the ordering — is in that skill's own header comment. A copy reappearing under this skill is the regression to catch.

After any edit to `SKILL.md`: walk E1–E6 against the changed text. Any edit touching Step 1's probes, the script invocation paths, or the Boundaries tree rules: walk E5 specifically, from inside a real worktree. Assert the Step 4 call is still one call of four questions, that every option set is still bounded at four, and that the current user still cannot appear as a reviewer option.

After any edit to the scripts: `sh -n` both. Run `branch-options.sh` in a work tree, in a commit-less repo (silent exit 0), detached (no `current` tag), and outside a repo (exit 1). Run `reviewer-options.sh` against a stub `gh` on `PATH` that answers `auth status` with exit 0 and `repo view --json assignableUsers` with a fixed JSON list, in a repo carrying a `.github/CODEOWNERS` with both `@user` and `@org/team` entries; confirm the order is codeowner-and-committer, then codeowner, then committer, then the rest, that the `@org/team` entry emits a `team` row with no `recent-committer` flag, and that the `codeowners: <path>` note reaches stderr. Confirm exit 1 with no `gh` on `PATH` and exit 2 with no `jq` — note that `jq` ships at `/usr/bin/jq` on this machine, so isolating the exit-2 path needs a scrubbed `PATH`, not merely a trimmed one. With a stub emitting more than 500 users, confirm the listing stops at 500 and a `truncated:` note reaches stderr.

E1–E4 and E6 need a real GitHub repo for a true end-to-end run, and E3 needs a fork the user has only read access to upstream of. When those are unavailable, walk them against the text and report them as walked, not passed. Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.
