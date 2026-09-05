# Run state

`SKILL.md` is never re-read from disk, and compaction re-attaches an invoked skill only up to a token budget. A run that walks three gated stages and a closing report can outlive the part of its own prose that told it what Stage 1 concluded. So the facts live in a file instead.

Path: `.specify/.speckit-bug-run-state.json`. Gitignored, beside `ccd-speckit-run`'s own state file. Internal bookkeeping — never committed, and never counted as the run's output.

## Shape

```json
{
  "version": 1,
  "report": "the bug report as supplied, verbatim",
  "slug": "login-timeout",
  "bug_dir": ".specify/bugs/login-timeout",
  "preflight": {
    "capability": "present",
    "stages": { "assess": "found", "fix": "found", "test": "found" },
    "dirty": "yes",
    "dirty_paths": ["src/auth.ts"],
    "slug_taken": "no"
  },
  "steps": { "0": "done" },
  "stages": {
    "1": "done",
    "2": "skipped: assessment verdict is invalid",
    "3": "skipped: stage 2 was skipped"
  },
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
  "closing": { "reported": false, "commit_reminder_given": false }
}
```

## Who writes what

| Field                       | Written at                                                                   |
| --------------------------- | ---------------------------------------------------------------------------- |
| `report`, `slug`, `bug_dir` | Step 0, from the maintainer's input and the preflight's normalised slug      |
| `preflight`                 | Step 0, from `bug-preflight.sh`'s output verbatim                            |
| `steps.0`                   | Step 0, on completion                                                        |
| `stages.N`                  | that stage, on completion — `done`, `skipped: <reason>` or `failed: <error>` |
| `outcomes`, `reports`       | after each stage, from `bug-outcome.sh`                                      |
| `closing`                   | the closing report                                                           |

## Rules

- **Every stage writes its own `stages.N`.** A precondition can only read what something actually wrote; a key nobody writes makes the check decorative.
- **`stages.N` records what the stage did, never the approval that allowed it.** `done` on a stage that ran, `skipped: <reason>` on one the branch table skipped, `failed: <error>` on one that errored.
- **`done` means the report was seen on disk.** Never write it on the strength of a dispatch that appeared to succeed. `bug-outcome.sh` reporting that stage's file as `present` is the evidence.
- **`outcomes` comes from `bug-outcome.sh`, never from recollection.** A value here beats anything remembered from earlier in the conversation. This is the whole reason the file exists.
- **`report` holds the maintainer's input verbatim.** Never rewritten, never summarised, never resolved from a URL. It is what Stage 1 receives, and what a resumed run would send again.
- **`preflight.dirty_paths` is captured before Stage 2 runs**, so the closing report can tell what was already modified from what the remediation changed. The remediation's own change record supplies the other half.
- **Read it before acting; update it before asking.** A stage that updates state only after its gate leaves an interrupted run describing something that did not happen.
- **A stopped run is resumed by re-invoking the skill with the same slug**, not from this file. The preflight finds the existing bug directory and `bug-outcome.sh` reports which stages already have reports; the branch table resumes at the first one that is `absent`. This file is a convenience for the current session, not the source of resumability — which is why losing it costs nothing but a re-read.

## What does not go here

- **The reports themselves.** They are the stages' output and are committed; this file is not.
- **Anything the three reports already record.** Duplicating a verdict here creates a second copy that can disagree with the first, and the one that loses is always the one the maintainer was shown.
- **Approvals.** What the maintainer agreed to is in the conversation and in what actually happened. Recording an approval here would invite a resumed run to treat it as still standing.
