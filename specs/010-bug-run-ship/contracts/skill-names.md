# Contract: skill names, reachability and dispatch

**Supersedes** `specs/009-bug-triage-run/contracts/skill-names.md`, which superseded `specs/006-claude-code-guidance/contracts/skill-names.md`.

Feature 010 adds **no** skill. The count stays at seven. This contract supersedes 009's because 009's rule is that a change to the set supersedes the contract rather than editing the number in place — and because two live pointers still cite 006's contract, which this feature corrects. An eighth skill supersedes this one in turn.

## The seven skills

| Directory                     | Frontmatter `name`     | Reachable by   | Changed in 010                                 |
| ----------------------------- | ---------------------- | -------------- | ---------------------------------------------- |
| `skills/ccd-branch-push`      | `ccd-branch-push`      | user and model | no                                             |
| `skills/ccd-commit-push`      | `ccd-commit-push`      | user and model | no — dispatched by the new shipping step       |
| `skills/ccd-conflict-resolve` | `ccd-conflict-resolve` | user and model | no                                             |
| `skills/ccd-github-pr`        | `ccd-github-pr`        | user and model | **yes** — `PR opts` split                      |
| `skills/ccd-gitlab-mr`        | `ccd-gitlab-mr`        | user and model | **no — verified only, per FR-029a**            |
| `skills/ccd-speckit-run`      | `ccd-speckit-run`      | user and model | no                                             |
| `skills/ccd-speckit-bug-run`  | `ccd-speckit-bug-run`  | user and model | **yes** — workspace, loop-back, ship, teardown |

## The rules

**Every one of the seven is addressed as `claude-code-devkit:<name>` when one skill dispatches another.** A bare name resolves to whatever the session decides when a personal copy is also installed.

**That rule reaches only this plugin's own skills, and `ccd-speckit-bug-run` dispatches skills outside it.** The three stages it drives — `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test` — are Spec Kit project skills compiled into `.claude/skills/` by the `bug` extension's installer. They are addressed by their **bare** names, because `claude-code-devkit:` does not name them and would not resolve. This is not an exception to the namespacing rule; it is outside its scope. Recorded explicitly so that a later normalising pass does not "fix" it into a dispatch that fails.

**Every directory basename equals its frontmatter `name`, and all seven carry the `ccd-` prefix.**

**Zero of the seven carry `disable-model-invocation: true`.** The count was one under 005, none under 006, none under 009, and stays none here. Adding it to `ccd-commit-push`, `ccd-github-pr` or `ccd-gitlab-mr` would break `ccd-speckit-bug-run`'s new shipping step silently, at the end of a full triage run — the same failure mode `ccd-speckit-run`'s Step 6 already carries this warning for, now with a second caller.

**`ccd-speckit-bug-run` addresses its own bundled files as `${CLAUDE_SKILL_DIR}`**, and reaches other skills' scripts through `${CLAUDE_PLUGIN_ROOT}`, always quoted, always invoked as `sh <path>`.

**Dispatch is a tool call, not a phrase.** Writing `/ccd-commit-push` into prose invokes nothing; the sub-skill's own `SKILL.md` never loads and its gates do not exist for that run.

## Verification

```sh
# 1. Seven skills, no more.
ls -1d skills/*/ | wc -l # expect: 7

# 2. Directory basename equals frontmatter name, all ccd- prefixed.
for d in skills/*/; do
  n=$(sed -n 's/^name: //p' "$d/SKILL.md" | head -1)
  [ "$n" = "$(basename "$d")" ] || echo "MISMATCH: $d -> $n"
done # expect: no output

# 3. No skill carries disable-model-invocation IN ITS FRONTMATTER.
#    Scope to the frontmatter block: every skill discusses the field in its authoring
#    note, so a whole-file grep reports six false positives and invites someone to
#    "fix" prose that is correct.
for d in skills/*/; do
  sed -n '2,/^---$/p' "$d/SKILL.md" | grep -q 'disable-model-invocation\|user-invocable' \
    && echo "CARRIES FIELD: $d"
done
# expect: no output

# 4. Cross-skill dispatch of THIS PLUGIN's skills uses the namespaced form.
#    The three speckit-bug-* dispatches are expected exclusions: they are Spec Kit
#    project skills, not this plugin's, and the namespace does not address them.
grep -rn 'Skill(skill:' skills/ | grep -v 'claude-code-devkit:' | grep -v '"init"' \
  | grep -v 'speckit-bug-'
# expect: no output

# 5. ccd-speckit-bug-run addresses its own files by ${CLAUDE_SKILL_DIR}, and other
#    skills' scripts by ${CLAUDE_PLUGIN_ROOT}. Both appear; neither is wrong here.
grep -c 'CLAUDE_SKILL_DIR' skills/ccd-speckit-bug-run/SKILL.md   # expect: > 0
grep -n 'CLAUDE_PLUGIN_ROOT' skills/ccd-speckit-bug-run/SKILL.md # expect: only sibling-skill script paths

# 6. No pointer still cites a superseded contract.
grep -rn '006-claude-code-guidance/contracts/skill-names' skills/ .claude/rules/ CLAUDE.md
# expect: no output

# 7. ccd-gitlab-mr's merge options were not reworked.
#    FR-029a forbids reworking that skill for cosmetic parity; it does not forbid
#    correcting a stale pointer in it, which FR-035 separately requires. So this
#    check asserts what the requirement means rather than that the file is
#    byte-identical, which was a stricter proxy that made the two requirements
#    contradict each other.
grep -c 'Delete source branch on merge (Recommended)' skills/ccd-gitlab-mr/SKILL.md # expect: 1
grep -c 'Squash commits on merge (Recommended)' skills/ccd-gitlab-mr/SKILL.md       # expect: 1
grep -c 'Merge opts.*exactly two options' skills/ccd-gitlab-mr/SKILL.md             # expect: 1
git diff main...HEAD -- skills/ccd-gitlab-mr/ | grep -c '^[-+].*Merge opts'         # expect: 0
```

Check 6 is new in 010 and was the one that failed. It found **six** stale pointers, not the two the research sweep reported: `skills/ccd-github-pr/SKILL.md`, `.claude/rules/skill-authoring.md`, `skills/ccd-gitlab-mr/SKILL.md`, `skills/ccd-conflict-resolve/SKILL.md`, `skills/ccd-speckit-run/SKILL.md` and `docs/skill-authoring-practices.md`. The last three also carried a stale **count** — "zero of the six" — which had been wrong since 009 made it seven. A grep found what reading did not, which is the argument for having the check at all.

Check 3 was rewritten during implementation. It began as `grep -rn 'disable-model-invocation' skills/`, which matches every skill's authoring note discussing the field and reported six false positives against a true answer of zero. A check that fails when the repository is correct trains people to ignore it, so it is now scoped to the frontmatter block.

Check 7 encodes FR-029a, and it was narrowed for a reason worth recording. It began as `git diff --name-only … -- skills/ccd-gitlab-mr/` expecting no output — which made FR-029a contradict FR-035, since one of the stale pointers check 6 found lives in that very file. FR-029a forbids **reworking that skill's merge options for cosmetic parity**; it does not forbid correcting a citation. The check now asserts the requirement rather than a stricter proxy for it: the two options and the `Merge opts` question are unchanged, and GitLab keeps the independent source-branch deletion it already had at `skills/ccd-gitlab-mr/SKILL.md:121`.
