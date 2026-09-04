# Step 6 — Ship: review request, branch cleanup

## Contents

- Terminology: review request, and the two forges it resolves to
- State precondition, and the one case the override rule does not cover
- Sub-skill contract — dispatch, inbound facts, self-check
- Decisions the sub-skill owns, and the skip-approval ceiling
- 6a — uncommitted work check (Step 6 commits nothing itself; it may dispatch a skill that does)
- 6b — review request: forge routing, and every reason it may be skipped
- 6c — delete local branches, and the feature-branch exception
- 6e — leaving the workspace: one question, two option sets, two different guards
- Gate

## Terminology

**Review request** is this file's forge-neutral term for what 6b opens. GitLab calls it a merge request and GitHub calls it a pull request; the two are the same step of the run, raised by two different sub-skills against two different CLIs.

Which one this run gets was decided at Step 0 by `<skill-dir>/scripts/forge-detect.sh` and recorded as `tooling.forge` and `tooling.review_skill`. **Read those fields. Never re-detect here, never infer the forge from the task description, the repo's language, or a remembered remote** — Step 6 arrives after eight phases and at least one compaction, and a guessed forge sends a `glab` invocation at a GitHub remote.

| `tooling.forge` | `tooling.review_skill`             | 6b opens                                    | CLI the sub-skill uses |
| --------------- | ---------------------------------- | ------------------------------------------- | ---------------------- |
| `gitlab`        | `claude-code-devkit:ccd-gitlab-mr` | a merge request                             | `glab`                 |
| `github`        | `claude-code-devkit:ccd-github-pr` | a pull request                              | `gh`                   |
| `other`         | `none`                             | nothing — 6b is skipped with the host named | —                      |
| `none`          | `none`                             | nothing — no remote is configured           | —                      |

Report the forge's own word for it in everything the user reads. A summary that calls a pull request a merge request is reporting a step that did not happen.

After Step 5's gate returns "proceed".

State precondition, both halves:

- `steps.5` is `done` — Step 5 ran. It is `done` on a failing check too; that is the step, not the verdict. `skipped: <reason>` is valid only for the one case Step 5 defines: Phase 8 never completed, so there was nothing to check.
- The verdict allows shipping: `verify.result` is `pass`, or it is `fail` or `none` **and** `verify.override` holds the decision Step 5 recorded.
- Every `findings[]` entry is `fixed` or `deferred`. An `open` entry means a reported issue was never addressed.

**The override rule applies only when Step 5 ran.** `steps.5 = "skipped: phase 8 <reason>"` means there was no implementation to check, so `verify.result = "none"` there records an absence, not an unverified branch — and Step 5, having been skipped, can never write the override that the `none` rule would demand. Sending the run back for one is a loop with no exit. That case goes straight to the Phase 8 question below, which is the decision actually being made: ship what exists, or stop. Record the answer as `verify.override` when the answer is to ship, so Step 7 reports why an unverified branch shipped.

Everything below the terminology section is forge-independent unless it says otherwise. Only 6b routes.

Any `open` finding → **do not ship.** List them with their source and severity, and return the run to Step 5's register gate. Minor is not an exemption: it was reported, so it gets a fix or an explicit deferral, and neither of those is something Step 6 may decide on its own.

`fail` or `none` with no `verify.override`, **where `steps.5` is `done`** → **do not ship.** Name which of the two it is, quote `verify.command` and the last output, and send the run back to Step 5's gate for the decision. Never supply the override yourself, and never read an earlier "proceed" as one — proceeding past Step 5 is consent to reach Step 6, not consent to ship a red branch.

Phase 8 skipped, stopped early, or scope-limited → say so, ask with `AskUserQuestion`: ship the partial result, or stop. Never ship silently past an incomplete `implement`.

Read that from `phases.8`, not from recollection. `skipped: <reason>` and `failed: <error>` are visible on their face; a scope limit is visible only because Phase 8 recorded it as `done: scope-limited to <what>`. Plain `done` means the whole of `tasks.md` ran. A run that reaches here after a compaction has nothing but that value to tell the three apart.

