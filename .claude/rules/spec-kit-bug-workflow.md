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

## The artifacts

- `.specify/bugs/<slug>/` is **committed project history**, not working state — FR-027 of feature
  001, and `.gitignore`'s own comment block. Do not add it to an ignore file.
- The run does not commit them. It names their paths, states the obligation, and names
  `claude-code-devkit:ccd-commit-push` as the way to discharge it.
- The slug is flat and user-named. There is no `NNN-` prefix and no `specs/` root; that convention
  belongs to mainline Spec Kit features, not to bugs.
