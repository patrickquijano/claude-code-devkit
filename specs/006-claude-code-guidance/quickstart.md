# Quickstart: validating feature 006

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

How to prove this feature works, end to end. Every scenario below is runnable and states what passing looks like. This is a validation guide — the implementation belongs in `tasks.md`.

## Prerequisites

- The `006-claude-code-guidance` branch checked out, or the worktree it was built in.
- `git`. Nothing else is required: the quality gate falls back to digest-pinned containers when a tool is absent, and a check that can do neither reports a skip rather than a failure.
- For scenarios 6 through 9, a Claude Code session in this repository.

## Scenario 1 — The quality gate passes

The repository's own check, and the constitution's precondition for proposing a change for review.

```sh
sh scripts/lint.sh
echo "exit=$?"
```

**Passes when** `exit=0`. Seven checks run and none fails. `citations` runs first and must pass — it fails if `.specify/memory/constitution.md` was amended, which this feature must not do.

Run a single check while iterating: `sh scripts/lint-markdown.sh`, `sh scripts/lint-shell.sh`, and so on.

To prove native and containerized paths agree:

```sh
LINT_FORCE_CONTAINER=1 sh scripts/lint.sh
```

## Scenario 2 — `CLAUDE.md` still satisfies FR-007

The proof obligation, not an assertion.

```sh
wc -l < CLAUDE.md
```

**Passes when** the count is under 200. It was 54 before this feature and should have grown by nothing — the only edits are two corrected statements.

```sh
git diff main -- CLAUDE.md
```

**Passes when** the diff touches only lines 13 and 20, and **no heading moves**. FR-007a forbids reordering; a diff that reorders sections fails this scenario even if the line count is fine.

```sh
grep -n '^## ' CLAUDE.md
git show main:CLAUDE.md | grep -n '^## '
```

**Passes when** the two heading lists are identical in order.

## Scenario 3 — The path-scoped rule declares its paths

The trap this rule exists to avoid is a rule file with no `paths` key, which loads unconditionally at launch while sitting in a directory named `rules`.

```sh
head -5 .claude/rules/*.md
```

**Passes when** every file shows a `paths:` key — `path:` singular is the documented mistake — and the new `repository-docs.md` lists at least `docs/**` and `CLAUDE.md`.

```sh
sh scripts/lint-markdown.sh && sh scripts/lint-format.sh
```

**Passes when** both succeed, proving the new rule file falls inside no exclusion declaration (FR-006).

## Scenario 4 — Zero skills carry `disable-model-invocation`

```sh
grep -rln 'disable-model-invocation' skills/*/SKILL.md
grep -rln 'user-invocable' skills/*/SKILL.md
```

**Passes when** both produce no output. The full check set is in [`contracts/skill-names.md`](./contracts/skill-names.md).

```sh
git diff --name-only main -- specs/005-merge-conflict-resolution/
```

**Passes when** this produces **no output**. The 005 contract is superseded, never edited — the single easiest thing to break with a global find-and-replace of "exactly one".

## Scenario 5 — All 42 falsified statements are handled

