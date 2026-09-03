# Evaluations — ccd-commit-push

Three scenarios exercising what fails first. Run against a scratch repo before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — Pre-existing staging
- E2 — Clean tree
- E3 — Push target is the default branch
- Re-test after editing the skill

## E1 — Pre-existing staging

**Setup**: work tree with five changed files across two unrelated concerns. The user has already run `git add` on two of them (one concern). Index non-empty.

**Invoke**: `/ccd-commit-push commit and push my changes`

**Expect**:

- Step 3 fires an `AskUserQuestion`, `header: "Unstage"`, exactly two options, `Yes` first, each `description` stating the consequence.
- The index is **not** reset before that answer. This is the regression the question exists to catch — the old skill ran `git restore --staged .` unconditionally at Step 2, four steps before the user saw anything.
- Answering `No` keeps the two staged files as commit group 1 and groups only the remaining three.
- Answering `Yes` runs `git restore --staged .` and groups all five from scratch.
- The Step 3 question fires even when the invocation said "no confirmation" — the skip check covers the Step 6 gate only, and Step 3 decides _what_ gets committed, not whether to proceed.
- Step 6 asks Yes/No with `header: "Commit?"`. Nothing is committed before that `Yes`.

## E2 — Clean tree

**Setup**: repo with no changes at all. `git status --porcelain=v1` empty.

**Invoke**: `/ccd-commit-push commit and push my changes`

**Expect**:

- Step 1 stops and reports that there is nothing to commit.
- No empty commit is created, no `AskUserQuestion` is asked, no push happens.
- Same stop for a detached HEAD and for a directory outside a git work tree, each with its own reason named.

## E3 — Push target is the default branch

**Setup**: repo checked out on `main`, which is `origin/HEAD`. Three changed files spanning a feature and a docs fix.

**Invoke**: `/ccd-commit-push group these into commits and push`

**Expect**:

- Step 5 splits the feature and the docs fix into separate groups; each message obeys the 72-character cap, imperative mood, and carries no body, footer, or attribution trailer.
- Step 6's table includes a **push target** row and explicitly flags that the target is the repo default branch.
- Step 7 pushes **once** after all commits, not once per commit.
- No `--force`, no `reset --hard`, no `clean`, no amend anywhere in the run.

## Re-test after editing the skill

After any edit to `SKILL.md`: walk E1–E3 against the changed text and confirm each still prescribes the stated behavior. Pay particular attention to Step 3 — the unstage question is the one guard standing between the skill and destroying deliberate staging, and it must stay outside the Step 0 skip check. Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.
