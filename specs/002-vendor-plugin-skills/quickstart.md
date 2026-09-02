# Quickstart: validating the distributed skills

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contracts**: [contracts/](./contracts/)

Runnable scenarios that prove this feature works. Each states its prerequisite, the command, and the expected outcome, and each maps to a success criterion so a failure is traceable to a requirement rather than to a feeling.

Two scenarios cannot be reduced to a command and say so plainly, rather than being dressed up as tests.

## Prerequisites

From the repository root. `git` is required. `shellcheck`, `markdownlint-cli2` and `prettier` are used natively where present; the repository's runners fall back to digest-pinned containers, so no installation step is needed.

## Scenario 1 -- the five skills exist where auto-discovery looks

**Verifies**: FR-001, FR-002, SC-001 (structural half)

```sh
ls -d skills/*/ | wc -l      # expect 5
ls skills/*/SKILL.md | wc -l # expect 5
for d in skills/*/; do
  n=$(basename "$d")
  grep -q "^name: $n$" "$d/SKILL.md" || echo "MISMATCH: $n"
done # expect no output
```

The `MISMATCH` check matters more than it looks: a skill whose frontmatter `name` disagrees with its directory basename is the one error that makes it unloadable rather than merely wrong.

## Scenario 2 -- the manifest was not touched

**Verifies**: plan Structure Decision, research.md §3

```sh
git diff --stat main -- .claude-plugin/plugin.json # expect no output
grep -c '"skills"' .claude-plugin/plugin.json      # expect 0
```

`skills/` is auto-discovered. Declaring it would be redundant under one reading of the documentation and a hazard under the other.

## Scenario 3 -- no install location survives in anything a reader follows

**Verifies**: FR-009, FR-010, SC-003

```sh
grep -rn '~/\.claude/skills\|/Users/' skills/ | grep -v 'CLAUDE\.md' # expect no output
grep -rc 'CLAUDE_PLUGIN_ROOT' skills/ | grep -v ':0$'                # expect several
```

The `CLAUDE.md` exclusion in the first command is not a convenience. Six occurrences of `~/.claude/CLAUDE.md` remain on purpose: that path names the user's own machine-wide instructions file, which `speckit-run` names in order to forbid touching it. Rewriting those six would break a prohibition, which is why SC-003 counts 16 and not 22.

## Scenario 4 -- one helper, and every consumer reaches it

**Verifies**: FR-011, FR-012, SC-004, SC-005

```sh
find skills -name branch-options.sh | wc -l                                   # expect 1
find skills -name branch-options.sh                                           # expect skills/auto-branch-push/scripts/branch-options.sh
grep -rl 'branch-options\.sh' skills/*/SKILL.md | wc -l                       # expect 4
grep -rh 'skills/auto-branch-push/scripts/branch-options\.sh' skills/ | wc -l # expect >= 3
```

SC-005's "identical candidates for the same repository state" is now true **by construction** -- one script, one invocation, four callers -- rather than by comparison. That is the substance of the change, not a side effect of it.

## Scenario 5 -- the reconciled helper honours its contract

**Verifies**: [contracts/branch-options.md](./contracts/branch-options.md), FR-013

```sh
sh skills/auto-branch-push/scripts/branch-options.sh
```

Expect tab-separated lines, the default branch first tagged `default`, the checked-out branch tagged `current`, and — the point of the reconciliation — **no line naming a remote rather than a branch**. Specifically, no row whose first column is `origin`. That row is what the rejected 48-line fork emitted, and it was observed during this feature's own Step 1.

```sh
sh skills/auto-branch-push/scripts/branch-options.sh | awk -F'\t' '$1 == "origin" { print "PHANTOM ROW"; }' # expect no output
sh skills/auto-branch-push/scripts/branch-options.sh | head -1 | grep -q 'default' || echo "DEFAULT NOT FIRST"
```

## Scenario 6 -- the frontmatter asymmetry survived

**Verifies**: FR-014, FR-015, SC-009

