# Contract: skill names and reachability

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

**Supersedes** [`specs/005-merge-conflict-resolution/contracts/skill-names.md`](../../005-merge-conflict-resolution/contracts/skill-names.md), which in turn superseded 003's and 002's. That contract's own rule — "if a future feature adds a seventh skill, it supersedes this contract in turn rather than editing the number here" — is followed here for a different trigger: the count of skills is unchanged at six, and what changes is **which of them are reachable which way**.

Nothing about the six names changes. Only reachability, the `disable-model-invocation` count, and the dispatch graph.

## The six skills

| Skill                  | Reachable by   | Dispatched by                                                         |
| ---------------------- | -------------- | --------------------------------------------------------------------- |
| `ccd-branch-push`      | user and model | nothing                                                               |
| `ccd-commit-push`      | user and model | `ccd-speckit-run` at Step 6a                                          |
| `ccd-conflict-resolve` | user and model | `ccd-speckit-run` at every step and phase boundary, **conditionally** |
| `ccd-github-pr`        | user and model | `ccd-speckit-run` at Step 6b, on a GitHub remote                      |
| `ccd-gitlab-mr`        | user and model | `ccd-speckit-run` at Step 6b, on a GitLab remote                      |
| `ccd-speckit-run`      | user and model | nothing                                                               |

## The invariants

**Every one of the six is addressed as `claude-code-devkit:<name>` when one skill dispatches another.** Unchanged from 002, 003 and 005. A bare name resolves to whichever copy the session picks when a personal skill shares the name; nothing here depends on the bare form working.

**Every directory basename equals its frontmatter `name`, and both carry the `ccd-` prefix.** Unchanged. Neither is enforced by the loader — the documentation's own example shows a plugin skill at `review/` with `name: fancy` becoming `/my-plugin:fancy` — so this is a convention with a maintenance rationale, not a constraint. The prefix disambiguates the **bare** name, which the `claude-code-devkit:` namespace does not.

**Zero of the six carry `disable-model-invocation: true`.** This is the change. The count was one under 005 and is now none.

**No skill carries `user-invocable`.** Its absence is what leaves a skill user-invocable. Setting it `false` would hide the skill from the `/` menu, which is the opposite of what any of these six wants, and setting it `true` would restate a default.

## Why the count went to zero

Under 005 the reasoning was threefold. It is now twofold, and the removed branch is worth stating rather than deleting.

**The four git and forge skills** omit the field because `ccd-speckit-run` dispatches three of them through the `Skill` tool at 6a and 6b, and the field's effect on an explicit `Skill` call originating in another skill is **not settled by the documentation**. Two passages now bear on it and they disagree — the field's own entry says it prevents Claude "from automatically loading this skill", while another passage says "To keep Claude from invoking it through the `Skill` tool, set `disable-model-invocation: true`", with no "automatically" qualifier. The gap is narrower than 005 recorded it and it has narrowed **toward** the strict reading. So the strict reading still binds, and more firmly: a skill that another skill dispatches does not carry the field. Adding it to any of the four would break Step 6 silently, at the end of a full pipeline run.

**`ccd-conflict-resolve`** omitted the field under 005 for a reason that is no longer available: "nothing dispatches it, so the ambiguity does not arise". Something dispatches it now — `ccd-speckit-run`, at every step and phase boundary, conditionally on a conflicted working tree. So it falls under the same rule as the other four, by the same strict reading, and reaches the same answer by a different route. Its second 005 reason survives untouched: every mutation it makes is gated on the user's approval, so being reached automatically cannot cause anything to be resolved automatically.

**`ccd-speckit-run`** carried the field under 005 because "it is a long pipeline a user chooses to start; having it engage on its own would be wrong." That argument was correct about the pipeline as it then was, in which one approval at Step 3 covered all eight phases and they then ran without stopping. It no longer describes the pipeline. Each phase is now proposed and approved on its own, stating the command, the verbatim argument and the artifacts it will write, and Steps 1, 2b and 6 keep their own gates. Nothing the pipeline does outside its own spec directory happens without an approval that names it.

That is the same argument 005 accepted for `ccd-conflict-resolve`, applied to a skill that has since acquired the property it turns on: **the gate is in the workflow, not in the frontmatter.**

## What this contract does not say

It does not say the field is harmless in general. It says these six skills each have a reason not to carry it. A seventh skill with side effects and no per-action gate would have a real case for it, and this contract would not settle that case.

It does not resolve the documentation gap. It records which side of an unresolved ambiguity this plugin stands on, and why the cost is asymmetric: under the strict reading, carrying the field on a dispatched skill breaks the dispatch; under the permissive reading, omitting it costs nothing.

## Verification

```sh
# 1. Zero skills carry disable-model-invocation.
grep -rln 'disable-model-invocation' skills/*/SKILL.md
# expect: no output

# 2. No skill carries user-invocable.
grep -rln 'user-invocable' skills/*/SKILL.md
# expect: no output

# 3. All six directory basenames match their frontmatter name, all ccd- prefixed.
for f in skills/*/SKILL.md; do
  d=$(basename "$(dirname "$f")")
  n=$(sed -n 's/^name: //p' "$f" | head -1)
  [ "$d" = "$n" ] || echo "MISMATCH $f: dir=$d name=$n"
  case "$n" in ccd-*) ;; *) echo "UNPREFIXED $f: $n" ;; esac
done
# expect: no output

# 4. Cross-skill dispatch uses the namespaced form.
grep -rn 'Skill(skill:' skills/ | grep -v 'claude-code-devkit:' | grep -v '"init"'
# expect: no output beyond the built-in /init dispatch at reference/claude-md.md
```

## Regressions this contract exists to catch

**The normalising pass.** Someone notices the six skills' frontmatter is inconsistent in some other respect and makes it uniform, adding `disable-model-invocation` back, or adding `user-invocable: true` "for clarity". Check 1 and check 2 catch both.

**The reachability reversal.** `disable-model-invocation` is restored to `ccd-speckit-run` on the reasoning 005 recorded, without noticing that the reasoning depended on phases being ungated. If the per-phase gates are ever removed, that argument becomes available again — and the field should come back with them. The two are a pair, and separating them is the regression.

**The dispatch that outruns the contract.** A future feature makes `ccd-speckit-run` dispatch a sixth skill, or makes something dispatch `ccd-speckit-run`. The dispatch table above goes stale. Superseding this contract is the remedy; editing the table in place is not.