Creates a review request, deletes branches, and in worktree mode can remove a working directory — so full proposal cycle: propose, approve, execute. It runs no `git add` or `git commit` of its own; see 6a. Proposal states: `verify` in full — command, result, attempts, and the override text whenever the branch ships red or unverified — then the register from 5g, every deferred finding named with its reason, then 6a's partition and the commit range the review request would carry, the forge and review skill from state, current branch, exact delete/keep table from `<skill-dir>/scripts/cleanup-plan.sh`, and — for the two sub-skills — only the **facts being handed to them**, never answers on their behalf. Verification status leads, because it is the fact that decides whether the rest should happen at all.

**The proposal ends by naming the questions the review skill will still ask after approval**, so that approval cannot be misread as having answered them. `ccd-gitlab-mr` asks target, assignee, reviewers and merge options; `ccd-github-pr` asks base, assignee, reviewers, and its PR options — **draft, and auto-merge**. Name them from the skill that is actually being dispatched, not from the other one. Approving Step 6's plan is consent to _reach_ that skill, never consent to skip what it asks. A run where that approval returns and no sub-skill question follows has swallowed those decisions, not settled them.

Auto-merge deserves its own sentence in a GitHub proposal, because it is the one sub-skill answer that can act after this run ends: `ccd-github-pr` recommends arming `--auto --squash --delete-branch`, which merges the branch the moment its checks pass — including on a branch this pipeline shipped red under an override, and including before any human has read it. Whether to arm it stays that skill's decision behind its own gate; naming it here is what stops Step 6's approval from being read as having armed it. In worktree mode add the consequence 6c and 6e both depend on: a source branch deleted on merge is deleted while the run's worktree still has it checked out.

Two sub-steps hand off to skills owning their own rules and their own approval gates. Never reimplement either — no hand-rolled review-request payload, no hand-rolled commit. And Step 6 never commits _itself_: `git add` and `git commit` are out of this step entirely. What 6a may do is **dispatch the skill whose job that is**, and only on an explicit answer to its own question. Delegating the decision is not the same as taking it.

## Sub-skill contract

**Dispatch is a tool call, not a phrase.** Each sub-step runs its skill through the `Skill` tool — `Skill(skill: "claude-code-devkit:ccd-commit-push")` at 6a, and at 6b `Skill(skill: <tooling.review_skill>)`, which is `"claude-code-devkit:ccd-gitlab-mr"` or `"claude-code-devkit:ccd-github-pr"` and is never typed from memory — with the inbound facts below as its arguments. Writing the slash command into prose, or performing the work inline because the intent is obvious, does not invoke anything: the sub-skill's own SKILL.md never loads, so its batched questions and its gate simply do not exist for that run. Inline `glab mr create`, inline `gh pr create`, or an MCP `create_merge_request` call inside Step 6 is a defect, not a shortcut — and reaching for the wrong forge's CLI is a defect twice over. Inline `git add` or `git commit` is worse: it is work Step 6 does not do at all.

**When a namespaced name does not resolve.** Dispatch the form Step 0 recorded as resolving for that companion. The namespaced `claude-code-devkit:<name>` is what a plugin install lists and is preferred whenever it resolves, because it names exactly one skill even on a machine that also holds a personal copy. Where Step 0 recorded the bare name as the form that resolved, dispatch that. Where it recorded the companion as missing under both forms, the sub-step is **skipped with that reason recorded** — 6b per the rule below, 6a by dropping its commit option — and never substituted with inline work. A `Skill` call on a name that does not resolve is a failed dispatch at the end of a full pipeline run, which is the failure Step 0's probe exists to move to the beginning.

**Self-check before the gate.** No `Skill` tool call in the transcript for that sub-step → the sub-step did not run, whatever the summary says. Report it, re-dispatch properly. Record the outcome in `ship.subskill_calls` as `invoked` or `skipped: <reason>`; a compacted run reads that field rather than trusting recollection that a skill "was used".

