# Step 0 — Preflight

Verify every command exists before executing anything. Nothing runs, nothing written, until this passes.

## Resolve the skill directory

`scripts/` is relative to this skill's own directory, not the repo being worked on. Resolve the absolute path once — the directory holding `SKILL.md`, which for this plugin is `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run` — and record it as `skill_dir`. Every later step invokes `sh <skill_dir>/scripts/<name>.sh` and reads the path from state rather than re-deriving it.

## Resolve the naming form

Spec Kit ships each command two ways: `/speckit.specify` (slash command) and `speckit-specify` (skills mode). Resolve which form this session has once, from the available skills and commands listing, reuse it every phase. Record as `command_form`.

## Resolve all eight

Up front, not lazily per phase: `constitution`, `specify`, `clarify`, `checklist`, `plan`, `tasks`, `analyze`, `implement`. Report a table: phase / resolved invocation / found or missing.

- **All eight found** — record the naming form, continue.
- **None found** — stop. Tell the user to run `specify init`, or install the Spec Kit integration for this agent. Never emulate the phases by hand.
- **Some missing** — stop, ask with `AskUserQuestion`, naming exactly which. Options: install the missing pieces and re-run (recommended), or proceed with the available subset, stating which guarantees are lost. State the loss concretely: without `analyze`, spec ↔ plan ↔ tasks drift reaches `implement` unchecked; without `clarify`, `[NEEDS CLARIFICATION]` markers reach the plan.

Resolve up front — the expensive failure is finding `implement` missing after a branch, a spec, a plan, and a task list already exist.

## Probe optional tooling

Same step. Record under `tooling`:

- `lean-ctx` `ctx_*` MCP tools, and `graphify` — see `reference/tooling.md`.
- **A subagent type for delegated sweeps**, resolved from the session's own agent listing and recorded as `tooling.subagent`: the name of a read-only explorer agent if one is listed, else a general-purpose one, else `none`. Resolve it here, not at dispatch time, and never hardcode a plugin's agent name — one that is absent fails mid-run, at Fan-out 1, where the alternative is a run that has already spent four phases. `none` is a normal result: the sweeps then happen inline and nothing else changes. See `reference/subagents.md`.
- **The forge this repo ships to, and the review skill that matches it.** Step 6b raises a merge request on GitLab and a pull request on GitHub, through two different sub-skills. Which one — if either — is decided here, from the remote, never from the task description or from what the last repo used:

  ```bash
  sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh"
  ```

  Record its `forge`, `host`, `review-skill`, `cli`, `cli-status` and `verdict` lines as `tooling.forge`, `tooling.forge_host`, `tooling.review_skill`, `tooling.forge_cli`, `tooling.forge_cli_status` and `tooling.forge_verdict`. `github` and `gitlab` each name their sub-skill; `other` and `none` name none, and both are ordinary results — a Bitbucket remote, a local bare origin, or no remote at all means this run has no review-request step and nothing else changes. Never re-derive the host in prose: that script handles scp-like URLs, embedded credentials, ports, and the self-hosted case where the hostname says nothing and a configured `glab` or `gh` is the only evidence.

- **The skills Step 6 hands off to. Probe them, do not assume them** — a `Skill` tool call for a skill that is not installed fails at 6a or 6b, after the whole pipeline has run. Probe the review skill the line above named, and the commit skill, which is forge-independent:

  **The session's own available-skills listing is the probe, and it is authoritative.** Look for each companion there, under the plugin-namespaced form `claude-code-devkit:<name>` or under the bare name. Record which form resolved; Step 6 dispatches that form. A filesystem test is not the probe and never the sole evidence of absence — where a skill's files live is an install detail, and a companion can be listed and dispatchable with nothing on disk where a probe thought to look.

  Only if the listing is unavailable or inconclusive, corroborate against what this plugin ships beside itself:

  ```bash
  # corroboration only; an empty result is "cannot determine", not "missing"
  ls "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr/SKILL.md" 2> /dev/null   # 6b, GitLab remote
  ls "${CLAUDE_PLUGIN_ROOT}/skills/ccd-github-pr/SKILL.md" 2> /dev/null   # 6b, GitHub remote
  ls "${CLAUDE_PLUGIN_ROOT}/skills/ccd-commit-push/SKILL.md" 2> /dev/null # 6a's commit option dispatches this
  ```

  These three companions ship in the same plugin as this skill, so `${CLAUDE_PLUGIN_ROOT}` reaches them without naming an install location. **Do not substitute a hard-coded personal path**: writing one in makes the probe answer "missing" for every install form but that one, and a companion wrongly recorded as missing is not a loud failure — it silently drops 6a's commit option and skips 6b, so the run reports success having produced neither a commit nor a review request. Where neither the listing nor this corroboration can settle it, record the companion as **undetermined** and treat it as present: a dispatch that fails is visible, and a probe that guessed absence is not.

  Record each as found or missing under `tooling`, together with the name form that resolved.

  **Why the namespaced form, and why that settles the ambiguous case.** A plugin's skills are addressed as `<plugin-name>:<skill-name>`, so `claude-code-devkit:ccd-commit-push` names exactly one skill: the one this plugin ships. A bare `ccd-commit-push` names whatever the session resolves that word to, and on a machine that has both a personal copy and the plugin installed, which one wins is not something this skill can determine or should depend on. Dispatching the namespaced name makes Step 6 deterministic under either install form and under both at once. Bare companion names still appear in the prose below where they describe a skill rather than address one; the namespaced form is what is dispatched and what `tooling.review_skill` holds. The **matching** skill missing → 6b is skipped with that reason; the other one's absence is irrelevant and is not reported as a problem. Missing `ccd-commit-push` → 6a's question drops its commit option and offers only "open anyway" or "stop", and says why.

