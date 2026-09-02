---
name: auto-github-pr
description: Use when the user wants a GitHub pull request created end-to-end — e.g. "open a PR for this branch", "create a pull request", "push this and make a GitHub PR to main". Not for a plain branch push with no pull request.
---

# Auto GitHub PR

Pushes the current branch if needed, gathers ranked base-branch and reviewer candidates, collects every required selection in one batched question, then creates the pull request with a conventional-style title and a template-structured description.

## When NOT to use

- User just wants a branch pushed with no PR — use `claude-code-devkit:auto-branch-push` instead.
- User already has an open PR and wants to edit it — this skill only creates PRs, it doesn't update existing ones.
- Target is a GitLab project — use `claude-code-devkit:auto-gitlab-mr` instead. Step 1 detects this from the remote host and stops.

## Asking the user

Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled "confirm?".

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

**Two calls on a clean run.** Step 4 batches all four selections into one call; Step 8 is the approval gate. Each of these adds a call only when triggered: multiple repo PR templates at Step 6, a rebase conflict at Step 5, a title-convention conflict at Step 6. The head branch is never asked — it is the current branch, established in Step 1.

Bundled `scripts/` and `templates/` paths below are relative to **this SKILL.md's own directory**, not the repo you are working in. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-github-pr/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch.

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
gh pr list --head <branch> --state open --json number,url,isDraft
```

Order matters: `command -v gh` and `gh auth status` come **before** any other `gh` call, because "stop when `gh` is unauthenticated" needs a probe behind it — otherwise the first real failure is a confusing error from `gh repo view`.

Stop and say why when: not inside a git work tree; detached HEAD (no head branch exists); the remote is not GitHub (name the right skill instead); `gh` missing, or present but unauthenticated; or `gh pr list` returns an **open PR for this branch** — report its URL and whether it is a draft, since this skill only creates PRs and a second create would just error.

**Worktree.** `--git-dir` and `--git-common-dir` differing means this is a linked worktree, not the main checkout. That changes nothing this skill does — every command it runs is worktree-local, and the branch it reads is this tree's branch — but it changes what the user needs told. Record the worktree's path and report it in Step 8's summary, so a PR raised from one of several parallel trees says which tree it came from. Never switch branch, never `cd` to the main checkout, never act on a branch this tree does not have checked out.

**Fork.** `isFork: true` means the head branch lives in the fork and the PR targets `parent`. Record `parent.nameWithOwner` and pass `--head <fork-owner>:<branch>` at Step 9, and remember that Step 2's base candidates must come from the **parent's** branches, not the fork's stale copies. `viewerPermission` of `READ` on the base repo means labels, assignees, and milestones will be **rejected** — GitHub only accepts those from a user with triage or write access — so drop them from the Step 4 question set and say so rather than letting Step 9 fail.

Branch absent from the remote → push it: `git push -u origin <branch>`.

**Step 2 — Rank the base-branch candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh"
```

Tab separated, repo default branch first then newest commit first: `<branch>  local|remote|both  <YYYY-MM-DD>  <tags>`. Drop the head branch from the output, then take the top four.

