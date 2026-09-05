---
paths:
  - 'skills/ccd-speckit-bug-run/**'
  - '.specify/bugs/**'
---

# The Spec Kit bug triage workflow

Reasoning and sources: [`docs/spec-kit-extensions.md`](../../docs/spec-kit-extensions.md).

## Dispatching the three stages

- The three stages — `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` — are **Spec Kit
  project skills**, compiled into `.claude/skills/` by the extension installer. They are not this
  plugin's.
- Dispatch them by their **bare** names. `claude-code-devkit:speckit-bug-assess` names nothing and
  fails at the first stage. This is not an exception to the namespacing rule in
  [`skill-authoring.md`](./skill-authoring.md); it is outside its scope, which is this plugin's own
  skills.
- The bare name stays correct where **directory-scoped variants** are also listed —
  `<some/dir>:speckit-bug-assess` beside the unscoped one, as happens in a repository with
  worktrees. It resolves to the unscoped skill. Namespacing is not the fix for that ambiguity and
  addresses nothing.
- **Never conclude the capability is absent from a filesystem test.** `bug-preflight.sh` reports
  `present` or `undetermined` and never `absent`, because a probe can establish presence and not
  absence — where a compiled skill's files live is an install detail. The session's available-skills
  listing settles it. Restoring an `absent` verdict restores a confident and wrong refusal on every
  install whose layout differs.
- The literal `/speckit-bug-*` names are correct here. Upstream forbids hard-coding a sibling
  command inside an **extension command body**, where an installer substitutes
  `__SPECKIT_COMMAND_<NAME>__` per agent. A plugin skill has no installer and one target agent, so
  the token would resolve to nothing.

## Branching on what a stage recorded

- The three outcome vocabularies are **closed sets**: verdict `valid` / `likely valid, needs
reproduction` / `invalid`; status `applied` / `partial` / `not-applied`; result `verified` /
  `partial` / `failed`. A value outside its set is an error condition, not a fourth branch.
- Read an outcome with `bug-outcome.sh`, never by reading the report and remembering it. The labels
  it matches are Markdown emitted by the extension's templates, not a published schema, so
  extraction is the one thing that must not vary between runs.
- `unknown` on a report that exists means the extraction contract has drifted. **Stop.** Never
  branch on a guessed value, and never re-read the report to second-guess the script — a second
  opinion from the same session is not evidence.
- `partial` is never "close enough". A `partial` validation result can mean a listed reproduction
  was never exercised, which is _nobody checked_ rather than _mostly fixed_.

## Preconditions, and not wasting a stage

- The stages chain: `fix` refuses without `assessment.md`, `test` refuses without `assessment.md`
  and `fix.md`. Skip a stage whose precondition the extension would refuse rather than invoking it
  and collecting the refusal.
- Announce a skip at its own boundary, with the recorded value that caused it. A skip taken
  silently is indistinguishable from a step that was forgotten.

## Safety

- `speckit-bug-fix` is the **only** stage that edits source code. `assess` and `test` never do.
- Pass a bug report to `assess` byte-identical, and **never pre-fetch a URL in it**. That stage
  applies its own host allowlist and untrusted-input policy; fetching first hands it prose instead
  of a URL and its rules never fire.
- Never do a stage's work in place of invoking it. If a stage cannot run, its work does not happen.

## Looping back to assessment

- A `partial` or `failed` validation result offers three choices: return to the assessment stage
  carrying what validation found, accept the result and stop, or stop and hand back. Returning
  re-enters the assessment stage; it does not end the run and it does not add a fourth stage.
- **Never take that choice on the run's own initiative.** Offering it is the run's job every time;
  taking it is the maintainer's, however many cycles have already happened.
- The cycle count is **not capped**. State it with the question instead, so the choice is made in
  view of the loop's own history rather than blind. A maintainer converging on a fix is not
  interrupted by an arbitrary limit, and a maintainer going in circles can see that they are.
- A re-entered stage is proposed and approved on exactly the terms a first-pass stage is. Nothing
  about a second cycle is lighter than the first.

## Branching, committing and shipping

- The run does not create commits or review requests itself. It asks, and dispatches the skill that
  owns the answer: `claude-code-devkit:ccd-commit-push` for the commit, and the review-request skill
  matching the remote for the pull or merge request. No `git add`, no `git commit`, no forge API
  called by hand — not even when the sub-skill turns out to be missing, which is a skip with a
  stated reason rather than a licence to improvise.
- Dispatch is a `Skill` tool call. Writing the skill's name in prose invokes nothing, so its own
  questions and its approval gate never run and the work happens under none of its rules.
- Hand a sub-skill facts, never answers. The target branch, assignee, reviewers, draft state,
  squash, auto-merge and source-branch deletion are all its own questions; supplying one suppresses
  the question it belongs to, which is how that value silently becomes wrong.
- The forge is decided once, at preflight, from the remote — never re-detected at shipping time and
  never inferred from the bug report's wording. An unsupported forge or no remote is an ordinary
  outcome: the review-request step is skipped with the reason named and the run still finishes.
- The workspace question comes **before** the first stage, because the remediation stage edits
  source files. Offer only the options that apply, and say why one is missing rather than letting it
  be silently absent. In worktree mode, verify the session actually moved before any stage runs;
  creating a directory does not move it, and an unverified worktree runs every stage in the old tree
  while reporting isolation.
- The teardown question comes after a review request exists, and is skipped with a reason when none
  was raised. The least destructive option is the recommended one in both option sets, because
  nobody has reviewed the change yet.
- Two guards, and they are not the same. A branch is deleted only when its commits are pushed; a
  worktree is removed only when nothing in it is uncommitted, **whatever the origin of that work**.
  A guarded-out option is not offered, and the reason is said out loud. No skip-approval phrase
  reaches either — a skip phrase covers approval of proposed content, never a deletion.

## The artifacts

- `.specify/bugs/<slug>/` is **committed project history**, not working state — FR-027 of feature
  001, and `.gitignore`'s own comment block. Do not add it to an ignore file.
- The run commits them by dispatching the commit skill once validation has recorded the defect
  resolved. A run that stops before that step leaves them uncommitted and says so, naming
  `claude-code-devkit:ccd-commit-push` as the way to discharge the obligation by hand.
- The slug is flat and user-named. There is no `NNN-` prefix and no `specs/` root; that convention
  belongs to mainline Spec Kit features, not to bugs.
