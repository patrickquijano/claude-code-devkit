# Contract: skill names, reachability and dispatch

**Supersedes** [`specs/006-claude-code-guidance/contracts/skill-names.md`](../../006-claude-code-guidance/contracts/skill-names.md).

That contract governed six skills and named its own successor condition twice. Under "What this contract does not say": "A seventh skill with side effects and no per-action gate would have a real case for it, and this contract would not settle that case." And under "Regressions this contract exists to catch": "A future feature makes `ccd-speckit-run` dispatch a sixth skill, or makes something dispatch `ccd-speckit-run`. The dispatch table above goes stale. **Superseding this contract is the remedy; editing the table in place is not.**"

Feature 009 adds the seventh skill. This contract supersedes 006 accordingly, and follows 006's own rule: an eighth skill supersedes this one in turn rather than editing the number here.

## The seven skills

| Skill                  | Reachable by   | Dispatched by                                                         |
| ---------------------- | -------------- | --------------------------------------------------------------------- |
| `ccd-branch-push`      | user and model | nothing                                                               |
| `ccd-commit-push`      | user and model | `ccd-speckit-run` at Step 6a                                          |
| `ccd-conflict-resolve` | user and model | `ccd-speckit-run` at every step and phase boundary, **conditionally** |
| `ccd-github-pr`        | user and model | `ccd-speckit-run` at Step 6b, on a GitHub remote                      |
| `ccd-gitlab-mr`        | user and model | `ccd-speckit-run` at Step 6b, on a GitLab remote                      |
| `ccd-speckit-run`      | user and model | nothing                                                               |
| `ccd-speckit-bug-run`  | user and model | nothing                                                               |

## The invariants

**Every one of the seven is addressed as `claude-code-devkit:<name>` when one skill dispatches another.** A bare name resolves to whichever copy the session picks when a personal skill shares the name; nothing here depends on the bare form working.

**That rule reaches only this plugin's own skills, and `ccd-speckit-bug-run` dispatches skills outside it.** The three stages it drives — `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` — are Spec Kit project skills compiled into `.claude/skills/` by the `bug` extension's installer. They are addressed by their **bare** names, because `claude-code-devkit:` does not name them and would not resolve. This is not an exception to the namespacing rule; it is outside its scope. Recorded explicitly so that a later normalising pass does not "fix" it into a dispatch that fails.

**Every directory basename equals its frontmatter `name`, and all seven carry the `ccd-` prefix.** Neither is enforced by the loader, so this is a convention with a maintenance rationale, not a constraint. The prefix disambiguates the **bare** name, which the `claude-code-devkit:` namespace does not.

**Zero of the seven carry `disable-model-invocation: true`.** The count was one under 005, none under 006, and stays none here.

**`ccd-speckit-bug-run` is the case 006 said it could not settle, and this contract settles it.** 006's reasoning was that a skill with side effects and _no per-action gate_ would have a real case for the field. `ccd-speckit-bug-run` has side effects — its second stage edits source code — and it has a per-action gate: every one of its three stages is proposed and approved immediately before it runs, and a stage that will be skipped is announced with its reason rather than passed over silently. Being reached by model invocation therefore cannot cause anything to happen that was not asked for, which is the property the field would otherwise have to provide. **The gate is in the workflow, not in the frontmatter.** If the per-stage gates are ever removed, this justification lapses and the field's case returns with them; the two are a pair.

**No skill carries `user-invocable`.** Its absence is what leaves a skill user-invocable. Setting it `false` would hide the skill from the `/` menu; setting it `true` would restate a default.

**`ccd-speckit-bug-run` addresses its own bundled files as `${CLAUDE_SKILL_DIR}`.** `ccd-speckit-run` uses `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/…` and contains no occurrence of `${CLAUDE_SKILL_DIR}`; it predates `.claude/rules/skill-authoring.md`. The rule is what binds new skills, not the older sibling's practice.

## What this contract does not say

It does not say the seven are the final set. It does not say `disable-model-invocation` is harmless in general — it says each of these seven has a reason not to carry it, and for the seventh that reason is the per-stage gate specifically.

