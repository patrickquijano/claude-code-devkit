# The three stages

Read this before Stage 1. It carries the outcome vocabularies the run branches on, the branch table itself, what each stage receives, and where each outcome is found.

## Contents

- [What each stage is](#what-each-stage-is)
- [What each stage receives](#what-each-stage-receives)
- [The three outcome vocabularies](#the-three-outcome-vocabularies)
- [The branch table](#the-branch-table)
- [Where an outcome is found](#where-an-outcome-is-found)
- [What the run must never do](#what-the-run-must-never-do)

## What each stage is

The three stages are the installed Spec Kit `bug` extension's commands. They are **Spec Kit project skills**, not this plugin's, so they are dispatched through the `Skill` tool by their **bare** names. `claude-code-devkit:speckit-bug-assess` names nothing and would fail.

The bare name is still correct where the session lists **directory-scoped variants** — `<some/dir>:speckit-bug-assess` beside the unscoped one, which happens in a repository with worktrees. The bare name resolves to the unscoped skill, and that is the one to dispatch unless the defect being fixed lives inside that subtree. Namespacing does not disambiguate these; it addresses nothing.

| Stage | Skill                | Writes                               | Edits source?                    |
| ----- | -------------------- | ------------------------------------ | -------------------------------- |
| 1     | `speckit-bug-assess` | `.specify/bugs/<slug>/assessment.md` | never                            |
| 2     | `speckit-bug-fix`    | `.specify/bugs/<slug>/fix.md`        | **yes — the only one that does** |
| 3     | `speckit-bug-test`   | `.specify/bugs/<slug>/test.md`       | never                            |

Their preconditions form a chain the run must respect: Stage 2 refuses without `assessment.md`, Stage 3 refuses without both `assessment.md` and `fix.md`.

Those three reports are **committed project history** in this repository, not scratch. `.gitignore` says so explicitly, and the run's closing report says so to the maintainer.

## What each stage receives

Composed by the run, shown verbatim at the boundary before it is sent, and revisable there.

| Stage | Wording                                                                                                     |
| ----- | ----------------------------------------------------------------------------------------------------------- |
| 1     | the bug report **exactly as the maintainer supplied it**, plus `slug=<slug>` only when they supplied a slug |
| 2     | `slug=<slug>` only                                                                                          |
| 3     | `slug=<slug>` only                                                                                          |

Stages 2 and 3 get nothing but the slug on purpose. `speckit-bug-fix` reads `assessment.md` itself and treats its **Proposed Remediation**, **Files likely to change**, **Tests to add or update** and **Risks & Considerations** sections as its contract. Restating any of that in the argument would duplicate a file the stage is about to read, and the two copies would disagree the moment the maintainer revised one.

## The three outcome vocabularies

Closed sets. A value outside its set is an error condition, not a fourth branch.

**Assessment — Verdict**: `valid` · `likely valid, needs reproduction` · `invalid`

**Assessment — Severity**: `critical` · `high` · `medium` · `low` — reported, never branched on. It informs the maintainer's decision at the Stage 2 boundary; it does not make one.

**Remediation — Status**: `applied` · `partial` · `not-applied`

**Validation — Result**: `verified` · `partial` · `failed`

`valid` is a substring of `invalid`. Comparisons are on the whole value, never a prefix or substring test — `bug-outcome.sh` already does this, which is why the run reads its output rather than the reports.

## The branch table

`→` is "proceed to". A skip is announced at its own boundary, with the recorded value that caused it, before it is taken.

| At            | Condition                                  | Stage 2                              | Stage 3                    | Run ends                                        |
| ------------- | ------------------------------------------ | ------------------------------------ | -------------------------- | ----------------------------------------------- |
| after Stage 1 | Verdict `invalid`                          | **skipped**                          | **skipped**                | closing report, no source change                |
| after Stage 1 | Verdict `likely valid, needs reproduction` | → , boundary states "not reproduced" | per Stage 2's status       | —                                               |
| after Stage 1 | Verdict `valid`                            | →                                    | per Stage 2's status       | —                                               |
| after Stage 2 | Status `not-applied`                       | —                                    | **skipped**                | closing report                                  |
| after Stage 2 | Status `partial`                           | —                                    | → , status carried forward | —                                               |
| after Stage 2 | Status `applied`                           | —                                    | →                          | —                                               |
| after Stage 3 | Result `verified`                          | —                                    | —                          | → Steps 4a, 4b, 4c, then closing report         |
| after Stage 3 | Result `partial` or `failed`               | —                                    | —                          | **stop and ask**; never described as successful |
| after Stage 3 | Result `partial`/`failed`, return chosen   | re-run after Stage 1                 | re-run after Stage 2       | loops to Stage 1; `cycles` increments, no cap   |
| any boundary  | maintainer chooses Stop                    | not invoked                          | not invoked                | closing report of what exists so far            |
| any stage     | outcome `unknown` on a report that exists  | —                                    | —                          | **stop**; report extraction drift, never guess  |

**On the middle verdict.** `likely valid, needs reproduction` proceeds, and the Stage 2 boundary says the defect was not reproduced so the maintainer approves with that in view. The run raises **no question of its own** about it: `speckit-bug-fix` already asks whether to proceed when the assessment carries unresolved items, and asking first would put one decision to the maintainer twice.

**On partial results.** `partial` never means "close enough". A remediation `partial` proceeds to validation, because validation is the stage best placed to say whether the applied part was enough. A validation `partial` stops, because it can mean a listed reproduction was never exercised — that is "nobody checked", not "mostly fixed".

## Where an outcome is found

Never by reading the report yourself, and never from memory of what a stage said. Always:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/bug-outcome.sh" ".specify/bugs/<slug>"
```

It prints `assessment`/`fix`/`test` as `present` or `absent`, and `verdict`/`severity`/`status`/`result` as a vocabulary value or `unknown`. Full contract: `specs/009-bug-triage-run/contracts/bug-outcome-cli.md`.

`unknown` on a report that reads `present` means the extraction contract has drifted — the labels are Markdown emitted by the extension's templates, not a published schema. Stop and report it. Do not re-read the file yourself to "check": that is the drift the script exists to catch, and a second opinion from the same session is not evidence.

## What the run must never do

- **Never do a stage's work in place of invoking it.** If Stage 2 cannot run, the run does not edit the source itself. Ever.
- **Never fetch a URL in the bug report.** `speckit-bug-assess` applies a host allowlist and an untrusted-input policy to whatever it fetches. Fetching first and passing the text along launders that fetch past the policy — the stage would see prose, not a URL, and its rules would never fire.
- **Never rewrite, summarise or "clean up" the bug report** before Stage 1. It goes through byte-identical.
- **Never invoke a stage whose precondition is unmet.** That is what the branch table is for, and a refusal at the end of a sequence the maintainer approved in good faith teaches them to distrust the boundaries.
- **Never branch on a guessed value.** `unknown` is a stop.
- **Never create a commit or a review request itself.** The run creates neither. Step 4a asks and dispatches `claude-code-devkit:ccd-commit-push`; Step 4b asks and dispatches whichever review skill the remote calls for. No `git add`, no `git commit`, no forge API called by hand — not even when the sub-skill turns out to be missing, which is a skip with a reason rather than a licence to improvise.
- **Never re-enter a stage on the run's own initiative.** A `partial` or `failed` validation offers the return to Stage 1; taking that offer is the maintainer's decision, every time, however many cycles have already happened.
- **Never create or destroy a branch or a workspace outside Steps 1 and 4c**, and never past either guard: a branch is deleted only when its commits are pushed, a worktree removed only when nothing in it is uncommitted, whatever the origin of that work.
