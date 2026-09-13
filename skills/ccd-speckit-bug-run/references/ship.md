# Shipping — Step 4a's commit, Step 4b's review request

Entered only when Stage 3 recorded `result verified`. Mirrored from `ccd-speckit-run`'s `reference/ship.md` sub-steps 6a and 6b; the reasoning lives there.

## Contents

- Dispatch is a tool call, not a phrase
- What each sub-skill owns
- Step 4a — the commit question
- Step 4b — the review request
- The skip table
- Never

## Dispatch is a tool call, not a phrase

Each sub-step runs its skill through the `Skill` tool:

```text
Skill(skill: "claude-code-devkit:ccd-commit-push")
Skill(skill: <tooling.review_skill>)
```

Writing `/ccd-commit-push` into prose, or performing the work inline because the intent is obvious, **invokes nothing**. The sub-skill's own `SKILL.md` never loads, so its batched questions and its approval gate simply do not exist for that run — and the run then produces a commit, or a review request, that none of those rules ever saw.

The namespaced form is not decoration. `claude-code-devkit:ccd-commit-push` names exactly one skill; a bare `ccd-commit-push` names whatever the session resolves it to when a personal copy is also installed. This is the opposite of the rule for the three `speckit-bug-*` stages, which are Spec Kit's and take bare names — the two rules do not conflict, they address different owners.

`tooling.review_skill` is **read from state**, never typed from memory and never inferred from the wording of the bug report. It was decided at Step 0 from `origin`.

## What each sub-skill owns

Hand over **facts, not answers**. Supplying a value suppresses the question it belongs to — each of these skills skips its own question whenever the invocation already names one — which is exactly how that value silently becomes wrong.

| Sub-skill         | Owns                                                                                                                                                        |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ccd-commit-push` | the commit message and its convention, how the change is split across commits, whether to push, its own approval gate                                       |
| `ccd-github-pr`   | **base branch**, assignee, reviewers, draft state, squash, **whether to arm auto-merge**, **whether to delete the source branch on merge**, title, template |
| `ccd-gitlab-mr`   | **target branch**, assignee, reviewers, squash-on-merge, delete-source-branch, title, description template                                                  |

What this run supplies is: the branch, the verification result, the three report paths, and the list of files Stage 2 changed.

**Auto-merge deserves its own sentence.** `ccd-github-pr` may arm `--auto`, which merges the branch the moment its checks pass — possibly before any human has read it. Whether to arm it is that skill's decision behind its own gate; naming it here is what stops this run's approval from being read as having armed it. In worktree mode, add the consequence Step 4c depends on: a source branch deleted on merge is deleted while this run's worktree still has it checked out.

## Step 4a — the commit question

**This run creates no commit.** No `git add`, no `git commit`, no `git stash`, no inline substitute, ever. What it may do — on an explicit answer, and only then — is dispatch the skill that owns commits and let it decide the message, the split and the push behind its own gate.

Report first, then ask. The report names three things:

1. The three reports under `.specify/bugs/<slug>/`, which are committed project history rather than working state.
2. Whatever Stage 2 changed, as `fix.md` lists it.
3. Whatever the preflight recorded as **already dirty before the run started**, kept separate — the maintainer's own work is not this run's to commit.

Then `AskUserQuestion`, `header: "Commit?"`, three options:

1. **Commit and push now (recommended)** — dispatch `ccd-commit-push`, handing it an **explicit list of the paths the question displayed**, path for path, minus anything credential-shaped. Stage 2 writes files unattended, and handing over the dirty tree wholesale is how a generated key reaches the remote.
2. **Open the review request on the commits that already exist** — valid when the range is non-empty. Never recommended when it is empty: a review request with no commits is not reviewable.
3. **Stop here** — the run ends with state written; re-invoking with the same slug resumes once the commits exist.

**It returns → re-check.** Re-read the dirty paths and the `<base>..HEAD` range, because changing them is the entire point of having asked. Range still empty, or the listed paths still dirty → its gate was declined or it stopped halfway. Say so and re-ask rather than proceeding on the old numbers.

Option 1 is unavailable when Step 0 recorded `ccd-commit-push` as missing. Drop it, say why, and offer only 2 and 3 — **never fall back to an inline `git commit` because the skill is absent.**

Record the dispatch in `ship.subskill_calls.commit` as `invoked` or `skipped: <reason>`. `invoked` is written only after the tool call returned.

## Step 4b — the review request

```text
Skill(skill: <tooling.review_skill>)
```

| `tooling.review_skill`             | Raises        | Asks its own                                                               |
| ---------------------------------- | ------------- | -------------------------------------------------------------------------- |
| `claude-code-devkit:ccd-github-pr` | pull request  | base, assignee, reviewers, draft, squash, auto-merge, delete-source-branch |
| `claude-code-devkit:ccd-gitlab-mr` | merge request | target, assignee, reviewers, squash, delete-source-branch                  |

Carry the verification status into what it is told, so the description says the defect was validated and by which stage.

**Name no target or base branch in the invocation** — not from state, not a guess. Same for assignee, reviewers, draft, squash, auto-merge and branch deletion.

Record the returned URL in `ship.review_request.url`, the forge in `.forge`, and whether that forge calls the result a pull request or a merge request in `.kind`. Report it under that name; a summary never calls one the other.

## The skip table

| Missing                                                 | Recorded reason                       |
| ------------------------------------------------------- | ------------------------------------- |
| `tooling.forge` is `other`                              | `skipped: unsupported forge (<host>)` |
| `tooling.forge` is `none`                               | `skipped: no remote configured`       |
| the skill `tooling.review_skill` names is not installed | `skipped: <skill> not installed`      |
| the forge's CLI is absent                               | `skipped: <gh\|glab> unavailable`     |
| the forge's CLI is present but unauthenticated          | `skipped: <gh\|glab> unauthenticated` |
| Step 4a left the commit range empty                     | `skipped: nothing committed`          |

Every one of these is an **ordinary outcome**, not a failure. The run finishes, the closing report names the reason, and Step 4c skips with it.

## Never

- Never run `git add`, `git commit` or `git push` in this run, under any circumstance, including "the skill is missing so I will just do it".
- Never re-detect the forge here. It was decided at Step 0.
- Never hand-roll a request against a forge's API because no skill matched it. An unsupported forge is a skip, not a problem to solve.
- Never supply an answer to a question the sub-skill owns.
- Never record `invoked` before the tool call returned.
- Never raise a review request on work that was never committed.
