---
name: ccd-gitlab-mr
description: Use when the user wants a GitLab merge request opened or brought up to date end-to-end — e.g. "open an MR for this branch", "create a merge request", "update the MR for this branch", "push this and make a GitLab MR to main". Not for a plain branch push with no merge request.
---

# Auto GitLab MR

Pushes the current branch if needed, establishes whether the branch already has a merge request, gathers ranked branch and member candidates, collects every required selection in one batched question, then either creates the merge request or updates the existing one — with a conventional-style title and a template-structured description.

## When NOT to use

- User just wants a branch pushed with no MR — use `claude-code-devkit:ccd-branch-push` instead.
- User wants an MR reviewed, approved, merged or closed — this skill opens and updates MRs and does none of those.
- Target is a GitHub repository — use `claude-code-devkit:ccd-github-pr` instead. Step 1 detects this from the remote host and stops.

## Two modes

Step 1 establishes which one this run is in, and Steps 4, 5, 7, 8 and 9 read it.

- **Create** — the branch has no merge request whose source is this branch, or the user chose to open a fresh one. This is the path an unchanged first run takes, and nothing about it changed.
- **Update** — an existing merge request was found and selected. The run brings it up to date rather than refusing, and everything it would change is shown with both values before anything is written.

The reasoning behind every forge-specific rule below, its source, and the tool version it was verified against are in [`docs/forge-review-requests.md`](../../docs/forge-review-requests.md). The short imperative form is in [`.claude/rules/forge-review-requests.md`](../../.claude/rules/forge-review-requests.md), which loads when this file is opened.

## Asking the user

Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled "confirm?".

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

**Two calls on a clean run.** Step 4 batches all four selections into one call; Step 8 is the approval gate. A rebase conflict at Step 5 or a convention conflict at Step 6 each add a call if triggered. The source branch is never asked — it is the current branch, established in Step 1.

**Update mode adds at most two more**, neither of which fires when it has nothing to ask: one at Step 1 to pick among several candidates or to decide a closed one's fate, and one at Step 7 for the description. The create path's count is unchanged.

Bundled `scripts/` and `templates/` paths below are relative to **this SKILL.md's own directory**, not the repo you are working in. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch. Ask at Step 8 anyway and say why the skip was not honored.
- **Hard exception, update mode.** A skip never covers an operation that destroys something a person wrote. Ask anyway, and say why the skip was not honored, when the run would: replace a description that already contains content, remove a reviewer or an assignee, or change the target branch of an existing merge request. A blanket "don't ask" is consent to skip a confirmation, not consent to lose a reviewer's checklist.

Honored → skip the **Step 8** wait, still show the summary, and **name the phrase that triggered the skip** so the user can see the inference that was made. Not honored, or no match → always wait for approval.

**Step 1 — Preflight.** Establish the source branch and the tree it lives in, and stop early on anything that makes the run pointless. Do all of this before Step 3's paginated member fetch, so an aborted run never pays for it.

```bash
git rev-parse --abbrev-ref HEAD
git rev-parse --git-dir --git-common-dir     # these differ inside a worktree
git remote get-url origin                    # confirm this is a GitLab remote
command -v glab
glab auth status
git ls-remote --heads origin <branch>
glab mr list --source-branch <branch> --all --output json
```

Order matters: `command -v glab` and `glab auth status` come **before** any `glab` call, because "stop when `glab` is unauthenticated" needs a probe behind it — otherwise the first real failure is a confusing error from `glab mr list`.

Stop and say why when: not inside a git work tree; detached HEAD (no source branch exists); the remote is not GitLab (name the right skill instead); or `glab` missing, or present but unauthenticated.

**Step 1b — Establish the mode.** Detection runs **after** the branch is known to be on the remote and **before** Step 3's paginated member fetch, Step 4's questions and Step 7's description — everything a stop, or a switch to update mode, would otherwise waste. It is not bounded to a time window or to a number of recent merge requests: the branch's whole history on this project is in scope.

`--all` is passed because `glab mr list --source-branch` returns **open** merge requests only by default, and a closed or merged one for this branch is exactly what changes the answer. (`-M` and `-c` narrow to merged or closed instead, and are not what is wanted here.)

