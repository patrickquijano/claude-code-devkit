# Skill authoring practices

How to write and revise a Claude Code skill so that it is found, loaded, and followed. Every practice carries its source; where the official documentation settles nothing, that is recorded as a **GAP** rather than filled with a guess.

Sources are the official documentation at <https://code.claude.com/docs>, principally [skills](https://code.claude.com/docs/en/skills.md) and the [plugins reference](https://code.claude.com/docs/en/plugins-reference.md).

## Contents

- The three budgets that shape a skill
- Frontmatter
- `disable-model-invocation`, and the ambiguity it rests on
- Naming and addressing
- Shipping scripts with a skill
- Evaluating a skill
- Corrections to this repository's earlier records
- Recorded gaps

## The three budgets that shape a skill

Almost every authoring decision follows from one of three documented limits.

**Description: 1,536 characters**, counting `description` and `when_to_use` combined, after which the skill listing truncates. And with many skills installed, Claude Code "shortens descriptions to fit the listing's character budget, which can strip the keywords Claude needs to match your request".

So put the triggering use case **first**. A description that opens with background and reaches the trigger in its third sentence is a description whose trigger may not survive truncation.

**Body: under 500 lines.** "Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files." Supporting files are cheap — a skill's body "loads only when it's used, so long reference material costs almost nothing until you need it" — but only if the body references them so Claude knows what each contains and when to load it.

**Compaction: the first 5,000 tokens.** When a conversation is summarized, Claude Code "re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each", with a combined budget of 25,000 tokens across re-attached skills.

That third one has a design consequence people miss: **a long skill loses its later half first.** Anything a long-running skill must still know at the end — state, decisions already made, the base branch — belongs in a file it writes, not in its own prose. This repository's `ccd-speckit-run` keeps run state in `.specify/.speckit-run-state.json` for exactly this reason.

## Frontmatter

Every field is optional. The ones that matter most in practice:

| Field                                  | What it does                                                                                                                                                              |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                                 | Display name. In a **plugin** skill it sets the last segment of the command; in a personal or project skill it is display-only and the directory name drives the command. |
| `description`                          | What the skill does and when to use it — what Claude matches against. Falls back to the first paragraph of the body.                                                      |
| `when_to_use`                          | Extra trigger context, appended to `description` in the listing and counting toward the same 1,536 characters.                                                            |
| `disable-model-invocation`             | Prevents automatic loading. See below.                                                                                                                                    |
| `user-invocable`                       | `false` hides it from the `/` menu — only Claude can invoke it.                                                                                                           |
| `allowed-tools` / `disallowed-tools`   | Tools permitted without asking, or removed, for the invoking turn only. The grant clears at the next user message.                                                        |
| `paths`                                | Globs limiting automatic activation to matching files.                                                                                                                    |
| `model`, `effort`                      | Model and effort level while the skill is active.                                                                                                                         |
| `context: fork`, `agent`, `background` | Run the skill in a forked subagent context.                                                                                                                               |
| `hooks`                                | Hooks registered on invocation, which keep running for the rest of the session.                                                                                           |
| `argument-hint`, `arguments`           | Autocomplete hint, and named arguments for `$name` substitution.                                                                                                          |
| `metadata`, `license`, `compatibility` | Accepted, not acted on.                                                                                                                                                   |

## `disable-model-invocation`, and the ambiguity it rests on

Quoted in full, because a load-bearing decision in this repository rests on what it does **not** say:

> "Set to `true` to prevent Claude from automatically loading this skill. Use for workflows you want to trigger manually with `/name`. Also prevents the skill from being preloaded into subagents. As of v2.1.196, also prevents the skill from running when a scheduled task fires with the skill as its prompt. Default: `false`."

**GAP: the documentation does not say whether an explicit `Skill` tool call from another skill is affected.** "Prevent Claude from automatically loading" can be read as silent on the non-automatic case, and no passage resolves it either way.

Two readings are available and only one is safe. Under the strict reading, setting the field on a skill that another skill dispatches would break that dispatch — silently, at the end of a long workflow. Under the permissive reading, omitting it costs nothing at all. So **the strict reading binds**: a skill that another skill dispatches does not carry the field.

**In this repository**, exactly one of six skills carries it, and it is `ccd-speckit-run` — the entry point a user invokes, which dispatches three of the others. The asymmetry is deliberate, and a pass that normalised the six "for consistency" would break that dispatch. The count is a committed contract at [`specs/005-merge-conflict-resolution/contracts/skill-names.md`](../specs/005-merge-conflict-resolution/contracts/skill-names.md).

The newest skill, `ccd-conflict-resolve`, omits the field for a different reason: nothing dispatches it, so the ambiguity does not arise, and every mutation it makes is gated on the user's approval — so being reached automatically cannot cause anything to be resolved automatically.

## Naming and addressing

A plugin skill is addressed `plugin-name:skill-name`, so it cannot collide with a personal or project skill of the same bare name — **both load**, under different prefixes. That is documented behaviour, not a defect.

Which is precisely why this repository prefixes all six of its skills `ccd-` even under the `claude-code-devkit:` namespace. The namespace disambiguates the namespaced form; nothing disambiguates the bare form, and the bare form is what a user types.

