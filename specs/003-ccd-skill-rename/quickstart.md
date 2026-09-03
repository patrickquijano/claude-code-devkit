# Quickstart: proving the rename landed

**Feature**: [003-ccd-skill-rename](./spec.md) | **Date**: 2026-09-03

Every check here is a **count** or an **absence**. That is deliberate: the failure mode of this feature is an omission, and an omission cannot be seen in a diff of the files that were changed. Run these from the repository root.

## Prerequisites

- A shell and `git`. No install step, no dependency to fetch.
- Scenarios 10 and 11 additionally need the `claude` CLI and a live plugin install.

## Scenario 1 — Five skills, all prefixed

```sh
ls -d skills/*/ | wc -l
ls -d skills/*/ | grep -cv '/ccd-'
```

Expect `5` and `0`. A count other than 5 means a directory was added or lost; a non-zero second number means one was missed.

## Scenario 2 — Directory basename equals frontmatter `name`

```sh
for d in skills/*/; do
  n=$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)
  b=$(basename "$d")
  [ "$n" = "$b" ] || echo "MISMATCH $b != $n"
done
```

Expect no output. This is the check for FR-002, and it catches the specific half-done rename that produces no error at load time: a directory moved without its `name` field.

## Scenario 3 — The exact five names

```sh
ls -d skills/*/ | sed 's|skills/||; s|/$||' | sort
```

Expect exactly:

```text
ccd-branch-push
ccd-commit-push
ccd-github-pr
ccd-gitlab-mr
ccd-speckit-run
```

Note what is **not** here: `ccd-auto-branch-push` and its three siblings. The `auto-` prefix is dropped, so a mechanical `s/^/ccd-/` fails this scenario. See [contracts/skill-names.md](./contracts/skill-names.md).

## Scenario 4 — No old name survives in live content

```sh
grep -rn -e 'speckit-run' -e 'auto-branch-push' -e 'auto-commit-push' -e 'auto-github-pr' -e 'auto-gitlab-mr' \
  skills/ README.md CLAUDE.md .claude-plugin/ \
  | grep -v 'ccd-speckit-run' \
  | grep -v 'speckit-run-state\.json' \
  | grep -v 'speckit-run-base-switch'
```

Expect no output.

The three exclusions are the deliberate ones from FR-014, and each has to be excluded for a different reason: `ccd-speckit-run` **contains** the old name as a substring, and the two bookkeeping strings are not skill names at all. An implementation that renamed those would fail Scenario 9.

## Scenario 5 — One shared helper, at the new path

```sh
find skills -name branch-options.sh
grep -rl 'ccd-branch-push/scripts/branch-options\.sh' skills/*/SKILL.md | wc -l
grep -rn 'auto-branch-push/scripts/branch-options\.sh' skills/
```

Expect `skills/ccd-branch-push/scripts/branch-options.sh`, then `4`, then no output.

## Scenario 6 — One `disable-model-invocation`, on the entry point

The check must read **frontmatter only**. Four of the five `SKILL.md` files mention the field in a "never add this" warning in their body, so a plain `grep -rl` reports four files and reads as a failure when nothing is wrong:

```sh
for f in skills/*/SKILL.md; do
  v=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$f" | grep -c '^disable-model-invocation:')
  echo "$f $v"
done
```

Expect `1` against `skills/ccd-speckit-run/SKILL.md` and `0` against the other four. This field on any of the other four blocks the `Skill` tool, which breaks `ccd-speckit-run`'s Step 6 dispatch — silently, at the end of a full eight-phase run.

## Scenario 7 — Every bundled path resolves

```sh
grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/skills/[A-Za-z0-9./-]+' skills/ \
  | sed 's|${CLAUDE_PLUGIN_ROOT}/||' | sort -u \
  | while read -r p; do [ -e "$p" ] || echo "MISSING $p"; done
```

Expect no output. Catches a `${CLAUDE_PLUGIN_ROOT}` path whose skill segment was missed.

## Scenario 8 — Every namespaced dispatch names a skill that exists

```sh
grep -rhoE 'claude-code-devkit:[a-z0-9-]+' skills/ README.md CLAUDE.md | sort -u \
  | sed 's|claude-code-devkit:||' \
  | while read -r n; do [ -d "skills/$n" ] || echo "UNRESOLVABLE $n"; done
```

Expect no output. This is SC-002 made runnable — the check for a dispatch string that survives the rename pointing at a skill that does not.

## Scenario 9 — The deliberate exclusions are still intact

```sh
grep -n 'speckit-run-state' .gitignore
find .specify -name '.speckit-run-state.json' -o -name '.speckit-dirty-snapshot'
grep -rn 'speckit-run-base-switch' skills/ccd-speckit-run/
```

Expect `.gitignore` line 11 unchanged, the bookkeeping filenames as they were, and the stash message still present under its old spelling. **A run that renamed these has over-applied the rename**, and this scenario is what catches it — every other scenario here would still pass.

## Scenario 10 — The plugin still validates

```sh
claude plugin validate . --strict
```

Expect a pass. `--strict` promotes unrecognised-field warnings to errors, so this also catches a stray field added to `plugin.json` — which this feature must not add, and specifically must not add a `skills` field.

## Scenario 11 — The skills are reachable under their new names

With the plugin installed, invoke each of the five by its namespaced name and confirm it loads:

```text
claude-code-devkit:ccd-speckit-run
claude-code-devkit:ccd-branch-push
claude-code-devkit:ccd-commit-push
claude-code-devkit:ccd-github-pr
claude-code-devkit:ccd-gitlab-mr
```

Expect 5 of 5 to load. This is SC-001, and it is the only scenario the static checks cannot stand in for.

## Scenario 12 — The aggregate quality check

```sh
sh scripts/lint.sh
```

Expect exit `0`.

If it fails, the fix is the file, never the configuration. Adding the path to `.lintignore` makes this pass and makes `scripts/lint-scope.sh` fail, because the other five ignore declarations no longer match — which is Principle V working as designed, not an obstacle to route around.

## Scenario 13 — The front page

Read `README.md` top to bottom and confirm the section order is title, description, table of contents, Install, Usage, Contributing, License. Then:

```sh
test -f LICENSE && head -3 LICENSE
grep -n '"license"' .claude-plugin/plugin.json
```

Expect the `LICENSE` file to exist and name MIT, and the manifest to declare the same. Before this feature the file did not exist while the manifest claimed it did — SC-007.

## Scenario 14 — The superseded records

```sh
git diff main -- specs/001-quality-gate-plugin/ specs/002-vendor-plugin-skills/ | grep -c '^+'
git diff main --stat -- specs/002-vendor-plugin-skills/
```

Expect the changed files to be exactly `contracts/skill-names.md` and `contracts/branch-options.md`, one added line each, and nothing at all under `specs/001-quality-gate-plugin/`. This is SC-010: the pointer, and no other edit.