**A detection call that fails stops the run with its reason.** An error from `glab mr list` is never read as "no merge request exists" — that reading turns an outage into a duplicate MR.

**Admissibility.** A returned merge request is a candidate only when its source is **this branch in this project**. `glab mr list` searches the current project, or the one `--repo` names — but a merge request opened _from a fork into this project_ still appears in that list, and it can carry a source branch of the same name. Check each candidate's source project and reject the ones that are not this project's. A source-branch name match is not an identity.

A merge request's source branch cannot be changed after creation; `glab mr update` has no flag for it. So a merge request whose source is a different branch is not this branch's, permanently, and is never something to correct by editing.

Then, from the admissible candidates:

- **None** → **create mode.** Continue exactly as before; nothing below applies.
- **Exactly one, opened** → **update mode** against it, whatever closed or merged candidates also exist. Report the others as present; do not offer them. An open merge request is unambiguously the live one for this branch.
- **More than one opened** → ask with `AskUserQuestion`, `header: "Which MR"`, listing each candidate's internal id, state, target branch and title. Never pick. This is a real state rather than a theoretical one: GitLab permits one open merge request per source-and-target pair, so two open ones from this branch to two different targets are perfectly legal.
- **No opened candidate, exactly one closed** → ask, `header: "Closed MR"`: reopen and update it (`glab mr reopen <iid>`, recommended — it keeps the review history), or leave it closed and open a fresh one. Change nothing before the answer.
- **No opened candidate, more than one closed or merged** → ask which, then apply the single-candidate rule to the pick.
- **Candidates all merged** → say so: a merged merge request cannot be reopened, which is long-standing GitLab behaviour tracked upstream as `gitlab-org/gitlab#9428`. Continue in **create mode**.

When more candidates exist than the question can show, say how many were found and how many are listed.

**A GitHub remote stops the run here**, before any `glab` call: `glab` against `github.com` fails with an error about GitLab hosts that says nothing about the actual problem. Name `claude-code-devkit:ccd-github-pr` as the skill for that repo and stop. A self-hosted host that `glab auth status` lists is a GitLab remote whatever its hostname looks like; one it does not list, and that is not a `gitlab.*` domain, is not this skill's to guess at.

**Worktree.** `--git-dir` and `--git-common-dir` differing means this is a linked worktree, not the main checkout. That changes nothing this skill does — every command it runs is worktree-local, and the branch it reads is this tree's branch — but it changes what the user needs told. Record the worktree's path and report it in Step 8's summary, so an MR raised from one of several parallel trees says which tree it came from. Never switch branch, never `cd` to the main checkout, never act on a branch this tree does not have checked out.

Branch absent from the remote → push it: `git push -u origin <branch>`.

**Step 2 — Rank the target-branch candidates.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh"
```

Tab separated, repo default branch first then newest commit first: `<branch>  local|remote|both  <YYYY-MM-DD>  <tags>`. Drop the source branch from the output, then take the top four.

**Step 3 — Rank the project members.**

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr/scripts/member-options.sh"
glab api user --output ndjson # the current user, for the assignee default
```

Tab separated, best candidate first: `<username>  <name>  <access_level>  recent-committer|-`. Recent committers on this branch rank above everyone else, then descending access level. Take the top four.

Script exits 1 (no `glab`) or 2 (no `jq`) → fall back to the GitLab MCP server per Tool Reference, or ask the user to name the assignee and reviewers directly.

**Step 4 — One batched `AskUserQuestion` call, four questions.**

1. `header: "Target"` — the top four from Step 2. The `default`-tagged branch first with `(Recommended)`; each `description` gives the last-commit date and local/remote/both. Skip this question when the invocation already names a target that Step 2 confirms exists.
2. `header: "Assignee"` — exactly four options: the current user first with `(Recommended)` (they opened it, so they own it), the next **two** from Step 3, then `Unassigned` as the escape option. Each `description` gives the member's name, access level, and whether they recently committed to this branch.
3. `header: "Reviewers"` — `multiSelect: true`, exactly four options: the top **three** from Step 3 **excluding** the current user, recent committers first as `(Recommended)` (they already know this code), then `No reviewers`.
4. `header: "Merge opts"` — `multiSelect: true`, exactly two options, both recommended and both selected by default in the recommendation text: `Delete source branch on merge (Recommended)` (keeps the branch list clean; leaving it costs nothing but accumulates dead branches) and `Squash commits on merge (Recommended)` (one commit per MR keeps the target branch history readable; skipping it preserves the individual commits). Selected means enabled.

