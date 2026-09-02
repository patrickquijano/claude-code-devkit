---
name: auto-branch-push
description: Use when the user wants a new branch created from a chosen remote branch, named from the current changes, and pushed to the remote — e.g. "create a branch for this", "branch off main and push", "make a new branch from develop for these changes". Not for committing changes, and not for opening a merge request.
---

# Auto Branch & Push

Creates a conventionally-named branch off a user-chosen base branch, checks it out, and pushes it — named from the current working tree's changes.

## When NOT to use

- User wants to commit on the _current_ branch — use `claude-code-devkit:auto-commit-push` instead.
- User already gave the exact branch name and base and just wants a one-shot `git checkout -b` / `git push` — this skill's overhead (base selection, naming inference, approval gate) isn't needed.

## Asking the user

Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled "confirm?".

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

Two calls is the target for a clean run: one for the base branch (Step 3), one for the approval gate (Step 6). A named base the script confirms drops the first. A convention conflict at Step 4, a name collision at Step 5b, or a repo with no `origin` each add one — all three are conditional, and none of them fires on a clean run.

Bundled `scripts/` paths below are relative to **this SKILL.md's own directory**, not the repo you are working in. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch. Ask at Step 6 anyway and say why the skip was not honored.

Honored → skip the **Step 6** wait, still show the summary, and **name the phrase that triggered the skip** so the user can see the inference that was made. Not honored, or no match → always wait for approval.

**Step 1 — Preflight.**

```bash
git rev-parse --is-inside-work-tree
git remote                               # is there any remote at all
git remote get-url origin                # is there an `origin` specifically
git rev-parse --git-dir --git-common-dir # these differ inside a worktree
```

Stop and say why, rather than proceeding, when any of these holds:

- Not inside a git work tree (`sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh` exits 1 and says so).
- No remote configured — the Step 7 push has nowhere to go.
- **No remote named `origin`.** Step 7 pushes to `origin` by name, so a repo whose only remote is `upstream` or `fork` passes a bare "is there a remote" check and then dies at the push, after the approval gate. Name the remotes that do exist and ask with `AskUserQuestion` which to push to, or stop. Never assume the single remote is `origin` — use the name the user picked everywhere Step 7 says `origin`.

A detached HEAD is **not** a blocker: the new branch is cut from the Step 3 base, not from HEAD. Note it in the Step 6 summary and continue.

**Worktree.** `--git-dir` and `--git-common-dir` differing means this is a linked worktree, not the main checkout. Nothing this skill does changes — `git switch -c` acts on the tree it is invoked in, and a base branch checked out in _another_ worktree is no obstacle, because the new branch is cut from that base's commit rather than checking the base out. What changes is what the user needs told: **Step 6's summary names the tree whose `HEAD` is about to move**, because with several worktrees open, "created and checked out" is ambiguous about where. Record the worktree path in Step 1 and report it there.

**Step 2 — Inspect current changes.** Used only to infer intent for naming; this skill never commits — any uncommitted changes simply travel with the checkout, which is standard git behavior.

```bash
git status --porcelain=v1
git diff
git diff --cached
```

