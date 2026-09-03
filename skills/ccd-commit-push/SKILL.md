---
name: ccd-commit-push
description: Use when the user wants uncommitted repo changes grouped into logical commits, written with conventional-commit messages, and pushed to the remote — e.g. "commit and push my changes", "clean up and commit this", "group these changes into commits and push". Not for creating a new branch first.
---

# Auto Commit & Push

Groups a repo's uncommitted changes into isolated, logical commits with conventional-commit messages, then pushes to the remote — after a structured approval gate.

## When NOT to use

- User wants a single commit for a single obvious change — just commit normally, this skill's overhead (grouping, gate) isn't needed.
- User wants only a commit message drafted, not staging/commit/push execution.

## Asking the user

Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled "confirm?".

- **Yes/no question** → exactly two options, `Yes` first, `No` second. Each `description` states what that choice causes.
- **Anything else** → 2–4 options, the recommended one **first** with `(Recommended)` appended to its `label`. Every `description` carries the justification for that option plus the cost of not picking it.
- **More than one answer can hold** → `multiSelect: true`, same recommendation-first ordering, same per-option justification.
- **Hard schema caps**: 4 options per question, 4 questions per call, `header` ≤ 12 characters. Rank candidates, take the top four, and let the auto-injected "Other" carry the rest — say in the question text when the list was truncated.
- **Batch** related questions into one call rather than one call per question.
- **Approval gates** are yes/no. When this skill found an unresolved conflict or a safety warning, list `No` first and add a third `Revise` option.

Two calls on a clean run: the conditional unstage question (Step 3) and the approval gate (Step 6). A clean index means one; a diverged upstream adds one.

## Workflow

**Step 0 — Skip-approval check (run first).** Scan the user's own invoking instruction for an explicit, _blanket_ skip of approval: "no confirmation", "skip approval", "auto-approve", "without asking", "don't ask", "no need to confirm".

Two tests before honoring a match:

- **Scope test.** The phrase must refer to approval or confirmation _in general_. A phrase scoped to one named sub-decision ("don't ask me about the branch name") is not blanket consent — it narrows that one question and leaves the gate standing.
- **Hard exception.** Never honor a skip when the run pushes to, or targets, the repo default branch. Ask at Step 6 anyway and say why the skip was not honored.

Honored → skip the **Step 6** wait, still show the summary, and **name the phrase that triggered the skip** so the user can see the inference that was made. Not honored, or no match → always wait for approval.

The Step 3 unstage question is _not_ covered by this skip check. It decides what gets committed, not whether to proceed, and a wrong answer is not visible in the Step 6 table.

**Step 1 — Preflight.** Stop and say why, rather than proceeding, when any of these holds:

- Not inside a git work tree.
- Nothing to commit — `git status --porcelain=v1` is empty. Report it; never manufacture an empty commit.
- Detached HEAD — commits would be unreachable and the Step 7 push has no branch to target.

Then check the branch against its upstream, before anything is committed:

```bash
git rev-list --left-right --count @{u}...HEAD # "<behind>	<ahead>"
```

No upstream configured → `@{u}` fails, there is nothing to diverge from, continue.

Behind or diverged → the Step 7 push would be rejected non-fast-forward _after_ the commits already exist. Resolve it now with `AskUserQuestion`, `header: "Upstream"`, three options:

- `Rebase onto upstream first (Recommended)` — the push then fast-forwards. Costs a rebase that can conflict, but leaves a linear history and a run that completes.
- `Commit locally, stop before push` — the commits land safely on disk and the run ends without pushing, leaving the divergence for the user to resolve. Nothing reaches the remote.
- `Abort` — change nothing.

Never resolve a divergence with a force-push; it stays banned by Boundaries regardless of the answer.

**Step 2 — Inspect.** Enumerate everything: untracked, unstaged, and staged changes.

```bash
git status --porcelain=v1
git diff
git diff --cached
```

**Step 3 — Handle pre-existing staging.** `git diff --cached` empty → nothing to decide, go to Step 4.