**GAP: nothing requires the directory basename to equal the frontmatter `name`.** For a plugin skill, `name` _replaces_ the directory name in the command's last segment — `my-plugin/skills/review/SKILL.md` with `name: fancy` becomes `/my-plugin:fancy`. A mismatch produces a skill that loads and answers to a name its own path contradicts.

This repository keeps basename and `name` equal anyway, as a convention with a maintenance rationale rather than a loader constraint: a skill answering to a name its path contradicts is a trap for whoever next greps for it.

**GAP: no character-set or length constraint on `name` is documented**, and none on `description` beyond the listing truncation.

## Shipping scripts with a skill

A skill directory may contain supporting files, and the documentation's own example layout includes `scripts/helper.py` annotated "executed, not loaded".

**Reference a skill's own files through `${CLAUDE_SKILL_DIR}`** — "the directory containing the skill's `SKILL.md` file", for "scripts or files bundled with the skill, regardless of the current working directory".

**Reference files shared between a plugin's skills through `${CLAUDE_PLUGIN_ROOT}`** — "the plugin's installation directory … including resources shared between the plugin's skills".

That distinction is the documented one, and it is worth following exactly:

| Situation                         | Use                                                      |
| --------------------------------- | -------------------------------------------------------- |
| A skill invoking its own script   | `${CLAUDE_SKILL_DIR}/scripts/<name>.sh`                  |
| Several skills sharing one script | `${CLAUDE_PLUGIN_ROOT}/skills/<owner>/scripts/<name>.sh` |

The practical argument for the first is this repository's own history: feature 003 renamed five skills and touched **328 references across 40 files**, because every path spelled out the skill's own directory name. `${CLAUDE_SKILL_DIR}` does not spell it out, so a rename touches the frontmatter and the directory and nothing else.

**In this repository**: `ccd-conflict-resolve` uses `${CLAUDE_SKILL_DIR}` for its four scripts. `branch-options.sh` is genuinely shared by four skills, so it keeps `${CLAUDE_PLUGIN_ROOT}` and lives in exactly one place. The four older skills still spell out `${CLAUDE_PLUGIN_ROOT}` for their own scripts; converting them is a deliberate future change, not an oversight to fix in passing.

**Invoke scripts as `sh <path>`, never by executing them directly.**

> **GAP: nothing documents whether the executable bit survives installation or copying.**

That gap is the whole reason for the rule. `sh <path>` is correct whether or not the bit survives; executing directly is correct only if it does. Quote the variable too — `sh "${CLAUDE_SKILL_DIR}/scripts/x.sh"` — so a plugin root containing a space does not split.

A `bin/` directory **cannot** be included in plugins distributed through claude.ai organization settings. **GAP**: whether that restriction extends to community-marketplace or personal distribution is not stated. This repository ships no `bin/` either way.

## Evaluating a skill

> "Seeing a skill trigger tells you Claude found it, not that it did what you intended."

Measure two things separately: whether Claude invokes it on the prompts it should, and whether the output matches expectation when it does. The documented method for both is a **baseline comparison** — collect realistic prompts, run each in a fresh session with the skill available and again with it disabled, and compare.

The documented tool is the `skill-creator` plugin: test cases in `evals/evals.json` inside the skill directory, a subagent per case for a clean context, assertion grading, a with-skill versus without-skill benchmark, and description tuning that generates should-trigger and should-not-trigger prompts and measures the hit rate.

**In this repository** each skill carries a hand-written `evaluations.md` instead — prose scenarios naming what passes and what fails. That is **not** the documented mechanism and the two should not be confused: `evaluations.md` is a checklist a human or an agent re-runs, `evals/evals.json` is a harness. Adopting the harness would be a real improvement and is not currently done.

**GAP**: `/skill-doctor` and `claude plugin eval` are not covered in the skills documentation; `skill-creator` is the documented route.

## Corrections to this repository's earlier records

Research for feature 005 found three claims in earlier artifacts that the documentation does not support. Those artifacts are left as the record of what each feature believed and shipped; the corrections live here.

| Claim                                                                     | Where                                             | Correction                                                                                                                     |
| ------------------------------------------------------------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| A basename/`name` mismatch "makes a skill unloadable"                     | `specs/002-vendor-plugin-skills/data-model.md:25` | It does not. `name` replaces the directory name in the command; the skill loads under a different name than its path suggests. |
| "The documentation offers no guidance on how long a `SKILL.md` should be" | `specs/002-vendor-plugin-skills/research.md:20`   | There is guidance: under 500 lines.                                                                                            |
| "`argument-hint` is not a documented field"                               | `specs/002-vendor-plugin-skills/research.md:42`   | It is documented.                                                                                                              |

A fourth is a narrowing rather than a correction: `specs/002-vendor-plugin-skills/research.md:106` states that a top-level `bin/` "is refused by marketplace sync" without qualification. The documented restriction is specific to claude.ai organization distribution.

## Recorded gaps

Collected for convenience; each is explained where it appears above.

- Whether `disable-model-invocation` affects an explicit `Skill` call from another skill.
- Whether the executable bit survives installation.
- Any character-set or length constraint on `name`.
- Any length constraint on `description` beyond listing truncation.
- Whether the `bin/` restriction extends beyond organization distribution.
- Whether the directory basename must equal the frontmatter `name` (it need not).
- Token costs for description loading, full skill loading, or reference files.
- Whether a description should be phrased in third person, or should state when _not_ to use the skill. This repository does both, by convention rather than by documented advice.
