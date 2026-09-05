---
name: ccd-speckit-bug-run
description: Use when the user wants one bug report taken from raw description to a verified fix in a single guided run — e.g. "triage this bug", "assess and fix this crash", "run the bug workflow on this stack trace", or when they paste a bug report or an issue URL and want it seen through end to end. Drives the installed GitHub Spec Kit bug extension's three stages — assess, then fix, then test — approving each one separately and skipping any stage whose precondition the extension would refuse. Not for feature work, which goes through the eight-phase spec pipeline; not for committing, branching, or opening a review request.
---

# Guided bug triage run

Bug report: $ARGUMENTS

One bug report, three stages, each approved on its own: `speckit-bug-assess`, then `speckit-bug-fix`, then `speckit-bug-test`. The run branches on what each stage **records**, skips a stage the extension would refuse rather than invoking it, and stops rather than reporting success over a defect that is still there.

Empty bug report → ask for one. Do not infer a defect from the conversation; the report is what Stage 1 assesses and what a resumed run would send again.

## Two standing rules

**The run never does a stage's work itself.** If Stage 2 cannot run, the run does not edit the source instead. If a report is missing, the run does not write it. Each stage's work happens by invoking that stage, or it does not happen.

**"Nothing happens without approval" means: no stage is invoked and no file is written without approval.** Reading the repository and running the read-only preflight are not covered — they are how the first boundary gets something to state. Without them the maintainer would be approving a blank.

## Scripts — run them, do not re-derive them

Two scripts carry the parts that must not vary between runs. Invoke as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"` — that variable resolves to this skill's own directory without naming it, so a rename touches the frontmatter and the directory and nothing else. Always `sh <path>`; the executable bit does not survive every install.

| Script                     | Prints                                                                                                                                                                         |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bug-preflight.sh [slug]`  | is the capability found (per stage, not just the extension directory), is the tree dirty and which paths, is this slug taken, and a `ready` / `undetermined: <reason>` verdict |
| `bug-outcome.sh <bug-dir>` | which of the three reports exist, and the `verdict` / `severity` / `status` / `result` each records — or `unknown`                                                             |

**Read the `verdict` line, never the exit status.** `exit 0` means the check ran. A repository with no bug extension installed exits 0 and says `undetermined`.

The outcome reader is invoked after every stage, so its form is given here once rather than repeated at each:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/bug-outcome.sh" ".specify/bugs/<slug>"
```

Act on what they print. Never reimplement their rules in prose, never override a verdict by hand, never re-read a report to second-guess `bug-outcome.sh` — a second opinion from the same session is not evidence.

## Reference map

Read each before the step that needs it. Both are short.

| File                     | Covers                                                                                                      |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `reference/stages.md`    | the three stages, what each receives, the outcome vocabularies, the branch table, where an outcome is found |
| `reference/run-state.md` | the state file — shape, who writes what, and why `done` means the report was seen on disk                   |

## Run state — read before acting, at every stage

A run spans three stages and many turns; compaction re-attaches this file only up to a token budget, so the later half is what a long run loses first, and it is never re-read from disk. Run facts live in `.specify/.speckit-bug-run-state.json`, not memory. Shape and rules: `reference/run-state.md`.

Before each stage: read state, confirm the previous stage is `done` or `skipped`. After each stage: update state, **then** ask.

State beats recollection. The slug, the verdict, what was already dirty — read them.

## Progress checklist

Copy into your response, tick off as you go:

