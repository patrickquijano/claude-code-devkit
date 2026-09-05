# Data Model: Guided Bug Triage Run

Phase 1 output for [plan.md](./plan.md). The feature stores nothing in a database and defines no wire format. What it does define is a state file, a set of outcome vocabularies it branches on, and the branch table those vocabularies drive. Those are the model.

## Contents

- [Entities](#entities)
- [The three outcome vocabularies](#the-three-outcome-vocabularies)
- [The branch table](#the-branch-table)
- [State file](#state-file)
- [Where an outcome is found](#where-an-outcome-is-found)
- [Validation rules](#validation-rules)

## Entities

| Entity                  | Owned by             | Location                                                        | Lifetime             |
| ----------------------- | -------------------- | --------------------------------------------------------------- | -------------------- |
| **Bug report**          | the maintainer       | supplied as the run's argument; never persisted by this feature | the run              |
| **Bug slug**            | the `bug` extension  | the directory name under `.specify/bugs/`                       | permanent, committed |
| **Assessment report**   | `speckit-bug-assess` | `.specify/bugs/<slug>/assessment.md`                            | permanent, committed |
| **Change record**       | `speckit-bug-fix`    | `.specify/bugs/<slug>/fix.md`                                   | permanent, committed |
| **Verification report** | `speckit-bug-test`   | `.specify/bugs/<slug>/test.md`                                  | permanent, committed |
| **Run state**           | this skill           | `.specify/.speckit-bug-run-state.json`                          | the run; gitignored  |
| **Preflight facts**     | `bug-preflight.sh`   | stdout, then copied into run state                              | the run              |

This feature **writes exactly one** of these: run state. The three reports are written by the stages it invokes, which is the point — FR-006 forbids the run from doing a stage's work itself.

## The three outcome vocabularies

Closed sets. FR-007 and FR-008 are exhaustive over the first two; FR-010 and FR-028 over the third. A value outside its set is an error condition, not a fourth branch.

**Assessment — Verdict** (`speckit-bug-assess/SKILL.md:115`)

| Value                              | Meaning                       | Run's branch                                   |
| ---------------------------------- | ----------------------------- | ---------------------------------------------- |
| `valid`                            | a real defect, established    | proceed to Stage 2                             |
| `likely valid, needs reproduction` | probably real, not reproduced | proceed to Stage 2, and say so at its boundary |
| `invalid`                          | not a real defect             | skip Stage 2 and Stage 3, with the reason      |

**Assessment — Severity** (`speckit-bug-assess/SKILL.md:116`): `critical`, `high`, `medium`, `low`. Reported, never branched on. It informs the maintainer's decision at the Stage 2 boundary; it does not make one.

**Remediation — Status** (`speckit-bug-fix/SKILL.md:72`)

| Value         | Meaning                             | Run's branch                                                    |
| ------------- | ----------------------------------- | --------------------------------------------------------------- |
| `applied`     | the remediation was applied in full | proceed to Stage 3                                              |
| `partial`     | applied in part                     | proceed to Stage 3, carrying the status into the closing report |
| `not-applied` | nothing was changed                 | skip Stage 3, with the reason                                   |

**Validation — Result** (`speckit-bug-test/SKILL.md:82`)

| Value      | Meaning                                                      | Run's branch                                                |
| ---------- | ------------------------------------------------------------ | ----------------------------------------------------------- |
| `verified` | the defect is resolved                                       | the run may complete                                        |
| `partial`  | resolved in part, or a listed reproduction was not exercised | stop, present the finding, put the choice to the maintainer |
| `failed`   | the defect still reproduces                                  | stop, present the finding, put the choice to the maintainer |

`partial` and `failed` are treated identically (FR-028). Neither is an ending the run may reach on its own.

## The branch table

The whole control flow, in one place. `→` is "proceed to"; a skip is announced at its own boundary before it is taken (FR-009).

| At            | Condition                                  | Stage 2                              | Stage 3                    | Run ends                                      |
| ------------- | ------------------------------------------ | ------------------------------------ | -------------------------- | --------------------------------------------- |
| after Stage 1 | Verdict `invalid`                          | **skipped**                          | **skipped**                | closing report, no source change              |
| after Stage 1 | Verdict `likely valid, needs reproduction` | → , boundary states "not reproduced" | per Stage 2's status       | —                                             |
| after Stage 1 | Verdict `valid`                            | →                                    | per Stage 2's status       | —                                             |
| after Stage 2 | Status `not-applied`                       | —                                    | **skipped**                | closing report                                |
| after Stage 2 | Status `partial`                           | —                                    | → , status carried forward | —                                             |
| after Stage 2 | Status `applied`                           | —                                    | →                          | —                                             |
| after Stage 3 | Result `verified`                          | —                                    | —                          | closing report, run complete                  |
| after Stage 3 | Result `partial` or `failed`               | —                                    | —                          | **stop and ask**; not described as successful |
| any boundary  | maintainer chooses Stop                    | not invoked                          | not invoked                | closing report of what exists so far          |
| any stage     | outcome value absent or unrecognised       | —                                    | —                          | **stop**; never guess a branch                |

The last row is [G3](./research.md#recorded-gaps) made operational: the field labels are Markdown, not a schema, so an unreadable outcome stops the run rather than defaulting.

### After a stop

A stopped run leaves whatever reports exist on disk and does not delete or roll back anything. **Resuming is re-invoking the skill with the same slug**, not a distinct resume mode: the preflight finds the existing bug directory, `bug-outcome.sh` reports which reports are present, and the branch table resumes from the first stage whose report is `absent`. This costs no extra machinery because the `bug` extension's own preconditions already work this way — `speckit-bug-fix` requires `assessment.md`, `speckit-bug-test` requires both. The state file is a convenience for the current session, not the source of resumability.

**A stop that follows a source edit is reported as one.** Where Stage 2 has already run when the maintainer stops, the closing report must state that source files were modified, name the change record that lists them, and repeat the paths the preflight reported as already-dirty beforehand — so the maintainer can tell the two apart without reconstructing it. The run does not offer to revert: undoing a remediation is a git operation, and FR-020 keeps the run out of git.

### Where each stage's wording comes from

FR-011 requires the maintainer to see the exact wording a stage will receive. That wording is **composed by the run**, not supplied by the maintainer and not fixed in advance:

| Stage     | Wording it receives                                                                                                                                                                                                              |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1, assess | the bug report exactly as supplied, plus `slug=<slug>` when the maintainer gave one. Nothing added, nothing summarised (FR-004, D9)                                                                                              |
| 2, fix    | `slug=<slug>` only. The remediation stage reads `assessment.md` itself and treats its sections as its contract (`speckit-bug-fix/SKILL.md:43`); restating them in the argument would duplicate a file the stage is about to read |
| 3, test   | `slug=<slug>` only, for the same reason                                                                                                                                                                                          |

The maintainer may revise any of these at its boundary (FR-012), which is what makes "composed by the run" acceptable rather than opaque.

## State file

`.specify/.speckit-bug-run-state.json`, gitignored. Written after every step and every stage, before anything that step needs to ask.

```json
{
  "version": 1,
  "report": "the bug report as supplied, verbatim",
  "slug": "login-timeout",
  "bug_dir": ".specify/bugs/login-timeout",
  "skill_dir": "resolved ${CLAUDE_SKILL_DIR}",
  "preflight": {
    "capability": "present | absent",
    "stages": { "assess": "found", "fix": "found", "test": "found" },
    "dirty_paths": ["src/auth.ts"],
    "slug_taken": false
  },
  "steps": { "0": "done", "1": "done" },
  "stages": {
    "1": "done",
    "2": "skipped: assessment verdict is invalid",
    "3": "pending"
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

### Rules

- Every step and stage writes its own key. A precondition can only read what something actually wrote; a key nobody writes makes the check decorative.
- `stages.N` is `done`, `skipped: <reason>`, `failed: <error>` or `pending`. It records what the stage did, never the approval that allowed it.
- A stage is `done` only once its report has been seen on disk (FR-015). Never on the strength of a call that appeared to succeed.
- `outcomes` is populated from `bug-outcome.sh`, never from recollection (FR-016). A value here beats anything remembered from earlier in the conversation.
- `preflight.dirty_paths` is captured **before** Stage 2 runs, so the closing report can distinguish what was already modified from what the remediation changed (FR-029).
- `report` holds the maintainer's input verbatim. It is never rewritten, summarised, or resolved from a URL (FR-004, D9).
- The file is internal bookkeeping and is gitignored. It is never committed and never counted as the run's output.

## Where an outcome is found

`bug-outcome.sh` reads the bold field labels the extension's own output templates emit. This is the whole extraction contract:

| Field    | Report          | Label as emitted | Template source                   |
| -------- | --------------- | ---------------- | --------------------------------- |
| Verdict  | `assessment.md` | `**Verdict**:`   | `speckit-bug-assess/SKILL.md:115` |
| Severity | `assessment.md` | `**Severity**:`  | `speckit-bug-assess/SKILL.md:116` |
| Status   | `fix.md`        | `**Status**:`    | `speckit-bug-fix/SKILL.md:72`     |
| Result   | `test.md`       | `**Result**:`    | `speckit-bug-test/SKILL.md:82`    |

A label that is present but carries a value outside its vocabulary, and a label that is absent entirely, both yield `unknown`. The skill stops on `unknown`; it does not pick the nearest value.

## Validation rules

Drawn from the spec's requirements, stated here as checkable conditions.

| Rule                                                                                                 | From           |
| ---------------------------------------------------------------------------------------------------- | -------------- |
| Exactly one bug report per run; more than one is refused before Stage 1                              | FR-021, FR-023 |
| The report reaches Stage 1 byte-identical to what was supplied                                       | FR-004, FR-009 |
| A slug already present under `.specify/bugs/` is reported before Stage 1, and the maintainer decides | FR-003         |
| Every stage boundary states command, verbatim wording, and artifacts before asking                   | FR-011         |
| A skipped stage is announced at its boundary with its reason                                         | FR-009         |
| No stage is recorded `done` without its report existing                                              | FR-015         |
| Every outcome in the closing report is read from a report file                                       | FR-016, FR-017 |
| The closing report names each report's path and the commit obligation                                | FR-030         |
| Nothing in the run creates a branch, commits, or opens a review request                              | FR-020         |
