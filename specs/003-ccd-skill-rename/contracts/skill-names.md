# Contract: skill names

**Feature**: [003-ccd-skill-rename](../spec.md) | **Date**: 2026-09-03

**Supersedes** [`specs/002-vendor-plugin-skills/contracts/skill-names.md`](../../002-vendor-plugin-skills/contracts/skill-names.md). That contract fixed the five names without a `ccd-` prefix and remains a true record of what shipped under feature 002; this one replaces it from feature 003 onward.

## What this contract covers

The interface this plugin exposes is a set of names. Plugin name is `claude-code-devkit`, from `.claude-plugin/plugin.json`. Each skill's directory basename equals its frontmatter `name`, and the resolvable name is the two joined by a colon.

| Directory                 | Frontmatter `name` | Resolvable name                      | Reachable by                                          |
| ------------------------- | ------------------ | ------------------------------------ | ----------------------------------------------------- |
| `skills/ccd-speckit-run/` | `ccd-speckit-run`  | `claude-code-devkit:ccd-speckit-run` | a user only                                           |
| `skills/ccd-branch-push/` | `ccd-branch-push`  | `claude-code-devkit:ccd-branch-push` | a user                                                |
| `skills/ccd-commit-push/` | `ccd-commit-push`  | `claude-code-devkit:ccd-commit-push` | a user, or `ccd-speckit-run` at 6a                    |
| `skills/ccd-github-pr/`   | `ccd-github-pr`    | `claude-code-devkit:ccd-github-pr`   | a user, or `ccd-speckit-run` at 6b on a GitHub remote |
| `skills/ccd-gitlab-mr/`   | `ccd-gitlab-mr`    | `claude-code-devkit:ccd-gitlab-mr`   | a user, or `ccd-speckit-run` at 6b on a GitLab remote |

## Guaranteed

- Each directory basename equals the frontmatter `name` in the `SKILL.md` it contains. For a plugin skill the frontmatter `name` is what supplies the command segment, so a divergence would make the skill answer to a name its own path contradicts.
- The five resolvable names above are stable and are what any caller uses.
- `ccd-speckit-run` is reachable by a user and not by automatic invocation. The other four are reachable both ways.
- Exactly one of the five carries `disable-model-invocation: true`, and it is `ccd-speckit-run`.
- Exactly five skills ship. No stub, alias or redirect exists under any previous name.

## Not guaranteed

- That the **bare** name resolves to the distributed copy. A personal skill of the same bare name remains available alongside the plugin's, under a different prefix — that is documented Claude Code behaviour, not a defect. The `ccd-` prefix makes the collision unlikely rather than impossible; callers use the namespaced form, and nothing here depends on the bare form working.
- That any previous name resolves to anything. The five previous names are retired with no transition period.

## The prefix is deliberate

`ccd-` looks redundant under the `claude-code-devkit:` namespace and is not. The namespace disambiguates the namespaced form; nothing disambiguates the bare form, and the bare form is what a user types. These five skills were derived from personal skills of the unprefixed names, which may still be installed on the same machine.

Removing the prefix as redundant is the regression this paragraph exists to prevent. `CLAUDE.md` records the same rationale.

## Names are a lookup, not a pattern

Four of the five drop an `auto-` prefix while gaining `ccd-`; one does not:

| Previous           | Current           |
| ------------------ | ----------------- |
| `speckit-run`      | `ccd-speckit-run` |
| `auto-branch-push` | `ccd-branch-push` |
| `auto-commit-push` | `ccd-commit-push` |
| `auto-github-pr`   | `ccd-github-pr`   |
| `auto-gitlab-mr`   | `ccd-gitlab-mr`   |

A mechanical `s/^/ccd-/` produces `ccd-auto-branch-push` and three siblings like it. Any tooling or future edit that derives one name from the other must use this table.

## Cross-skill dispatch

`ccd-speckit-run` hands work to three of the four at two points in its run.

| Step | Skill dispatched                     | Chosen by                                      | Carries                                                 |
| ---- | ------------------------------------ | ---------------------------------------------- | ------------------------------------------------------- |
| 6a   | `claude-code-devkit:ccd-commit-push` | the user's answer to 6a's question             | an explicit path list, credential-shaped paths excluded |
| 6b   | `claude-code-devkit:ccd-github-pr`   | `tooling.forge = "github"`, recorded at Step 0 | the verification status                                 |
| 6b   | `claude-code-devkit:ccd-gitlab-mr`   | `tooling.forge = "gitlab"`, recorded at Step 0 | the verification status                                 |

Dispatch is a `Skill` tool call using the resolvable name. Prose naming a skill dispatches nothing.

## Verifying this contract

```sh
# exactly five skills, all ccd-prefixed
ls -d skills/*/ | wc -l            # expect 5
ls -d skills/*/ | grep -cv '/ccd-' # expect 0

# directory basename equals frontmatter name, for each
for d in skills/*/; do
  n=$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)
  b=$(basename "$d")
  [ "$n" = "$b" ] || echo "MISMATCH $b != $n"
done # expect no output

# exactly one disable-model-invocation, in frontmatter, on the pipeline skill
# (a plain grep -rl also matches the "never add this" warning in four bodies)
for f in skills/*/SKILL.md; do
  v=$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$f" | grep -c '^disable-model-invocation:')
  echo "$f $v"
done # expect 1 only for ccd-speckit-run
```
