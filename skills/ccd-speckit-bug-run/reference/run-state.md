# Run state

`SKILL.md` is never re-read from disk, and compaction re-attaches an invoked skill only up to a token budget. A run that walks three gated stages and a closing report can outlive the part of its own prose that told it what Stage 1 concluded. So the facts live in a file instead.

Path: `.specify/.speckit-bug-run-state.json`. Gitignored, beside `ccd-speckit-run`'s own state file. Internal bookkeeping — never committed, and never counted as the run's output.

## Shape

```json
{
  "version": 2,
  "report": "the bug report as supplied, verbatim",
  "slug": "login-timeout",
  "bug_dir": ".specify/bugs/login-timeout",
  "preflight": {
    "capability": "present",
    "stages": { "assess": "found", "fix": "found", "test": "found" },
    "dirty": "yes",
    "dirty_paths": ["src/auth.ts"],
    "slug_taken": "no",
    "git_repo": "yes",
    "worktree_supported": "yes",
    "in_worktree": "no",
    "submodules": "no"
  },
  "tooling": {
    "forge": "github",
    "forge_host": "github.com",
    "review_skill": "claude-code-devkit:ccd-github-pr",
    "forge_cli": "gh",
    "forge_cli_status": "ready",
    "commit_skill": true,
    "enter_worktree": true
  },
  "workspace": "worktree",
  "worktree": {
    "path": "/abs/path/.claude/worktrees/login-timeout",
    "original_dir": "/abs/path",
    "created": true,
    "teardown": null
  },
  "branch": { "created": true, "name": "fix/login-timeout", "previous": "main", "teardown": null },
  "steps": { "0": "done", "1": "done", "4a": "pending", "4b": "pending", "4c": "pending" },
  "stages": {
    "1": "done",
    "2": "skipped: assessment verdict is invalid",
    "3": "skipped: stage 2 was skipped"
  },
  "cycles": 1,
  "outcomes": {
    "verdict": "invalid",
    "severity": "low",
    "status": null,
    "result": null
  },
  "reports": {
    "assessment": ".specify/bugs/login-timeout/assessment.md",
    "fix": null,
    "test": null
  },
  "ship": {
    "subskill_calls": {
      "commit": "skipped: stage 3 did not run",
      "review": "skipped: nothing committed"
    },
    "review_request": { "forge": null, "kind": null, "url": null, "target": null },
    "uncommitted": [],
    "branches_deleted": [],
    "branches_kept": []
  },
  "closing": { "reported": false }
}
```

## Who writes what

| Field                                   | Written at                                                                   |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| `report`, `slug`, `bug_dir`             | Step 0, from the maintainer's input and the preflight's normalised slug      |
| `preflight`                             | Step 0, from `bug-preflight.sh`'s output verbatim                            |
| `tooling`                               | Step 0, from `forge-detect.sh` and the session's available-skills listing    |
| `steps.N`                               | that step, on completion — `done`, `skipped: <reason>` or `failed: <error>`  |
| `workspace`                             | Step 1, **the moment the answer returns**, before the mode is acted on       |
| `worktree`, `branch`                    | Step 1, once the mode was carried out and verified                           |
| `stages.N`                              | that stage, on completion — `done`, `skipped: <reason>` or `failed: <error>` |
| `cycles`                                | Stage 3, on entering a re-run assessment                                     |
| `outcomes`, `reports`                   | after each stage, from `bug-outcome.sh`                                      |
| `ship`                                  | Steps 4a and 4b, each after its dispatch returned                            |
| `worktree.teardown` / `branch.teardown` | Step 4c                                                                      |
| `closing`                               | the closing report                                                           |

## Rules

- **Every stage writes its own `stages.N`.** A precondition can only read what something actually wrote; a key nobody writes makes the check decorative.
- **`stages.N` records what the stage did, never the approval that allowed it.** `done` on a stage that ran, `skipped: <reason>` on one the branch table skipped, `failed: <error>` on one that errored.
- **`done` means the report was seen on disk.** Never write it on the strength of a dispatch that appeared to succeed. `bug-outcome.sh` reporting that stage's file as `present` is the evidence.
- **`outcomes` comes from `bug-outcome.sh`, never from recollection.** A value here beats anything remembered from earlier in the conversation. This is the whole reason the file exists.
- **`report` holds the maintainer's input verbatim.** Never rewritten, never summarised, never resolved from a URL. It is what Stage 1 receives, and what a resumed run would send again.
- **`preflight.dirty_paths` is captured before Stage 2 runs**, so the closing report can tell what was already modified from what the remediation changed. The remediation's own change record supplies the other half.
- **Read it before acting; update it before asking.** A stage that updates state only after its gate leaves an interrupted run describing something that did not happen.
- **A stopped run is resumed by re-invoking the skill with the same slug**, not from this file. The preflight finds the existing bug directory and `bug-outcome.sh` reports which stages already have reports; the branch table resumes at the first one that is `absent`. This file is a convenience for the current session, not the source of resumability — which is why losing it costs nothing but a re-read.
- **`workspace` is written the moment Step 1's answer returns**, before the mode is acted on. Step 4c reads it to decide which teardown question to ask, and a mode held only in the conversation is a mode a compacted run cannot read. `worktree` is null in checkout mode; `worktree.teardown` and `branch.teardown` never both carry a value.
- **`worktree.created` distinguishes a worktree this run made from one the session was already inside.** `false` means Step 4c never offers to remove it — that tree is not this run's to tear down.
- **`tooling.forge` and `tooling.review_skill` are written at Step 0 and read at Step 4b.** Never re-detect the forge at shipping time and never infer it from the bug report. `other` and `none` are ordinary values meaning this run has no review-request step, not that detection failed.
- **`ship.subskill_calls.*` is written `invoked` only after the tool call returned.** A run that produced commits, or a review request, with no entry here did the work inline — which means the sub-skill's rules never loaded. Treat that as unfinished, not as done.
- **`ship.uncommitted` holds every path still dirty after Step 4a's dispatch**, the run's own output and pre-existing work alike. Empty after a run that edited source and never dispatched means the check never ran, not that the tree was clean.
- **`cycles` starts at 1 and increments on entry to a re-run assessment**, never on the first pass. It is never reset and **never capped** — the loop ends when the maintainer says so. Its value is stated at every such choice, so the decision is made in view of the loop's own history.
- **A `version: 1` file predates `tooling`, `workspace`, `worktree`, `branch`, `cycles` and `ship`.** Re-run the preflight once and write the version 2 fields before any later step reads them; an absent `review_skill` is exactly what a guess fills in.

## What does not go here

- **The reports themselves.** They are the stages' output and are committed; this file is not.
- **Anything the three reports already record.** Duplicating a verdict here creates a second copy that can disagree with the first, and the one that loses is always the one the maintainer was shown.
- **Approvals.** What the maintainer agreed to is in the conversation and in what actually happened. Recording an approval here would invite a resumed run to treat it as still standing.