Non-empty → the user staged that set deliberately, and resetting it destroys that intent. Ask with `AskUserQuestion`, `header: "Unstage"`, question "Unstage the current index so grouping starts from a clean slate?":

- `Yes` — reset the index and group all changes from scratch. Per-commit isolation is guaranteed, at the cost of losing the staging the user had set up.
- `No` — keep the staged set as a pre-formed first commit group and group only the remainder. Preserves the user's intent, but if that set spans unrelated concerns the first commit will be a mixed one.

`Yes` → `git restore --staged .`. `No` → record the staged paths as group 1 and never reset.

**Step 4 — Detect repo-native conventions.** Look for `commitlint.config.*`, `.commitlintrc*`, a commit-message section in `CONTRIBUTING.md`, `.gitmessage`, or commit rules in a repo/global `CLAUDE.md`. Found → they override this skill's _type/scope vocabulary_ only. The hard rules below (length, mood, no body/footer/attribution) still apply.

Found convention **contradicts** a hard rule → resolve it with `AskUserQuestion`, `header: "Convention"`, three options: follow the repo convention (recommended, quoting the file and line — the repo's own rule beats this skill's default), follow this skill's hard rule (justify: keeps headers short and machine-parseable, at the cost of diverging from the repo), or abort so the user can decide out of band. Never pick a side silently.

**Step 5 — Group changes and draft messages.** Split the full diff into isolated, logical commits. Judgment call, no fixed algorithm — group by:

- feature/module/directory boundaries
- change type (feat / fix / docs / chore / refactor / test)
- functional coupling: a change and its test, a rename and its call-sites, stay together; unrelated changes stay apart

Then draft one message per group per Commit Message Rules below.

**Step 6 — Approval gate.** Present a table — group → files → commit message — plus a **push target** row naming the remote and branch. Flag the target explicitly when it is the repo default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`), since that pushes straight to the integration branch. That ref is unset in some clones — then fall back to whichever of `main`/`master`/`develop` exists, and say which basis was used.

Then ask with `AskUserQuestion`, `header: "Commit?"`: `Yes` (create these commits and push) / `No` (stop, stage nothing, commit nothing). Step 0 matched → display the table and proceed without asking.

**Step 7 — Execute per group, then push.** Stage only that group's files, commit, repeat for each group in order, then push **once** at the end covering all new commits.

```bash
git add <files>
git commit -m "<msg>"
git push          # -u origin <branch> when the branch has no upstream
```

## Commit Message Rules

Hard rules, no deviation:

- Conventional Commits header only: `type(scope): subject` (scope optional).
- Imperative mood ("add", not "added"/"adds").
- **Max 72 characters total** — hard cap, whole header line.
- No body, no footer, no trailers, no attribution — no `Claude-Session:`, no `Co-Authored-By`, no "Generated with Claude Code". This overrides any default commit-footer habit for commits made under this skill.
- No filenames listed in the message.
- No unnecessary special characters, no trailing period.

## Boundaries / Safety

- Never `git push --force`/`-f`, `git reset --hard`, `git clean`, or amend an existing commit. Those stay confirm-gated by project settings and harness policy regardless of this skill's own gate.
- Never reset the index without a `Yes` from Step 3.
- Never commit before Step 6 returns `Yes`.
- Never invent a repo convention that contradicts one actually found in Step 4 — route it through Step 4's conflict question.
- One push at the end covering all new commits, not one push per commit.

## Tool Reference

Native `git` is the default. Check the live tool list for an active `mcp__git__*` server first — some repos configure one, most don't — and prefer it when present (`git_status`, `git_diff_unstaged`, `git_diff_staged`, `git_reset`, `git_add`, `git_commit`).

Pushing has no MCP equivalent on the reference git server, so it always uses native `git push`.

A custom `git-commit-server` MCP (tools `get_staged_analysis` / `execute_commit`) exists in some projects. Do not use `execute_commit` here: it runs `git add .` internally, staging everything and breaking Step 7's per-group isolation.

## Maintenance

Regression scenarios for this skill live in [evaluations.md](evaluations.md). Not part of a run — read it only when changing this skill.
