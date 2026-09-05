---
name: ccd-speckit-bug-run
description: Use when the user wants one bug report taken from raw description to a verified fix and a raised review request in a single guided run — e.g. "triage this bug", "assess and fix this crash", "run the bug workflow on this stack trace", or when they paste a bug report or an issue URL and want it seen through end to end. Drives the installed GitHub Spec Kit bug extension's three stages — assess, then fix, then test — approving each separately and skipping any stage whose precondition the extension would refuse, then commits the work and raises a pull or merge request by handing each job to the skill that owns it. Not for feature work, which goes through the eight-phase spec pipeline.
---

# Guided bug triage run

Bug report: $ARGUMENTS

One bug report, one workspace choice, three stages each approved on its own — `speckit-bug-assess`, then `speckit-bug-fix`, then `speckit-bug-test` — and then, when validation says the defect is gone, a commit and a review request. The run branches on what each stage **records**, skips a stage the extension would refuse rather than invoking it, and stops rather than reporting success over a defect that is still there.

Empty bug report → ask for one. Do not infer a defect from the conversation; the report is what Stage 1 assesses and what a resumed run would send again.

## Three standing rules

**The run never does a stage's work itself.** If Stage 2 cannot run, the run does not edit the source instead. If a report is missing, the run does not write it. Each stage's work happens by invoking that stage, or it does not happen.

**The run never does a sub-skill's work either.** It creates no commit of its own and raises no review request of its own. Step 4a dispatches `claude-code-devkit:ccd-commit-push`; Step 4b dispatches whichever review skill the remote calls for. What this run owns is the question; what the sub-skill owns is the answer.

**"Nothing happens without approval" means: no stage is invoked, no file is written, no branch or workspace is created or destroyed without approval.** Reading the repository and running the read-only preflight are not covered — they are how the first boundary gets something to state. Without them the maintainer would be approving a blank.

## Scripts — run them, do not re-derive them

Two scripts are this skill's own. Invoke as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"` — that variable resolves to this skill's own directory without naming it, so a rename touches the frontmatter and the directory and nothing else.

Three more belong to sibling skills and are reached through `${CLAUDE_PLUGIN_ROOT}`. They are **not** copied here; a fork of one is the regression this plugin already records against `branch-options.sh`.

Always `sh <path>`, always quoted; the executable bit does not survive every install.

| Script                                                                   | Prints                                                                                                                                                                        |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `${CLAUDE_SKILL_DIR}/scripts/bug-preflight.sh [slug]`                    | is the capability found (per stage, not just the extension directory), is the tree dirty and which paths, is this slug taken, the workspace facts Step 1 needs, and a verdict |
| `${CLAUDE_SKILL_DIR}/scripts/bug-outcome.sh <bug-dir>`                   | which of the three reports exist, and the `verdict` / `severity` / `status` / `result` each records — or `unknown`                                                            |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh`   | which forge `origin` points at, the review skill and CLI that match it, and a `ready` / `skip: <reason>` verdict                                                              |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh` | base-branch candidates: branch, local/remote/both, last commit date, `default`/`current` tags                                                                                 |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/cleanup-plan.sh`   | per local branch: `delete` or `keep`, with reason                                                                                                                             |

**Read the `verdict` line, never the exit status.** `exit 0` means the check ran. A repository with no bug extension installed exits 0 and says `undetermined`.

The outcome reader is invoked after every stage, so its form is given here once rather than repeated at each:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/bug-outcome.sh" ".specify/bugs/<slug>"
```

Act on what they print. Never reimplement their rules in prose, never override a verdict by hand, never re-read a report to second-guess `bug-outcome.sh` — a second opinion from the same session is not evidence.

## Reference map

Read each before the step that needs it.

| File                     | Covers                                                                                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `reference/stages.md`    | the three stages, what each receives, the outcome vocabularies, the branch table, where an outcome is found |
| `reference/run-state.md` | the state file — shape, who writes what, and why `done` means the report was seen on disk                   |
| `reference/workspace.md` | Step 1's mode choice and Step 4c's teardown — both option sets, both guards, worktree create and verify     |
| `reference/ship.md`      | Step 4a and 4b — the commit question, the review-request routing, and what dispatch actually means          |

## Run state — read before acting, at every step