**Inbound**, stated in the invocation: feature branch, the `verify` status, every deferred finding, any uncommitted paths 6a reported as left behind, and any skip-approval phrase. The base branch is **not** inbound. Worktree mode adds the worktree path, so the sub-skill can report which tree it acted in.

**Outbound**, captured into `ship`: the commit range and pushed state from 6a when it dispatched, and from 6b the review request's URL into `ship.review_request` with its `forge` and `kind`.

### Decisions the sub-skill owns

`ccd-speckit-run` supplies **facts**. The sub-skill supplies **answers**. Any item below arriving pre-decided in the invocation is a bug in this step, not a convenience.

| Sub-skill         | Owns                                                                                                                                                              |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ccd-commit-push` | commit message and its convention, how the change is split across commits, whether to push, its own approval gate                                                 |
| `ccd-gitlab-mr`   | **target branch**, assignee, reviewers, squash-on-merge, delete-source-branch, MR title, description template, any project title-convention conflict              |
| `ccd-github-pr`   | **base branch**, assignee, reviewers, draft state, **whether to arm auto-merge**, PR title, which repo PR template to fill, any project title-convention conflict |

The base branch in state is what the feature branch was cut from and what 6c's cleanup plan protects. It is **not** the review request's target, and it is never passed as one. Both skills rank candidates themselves at their Step 2 and ask at their Step 4, and both skip that question outright when the invocation already names one — `ccd-gitlab-mr` calls it the target branch, `ccd-github-pr` calls it the base branch, and supplying either is how it silently becomes wrong. Omit it.

**Trust nothing.** A sub-skill's gate can be declined; it can stop halfway. Verify each postcondition with git before moving on. Postcondition unmet → stop before 6c, never delete.

**Approval pass-through, and its ceiling.** Both skills scan _their invoking instruction_ for skip-approval phrases. User gave `ccd-speckit-run` such a phrase — "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm" → repeat it verbatim when invoking 6a's commit skill or 6b's review skill.

A skip phrase suppresses **exactly one thing: that skill's own final approval gate**. It suppresses nothing else. Its batched selection question — target or base, assignee, reviewers, and the forge's own merge options — and its title-convention or template conflict are content questions: they decide what gets built rather than whether to proceed, and they run on every invocation whatever the user said. 6a's own question, when the run's work is uncommitted, is not suppressed either — it decides what the review request contains.

Bug signature: a sub-skill that returns having asked nothing at all. Zero questions means the skill was never dispatched (see **Dispatch**) or its content questions were answered on the user's behalf. Either way the result is not shippable — re-dispatch.

**Pass-through stops there, deliberately.** 6c deletes branches and 6e can remove a worktree. A skip phrase is consent to skip review of proposed content, not consent to irreversible deletion. 6c and 6e always confirm, whatever the user said.

## 6a — Uncommitted work check

**Step 6 runs no commit of its own.** No `git add`, no `git commit`, no `git stash`, no inline substitute, ever. What it may do — on an explicit answer to the question below, and only then — is dispatch `claude-code-devkit:ccd-commit-push` through the `Skill` tool and let that skill decide the message, the split, and the push, behind its own approval gate.

That distinction is the whole of this sub-step. Step 6 does not decide to commit; it asks, and hands the answer to the skill that owns commits. Nothing here writes to the index.

Why the question exists at all: Phase 8 (`implement`) writes files and typically commits none of them, and Step 6 commits none either. So the ordinary end of a successful run is a feature branch whose work is entirely uncommitted and a `<base>..HEAD` range that is empty — a review request carrying nothing. Left unaddressed, that is a pipeline that verifies real work and then ships an empty diff.

Partition the dirty tree:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/dirty-diff.sh" compare .specify/.speckit-dirty-snapshot
```

- `new` → written by this run and **still uncommitted**. Report every path.
- `pre-existing` → the user's own work from before the run. Report it, leave it.
- `internal` → this run's bookkeeping.

Then establish what the review request would actually carry:

```bash
git log --oneline '<base>'..HEAD # commits the feature branch has over the base
git status --porcelain=v1        # what is still dirty
```

