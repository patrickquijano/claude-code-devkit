# Research: Bug triage run ships its own work

Phase 0 output. Every claim of fact names its source. Questions the sources do not settle are recorded as **GAP** rather than answered by guess, per FR-032. Retrieved 2026-09-05.

## Contents

- 1. Whether upstream Spec Kit wires git into the bug workflow
- 2. Spec Kit hook events — the real inventory
- 3. Where the extension config actually lives
- 4. Upstream guidance on agents, commits and review requests
- 5. Extension authoring standards and the component priority stack
- 6. Claude Code effectiveness — the practices that bear on this design
- 7. `CLAUDE.md` — length, structure, and the section-order question
- 8. Skill authoring budgets and the compaction constraint
- 9. What the two skills already do
- 10. Decisions
- 11. Recorded gaps
- 12. Corrections to the published record

## 1. Whether upstream Spec Kit wires git into the bug workflow

**Decision-bearing finding.** It does not, and it cannot as currently built.

The installed `.specify/extensions.yml` declares hook entries under 18 event keys, all of them core spec-driven-development events. There is no `before_bug_*` or `after_bug_*` key anywhere in the file, and `.specify/extensions/bug/extension.yml` declares only `provides.commands` — three of them — with no `hooks:` key at all. The bug extension's own README states: "This extension registers no hooks."

The consequence follows directly: installing the `git` extension produces no branching and no committing around `speckit.bug.*`, because the events that would carry those hooks do not exist. **Any branch, commit or review-request behaviour around a bug run has to be supplied by the caller.**

This is what reconciles this feature with feature 009's FR-020. That requirement was written when the run's scope stopped at three reports; it is not a statement that the behaviour is undesirable upstream, but a boundary this repository drew for itself. Since upstream leaves the gap open by design, the caller filling it is the intended shape rather than a workaround.

## 2. Spec Kit hook events — the real inventory

`docs/reference/extensions.md` upstream documents 18 hook events. The **installed** core skills at version 1.0.2.dev0 check **20**, adding `before_converge` and `after_converge`, which correspond to the `speckit-converge` command present in `.claude/skills/`. Those two are undocumented upstream.

The 18 declared in this repository's `extensions.yml`, with what each carries: `before_constitution` and `before_specify` are the only two with a non-optional entry (`git`, `optional: false`); `before_implement` carries `superb`'s implementation gate as its only other mandatory entry. Every remaining entry across all 18 events is optional.

**In this repository**, `git-config.yml` sets `auto_commit.default: false` and `false` for all sixteen per-command overrides, so the `git` extension's `speckit.git.commit` hook is registered everywhere and does nothing anywhere. That is why an ordinary pipeline run ends with an empty commit range and why `ccd-speckit-run`'s Step 6a exists at all.

## 3. Where the extension config actually lives

Two upstream documents disagree. `EXTENSION-API-REFERENCE.md:884` places the project config at `.specify/extensions/extensions.yml`; `docs/reference/extensions.md:200` places it at `.specify/extensions.yml`.

**`docs/reference/extensions.md` is correct**, verified two ways: the file exists on disk at `.specify/extensions.yml` in this repository, and the CLI's `EXTENSIONS_CONFIG` handling in `specify_cli/extensions/__init__.py` resolves to that path. The API reference's layout block is stale — it is self-stamped "Spec Kit Version: 0.1.0" at line 896.

## 4. Upstream guidance on agents, commits and review requests

There is **no** extension API, hook event, or CLI command anywhere in Spec Kit for opening or updating a pull or merge request. `speckit.git.remote` only detects the remote URL. The only forge-facing core command is `speckit.taskstoissues`, which creates issues, not review requests.

The closest thing to guidance is `AGENTS.md` in the spec-kit repository itself, which is contributor policy for that repository and explicitly not extension-authoring guidance, and not binding on downstream projects. It is recorded here because it is the only upstream statement on the subject and because three of its rules are worth weighing even though they do not bind:

- L509: "…ask for explicit permission to proceed. Do not assume consent. **If the user is unavailable to provide that permission, including during autonomous or non-interactive operation, do not open the pull request.** Preserve the work on a branch and report that confirmation is required."
- L513-517: every agent-authored commit should carry an `Assisted-by:` trailer naming the agent and whether it acted autonomously or under supervision.
- L520: "Never push solo-authored commits that hide agent authorship behind the operator's git identity."

**In this repository**, the first is already satisfied structurally: every step of this run gates on `AskUserQuestion`, and a step whose gate cannot be answered does not proceed. The second and third are `ccd-commit-push`'s business, not this feature's, and are not adopted here — doing so would be a repository-wide commit-message policy, which is a constitution-level change and outside this feature's scope. Recorded as a **GAP** below.

## 5. Extension authoring standards and the component priority stack

Spec Kit's README defines a four-tier resolution stack, extensions sitting third: `.specify/templates/overrides/` → `.specify/presets/templates/` → `.specify/extensions/templates/` → `.specify/templates/`.

