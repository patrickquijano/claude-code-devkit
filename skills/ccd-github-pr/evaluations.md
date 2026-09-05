# Evaluations — ccd-github-pr

Ten scenarios exercising what fails first. Run against a scratch repo and a scratch GitHub repo before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — 25 assignable users, 15 branches, one batched call
- E2 — Branch already has an open PR
- E3 — PR from a fork
- E4 — Multiple templates in `.github/PULL_REQUEST_TEMPLATE/`
- E5 — Invoked from inside a git worktree
- E6 — Auto-merge cannot be armed
- E7 — The PR body carries work a person did
- E8 — The PR is closed, or merged
- E9 — Two open PRs from one branch
- E10 — The PR is already under review
- Re-test after editing the skill

## E1 — 25 assignable users, 15 branches, one batched call

**Setup**: GitHub repo with 25 assignable users, 15 branches, default branch `main`, `.github/CODEOWNERS` naming three of the users and one `@acme/platform` team, squash merge and delete-branch-on-merge both enabled. Current branch `feat/audit-pagination` pushed, several commits, two CODEOWNERS entries appear as commit authors on it.

**Invoke**: `/ccd-github-pr open a PR for this branch`

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

**Setup**: same repo. `feat/audit-pagination` already has PR `#42` open against `main`. Its body is the one this skill generated on the first run and nobody has edited it. No reviews and no comments.

**Invoke**: `/ccd-github-pr create a pull request`

**Expect**:

- Step 1's `gh pr list --head <branch> --state all` finds `#42` and the run continues in **update mode**, reporting the number, URL and state. A run that **stops** here is the headline regression this scenario now catches — that was the old behavior and it is what left the user editing the PR by hand.
- `--state all` is actually passed. Omitting it is invisible in this scenario, because `#42` is open, and it is exactly what breaks E8 — so check the call, not just the outcome.
- Step 8's summary says it is an update in its first line and lists all five fields — title, body, base, reviewers, assignees — each with its current and proposed value, naming the ones that are not changing.
- The `PR opts` question is **not** asked. Draft state and auto-merge are outside the five fields, and asking about something update mode cannot change is a regression even though nothing breaks.
- Step 9 issues one `gh pr edit 42` carrying only the flags whose field changed. No `gh pr create` is issued.
- Afterwards `gh pr list --head <branch> --state all` returns exactly one PR, still `#42`, with its comment history intact.
- Nothing arms auto-merge on `#42`.

## E3 — PR from a fork

**Setup**: `contributor/cli` is a fork of `cli/cli`. The user has `READ` on `cli/cli` and write on the fork. Branch `fix/flag-parsing` pushed to the fork. The fork's copy of `trunk` is 40 commits behind the parent's.

**Invoke**: `/ccd-github-pr open a PR to trunk`

**Expect**:

- Step 1 reads `isFork: true` and records `parent.nameWithOwner` as `cli/cli`.
- Step 2's base candidates come from the **parent's** branches. Offering the fork's stale `trunk` is a real regression, just an invisible one.
- Step 5 rebases onto the **parent's** base (`git fetch upstream trunk` / `git rebase upstream/trunk`), not `origin/trunk`. Rebasing onto the fork's 40-commits-behind copy succeeds and produces a PR whose diff includes commits the parent already has — the failure this step exists to prevent.
- `viewerPermission: READ` on the base repo → the `Assignee` question is **omitted** and the skill says why. Assignees, labels, and milestones from a read-only user are rejected by GitHub and fail the whole `gh pr create`.
- Step 9 passes `--head contributor:fix/flag-parsing`. A bare `--head fix/flag-parsing` is the regression: it resolves against the base repo, which has no such branch.

## E4 — Multiple templates in `.github/PULL_REQUEST_TEMPLATE/`

**Setup**: same repo as E1, plus `.github/PULL_REQUEST_TEMPLATE/` containing `feature.md`, `bugfix.md`, and `hotfix.md`, and **no** single-file `pull_request_template.md`. Branch `fix/session-npe`, every commit prefixed `fix:`.

**Invoke**: `/ccd-github-pr create a PR`

**Expect**:

- Step 6 finds the directory and issues **one extra** `AskUserQuestion` call, `header: "Template"`, with `bugfix.md` first as `(Recommended)` and the match named against the branch's actual commits.
- Silently taking the first file alphabetically, or falling through to the bundled default while three repo templates sit unused, are both regressions — the repo split its templates on purpose.
- Step 7 fills the chosen template's prompts. No HTML comment and no italic placeholder survives into the submitted body, and no heading the template supplied is deleted — a section with nothing to say gets one honest line.
- Nothing is written into `.github/` — Step 6 reads templates, it does not install them. A template written onto the feature branch would not take effect for this PR anyway (templates apply only from the default branch) and would widen the diff.
- Total calls: three (Step 4, Step 6 template, Step 8 gate).