**Any `new` path, or an empty `<base>..HEAD` range, means the review request will not contain the run's work** — and an empty range means it carries nothing at all. Name which of the two it is, list the paths, and ask with `AskUserQuestion`, `header: "Commit?"`, three options:

1. **Commit and push the run's work now (recommended when there is any `new` path)** — dispatch `Skill(skill: "claude-code-devkit:ccd-commit-push")`, handing it an **explicit list of the `new` paths**, the feature branch, the `verify` status and any skip-approval phrase.

   The list must be the one the question itself displayed, path for path. `implement` writes files unattended, and among them can be a generated `.env.local`, a fixture key, a token in a scratch config. Handing over "the dirty tree" rather than a list the user has just read restores exactly the unbroken automatic path from generated credential to remote history that 6a exists to break. So: name every path in the question, hand over that same list, and name separately — as deliberately excluded — anything credential-shaped: `.env*`, `*.pem`, `*.key`, `*_rsa`, anything the repo's own ignore rules cover. Excluded paths stay dirty and are reported as left behind. A user who wants one of them committed can say so; it is never the default and never inferred.
   That skill writes the commits behind its own gate. It returns → re-run the partition and the `<base>..HEAD` range and report both again, because the whole point of asking was to change them. Range still empty, or `new` paths still present → its gate was declined or it stopped halfway; say so and re-ask rather than proceeding on the old numbers.

2. **Open the review request anyway, on the commits that already exist** — valid when the range is non-empty and the user accepts that the listed paths stay out of it. Never offered as recommended when the range is empty: a review request with no commits is not reviewable.
3. **Stop here** — ends the run at Step 6 with state written; preflight resumes it once the commits exist, by hand or otherwise.

Option 1 is unavailable when Step 0 recorded `ccd-commit-push` as missing. Drop it, say why, and offer only 2 and 3 — never fall back to an inline `git commit` because the skill is absent. Record the dispatch in `ship.subskill_calls.6a` as `invoked` or `skipped: <reason>`, on the same terms as 6b.

A `CLAUDE.md` or `.claude/rules/` file that Step 2b wrote appears in `new` like any other output, and belongs in the commit — the rule changed because of this feature. Name it separately in 6a's report rather than letting it sit anonymously in the path list: it is a repo-wide instruction change riding in a feature review request, and the reviewer is the person who most needs to see it flagged. Read `claude_md.action` to know whether to expect one.

`pre-existing` paths are never part of this. They are the user's own work from before the run, and option 1 hands the commit skill the `new` paths only — sweeping a user's unrelated edits into the feature's commits is worse than an empty range, because it is not visible in the range that gets reviewed. Worktree mode makes that partition trivially safe: the user's edits are in a different directory entirely.

Never answer this question by committing yourself. The only commit path out of 6a is the dispatch in option 1.

Both buckets go into `ship.uncommitted` — as they stand **after** any option-1 dispatch, not as first found — so Step 7 reports what was actually left behind and a compacted run does not claim a clean tree it never saw.

Nothing dirty and the range non-empty → say so and continue.

## 6b — Review request

Route first, from state, before anything else in this sub-step: `tooling.forge` and `tooling.review_skill` decide which skill is dispatched, and whether one is dispatched at all. The terminology table above is the whole of that decision.

Deferred findings go into the invocation too — source, severity, statement, and the reason you accepted them. They are the known debt this review request carries, and the reviewer is the person who most needs them stated. A fixed finding needs no mention; the diff is its evidence.

`verify.result` is `fail` or `none` → the invocation states it verbatim: the command, the result, the attempt count, and the override. Both skills build their description from what they are given plus the diff, so this is how the warning reaches the MR or PR body — and each one's approval gate shows that description before anything is created. Never open a review request whose description reads as if the branch were verified when it was not.

On GitHub this fact carries further than the description. `ccd-github-pr` offers auto-merge, and an armed auto-merge on a branch that shipped red merges it as soon as the checks it does have go green. State the verify status and the override in the invocation for that reason as much as for the body, and let that skill's gate put the decision in front of the user. Do not arm it, do not suppress it, and do not answer its options question on the user's behalf.