**Update mode changes what may be asked here.** Exactly five fields can change on an existing merge request: **title, description, target branch, reviewers, assignees.** Nothing else — not draft state, not squash, not delete-source-branch, not labels, not milestone.

`glab mr update` has flags for every one of those excluded things: `--draft`, `--ready`, `--squash-before-merge`, `--remove-source-branch`, `--label`, `--unlabel`, `--milestone`. **The flag existing is not a reason to pass it.** They are outside the five fields and this skill does not touch them on a merge request that already exists.

So in update mode:

- Question 1 `Target` still applies. Its **default is the target the merge request already has**, not the project default branch. A different pick is a change like any other: it appears in Step 8's summary with both values and is applied only on approval, never on the strength of the selection.
- Questions 2 and 3 `Assignee` and `Reviewers` still apply, and they **add**. See the rule below, which is the most dangerous one in this skill.
- Question 4 `Merge opts` is **not asked**. Squash and delete-source-branch are outside the five fields, and a question whose answer this run cannot act on is worse than no question — it implies a change that will not happen.

**Reviewers and assignees are added, never substituted — and on GitLab that takes a prefix.**

`glab mr update --reviewer alice,bob` **replaces the entire reviewer set** with alice and bob, silently dropping everyone else, and reports success. Adding requires a `+` on each username; removing requires `-` or `!`:

```bash
glab mr update 42 --reviewer '+carol' # adds carol, everyone else stays
glab mr update 42 --reviewer 'carol'  # carol is now the ONLY reviewer
glab mr update 42 --reviewer '-carol' # removes carol, everyone else stays
```

`--assignee` behaves identically, and `--unassign` clears assignees outright.

This is the opposite shape from `gh`, which has separate `--add-reviewer` and `--remove-reviewer` flags and therefore cannot strip anyone by accident. An instruction phrased "add the reviewer the user picked", written once to cover both skills, is correct on GitHub and destroys the reviewer list here. **Never write one rule covering both forges.** The bare form is never used in update mode.

Removal is available and is always an explicit choice by the user, offered only when they ask for it, and it goes through Step 0's hard exception.

The Reviewers question in update mode excludes people already on the merge request from its recommended options — they are already there — and says who those are in the question text.

**When no field would change**, say so and issue no update at Step 9. An update that changes nothing still produces activity every watcher of the merge request sees. This does not affect pushing the branch or bringing it up to date, which Step 5 governs.

**Step 5 — Rebase onto target.** Source branch MUST rebase onto the chosen target before the MR is created — MR reflects a clean, up-to-date diff, and Step 7's generated description is built from post-rebase commits/diff.

**In update mode, probe first.** Rebasing and force-pushing rewrites the branch's published history, which detaches review threads from the lines they point at. The comments survive; the code they were about does not. So before rebasing, establish whether the selected merge request carries **review activity**:

```bash
glab api "projects/:id/merge_requests/<iid>/approvals"
glab api "projects/:id/merge_requests/<iid>/discussions"
```

**Review activity** means an approval, or a discussion whose notes carry diff position — a thread attached to a line of the change. A plain conversation comment on the merge request is **not** review activity, and neither is anything a bot posted: neither is anchored to a commit, so neither is broken by a rewrite. Counting them would suppress the rebase on nearly every run, and on a project with pipeline bots that comment it would suppress it from the first push onward — which is indistinguishable from removing the rebase.

Review activity **present** → do not rebase, do not force-push. Report the suppression, its reason, and these alternatives: let GitLab report any conflict on the merge request page itself; merge the target into the branch rather than replaying the branch onto it; or rebase deliberately once the review threads are resolved. Carry all of that into Step 8's summary, not only into passing output — a decision the user reads once in transient text is a decision they did not make.

Review activity **absent**, or create mode → rebase and force-push exactly as below. The create path is unchanged.

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

**Update mode: the existing description is read before anything is proposed.**

```bash
glab mr view json --jq '.description' < iid > --output
```