**Step 3 — Rank the reviewer and assignee candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/auto-github-pr/scripts/reviewer-options.sh"
gh api user --jq '.login' # the current user, for the assignee default
```

Tab separated, best candidate first: `<handle>  <name|->  user|team  codeowner|-  recent-committer|-`. CODEOWNERS entries who also committed on this branch rank first, then other CODEOWNERS entries, then other recent committers, then everyone else assignable. Take the top four.

GitHub exposes no per-collaborator access level to a read-only token, so the script uses `CODEOWNERS` as the authority signal instead — which is the repo's own declaration of who reviews which paths. Script exits 1 (no `gh`, unauthenticated, or repo query failed) or 2 (no `jq`) → ask the user to name the assignee and reviewers directly.

**CODEOWNERS is already a reviewer request.** When the script reported a `codeowners:` path on stderr, GitHub will auto-request the owners of the touched paths the moment a **non-draft** PR opens. Say so in the Reviewers question text, and rank CODEOWNERS entries as recommended for the honest reason: they were going to be requested anyway. A **draft** PR does not trigger that auto-request, so when the user picks draft at Step 4, an explicit `--reviewer` is the only thing that reaches anyone.

**Step 4 — One batched `AskUserQuestion` call, four questions.**

1. `header: "Base"` — the top four from Step 2. The `default`-tagged branch first with `(Recommended)`; each `description` gives the last-commit date and local/remote/both. Skip this question when the invocation already names a base that Step 2 confirms exists.
2. `header: "Assignee"` — exactly four options: the current user first with `(Recommended)` (they opened it, so they own it), the next **two** `user` rows from Step 3, then `Unassigned` as the escape option. Never offer a `team` row here — `--assignee` rejects teams. Each `description` gives the handle's name and whether it is a CODEOWNERS entry or a recent committer. Omit this question entirely when Step 1 found `viewerPermission: READ`.
3. `header: "Reviewers"` — `multiSelect: true`, exactly four options: the top **three** from Step 3 **excluding the current user** (GitHub rejects a review request from the PR author, so including them fails the whole create), CODEOWNERS entries first as `(Recommended)`, then `No reviewers`. `team` rows are valid here as `org/team`.
4. `header: "PR opts"` — `multiSelect: true`, exactly two options: `Enable auto-merge — squash + delete branch (Recommended)` (the base branch keeps a one-commit-per-PR history and dead branches don't accumulate; skipping it means merging by hand later) and `Open as draft` (unselected by default: a draft blocks CI-gated auto-merge and suppresses the CODEOWNERS auto-request, so pick it only when the work wants early feedback rather than merge approval). Selected means enabled.

Step 1's `squashMergeAllowed: false` → drop the squash half of option 4 and say the repo forbids it; `deleteBranchOnMerge: true` already → say the delete half is the repo default and needs no flag.

**Step 5 — Rebase onto base.** Head branch MUST rebase onto the chosen base before the PR is created — the PR reflects a clean, up-to-date diff, and Step 7's generated description is built from post-rebase commits/diff.

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

**Step 8 — Approval gate.** Present the full structured summary: head, base, base repo (and the fork it is raised from, when Step 1 found one), assignee, reviewers, whether CODEOWNERS will add more, draft, auto-merge, rebase outcome (clean or how conflicts were resolved), generated title, generated description, which template was used, and — when Step 1 found one — the worktree path this PR is being raised from. Then ask with `AskUserQuestion`, `header: "Open PR?"`: `Yes` (create the pull request now) / `No` (stop, create nothing). Step 0 matched → display the summary and proceed without asking.

**Step 9 — Create the PR.** Write the description to a temp file and pass it with `--body-file`. A generated PR description routinely contains backticks, `$`, and newlines; inlining it in a double-quoted `--body` argument makes the shell run those backticks as command substitution. `--body-file` avoids the quoting problem entirely — do not substitute `--body "$(cat …)"` for it.

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

**Auto-merge, when selected.** It is a separate call, because GitHub has no per-PR squash or delete-branch flag at create time — those are repo settings and merge-time choices, unlike GitLab's MR checkboxes.

```bash
gh pr merge '<url>' --auto --squash --delete-branch
```

This fails when the repo has auto-merge disabled, when no branch protection requires a check (GitHub rejects auto-merge with nothing to wait for), or when the PR is a draft. The PR is already created and safe at that point, so treat a failure as a reportable outcome, not a run failure: report the created PR URL **first**, then that auto-merge could not be armed and the exact reason.

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
- Never create the PR before Step 8 returns `Yes`.
- Only creates PRs; never edits, reviews, merges, or closes existing ones. Step 9's `gh pr merge --auto` arms auto-merge on the PR just created and merges nothing itself.

## Tool Reference

`gh` is the primary tool and, in practice, the only one: it covers PR creation, assignees, reviewers, draft state, and arming auto-merge.

| Operation                              | Command                                                                                                                    |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Current branch                         | `git rev-parse --abbrev-ref HEAD`                                                                                          |
| Repo, fork, permission, merge settings | `gh repo view --json nameWithOwner,isFork,parent,viewerPermission,defaultBranchRef,squashMergeAllowed,deleteBranchOnMerge` |
| Branch on remote                       | `git ls-remote --heads origin <branch>`                                                                                    |
| Existing PR for branch                 | `gh pr list --head <branch> --state open --json number,url,isDraft`                                                        |
| Push branch                            | `git push -u origin <branch>`                                                                                              |
| Fetch base                             | `git fetch origin <base>` (fork: `git fetch upstream <base>`)                                                              |
| Rebase onto base                       | `git rebase origin/<base>`                                                                                                 |
| Push rebased branch                    | `git push --force-with-lease origin <head>`                                                                                |
| Base candidates                        | `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh`                                               |
| Reviewer candidates                    | `sh <skill-dir>/scripts/reviewer-options.sh` (wraps `gh repo view --json assignableUsers` plus `CODEOWNERS`)               |
| Current user                           | `gh api user --jq '.login'`                                                                                                |
| Create PR                              | `gh pr create` (see Step 9)                                                                                                |
| Arm auto-merge                         | `gh pr merge <url> --auto --squash --delete-branch`                                                                        |
| Available labels                       | `gh label list`                                                                                                            |

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

`branch-options.sh` is **not** this skill's file and no longer exists in it. It ships once, in `auto-branch-push`, and this skill invokes that copy through `${CLAUDE_PLUGIN_ROOT}`. There is nothing left to keep in step: the four consumers see identical candidates by construction rather than by comparison. Adding a copy back here is the regression — see evaluations.md for the check.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** That field blocks the `Skill` tool, not merely automatic loading, so any skill or pipeline dispatching this one through that tool breaks silently. `speckit-run` dispatches this skill at its Step 6b on a GitHub remote — a GitLab one gets `claude-code-devkit:auto-gitlab-mr` — so setting the field breaks that handoff at the very end of a full eight-phase pipeline run. The same applies to `user-invocable: false`, which would take away the `/auto-github-pr` invocation this skill is designed around.