Dispatch the named skill through the `Skill` tool. Let it run its own flow — each pushes the branch's existing commits if the remote lacks them, never creating any, then asks its own batch. Neither asks which branch the request comes _from_: that is the branch the invoking tree has checked out, which is the feature branch this run is standing on.

| `tooling.review_skill`             | Dispatch                                           | Asks                                                      |
| ---------------------------------- | -------------------------------------------------- | --------------------------------------------------------- |
| `claude-code-devkit:ccd-gitlab-mr` | `Skill(skill: "claude-code-devkit:ccd-gitlab-mr")` | target, assignee, reviewers, squash, delete-source-branch |
| `claude-code-devkit:ccd-github-pr` | `Skill(skill: "claude-code-devkit:ccd-github-pr")` | base, assignee, reviewers, draft, auto-merge              |

**Name no target or base branch in the invocation**, not the base branch from state and not a guess: each skill skips its own target question whenever the invocation supplies one, so supplying one is how the target silently becomes wrong. Same for assignee, reviewers, draft, squash and auto-merge — hand over facts, not selections. Capture the returned URL into `ship.review_request.url` with `forge` and `kind` beside it, and write `ship.subskill_calls.6b = "invoked"`.

**6b is available only when Step 0 found all of it.** Any one of these skips 6b with that exact reason recorded in `ship.subskill_calls.6b` — never improvise a substitute, never hand-roll a request against a forge's API, and never fall back to the other forge's skill or CLI:

| Missing                                                 | Recorded reason                       |
| ------------------------------------------------------- | ------------------------------------- |
| `tooling.forge` is `other`                              | `skipped: unsupported forge (<host>)` |
| `tooling.forge` is `none`                               | `skipped: no remote configured`       |
| the skill `tooling.review_skill` names is not installed | `skipped: <skill> not installed`      |
| the forge's CLI is absent                               | `skipped: <glab\|gh> unavailable`     |
| the forge's CLI is present but unauthenticated          | `skipped: <glab\|gh> unauthenticated` |

`tooling.forge_verdict` already holds the last three verbatim, written at Step 0 by `forge-detect.sh`. Record it as it stands rather than composing a reason here.

A remote at neither forge — Bitbucket, Gitea, a bare local origin, a plain `file://` path — is the common case of row one, and it is a normal repo, not a broken one. Spec Kit is GitHub Spec Kit, but the eight phases care nothing about the remote, so a repo can run the whole pipeline perfectly and still have no review-request path here. Say so plainly, naming the host, leave the branch pushed or unpushed exactly as it is, and continue to 6c. Opening a review request by hand there is the user's to do, outside this run.

A skipped 6b is not a failed step. 6c still runs — with the feature branch kept, since no URL came back to justify anything else — and Step 7 reports the skip reason where the URL would have been.

No URL back → 6b unfinished. Stop before 6c.

**The run stays on the feature branch.** Nothing switches back after the review request — not to the base branch, and never to the review request's target. The working tree is left where the review will need it.

## 6c — Delete local branches