A run spans three stages, four steps and many turns, and may loop back through the stages more than once; compaction re-attaches this file only up to a token budget, so the later half is what a long run loses first, and it is never re-read from disk. **The added steps are exactly the ones that run last.** Run facts live in `.specify/.speckit-bug-run-state.json`, not memory. Shape and rules: `reference/run-state.md`.

Before each step and stage: read state, confirm the predecessor is `done` or `skipped`. After each: update state, **then** ask.

State beats recollection. The slug, the verdict, the workspace mode, the forge, the cycle count — read them.

## Progress checklist

Copy into your response, tick off as you go:

```text
- [ ] Step 0: preflight — capability, slug, dirty paths, forge, companion skills, one report only; state written
- [ ] Step 1: workspace — mode chosen, carried out, verified; state written before any stage runs
- [ ] Stage 1: assess — proposed, approved, dispatched, report confirmed, verdict recorded
- [ ] Stage 2: fix — proposed (or proposed as a skip), branch taken per the verdict
- [ ] Stage 3: test — proposed (or proposed as a skip), branch taken per the result, loop-back offered on partial or failed
- [ ] Step 4a: commit — uncommitted work reported, question asked, ccd-commit-push dispatched or skipped with reason
- [ ] Step 4b: review request — raised through the forge's own skill, or skipped with reason
- [ ] Step 4c: teardown — workspace question asked and the answer verified, or skipped with reason
- [ ] Closing report — every stage and step, every outcome, every report path, the review request
```

## Step 0 — Preflight

Nothing is dispatched and nothing is written until this passes.

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/bug-preflight.sh" "<slug or omit>"
```

Act on it:

| Line                                | Do                                                                                                                                                                                       |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `verdict undetermined: …`           | **Do not stop on this alone.** See "Resolving `undetermined`" below — the script cannot establish absence, only the session listing can                                                  |
| `stage-* missing`                   | Name which stage. An extension added but never compiled is a different problem from one never installed, and is fixed differently                                                        |
| `slug-taken yes`                    | Report it and **ask** before Stage 1. An existing report is not overwritten unasked                                                                                                      |
| `dirty yes` with `dirty-path` lines | Report those paths **before Stage 2**, then continue. Not a refusal: fixing a bug mid-task is ordinary, and the change record will list what the fix touched, so the two halves subtract |
| `dirty unknown`                     | Say so. Not a git repository is a normal result; do not report it as a clean tree                                                                                                        |
| `git-repo no`                       | Step 1 skips itself and Steps 4a–4c skip with it. The three stages still run                                                                                                             |

The remaining lines — `worktree-supported`, `in-worktree`, `submodules` — decide which options Step 1 may offer. Record them here and read them there; do not probe a second time, because a second probe is a second answer that can disagree with the one the question was built from.

**More than one bug report supplied → refuse here**, before Stage 1, saying why. One run handles one report; two would share a slug, a directory and a closing report that could not honestly describe either.

Then two probes whose results are read much later, and must not be re-derived at the moment they are needed.

**The forge.** Step 4b raises a pull request on GitHub and a merge request on GitLab, through two different skills. Which one — if either — is decided **here**, from the remote:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh"
```

Record its `forge`, `host`, `review-skill`, `cli` and `cli-status` lines as `tooling.forge`, `tooling.forge_host`, `tooling.review_skill`, `tooling.forge_cli` and `tooling.forge_cli_status`. `other` and `none` are ordinary results meaning this run has no review-request step; nothing else changes. Never re-derive the host in prose — that script handles scp-like URLs, embedded credentials, ports, and the self-hosted case where the hostname says nothing.

**The companion skills.** Step 4a and 4b dispatch skills that may not be installed, and a dispatch that fails does so after every stage has run. **The session's own available-skills listing is the probe, and it is authoritative** — look there for `claude-code-devkit:ccd-commit-push` and for whichever skill `tooling.review_skill` named. A filesystem test is not the probe: where a skill's files live is an install detail. Record each as found, missing, or **undetermined** — and treat undetermined as present, because a dispatch that fails is visible and a probe that guessed absence is not.

### Resolving `undetermined`

The script reports `capability present` or `capability undetermined`. **It never reports `absent`, and that is deliberate.** A filesystem probe can show that something is here; it cannot show that something is not. Where a compiled skill's files live is an install detail, and a skill can be listed and dispatchable with nothing on disk where the script thought to look.