Two different resolution times apply, and conflating them is the trap: "**Templates** are resolved at **runtime** — Spec Kit walks the stack top-down and uses the first match", whereas "**Extension/preset commands** are applied at **install time**." This is why editing an extension manifest requires a reinstall to take effect, and why `register_hooks()` rewriting `extensions.yml` on every install is destructive to hand-assigned priorities — the behaviour this repository's `extensions.yml` header comment already warns about at length.

Extension command names follow `speckit.{extension}.{command}`. Templates and scripts always replace rather than merge.

**In this repository**, none of this changes: the feature adds no extension, no template and no hook. It is recorded because `docs/spec-kit-extensions.md` is the file the feature updates, and the config-path and hook-count corrections in sections 2 and 3 belong there.

## 6. Claude Code effectiveness — the practices that bear on this design

From `https://code.claude.com/docs/en/best-practices.md`:

- The governing constraint is context: "Most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills."
- On delegation: "Use subagents to keep research out of it. When Claude researches a codebase it reads lots of files, all of which consume your context. Subagents run in separate context windows and report back summaries."
- On verification: "Give Claude a check it can run: tests, a build, a screenshot to compare. It's the difference between a session you watch and one you walk away from."
- On correction: "After two failed corrections, `/clear` and write a better initial prompt incorporating what you learned."
- The recommended shape is explore → plan → code → commit, with plan mode separating research from implementation.

**In this repository**, the first two are already load-bearing rather than aspirational: `ccd-speckit-run/reference/subagents.md` caps delegated sweeps at ten and forbids delegating a decision, and this very run dispatched five read-only sweeps for exactly the stated reason. The verification point is what `scripts/lint.sh` is — a check the agent can run and act on unattended. This is the material `docs/claude-code-practices.md` currently lacks: that file has no section on working efficiently, and the string "token cost" appears in the docs set only as a recorded gap.

## 7. `CLAUDE.md` — length, structure, and the section-order question

From `https://code.claude.com/docs/en/memory.md`:

- "Size: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."
- Files over 4 MiB are skipped entirely.
- Imports use `@path/to/import`, resolve relative to the importing file, and recurse to "a maximum depth of four hops."
- Path-scoped rules: "Rules can be scoped to specific files using YAML frontmatter with the `paths` field… Path-scoped rules trigger when Claude reads files matching the pattern, not on every tool use."
- Structure guidance is about grouping, not ordering: "use markdown headers and bullets to group related instructions."
- `/doctor` "proposes trims for a checked-in CLAUDE.md: it cuts content Claude can derive from the codebase… and keeps pitfalls, rationale, and conventions that differ from tool defaults."

**On recommended section order specifically**: the documentation states what belongs in the file and that structure should group related instructions, and prescribes **no ordering of sections**. This is a definite finding, not a gap, and this repository already records it as such in `docs/claude-code-project-structure.md:144` and `.claude/rules/repository-docs.md:33`. A re-check on 2026-09-05 confirms it still holds. Nothing in this feature invents an order.

## 8. Skill authoring budgets and the compaction constraint

From `https://code.claude.com/docs/en/skills.md`: `description` is "your primary tool for Claude's automatic skill invocation"; `description` plus `when_to_use` are capped at 1,536 characters combined; "Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files"; skill content "loads only when invoked, so large reference material costs almost nothing until needed. This differs from `CLAUDE.md`, where all content loads on every turn." `${CLAUDE_SKILL_DIR}` names the skill's own directory; `${CLAUDE_PLUGIN_ROOT}` names the plugin installation directory and is how skills share resources.

The compaction budget is the one that shapes this feature. `ccd-speckit-run/reference/run-state.md` records the mechanism in its first line: an invoked skill is re-attached after compaction only up to a token budget, so the later half of a long skill is what a long run loses first, and it is never re-read from disk. `ccd-speckit-bug-run` is 235 lines today; the added material is substantial, and the steps that need it — shipping and teardown — are precisely the ones that run last. Hence two new reference files and an extended state file rather than a longer `SKILL.md`.

## 9. What the two skills already do

`ccd-speckit-bug-run` has none of the five behaviours this feature adds, and three are actively forbidden in its current text: `SKILL.md:200` ("**Do not commit.** No `git add`, no `git commit`, no branch, no review request"), `reference/stages.md:96`, its own frontmatter `description`, plus red-flag rows at `SKILL.md:220` and `:224` and an evaluation at `evaluations.md:56`. Every one of those is a site the implementation must rewrite, not merely add around.

Its loop-back is the partial exception: `SKILL.md:190` already offers "re-run the assessment with the new evidence" as one of three choices on a `partial` or `failed` result. What is missing is the edge — choosing it currently ends the run. `reference/stages.md:69` shows the branch table's terminal row.

`ccd-github-pr` already offers source-branch deletion, but only welded to auto-merge. `SKILL.md:125` offers exactly two `PR opts`: `Enable auto-merge — squash + delete branch (Recommended)` and `Open as draft`. `SKILL.md:127` already handles the repository-default case: "`deleteBranchOnMerge: true` already → say the delete half is the repo default and needs no flag." `SKILL.md:277` shows the mechanism, `gh pr merge '<url>' --auto --squash --delete-branch`, and `:274` explains why it is a separate call: "GitHub has no per-PR squash or delete-branch flag at create time."

