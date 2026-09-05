# Evaluations — ccd-gitlab-mr

Nine scenarios exercising what fails first. Run against a scratch repo and a scratch GitLab project before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — 20 members, 15 branches, one batched call
- E2 — Branch already has an open MR
- E3 — `glab` unavailable, MCP fallback
- E4 — invoked from inside a git worktree
- E5 — a GitHub remote, which this skill must refuse rather than attempt
- E6 — Reviewers on an existing MR, and the prefix that keeps them
- E7 — The MR description carries work a person did
- E8 — The MR is closed, or merged
- E9 — Two open MRs from one branch
- E10 — The MR is already under review
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

**Setup**: same project. `feat/audit-pagination` already has MR `!42` open against `main`. Its description is the one this skill generated on the first run and nobody has edited it. No approvals and no discussions.

**Invoke**: `/ccd-gitlab-mr create a merge request`

**Expect**:

- Step 1's `glab mr list --source-branch <branch> --all` finds `!42` and the run continues in **update mode**, reporting the internal id, URL and state. A run that **stops** here is the headline regression this scenario now catches — that was the old behavior and it is what left the user editing the MR by hand.
- `--all` is actually passed. Omitting it is invisible in this scenario, because `!42` is open, and it is exactly what breaks E8 — so check the call, not just the outcome.
- Detection still happens before Step 3, so the paginated 20-member fetch never runs on a stop. This is the ordering regression the scenario has always caught, and it survives the mode change.
- Step 8's summary says it is an update in its first line and lists all five fields — title, description, target, reviewers, assignees — each with its current and proposed value, naming the ones that are not changing.
- The `Merge opts` question is **not** asked. Squash and delete-source-branch are outside the five fields, and asking about something update mode cannot change is a regression even though nothing breaks.
- Step 9 issues one `glab mr update 42` carrying only the flags whose field changed. No `glab mr create` is issued.
- Afterwards `glab mr list --source-branch <branch> --all` returns exactly one MR, still `!42`, with its discussion history intact.

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

## E6 — Reviewers on an existing MR, and the prefix that keeps them

**This is the most important scenario in this file.** It is the one defect that succeeds silently, on a command that reports success, and destroys someone else's state.

**Setup**: `!42` open, with `alice` and `bob` already set as reviewers by someone else.

**Invoke**: `/ccd-gitlab-mr update the MR, add carol as reviewer`

**Expect**:

- Step 9 issues `glab mr update 42 --reviewer '+carol'` — **with the `+`**.
- Afterwards the MR has **three** reviewers: alice, bob, carol.
- `glab mr update 42 --reviewer 'carol'` is the regression. It exits zero, reports success, and leaves carol as the only reviewer. Check the **command that was issued**, not just that the run said it worked — and check the reviewer list on the MR afterwards, because the run's own output will not tell you.
- The same holds for `--assignee`. `--unassign` must not appear unless the user explicitly asked to clear assignees.
- The Reviewers question does not offer alice or bob as options to add; they are already there, and the question text says so.
- With `/ccd-gitlab-mr update the MR, remove bob, don't ask me anything`: the removal is confirmed **anyway** and the skill says why the skip was not honored. Removal is `--reviewer '-bob'`, never a bare list omitting bob.

Walk this scenario after **any** edit to Step 4 or Step 9 of this skill, and after any edit that touches both skills at once — a rule written once for GitHub and GitLab together is correct for `gh` and wrong here.

## E7 — The MR description carries work a person did

**Setup**: same project, `!42` open. Someone has edited its description: a hand-written paragraph near the top, and one of the template's checklist items ticked.

**Invoke**: `/ccd-gitlab-mr update the MR`

**Expect**:

- Step 7 reads the live description with `glab mr view 42 --output json` **before** proposing anything, and shows the difference against what it would generate.
- The question offers leave / append / replace, with **leave first and recommended**. `Replace it entirely` says in its own description that hand-written text and ticked checkboxes go with it.
- Choosing leave: `glab mr update` is issued without `--description-file` at all. Passing the flag with an unchanged value is a regression — it rewrites the description for no reason.
- Choosing append: the paragraph and the tick are still present afterwards, and the generated content sits between `<!-- ccd-gitlab-mr:begin -->` and `<!-- ccd-gitlab-mr:end -->`.
- Run again, choosing append again: there is still exactly **one** fenced region, replaced rather than added to.
- Delete just the `:end` marker by hand and run again choosing append: the skill reports the region as not found and appends a **fresh** section, rather than guessing where it ended.
- With `don't ask me anything` in the invocation: the description question is asked **anyway**, with the reason the skip was not honored.

## E8 — The MR is closed, or merged

**Setup**: two variants against the same branch, run separately. (a) `!42` closed. (b) `!42` merged.