`glab mr update --description` and `--description-file` **replace the description outright.** There is no append mode in `glab` and no merge on GitLab's side. The description is where reviewers tick checklist items and where people write notes they were asked to record, and none of that is recoverable once overwritten. This is the only irreversible thing this skill can do.

Live description identical to what this run would generate → no change; say so and move on.

Otherwise show the difference and ask with `AskUserQuestion`, `header: "MR desc"`:

1. `Leave it as it is (Recommended)` — the description is not touched. Recommended because a description that differs from the generated one usually differs because a person changed it.
2. `Append an update section` — the existing text is untouched and new content is added below it, inside this skill's fence.
3. `Replace it entirely` — the generated description replaces everything, including any hand-written text and any ticked checkbox. Say that in the option description, in those words.

**The fence.** An appended section is delimited by a begin and an end HTML comment naming this skill:

```markdown
<!-- ccd-gitlab-mr:begin -->

... generated content ...

<!-- ccd-gitlab-mr:end -->
```

Both markers are invisible when GitLab renders the description, so they cost the reader nothing. Exactly one well-formed pair — one begin, one end, begin first — means replace the text between them and leave everything else alone. **Anything else means the region was not found**: one marker without its partner, more than one pair, or an end before a begin. Report what was found and append a fresh section. Never infer the missing boundary from surrounding content, and never delete a region this skill did not write.

Step 0's hard exception applies: a blanket skip-approval phrase does not reach this question when the live description is non-empty.

**Step 8 — Approval gate.** Present the full structured summary: source, target, assignee, reviewers, delete-source-branch, squash, rebase outcome (clean or how conflicts were resolved), generated title, generated description, which template was used, and — when Step 1 found one — the worktree path this MR is being raised from. Then ask with `AskUserQuestion`, `header: "Open MR?"`: `Yes` (create the merge request now) / `No` (stop, create nothing). Step 0 matched → display the summary and proceed without asking.

**In update mode the summary is a different shape**, and says so in its first line — a reader must be able to tell an update from a creation without inspecting the fields. Lead with the merge request's internal id, URL and state, then list **each of the five fields with its current value and its proposed value**, and name the ones that are not changing rather than omitting them silently. Include Step 5's rebase outcome or its suppression with the reason, the description decision that was taken, and the worktree path when there is one. The question becomes `header: "Update MR?"`: `Yes` (apply these changes to MR !N) / `No` (stop, change nothing).

**The values shown are the values read during this run.** GitLab is a shared system and the merge request can move underneath a run — someone merges it, closes it, or edits the description between Step 1's read and Step 8's approval. Before applying at Step 9, re-read the fields being changed. Where any differs from what was displayed, do **not** apply over the newer state: report what changed, and ask again with the fresh values.

Nothing about `Yes` here means "create as well as update". Update mode never creates a second merge request.

**Step 9, update mode — Update the MR.** One `glab mr update` call, carrying **only** the flags whose field actually changed. A flag passed with the value already on the merge request is not harmless: `--description-file` with an unchanged description still rewrites it, and every flag passed widens the blast radius of a mistake.

```bash
printf '%s\n' "$description" > "$tmp"
glab mr update '<iid>' \
  --title '<title>' \
  --description-file "$tmp" \
  --target-branch '<target>' \
  --reviewer '+<user1>,+<user2>' \
  --assignee '+<user>' \
  --yes
```

- **Every username carries its `+`.** A bare `--reviewer 'alice'` replaces the whole reviewer set with alice. This is the defect this skill exists to prevent; see Step 4.
- `--description-file`, never an inline `--description "$(cat …)"`: a generated description contains backticks and `$`, and a double-quoted argument runs them.
- There is **no flag for the source branch.** It cannot be changed after creation. If the source is wrong, the merge request is the wrong one.
- No `--draft`, `--ready`, `--squash-before-merge`, `--remove-source-branch`, `--label`, `--unlabel` or `--milestone`: all outside the five fields, all available, all deliberately unused here.

No field changed → issue no call at all, and report that the merge request was already up to date.

Report the merge request's URL, its internal id, and which fields were changed.

**`glab` unavailable, update mode** → MCP `mcp__plugin_gitlab_gitlab__save_merge_request` with `merge_request_iid` **supplied**. That field alone decides update versus create, and this is the exact inverse of the create path's rule below: **omitted creates, supplied updates**, and each direction fails silently into the other rather than erroring. Omitting it here opens a second merge request; passing it there edits an existing one. Verify with `mcp__plugin_gitlab_gitlab__get_merge_request` rather than trusting the response.