`ccd-gitlab-mr` **already offers the choice independently**. `SKILL.md:121`: "`header: \"Merge opts\"` — `multiSelect: true`, exactly two options… `Delete source branch on merge (Recommended)`… and `Squash commits on merge (Recommended)`." This is the verification FR-029a requires, and it is why only one skill changes.

## 10. Decisions

**Decision: mirror `ccd-speckit-run/reference/ship.md` rather than generalise it.**
Rationale: extracting a shared reference file that both skills import would be the DRY answer, but a skill's reference files are read through its own `${CLAUDE_SKILL_DIR}`, and cross-skill reference imports are not a mechanism Claude Code provides. Mirroring with an explicit citation is the available option.
Alternatives considered: (a) extract to a shared `reference/` under the plugin root — rejected, no import mechanism, and `${CLAUDE_PLUGIN_ROOT}` reaches _scripts_ by path but a reference file must be read by the model, which means naming it in prose the skill may have lost to compaction; (b) have `ccd-speckit-bug-run` dispatch `ccd-speckit-run` for its Step 6 — rejected, that skill's Step 6 has preconditions on eight phases of its own state.

**Decision: extend the existing state file rather than add a second.**
Rationale: feature 009 established `.specify/.speckit-bug-run-state.json` and the precondition discipline around it. New blocks follow the same write-as-you-go rule.
Alternatives considered: a separate ship-state file — rejected as two files to keep consistent with no benefit.

**Decision: the reassessment cycle counter lives in state, not in prose.**
Rationale: FR-011b requires the count be stated at each choice, and the choice happens late in a long run — exactly where compaction has already removed early conversation.

**Decision: change `ccd-github-pr` only; verify and record `ccd-gitlab-mr`.**
Rationale: section 9 establishes GitLab already complies. FR-029a forbids cosmetic rework.

**Decision: no constitution amendment.**
Rationale: Principle VI already requires both paths' artifacts committed and is silent on who commits them. See `plan.md`.

**Decision: no `Assisted-by:` trailer policy.**
Rationale: upstream contributor policy is not binding downstream, and adopting it would be a repository-wide commit-message rule — constitution-level, and outside this feature. Recorded as a gap rather than silently dropped.

## 11. Recorded gaps

- **GAP**: Whether `disable-model-invocation` blocks an explicit `Skill` tool call or only automatic loading. The documentation says both things in different places; `docs/skill-authoring-practices.md` already records this and this feature does not resolve it. It binds here only negatively — no skill in this plugin carries the field, and none may.
- **GAP**: Whether this repository should adopt an `Assisted-by:` commit trailer, per spec-kit's own `AGENTS.md`. Not settled by this feature; it is a commit-message policy for `ccd-commit-push` and arguably for the constitution.
- **GAP**: Upstream documents 18 hook events; the installed core skills check 20. No upstream document explains `before_converge`/`after_converge`, and no changelog entry was found introducing them.
- **GAP**: Whether the ordering assumption behind hook priorities is specified anywhere. `docs/spec-kit-extensions.md:164` already assigns this gap to Spec Kit rather than to this repository; re-checked and still open.
- **GAP**: Whether auto memory and `CLAUDE.md` have a defined precedence when they conflict. The memory documentation describes both loading into context but does not say which wins.

## 12. Corrections to the published record

| Claim as previously recorded                                                                                                   | Correction                                                                                                          | Evidence                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `docs/spec-kit-extensions.md` states the hook-event inventory without a count discrepancy                                      | Upstream documents 18; the installed 1.0.2.dev0 core skills check 20, adding `before_converge` and `after_converge` | installed `.claude/skills/speckit-converge/SKILL.md`; upstream `docs/reference/extensions.md` |
| Extension project config path, per `EXTENSION-API-REFERENCE.md:884`, is `.specify/extensions/extensions.yml`                   | It is `.specify/extensions.yml`; the API reference block is stale and self-stamped version 0.1.0                    | on-disk file; `specify_cli/extensions/__init__.py` `EXTENSIONS_CONFIG`                        |
| `.claude/rules/skill-authoring.md` cites `specs/006-claude-code-guidance/contracts/skill-names.md` as the skill-count contract | 009's contract superseded 006's; this feature's contract supersedes 009's in turn                                   | `specs/009-bug-triage-run/contracts/skill-names.md:7`                                         |
| `skills/ccd-github-pr/SKILL.md:364` cites 006's contract for the same rule                                                     | Same correction                                                                                                     | as above                                                                                      |
| Feature 009's FR-020 records that the run must not branch, commit or open a review request                                     | Superseded by this feature's FR-019. 009's record is left intact as the historical statement of what 009 shipped    | `specs/010-bug-run-ship/spec.md` FR-019                                                       |
