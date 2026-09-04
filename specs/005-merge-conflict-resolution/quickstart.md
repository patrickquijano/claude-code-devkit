# Quickstart: Merge Conflict Resolution

**Feature**: [005-merge-conflict-resolution](./spec.md) | **Date**: 2026-09-04

Runnable scenarios that prove this feature works. Each names its prerequisites, what to run, and what should happen — and each traces to the requirement or success criterion it validates, so a reviewer can tell what a passing scenario actually establishes.

These are validation steps, not implementation. The scripts' interface is [contracts/conflict-scripts-cli.md](./contracts/conflict-scripts-cli.md); the entities are [data-model.md](./data-model.md).

## Prerequisites

- `git` 2.35.0 or later on `PATH`. The floor is `zdiff3`, added in 2.35.0 (research §3.9.8); everything else works further back.
- The plugin installed, so `claude-code-devkit:ccd-conflict-resolve` resolves.
- A scratch repository for the conflict scenarios. **Do not run scenarios 3 through 9 against a repository you care about** — they deliberately create conflicts.

Build the scratch repository once:

```sh
cd "$(mktemp -d)"
git init -b main scratch && cd scratch
printf 'line one\nline two\nline three\n' > file.txt
git add file.txt && git commit -m 'base'

git switch -c theirs
printf 'line one\nTHEIR change\nline three\n' > file.txt
git commit -am 'their change'

git switch main
printf 'line one\nOUR change\nline three\n' > file.txt
git commit -am 'our change'
```

`git merge theirs` in that repository produces a `both-modified` conflict in `file.txt`.

## Scenario 1 — The repository's own gate passes

**Validates**: SC-007, and the constitution's Development Workflow requirement that the aggregate check has passed before review.

```sh
sh scripts/lint.sh
```

**Expect**: exit 0, ending `==> lint.sh: all checks passed`. All seven checks run in the order `citations editorconfig format markdown yaml shell python`.

**Expect specifically**: no check reports the new files as excluded or skipped. `docs/`, `skills/ccd-conflict-resolve/` and `.claude/rules/` are all in scope. If any of them is silently not being checked, this scenario passes while SC-007 fails — so confirm scope with Scenario 2 rather than trusting a green run.

## Scenario 2 — The new content is actually governed

**Validates**: FR-005, FR-005a, SC-007. This is the scenario that catches the failure Scenario 1 cannot.

```sh
# the rule files must be inside the three documentation checks
printf 'x  \n' >> .claude/rules/*.md # trailing whitespace, deliberately
sh scripts/lint-format.sh
echo "format exit=$?"
```

**Expect**: non-zero, naming the rule file. Then revert the edit.

**Expect also**: `.claude/` other than `rules/` is still excluded — adding the same violation to `.claude/settings.json` should **not** fail the check, because FR-005a narrowed the exclusion rather than removing it.

```sh
grep -n 'claude' .prettierignore .markdownlint-cli2.jsonc .editorconfig-checker.json
```

**Expect**: each shows `.claude` still excluded and `.claude/rules` re-included, in whatever form that file's syntax takes. Three files, no more — the yaml, shell and python declarations are untouched, because no rule file is YAML, shell or Python.

## Scenario 3 — `git` absent stops everything

**Validates**: FR-009, SC-004. The highest-value scenario in the list, because it is the one that must hold before any other behaviour matters.

```sh
env PATH=/nonexistent sh "${CLAUDE_SKILL_DIR}/scripts/conflict-preflight.sh"
echo "exit=$?"
```

**Expect**: exit 2, `no-git:` on stderr, and **no other output** — no probing of the repository, no key lines.

**Expect**: `git status --porcelain` in the scratch repository afterwards shows exactly what it showed before. Zero modified paths, which is what SC-004 measures.

## Scenario 4 — Identification is complete and stable

**Validates**: FR-011, SC-005.

In the scratch repository, with `git merge theirs` conflicted:

```sh
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-preflight.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh"
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh" | md5
sh "${CLAUDE_SKILL_DIR}/scripts/conflict-list.sh" | md5
```

**Expect** from preflight: `operation<TAB>merge`, `conflicts<TAB>1`, `git<TAB>available`, `repo<TAB>yes`.

**Expect** from list: exactly one line, `file.txt<TAB>both-modified<TAB>123<TAB>text`.

**Expect**: the two digests are identical. SC-005 requires identical reports across runs, and since git documents porcelain v2's order as undefined, this is testing that the script sorts rather than that git happens to be consistent. Run it in a repository with several conflicts to make the test meaningful.

## Scenario 5 — Nothing is modified before approval

**Validates**: FR-012, SC-006. Run through the skill rather than the scripts.

Invoke `claude-code-devkit:ccd-conflict-resolve` on the conflicted scratch repository and stop at the point where it presents candidate resolutions.

**Expect**: it has reported the conflicted path and its kind, and presented candidates with an explanation each, one recommendation, and a justification for it.

**Expect, and this is the assertion**: `git status --porcelain` and `git diff` show the tree exactly as the conflicted merge left it. No file rewritten, nothing staged. SC-006 counts unapproved modifications and the expected count is zero.

**Then decline every option.** Expect the tree still unchanged and the merge still in progress — FR-016 forbids falling back to a resolution nobody approved.

## Scenario 6 — Ours and theirs are described, not labelled