So on `undetermined`, look in **the session's own available-skills listing** — which is the authoritative probe — for `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test`.

- **All three listed** → proceed. Say once that the compiled skills are not at `.claude/skills/`, so this install's layout differs from the one the script checks. Nothing else changes.
- **Not listed** → _now_ you have determined absence. Report it and **stop**, naming which are missing. Never carry out the stages by other means — a hand-rolled triage is not this skill's output.
- **Listing unavailable or inconclusive** → treat the capability as present and proceed. A dispatch that fails is visible and says what is wrong; a refusal that guessed absence is neither.

### An existing run

If `.specify/.speckit-bug-run-state.json` already exists, read it before writing anything. Report which bug it describes and how far it got, then **ask**: resume that bug (re-invoke with its slug), start this new one and overwrite the file, or stop. Overwriting silently loses the only record of an interrupted run.

Resuming needs nothing from that file beyond the slug — the preflight finds the bug directory and `bug-outcome.sh` reports which stages already have reports, and the branch table resumes at the first one that is `absent`.

A `version: 1` state file predates the `tooling`, `workspace`, `worktree`, `branch`, `cycles` and `ship` blocks. Re-run this preflight once and write the version 2 fields before any later step reads them; an absent `review_skill` is exactly what a guess fills in.

Then write state: `report` verbatim, `slug`, `bug_dir`, the whole `preflight` block, the `tooling` block, `steps.0 = "done"`.

## Step 1 — Workspace

**Before Stage 1, always.** Stage 2 edits source files, and doing that on whatever branch the maintainer happened to be on — in the tree they have open — is the failure that costs them their own uncommitted work, before they have seen a single finding.

Read `reference/workspace.md`. One `AskUserQuestion`, `header: "Workspace"`. **Offer only the choices that apply**, and where one is withheld, say why rather than letting it be silently absent.

| Option                         | Offered when                                                      |
| ------------------------------ | ----------------------------------------------------------------- |
| `Fresh worktree (Recommended)` | worktree supported, `EnterWorktree` available, not already in one |
| `New branch here`              | in a git repository                                               |
| `Stay on the current branch`   | always, in a git repository                                       |
| `Stay in this worktree`        | replaces the first two when already inside a worktree             |

This step writes to the repository, so it takes a full proposal: state what will run, the path or branch it will create, and what it will not touch. Then the gate.

**Write `workspace` to state the moment the answer returns**, before acting on it. A mode held only in the conversation is one a compacted run cannot read — and Step 4c reads it.

Worktree mode ends with a **verification**, not an assumption: `git rev-parse --show-toplevel` must report the new path. `git worktree add` creates a directory; it does not move the session. Without the check every stage runs in the old tree while the run reports isolation.

Not a git repository → skip the step, record `steps.1 = "skipped: not a git repo"`, continue to Stage 1. Never `git init`.

## The per-stage proposal

Before invoking a stage, state four things and nothing else:

|             |                                                                                                                                               |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **Stage**   | which of the three, and the skill about to be dispatched                                                                                      |
| **Wording** | the **verbatim** argument it will receive. Never summarised, never truncated — an approval given against a paraphrase approves something else |
| **Writes**  | the report path that stage will create                                                                                                        |
| **Why now** | what the previous stage recorded that makes this stage the right next thing — or, for a skip, what makes it the wrong one                     |

Then `AskUserQuestion`: `Proceed` / `Revise` / `Stop`.