**Step 3 — Pick the base branch.** Run the bundled ranking script and take the **top four** lines as the option set:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh"
```

Output is tab separated, repo default branch first then newest commit first: `<branch>  local|remote|both  <YYYY-MM-DD>  <tags>`, where `<tags>` is a comma-joined subset of `default` and `current`, or `-`.

Present those four via `AskUserQuestion`, `header: "Base"`. The line tagged `default` goes first with `(Recommended)` — it is the repo's own integration branch. Each `description` names the branch's last-commit date and whether it lives locally, remotely, or both, so the user can tell a stale branch from a live one. Say in the question text when there were more than four candidates.

Skip this question entirely when the invoking prompt already names an explicit base and the script's output confirms it exists. Named but absent from the output → ask, never invent it.

**Step 4 — Detect repo-native branch conventions.** Scan the Step 3 branch names for a shared prefix pattern (`feature/`, `users/<name>/...`, `JIRA-123-...`) and check `CONTRIBUTING.md` / repo `CLAUDE.md` for an explicit branching rule. Found → it overrides the default type vocabulary in Branch Name Rules below.

Found convention **contradicts** a hard rule (the 72-character cap, the no-attribution rule) → resolve it with `AskUserQuestion`, `header: "Convention"`, three options: follow the repo convention (recommended, quoting the observed evidence — the repo's own rule beats this skill's default), follow this skill's hard rule (justify: keeps names short and tool-friendly, at the cost of diverging from the repo), or abort so the user can decide out of band. Never pick a side silently.

**Step 5 — Derive the branch name.** `type/kebab-case-description`, from the Step 2 diff plus the user's own instructions. Infer `type` from the nature of the change — new code → `feat`, bug patch → `fix`, docs-only → `docs`. See Branch Name Rules below.

**Step 5b — Check the derived name is free.** Before the gate, never after it.

```bash
git show-ref --verify --quiet "refs/heads/<name>" # exists locally?
git ls-remote --heads origin "<name>"             # exists on the remote?
git worktree list --porcelain                     # and if local, checked out where?
```

`git switch -c <name>` is fatal on a name that already exists — `fatal: a branch named '<name>' already exists` — and it is equally fatal when that branch is checked out in **another worktree**, since the branch existing at all is what it objects to. Reaching Step 7 without this probe means the run asks for approval, gets it, and then dies; the user has approved something that was never possible.

Free everywhere → say so in the Step 6 summary in one line and continue.

Taken → this is a decision, not an error. Ask with `AskUserQuestion`, `header: "Name taken"`, stating **where** it is taken — local, remote, both, and the worktree path when `git worktree list` shows one, because "checked out in ../hotfix" is what tells the user this is their own parallel work rather than a stale leftover. Three options: a suffixed variant this skill derives and has verified is free, recommended first, quoting the new name; switch to the existing branch instead of creating one — offered **only** when the existing branch is not checked out elsewhere, since git cannot check the same branch out twice; or stop so the user can name it themselves. Never overwrite, never `-B`, never `--force`, and never quietly append a number without saying the original was taken.

**Step 6 — Approval gate.** Present a structured summary — base branch, new branch name and that it was verified free, remote target, the tree whose `HEAD` will move (with its worktree path when Step 1 found one), and whether uncommitted changes are travelling with the checkout — then ask with `AskUserQuestion`, `header: "Create?"`: `Yes` (create, check out, and push this branch) / `No` (stop, change nothing). Step 0 matched → display the summary and proceed without asking.

Step 5b's own question is **not** covered by the Step 0 skip check. It decides what gets built rather than whether to proceed, and a collision resolved by inference is a branch under a name the user never saw.

**Step 7 — Execute.** Create and check out the new branch from the chosen base, then push with upstream tracking.

```bash
git switch -c <name> <base>
git push -u origin <name>
```

`git switch -c` rather than `git checkout -b`: same semantics, same fatal on a name that already exists, and it is the spelling used across this skill family. A base tagged `remote` only exists as a remote-tracking ref, so track it explicitly:

```bash
git switch -c <name> --track origin/<base>
```

Push to whichever remote Step 1 established, not to the literal word `origin` when the repo does not have one.

## Branch Name Rules

Hard rules, no deviation:

- Conventional format: `type/kebab-case-description`. Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `hotfix`, `release`. A repo-native prefix detected in Step 4 overrides this vocabulary.
- Imperative, describes the change.
- **Max 72 characters total** — hard cap, whole branch name.
- No attributions, no filenames in the name, no unnecessary special characters (letters, digits, hyphens, and one slash only).

## Boundaries / Safety

- Never force-push (`git push -f` / `--force`) the new branch.
- Never discard uncommitted changes to make the checkout succeed. `git switch -c` errors on a conflict with the base → stop and ask with `AskUserQuestion`; don't stash or discard unasked.
- Never reuse or overwrite an existing branch name. No `git branch -f`, no `git switch -C`, no silent numeric suffix — Step 5b asks instead.
- Never leave the tree this skill was invoked in, and never act on another worktree. `git switch -c` moves this tree's `HEAD` and no other; a base checked out elsewhere is read for its commit and left alone. No `cd`, no `git -C`, no `git worktree add`.
- Never invent a repo-native convention that contradicts one actually observed in Step 4 — route it through Step 4's conflict question.
- Never create the branch before Step 6 returns `Yes`.

## Tool Reference

Native `git` is the default. Check the live tool list for an active `mcp__git__*` server first — some repos configure one, most don't — and prefer it for the read-only status and diff calls when present (`git_status`, `git_diff_unstaged`, `git_diff_staged`, `git_create_branch`, `git_checkout`).

Branch listing and pushing have no MCP equivalent on the reference git server, so they always use native git: `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh` and `git push -u origin <name>`. Step 5b's collision probe is native git too — `git show-ref`, `git ls-remote`, `git worktree list` have no MCP counterparts, and `git_create_branch` reports its own failure too late to be a probe.

A custom `git-commit-server` MCP exists in some projects. It only exposes commit-message drafting, nothing relevant to branching.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.

**Never add `disable-model-invocation: true` to this skill's frontmatter.** That field blocks the `Skill` tool, not merely automatic loading. Nothing dispatches this skill today, but `auto-gitlab-mr` names it as the alternative for a push with no merge request, so a future handoff through that tool is the expected direction — and the field would break it silently, at dispatch time rather than at install time. `user-invocable: false` is wrong for the opposite reason: it would remove the `/auto-branch-push` invocation this skill is built around.
