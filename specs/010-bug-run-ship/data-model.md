# Data model: Bug triage run ships its own work

The only persisted state is `.specify/.speckit-bug-run-state.json`, gitignored, established by feature 009 and extended here. Entities below map to the spec's Key Entities section.

## Entity: run state (the file as a whole)

| Field       | Type           | Written at      | Notes                                                                                                                                    |
| ----------- | -------------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `version`   | integer        | Step 0          | `2` for this feature. A `version: 1` file predates the workspace and ship blocks; migrate by re-running preflight before acting on them. |
| `report`    | string         | Step 0          | The bug report as supplied. Unchanged from 009.                                                                                          |
| `slug`      | string         | Step 0          | Normalised by `bug-preflight.sh`. Unchanged.                                                                                             |
| `bug_dir`   | string         | Step 0          | `.specify/bugs/<slug>`. Unchanged.                                                                                                       |
| `preflight` | object         | Step 0          | Unchanged.                                                                                                                               |
| `tooling`   | object         | Step 0          | **NEW** — see below.                                                                                                                     |
| `workspace` | string         | Step 1          | **NEW** — `checkout` or `worktree`. Written the moment the answer returns, before the mode is acted on.                                  |
| `worktree`  | object or null | Step 1          | **NEW** — null in checkout mode.                                                                                                         |
| `branch`    | object         | Step 1, Step 4c | **NEW** — checkout mode's counterpart to `worktree`.                                                                                     |
| `steps`     | object         | each step       | Extended with `1` and `4`.                                                                                                               |
| `stages`    | object         | each stage      | Unchanged shape; values may now be written more than once (see `cycles`).                                                                |
| `cycles`    | integer        | Stage 3         | **NEW** — how many times assessment has been entered. Starts at `1`.                                                                     |
| `outcomes`  | object         | each stage      | Unchanged. On a re-entered cycle these are overwritten by the new stage's report.                                                        |
| `reports`   | object         | each stage      | Unchanged.                                                                                                                               |
| `ship`      | object         | Step 4          | **NEW** — see below.                                                                                                                     |
| `closing`   | object         | closing report  | Extended with the shipping fields.                                                                                                       |

## Entity: `tooling`

Resolved once at Step 0, read later rather than re-derived. Mirrors `ccd-speckit-run`'s block of the same name and for the same reason: a forge inferred at shipping time, six stages after the evidence was in hand, is a forge that can be inferred wrongly.

| Field                | Values                                                                             | Notes                                                                                                                                       |
| -------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `forge`              | `github` \| `gitlab` \| `other` \| `none`                                          | From `forge-detect.sh`. `other` and `none` are ordinary results meaning this run has no review-request step.                                |
| `forge_host`         | string                                                                             | The detected host, named in any skip reason.                                                                                                |
| `review_skill`       | `claude-code-devkit:ccd-github-pr` \| `claude-code-devkit:ccd-gitlab-mr` \| `none` | The only place the review skill is decided.                                                                                                 |
| `forge_cli`          | `gh` \| `glab` \| `none`                                                           |                                                                                                                                             |
| `forge_cli_status`   | `ready` \| `unauthenticated` \| `absent` \| `n-a`                                  |                                                                                                                                             |
| `commit_skill`       | boolean                                                                            | Whether `claude-code-devkit:ccd-commit-push` resolved. False drops the commit option and says why; it never falls back to an inline commit. |
| `worktree_supported` | boolean                                                                            | False withholds the worktree option with a stated reason.                                                                                   |
| `enter_worktree`     | boolean                                                                            | Whether the session can actually move. False withholds the option — a worktree created and not entered is worse than none.                  |

## Entity: `workspace` and `worktree`

`workspace` is the discriminator. It decides which question Step 1 asked, which teardown Step 4c offers, and — in `worktree` mode — which directory this state file itself lives in.

