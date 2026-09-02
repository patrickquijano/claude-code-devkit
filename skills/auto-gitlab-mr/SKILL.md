---
name: auto-gitlab-mr
description: Use when the user wants a GitLab merge request created end-to-end — e.g. "open an MR for this branch", "create a merge request", "push this and make a GitLab MR to main". Not for a plain branch push with no merge request.
---

# Auto GitLab MR

Pushes the current branch if needed, gathers ranked branch and member candidates, collects every required selection in one batched question, then creates the merge request with a conventional-style title and a template-structured description.

## When NOT to use

- User just wants a branch pushed with no MR — use `claude-code-devkit:auto-branch-push` instead.
- User already has an open MR and wants to edit it — this skill only creates MRs, it doesn't update existing ones.
- Target is a GitHub repository — use `claude-code-devkit:auto-github-pr` instead. Step 1 detects this from the remote host and stops.

## Asking the user

Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled "confirm?".

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

**Two calls on a clean run.** Step 4 batches all four selections into one call; Step 8 is the approval gate. A rebase conflict at Step 5 or a convention conflict at Step 6 each add a call if triggered. The source branch is never asked — it is the current branch, established in Step 1.

Bundled `scripts/` and `templates/` paths below are relative to **this SKILL.md's own directory**, not the repo you are working in. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-gitlab-mr/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch. Ask at Step 8 anyway and say why the skip was not honored.

Honored → skip the **Step 8** wait, still show the summary, and **name the phrase that triggered the skip** so the user can see the inference that was made. Not honored, or no match → always wait for approval.

**Step 1 — Preflight.** Establish the source branch and the tree it lives in, and stop early on anything that makes the run pointless. Do all of this before Step 3's paginated member fetch, so an aborted run never pays for it.

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --git-dir --git-common-dir     # these differ inside a worktree
git remote get-url origin                    # confirm this is a GitLab remote
command -v glab
glab auth status
git ls-remote --heads origin <branch>
glab mr list --source-branch <branch> --state opened --output json
```

Order matters: `command -v glab` and `glab auth status` come **before** any `glab` call, because "stop when `glab` is unauthenticated" needs a probe behind it — otherwise the first real failure is a confusing error from `glab mr list`.

Stop and say why when: not inside a git work tree; detached HEAD (no source branch exists); the remote is not GitLab (name the right skill instead); `glab` missing, or present but unauthenticated; or `glab mr list` returns an **open MR for this branch** — report its URL, since this skill only creates MRs and a second create would just error.

**A GitHub remote stops the run here**, before any `glab` call: `glab` against `github.com` fails with an error about GitLab hosts that says nothing about the actual problem. Name `claude-code-devkit:auto-github-pr` as the skill for that repo and stop. A self-hosted host that `glab auth status` lists is a GitLab remote whatever its hostname looks like; one it does not list, and that is not a `gitlab.*` domain, is not this skill's to guess at.

**Worktree.** `--git-dir` and `--git-common-dir` differing means this is a linked worktree, not the main checkout. That changes nothing this skill does — every command it runs is worktree-local, and the branch it reads is this tree's branch — but it changes what the user needs told. Record the worktree's path and report it in Step 8's summary, so an MR raised from one of several parallel trees says which tree it came from. Never switch branch, never `cd` to the main checkout, never act on a branch this tree does not have checked out.

Branch absent from the remote → push it: `git push -u origin <branch>`.

**Step 2 — Rank the target-branch candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh"
```

Tab separated, repo default branch first then newest commit first: `<branch>  local|remote|both  <YYYY-MM-DD>  <tags>`. Drop the source branch from the output, then take the top four.

