# Contract: the distributed skills, their names, and what none of them carries

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

**Supersedes** `specs/010-bug-run-ship/contracts/skill-names.md`, which recorded seven skills. The count changes because this feature adds `ccd-pipeline-fix`, and the dispatch set widens because that skill dispatches `ccd-speckit-bug-run`. Feature 010's contract stays on disk as the record of what it shipped.

This supersedes 010's, which superseded 009's, which superseded 006's, which superseded 003's, which superseded 002's. The chain exists because each time, a live pointer cited a stale count.

## The eight

| Directory              | Frontmatter `name`     | Dispatched by                                    |
| ---------------------- | ---------------------- | ------------------------------------------------ |
| `ccd-branch-push`      | `ccd-branch-push`      | — (also the sole home of `branch-options.sh`)    |
| `ccd-commit-push`      | `ccd-commit-push`      | `ccd-speckit-run` §6a, `ccd-speckit-bug-run` §4a |
| `ccd-conflict-resolve` | `ccd-conflict-resolve` | `ccd-speckit-run` boundary check                 |
| `ccd-github-pr`        | `ccd-github-pr`        | `ccd-speckit-run` §6b, `ccd-speckit-bug-run` §4b |
| `ccd-gitlab-mr`        | `ccd-gitlab-mr`        | `ccd-speckit-run` §6b, `ccd-speckit-bug-run` §4b |
| `ccd-speckit-bug-run`  | `ccd-speckit-bug-run`  | **`ccd-pipeline-fix`** — new caller              |
| `ccd-speckit-run`      | `ccd-speckit-run`      | —                                                |
| **`ccd-pipeline-fix`** | **`ccd-pipeline-fix`** | —                                                |

**Directory basename and frontmatter `name` are the same string, and both carry the `ccd-` prefix.** Nothing in the loader enforces either. The prefix looks redundant under the `claude-code-devkit:` namespace and is not: it is what makes the **bare** name unambiguous when a personal copy of the same skill is also installed.

## Zero of the eight carry `disable-model-invocation`

The count was one under 005, none under 006, none under 009, none under 010, and stays **none** here.

`ccd-pipeline-fix` does not carry it, and neither does anything it dispatches. `ccd-speckit-bug-run` now has **two** callers rather than one, so the field on it would break two dispatches silently, at the end of a long workflow. `ccd-commit-push`, `ccd-github-pr` and `ccd-gitlab-mr` keep their two callers each.

**The reachability argument, re-examined — this discharges FR-034.** `skills/ccd-speckit-run/SKILL.md` and `specs/006-claude-code-guidance/contracts/skill-names.md` both record that the field's absence from `ccd-speckit-run` was justified by every phase being separately gated, and that _"if the per-phase gates are ever removed, the old argument returns and the field should return with them. The two are a pair."_

This feature **narrows** those gates; it does not remove them. The property the pairing depended on is untouched: by `contracts/gate-decision.md`'s always-gate set, the workflow cannot reach `implement`, or any step that commits, pushes, raises a review request or deletes a branch or workspace, without an explicit approval for that step. A skill reached automatically still cannot _do_ anything automatically. The field stays off.

The pairing is not discharged, only satisfied differently. If a future feature removes the always-gate set, the argument returns intact and the field should return with it.

## Zero of the eight carry `user-invocable`

Its absence is what leaves a skill user-invocable; `false` would hide it from the `/` menu.

## Cross-skill dispatch is namespaced

`claude-code-devkit:<name>`, through the `Skill` tool. A bare name resolves to whichever copy the session picks when a personal skill shares the name.

**One documented exception, which is not an exception to this contract but outside its scope**: `ccd-speckit-bug-run` dispatches `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test` by their **bare** names, because those are Spec Kit project skills and `claude-code-devkit:speckit-bug-assess` names nothing. `ccd-pipeline-fix` never dispatches those three at all — it dispatches `ccd-speckit-bug-run` and lets that skill own them, per `research.md` R6.

**Writing a skill's name in prose invokes nothing.** Only a `Skill` tool call loads it.

## Shared scripts exist exactly once

| Script              | Home              | Reached by consumers as                                                  |
| ------------------- | ----------------- | ------------------------------------------------------------------------ |
| `branch-options.sh` | `ccd-branch-push` | `${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh` |
| `forge-detect.sh`   | `ccd-speckit-run` | `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/forge-detect.sh`   |
| `cleanup-plan.sh`   | `ccd-speckit-run` | `${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/cleanup-plan.sh`   |

`ccd-pipeline-fix` reaches `forge-detect.sh` this way. **A fork of any of these is the regression, not the sharing** — the header comment on `branch-options.sh` records the three defects of the fork that was already rejected once.

A skill's **own** files are addressed as `${CLAUDE_SKILL_DIR}/…`, which does not spell out the directory name, so a rename touches the frontmatter and the directory and nothing else. `ccd-pipeline-fix` uses `${CLAUDE_SKILL_DIR}` throughout. `ccd-speckit-run` predates the rule and still uses expanded paths; this feature does not change that, and it is not licence for a new skill to copy it.

Always `sh <path>`, always quoted. The executable bit does not survive every install path.

## Every skill ships an `evaluations.md`

All eight, `ccd-pipeline-fix` included. `ccd-speckit-run` keeps its at `reference/evaluations.md`; the other seven keep theirs at the skill root.

## Where the count is stated, and where it must agree

Three places, and SC-011 makes any disagreement a failure:

1. `.claude-plugin/plugin.json` — the `description` field, "seven skills" → **"eight skills"**, and `version` 0.4.0 → **0.5.0**.
2. `CLAUDE.md` — the "What this repository is" paragraph and the distributed-skills section.
3. This contract.

**The version bump is not optional.** It is the only cache key a consumer has, a stale copy is served silently, and feature 008 caught exactly that happening.