**Validates**: FR-012, and research §3.5. The scenario most likely to catch a real defect.

Set up a **rebase** conflict rather than a merge:

```sh
git merge --abort
git switch theirs
git rebase main # conflicts
```

Invoke the skill and read the candidate resolutions.

**Expect**: the options describe the effect in concrete terms — naming which branch's content is kept and whose change is discarded. Under this rebase, keeping "ours" keeps `main`'s content and discards the commit being replayed.

**Fail the scenario if** the options read "take ours" and "take theirs" with no further explanation. Git documents that during a rebase "the sides are swapped", so a bare label tells the user the opposite of the truth, and FR-012's explanation requirement exists precisely for this.

## Scenario 7 — Unrelated work survives concluding

**Validates**: FR-017c, SC-006a. The scenario that exists because the Phase 4 checklist found the contradiction at CHK020.

```sh
git rebase --abort
git switch main
git merge theirs # conflict in file.txt
printf 'unrelated\n' > other.txt
git add other.txt # deliberately staged, unrelated
```

Resolve `file.txt` through the skill and let it conclude.

**Expect**: `conflict-conclude.sh` exits 4, prints `other.txt`, and **concludes nothing**. The skill reports the staged unrelated path and asks, rather than committing it.

**Fail the scenario if** the merge commit contains `other.txt`. Git commits the whole index and refuses a pathname-limited commit during a merge (research §3.7.8), so nothing downstream can undo this — the check has to happen before concluding or not at all.

Repeat with `other.txt` **unstaged**. Expect concluding to succeed and `other.txt` to remain uncommitted and unstaged afterwards — that is the SC-006a assertion, and it holds because git leaves pre-existing local modifications matching `HEAD` (research §3.7.9).

## Scenario 8 — Iteration reports lack of progress

**Validates**: FR-014, and the Edge Cases entry about a resolution that does not resolve.

Create a repository with two conflicted paths, resolve one through the skill, and let it re-identify.

**Expect**: it reports the remaining conflict and proposes again rather than reporting completion.

Then force the pathological case: approve a `staged` apply for a path whose working-tree content still carries conflict markers.

**Expect**: `conflict-apply.sh` exits 4 and stages nothing. If a resolution ever does leave the set unchanged, expect the skill to report no progress and stop, rather than looping.

## Scenario 9 — A conflict that cannot be resolved by choosing lines

**Validates**: FR-019.

```sh
git merge --abort
git switch theirs && git rm file.txt && git commit -m 'delete it'
git switch main && git merge theirs # modify/delete conflict
```

**Expect** from `conflict-list.sh`: `file.txt<TAB>deleted-by-them<TAB>12-<TAB>text` — stage 3 absent.

**Expect** from the skill: candidates appropriate to a modify/delete — keep the file as modified, or accept the deletion — and **no line-level option**, because there is no third stage to merge lines from.

Repeat with a binary file changed on both sides. Expect `binary` as the kind and whole-file options only, regardless of the `XY` code.

## Scenario 10 — The skill is reachable both ways

**Validates**: FR-018, and the count invariant in [contracts/skill-names.md](./contracts/skill-names.md).

```sh
ls -d skills/*/ | wc -l                                                 # expect 6
ls -d skills/*/ | grep -cv '/ccd-'                                      # expect 0
grep -c 'disable-model-invocation' skills/ccd-conflict-resolve/SKILL.md # expect 0
```

**Expect**: typing `/claude-code-devkit:ccd-conflict-resolve` invokes it.

**Expect**: describing a conflicted tree in a fresh session, without naming the skill, is enough for Claude to reach for it. That is a judgment call rather than a guarantee — the contract's "Not guaranteed" section says so — but a consistent failure to trigger means the description needs work, per research §2.2.2.

## Scenario 11 — The documentation carries its sources

**Validates**: FR-004, SC-002, SC-009.

```sh
ls docs/
```

**Expect**: three files, one per subject.

**Expect**: every recorded practice carries either a citation or an explicit note that no authoritative source was found. SC-002 measures 100%, so the check is a read-through rather than a grep — but a grep for a bare assertion with no adjacent link or gap marker is a fast way to find candidates.

**Expect**: a reader who has never opened this repository can act on any of the three subjects without reading source code (SC-009).

## Scenario 12 — Instructions and documentation agree

**Validates**: FR-006, FR-007, FR-021a, SC-003, SC-008.

```sh
grep -rn 'five skills\|five distributed\|all five' CLAUDE.md README.md docs/ .claude/rules/
```

**Expect**: no output. Every statement of the old count has been corrected — that is FR-021a and SC-008, and it is what keeps the counting check in `contracts/skill-names.md` honest.

```sh
wc -l CLAUDE.md # expect under 200
head -5 .claude/rules/*.md
```

**Expect**: `CLAUDE.md` under its 200-line target (FR-006b), and every rule file opening with YAML frontmatter containing a `paths:` key (FR-006a).

**Expect specifically**: no rule file lacks `paths:`. Research §1.2.6 found that a rule file without it "is loaded unconditionally at launch" — it would cost context in every session while looking scoped, which is the whole failure this arrangement exists to avoid.

Then read `CLAUDE.md`, the rule files and `docs/` against each other. **Expect** no statement in one contradicting another (SC-003). This is the manual step; CHK025 already flagged that it rests on judgment, and no command replaces it.