```text
- [ ] Step 0: preflight — capability, slug, dirty paths, one report only; state written
- [ ] Stage 1: assess — proposed, approved, dispatched, report confirmed, verdict recorded
- [ ] Stage 2: fix — proposed (or proposed as a skip), branch taken per the verdict
- [ ] Stage 3: test — proposed (or proposed as a skip), branch taken per the status
- [ ] Closing report — every stage's status and outcome, every report path, the commit obligation
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

**More than one bug report supplied → refuse here**, before Stage 1, saying why. One run handles one report; two would share a slug, a directory and a closing report that could not honestly describe either.

### Resolving `undetermined`

The script reports `capability present` or `capability undetermined`. **It never reports `absent`, and that is deliberate.** A filesystem probe can show that something is here; it cannot show that something is not. Where a compiled skill's files live is an install detail, and a skill can be listed and dispatchable with nothing on disk where the script thought to look.

So on `undetermined`, look in **the session's own available-skills listing** — which is the authoritative probe — for `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test`.

- **All three listed** → proceed. Say once that the compiled skills are not at `.claude/skills/`, so this install's layout differs from the one the script checks. Nothing else changes.
- **Not listed** → _now_ you have determined absence. Report it and **stop**, naming which are missing. Never carry out the stages by other means — a hand-rolled triage is not this skill's output.
- **Listing unavailable or inconclusive** → treat the capability as present and proceed. A dispatch that fails is visible and says what is wrong; a refusal that guessed absence is neither.

### An existing run

If `.specify/.speckit-bug-run-state.json` already exists, read it before writing anything. Report which bug it describes and how far it got, then **ask**: resume that bug (re-invoke with its slug), start this new one and overwrite the file, or stop. Overwriting silently loses the only record of an interrupted run.

Resuming needs nothing from that file beyond the slug — the preflight finds the bug directory and `bug-outcome.sh` reports which stages already have reports, and the branch table resumes at the first one that is `absent`.

Then write state: `report` verbatim, `slug`, `bug_dir`, the whole `preflight` block, `steps.0 = "done"`.

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

## Stage 1 — Assess

```text
Skill(skill: "speckit-bug-assess")
```

Bare name, not `claude-code-devkit:speckit-bug-assess`. The three stages are Spec Kit project skills, not this plugin's; the namespace does not address them and would fail.

The bare name stays correct even where the session lists **directory-scoped variants** — `<some/dir>:speckit-bug-assess` alongside the unscoped one, which happens in a repository with worktrees. The bare name resolves to the unscoped skill, which is the one to use unless the bug being fixed lives inside that subtree. Namespacing is not the fix for the ambiguity, and applying it produces a dispatch that resolves to nothing.

**Wording**: the bug report **exactly as supplied**, plus `slug=<slug>` only if the maintainer gave one. Where they gave none, pass no slug and let the extension derive it — it owns that normalisation.

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
| `not-applied`, or Stage 2 skipped | **Skip.** Propose the skip with the reason, go to the closing report                                                                              |
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
| `verified` | The run may complete                                                             |
| `partial`  | **Stop and ask.** State what validation found **and why the result was partial** |
| `failed`   | **Stop and ask.** State what validation found                                    |
| `unknown`  | **Stop** and report the drift                                                    |

`partial` and `failed` are treated identically. Neither is an ending the run may reach on its own, and **neither is described as successful.** `partial` can mean a listed reproduction was never exercised — "nobody checked", not "mostly fixed". Offer the choice: re-run the assessment with the new evidence, accept the partial result and stop here, or stop and hand back. Never re-invoke a stage on your own initiative.

## Closing report

Every run ends here, including a run that stopped early.

1. Each stage: ran or skipped, its recorded outcome, and — for a skip — the value that caused it.
2. Each report's path. Absent ones named as absent.
3. Whether source files were modified, and by which stage.
4. The paths the preflight reported as **already dirty** before the run started, so the maintainer can tell them from the fix.
5. **The commit obligation**: these reports are project history, and governance requires them committed before the change is proposed for review. Name `claude-code-devkit:ccd-commit-push` as the way. **Do not commit.** No `git add`, no `git commit`, no branch, no review request.

Take every outcome from state, which took it from `bug-outcome.sh`. Not from memory of what a stage said.

### After a stop

Whatever exists stays on disk; nothing is deleted or rolled back. **Resuming is re-invoking this skill with the same slug** — the preflight finds the directory, `bug-outcome.sh` says which reports exist, and the branch table resumes at the first one that is `absent`. There is no separate resume mode because the extension's own preconditions already work this way.

A stop **after Stage 2 has run** says so explicitly: source files were modified, `fix.md` lists them, and the already-dirty paths were these. The run does not offer to revert — undoing a remediation is a git operation, and this skill stays out of git.

## Red flags — stop and re-read

| Thought                                                               | Reality                                                                                     |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| "The script exited 0, so we're good"                                  | Exit 0 means the check ran. Read the `verdict` line. A repo with no bug extension exits 0   |
| "`unknown` probably means the benign value"                           | `unknown` is a stop. Guessing a verdict is how a run edits source nobody authorised         |
| "The stage refused, so I'll do it myself"                             | Never. If a stage cannot run, its work does not happen                                      |
| "I'll fetch the issue URL so the assessment has more context"         | That launders the fetch past the assess stage's host allowlist. Hand over the URL untouched |
| "The verdict is `likely valid`, so I should ask before fixing"        | `speckit-bug-fix` already asks. Say it was not reproduced; let the stage ask                |
| "Validation says `partial`, which is basically fixed"                 | It can mean nobody ran the reproduction. Stop and ask                                       |
| "The test failed, so I'll re-run assess with the new evidence"        | That is the maintainer's call. Offer it; never take it                                      |
| "This stage is being skipped, so there's nothing to propose"          | A skip is a decision. Propose it with its reason                                            |
| "The dispatch returned, so the stage is done"                         | `done` means the report was seen on disk                                                    |
| "`claude-code-devkit:speckit-bug-fix` is the correct namespaced form" | It names nothing. The three stages are Spec Kit's, not this plugin's. Bare names            |
| "The reports should be committed, so I'll commit them"                | Name the obligation and the skill that discharges it. This run commits nothing              |
| "I remember the verdict from earlier"                                 | Read state. Conversations compact; the file does not                                        |

## Authoring note

Do not hard-wrap long lines when editing this skill or its reference files. One line per paragraph, bullet or table row, however long. Script bodies are code — never compress them. Inside fenced blocks use two spaces, never a tab: `.editorconfig`'s `[*.md]` section overrides only `indent_size`, so `indent_style = space` still governs fences and the `editorconfig` check rejects the tab.

After editing, re-run the scenarios in `evaluations.md`.

**Never add `disable-model-invocation: true`, and never add `user-invocable`.** Zero of the seven skills in this plugin carry either, and that is a committed contract at `specs/009-bug-triage-run/contracts/skill-names.md`.

That contract's predecessor said a seventh skill "with side effects and no per-action gate would have a real case for" the field. This skill has side effects — Stage 2 edits source — and the answer was to remove the antecedent rather than add the field: every stage is proposed and approved immediately before it runs, and a skip is announced rather than taken silently. **The gate is in the workflow, not in the frontmatter.** If the per-stage gates are ever collapsed into one approval, that justification lapses and the field's case returns with them. The two are a pair.