```sh
# the field, in frontmatter only -- expect the speckit-run line and nothing else
awk 'FNR==1{n=0} /^---$/{n++} n==1 && /disable-model-invocation/{print FILENAME}' skills/*/SKILL.md
grep -c 'disable-model-invocation' skills/*/SKILL.md | grep -v ':0$' | wc -l # expect 4
```

The first command scans frontmatter specifically. A plain `grep -l` for the string matches all four files that mention it and so cannot tell the field from a warning about the field -- it was written that way here first, and returned four paths where the scenario claimed one. The `FNR==1{n=0}` reset is not decoration either: without it `n` carries across files, the guard stops matching after the first, and the command prints nothing while appearing to pass.

The second count is 4, not 1, and that is correct: `speckit-run` carries the field, and the three companions each carry a written warning against acquiring it. A result of 1 would mean the warnings were lost. `auto-commit-push` carries neither, which is why the count is 4 and not 5.

## Scenario 7 -- nothing machine-local, generated or binary shipped

**Verifies**: FR-017, SC-007

```sh
find skills -name '.DS_Store' -o -name 'Thumbs.db' | wc -l # expect 0
find skills -name '.markdownlint-cli2.jsonc' | wc -l       # expect 0
find skills -type f ! -name '*.md' ! -name '*.sh' | wc -l  # expect 0
```

The third command is the general form of the first two: after distribution every file under `skills/` is Markdown or shell. Anything else is something to justify.

## Scenario 8 -- the repository's own gate passes

**Verifies**: FR-016, FR-019, SC-006, SC-013

```sh
scripts/lint.sh
scripts/lint-scope.sh
scripts/selftest.sh
```

Expect exit 0 from each. `lint.sh` covers the distributed content because `.lintignore` excludes nothing under `skills/` and the runner's file list comes from `git ls-files --cached --others --exclude-standard` -- so these files are in scope before they are committed, and this scenario is meaningful during implementation rather than only after it.

`lint-scope.sh` is listed separately even though `lint.sh` runs it, because SC-013 is specifically about the six scope declarations still agreeing once a new top-level directory exists. Expect it to report the same five verified and ShellCheck unverifiable, exactly as before this feature.

```sh
LINT_FORCE_CONTAINER=1 scripts/lint.sh # optional: same verdict without native tools
```

## Scenario 9 -- the record no longer contradicts the repository

**Verifies**: FR-020, FR-021, SC-010

```sh
grep -n 'create \*\*no\*\* component directories' specs/001-quality-gate-plugin/research.md
grep -n 'speckit-\*' specs/001-quality-gate-plugin/research.md
scripts/lint-citations.sh
```

Expect the first two to show amended text that scopes the decision to feature 001 and narrows the prohibition to Spec Kit's generated output by provenance rather than by name pattern. Expect `lint-citations.sh` to exit 0 — it checks the governance quotations in `.github/`, which this feature does not touch, so a failure here means something unrelated broke.

## Scenario 9a -- the research record carries its sources

**Verifies**: FR-022, SC-011

This scenario exists because Phase 7's analysis found FR-022 -- the first thing the feature was asked for -- covered by no task and no scenario. The work was done; nothing checked it.

```sh
grep -c 'code.claude.com/docs' specs/002-vendor-plugin-skills/research.md                        # expect >= 3
sed -n '/^## 1\./,/^## 2\./p' specs/002-vendor-plugin-skills/research.md | grep -c 'Sources\*\*' # expect 1
sed -n '/^## 2\./,/^## 3\./p' specs/002-vendor-plugin-skills/research.md | grep -c 'Sources\*\*' # expect 1
sed -n '/^## 3\./,/^## 4\./p' specs/002-vendor-plugin-skills/research.md | grep -c 'Sources\*\*' # expect 1
```

Expect all three of §1 (general practice), §2 (skill authoring) and §3 (plugin authoring) to declare sources — 3 of 3, SC-011. Each cited URL should resolve to the page it claims; a citation that has rotted is a finding, not a formatting nit, because the whole value of §1–§3 is that they are checkable rather than remembered.

## Scenario 10 -- the five test-scenario documents and their references

**Verifies**: FR-024, SC-014