- **`/init`, and whether a project `CLAUDE.md` already exists** — Step 2b needs both. `/init` is a built-in reached through the `Skill` tool, so confirm it in the session's own command listing rather than assuming it; record as `tooling.init`. Unavailable only matters on Step 2b's Branch A, and it degrades that branch to a reported skip, never to a hand-written substitute.

  ```bash
  ls CLAUDE.md .claude/CLAUDE.md 2> /dev/null # project instructions, either location
  ls AGENTS.md .cursorrules .github/copilot-instructions.md 2> /dev/null
  ```

  Record which exist. An `AGENTS.md` with no `CLAUDE.md` is the case Branch A handles with an import rather than a generated file, per `reference/claude-md.md`.

- Whether the working directory is a git repo at all — Step 1 needs it.
- Whether `git worktree` works, whether the repo has submodules (`test -f .gitmodules`), whether the session is already inside a worktree, and whether `EnterWorktree` exists in this session. These are Step 1b's restriction probes, listed in `reference/worktree.md`; run them here so 1b can offer or withhold the worktree option without a second round of probing.

None of it blocks the run; a missing piece degrades its step to a reported skip. Say so once at the prompt-review gate — including which forge was detected and which review skill will therefore be dispatched — so the user knows before Phase 1 whether this run ends in a merge request, a pull request, or neither.

## Detect a run already in progress

Twin of the failure above: silently redoing four phases of finished work.

`resume-state.sh` exits 1 with `not-a-git-repo` outside a work tree, and a run outside one is supported — Step 1 skips itself rather than stopping. So probe git first, and when the working directory is not a repo, record `resume: skipped: not a git repo`, treat the run as fresh, and continue to the state file. That exit is a condition to branch on, never a preflight failure.

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/resume-state.sh"
```

Reports whether this tree is a worktree, whether `.specify/.speckit-run-state.json` exists here, **whether one exists in a sibling worktree**, the current spec directory, which of `spec.md` / `plan.md` / `tasks.md` / `checklists/` exist, checked-off task count, suggested resume point.

- State file present → authoritative. Read it, report the last completed phase, ask with `AskUserQuestion`: resume from the next unfinished phase, restart from Phase 1, abandon the previous run, or stop. A non-null `stash_ref` is reported alongside it — a previous run parked the user's uncommitted work and could not restore it, and that has to be said before anything switches branches again.
- **`state-file-elsewhere` lines present** → a previous run was in worktree mode and its state lives in that worktree, not here. `state-file absent` in this tree is therefore not a fresh run, and treating it as one restarts Phase 1 on top of eight finished phases. Report the path and the mode, and ask with `AskUserQuestion`: enter that worktree and resume there — `EnterWorktree(path: …)`, then re-run this probe from inside it — start a fresh run in this tree alongside it, or stop. Recommend entering. Never read or write another worktree's state file from here; resuming a run means being in the tree that run was happening in.
- State file absent but a spec directory exists → a run happened without this skill, or the file was deleted. Report the artifact inventory and the script's suggested resume point, ask the same question.
- Nothing found, here or in a sibling worktree → fresh run.

### Abandon

Resuming and restarting both assume the previous run is wanted. Sometimes it is not, and leaving it in place means the next run inherits a state file, a dirty snapshot, a feature branch, and a spec directory that describe work nobody intends to finish — `resume-state.sh` will keep offering it every session.

Abandoning is a deletion, so it is proposed rather than performed. List, from state and from disk, exactly what would go:

- `.specify/.speckit-run-state.json` and `.specify/.speckit-dirty-snapshot` — this skill's own bookkeeping, always safe to remove.
- The spec directory it names, with its file count — **committed artifacts, not scratch.** Deleting them discards the spec, plan and task list.
- The feature branch, if one exists, with the `cleanup-plan.sh` verdict for it.
- The worktree named in `worktree.path`, if the abandoned run was in worktree mode — a **whole working directory**, whose uncommitted contents exist nowhere else. It is listed so the user can see it, and it is **never** removed here: 6d owns worktree removal and its safety rules, and this is not that step.
- Any `stash_ref`, which is **never** dropped here whatever the answer.

Confirm with `AskUserQuestion`, recommending the narrow option first: remove only the bookkeeping and leave every artifact and branch in place. That un-sticks the resume prompt without destroying anything a run produced. Removing the spec directory or the branch is a separate, explicit choice, and neither happens on the same answer as the bookkeeping. Never delete a branch here — 6c owns branch deletion and its rules, and this is not that step.

## Write the state file

Create `.specify/.speckit-run-state.json` per `reference/run-state.md` with `task`, `command_form`, `skill_dir`, `tooling`, `steps.0 = "done"`. Every later step reads it before acting.

`tooling.forge` and `tooling.review_skill` are read at Step 6b, six phases and at least one compaction later. Written here and nowhere else, they are what stops that step from guessing a forge from the task description — which is how a GitHub repo gets a `glab` invocation.
