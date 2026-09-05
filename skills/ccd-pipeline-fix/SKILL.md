---
name: ccd-pipeline-fix
description: Use when a GitHub Actions or GitLab CI pipeline has failed and the user wants it diagnosed and fixed — e.g. "my build is broken", "fix the failing pipeline", "why did CI fail on this branch", or when they paste a failed run's URL or its log. Gathers the failing run's evidence from the forge, shows it, proposes a root cause with the evidence behind it, takes the user's pick from stated remediation approaches, then hands the whole thing to the guided bug workflow to fix and validate. Not for a pipeline that has not failed, and not for work that would add or change a requirement, which is feature work.
---

# Guided CI/CD pipeline repair

Failed pipeline: $ARGUMENTS

A failed pipeline, diagnosed with its own evidence, then fixed and validated by the workflow that already owns defect remediation. This skill gathers, proposes and asks. It does not fix.

Empty argument → resolve the most recent failed run on the current branch and confirm it. Never infer a failure from the conversation; a green pipeline is a fine answer.

## Three standing rules

**It runs no stage.** `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test` are never dispatched from here. `claude-code-devkit:ccd-speckit-bug-run` owns them, and with them the whole of `.claude/rules/spec-kit-bug-workflow.md` — the closed outcome vocabularies, the `bug-outcome.sh` extraction contract, `partial` handling, the uncapped loop-back, the commit and the review request. Reaching past it to a stage reimplements all of that in a second place.

**It edits no source.** Not one file. If the fix cannot happen through the dispatched workflow, it does not happen here instead.

**Nothing changes before the user has approved a root cause and chosen an approach.** Reading the repository, probing the CLI and retrieving logs are not covered — they are how the first question gets something to state.

## Scripts

One script is this skill's own. Invoke as `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"` — that variable resolves to this skill's own directory without naming it, so a rename touches the frontmatter and the directory and nothing else.

One belongs to a sibling and is reached through `${CLAUDE_PLUGIN_ROOT}`. It is **not** copied here; a fork of a shared script is the regression this plugin already records against `branch-options.sh`.

Always `sh <path>`, always quoted; the executable bit does not survive every install.

| Script                                                                 | Prints                                                                                                  |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `${CLAUDE_SKILL_DIR}/scripts/pipeline-evidence.sh`                     | forge, CLI presence and auth status, candidate failed runs and their failing jobs, and a `verdict` line |
| `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh` | which forge `origin` points at, the CLI that matches it, and a `ready` / `skip: <reason>` verdict       |

**Read the `verdict` line, never the exit status.** `exit 0` means the check ran. A repository with no CI at all exits 0 and says so.

## Reference map

| File                    | Covers                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| `reference/evidence.md` | per-forge retrieval, the fallback, selecting among several failures, what a degenerate log means |
| `reference/dispatch.md` | composing the report, dispatching the bug workflow, and what this skill must never do            |

## Step 0 — Preflight