Never decide this by hand. Run:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/cleanup-plan.sh" '<base>'
```

One verdict per local branch: `delete` only when the branch's upstream already holds every one of its commits; `keep` with reason otherwise — no upstream, unpushed commits ahead, checked out in a worktree, or the protected base.

Present the whole table, confirm, delete exactly the `delete` rows:

```bash
git branch -d <branch>
```

**Worktree mode needs no override here.** The feature branch is checked out in the run's worktree, so `cleanup-plan.sh` prints `keep — checked out in a worktree` for it on its own evidence. Report that the script protected it, and do not claim an override that did nothing. The paragraph below is the checkout-mode case.

**The feature branch 6b just raised is kept, whatever the script says.** In checkout mode, once its commits are pushed it is level with its upstream, so `cleanup-plan.sh` marks it `delete` on the evidence available to it — that script knows about upstreams, not about open review requests. But review has not happened yet, and the branch is most wanted precisely while the review request is open: a review comment means checking it out again, and a deleted local branch turns that into a re-fetch at best. Override the row to `keep`, with the review request's URL as the reason, and say so in the table. Deleting it anyway is available as an explicit choice at the confirmation, never a default.

`-d` refuses anything git considers unmerged — that refusal is a signal, not an obstacle. `git branch -D` is available only for the feature branch, only after 6b returned a review-request URL, and only when the user explicitly asked for it over the keep above. Never touch remote branches, never `git push --delete`, never delete a `keep` row.

## 6e — Leaving the workspace

Entered once 6b has returned a review-request URL. **This is the last point at which the pipeline still has the floor** — a person merges the review request, and the pipeline is not there when they do, so "after the merge" is not a moment this skill can act in.

Skipped, with the reason recorded, when 6b was skipped: with no review request there is nothing to leave the workspace _for_, and the run ends where it is.

One question, one `AskUserQuestion` call. Which option set depends on `workspace`.

**Checkout mode** — `header: "Branch"`:

1. `Stay on the feature branch (Recommended)` — nothing runs.
2. `Switch to <target>, keep the feature branch` — `git switch <target>`. The branch stays for a review comment to be answered on.
3. `Switch to <target> and delete the feature branch` — `git switch <target>`, then `git branch -d <feature>`. Offered **only** when the branch's commits are pushed; `-d` refuses an unmerged branch and that refusal is honoured, never worked around.

**Worktree mode** — `header: "Worktree"`. Skipped with a reason when `worktree.created` is false; a worktree the session was already inside is not this run's to tear down.

1. `Stay in the worktree (Recommended)` — nothing runs.
2. `Exit, keep the worktree` — `ExitWorktree(action: "keep")`, returning to `worktree.original_dir`.
3. `Exit and remove the worktree` — `ExitWorktree(action: "keep")`, then `git worktree remove <path>`.
4. `Exit, remove the worktree, delete the branch` — the same, then `git branch -d <feature>` from the original directory.

### Why the least-destructive option is recommended

Review has not happened. The branch and the tree are most wanted precisely while the review request is open, because a review comment means checking the work out again — the argument 6c already makes for keeping the feature branch. The user chose the create-time trigger with that argument in front of them; the recommendation is where it still gets its say. Recommending is not deciding: every option above is offered.

### The two guards are different guards

They protect different things, and collapsing them into one "is anything uncommitted" test gets both wrong.

| Action              | Guarded on                                                     | Why                                                                                            |
| ------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Deleting a branch   | its commits being pushed                                       | history exists on the remote; `git branch -d` enforces this itself and its refusal is a signal |
| Removing a worktree | **no** uncommitted path in that directory, whatever its origin | `git worktree remove` discards the whole directory, so origin is irrelevant — it is all gone   |

A guarded-out option is **not offered**, and the reason is said out loud rather than the option quietly vanishing.

`git worktree remove --force` is never used. `git branch -D` is available only for the feature branch, only after 6b returned a URL, and only on an explicit request over the keep.

`ExitWorktree(action: "remove")` does not apply here: that action only removes a worktree the tool itself created with `name`, and one entered by `path` is left on disk whatever is passed. The removal is the explicit `git worktree remove` above.

**No skip-approval phrase reaches this question.** A skip phrase covers approval of proposed content, never a deletion — the same ceiling as 6c.

Record the answer in `worktree.teardown` or `branch.teardown`, and verify it with `git worktree list` and `git branch --list` rather than trusting the tool's report.

## Gate

Report: 6a's final partition and the commit range the review request carries, `ship.subskill_calls.6a` and `.6b`, the forge and the review request's URL — by that forge's own name for it — or the skip reason, current branch, branches deleted, branches kept with reason, every uncommitted path left behind — the run's own and pre-existing alike — and, in worktree mode, the worktree path and `worktree.teardown`. Write `ship`, `worktree` and `steps.6` to state, then ask with `AskUserQuestion`: proceed to the summary, redo a sub-step, or stop.
