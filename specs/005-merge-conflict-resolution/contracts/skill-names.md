# Contract: skill names

**Feature**: [005-merge-conflict-resolution](../spec.md) | **Date**: 2026-09-04

**Supersedes** [`specs/003-ccd-skill-rename/contracts/skill-names.md`](../../003-ccd-skill-rename/contracts/skill-names.md). That contract fixed five `ccd-`-prefixed names and remains a true record of what shipped under feature 003; this one replaces it from feature 005 onward, when a sixth skill joined the set. Nothing about the five existing names changes here — only the count, and the statement of which skills are reachable which way.

## What this contract covers

The interface this plugin exposes is a set of names. Plugin name is `claude-code-devkit`, from `.claude-plugin/plugin.json`. Each skill's directory basename equals its frontmatter `name`, and the resolvable name is the two joined by a colon.

| Directory                      | Frontmatter `name`     | Resolvable name                           | Reachable by                                          |
| ------------------------------ | ---------------------- | ----------------------------------------- | ----------------------------------------------------- |
| `skills/ccd-speckit-run/`      | `ccd-speckit-run`      | `claude-code-devkit:ccd-speckit-run`      | a user only                                           |
| `skills/ccd-branch-push/`      | `ccd-branch-push`      | `claude-code-devkit:ccd-branch-push`      | a user                                                |
| `skills/ccd-commit-push/`      | `ccd-commit-push`      | `claude-code-devkit:ccd-commit-push`      | a user, or `ccd-speckit-run` at 6a                    |
| `skills/ccd-github-pr/`        | `ccd-github-pr`        | `claude-code-devkit:ccd-github-pr`        | a user, or `ccd-speckit-run` at 6b on a GitHub remote |
| `skills/ccd-gitlab-mr/`        | `ccd-gitlab-mr`        | `claude-code-devkit:ccd-gitlab-mr`        | a user, or `ccd-speckit-run` at 6b on a GitLab remote |
| `skills/ccd-conflict-resolve/` | `ccd-conflict-resolve` | `claude-code-devkit:ccd-conflict-resolve` | a user, or automatic invocation on a conflicted tree  |

## Guaranteed

- Each directory basename equals the frontmatter `name` in the `SKILL.md` it contains. This is a repository convention rather than a loader requirement — see "The basename rule is ours, not the loader's" below — and it holds for all six.
- The six resolvable names above are stable and are what any caller uses.
- `ccd-speckit-run` is reachable by a user and not by automatic invocation. The other five are reachable both ways.
- Exactly one of the six carries `disable-model-invocation: true`, and it is `ccd-speckit-run`. The count of skills grew; the count carrying that field did not.
- Exactly six skills ship. No stub, alias or redirect exists under any previous name.
- No skill carries `user-invocable: false`. All six are reachable when a user names them.

## Not guaranteed

- That the **bare** name resolves to the distributed copy. A personal skill of the same bare name remains available alongside the plugin's, under a different prefix — that is documented Claude Code behaviour, not a defect. The `ccd-` prefix makes the collision unlikely rather than impossible; callers use the namespaced form, and nothing here depends on the bare form working.
- That any previous name resolves to anything. The five previous names retired under feature 003 stay retired.
- That `ccd-conflict-resolve` will be reached automatically in any given situation. Automatic invocation is permitted, not promised: it depends on the model's judgment against the skill's description, which no contract can fix.

## The sixth skill, and why the count is stated rather than dropped

Feature 003's contract said "Exactly five skills ship", and feature 003's plan turned that into a counting check — `ls -d skills/*/ | wc -l # expect 5`. That was deliberate: the failure mode for a rename is an omission, and a count catches an omission where a comparison does not.

Adding a skill therefore cannot be done by quietly letting the count drift. It is done by superseding the statement, so that the check keeps testing something true. The number is load-bearing precisely because it is checked; if a future feature adds a seventh skill, it supersedes this contract in turn rather than editing the number here.

## `ccd-conflict-resolve` carries no `disable-model-invocation`

This is the one substantive difference from the five that came before, and it is a decision rather than an oversight.

`ccd-speckit-run` carries the field because it is a long pipeline a user chooses to start; having it engage on its own would be wrong. The four git skills omit it because `ccd-speckit-run` dispatches three of them through the `Skill` tool at 6a and 6b, and the field's effect on an explicit `Skill` call from another skill is **not settled by the documentation** — so the strict reading binds and the field stays off. That reasoning is recorded at `skills/ccd-speckit-run/SKILL.md` under Authoring note, and this feature's research confirmed the documentation is still silent on the point.

`ccd-conflict-resolve` omits it for a third reason, independent of both. Nothing dispatches it, so the ambiguity above does not arise. It omits the field because a merge conflict is a state worth reaching for the skill on, and every mutation the skill makes is already gated on the user's approval by FR-012 and FR-016 — so being reached automatically cannot cause anything to be resolved automatically. The gate is in the workflow, not in the frontmatter.

The asymmetry across the six is therefore now threefold and each case has its own reason. A pass that normalises them would break `ccd-speckit-run`'s Step 6 dispatch, exactly as feature 002's contract warned.

## The basename rule is ours, not the loader's

Feature 002's `data-model.md:25` states that a mismatch between directory basename and frontmatter `name` "is the one error that makes a skill unloadable rather than merely wrong." **This feature's research found that claim to be wrong.** The documentation states that for a plugin skill the frontmatter `name` _replaces_ the directory name in the last segment of the command — so a mismatch produces a skill that loads and answers to a different name than its path suggests, which is confusing rather than fatal.

The convention is kept anyway, and is still guaranteed above, because a skill answering to a name its own path contradicts is a maintenance trap. But it is recorded here as a repository convention with a real cost, not as a loader constraint — and the verification below checks it for that reason rather than to avoid an unloadable skill.

That correction is not applied to feature 002's artifact, which stays as the record of what that feature believed and shipped. It is recorded in `docs/skill-authoring-practices.md` with its source.

## Verifying this contract

```sh
# exactly six skills, all ccd-prefixed
ls -d skills/*/ | wc -l            # expect 6
ls -d skills/*/ | grep -cv '/ccd-' # expect 0

# directory basename equals frontmatter name, for each
for d in skills/*/; do
  n=$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)
  b=$(basename "$d")
  [ "$n" = "$b" ] || echo "MISMATCH $b != $n"
done # expect no output

# exactly one disable-model-invocation, in frontmatter, on the pipeline skill
# (a plain grep -rl also matches the "never add this" warning in several bodies)
for f in skills/*/SKILL.md; do
  awk 'FNR==1{n=0} /^---$/{n++} n==1 && /^disable-model-invocation:/{print FILENAME}' "$f"
done # expect exactly skills/ccd-speckit-run/SKILL.md

# no skill is hidden from the user
grep -l '^user-invocable: false' skills/*/SKILL.md # expect no output
```

## The regression to catch

A seventh skill appearing under `skills/` without this contract being superseded. The count check then fails against a tree that is correct, which trains the next reader to ignore it — and a check that is ignored catches nothing.

The second regression is the frontmatter one: `disable-model-invocation` appearing on any skill other than `ccd-speckit-run`, or being removed from it. Counting is the check, for the same reason as before.
