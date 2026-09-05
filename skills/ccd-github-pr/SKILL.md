---
name: ccd-github-pr
description: Use when the user wants a GitHub pull request opened or brought up to date end-to-end — e.g. "open a PR for this branch", "create a pull request", "update the PR for this branch", "push this and make a GitHub PR to main". Not for a plain branch push with no pull request.
---

# Auto GitHub PR

Pushes the current branch if needed, establishes whether the branch already has a pull request, gathers ranked base-branch and reviewer candidates, collects every required selection in one batched question, then either creates the pull request or updates the existing one — with a conventional-style title and a template-structured description.

## When NOT to use

- User just wants a branch pushed with no PR — use `claude-code-devkit:ccd-branch-push` instead.
- User wants a PR reviewed, approved, merged or closed — this skill opens and updates PRs and does none of those.
- Target is a GitLab project — use `claude-code-devkit:ccd-gitlab-mr` instead. Step 1 detects this from the remote host and stops.

## Two modes

Step 1 establishes which one this run is in, and Steps 4, 5, 7, 8 and 9 read it.

- **Create** — the branch has no pull request whose head is this branch, or the user chose to open a fresh one. This is the path an unchanged first run takes, and nothing about it changed.
- **Update** — an existing pull request was found and selected. The run brings it up to date rather than refusing, and everything it would change is shown with both values before anything is written.

The reasoning behind every forge-specific rule below, its source, and the tool version it was verified against are in [`docs/forge-review-requests.md`](../../docs/forge-review-requests.md). The short imperative form is in [`.claude/rules/forge-review-requests.md`](../../.claude/rules/forge-review-requests.md), which loads when this file is opened.

## Asking the user

Questions in this skill follow the repository-wide standard in [`.claude/rules/skill-authoring.md`](../../.claude/rules/skill-authoring.md).

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

**Two calls on a clean run.** Step 4 batches all four selections into one call; Step 8 is the approval gate. Each of these adds a call only when triggered: multiple repo PR templates at Step 6, a rebase conflict at Step 5, a title-convention conflict at Step 6. The head branch is never asked — it is the current branch, established in Step 1.

**Update mode adds at most two more**, neither of which fires when it has nothing to ask: one at Step 1 to pick among several candidates or to decide a closed one's fate, and one at Step 7 for the description. The create path's count is unchanged.

Bundled `scripts/` and `templates/` paths below are relative to **this SKILL.md's own directory**, not the repo you are working in. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-github-pr/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch.
- **Hard exception, update mode.** A skip never covers an operation that destroys something a person wrote. Ask anyway, and say why the skip was not honored, when the run would: replace a description that already contains content, remove a reviewer or an assignee, or change the target branch of an existing pull request. A blanket "don't ask" is consent to skip a confirmation, not consent to lose a reviewer's checklist.

Honored → skip the **Step 8** wait, still show the summary, and **name the phrase that triggered the skip** so the user can see the inference that was made. Not honored, or no match → always wait for approval, and when a skip was present but not honored, say why.

**Step 1 — Preflight.** Establish the head branch and the tree it lives in, and stop early on anything that makes the run pointless. Do all of this before Step 3's reviewer fetch, so an aborted run never pays for it.

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --git-dir --git-common-dir     # these differ inside a worktree
git remote get-url origin                    # confirm this is a GitHub remote
command -v gh
gh auth status
gh repo view --json nameWithOwner,isFork,parent,viewerPermission,defaultBranchRef,squashMergeAllowed,deleteBranchOnMerge
git ls-remote --heads origin <branch>
gh pr list --head <branch> --state all \
  --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author