## E5 — Invoked from inside a git worktree

**Setup**: same repo as E1. The main checkout has `main` out with uncommitted edits. A linked worktree at `.claude/worktrees/audit` has `feat/audit-pagination` checked out and pushed, several commits over `main`. **Invoke from inside the worktree.**

**Invoke**: `/ccd-github-pr open a PR for this branch`

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

**Invoke**: `/ccd-github-pr open a PR and enable auto-merge`

**Expect**:

- `gh pr create` succeeds. `gh pr merge --auto --squash --delete-branch` fails.
- The PR **URL is reported first**, then the auto-merge failure with its reason. Reporting the run as failed, or worse retrying the create, is the regression: the PR exists and re-creating is impossible anyway.
- Nothing is merged. `--auto` arms; it does not merge.
- Same expectation when the user picked draft: a draft cannot auto-merge, so the skill says so rather than issuing a call it knows will fail.

## E7 — The PR body carries work a person did

**Setup**: same repo, `#42` open. Someone has edited its body: a hand-written paragraph near the top, and one of the template's checklist items ticked.

**Invoke**: `/ccd-github-pr update the PR`

**Expect**:

- Step 7 reads the live body with `gh pr view 42 --json body` **before** proposing anything, and shows the difference against what it would generate.
- The question offers leave / append / replace, with **leave first and recommended**. `Replace it entirely` says in its own description that hand-written text and ticked checkboxes go with it.
- Choosing leave: `gh pr edit` is issued without `--body-file` at all. Passing the flag with an unchanged value is a regression — it rewrites the body for no reason.
- Choosing append: the paragraph and the tick are still present afterwards, and the generated content sits between `<!-- ccd-github-pr:begin -->` and `<!-- ccd-github-pr:end -->`.
- Run again, choosing append again: there is still exactly **one** fenced region, replaced rather than added to. Two stacked regions is the regression.
- Now delete just the `:end` marker by hand and run again choosing append. The skill reports the region as not found and appends a **fresh** fenced section. Anything that guesses where the region ended, or that deletes to the end of the body, is the dangerous failure here.
- With `/ccd-github-pr update the PR, don't ask me anything`: the body question is asked **anyway**, and the skill says why the skip was not honored. A skip phrase that reaches this question is the worst regression in the whole suite — it silently destroys a reviewer's work on a run the user thought was routine.

## E8 — The PR is closed, or merged

**Setup**: two variants against the same branch, run separately. (a) `#42` closed, not merged. (b) `#42` merged.

**Invoke**: `/ccd-github-pr open a PR for this branch`

**Expect**:

- (a) Step 1 offers two options: reopen `#42` and update it, or leave it closed and open a fresh one. Reopen is recommended, because it keeps the review history. **Nothing is changed before the answer** — no `gh pr reopen`, no create.
- (a) Choosing reopen: `gh pr reopen 42` runs, then the E2 update path.
- (a) Choosing fresh: a new PR is created and `#42` is left closed, untouched.
- (b) The skill states that a merged PR cannot be reopened — GitHub treats merge as terminal — and continues in create mode. Attempting `gh pr reopen` on a merged PR is the regression: it cannot work.
- (b) A new PR is created. Treating the merged one as "no candidate" and saying nothing about it is a lesser regression but still one: the user is entitled to know a previous PR for this branch was merged.
- Both variants require `--state all` on the Step 1 listing. With the default open-only listing, both silently become "no candidate" and open a duplicate.

## E9 — Two open PRs from one branch

**Setup**: `feat/audit-pagination` has `#42` open against `main` and `#43` open against `release/2.x`. Both are legal — GitHub forbids two open PRs only when head **and** base match.

**Invoke**: `/ccd-github-pr update the PR for this branch`

**Expect**:

- Step 1 lists both with number, state, base branch and title, and asks which. Picking the newest, or the first returned, is the regression — and a silent one, because the run then looks entirely normal while updating the wrong PR.
- Nothing is written before the pick.
- The chosen PR's base is the default for the `Base` question, not the repo default branch.

## E10 — The PR is already under review

**Setup**: `#42` open, a reviewer has left a comment thread on a line of the diff and requested changes. Record the branch's remote tip: `git rev-parse origin/feat/audit-pagination`. The base branch has moved on since the branch was cut.

**Invoke**: `/ccd-github-pr update the PR`

**Expect**:

- Step 5 probes for review activity **before** rebasing, and finds it.
- No `git rebase` and no `git push --force-with-lease` is issued. The remote tip is unchanged, or if the user amended the branch, the previously recorded commit is still reachable from the new tip — commits may be added, none replaced.
- The suppression, its reason, and the three alternatives appear in **Step 8's summary**, not only in passing output.
- Variant: same PR, but the only activity is one conversation comment and one bot comment, neither anchored to the diff. Then the rebase **does** run. Treating any comment as review activity is the regression — on a repo with a commenting bot it disables the rebase permanently, and the user is told it was skipped on every single run.

## Re-test after editing the skill

`branch-options.sh` is not this skill's file. It exists **once**, in `ccd-branch-push`, and this skill reaches it through `${CLAUDE_PLUGIN_ROOT}`. There is nothing to compare, so the check is that the single implementation is still single and that this skill's reference still resolves to it:

```bash
test "$(find skills -name branch-options.sh | wc -l)" -eq 1 || echo "MORE THAN ONE IMPLEMENTATION"
grep -c 'ccd-branch-push/scripts/branch-options\.sh' skills/ccd-github-pr/SKILL.md # expect 2
```

Editing it means editing `ccd-branch-push`'s copy, and its contract — the four columns and the ordering — is in that skill's own header comment. A copy reappearing under this skill is the regression to catch.

After any edit to Step 1, Step 5, Step 7, Step 8 or Step 9 — the five steps update mode runs through — walk E2, E7, E8, E9 and E10 specifically. The create path and the update path share those steps, so an edit meant for one reaches the other. E1 is the check that the create path did not move.

## E11: the merge options, independently

Reach Step 4 in create mode and select `Delete source branch on merge` **without** selecting `Enable auto-merge`.

**Expect** the pull request created, and then **no `gh pr merge` call at all** — without `--auto` that command merges immediately, which nobody asked for. Expect the run to report instead that the branch will not be deleted automatically, and to name the two ways to get it: arm auto-merge, or pass `--delete-branch` when merging by hand.

**Fails if** the run merges the pull request in order to honour a branch-deletion preference. That is the regression this scenario exists for, and it is worse than the bug it replaced.

**Expect also**, on a repository whose `deleteBranchOnMerge` is already `true`: the delete option **not offered**, with the repository default stated. Same for the squash option where `squashMergeAllowed` is `false`.

**Fails if** the four options are ever re-bundled into one. They were a single `Enable auto-merge — squash + delete branch` option until feature 010, which meant a maintainer wanting the finished branch tidied up but a human to do the merging could ask for neither.

**Fails if** update mode asks the merge options at all. Four excluded options are as excluded as one was: title, description, base branch, reviewers and assignees remain the only five fields.

After any edit to `SKILL.md`: walk E1–E11 against the changed text. Any edit touching Step 1's probes, the script invocation paths, or the Boundaries tree rules: walk E5 specifically, from inside a real worktree. Assert the Step 4 call is still one call of four questions, that every option set is still bounded at four, and that the current user still cannot appear as a reviewer option.

After any edit to the scripts: `sh -n` both. Run `branch-options.sh` in a work tree, in a commit-less repo (silent exit 0), detached (no `current` tag), and outside a repo (exit 1). Run `reviewer-options.sh` against a stub `gh` on `PATH` that answers `auth status` with exit 0 and `repo view --json assignableUsers` with a fixed JSON list, in a repo carrying a `.github/CODEOWNERS` with both `@user` and `@org/team` entries; confirm the order is codeowner-and-committer, then codeowner, then committer, then the rest, that the `@org/team` entry emits a `team` row with no `recent-committer` flag, and that the `codeowners: <path>` note reaches stderr. Confirm exit 1 with no `gh` on `PATH` and exit 2 with no `jq` — note that `jq` ships at `/usr/bin/jq` on this machine, so isolating the exit-2 path needs a scrubbed `PATH`, not merely a trimmed one. With a stub emitting more than 500 users, confirm the listing stops at 500 and a `truncated:` note reaches stderr.

E1–E4 and E6 need a real GitHub repo for a true end-to-end run, and E3 needs a fork the user has only read access to upstream of. When those are unavailable, walk them against the text and report them as walked, not passed. Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.

## The question standard

Every ask in this skill goes through `AskUserQuestion` with options, per-option effect and cost, exactly one `(Recommended)` and the reason for it — or an explicit statement that no recommendation is defensible. The rule lives once, in `.claude/rules/skill-authoring.md`; this skill restates none of it.

**Regression to re-check after any edit that touches a question**: no ask site instructs asking without naming the tool, no question offers options with no recommendation and no explanation of why none is given, and no local copy of the rule has crept back in. Run:

```sh
grep -n "Every question in this skill goes through" SKILL.md
```

Zero hits is correct. A hit means the repository-wide rule now has a second copy, which is the drift `.claude/rules/repository-docs.md` calls worse than having no rule at all.