**Invoke**: `/ccd-gitlab-mr open an MR for this branch`

**Expect**:

- (a) Step 1 offers two options: reopen `!42` and update it, or leave it closed and open a fresh one. Reopen is recommended. **Nothing is changed before the answer.**
- (a) Choosing reopen: `glab mr reopen 42` runs, then the E2 update path.
- (b) The skill states that a merged MR cannot be reopened — long-standing GitLab behaviour, `gitlab-org/gitlab#9428` — and continues in create mode. Attempting `glab mr reopen` on a merged MR is the regression: it cannot work.
- (b) A new MR is created, and the merged one is mentioned rather than passed over in silence.
- Both variants require `--all` on the Step 1 listing. With the default open-only listing, both silently become "no candidate" and open a duplicate.

## E9 — Two open MRs from one branch

**Setup**: `feat/audit-pagination` has `!42` open against `main` and `!43` open against `release/2.x`. Both are legal: GitLab's one-open-MR rule is per source-**and**-target pair, so two targets means two MRs are permitted.

**Invoke**: `/ccd-gitlab-mr update the MR for this branch`

**Expect**:

- Step 1 lists both with internal id, state, target branch and title, and asks which. Picking the newest, or the first returned, is the regression — and a silent one, because the run then looks entirely normal while updating the wrong MR.
- Nothing is written before the pick.
- The chosen MR's target is the default for the `Target` question, not the project default branch.

## E10 — The MR is already under review

**Setup**: `!42` open, a reviewer has left a discussion thread on a line of the diff and one approval is recorded. Record the branch's remote tip: `git rev-parse origin/feat/audit-pagination`. The target branch has moved on since the branch was cut.

**Invoke**: `/ccd-gitlab-mr update the MR`

**Expect**:

- Step 5 probes approvals and discussions **before** rebasing, and finds anchored activity.
- No `git rebase` and no `git push --force-with-lease` is issued. The previously recorded commit is still reachable from the tip afterwards — commits may be added, none replaced.
- The suppression, its reason, and the three alternatives appear in **Step 8's summary**, not only in passing output.
- Variant: the only activity is one conversation comment and one pipeline-bot comment, neither carrying diff position. Then the rebase **does** run. Treating any comment as review activity is the regression — on a project with a commenting bot it disables the rebase permanently.

## Re-test after editing the skill

`branch-options.sh` is not this skill's file. It exists **once**, in `ccd-branch-push`, and this skill reaches it through `${CLAUDE_PLUGIN_ROOT}`. There is nothing to compare, so the check is that the single implementation is still single and that this skill's reference still resolves to it:

```bash
test "$(find skills -name branch-options.sh | wc -l)" -eq 1 || echo "MORE THAN ONE IMPLEMENTATION"
grep -c 'ccd-branch-push/scripts/branch-options\.sh' skills/ccd-gitlab-mr/SKILL.md # expect 2
```

Editing it means editing `ccd-branch-push`'s copy, and its contract — the four columns and the ordering — is in that skill's own header comment. A copy reappearing under this skill is the regression to catch.

After any edit to Step 1, Step 5, Step 7, Step 8 or Step 9 — the five steps update mode runs through — walk E2, E6, E7, E8, E9 and E10 specifically, and walk **E6 first**. The create path and the update path share those steps, so an edit meant for one reaches the other; E1 is the check that the create path did not move.

Any edit that changes both this skill and `ccd-github-pr` in one pass: walk E6 before anything else. A rule phrased once to cover both forges is correct for `gh` and strips this project's reviewers.

After any edit to `SKILL.md`: walk E1–E10 against the changed text. Any edit touching Step 1's remote check or the forge guard: walk E5 including its self-hosted variant — the GitHub half fails loudly, the self-hosted half fails by refusing a repo it should have accepted. Any edit touching Step 1's probes, the script invocation paths, or the Boundaries tree rules: walk E4 specifically, from inside a real worktree. Assert the Step 4 call is still one call of four questions, and that every option set is still bounded at four.

After any edit to the scripts: `sh -n` both, then run `scripts/branch-options.sh` in a work tree, in a commit-less repo (silent exit 0), detached (no `current` tag), and outside a repo (exit 1). Run `scripts/member-options.sh` with a stub `glab` on `PATH` emitting 20 ndjson members and confirm recent committers sort first, then access level descending, then username; confirm exit 1 with no `glab` and exit 2 with no `jq`. With a stub emitting more than 500 records, confirm the listing stops at 500 and a `truncated:` note reaches stderr — a silent cap would misreport coverage.

E1 and E2 need a real GitLab project for a true end-to-end run. When that is unavailable, walk them against the text and report them as walked, not passed. Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.