```

Order matters: `command -v gh` and `gh auth status` come **before** any other `gh` call, because "stop when `gh` is unauthenticated" needs a probe behind it — otherwise the first real failure is a confusing error from `gh repo view`.

Stop and say why when: not inside a git work tree; detached HEAD (no head branch exists); the remote is not GitHub (name the right skill instead); or `gh` missing, or present but unauthenticated.

**Step 1b — Establish the mode.** Detection runs **after** the branch is known to be on the remote and **before** Step 3's reviewer fetch, Step 4's questions and Step 7's description — everything a stop, or a switch to update mode, would otherwise waste. It is not bounded to a time window or to a number of recent pull requests: the branch's whole history on this repository is in scope.

`--state` is passed explicitly because `gh pr list` lists open pull requests by default, and a closed or merged one for this branch is exactly what changes the answer.

**A detection call that fails stops the run with its reason.** An error from `gh pr list` is never read as "no pull request exists" — that reading turns an outage into a duplicate PR.

**Admissibility.** A returned pull request is a candidate only when its head is **this branch in this repository**. `gh pr list --head` does **not** accept the qualified `owner:branch` form — its own flag help says the syntax is unsupported — so a fork carrying a branch of the same name comes back in the same list. Filter on `isCrossRepository` and the head repository's owner. Never pass a qualified head to work around it.

A pull request's head branch cannot be changed after creation; there is no `gh pr edit` flag for it. So a pull request whose head is a different branch is not this branch's, permanently, and is never something to correct by editing.

Then, from the admissible candidates:

- **None** → **create mode.** Continue exactly as before; nothing below applies.
- **Exactly one, open** → **update mode** against it, whatever closed or merged candidates also exist. Report the others as present; do not offer them. An open pull request is unambiguously the live one for this branch.
- **More than one open** → ask with `AskUserQuestion`, `header: "Which PR"`, listing each candidate's number, state, base branch and title. Never pick. This is a real state rather than a theoretical one: GitHub forbids two open pull requests with the same head **and base**, so two open ones from this branch to two different bases are perfectly legal.
- **No open candidate, exactly one closed** → `AskUserQuestion`, `header: "Closed PR"`: reopen and update it (`gh pr reopen <number>`, recommended — it keeps the review history), or leave it closed and open a fresh one. Change nothing before the answer.
- **No open candidate, more than one closed or merged** → `AskUserQuestion` listing each with its state, title and last update, then apply the single-candidate rule to the pick. **No recommendation is defensible here**: a closed pull request and a merged one mean different things about intent, and only the user knows which of several was the real one. Say that rather than defaulting to the most recent.
- **Candidates all merged** → say so: GitHub treats merge as terminal and a merged pull request cannot be reopened. Continue in **create mode**.

When more candidates exist than the question can show, say how many were found and how many are listed.

**Worktree.** `--git-dir` and `--git-common-dir` differing means this is a linked worktree, not the main checkout. That changes nothing this skill does — every command it runs is worktree-local, and the branch it reads is this tree's branch — but it changes what the user needs told. Record the worktree's path and report it in Step 8's summary, so a PR raised from one of several parallel trees says which tree it came from. Never switch branch, never `cd` to the main checkout, never act on a branch this tree does not have checked out.

**Fork.** `isFork: true` means the head branch lives in the fork and the PR targets `parent`. Record `parent.nameWithOwner` and pass `--head <fork-owner>:<branch>` at Step 9, and remember that Step 2's base candidates must come from the **parent's** branches, not the fork's stale copies. `viewerPermission` of `READ` on the base repo means labels, assignees, and milestones will be **rejected** — GitHub only accepts those from a user with triage or write access — so drop them from the Step 4 question set and say so rather than letting Step 9 fail.

Branch absent from the remote → push it: `git push -u origin <branch>`.

**Step 2 — Rank the base-branch candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh"
```

Tab separated, repo default branch first then newest commit first: `<branch>  local|remote|both  <YYYY-MM-DD>  <tags>`. Drop the head branch from the output, then take the top four.

