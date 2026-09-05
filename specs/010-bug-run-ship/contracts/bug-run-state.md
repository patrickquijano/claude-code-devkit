# Contract: the extended run-state file

Path: `.specify/.speckit-bug-run-state.json`. Gitignored, beside `ccd-speckit-run`'s own state file. Established by feature 009; this contract records what 010 adds and the rules that govern it. Field-by-field shape is in [`../data-model.md`](../data-model.md).

## Why the file exists at all

An invoked skill is re-attached after compaction only up to a token budget, so the later half of a long skill's body is what a long run loses first — and it is never re-read from disk. The steps 010 adds are precisely the ones that run last. Every fact those steps need is therefore in this file rather than in the skill's prose or in the conversation.

## Write rules

- **Every step writes its own `steps.N`**, the way every stage writes `stages.N`. A precondition can only read what some step actually wrote; a key nobody writes makes the check decorative.
- `steps.N` records whether the step **ran**, never whether its outcome was good.
- **`workspace` is written the moment Step 1's answer returns**, before the mode is acted on. A mode held only in the conversation is a mode a compacted run cannot read.
- **`tooling.forge` and `tooling.review_skill` are written at Step 0 and read at Step 4b.** Never re-detect the forge at shipping time and never infer it from the bug report. `other` and `none` are ordinary values meaning this run has no review-request step.
- **`ship.subskill_calls.*` is written `invoked` only after the tool call returned.** A run that produced commits, or a review request, with no entry here did the work inline — which means the sub-skill's rules never loaded. Treat it as unfinished, not as done.
- **`cycles` starts at `1` and increments on entry to a re-run assessment**, never on the first pass. It is never reset and never capped (FR-011a).
- `ship.uncommitted` holds every path still dirty **after** any commit dispatch. Empty after a run that edited source files and never dispatched the commit skill means the check never ran, not that the tree was clean.
- **A stage is never recorded complete until its artifact has been confirmed on disk** (FR-015, carried forward from 009). This applies to a re-entered stage exactly as to a first-pass one.
- `worktree.created: false` is what tells Step 4c to skip teardown. A worktree the session was already inside is not this run's to remove.
- `worktree.teardown` and `branch.teardown` never both carry a value; `workspace` decides which question was asked.
- Update as each step finishes, **before** asking anything it needs to ask, so an interrupted run leaves accurate state behind.
- A value here always beats a recollection from earlier in the conversation.

## Preconditions

Before acting, every step reads the file and checks its predecessor is `done` or `skipped`. Predecessor `pending` or `failed` → do not run; name the unfinished step and stop.

| Step             | Predecessor | Additional precondition             |
| ---------------- | ----------- | ----------------------------------- |
| Step 1 workspace | `steps.0`   | —                                   |
| Stage 1 assess   | `steps.1`   | `workspace` non-null                |
| Stage 2 fix      | `stages.1`  | assessment verdict is not `invalid` |
| Stage 3 test     | `stages.2`  | fix status is not `not-applied`     |
| Step 4a commit   | `stages.3`  | test result is `verified`           |
| Step 4b review   | `steps.4a`  | commit range non-empty              |
| Step 4c teardown | `steps.4b`  | `ship.review_request.url` non-null  |

A `version: 1` file predates the `tooling`, `workspace`, `worktree`, `branch`, `cycles` and `ship` blocks. Re-run preflight once and write the `version: 2` fields before any step acts on them; an absent `review_skill` is exactly what a guess fills in.

## What is deliberately not stored

- The bug report's fetched contents. The run never retrieves a URL itself (FR-004, carried from 009); the assessment stage owns that, with its own untrusted-input policy.
- Anything credential-shaped. What the commit skill receives is the explicit path list Step 4a displayed, minus anything credential-shaped — the fix stage writes files unattended, and handing over the dirty tree wholesale is how a generated key reaches the remote.