```sh
grep -rn 'ccd-conflict-resolve` is dispatched by nothing' CLAUDE.md README.md docs/ .claude/rules/ skills/
grep -rn 'without stopping\|Phases are not gated\|no gate after one' skills/ CLAUDE.md README.md
grep -rn 'two fan-out\|they are the only two\|up to four independent sweeps' skills/
```

**Passes when** all three produce no output. The first is scoped to `ccd-conflict-resolve` on purpose: a bare "dispatched by nothing" also matches a true sentence about `ccd-speckit-run`, which nothing does dispatch. The enumeration and the reasoning are in [`contracts/falsified-statements.md`](./contracts/falsified-statements.md).

## Scenario 6 — The conflict script reports a clean tree

```sh
sh skills/ccd-speckit-run/scripts/conflict-state.sh
echo "exit=$?"
```

**Passes when** the output is `verdict<TAB>clean`, `unmerged<TAB>0`, `operation<TAB>none`, and `exit=0`.

Then, in a scratch clone — **never in a working repository**:

```sh
REPO=$(pwd) # the 006 worktree, before cloning
git clone . /tmp/ccd-conflict-test && cd /tmp/ccd-conflict-test
git switch -c a && echo one > f.txt && git add f.txt && git commit -m a
git switch -c b main && echo two > f.txt && git add f.txt && git commit -m b
git merge a # conflicts
sh "$REPO/skills/ccd-speckit-run/scripts/conflict-state.sh"
```

**Passes when** the verdict is `conflicted`, `unmerged` is `1`, `operation` is `merge`, and one `paths` line names `f.txt`.

The case that matters most — an interrupted operation with a **clean** working tree, which a `git status` grep would miss:

```sh
git merge --abort
git rebase a                                 # conflicts
git checkout --theirs f.txt && git add f.txt # resolved, but not continued
sh "$REPO/skills/ccd-speckit-run/scripts/conflict-state.sh"
```

**Passes when** the verdict is still `conflicted`, `unmerged` is `0`, and `operation` is `rebase`.

```sh
shellcheck --shell=sh skills/ccd-speckit-run/scripts/conflict-state.sh
```

**Passes when** there is no output.

## Scenario 7 — The pipeline is reachable both ways

In a fresh Claude Code session in this repository:

1. Type `/claude-code-devkit:ccd-speckit-run` — **passes when** the skill appears in the `/` menu and loads.
2. In another fresh session, describe a task the pipeline covers without naming it — for instance _"take this change end to end through spec-driven development"_. **Passes when** the model can reach the skill on its own judgement.

The second was impossible before this feature and is the whole of FR-008.

## Scenario 8 — Each phase is proposed and approved on its own

Start a pipeline run against any small task.

**Passes when** every one of the eight phases is preceded by a proposal naming the command, the verbatim argument, the artifacts it will write, and what changed since the Step 3 plan — with "nothing changed since the plan" stated explicitly when nothing did.

**Fails when** any phase is invoked without a preceding proposal, or when a proposal shows a summarized rather than verbatim argument, or when the delta line is missing. A run in which all eight proposals are word-for-word identical apart from the command name also fails: FR-013 exists so the gates stay readable, and identical gates are the click-through failure the old design warned about.

Answer "Revise" on one phase. **Passes when** only that phase's argument changes and it is re-proposed.

## Scenario 9 — A boundary check runs at every boundary

During the run of scenario 8:

**Passes when** each step and each phase is followed by a reported conflict verdict — "checked, clean" on an ordinary run — and the count of verdicts equals the count of boundaries (SC-006).

**Fails when** clean verdicts are silent. FR-016 requires them reported, because a check that says nothing when it passes is indistinguishable from a check that never ran.

Inspect the durable record:

```sh
python3 -c "import json;print(json.load(open('.specify/.speckit-run-state.json'))['conflict_checks'])"
```

**Passes when** there is one element per boundary, each with `at`, `verdict` and `dispatched`.

## Scenario 10 — Workspace teardown is offered once a review request exists

Run the pipeline to the point where a pull request has been created.

**Passes when** the run asks where to leave the workspace, with choices matching the mode — three for a branch run, four for a worktree run — and the least-destructive option recommended.

**Fails when** a destructive option is offered while anything is uncommitted or unpushed, or when two separate teardown questions appear (6d and 6e were folded into one), or when a blanket approval given earlier in the run causes a branch deletion or a worktree removal to happen without being asked.

## Scenario 11 — The documentation is complete and sourced

```sh
ls docs/
wc -l docs/*.md
```

**Passes when** `claude-code-project-structure.md` exists alongside the three existing documents.

Read it and confirm: every claim of fact carries a source link or sits under a `GAP` marker (FR-002); there is a "Recorded gaps" section; there is an "In this repository" paragraph grounding each topic. Confirm the corrections to the two existing documents are recorded in a corrections table rather than having replaced the old text silently (FR-003).

## What is deliberately not tested here

- **That the documentation's claims are true of Claude Code.** They are cited to the official documentation, which is the evidence; re-deriving them is not this repository's job.
- **Whether removing `disable-model-invocation` changes how another skill's `Skill` call behaves.** That question is an unresolved documentation gap, recorded in `research.md` F12. No skill dispatches `ccd-speckit-run`, so nothing here depends on the answer.
- **Skill triggering accuracy.** The documented method is a baseline comparison via the `skill-creator` plugin and `evals/evals.json`. This repository uses hand-written `evaluations.md` scenarios instead, which is not the documented mechanism — recorded at `docs/skill-authoring-practices.md:112` and unchanged by this feature.