**Step 3 — Rank the reviewer and assignee candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-github-pr/scripts/reviewer-options.sh"
gh api user --jq '.login' # the current user, for the assignee default
```

Tab separated, best candidate first: `<handle>  <name|->  user|team  codeowner|-  recent-committer|-`. CODEOWNERS entries who also committed on this branch rank first, then other CODEOWNERS entries, then other recent committers, then everyone else assignable. Take the top four.

GitHub exposes no per-collaborator access level to a read-only token, so the script uses `CODEOWNERS` as the authority signal instead — which is the repo's own declaration of who reviews which paths. Script exits 1 (no `gh`, unauthenticated, or repo query failed) or 2 (no `jq`) → say which of the three occurred, then `AskUserQuestion`, `header: "Reviewers"`: name them now, or open the pull request with none and add them on the forge afterwards. Recommend opening with none, because an unreviewed pull request is visible and correctable while a guessed reviewer is neither.

**CODEOWNERS is already a reviewer request.** When the script reported a `codeowners:` path on stderr, GitHub will auto-request the owners of the touched paths the moment a **non-draft** PR opens. Say so in the Reviewers question text, and rank CODEOWNERS entries as recommended for the honest reason: they were going to be requested anyway. A **draft** PR does not trigger that auto-request, so when the user picks draft at Step 4, an explicit `--reviewer` is the only thing that reaches anyone.

**Step 4 — One batched `AskUserQuestion` call, four questions.**

1. `header: "Base"` — the top four from Step 2. The `default`-tagged branch first with `(Recommended)`; each `description` gives the last-commit date and local/remote/both. Skip this question when the invocation already names a base that Step 2 confirms exists.
2. `header: "Assignee"` — exactly four options: the current user first with `(Recommended)` (they opened it, so they own it), the next **two** `user` rows from Step 3, then `Unassigned` as the escape option. Never offer a `team` row here — `--assignee` rejects teams. Each `description` gives the handle's name and whether it is a CODEOWNERS entry or a recent committer. Omit this question entirely when Step 1 found `viewerPermission: READ`.
3. `header: "Reviewers"` — `multiSelect: true`, exactly four options: the top **three** from Step 3 **excluding the current user** (GitHub rejects a review request from the PR author, so including them fails the whole create), CODEOWNERS entries first as `(Recommended)`, then `No reviewers`. `team` rows are valid here as `org/team`.
4. `header: "PR opts"` — `multiSelect: true`, **four independent options**, each selectable on its own:
   - `Delete source branch on merge (Recommended)` — selected by default. Dead branches do not accumulate, and the branch survives until the merge actually happens, so nothing is lost while review is still open.
   - `Squash commits on merge (Recommended)` — selected by default. One commit per PR keeps the base branch's history readable; skipping it preserves the individual commits.
   - `Enable auto-merge` — selected by default. Merges the moment required checks pass. **Unlike the other three this one can act after this run ends and without a human having read the PR**, so it is the one to deselect when the work wants a reviewer's eyes before it lands.
   - `Open as draft` — **unselected** by default. A draft blocks CI-gated auto-merge and suppresses the CODEOWNERS auto-request, so pick it only when the work wants early feedback rather than merge approval.

   Selected means enabled. **These four were one bundled option until feature 010.** Welding branch deletion to auto-merge meant a maintainer who wanted the finished branch tidied up but wanted a human to merge it could ask for neither — the two are unrelated decisions and are now asked as such.

Step 1 already probed the repository, so use what it found rather than offering a choice that changes nothing:

- `squashMergeAllowed: false` → **drop the squash option** and say the repository forbids squash merges.
- `deleteBranchOnMerge: true` → **drop the delete option** and say the repository already deletes source branches on merge, so no flag is needed. This is a statement about the repository's default, not a refusal.

**Update mode changes what may be asked here.** Exactly five fields can change on an existing pull request: **title, description, base branch, reviewers, assignees.** Nothing else — not draft state, not auto-merge, not labels, not milestone — whether or not `gh` has a flag for it.

So in update mode:

- Question 1 `Base` still applies. Its **default is the base the pull request already has**, not the repo default branch. A different pick is a change like any other: it appears in Step 8's summary with both values and is applied only on approval, never on the strength of the selection.
- Questions 2 and 3 `Assignee` and `Reviewers` still apply, and they **add**. See below.
- Question 4 `PR opts` is **not asked**. Draft state, auto-merge, squash and source-branch deletion are all outside the five fields, and a question whose answer this run cannot act on is worse than no question — it implies a change that will not happen. Splitting that question into four independent options in feature 010 did not widen what update mode may change: four excluded options are as excluded as one was.

**Reviewers and assignees are added, never substituted.** Naming someone adds them to whoever is already on the pull request. `gh pr edit --add-reviewer` and `--add-assignee` are additive by construction, which is why GitHub cannot strip anyone here by accident — but the rule is about the outcome, not the flag: never replace the existing set as a side effect of naming a different one. Removal is available and is always an explicit choice by the user, offered only when they ask for it, and it goes through Step 0's hard exception. Re-naming a reviewer who is already requested is how GitHub re-requests review, so it is harmless rather than an error.

The Reviewers question in update mode excludes people already requested from its recommended options — they are already there — and says who those are in the question text.

**When no field would change**, say so and issue no edit at Step 9. An edit that changes nothing still produces activity every watcher of the pull request sees. This does not affect pushing the branch or bringing it up to date, which Step 5 governs.

**Step 5 — Rebase onto base.** Head branch MUST rebase onto the chosen base before the PR is created — the PR reflects a clean, up-to-date diff, and Step 7's generated description is built from post-rebase commits/diff.

**In update mode, probe first.** Rebasing and force-pushing rewrites the branch's published history, which detaches review threads from the lines they point at. The comments survive; the code they were about does not. So before rebasing, establish whether the selected pull request carries **review activity**:

```bash
gh pr view reviews,reviewDecision,latestReviews < number > --json
gh api "repos/{owner}/{repo}/pulls/<number>/comments" --jq 'length'
```

**Review activity** means a submitted review, an approval or a change request, or a comment thread attached to a line of the diff. A plain conversation comment on the pull request is **not** review activity, and neither is anything a bot posted: neither is anchored to a commit, so neither is broken by a rewrite. Counting them would suppress the rebase on nearly every run, and on a repository with commenting automation it would suppress it from the first push onward — which is indistinguishable from removing the rebase.

Review activity **present** → do not rebase, do not force-push. Report the suppression, its reason, and these alternatives: let GitHub report any conflict on the PR page itself; merge the base into the branch rather than replaying the branch onto it; or rebase deliberately once the review threads are resolved. Carry all of that into Step 8's summary, not only into passing output — a decision the user reads once in transient text is a decision they did not make.

Review activity **absent**, or create mode → rebase and force-push exactly as below. The create path is unchanged.

```bash
git fetch origin <base>
git rebase origin/<base>
```

On a fork, fetch the base from the parent, not from `origin`: add the parent once as a remote (`git remote add upstream <parent-url>`), then `git fetch upstream <base>` and `git rebase upstream/<base>`. Rebasing onto the fork's own stale copy of the base branch is the silent failure here — it succeeds, and the PR still shows a diff against commits the parent moved past.

Clean rebase (no conflicts) → force-push the rewritten branch, then continue to Step 6:

```bash
git push --force-with-lease origin <head>
```

Conflict during rebase → do **not** resolve unilaterally. Brainstorm the viable approaches for this specific conflict (e.g. resolve manually and continue, merge instead of rebase, skip the rebase and let GitHub's PR page surface the conflict, cherry-pick around the conflicting commit, abort the run) and put them to `AskUserQuestion`: recommended option first with `(Recommended)` and its justification, remaining viable options each with their own justification, `Abort` last. Wait for the user's pick.

Approved → execute exactly that approach (manual resolution means editing the conflicted files, `git add`, `git rebase --continue`), then force-push with lease as above. `Abort` → stop the run, leave the branch as-is, do not push, do not create a PR.

Never advance to Step 6 until the rebase is either clean or resolved-and-approved, and the force-push has confirmed.

**Step 6 — Project convention and template check.** GitHub honors a PR template at any of six paths, and the filename is case-insensitive. Look for all of them:

```bash
ls .github/pull_request_template.md pull_request_template.md docs/pull_request_template.md 2> /dev/null
ls .github/PULL_REQUEST_TEMPLATE/ PULL_REQUEST_TEMPLATE/ docs/PULL_REQUEST_TEMPLATE/ 2> /dev/null
```

Resolve in this order:

- **One single-file template** → use it verbatim as the description structure.
- **A `PULL_REQUEST_TEMPLATE/` directory with more than one `.md`** → this repo deliberately splits templates by change type, and picking one silently discards that intent. Ask with `AskUserQuestion`, `header: "Template"`: the template whose filename best matches the branch's actual diff first with `(Recommended)` and the match named (`bugfix.md` — this branch's commits are all `fix:`), the next two by relevance, and a fourth option using whichever single-file template also exists, or the bundled default. This is the one conditional call at Step 6.
- **A directory with exactly one `.md`** → use it, no question.
- **None found** → use the bundled `templates/default-pr-template.md`.

Also check for a PR-title convention: `commitlint.config.*`, a `.github/workflows/*` job running a title linter (`amannn/action-semantic-pull-request` and friends), or a documented convention in `CONTRIBUTING.md` / repo `CLAUDE.md`. A found convention overrides the default vocabulary. It **contradicts** a hard rule below → resolve with `AskUserQuestion`, `header: "Convention"`, three options: follow the project convention (recommended, quoting the file and line), follow this skill's hard rule (justify: keeps titles short and machine-parseable, at the cost of diverging from the project), or abort. Never pick a side silently.

**Step 7 — Generate title and description.** Title per PR Title Rules below. Description filled into whichever template applies, synthesized from the branch's actual diff and commits — what and why, how to validate, checklist. Brief and concrete, not padded.

Fill the template's own prompts; never leave an HTML comment or an italic placeholder standing in the submitted body. A section the diff genuinely has nothing for gets one honest line (`No user-visible surface — API-only change.`), not a deleted heading, because the repo put that heading there on purpose.

**Issue references are behavior, not prose.** `Closes #123` / `Fixes #123` in the body closes that issue when the PR merges; a bare `#123` only links. Use the closing form only for an issue the user actually named as resolved by this branch. Never infer one from a branch name — `fix/1234-timeout` may be a ticket ID from another tracker, and a wrong `Closes` silently closes someone else's issue on merge.

**Update mode: the existing body is read before anything is proposed.**

```bash
gh pr view body --jq '.body' < number > --json
```

`gh pr edit --body` and `--body-file` **replace the body outright.** There is no append mode in `gh` and no merge on GitHub's side. The body is where reviewers tick checklist items and where people write notes they were asked to record, and none of that is recoverable once overwritten. This is the only irreversible thing this skill can do.

Live body identical to what this run would generate → no change; say so and move on.

Otherwise show the difference and ask with `AskUserQuestion`, `header: "PR body"`:

1. `Leave it as it is (Recommended)` — the body is not touched. Recommended because a body that differs from the generated one usually differs because a person changed it.
2. `Append an update section` — the existing text is untouched and new content is added below it, inside this skill's fence.
3. `Replace it entirely` — the generated body replaces everything, including any hand-written text and any ticked checkbox. Say that in the option description, in those words.

**The fence.** An appended section is delimited by a begin and an end HTML comment naming this skill:

```markdown
<!-- ccd-github-pr:begin -->

... generated content ...

<!-- ccd-github-pr:end -->
```

Both markers are invisible when GitHub renders the body, so they cost the reader nothing. Exactly one well-formed pair — one begin, one end, begin first — means replace the text between them and leave everything else alone. **Anything else means the region was not found**: one marker without its partner, more than one pair, or an end before a begin. Report what was found and append a fresh section. Never infer the missing boundary from surrounding content, and never delete a region this skill did not write.

Step 0's hard exception applies: a blanket skip-approval phrase does not reach this question when the live body is non-empty.

**Step 8 — Approval gate.** Present the full structured summary: head, base, base repo (and the fork it is raised from, when Step 1 found one), assignee, reviewers, whether CODEOWNERS will add more, draft, auto-merge, rebase outcome (clean or how conflicts were resolved), generated title, generated description, which template was used, and — when Step 1 found one — the worktree path this PR is being raised from. Then ask with `AskUserQuestion`, `header: "Open PR?"`: `Yes` (create the pull request now) / `No` (stop, create nothing). Step 0 matched → display the summary and proceed without asking.

**In update mode the summary is a different shape**, and says so in its first line — a reader must be able to tell an update from a creation without inspecting the fields. Lead with the pull request's number, URL and state, then list **each of the five fields with its current value and its proposed value**, and name the ones that are not changing rather than omitting them silently. Include Step 5's rebase outcome or its suppression with the reason, the description decision that was taken, and the worktree path when there is one. The question becomes `header: "Update PR?"`: `Yes` (apply these changes to PR #N) / `No` (stop, change nothing).

**The values shown are the values read during this run.** GitHub is a shared system and the pull request can move underneath a run — someone merges it, closes it, or edits the body between Step 1's read and Step 8's approval. Before applying at Step 9, re-read the fields being changed. Where any differs from what was displayed, do **not** apply over the newer state: report what changed, then put the Step 8 question again with `AskUserQuestion` and the fresh values. Recommend re-reviewing rather than re-applying, and say why — the earlier approval was given against text that no longer exists.

Nothing about `Yes` here means "create as well as update". Update mode never creates a second pull request.

**Step 9, update mode — Edit the PR.** One `gh pr edit` call, carrying **only** the flags whose field actually changed. A flag passed with the value already on the pull request is not harmless: `--body-file` with an unchanged body still rewrites the body, and every flag passed widens the blast radius of a mistake.

```bash
printf '%s\n' "$body" > "$tmp"
gh pr edit '<number>' \
  --title '<title>' \
  --body-file "$tmp" \
  --base '<base>' \
  --add-reviewer '<login1>,<org/team>' \
  --add-assignee '<login>'
```

- `--body-file`, never `--body "$(cat …)"`, for the same reason as the create path: a generated body contains backticks and `$`, and a double-quoted argument runs them.
- `--add-reviewer` and `--add-assignee` add. `--remove-reviewer` and `--remove-assignee` exist and are issued **only** on an explicit removal the user asked for.
- There is **no flag for the head branch.** It cannot be changed after creation. If the head is wrong, the pull request is the wrong one.
- No `--add-label`, `--remove-label`, `--milestone`, `--add-project` or `--remove-project`: all outside the five fields. `--add-project` would additionally need the `project` scope, which the create path never asked for.
- Nothing arms auto-merge here. Arming it on an existing pull request that someone deliberately left un-armed is a change nobody asked for.

No field changed → issue no call at all, and report that the pull request was already up to date.

Report the pull request's URL, its number, and which fields were changed.

**Step 9, create mode — Create the PR.** Write the description to a temp file and pass it with `--body-file`. A generated PR description routinely contains backticks, `$`, and newlines; inlining it in a double-quoted `--body` argument makes the shell run those backticks as command substitution. `--body-file` avoids the quoting problem entirely — do not substitute `--body "$(cat …)"` for it.

```bash
printf '%s\n' "$description" > "$tmp"
gh pr create \
  --base '<base>' --head '<head>' \
  --title '<title>' --body-file "$tmp" \
  --assignee '<login>' --reviewer '<login1>,<org/team>' \
  --draft
```

Omit `--assignee` entirely for `Unassigned`, and `--reviewer` for `No reviewers`. Omit `--draft` unless the user selected it. On a fork, `--head <fork-owner>:<branch>`.

`gh pr create` is all-or-nothing on its metadata: one unknown reviewer handle, one label that does not exist in the base repo, or a review requested from the PR author fails the whole call and creates nothing. Every handle passed here came from Step 3's live listing for exactly that reason — never pass a handle the user typed without confirming it appears in that listing.

**The merge options, when any is selected.** They need a separate call, because GitHub has no per-PR squash or delete-branch flag at create time — those are repository settings and merge-time choices, unlike GitLab's MR checkboxes.

Build the call from **exactly the options that were selected**, never from a fixed string:

```bash
gh pr merge '<url>' --auto --squash --delete-branch
```

| Selected                        | Flag              |
| ------------------------------- | ----------------- |
| `Enable auto-merge`             | `--auto`          |
| `Squash commits on merge`       | `--squash`        |
| `Delete source branch on merge` | `--delete-branch` |

**Deletion wanted, auto-merge declined** is the case the old bundled option could not express, and it is now the interesting one. `gh pr merge` without `--auto` merges **immediately**, which is not what was asked for — so do not run this command at all in that case. Instead, report that the branch will not be deleted automatically and name the two ways to get it: select auto-merge, or pass `--delete-branch` when merging by hand later. Never merge a pull request to honour a branch-deletion preference.

Auto-merge fails when the repository has it disabled, when no branch protection requires a check (GitHub rejects auto-merge with nothing to wait for), or when the PR is a draft. The PR is already created and safe at that point, so treat a failure as a reportable outcome, not a run failure: report the created PR URL **first**, then that auto-merge could not be armed and the exact reason.

Report the returned PR URL either way.

## PR Title Rules

Hard rules, no deviation:

- Conventional Commits header only: `type(scope): subject`.
- Imperative mood, describes the change.
- **Max 72 characters total** — hard cap.
- No body, footer, attribution, or trailers; no filenames listed; no unnecessary special characters.

GitHub's squash merge takes the commit subject from the PR title and the commit body from the PR description, so on a squash-merge repo this title is what lands in `git log` on the base branch permanently. That is why the cap is hard and the vocabulary is fixed.

## Boundaries

- Never force-push to satisfy Step 1. Step 5's rebase is the one exception: force-push there is always `--force-with-lease`, always to the head branch this tree owns, never to the base.
- Never switch branch, never `cd` elsewhere, never touch a tree other than the one invoked in. The head branch is whatever this working tree has checked out — that holds in the main checkout and in a linked worktree alike, and it is what makes this skill safe to call from one of several parallel worktrees.
- Never fabricate handles, teams, labels, or branches — Steps 2 and 3 always re-fetch live data, and `gh pr create` rejects the whole call on one bad value.
- Never write a `Closes`/`Fixes` reference for an issue the user did not name.
- Never silently override a detected project title/template convention that conflicts with a hard rule — route it through Step 6's conflict question.
- Never resolve a rebase conflict unilaterally — route it through Step 5's conflict question and wait for approval.
- Never create or edit the PR before Step 8 returns `Yes`.
- Creates and updates PRs. Never reviews, approves, merges, or closes one. Step 9's `gh pr merge --auto` arms auto-merge on a PR this run just created, and merges nothing itself; update mode arms nothing.
- Never open a second PR for a branch that already has an open one — that is what Step 1b exists to prevent, and GitHub would reject it anyway when the base matches.
- Never replace a PR body that contains content a person wrote without an explicit answer to Step 7's question. There is no undo.
- Never remove a reviewer or an assignee as a side effect of naming a different set.
- Never change draft state, auto-merge, squash, source-branch deletion, labels or the milestone on an existing PR. Five fields, no others.
- Never run `gh pr merge` without `--auto` in order to honour a branch-deletion preference. That merges the pull request immediately, which nobody asked for.
- Never rewrite the branch's published history when the PR carries review activity.
- Never read a failed detection call as "no PR exists".

## Tool Reference

`gh` is the primary tool and, in practice, the only one: it covers PR creation, assignees, reviewers, draft state, and arming auto-merge.

| Operation                              | Command                                                                                                                    |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Current branch                         | `git rev-parse --abbrev-ref HEAD`                                                                                          |
| Repo, fork, permission, merge settings | `gh repo view --json nameWithOwner,isFork,parent,viewerPermission,defaultBranchRef,squashMergeAllowed,deleteBranchOnMerge` |
| Branch on remote                       | `git ls-remote --heads origin <branch>`                                                                                    |
| Candidates for branch, all states      | `gh pr list --head <branch> --state all --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author`  |
| Existing PR's body                     | `gh pr view <number> --json body --jq '.body'`                                                                             |
| Review activity on a PR                | `gh pr view <number> --json reviews,reviewDecision,latestReviews` plus `gh api repos/{owner}/{repo}/pulls/<n>/comments`    |
| Update a PR                            | `gh pr edit <number>` (see Step 9, update mode)                                                                            |
| Reopen a closed PR                     | `gh pr reopen <number>` — a merged PR cannot be reopened                                                                   |
| Push branch                            | `git push -u origin <branch>`                                                                                              |
| Fetch base                             | `git fetch origin <base>` (fork: `git fetch upstream <base>`)                                                              |
| Rebase onto base                       | `git rebase origin/<base>`                                                                                                 |
| Push rebased branch                    | `git push --force-with-lease origin <head>`                                                                                |
| Base candidates                        | `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh`                                                |
| Reviewer candidates                    | `sh <skill-dir>/scripts/reviewer-options.sh` (wraps `gh repo view --json assignableUsers` plus `CODEOWNERS`)               |
| Current user                           | `gh api user --jq '.login'`                                                                                                |
| Create PR                              | `gh pr create` (see Step 9)                                                                                                |
| Arm auto-merge                         | `gh pr merge <url> --auto --squash --delete-branch`                                                                        |
| Available labels                       | `gh label list`                                                                                                            |

Every command and flag in this table, what it does, and the `gh` version it was verified against are recorded in [`docs/forge-review-requests.md`](../../docs/forge-review-requests.md), together with the GitLab equivalents and the places the two forges differ. Check a claim there before changing one here.

`repos/{owner}/{repo}/collaborators` is **not** a usable member source: it returns 403 without push access on the repo. `assignableUsers` resolves for a read-only token, which is why the script uses it.

`gh` unavailable → stop and say so. There is no GitHub MCP server configured in this environment to fall back to, and inventing a `curl` path would hide an auth problem behind a second failure. The same operations map to the REST API for a caller that does have credentials: `POST /repos/{owner}/{repo}/pulls`, `POST /repos/{owner}/{repo}/pulls/{n}/requested_reviewers`, `GET /repos/{owner}/{repo}/branches`.

## Bundled templates

`templates/default-pr-template.md` is the fallback Step 6 uses when the repo has none. It is **not** installed into the repo — it only shapes the description of the PR being opened.

`templates/github/` is a drop-in set for a repo that wants templates of its own, laid out at the paths GitHub reads:

- `templates/github/pull_request_template.md` — the single-template install, copied to `.github/pull_request_template.md`.
- `templates/github/PULL_REQUEST_TEMPLATE/{feature,bugfix,hotfix,docs,refactor}.md` — the multi-template install, copied to `.github/PULL_REQUEST_TEMPLATE/`. GitHub's web UI offers these via `?template=bugfix.md`; Step 6 asks which one to use.

Installing either is a **separate, explicitly requested** action, not part of a PR run: templates only take effect once they are merged to the default branch, so writing them onto a feature branch mid-PR changes nothing for this PR and quietly widens its diff. Offer it, don't do it.

**Two sets, and neither is the other.** The distinction above is the one that gets lost: `default-pr-template.md` is never installed anywhere — it is the shape of a PR description this skill writes when the target repo has no template of its own. `templates/github/` is the opposite: files that do nothing until they are copied into a repo's `.github/`, and that shape every future PR once they are.

**Neither set is to be merged with `claude-code-devkit`'s own `.github/` templates**, even though this skill now ships inside that repository. Those templates are that repository's change-proposal forms, they quote `.specify/memory/constitution.md` verbatim, and `scripts/lint-citations.sh` fails the repository's aggregate check when an amendment leaves one of those quotations stale. Copying this skill's drop-in set over them would delete governance text the check is watching; copying theirs into `templates/github/` would ship constitution quotations to every unrelated repository this skill is used against. The two sets look alike and answer to different owners.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.

`branch-options.sh` is **not** this skill's file and no longer exists in it. It ships once, in `ccd-branch-push`, and this skill invokes that copy through `${CLAUDE_PLUGIN_ROOT}`. There is nothing left to keep in step: the four consumers see identical candidates by construction rather than by comparison. Adding a copy back here is the regression — see evaluations.md for the check.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** No skill in this plugin carries it, and none may — the count is a contract at `specs/010-bug-run-ship/contracts/skill-names.md`. The field blocks the `Skill` tool, not merely automatic loading, so any skill or pipeline dispatching this one through that tool breaks silently. **Two** callers now dispatch this skill on a GitHub remote — `ccd-speckit-run` at its Step 6b, and `ccd-speckit-bug-run` at its Step 4b; a GitLab remote sends both to `claude-code-devkit:ccd-gitlab-mr` instead — so setting the field breaks either handoff at the very end of a long run. The same applies to `user-invocable: false`, which would take away the `/ccd-github-pr` invocation this skill is designed around.
