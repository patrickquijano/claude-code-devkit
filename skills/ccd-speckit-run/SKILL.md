---
name: ccd-speckit-run
description: Use when the user invokes /ccd-speckit-run, or asks to take a feature end to end through GitHub Spec Kit spec-driven development from a single task description. Also use when an earlier Spec Kit run was interrupted and needs resuming.
---

# Spec Kit pipeline run

Task description: $ARGUMENTS

Eight Spec Kit phases from one description. Each prompt in its phase's style. Step 3 drafts all eight arguments together and shows them as a plan. **A boundary then either gates or announces**: it gates when it is irreversible or its argument changed since that plan, stating the command, the verbatim argument, the artifacts and the delta; otherwise it proceeds and prints one line saying which boundary and why it did not ask. Never skip a step, never merge two phases into one invocation, and never let a boundary pass in silence. Run ends verified and shipped — repo's own tests, review request, still on the feature branch — not at `implement`. **Review request** means a GitLab merge request or a GitHub pull request: Step 0 detects which forge `origin` points at and Step 6b dispatches the matching sub-skill, `claude-code-devkit:ccd-gitlab-mr` or `claude-code-devkit:ccd-github-pr`. A remote at neither forge is a normal result and skips that step alone.

Step 1 asks where the run happens: the current checkout, or a fresh git worktree that leaves the user's open tree untouched. Step 6 runs no `git add` or `git commit` of its own; where the work needs committing it dispatches `claude-code-devkit:ccd-commit-push`, which owns that decision.

Empty task description → use current conversation's request.

## Run state — read before acting, every step

Do not rely on this file still being here in full. A run spans eight phases and many turns; compaction re-attaches an invoked skill only up to a token budget, so the later half of this file is exactly what a long run loses first — and it is never re-read from disk. So run facts live in `.specify/.speckit-run-state.json`, not memory. Shape and rules: `reference/run-state.md`.

Before every step: read state, confirm predecessor `done` or `skipped`. Predecessor `pending` or `failed` → stop, name the unfinished step. After every step: update state, then ask the gate question.

State file beats memory. Base branch, command form, skill directory — read them.

## Progress checklist

Copy into your response, tick off as you complete them:

```text
- [ ] Step 0: preflight — eight commands resolved, tooling probed, forge detected, resume checked, state file written
- [ ] Step 1: workspace mode and base branch — both chosen by user in one call, worktree created and entered or branch switched, dirty tree snapshotted
- [ ] Step 2: task read — requirements, goals, non-goals identified, `steps.2` written
- [ ] Step 2b: project `CLAUDE.md` — created if absent, checked against the task if present, verdict reported (no change is the usual one)
- [ ] Step 3: eight phase prompts drafted together, leakage check applied across all eight, plan presented, `gate_mode` chosen and written to state
- [ ] Conflicts: checked at Step 2 and again at every step and phase boundary, each one resolved and recorded in `conflicts[]` and `conflict_checks[]`
- [ ] Sweeps: delegated where `reference/subagents.md` allows it, evidence only, no phase and no decision handed to an agent
- [ ] Gates: every always-gate boundary — Steps 1, 2b, 6 and Phases 2, 5, 8 — proposed and approved before executing, plus any phase whose argument changed
- [ ] Announcements: every boundary that proceeded without asking printed one line naming it and the reason — no boundary passed in silence
- [ ] Step 4: phases 1–8
      - [ ] Phase 1: constitution
      - [ ] Phase 2: specify
      - [ ] Phase 3: clarify
      - [ ] Phase 4: checklist
      - [ ] Phase 5: plan
      - [ ] Phase 6: tasks
      - [ ] Phase 7: analyze
      - [ ] Phase 8: implement
- [ ] Step 5: verify and resolve — check resolved, run, evidence shown, findings collected from all four sources, every one fixed or explicitly deferred
- [ ] Step 6: ship — uncommitted work reported and committed or explicitly left, review request raised through the forge's own sub-skill or skipped with a reason, local branches cleared, worktree teardown answered, still on the feature branch
- [ ] Step 7: final summary
```

## Reference map

Read a step's file before running that step. Each self-contained.

| File                        | Covers                                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `reference/run-state.md`    | state file — shape, who writes what, precondition rule                                                                         |
| `reference/preflight.md`    | Step 0 — command resolution, tooling probe, resume detection                                                                   |
| `reference/base-branch.md`  | Step 1 — branch pick, switch, dirty-tree snapshot                                                                              |
| `reference/worktree.md`     | Step 1 — checkout vs worktree, worktree create/enter/verify, Step 6e teardown                                                  |
| `reference/claude-md.md`    | Step 2b — project `CLAUDE.md`: create it, or test whether the task states a durable rule it lacks                              |
| `reference/prompt-rules.md` | Step 3 — what each phase's prompt argument may and may not contain                                                             |
| `reference/constitution.md` | Phase 1 — constitution states, amendment, semver                                                                               |
| `reference/conflicts.md`    | conflict detection and resolution — every phase                                                                                |
| `reference/tooling.md`      | mandatory `ctx_*` and `graphify` substitutions                                                                                 |
| `reference/subagents.md`    | delegating read-only sweeps — the threshold, the cap of ten, the fan-out points, agent selection, what must never be delegated |
| `reference/verify.md`       | Step 5 — resolving and running the check, bounded fix loop                                                                     |
| `reference/findings.md`     | Step 5e–5g — the finding register: collect from all four sources, resolve, gate                                                |
| `reference/ship.md`         | Step 6 — uncommitted-work check and commit dispatch, review request and its forge routing, branch cleanup, worktree teardown   |
| `reference/evaluations.md`  | scenarios to re-run after editing this skill                                                                                   |