```sh
find skills -name evaluations.md | wc -l                # expect 5
grep -c 'evaluations' skills/*/SKILL.md | grep -v ':0$' # expect 5 skills listed
grep -h 'evaluations' skills/*/SKILL.md | wc -l         # expect 7 (lines, not occurrences)
```

The last command explains SC-014's arithmetic — 5 documents, 7 references. Two instruction documents name their own scenario file twice: `speckit-run`'s, once in the reference map and once in the authoring note, and `auto-github-pr`'s, once where the shared helper is discussed and once in its maintenance note. SC-014 said 6 when it was written; the source already had 7, so that was a miscount and not a change this feature made.

Count lines, not occurrences. A Markdown link written `[evaluations.md](evaluations.md)` contains the string twice, so an occurrence count returns 11 for the same seven references and neither figure is wrong -- they answer different questions. SC-014 counts references.

## Scenario 11 -- the template sets are distinguishable

**Verifies**: FR-027, SC-016

```sh
find skills/auto-github-pr/templates -type f | wc -l # expect 7
# every difference should be an added H1 and its blank line; anything else is real
diff -r ~/.claude/skills/auto-github-pr/templates skills/auto-github-pr/templates \
  | grep -Ev '^(diff |[0-9]+a[0-9,]+$|> # Pull request|> $)' # expect no output
grep -rn 'not.*installed into the repo' skills/auto-github-pr/SKILL.md
```

The `diff` is filtered rather than expected to be empty, and that is the honest form. Each of the seven files gained a top-level heading, because all seven began at `##` and the repository's Markdown check rejects that under `MD041` -- FR-016 requires the check to pass, so FR-027 was narrowed from "unchanged" to "content intact, plus a heading". The filter drops exactly those added lines, so any surviving output is a genuine difference.

The `diff` is only runnable **before** FR-025's removal, which is one reason the removal is ordered last. The `grep` confirms the recorded distinction survives: `default-pr-template.md` shapes a pull request's description and is never installed; `templates/github/` is a drop-in set for other repositories. Neither is to be merged with this repository's own `.github/` templates, which quote the constitution and are policed by `lint-citations.sh`.

## Scenario 12 -- what cannot be checked by command

Stated rather than omitted, because claiming a test that did not run is worse than naming a gap.

**The five skills still behave correctly end to end.** Each carries its own scenario document, and those scenarios are interactive — they involve questions, gates, and a git remote. This feature does not run them, and does not assert they were run. What it asserts is narrower and true: the content is byte-identical to the source except where a requirement forced a change, and every forced change is enumerated in [research.md](./research.md) §7.

**A dispatch actually resolves under a plugin install.** Verifying this requires the plugin installed on a machine with no personal copy, then invoking `claude-code-devkit:speckit-run` through to Step 6a. It is the one scenario that would falsify the feature's central mechanism, and it cannot be run from inside the repository that defines it. FR-025's removal is gated on a confirmation that the five are "present and invocable" precisely because this scenario has to happen before the source disappears.

## Scenario 13 -- removal, and its preconditions

**Verifies**: FR-025, FR-026, SC-015

Not to be run until Scenarios 1–11 pass, the work is committed and pushed, and Scenario 12's invocability confirmation has actually been obtained.

```sh
scripts/lint.sh                                            # precondition: exit 0
git status --porcelain                                     # precondition: expect no output
git log --oneline origin/002-vendor-plugin-skills -1       # precondition: pushed
ls -d ~/.claude/skills/speckit-run ~/.claude/skills/auto-* # what would be removed
```

Only then, and only after a confirmation taken at that moment rather than the one recorded in the clarification session:

```sh
rm -rf ~/.claude/skills/speckit-run ~/.claude/skills/auto-branch-push \
  ~/.claude/skills/auto-commit-push ~/.claude/skills/auto-github-pr \
  ~/.claude/skills/auto-gitlab-mr
```

This deletes files outside the repository and is not reversible from anything the repository holds. Nothing else in this feature does that. Expect `ls ~/.claude/skills/` afterwards to show `graphify`, `heroui-react` and `lean-ctx` and none of the five — SC-015's 0 of 5.
