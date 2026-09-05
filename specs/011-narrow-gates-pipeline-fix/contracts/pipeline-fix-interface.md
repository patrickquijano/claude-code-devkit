# Contract: `ccd-pipeline-fix` — inputs, evidence, dispatch and outcomes

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

The eighth distributed skill. It takes a maintainer from a failed CI pipeline to a verified fix **by dispatching `claude-code-devkit:ccd-speckit-bug-run`**, and it does none of that workflow's work itself.

## Three standing rules

**It runs no stage.** `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test` are never dispatched from here. `ccd-speckit-bug-run` owns them, together with the whole of `.claude/rules/spec-kit-bug-workflow.md` — the closed outcome vocabularies, `bug-outcome.sh`, `partial` handling, the uncapped loop-back, the commit and the review request.

**It edits no source.** FR-014. If the fix cannot happen through the dispatched workflow, it does not happen here instead.

**It changes nothing before the maintainer has approved a root cause and chosen an approach.** Reading the repository, probing the CLI and retrieving logs are not covered — they are how the first question gets something to state.

## Input

The skill's argument is free text: a pipeline URL, a run id, a branch name, a pasted failure, or nothing at all. Nothing is required.

Empty argument → resolve the most recent failed run on the current branch and confirm it with the maintainer. Never infer a failure from the conversation.

## Step 0 — Preflight

Read-only. Establishes what the run can do before it promises anything.

| Probe                           | Source                                                                      | Recorded as                        |
| ------------------------------- | --------------------------------------------------------------------------- | ---------------------------------- |
| Forge                           | `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh"` | `forge`, `forge_host`, `forge_cli` |
| CLI present and authenticated   | `gh auth status` / `glab auth status`                                       | `retrieval_path`                   |
| `ccd-speckit-bug-run` installed | the session's available-skills listing                                      | `dispatch_target`                  |
| Bug extension present           | the listing again, for the three stages                                     | reported, not required here        |

**Read the `verdict` line, never the exit status.** `exit 0` means the check ran.

**The forge is decided here and nowhere else.** Never re-detected later, never inferred from the argument's wording. A `github.com` URL in a bug report does not make the repository's remote GitHub.

`retrieval_path` is `cli` when the matching CLI is present and authenticated, and `maintainer-supplied` otherwise. **It is announced before Step 1** (FR-011c). Discovering it partway is the failure this probe exists to prevent.

`forge` of `other` or `none` → `retrieval_path` is `maintainer-supplied`, reported with the host named. That is an ordinary outcome, not a failure (FR-010).

`dispatch_target` missing → **stop**. Unlike a missing CLI, this has no fallback: the skill's entire function is to dispatch it, and doing the work inline would reimplement a governed workflow.

## Step 1 — Evidence

### Selecting the run

| Forge  | List                           | Detail                           | Failing log                     |
| ------ | ------------------------------ | -------------------------------- | ------------------------------- |
| GitHub | `gh run list --status failure` | `gh run view <id>`               | `gh run view <id> --log-failed` |
| GitLab | `glab ci list --status failed` | `glab ci get --pipeline-id <id>` | `glab ci trace <job-id>`        |

Each forge's rule is written in its own vocabulary, in its own section of `reference/evidence.md`. **Never one instruction covering both** — `.claude/rules/forge-review-requests.md` records that `gh` and `glab` disagree on the shape of every operation and that the wrong one succeeds rather than erroring.

More than one failed run, or more than one failing job → **ask** (FR-017). Never choose. The maintainer may select several jobs; the composed report then covers them together.

### Displaying it

The failing output is shown to the maintainer **before** any cause is proposed (FR-011). Long logs are shown as the failing region with the omission marked, never silently truncated.

### When retrieval does not work

`retrieval_path = maintainer-supplied`, or a retrieval that errors mid-run → say which of the four occurred (no CLI, not authenticated, call failed, unsupported forge) and ask the maintainer to paste the failing output. **This does not stop the run** (FR-011b).

Retrieved but empty, truncated, or expired by retention → the same path. An empty log is reported as empty, never treated as "no failure found".

## Step 2 — Root cause

Proposed with the specific evidence supporting it, and approved before anything changes (FR-012).

Two terminal exits, both taken **before** dispatch:

- **Cause outside the repository's content** — an outage, an expired credential, a runner fault, an upstream break in something the repository does not pin. Report it as the finding and stop (FR-018). This is a successful diagnosis, and the run says so rather than apologising for producing no code change.
- **The fix would add or alter a requirement** — report that this is feature work, name `/ccd-speckit-run` as the path for it, and stop (FR-019). Constitution Principle VI is what makes this a hard boundary rather than a preference.

## Step 3 — Approach

At least two stated alternatives, with effect and cost each, one recommended with its reason (FR-013, and the question standard). The maintainer chooses. A single "alternative" does not satisfy this.

## Step 4 — Compose and dispatch

The report carries the evidence, the approved root cause, and the chosen approach. It is **shown verbatim and is revisable** before it is sent.

```text
Skill(skill: "claude-code-devkit:ccd-speckit-bug-run")
```

**Dispatch is a tool call.** Writing the name in prose invokes nothing, and the run would then proceed under none of that skill's rules.

What travels, and what does not:

- The root cause and approach travel **as report content**, because `reference/stages.md` states that Stage 1 receives the report and Stages 2 and 3 receive nothing but the slug. Restating assessment content in a stage argument duplicates a file the stage is about to read.
- **No URL inside the report is pre-fetched.** `speckit-bug-assess` applies its own host allowlist and untrusted-input policy; fetching first hands it prose instead of a URL and its rules never fire.
- A slug travels only if the maintainer supplied one. It is flat and user-named — no `NNN-` prefix, no `specs/` root.

After dispatch, `ccd-speckit-bug-run` owns the run: its three gated stages, the loop-back offer on `partial` or `failed`, its commit dispatch and its review request. This skill reports where things ended and stops.

## Outcomes

| Outcome                       | Meaning                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------- |
| `dispatched`                  | the report was sent; the bug workflow's own outcome is that workflow's to report |
| `stopped: outside-repository` | FR-018 — a diagnosis, not a failure                                              |
| `stopped: feature-work`       | FR-019                                                                           |
| `stopped: no-failed-run`      | nothing failed; nothing to do                                                    |
| `stopped: no-dispatch-target` | `ccd-speckit-bug-run` not installed                                              |
| `stopped: declined`           | the maintainer stopped at a gate                                                 |

`stopped: no-failed-run` is reported plainly and is not an error (FR-010's spirit): a maintainer who asks about a pipeline that is green gets told it is green.

## Prohibited

- Dispatching `speckit-bug-assess`, `speckit-bug-fix` or `speckit-bug-test` directly.
- Editing any source file.
- Re-detecting the forge after Step 0, or inferring it from the argument.
- Forking `forge-detect.sh` rather than reaching the shared copy.
- Carrying `disable-model-invocation` or `user-invocable` in frontmatter.
- Proposing a cause before the evidence has been displayed.
- Choosing among several failed runs or jobs without asking.
- Pre-fetching a URL that appears in the composed report.
- Treating an empty or truncated log as evidence of anything.