| Field                   | Values                                                                                   | Notes                                                                                                                           |
| ----------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `workspace`             | `checkout` \| `worktree`                                                                 | Written before the mode is acted on. A mode held only in conversation is one a compacted run cannot read.                       |
| `worktree.path`         | string                                                                                   | Absolute. `.claude/worktrees/<slug>`.                                                                                           |
| `worktree.original_dir` | string                                                                                   | Where the session started. Teardown needs somewhere to return to.                                                               |
| `worktree.created`      | boolean                                                                                  | **Distinguishes a worktree this run made from one the session was already inside.** `false` means Step 4c never offers removal. |
| `worktree.teardown`     | `stayed` \| `exited-kept` \| `exited-removed` \| `exited-removed-branch-deleted` \| null | Null after a worktree run means Step 4c never ran, which the closing report states rather than glosses.                         |
| `branch.created`        | boolean                                                                                  | Whether this run cut the branch.                                                                                                |
| `branch.name`           | string or null                                                                           |                                                                                                                                 |
| `branch.previous`       | string or null                                                                           | What to return to.                                                                                                              |
| `branch.teardown`       | `stayed` \| `switched-kept` \| `switched-deleted` \| null                                | Null in worktree mode. `workspace` decides which of the two teardown fields carries a value; they never both do.                |

## Entity: `ship`

| Field                   | Type                                      | Notes                                                                                                                                                                                          |
| ----------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subskill_calls.commit` | `invoked` \| `skipped: <reason>`          | Written `invoked` only after the tool call returned. A run that produced commits with no entry here did the work inline, which means the sub-skill's rules never loaded — treat as unfinished. |
| `subskill_calls.review` | `invoked` \| `skipped: <reason>`          | Same discipline.                                                                                                                                                                               |
| `review_request.forge`  | `github` \| `gitlab` \| null              |                                                                                                                                                                                                |
| `review_request.kind`   | `pull request` \| `merge request` \| null | Reported verbatim so a summary never calls one the other.                                                                                                                                      |
| `review_request.url`    | string or null                            | Null when the review step was skipped; the reason lives in `subskill_calls.review`.                                                                                                            |
| `review_request.target` | string or null                            | Learned _from_ the review skill, never supplied _to_ it. Step 4c's switch destination.                                                                                                         |
| `uncommitted`           | array of strings                          | Every path still dirty after any commit dispatch. Empty after a run that edited source and never dispatched means the check never ran, not that the tree was clean.                            |
| `branches_deleted`      | array of strings                          |                                                                                                                                                                                                |
| `branches_kept`         | array of objects                          | `{branch, reason}`.                                                                                                                                                                            |

## State transitions

### Stage progression, with the loop

```text
Step 0 preflight → Step 1 workspace → Stage 1 assess → Stage 2 fix → Stage 3 test
                                            ▲                             │
                                            └──── cycles += 1 ────────────┘
                                              (maintainer's explicit choice only)
                                                                          │
                                                          result verified │
                                                                          ▼
                                        Step 4a commit → Step 4b review → Step 4c teardown
```

`cycles` increments on entry to a re-run assessment, never on the first. FR-011a forbids capping it; FR-011b requires its value be stated at the choice.

### Which stages may be re-entered

Only Stage 1. Choosing to return re-enters assessment, which then flows forward through fix and test as normal — the stages' own preconditions govern overwriting their reports, exactly as on the first pass. Nothing re-enters Stage 2 or Stage 3 directly.

### Validation rules

- `workspace` must be non-null before Stage 1 runs. Unset means Step 1 did not complete, and the run stops rather than assuming `checkout`.
- `worktree` non-null requires `workspace == "worktree"`; `branch.teardown` non-null requires `workspace == "checkout"`.
- `ship.review_request.url` non-null requires `ship.subskill_calls.review == "invoked"`.
- Step 4c runs only when `ship.review_request.url` is non-null; otherwise it is skipped with that reason.
- A destructive teardown option requires its guard satisfied: branch deletion requires the branch's commits pushed; worktree removal requires no uncommitted path in that directory whatever its origin. A guarded-out option is not offered, and its absence is explained.