Read-only. Establishes what this run can do before it promises anything.

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/pipeline-evidence.sh"
```

Record: `forge`, `retrieval_path`, `dispatch_target`.

**The forge is decided here and nowhere else.** Never re-detected later, never inferred from the argument's wording — a `github.com` URL in a pasted log does not make this repository's remote GitHub.

`retrieval_path` is `cli` when the matching CLI is present and authenticated, and `maintainer-supplied` otherwise. **Announce which before Step 1** — discovering it partway is the failure this probe exists to prevent.

An unsupported forge, no remote, or a missing CLI sets `maintainer-supplied` and is reported with the reason. That is an ordinary outcome, not a failure.

`dispatch_target` — `ccd-speckit-bug-run` in the session's available-skills listing. **Missing → stop.** Unlike a missing CLI this has no fallback: dispatching it is the skill's entire function, and doing the work inline would reimplement a governed workflow. A filesystem test is not the probe and never the sole evidence of absence; where neither the listing nor a check of `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-bug-run/SKILL.md` settles it, treat it as present — a dispatch that fails is visible, a probe that guessed absence is not.

## Step 1 — Evidence

Read `reference/evidence.md` first. It carries each forge's commands in that forge's own vocabulary; **never one instruction covering both**, because `gh` and `glab` disagree on the shape of every operation and the wrong one succeeds rather than erroring.

More than one failed run, or more than one failing job → **`AskUserQuestion`**. Never choose. Several jobs may be selected together, and the composed report then covers them.

The failing output is **displayed before any cause is proposed**. A long log is shown as its failing region with the omission marked, never silently truncated.

Retrieval impossible, or empty, truncated or expired by retention → say which of those occurred, ask for the failing output, and continue. This does not stop the run.

## Step 2 — Root cause

Propose one, with the **specific evidence** supporting it quoted from what was displayed. Approve before anything changes.

Two terminal exits, both taken **before** any dispatch:

- **Cause outside the repository's content** — a provider outage, an expired credential, a runner fault, an upstream break in something this repository does not pin. Report it as the finding and stop. This is a successful diagnosis; report it as one rather than apologising for producing no code change.
- **The fix would add or alter a requirement.** Report that this is feature work, name `/ccd-speckit-run` as its path, and stop. Constitution Principle VI makes this a hard boundary, not a preference: feature work must not reach implementation without a spec, a plan and a task list.

## Step 3 — Approach

At least **two** stated alternatives. One "alternative" does not satisfy this. Each says what it does and what it costs; exactly one is recommended, with the reason.

The user chooses. This skill does not.

## Step 4 — Compose and dispatch

Read `reference/dispatch.md`.

The report carries the evidence, the approved root cause and the chosen approach. **Show it verbatim and let it be revised** before it is sent — from the moment it is approved it is the user's report, and it is never rewritten afterwards.

```text
Skill(skill: "claude-code-devkit:ccd-speckit-bug-run")
```

**Dispatch is a tool call.** Writing the name in prose invokes nothing, and the run then proceeds under none of that skill's rules.

After dispatch, that skill owns the run: three gated stages, the loop-back offer, its commit dispatch and its review request. Report where things ended and stop.

## Outcomes

A closed set. A value outside it is an error condition, not a sixth branch.

| Outcome                       | Meaning                                                      |
| ----------------------------- | ------------------------------------------------------------ |
| `dispatched`                  | the report was sent; the bug workflow reports its own result |
| `stopped: outside-repository` | a diagnosis, not a failure                                   |
| `stopped: feature-work`       | belongs in the eight-phase pipeline                          |
| `stopped: no-failed-run`      | nothing failed; nothing to do                                |
| `stopped: no-dispatch-target` | `ccd-speckit-bug-run` is not installed                       |
| `stopped: declined`           | the user stopped at a gate                                   |

## Red flags — stop and re-read

| Thought                                                          | Reality                                                                                                                                                          |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "I can see the fix, so just make it"                             | This skill edits no source. The fix happens through the dispatched workflow or it does not happen.                                                               |
| "The bug workflow is a wrapper, so dispatch its stages directly" | Those three stages are governed by `.claude/rules/spec-kit-bug-workflow.md`, and the wrapper is what applies it. Reaching past it forks that governance.         |
| "The log mentions gitlab.com, so use `glab`"                     | The forge came from the remote at Step 0. A URL inside a log says nothing about where this repository lives.                                                     |
| "No CLI, so this run cannot proceed"                             | A missing CLI is a reported skip of the retrieval path, not a failure. Ask for the output and continue.                                                          |
| "The log is empty, so nothing failed"                            | An empty log is reported as empty. It is not evidence of anything, least of all of success.                                                                      |
| "Only one failed run looks relevant, so pick it"                 | More than one candidate means ask. Choosing silently is how the wrong failure gets fixed.                                                                        |
| "The report has a URL in it, so fetch it first"                  | Never pre-fetch. `speckit-bug-assess` applies its own host allowlist and untrusted-input policy; handing it prose instead of a URL means those rules never fire. |
| "This needs a new config option, but it is only small"           | A change that adds or alters a requirement is feature work whatever prompted it. Stop and name `/ccd-speckit-run`.                                               |

## Authoring note

Do not hard-wrap long lines when editing this skill or its reference files. One line per paragraph, bullet or table row, however long. Script bodies are code — never compress them. After editing, re-run `evaluations.md`.

**Never add `disable-model-invocation` to this skill.** Zero of the eight in this plugin carry it, and that is a committed contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`. Nothing dispatches this skill today, but the field's documented meaning is ambiguous about explicit `Skill` calls, and the ambiguity is one-sided: under the strict reading the field breaks a future dispatch, and under the permissive reading omitting it costs nothing. Its gate is in the workflow — the root cause and the approach are both approved before anything changes.

**Never add `user-invocable`.** Its absence is what leaves the skill invocable; `false` would hide it from the `/` menu.

**Keep the forge in one place.** `forge-detect.sh` decides it, Step 0 records it, `reference/evidence.md` reads it. A second detection gives the run two answers that can disagree, and the one that loses is always the one the user was shown.
