---
paths:
  - 'skills/**'
---

# Authoring a skill in `skills/`

Reasoning and sources: [`docs/skill-authoring-practices.md`](../../docs/skill-authoring-practices.md).

## Naming and dispatch

- The directory basename and the frontmatter `name` must be the same string, and both carry the
  `ccd-` prefix. Nothing in the loader enforces either; a mismatch produces a skill that answers to
  a name its own path contradicts.
- One skill dispatching another uses the namespaced form `claude-code-devkit:<name>`. A bare name
  resolves to whichever copy the session picks when a personal skill shares the name.
- **No skill carries `disable-model-invocation`**, and none may. Adding the field to a skill that
  another skill dispatches breaks that dispatch silently, at the end of a long workflow —
  `ccd-speckit-run` dispatches four of the other seven, `ccd-speckit-bug-run` dispatches three of
  them too, and `ccd-pipeline-fix` dispatches `ccd-speckit-bug-run` — so `ccd-commit-push`,
  `ccd-github-pr`, `ccd-gitlab-mr` and `ccd-speckit-bug-run` each have two callers that the field
  would break. `ccd-speckit-run` dropped the field itself in feature 006 once every phase
  became separately gated, and `ccd-speckit-bug-run` never carried it for the same reason: the gate
  is in the workflow, not the frontmatter. The count is a contract:
  `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`, which records eight skills.
- No skill carries `user-invocable`. Its absence is what leaves a skill user-invocable; `false`
  would hide it from the `/` menu.

## Referencing bundled files

- A skill's own scripts and reference files: `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"`.
  `${CLAUDE_SKILL_DIR}` does not spell out the skill's directory name, so a rename touches the
  frontmatter and the directory and nothing else.
- Files genuinely shared between skills:
  `sh "${CLAUDE_PLUGIN_ROOT}/skills/<owner>/scripts/<name>.sh"`. Three qualify today, each existing
  exactly once: `branch-options.sh` in `ccd-branch-push`, and `forge-detect.sh` and
  `cleanup-plan.sh` in `ccd-speckit-run`. `ccd-pipeline-fix` reaches `forge-detect.sh` this way
  rather than carrying a copy. A fork of any of them is the regression, not the sharing.
- Always `sh <path>`, never direct execution — nothing documents that the executable bit survives
  installation. Always quote the variable, so a plugin root containing a space does not split.

## The three budgets

- `SKILL.md` stays under 500 lines. Longer reference material goes in a sibling file that the body
  names, saying what it contains and when to read it.
- `description` and `when_to_use` share 1,536 characters, and the listing truncates. Put the
  triggering use case in the first sentence.
- Only the first 5,000 tokens of a skill survive compaction. Anything a long-running skill must
  still know at its last step belongs in a file it writes, not in its own prose — the way
  `ccd-speckit-run` keeps run state in `.specify/.speckit-run-state.json`.

## Asking the user something

This is the **only** place this rule is stated. A skill that restates it locally creates a second
copy that agrees the day it is written and drifts silently afterwards, which
[`repository-docs.md`](repository-docs.md) calls worse than recording it in neither.

- **Every** point where a skill needs a decision from the user goes through the `AskUserQuestion`
  tool. Never ask in prose, never wait on an untooled "confirm?", never treat silence as assent.
  A question is a tool call or it did not happen.
- Every question presents its **options**. A question with no options is prose wearing a question
  mark, and it puts the whole burden of inventing the alternatives on the reader.
- Every option says what it **does** and what it **costs**. An option list that describes only the
  upside is a recommendation with extra steps.
- Exactly **one** option is marked `(Recommended)`, and the reason is stated. Two recommendations
  is a defect; zero is a defect unless the next rule applies.
- Where recommending anything would be wrong — the decision is the user's alone and no default is
  defensible — say so explicitly. Omitting the recommendation without comment is indistinguishable
  from having forgotten it.
- The recommendation is chosen on the tradeoff, never on which option is easiest to carry out.
  Where the recommended option is the cautious one, say what caution costs.

One thing this rule does not cover: asking the user to **supply** something — paste a log, give a bug report, name a branch that does not exist yet. That is an input request, not a decision among alternatives, and an options list cannot express it. Ask for it in prose, and use the tool for the decision that follows once it arrives. The test is whether the skill could enumerate the acceptable answers; if it could, it must.

Writing the tool's name in prose calls nothing, exactly as with the `Skill` tool.

## Markdown inside a skill

- Never indent with a tab inside a fenced code block. `.editorconfig`'s `[*.md]` section overrides
  only `indent_size` and `trim_trailing_whitespace`, so `indent_style = space` still governs the
  whole file, fences included, and the `editorconfig` check rejects the tab. Use two spaces.
- Every skill carries an `evaluations.md` stating what a correct run looks like and which
  regressions to re-check after editing it.