## Scripts — run them, do not re-derive them

Deterministic git logic lives in `scripts/`. Those paths are relative to **this SKILL.md's own directory**, not the repo you are working in — the run's working directory is the target repo, where `scripts/` means something else or nothing at all. Invoke them as `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/<name>.sh` — the substitution variable a plugin's own files use to reach what they ship with, so the path holds wherever the plugin is installed and no install location is written down. Use `sh` explicitly; the executable bit does not survive every install path.

Step 0 resolves `<skill-dir>` once and records it as `skill_dir` in the state file. Every later step reads it from there rather than guessing the install location again.

Act on the printed table. Never reimplement their rules in prose, never override a verdict by hand.

| Script                                                                   | Prints                                                                                                                                                                                                                  |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh` | base-branch candidates: branch, local/remote/both, last commit date, `default`/`current` tags. Ships once, in `ccd-branch-push`, and is invoked from there by all four consumers — not from this skill's own `scripts/` |
| `scripts/dirty-diff.sh snapshot\|compare <file>`                         | records pre-run dirty paths, then splits today's into `pre-existing` / `new` / `internal`                                                                                                                               |
| `scripts/copy-env-files.sh <source-dir> <worktree-dir>`                  | worktree mode only: copies untracked local config (`.env*`, `appsettings*.json`, etc) from the original checkout into the new worktree                                                                                  |
| `scripts/cleanup-plan.sh [base]`                                         | per local branch: `delete` or `keep`, with reason                                                                                                                                                                       |
| `scripts/resume-state.sh`                                                | whether a run is already in progress, and where to resume                                                                                                                                                               |
| `scripts/forge-detect.sh`                                                | which forge `origin` points at, the review skill and CLI that match it, and a `ready` / `skip: <reason>` verdict                                                                                                        |

## Step 0 — Preflight

Nothing runs, nothing written, until this passes. Read `reference/preflight.md`.

Resolve all eight commands up front — `constitution`, `specify`, `clarify`, `checklist`, `plan`, `tasks`, `analyze`, `implement` — plus naming form. Probe optional tooling, git included. Run `<skill-dir>/scripts/forge-detect.sh` and record its verdict as `tooling.forge` and `tooling.review_skill`: that is the only place the forge is decided, and Step 6b reads it from state rather than detecting again six phases later. Inside a git repo, run `<skill-dir>/scripts/resume-state.sh` and offer a resume point if a run is already underway; outside one, that script exits 1 and resume detection is skipped, not failed. Write the state file. Any of the eight missing → stop, per `reference/preflight.md`.

## Step 1 — Workspace and base branch

Two decisions, one `AskUserQuestion` call. Read `reference/base-branch.md` and `reference/worktree.md`.

**Workspace.** Current checkout, or a fresh worktree off the chosen base. Worktree mode leaves the user's open tree untouched and stashes nothing; checkout mode switches that tree and can die on a stash collision. Recommend the worktree unless a restriction in `reference/worktree.md` rules it out. Worktree mode is `git worktree add --detach`, then `EnterWorktree(path: …)`, then **verify the session actually moved** — a worktree created and not entered runs all eight phases in the wrong tree while looking isolated. Then `scripts/copy-env-files.sh` carries the original checkout's untracked local config (`.env*`, `appsettings*.json`, and the rest) into the new worktree, since `git worktree add` only checks out tracked history.

**Base branch.** Phase 2 cuts the feature branch off `HEAD`, so the base is decided here, before any phase. Candidates from `${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh`, never enumerated by hand.

Then snapshot the dirty tree in whichever tree the run is now in. Not a git repo → skip the whole step, record reason, continue.

## Step 2 — Read the task

Extract from the task description: intent, actors, concrete requirements, explicit non-goals, constraints.

Extract stated tech choices separately, **hold back for Phase 5 (`plan`)**. A framework, language, datastore, or library named in a specify prompt corrupts the spec.

Use `graphify` and `ctx_*` per `reference/tooling.md` — check what the repo already does before assuming new work.

This is the run's widest read, and `reference/subagents.md` names it as a fan-out point: independent read-only sweeps — prior art, governance, existing artifacts, conventions, and more where the repository justifies them — dispatched in one batch of up to ten when the repo is big enough for the sweep to cost more than the dispatch. Evidence comes back here; every conflict block and every `conflicts[]` entry is written in the main run. A small repo, or a `graphify query` that already answers the question, needs no agent.

This step has no gate — nothing here is irreversible and there is nothing to approve. It still writes `steps.2 = "done"` when the extraction is finished, because Step 2b checks its predecessor and an unwritten key fails that check as surely as a failed step would.

## Step 2b — Project instructions: `CLAUDE.md`

After Step 2, before Step 3. Read `reference/claude-md.md`.

No project `CLAUDE.md` → create one. An `AGENTS.md` already in the repo gets a `CLAUDE.md` that imports it, `@AGENTS.md`, so both tools read one source; otherwise dispatch `/init` through the `Skill` tool — it is a built-in reachable that way, and prose naming it invokes nothing.

One exists → **the default is no change.** The question is narrow: does the task state a _durable working rule_ this file does not already record? A feature requirement is not a rule — it belongs in `spec.md`. An entry is warranted only when it is stated rather than inferred, outlives this feature, is not already recorded, and is **not derivable from the codebase**. Reporting "no change needed" with the reason is the common and correct outcome.

Content that is real but not `CLAUDE.md`-shaped gets placed, not stuffed: scoped to one area → `.claude/rules/<topic>.md` with `paths:` globs; a multi-step procedure → a skill, **proposed** rather than written here.

Two boundaries hold this step in place. `CLAUDE.md` is operational — commands, conventions, pitfalls; the constitution is normative — testable `MUST` principles the plan gates read. 2b writes none of the latter, and Phase 1 restates none of the former. And 2b records only what is **already true** of the repo, never what the task proposes, which is what keeps Phase 5's hold-back intact.

It writes a committed repo-wide file, so it takes the full proposal cycle. Never touches `~/.claude/CLAUDE.md`, a managed policy file, or a `CLAUDE.local.md`. Runs even outside a git repo. No outcome blocks the run.

## Step 3 — Draft all eight phase prompts up front

Read `reference/prompt-rules.md`, draft every phase's prompt argument before running any phase. Drafting together is what catches leakage between phases.

Present all eight in one block as the **plan**. Report there: command form, base branch from Step 1, constitution state from Phase 1's classification, active optional tooling, the detected forge and the review skill Step 6b will therefore dispatch — or that this run has no review-request step, with the reason — and conflicts already found per `reference/conflicts.md`.

**This step presents; it does not approve.** Approval belongs to each boundary that gates, at the moment it is about to run, per Step 4. What Step 3 owns is the **leakage check** in `reference/prompt-rules.md`, and that is why all eight arguments are drafted together and shown together: a technology leaking out of the plan prompt and into the specify prompt is invisible when the specify prompt is read alone.

**Narrowing the gates does not narrow this check, and never may.** Feature 006 required all eight arguments to be drafted together and checked across each other, and feature 011 supersedes only the requirement to approve each one — the leakage check still runs over all eight, here, every run, whatever `gate_mode` says and however few boundaries end up asking. A run that checks only the arguments belonging to boundaries that will gate has silently reintroduced the defect both features exist to prevent, because the specify prompt is in the auto-proceed set and is the prompt most often corrupted.

Step 3 approves nothing, but it does **ask one question**: how often the run should stop. `AskUserQuestion`, `header: "Gating"`, two options — `Narrowed (Recommended)`, which asks only at the always-gate set and where an argument changed, saying so at every boundary it skips; and `Every phase`, which asks at all thirteen. Recommend `narrowed`, and say why: the irreversible steps still gate either way, so `every-phase` buys confirmation of decisions already settled at the cost of the click-through it is meant to prevent. Write the answer to `gate_mode` in state **before Phase 1**, and read it from there at every boundary — a mode held only in the conversation is a mode a compacted run silently reverts.

Then report the plan and the leakage-check result, and go to Phase 1.

**On the objection this design used to make, and how it was finally answered.** An early version of this skill argued that gates work only while still read, and that twenty prompts trains click-through where two real ones do not. Feature 006 answered it with the delta row: every proposal states **what changed since this plan**, so an unchanged proposal is visibly unchanged. That was a real answer and the delta row survives.

It was not a sufficient one. A proposal that says "nothing changed since the plan" is still a proposal to read, and eight of them in a row is still the pattern the objection described. Feature 011 finishes the job: a boundary with nothing to decide no longer asks at all — it says what it is doing and why it did not ask. **The gate did not get better; there are simply fewer of them, and each survivor carries a decision that is genuinely still open.** The original argument is now spent rather than merely mitigated.

What it cost: a boundary can now proceed with no approval. That is bounded by the always-gate set, which no comparison and no mode can reach, and audited by the announcement line, which is never suppressed.

## Step 4 — Execute Phases 1–8

This order. **Each phase is proposed immediately before it runs. Whether that proposal is also gated depends on the rule below** — Step 3 drafted the arguments and checked them for leakage; this is where each one is either agreed to or announced.

### When a phase gates, and when it proceeds

The rule lives in one place, `specs/011-narrow-gates-pipeline-fix/contracts/gate-decision.md`, and nothing here or in `reference/` restates it. Evaluated fresh at each boundary; the first `true` decides:

1. **In the always-gate set?** → ask.
2. **`gate_mode` is `every-phase`?** → ask.
3. **Verbatim argument differs from Step 3's draft?** → ask.
4. Otherwise → **proceed without asking, and print why.**

**Record which rule fired, not only announce it.** Write the deciding rule to `gates[<boundary>]` in state as each boundary resolves — `always-gate`, `every-phase`, `argument-changed`, or `auto-proceeded` — alongside the reason the announcement line carried. The announcement is for the user reading the run; the record is for anyone checking afterwards that every approval was one of the two conditions and every unasked boundary was neither. **Output is not a record**: it scrolls past, it compacts away, and a run that only printed its reasoning cannot be audited once it has finished. `reference/run-state.md` carries the field.

**The always-gate set.** Membership is a property of the step, never of the run.

| Boundary            | Why                                                                     |
| ------------------- | ----------------------------------------------------------------------- |
| Step 1              | Creates a working directory, or moves the user's tree and may stash it  |
| Step 2b             | Writes a committed repo-wide instruction file                           |
| Phase 2 `specify`   | Cuts the feature branch                                                 |
| Phase 5 `plan`      | Fixes the approach everything later is built on                         |
| Phase 8 `implement` | Writes source                                                           |
| Step 6              | Commits, pushes, opens a review request, deletes branches and worktrees |

**A boundary in this set can never compute "do not ask."** No argument comparison, no `gate_mode`, no skip-approval phrase reaches it. That invariant is what keeps the run unable to reach implementation or any irreversible step without an approval given for that step — and it is why this skill still carries no `disable-model-invocation`.

**An approval does not survive an interruption.** Where a run stops between an approval and the step it approved — a compaction that loses the turn, a crash, a session ended and resumed — the resumed run **proposes that step again**. It never reads the recorded approval as still held. An approval is given against a state of the world the interruption may have changed: the tree may have moved, the remote may have advanced, the user may have done the work by hand. This is what makes the always-gate invariant worth anything; without it, a resumed run can execute an irreversible step whose approval was given against a repository that no longer exists. On resume, treat any boundary whose `gates[<boundary>]` entry exists but whose step never completed as **unapproved**.

A phase in the auto-proceed set — 1, 3, 4, 6, 7 — gates anyway the moment its argument was revised, a conflict resolution changed it, a preceding phase changed what it will receive, or it is about to be skipped for a reason the Step 3 plan did not carry.

**When an auto-proceeded phase fails, say that nobody approved it individually.** The failure report names the phase, the error, and the fact that this boundary proceeded under rule 4 rather than under an approval. Two things follow and neither is optional: the auto-proceed is **never** offered as a reason to continue past the failure — it is the opposite, since less was read before it ran than at a gated boundary — and the failure is **never** presented as though an approval had covered it. The narrowed gate is defensible only while the run is honest about which boundaries it did not stop at, and a failure is exactly when that matters.

### Announcing a phase that did not gate

**Silence is forbidden.** Before the phase runs, print one line naming the boundary and the reason:

```text
Phase 6 (tasks) — proceeding without asking: argument byte-identical to the approved plan, effect readily undone.
```

A boundary that proceeds with no line is a defect: it is indistinguishable from one that was forgotten. This line is not ceremony and is **out of scope for any compaction pass** — it is the mechanism by which a narrowed gate stays auditable.

### The proposal, when a phase does gate

State four things and nothing else:

|                            |                                                                                                                                                           |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Command**                | the command about to be invoked, in the naming form Step 0 resolved                                                                                       |
| **Argument**               | the **verbatim** argument. Never summarized, never truncated, never paraphrased — an approval given against a paraphrase is an approval of something else |
| **Writes**                 | the artifacts the phase will create or modify                                                                                                             |
| **Changed since the plan** | what differs from Step 3's draft, or the words "nothing changed since the plan" when nothing does                                                         |

That last row is now the most informative line in the proposal rather than a formality: under the narrowed rule, a Phase 1/3/4/6/7 proposal exists **because** something changed. Say it explicitly; silence there is indistinguishable from having forgotten to check.

Then `AskUserQuestion`: `Proceed` / `Revise` / `Stop`, with `Proceed` recommended and the reason stated — the argument was reviewed at Step 3 and the delta row says what moved since.

- **Proceed** → invoke the phase. Confirm its artifacts on disk, report, write `phases.N`.
- **Revise** → amend **only that phase's argument** from the user's note, re-propose it. No other phase's argument changes. After three revisions of one phase, stop and ask rather than loop.
- **Stop** → the run halts with accurate state on disk.

A **conditional phase about to be skipped is still reported** — the skip and its reason, at the point the phase would have run. A skip the Step 3 plan already carried is announced; a skip for any other reason is a difference from the plan and therefore gates. A skip is a decision about what will not happen, and it is never silent either way.

The proposal is not the place to re-argue the plan. It is the place to see what is about to run.

| Phase | Command        | Prompt argument                  | Notes                                                                                      |
| ----- | -------------- | -------------------------------- | ------------------------------------------------------------------------------------------ |
| 1     | `constitution` | governing principles             | conditional, idempotent — see `reference/constitution.md`                                  |
| 2     | `specify`      | WHAT and WHY only                | creates branch + `specs/NNN-slug/spec.md`                                                  |
| 3     | `clarify`      | the ambiguous areas              | conditional: only if spec carries `[NEEDS CLARIFICATION]` markers, or previous phase asked |
| 4     | `checklist`    | the validation dimension         | requirements completeness, clarity, consistency                                            |
| 5     | `plan`         | tech stack and architecture      | produces `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`          |
| 6     | `tasks`        | usually none                     | produces `tasks.md` with `[P]` parallel markers                                            |
| 7     | `analyze`      | none                             | cross-artifact consistency; after `tasks`, before `implement`                              |
| 8     | `implement`    | none, or an explicit scope limit | executes `tasks.md`                                                                        |

Skipping allowed only for conditional phases. Report a conditional skip when that phase comes up, with its reason, and record it as `skipped: <reason>`.

Phase 8 given a scope limit records it in the value — `done: scope-limited to <what>` — never plain `done`. Step 6 reads that prefix to know the run implemented part of `tasks.md`, and a limit stated only in conversation is one Step 6 cannot see.

## Proposal discipline: propose before executing

Applies to **the always-gate set** — Steps 1, 2b and 6, and Phases 2, 5 and 8 — and to any other phase whose argument changed since the plan. Step 1 switches branch carrying uncommitted changes or creates a worktree; Step 2b writes a committed repo-wide instruction file; Step 6 opens a review request, can dispatch a commit, deletes branches, and can remove a worktree; Phases 2, 5 and 8 cut the branch, fix the approach, and write source. Every one of these proposes for itself immediately before it runs — Step 3's plan is a draft to read, not an approval to spend.

Phases 1, 3, 4, 6 and 7 are outside it while their arguments are unchanged: they announce rather than ask, per Step 4. They are not exempt from the discipline, only from the gate — the proposal's content is still stated, in the announcement line.

1. **Propose, do not act.** Proposal states: exactly what will run, the files and branches it will create, modify or delete, and any conflict found. Each step's own reference file — `reference/base-branch.md`, `reference/ship.md` — names what else its proposal must carry. No write action until step 3.
2. **Approve with `AskUserQuestion`.** `Proceed` / `Revise` / `Stop`, each option saying what it does and costs, with one recommended and the reason given. Recommend `Proceed` where the proposal matches what was planned and the step is reversible; where the step deletes something or reaches a remote, say what is not undoable and let that carry the recommendation. That call _is_ the gate for this step; do not gate a second time before executing. Rejected → revise the proposal in place, re-submit, never proceed.
3. **Execute only after approval.** These steps switch branches, stash, push and delete. Nothing writes before approval.
4. **Propose again for each one.** Step 1's approval is not Step 2b's and neither is Step 6's; they are separated by phases, gates and often a compaction. One exception, stated in `reference/claude-md.md`: a 2b verdict of "no change needed" reports and continues without a gate, because changing nothing needs no approval.

## Report after every phase

Phase completes → confirm its artifacts exist on disk, report what changed and any unresolved markers, run the boundary check per `reference/conflicts.md`, update the state file, then propose the next phase. The reporting after a phase is not itself a stop; the gate is the next phase's proposal.

Confirming the artifacts is not optional just because nothing gates on it. `done` still means the files were seen on disk, never that the command appeared to succeed.

Before Phase 8 (`implement`), report `analyze`'s findings and every surviving `[NEEDS CLARIFICATION]` marker. Those are the facts a reader needs in order to interrupt on their own initiative, and `implement` is the last point where interrupting is cheap.

**Stop only when the phase needs attention this skill cannot give it.**

The default is silence: report and continue. What overrides that default is not a category of phase but a category of question — one whose answer is the user's to give, and which the next phase would otherwise inherit as a guess. The test is one line: **would proceeding require me to decide something that is not mine to decide, or to build on an artifact that is not there?** Yes → stop and ask with `AskUserQuestion`. No → report and keep going.

Two cases meet that test every time, and they are named because they are the ones that recur — not because they are the only ones:

- **A phase that errors or writes nothing does not advance.** Record `failed: <error>`, report the actual error output, then `AskUserQuestion`, `header: "Phase failed"`: retry unchanged, revise the prompt and retry, or stop. Recommend retrying unchanged when the error reads as transient and revising when it names something in the argument, and say which of the two the output supports. Continuing hands the next phase an artifact that does not exist. Never hand-write the artifact a phase failed to produce, never mark a phase `done` on the assumption it worked.
- **A conflict is resolved before the phase that hit it advances**, per `reference/conflicts.md`. That protocol asks because the choice is the user's — which artifact to change is not a decision this skill may make on its own. `analyze`'s findings are conflicts by this definition, so Phase 7 reporting drift is the most common way a real stop arrives.

Anything else that meets the test stops too, on its own merits — a phase that wrote its artifacts but reports it could not do part of the work, a `checklist` result that invalidates the spec the plan was built on, a scope limit the task never asked for. Judge these by the test, not by whether they appear above. Ordinary progress, an unremarkable phase result, and a marker you have already reported are not attention; stopping for those is the ceremony that was just removed.

"Revise" on a failed phase → amend that phase's prompt from the user's note, re-invoke the same phase, report again. After three revisions of one phase, stop and ask rather than loop.

## Step 5 — Verify and resolve

After Phase 8 completes. Read `reference/verify.md`, then `reference/findings.md`.

Resolve the repo's own check — constitution mandate, then `tasks.md`, then repo config, then CI. Run it, show actual output as evidence, fix and re-run at most three consecutive failures. No runner found → say so plainly. Never claim verification that did not happen.

A failing check or no check at all does not end the run, and does not silently continue it either. Shipping past one takes an explicit user decision, recorded as `verify.override` — Step 6 reads that field, not the conversation.

Then 5e–5g: a green check is not an empty register. Two of the four sources — surviving markers and unchecked `tasks.md` items — are read-only sweeps that `reference/subagents.md` allows delegating in one batch; the hook dispatch and the check output stay here, because one runs commands and the other is already in context. Severity and status are always written here. Collect every reported issue from all four sources — the `after_implement` hooks in `.specify/extensions.yml`, this check's own non-fatal output, surviving `[NEEDS CLARIFICATION]` markers, unchecked `tasks.md` items — and resolve each one. **A finding is addressed, never skipped.** Minor findings get an attempt like any other; the only other exit is a deferral you chose explicitly, recorded with its reason. One open finding and Step 6 does not run.

## Step 6 — Ship: commit check, review request, branch cleanup, worktree teardown

After Step 5's gate. Read `reference/ship.md`, and `reference/worktree.md` for 6e.

Ships only what Step 5 cleared: `verify.result` is `pass`, or `verify.override` records the decision to ship without it, **and** every finding reads `fixed` or `deferred`. Any of that unmet → back to Step 5, no review request.

**Step 6 runs no commit of its own.** No `git add`, no `git commit`, no inline substitute. 6a reports what is still uncommitted and what the review request would therefore carry, then asks — and one of its three answers dispatches `claude-code-devkit:ccd-commit-push` through the `Skill` tool, which owns the message, the split and the push behind its own gate. Step 6 delegates that decision; it never takes it. This matters because `implement` normally commits nothing, so without 6a's question the ordinary successful run ends with an empty `<base>..HEAD` and a review request carrying no diff. What the commit skill receives is the explicit path list 6a displayed, minus anything credential-shaped — `implement` writes files unattended, and handing over the dirty tree wholesale is how a generated key reaches the remote.

Raise the review request by dispatching the skill `tooling.review_skill` names — `claude-code-devkit:ccd-gitlab-mr` on a GitLab remote, `claude-code-devkit:ccd-github-pr` on a GitHub one — through the `Skill` tool, carrying the verification status into its description. **Read the forge from state; never re-detect it here and never infer it from the task.** That skill, its CLI, and a remote at a supported forge are all optional — any of them missing skips 6b with the reason recorded, per `reference/ship.md`, and the run still finishes. Hand that skill facts, never answers: the target or base branch, assignee, reviewers, and the forge's own merge options — squash and delete-source-branch on GitLab, draft and auto-merge on GitHub — are all its own. Then verify each postcondition with git rather than trusting the report, stay on the feature branch, delete only branches `<skill-dir>/scripts/cleanup-plan.sh` marks `delete` — **except the feature branch itself, which 6c keeps even when the script marks it `delete`**, because review has not happened yet. In worktree mode the script keeps it unprompted, since it is checked out there. Never reimplement what a sub-skill does.

Once 6b has returned a review-request URL, **6e** asks where to leave the workspace — one question, with the option set matching the mode. Checkout mode: stay on the feature branch (the default), switch to the target keeping the branch, or switch and delete it. Worktree mode: stay (the default), exit and keep, exit and remove, or exit and remove and delete the branch. Review has not happened, so the least-destructive option is the recommended one in both sets. The two guards differ — a branch deletion turns on unpushed commits, a worktree removal on any uncommitted path in that directory whatever its origin — and neither is ever covered by a skip-approval phrase.

## Step 7 — Final summary

Output, in this order:

1. Run table: phase / command invoked / artifacts written / recorded status. The last column is `done`, `skipped: <reason>` or `failed: <error>` from state — what the phase did, not the approval that let it run.
2. Conflicts table: conflict / evidence / chosen resolution. Omit only if there were none.
3. Remaining `[NEEDS CLARIFICATION]` markers, with file locations — each one traceable to a register entry that was deferred, since 5g lets no other kind survive.
4. Unchecked items left in `tasks.md`, on the same terms.
5. Step 5's verification: command, result, both counters — total attempts and consecutive failures — or why none ran, plus the override text if the run shipped red or unverified.
6. The finding register: every finding's source, severity, statement and final status. Fixed ones with their resolution, deferred ones with the reason you gave. Sources that returned nothing, named as searched.
7. Step 6's shipping result: the commit range the review request carries, the detected forge, the review request's URL under that forge's own name for it — merge request or pull request — `ship.subskill_calls.6a` and `.6b`, or why either was skipped.
8. Branches deleted, branches kept with reason, every path 6a reported still uncommitted **after** any commit dispatch — the run's own and pre-existing alike — and any `stash_ref` still on the stack.
9. Step 2b's result: the `CLAUDE.md` path, `claude_md.action`, any entries added verbatim, any `.claude/rules/` file written, any skill proposed but not written, and any stale or contradicting instruction found — including on a run that changed nothing.
10. Workspace mode. Worktree mode adds the worktree's path, `worktree.teardown`, and whether the worktree still exists on disk.
11. Base branch from Step 1, feature branch name, spec directory path.

## Red flags — stop and re-read the step

Each of these is a rationalization this run has an incentive to reach for, and each has cost a real run its result. Recognising one means the step's own reference file is what to read next, not the shortcut.

| Thought                                                              | Reality                                                                                                                                                                                                                                                                    |
| -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "The plan was approved at Step 3, so the phases can run"             | Step 3 presents and asks one question about gating; it approves no phase. Every boundary in the always-gate set is approved at its own proposal, immediately before it runs.                                                                                               |
| "This boundary has nothing to decide, so say nothing and move on"    | Proceeding without asking requires the announcement line. A boundary that proceeds silently is indistinguishable from one that was forgotten, and that line is what makes a narrowed gate auditable. Never suppress it, and never compact it away.                         |
| "Nothing changed, so Step 6 can proceed unasked like Phase 6 did"    | Step 6 is in the always-gate set. So are Steps 1 and 2b and Phases 2, 5 and 8. No argument comparison, no `gate_mode` and no skip-approval phrase reaches any of them — that invariant is why this skill carries no `disable-model-invocation`.                            |
| "The user said auto-approve earlier, so `gate_mode` is narrowed"     | A skip-approval phrase is not an answer to Step 3's gating question. Read `gate_mode` from state; absent on a resumed pre-011 run it is `narrowed`, and that is said out loud rather than assumed.                                                                         |
| "The argument is long, so summarize it in the proposal"              | The verbatim argument or nothing. An approval given against a paraphrase approves something the phase will not receive.                                                                                                                                                    |
| "This phase is being skipped, so there is nothing to propose"        | A skip is a decision about what will not happen. Propose it, with its reason, the same as one about what will.                                                                                                                                                             |
| "The command returned, so the phase is done"                         | `done` means the artifacts were seen on disk. Never write it on the strength of a response that merely looked successful.                                                                                                                                                  |
| "The check is green, and that finding is only Minor"                 | Minor is a claim about cost, not an exemption. Every finding leaves the register `fixed` or `deferred`, and only the user defers.                                                                                                                                          |
| "No test runner, so there is nothing to report"                      | `verify.result = none`, said plainly, with what was searched. Never describe a check that did not run as a pass.                                                                                                                                                           |
| "I will commit the work so the review request carries something"     | Step 6 runs no commit of its own — no `git add`, no `git commit`, no substitute. The only commit path is 6a's dispatch of `claude-code-devkit:ccd-commit-push`, on the user's explicit answer.                                                                             |
| "The worktree is created, so the run is isolated"                    | Creating a directory does not move the session. Without a returned `EnterWorktree` call and a verified `git rev-parse --show-toplevel`, all eight phases run in the old checkout.                                                                                          |
| "`state-file absent`, so this is a fresh run"                        | Read the `state-file-elsewhere` lines. A worktree-mode run keeps its state inside its worktree, and treating that as fresh restarts Phase 1 over eight finished phases.                                                                                                    |
| "The worktree has served its purpose, so remove it"                  | 6e's removal option exists only with nothing uncommitted and the commits pushed, and it is never covered by a skip-approval phrase. The worktree is where the run's work lives.                                                                                            |
| "Writing `/ccd-gitlab-mr` in the response invokes it"                | Only a `Skill` tool call loads the sub-skill. Prose invokes nothing, and the run then builds a review request the sub-skill's rules never saw.                                                                                                                             |
| "The base branch is obviously the review request's target"           | The sub-skill ranks and asks. Supplying a target or base suppresses that question by its own rule, which is how it silently becomes wrong.                                                                                                                                 |
| "This is a merge request, so dispatch `ccd-gitlab-mr`"               | Read `tooling.review_skill`. The forge was decided at Step 0 from `origin`, not from the word the run happened to use, and `glab` against a GitHub remote fails after eight phases of work.                                                                                |
| "No GitLab remote, so 6b has nothing to dispatch"                    | GitHub is the other supported forge, not an absence. `tooling.forge = "github"` dispatches `claude-code-devkit:ccd-github-pr`; only `other` and `none` skip 6b.                                                                                                            |
| "Neither forge matched, so preflight failed"                         | A Bitbucket, Gitea or local-path origin is a normal repo. 6b is skipped with the host named, 6c still runs, and `steps.6` is `done`. Never hand-roll a request against that forge's API.                                                                                   |
| "Auto-merge is the tidy default, so arm it"                          | `ccd-github-pr` owns that answer behind its own gate. Armed on a pipeline branch, it merges unreviewed work the moment checks pass — and on a branch shipped under a `verify.override`, checks that never really passed. Hand over the verify status and let its gate ask. |
| "The user said auto-approve, so the questions can go"                | A skip phrase suppresses exactly one thing: the sub-skill's final approval gate. Content questions, 6a's question and 6c's deletion all still run.                                                                                                                         |
| "I remember the base branch from earlier in the run"                 | Read the state file. Conversations compact; `.specify/.speckit-run-state.json` does not.                                                                                                                                                                                   |
| "The spec is clearer if it names the datastore"                      | A technology in a specify prompt corrupts `spec.md` permanently. Hold every tech choice for Phase 5.                                                                                                                                                                       |
| "`tasks.md` has `[P]` markers, so fan out agents across them"        | Those markers belong to `implement`. Dispatching agents against them reimplements the phase, races several writers in the repo, and makes `phases.8` a lie. Forbidden — `reference/subagents.md`.                                                                          |
| "The subagent looked into it and says to amend the spec"             | An agent returns evidence; conclusions are not its to draw. Keep the quotes, drop the verdict, route it through `reference/conflicts.md` here.                                                                                                                             |
| "No agent available, so that source is not searchable"               | The sweep is the work; the agent is only where it happens. Read it inline. A source recorded as swept because an agent was asked is an unswept source.                                                                                                                     |
| "Step 2b found nothing to add, so it did not really run"             | No change is the usual correct outcome. `CLAUDE.md` loads into every session and longer files reduce adherence; a step that adds something every run makes the file worse every run.                                                                                       |
| "This requirement is important, so it belongs in `CLAUDE.md` too"    | Important is not durable. A feature requirement goes in `spec.md`; `CLAUDE.md` records how the repo is worked in, every session, forever.                                                                                                                                  |
| "`/init` will refresh the existing `CLAUDE.md`"                      | Branch B is a targeted read and a targeted edit. `/init` asks what the file could say about the codebase; 2b asks whether the task stated a rule the file lacks.                                                                                                           |
| "The user's `~/.claude/CLAUDE.md` is where this rule really belongs" | Out of scope for every run. That file governs all their projects; this pipeline edits the repo's own file and nothing above it.                                                                                                                                            |

## Authoring note

Do not hard-wrap long lines when writing or editing this skill or its reference files. One line per paragraph, bullet, or table row, however long it runs. Script bodies are code — never compress them. After editing, re-run the scenarios in `reference/evaluations.md`.

**Never add `disable-model-invocation: true` to any skill in this plugin — including this one.** Zero of the eight carry it, and that is a committed contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`. On the four skills this one dispatches through the `Skill` tool at 6a, 6b and the boundary check, the field would break that dispatch silently, at the end of a full pipeline run — and three of those four are now dispatched by `ccd-speckit-bug-run` as well, so the field would break two callers rather than one.

The documentation does not settle it, and two of its passages disagree. The field's own entry says it prevents Claude from loading a skill **automatically**, which reads as silent on an explicit call. Another passage says "To keep Claude from invoking it through the `Skill` tool, set `disable-model-invocation: true`" — naming the tool, with no qualifier. So the gap is real but one-sided in its cost: under the strict reading the field breaks a dispatch, and under the permissive reading omitting it costs nothing at all. The strict reading binds.

**This skill no longer carries the field either, and the reason is worth stating because it is not the same reason.** Nothing dispatches this skill, so the ambiguity above never arises for it. It carried the field because an eight-phase pipeline that engages on its own would be wrong — and that was true while one approval at Step 3 covered all eight phases. It is no longer true. **The gate is in the workflow, not in the frontmatter.**

**Feature 011 narrowed those gates and the field still stays off — this is the re-examination, not an oversight.** Feature 006 recorded that the field's absence was justified by every phase being separately gated, and that "if the per-phase gates are ever removed, the old argument returns and the field should return with them. The two are a pair." Narrowing is not removal, and the property the pairing actually depended on is untouched: by the always-gate set in Step 4, this skill cannot reach `implement`, or any step that commits, pushes, raises a review request or deletes a branch or workspace, without an explicit approval for that step. A skill reached automatically still cannot **do** anything automatically, which is the whole of what the original argument was about.

The pairing is therefore satisfied, not discharged. **If a future feature removes the always-gate set, the argument returns intact and the field should return with it.** Recorded at `specs/011-narrow-gates-pipeline-fix/research.md` R9 and `contracts/skill-names.md`.

**Keep the forge in exactly one place.** `scripts/forge-detect.sh` decides it, Step 0 records it, Step 6b reads it. Adding a second detection — a host check in prose, a `glab` probe at 6b, a guess from the task description — gives the run two answers that can disagree, and the one that loses is always the one the user was shown.