- **Proceed** → dispatch. Confirm the report exists, record the outcome, report, write `stages.N`.
- **Revise** → amend **only this stage's wording** and re-present **this** boundary. No other stage's wording changes and nothing advances. After three revisions of one stage, stop and ask rather than loop.
- **Stop** → the run halts with accurate state on disk. See [After a stop](#after-a-stop).

**A stage about to be skipped still gets a proposal**, stating the skip and the recorded value that caused it. A skip is a decision about what will not happen, and it is reported the same way as one about what will.

**A stage re-entered by the loop-back is proposed on exactly these terms**, with its cycle number stated. Nothing about a second pass is lighter than a first.

## Stage 1 — Assess

```text
Skill(skill: "speckit-bug-assess")
```

Bare name, not `claude-code-devkit:speckit-bug-assess`. The three stages are Spec Kit project skills, not this plugin's; the namespace does not address them and would fail.

The bare name stays correct even where the session lists **directory-scoped variants** — `<some/dir>:speckit-bug-assess` alongside the unscoped one, which happens in a repository with worktrees. The bare name resolves to the unscoped skill, which is the one to use unless the bug being fixed lives inside that subtree. Namespacing is not the fix for the ambiguity, and applying it produces a dispatch that resolves to nothing.

**Wording**: the bug report **exactly as supplied**, plus `slug=<slug>` only if the maintainer gave one. Where they gave none, pass no slug and let the extension derive it — it owns that normalisation.

On a re-entered cycle, the wording also carries **what validation recorded** — its result and its findings — because that is the new evidence the reassessment exists to weigh. The bug report itself is unchanged.

**Never fetch a URL in the report.** `speckit-bug-assess` applies its own host allowlist and untrusted-input policy to whatever it fetches. Fetching first and handing over the text launders that fetch past the policy: the stage would see prose, not a URL, and its rules would never fire.

After it returns, run `bug-outcome.sh` and record `verdict` and `severity`. `assessment absent` → the stage did not produce its artifact; record `failed`, report the actual error, and ask whether to retry, revise the wording, or stop. Never write `done` on a dispatch that merely looked successful.

## Stage 2 — Fix

Branch on the recorded verdict. Full table in `reference/stages.md`.

| Verdict                            | Do                                                                                                                    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `invalid`                          | **Skip**, and skip Stage 3 with it. Propose the skip, state the verdict, go to the closing report                     |
| `likely valid, needs reproduction` | **Proceed** — and say at this boundary that the defect was **not reproduced**, so the approval is given in view of it |
| `valid`                            | **Proceed**                                                                                                           |
| `unknown`                          | **Stop.** The extraction contract has drifted; report it                                                              |

**State the recorded severity at this boundary**, whichever verdict applies. It is the one stage where source is about to be edited, and severity is what tells the maintainer whether that is proportionate. The run never branches on it — `critical` and `low` take the same path — but a decision made without it is made with less than the assessment recorded.

On the middle verdict, raise **no question of your own** about proceeding on unreproduced evidence. `speckit-bug-fix` asks that itself when the assessment carries unresolved items. Asking first puts one decision to the maintainer twice, and the second asking looks like the first was ignored.

```text
Skill(skill: "speckit-bug-fix")
```

**Wording**: `slug=<slug>` only. The stage reads `assessment.md` itself and treats its sections as its contract; restating them here would duplicate a file it is about to read, and the copies would disagree the moment one was revised.

This is the **only** stage that edits source. After it returns, run `bug-outcome.sh`, record `status`, and record `fix.md`'s path.

## Stage 3 — Test

Branch on the recorded status.

| Status                            | Do                                                                                                                                                |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `not-applied`, or Stage 2 skipped | **Skip**, and skip Steps 4a–4c with it. Propose the skip with the reason, go to the closing report                                                |
| `partial`                         | **Proceed**, and carry the partial status into the closing report. Validation is the stage best placed to say whether the applied part was enough |
| `applied`                         | **Proceed**                                                                                                                                       |
| `unknown`                         | **Stop** and report the drift                                                                                                                     |

```text
Skill(skill: "speckit-bug-test")
```

**Wording**: `slug=<slug>` only.

After it returns, run `bug-outcome.sh` and record `result`.

| Result     | Do                                                                               |
| ---------- | -------------------------------------------------------------------------------- |
| `verified` | Go to Step 4a                                                                    |
| `partial`  | **Stop and ask.** State what validation found **and why the result was partial** |
| `failed`   | **Stop and ask.** State what validation found                                    |
| `unknown`  | **Stop** and report the drift                                                    |

`partial` and `failed` are treated identically. Neither is an ending the run may reach on its own, and **neither is described as successful.** `partial` can mean a listed reproduction was never exercised — "nobody checked", not "mostly fixed".

Offer three choices: **return to Stage 1 carrying what validation found**, accept the result and stop here, or stop and hand back.

**State the cycle count with the question.** `cycles` is how many times assessment has been entered; say it, so the choice is made in view of the loop's own history rather than blind. There is **no cap** — a maintainer converging on a fix is not interrupted by an arbitrary limit, and every cycle is an explicit choice they made.

Choosing to return increments `cycles` and re-enters Stage 1, which then flows forward through Stage 2 and Stage 3 as normal; each stage's own precondition governs overwriting its report, exactly as on the first pass. **Never re-enter a stage on your own initiative** — offering the choice is this run's job, taking it is the maintainer's.

## Step 4a — Commit

Entered only on `result verified`. Read `reference/ship.md`.

**This run creates no commit.** No `git add`, no `git commit`, no inline substitute. What it does is report what is uncommitted — the three reports, whatever Stage 2 edited, and whatever was already dirty before the run started — and then ask, with one answer dispatching the skill that owns commits:

```text
Skill(skill: "claude-code-devkit:ccd-commit-push")
```

Three options: commit and push now (recommended), open the review request on whatever commits already exist, or stop here. What the commit skill receives is the **explicit path list the question displayed**, minus anything credential-shaped — Stage 2 writes files unattended, and handing over the dirty tree wholesale is how a generated key reaches the remote.

It returns → **re-check**. Re-read the dirty paths and the commit range, because changing them is the whole point of having asked. Range still empty, or the paths still dirty → its gate was declined or it stopped halfway; say so and re-ask rather than proceeding on the old numbers.

Option one is unavailable when Step 0 recorded `ccd-commit-push` as missing. Drop it, say why, and offer only the other two — never fall back to an inline commit because the skill is absent.

## Step 4b — Review request

**Read the forge from state.** `tooling.review_skill` was decided at Step 0 from the remote; never re-detect it here and never infer it from the bug report.

```text
Skill(skill: <tooling.review_skill>)
```

Hand it **facts, not answers**: the branch, the verification result, the three report paths. The target branch, assignee, reviewers, draft state, squash, auto-merge and source-branch deletion are all that skill's own questions, behind its own gate — and supplying one suppresses the question it belongs to, which is how it silently becomes wrong.

Skipped, with the reason recorded, when `tooling.forge` is `other` or `none`, when the named skill is not installed, or when its CLI is absent or unauthenticated. A skip here is a normal outcome: the run still finishes, and Step 4c skips with it.

Record the returned URL, the forge, and whether that forge calls the result a pull request or a merge request. Report it under the forge's own name for it.

## Step 4c — Teardown

Entered once Step 4b returned a URL. Skipped with a reason when it did not — with no review request there is nothing to leave the workspace for.

One `AskUserQuestion`, option set chosen by `workspace`. Both sets, both guards, and the bans on `--force`, `branch -D` and `ExitWorktree(action: "remove")` are in `reference/workspace.md`.

**The least destructive option is the recommended one in both sets**, because the review request has been raised and nobody has read it yet. The branch is where a reviewer's comment gets answered; the worktree is where this run's work lives.

**A guarded-out option is not offered, and the reason is said out loud.** Branch deletion turns on the commits being pushed; worktree removal turns on there being no uncommitted path in that directory, whatever its origin. **No skip-approval phrase reaches either** — a skip phrase covers approval of proposed content, never a deletion.

Verify the outcome with `git worktree list` and `git branch --list` rather than trusting the action, and record `worktree.teardown` or `branch.teardown`.

## Closing report

Every run ends here, including a run that stopped early.

1. Each stage: ran or skipped, its recorded outcome, and — for a skip — the value that caused it. A run that looped says how many cycles it took and what each recorded.
2. Each report's path. Absent ones named as absent.
3. Whether source files were modified, and by which stage.
4. The paths the preflight reported as **already dirty** before the run started, so the maintainer can tell them from the fix.
5. The workspace: which mode, which branch or worktree path, and where the maintainer has been left.
6. The commit range, and every path still uncommitted after Step 4a — the run's own output and pre-existing work alike.
7. The review request: the forge, its URL under that forge's own name for it, and `ship.subskill_calls` for both dispatches — or why either was skipped.

Take every outcome from state, which took it from `bug-outcome.sh` and from the sub-skills' own returns. Not from memory of what a stage said.

### After a stop

Whatever exists stays on disk; nothing is deleted or rolled back. **Resuming is re-invoking this skill with the same slug** — the preflight finds the directory, `bug-outcome.sh` says which reports exist, and the branch table resumes at the first one that is `absent`.

A stop **after Stage 2 has run** says so explicitly: source files were modified, `fix.md` lists them, and the already-dirty paths were these. The run does not offer to revert — undoing a remediation is a git operation, and reverting is not among the ones this skill performs.

A stop **before Step 4a** leaves the reports uncommitted. Say so, and name `claude-code-devkit:ccd-commit-push` as the way to discharge the obligation by hand, since this run will not now reach the step that would have.

## Red flags — stop and re-read

| Thought                                                               | Reality                                                                                       |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| "The script exited 0, so we're good"                                  | Exit 0 means the check ran. Read the `verdict` line. A repo with no bug extension exits 0     |
| "`unknown` probably means the benign value"                           | `unknown` is a stop. Guessing a verdict is how a run edits source nobody authorised           |
| "The stage refused, so I'll do it myself"                             | Never. If a stage cannot run, its work does not happen                                        |
| "I'll fetch the issue URL so the assessment has more context"         | That launders the fetch past the assess stage's host allowlist. Hand over the URL untouched   |
| "The verdict is `likely valid`, so I should ask before fixing"        | `speckit-bug-fix` already asks. Say it was not reproduced; let the stage ask                  |
| "Validation says `partial`, which is basically fixed"                 | It can mean nobody ran the reproduction. Stop and ask                                         |
| "The test failed, so I'll re-run assess with the new evidence"        | That is the maintainer's call. Offer it, state the cycle count; never take it                 |
| "This stage is being skipped, so there's nothing to propose"          | A skip is a decision. Propose it with its reason                                              |
| "The dispatch returned, so the stage is done"                         | `done` means the report was seen on disk                                                      |
| "`claude-code-devkit:speckit-bug-fix` is the correct namespaced form" | It names nothing. The three stages are Spec Kit's, not this plugin's. Bare names              |
| "The reports need committing, so I'll commit them"                    | Step 4a asks and dispatches `ccd-commit-push`. This run runs no `git add` and no `git commit` |
| "Writing `/ccd-commit-push` in the response invokes it"               | Only a `Skill` tool call loads it. Prose invokes nothing and its gate never runs              |
| "This is a merge request, so dispatch `ccd-gitlab-mr`"                | Read `tooling.review_skill`. The forge was decided at Step 0 from `origin`, not from wording  |
| "The base branch is obviously the review request's target"            | The sub-skill ranks and asks. Supplying a target suppresses that question by its own rule     |
| "The worktree is created, so the run is isolated"                     | Creating a directory does not move the session. Verify with `git rev-parse --show-toplevel`   |
| "The work is shipped, so the worktree can go"                         | Removal needs its guard satisfied, and no skip phrase reaches it. It holds this run's output  |
| "I remember the verdict from earlier"                                 | Read state. Conversations compact; the file does not                                          |

## Authoring note

Do not hard-wrap long lines when editing this skill or its reference files. One line per paragraph, bullet or table row, however long. Script bodies are code — never compress them. Inside fenced blocks use two spaces, never a tab: `.editorconfig`'s `[*.md]` section overrides only `indent_size`, so `indent_style = space` still governs fences and the `editorconfig` check rejects the tab.

After editing, re-run the scenarios in `evaluations.md`.

**Never add `disable-model-invocation: true`, and never add `user-invocable`.** Zero of the seven skills in this plugin carry either, and that is a committed contract at `specs/010-bug-run-ship/contracts/skill-names.md`.

That contract's ancestor said a seventh skill "with side effects and no per-action gate would have a real case for" the field. This skill has side effects — Stage 2 edits source, Step 4a commits through a sub-skill, Step 4c can delete a branch — and the answer was to remove the antecedent rather than add the field: every stage and every step is proposed and approved immediately before it runs, and a skip is announced rather than taken silently. **The gate is in the workflow, not in the frontmatter.** If those gates are ever collapsed into one approval, that justification lapses and the field's case returns with them. The two are a pair.

The same field must not be added to `ccd-commit-push`, `ccd-github-pr` or `ccd-gitlab-mr` either. This skill now dispatches all three through the `Skill` tool, so the field would break Step 4a or 4b silently, at the very end of a full triage run.