**Step 3 — Rank the project members.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/auto-gitlab-mr/scripts/member-options.sh"
glab api user --output ndjson # the current user, for the assignee default
```

Tab separated, best candidate first: `<username>  <name>  <access_level>  recent-committer|-`. Recent committers on this branch rank above everyone else, then descending access level. Take the top four.

Script exits 1 (no `glab`) or 2 (no `jq`) → fall back to the GitLab MCP server per Tool Reference, or ask the user to name the assignee and reviewers directly.

**Step 4 — One batched `AskUserQuestion` call, four questions.**

1. `header: "Target"` — the top four from Step 2. The `default`-tagged branch first with `(Recommended)`; each `description` gives the last-commit date and local/remote/both. Skip this question when the invocation already names a target that Step 2 confirms exists.
2. `header: "Assignee"` — exactly four options: the current user first with `(Recommended)` (they opened it, so they own it), the next **two** from Step 3, then `Unassigned` as the escape option. Each `description` gives the member's name, access level, and whether they recently committed to this branch.
3. `header: "Reviewers"` — `multiSelect: true`, exactly four options: the top **three** from Step 3 **excluding** the current user, recent committers first as `(Recommended)` (they already know this code), then `No reviewers`.
4. `header: "Merge opts"` — `multiSelect: true`, exactly two options, both recommended and both selected by default in the recommendation text: `Delete source branch on merge (Recommended)` (keeps the branch list clean; leaving it costs nothing but accumulates dead branches) and `Squash commits on merge (Recommended)` (one commit per MR keeps the target branch history readable; skipping it preserves the individual commits). Selected means enabled.

**Step 5 — Rebase onto target.** Source branch MUST rebase onto the chosen target before the MR is created — MR reflects a clean, up-to-date diff, and Step 7's generated description is built from post-rebase commits/diff.

```bash
git fetch origin <target>
git rebase origin/<target>
```

Clean rebase (no conflicts) → force-push the rewritten branch, then continue to Step 6:

```bash
git push --force-with-lease origin <source>
```

Conflict during rebase → do **not** resolve unilaterally. Brainstorm the viable approaches for this specific conflict (e.g. resolve manually and continue, merge instead of rebase, skip rebase and let GitLab's MR UI surface the conflict, cherry-pick around the conflicting commit, abort the run) and put them to `AskUserQuestion`: recommended option first with `(Recommended)` and its justification, remaining viable options each with their own justification, `Abort` last. Wait for the user's pick.

Approved → execute exactly that approach (manual resolution means editing the conflicted files, `git add`, `git rebase --continue`), then force-push with lease as above. `Abort` → stop the run, leave the branch as-is, do not push, do not create an MR.

Never advance to Step 6 until the rebase is either clean or resolved-and-approved, and the force-push has confirmed.

**Step 6 — Project convention and template check.** Look for `.gitlab/merge_request_templates/*.md`, preferring `Default.md`, and any MR-title linting config (`commitlint.config.*`, `.gitlab-ci.yml` title checks) or documented convention in `CONTRIBUTING.md` / repo `CLAUDE.md`.

Project template found → use it verbatim as the description structure. None found → use the bundled `templates/default-mr-template.md`.

A found title convention overrides the default vocabulary. It **contradicts** a hard rule below → resolve with `AskUserQuestion`, `header: "Convention"`, three options: follow the project convention (recommended, quoting the file and line), follow this skill's hard rule (justify: keeps titles short and machine-parseable, at the cost of diverging from the project), or abort. Never pick a side silently.

**Step 7 — Generate title and description.** Title per MR Title Rules below. Description filled into whichever template applies, synthesized from the branch's actual diff and commits — what and why, related issue refs if the user mentioned any, how to validate, checklist. Brief and concrete, not padded.

**Step 8 — Approval gate.** Present the full structured summary: source, target, assignee, reviewers, delete-source-branch, squash, rebase outcome (clean or how conflicts were resolved), generated title, generated description, which template was used, and — when Step 1 found one — the worktree path this MR is being raised from. Then ask with `AskUserQuestion`, `header: "Open MR?"`: `Yes` (create the merge request now) / `No` (stop, create nothing). Step 0 matched → display the summary and proceed without asking.

**Step 9 — Create the MR.** One `glab` call does everything, assignee and reviewers by **username** — no ID resolution needed.

Write the description to a temp file first and read it back with `$(cat …)`. A generated MR description routinely contains backticks, `$`, and newlines; inlining it in a double-quoted argument makes the shell run those backticks as command substitution.

```bash
printf '%s\n' "$description" > "$tmp" # or write the file directly
glab mr create \
  --source-branch '<source>' --target-branch '<target>' \
  --title '<title>' --description "$(cat "$tmp")" \
  --assignee '<username>' --reviewer '<user1>,<user2>' \
  --squash-before-merge --remove-source-branch --yes
```

Omit `--squash-before-merge` / `--remove-source-branch` to inherit the project default; pass `=false` to force them off. Omit `--assignee` entirely for `Unassigned`, and `--reviewer` for `No reviewers`.

Report the returned MR URL.

**`glab` unavailable** → MCP `mcp__plugin_gitlab_gitlab__save_merge_request`, with `merge_request_iid` **omitted**: that field alone decides create versus update, so passing it turns the create into an edit of some existing MR. It takes `project_id`, `title`, `source_branch`, `target_branch`, `description`, `assignees` and `reviewers` by **username** (not numeric IDs), plus `squash` and `remove_source_branch`, so one call covers everything Step 9 does and no follow-up request is needed.

Verify the created MR with `mcp__plugin_gitlab_gitlab__get_merge_request` rather than trusting the create response, then report the URL.

## MR Title Rules

Hard rules, no deviation:

- Conventional Commits header only: `type(scope): subject`.
- Imperative mood, describes the change.
- **Max 72 characters total** — hard cap.
- No body, footer, attribution, or trailers; no filenames listed; no unnecessary special characters.

## Boundaries

- Never force-push to satisfy Step 1. Step 5's rebase is the one exception: force-push there is always `--force-with-lease`, always to the source branch this tree owns, never to the target.
- Never switch branch, never `cd` elsewhere, never touch a tree other than the one invoked in. The source branch is whatever this working tree has checked out — that holds in the main checkout and in a linked worktree alike, and it is what makes this skill safe to call from one of several parallel worktrees.
- Never fabricate project members or branches — Steps 2 and 3 always re-fetch live data.
- Never silently override a detected project title/template convention that conflicts with a hard rule — route it through Step 6's conflict question.
- Never resolve a rebase conflict unilaterally — route it through Step 5's conflict question and wait for approval.
- Never create the MR before Step 8 returns `Yes`.
- Only creates MRs; never edits, merges, or closes existing ones.

## Tool Reference

`glab` is the primary tool: it covers MR creation, assignees, reviewers, squash, and remove-source-branch in a single call. The GitLab MCP server (`mcp__plugin_gitlab_gitlab__*`) is the fallback when `glab` is absent or unauthenticated. Probe which MCP tools this session actually exposes rather than assuming a name — that server's surface has changed, and a tool called from memory fails as "tool not found" at the last step of the run.

| Operation              | Command                                                                                           |
| ---------------------- | ------------------------------------------------------------------------------------------------- |
| Current branch         | `git rev-parse --abbrev-ref HEAD`                                                                 |
| Branch on remote       | `git ls-remote --heads origin <branch>`                                                           |
| Existing MR for branch | `glab mr list --source-branch <branch> --output json`                                             |
| Push branch            | `git push -u origin <branch>`                                                                     |
| Fetch target           | `git fetch origin <target>`                                                                       |
| Rebase onto target     | `git rebase origin/<target>`                                                                      |
| Push rebased branch    | `git push --force-with-lease origin <source>`                                                     |
| Target candidates      | `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh`                      |
| Member candidates      | `sh <skill-dir>/scripts/member-options.sh` (wraps `glab api projects/:id/members/all --paginate`) |
| Current user           | `glab api user`                                                                                   |
| Create MR              | `glab mr create` (see Step 9)                                                                     |
| Create MR, fallback    | MCP `save_merge_request` with `merge_request_iid` omitted                                         |

Neither `glab` nor the GitLab MCP server available → the same operations map to the REST API: `POST /projects/:id/merge_requests`, `GET /projects/:id/repository/branches`, `GET /projects/:id/members/all`.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** That field blocks the `Skill` tool, not merely automatic loading. `speckit-run` dispatches this skill at its Step 6b through exactly that tool — on a GitLab remote; a GitHub one gets `claude-code-devkit:auto-github-pr` — so setting the field breaks that handoff silently, and only at the very end of a full eight-phase pipeline run. The same applies to `user-invocable: false`, which would take away the `/auto-gitlab-mr` invocation this skill is designed around.