**Step 9, create mode — Create the MR.** One `glab` call does everything, assignee and reviewers by **username** — no ID resolution needed.

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
- Never create or update the MR before Step 8 returns `Yes`.
- Creates and updates MRs. Never reviews, approves, merges, or closes one.
- Never open a second MR for a branch that already has an open one to the same target — that is what Step 1b exists to prevent, and GitLab would reject it anyway.
- **Never pass a bare username to `--reviewer` or `--assignee` in update mode.** The `+` prefix is what makes it an addition; without it the flag replaces the whole set.
- Never replace an MR description that contains content a person wrote without an explicit answer to Step 7's question. There is no undo.
- Never change draft state, squash, delete-source-branch, labels or the milestone on an existing MR. Five fields, no others, however many flags `glab mr update` offers.
- Never rewrite the branch's published history when the MR carries review activity.
- Never read a failed detection call as "no MR exists".

## Tool Reference

`glab` is the primary tool: it covers MR creation, assignees, reviewers, squash, and remove-source-branch in a single call. The GitLab MCP server (`mcp__plugin_gitlab_gitlab__*`) is the fallback when `glab` is absent or unauthenticated. Probe which MCP tools this session actually exposes rather than assuming a name — that server's surface has changed, and a tool called from memory fails as "tool not found" at the last step of the run.

| Operation                         | Command                                                                                           |
| --------------------------------- | ------------------------------------------------------------------------------------------------- |
| Current branch                    | `git rev-parse --abbrev-ref HEAD`                                                                 |
| Branch on remote                  | `git ls-remote --heads origin <branch>`                                                           |
| Candidates for branch, all states | `glab mr list --source-branch <branch> --all --output json`                                       |
| Existing MR's description         | `glab mr view <iid> --output json --jq '.description'`                                            |
| Review activity on an MR          | `glab api projects/:id/merge_requests/<iid>/approvals` and `.../discussions`                      |
| Update an MR                      | `glab mr update <iid> --yes` (see Step 9, update mode)                                            |
| Reopen a closed MR                | `glab mr reopen <iid>` — a merged MR cannot be reopened                                           |
| Update an MR, fallback            | MCP `save_merge_request` with `merge_request_iid` supplied                                        |
| Push branch                       | `git push -u origin <branch>`                                                                     |
| Fetch target                      | `git fetch origin <target>`                                                                       |
| Rebase onto target                | `git rebase origin/<target>`                                                                      |
| Push rebased branch               | `git push --force-with-lease origin <source>`                                                     |
| Target candidates                 | `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh`                       |
| Member candidates                 | `sh <skill-dir>/scripts/member-options.sh` (wraps `glab api projects/:id/members/all --paginate`) |
| Current user                      | `glab api user`                                                                                   |
| Create MR                         | `glab mr create` (see Step 9)                                                                     |
| Create MR, fallback               | MCP `save_merge_request` with `merge_request_iid` omitted                                         |

Every command and flag in this table, what it does, and the `glab` version it was verified against are recorded in [`docs/forge-review-requests.md`](../../docs/forge-review-requests.md), together with the GitHub equivalents and the places the two forges differ — including the reviewer prefix. Check a claim there before changing one here.

Neither `glab` nor the GitLab MCP server available → the same operations map to the REST API: `POST /projects/:id/merge_requests`, `PUT /projects/:id/merge_requests/:iid`, `GET /projects/:id/repository/branches`, `GET /projects/:id/members/all`.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** No skill in this plugin carries it, and none may — the count is a contract at `specs/010-bug-run-ship/contracts/skill-names.md`. The field blocks the `Skill` tool, not merely automatic loading. **Two** callers dispatch this skill through exactly that tool on a GitLab remote — `ccd-speckit-run` at its Step 6b and `ccd-speckit-bug-run` at its Step 4b; a GitHub remote sends both to `claude-code-devkit:ccd-github-pr` — so setting the field breaks either handoff silently, and only at the very end of a long run. The same applies to `user-invocable: false`, which would take away the `/ccd-gitlab-mr` invocation this skill is designed around.