It does not say every skill must dispatch by the namespaced form unconditionally. It says that form addresses **this plugin's** skills, and that a skill reaching outside the plugin uses whatever form addresses the target.

## Verification

```sh
# 1. Zero skills carry disable-model-invocation IN FRONTMATTER.
#    Scoped to the frontmatter block on purpose. Six of the seven discuss the field in their
#    Maintenance prose, so a whole-file grep -- which is what this contract's predecessor
#    specified -- reports six hits while the invariant holds perfectly. See the corrections note
#    below.
for f in skills/*/SKILL.md; do
  sed -n '2,/^---$/p' "$f" | grep -q 'disable-model-invocation' && echo "CARRIES FIELD: $f"
done # expect: no output

# 2. No skill carries user-invocable in frontmatter, for the same reason.
for f in skills/*/SKILL.md; do
  sed -n '2,/^---$/p' "$f" | grep -q 'user-invocable' && echo "CARRIES FIELD: $f"
done # expect: no output

# 3. All seven directory basenames match their frontmatter name, all ccd- prefixed.
for f in skills/*/SKILL.md; do
  d=$(basename "$(dirname "$f")")
  n=$(sed -n 's/^name: //p' "$f" | head -1)
  [ "$d" = "$n" ] || echo "MISMATCH $f: dir=$d name=$n"
  case "$n" in ccd-*) ;; *) echo "UNPREFIXED $f: $n" ;; esac
done # expect: no output

# 4. There are seven of them.
ls -1d skills/*/ | wc -l # expect: 7

# 5. Cross-skill dispatch of THIS PLUGIN's skills uses the namespaced form.
#    The three speckit-bug-* dispatches are expected exclusions: they are Spec Kit
#    project skills, not this plugin's, and the namespace does not address them.
grep -rn 'Skill(skill:' skills/ | grep -v 'claude-code-devkit:' | grep -v '"init"' \
  | grep -v 'speckit-bug-'
# expect: no output

# 6. The new skill addresses its own files by ${CLAUDE_SKILL_DIR}.
grep -c 'CLAUDE_PLUGIN_ROOT' skills/ccd-speckit-bug-run/SKILL.md # expect: 0
```

## A correction to the predecessor's verification

`specs/006-claude-code-guidance/contracts/skill-names.md` specified checks 1 and 2 as whole-file greps:

```sh
grep -rln 'disable-model-invocation' skills/*/SKILL.md # expect: no output
```

**That command does not test the invariant.** Six of the seven skills name the field in their Maintenance sections — telling a future editor not to add it — so the grep reports six files while every frontmatter block is clean. Run as written it fails on a healthy repository, which trains the reader to ignore it; and it would go on failing in exactly the same way if a skill did carry the field, so it cannot distinguish the two states at all.

Checks 1 and 2 above are scoped to the frontmatter block instead. The invariant is unchanged; only the way it is tested is. Feature 006's artifacts are left as the record of what that feature believed and shipped.

## Regressions this contract exists to catch

**The normalising pass.** Someone notices the seven skills' frontmatter is inconsistent in some other respect and makes it uniform, adding `disable-model-invocation` back or `user-invocable: true` "for clarity". Checks 1 and 2 catch both.

**The namespacing pass.** Someone runs check 5 without its `speckit-bug-` exclusion, sees three bare dispatches in `ccd-speckit-bug-run`, and "fixes" them to `claude-code-devkit:speckit-bug-assess` — which names nothing and fails at the first stage of every run. The exclusion in check 5 and the second invariant above exist for this.

**The gate removal.** Someone simplifies `ccd-speckit-bug-run` to approve all three stages once at the start. That is not merely a UX change: it removes the justification recorded above for the skill carrying no `disable-model-invocation`. Removing the gates and keeping the frontmatter as-is leaves a side-effecting skill that a model may invoke with one approval covering a source edit.

**The sibling-copying pass.** Someone aligns `ccd-speckit-bug-run` to `ccd-speckit-run` — `${CLAUDE_PLUGIN_ROOT}` addressing, `evaluations.md` under `reference/`. Both would follow the single exception over the majority and over the written rule. Check 6 catches the first.

**The count going stale.** An eighth skill arrives and this table is edited in place. Supersede instead.
