# Research: Claude Code guidance and pipeline gating

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

Phase 0 output. Every documentation claim below was fetched from <https://code.claude.com/docs> during this phase, not recalled. Where the documentation does not settle a question it is recorded as a **GAP**, in the style the two existing practice documents already use.

## Contents

- Sources consulted
- Findings: what the documentation says that this repository does not yet record
- Findings: what this repository records that the documentation no longer supports
- Decision 1 — the new project-structure document
- Decision 2 — corrections to the two existing practice documents
- Decision 3 — the path-scoped authoring rule
- Decision 4 — skill reachability and the superseding contract
- Decision 5 — per-phase gating
- Decision 6 — the subagent concurrency cap
- Decision 7 — conflict detection
- Decision 8 — workspace teardown
- Decision 9 — the five requirements-quality gaps
- Recorded gaps

## Sources consulted

| Page                                                                      | Used for                                                                                         |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| [claude-directory](https://code.claude.com/docs/en/claude-directory.md)   | what `.claude/` holds and when each part loads — **not cited anywhere in this repository today** |
| [memory](https://code.claude.com/docs/en/memory.md)                       | instruction-file precedence, `CLAUDE.md` limits, `@path` imports, `.claude/rules/`               |
| [settings](https://code.claude.com/docs/en/settings.md)                   | settings precedence and list merging                                                             |
| [hooks-guide](https://code.claude.com/docs/en/hooks-guide.md)             | the hook event list                                                                              |
| [skills](https://code.claude.com/docs/en/skills.md)                       | frontmatter, the three budgets, naming, bundled scripts, evaluation                              |
| [plugins-reference](https://code.claude.com/docs/en/plugins-reference.md) | manifest path fields and whether each extends or replaces                                        |
| [plugins](https://code.claude.com/docs/en/plugins.md)                     | plugin layout, the `bin/` restriction                                                            |
| [best-practices](https://code.claude.com/docs/en/best-practices.md)       | writing an instruction that is followed, verification                                            |

## Findings: what the documentation says that this repository does not yet record

**F1 — There is a documentation page devoted to the `.claude/` directory, and nothing here cites it.** `claude-directory.md` is the natural primary source for FR-001 and is referenced by none of the three existing documents.

**F2 — The plugin `skills` field has a documented exception.** The additive behaviour this repository records is correct — "The default `skills/` is always scanned. Custom paths are loaded alongside the default" — but the documentation adds: "For marketplace entries with `source` resolving to marketplace root, declaring specific subdirectories **replaces** the default `skills/` scan." Every other path field replaces rather than extends: "When you specify a manifest field, the default directory is NOT scanned. To keep the default AND add more, list it explicitly."

**F3 — `MEMORY.md` has its own load limit.** "The first 200 lines of `MEMORY.md`, or the first 25KB, whichever comes first, are loaded at the start of every conversation."

**F4 — The `paths` budget has a qualifier this repository omits.** "a rule's whole `paths` list shares one budget of 1,000 expanded patterns and 4 MiB, **and patterns without braces don't count against it**." The existing text records the budget but not the exemption.

**F5 — Relative import paths resolve against the importing file.** "Relative paths resolve relative to the file containing the import, not the working directory."

**F6 — Instruction files concatenate rather than override.** "All discovered files are concatenated into context rather than overriding each other... instructions closer to where you launched Claude are read last." This is what makes the contradiction behaviour at `memory.md` — "if two rules contradict each other, Claude may pick one arbitrarily" — a consequence rather than a separate rule.

**F7 — Eight skill frontmatter fields and features are absent from this repository's table**: `when_to_use` as a first-class trigger field, `shell`, the `skillOverrides` setting, nested `.claude/skills/` with directory-qualified naming such as `apps/web:deploy`, synced skills under `~/.claude/skills/synced/`, the `$N` argument shorthand, `background: false` for an in-turn forked skill, and the abort-the-whole-invocation behaviour when dynamic context injection fails.

**F8 — `/doctor` proposes cuts to a checked-in `CLAUDE.md`.** "For a checked-in CLAUDE.md, run `/doctor` and Claude proposes cuts for content it can derive from the codebase." This is the documented tool for the derivability test this repository already applies by hand.

**F9 — Emphasis is a scarce resource.** "If Claude keeps skipping one instruction, add emphasis such as 'IMPORTANT' to that line alone. If you emphasize many lines, none of them stands out."

## Findings: what this repository records that the documentation no longer supports

**F10 — The hook event list is stale.** `docs/claude-code-practices.md:99` names twelve events and says "and others". The documented list now holds **32**, including `PostToolBatch`, `MessageDisplay`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `InstructionsLoaded`, `ConfigChange`, `CwdChanged`, `DirectoryAdded`, `WorktreeCreate`, `WorktreeRemove`, `PreModelSwitch`, `PostModelSwitch`, `Elicitation`, `ElicitationResult`, `StopFailure`, `PermissionDenied`, `UserPromptExpansion` and `Setup`. Every event the existing text names still exists; the list is incomplete rather than wrong.

**F11 — The description-truncation mechanism is described incorrectly.** `docs/skill-authoring-practices.md:22` says Claude Code "shortens descriptions to fit the listing's character budget, which can strip the keywords Claude needs to match your request". The documented behaviour is different in kind: "When the listing overflows, Claude Code **drops** descriptions starting with the skills you invoke least, so the skills you use most keep their full text." Whole descriptions are dropped, least-invoked first — not truncated. The 1,536-character truncation is a separate, real limit that applies to a single skill's own `description` plus `when_to_use`. The advice that follows — put the trigger first — survives both mechanisms, but the stated mechanism is wrong and a reader reasoning from it would reason wrongly.

**F12 — The `disable-model-invocation` gap is narrower than recorded, and it narrows toward the strict reading.** `docs/skill-authoring-practices.md:57` records: "the documentation does not say whether an explicit `Skill` tool call from another skill is affected." A passage now bears on it directly:

> "To keep Claude from **invoking it through the Skill tool**, set `disable-model-invocation: true`." — `skills.md`

That sentence names the `Skill` tool with no "automatically" qualifier, and sits against the field's own entry:

> "Set to `true` to prevent Claude from automatically loading this skill. Use for workflows you want to trigger manually with `/name`. Also prevents the skill from being preloaded into subagents. As of v2.1.196, also prevents the skill from running when a scheduled task fires with the skill as its prompt. Default: `false`."

**GAP remains**, because the two passages still pull in opposite directions and neither addresses a call originating in another skill. But the weight has moved onto the strict reading, which is the reading this repository already adopted on asymmetry grounds. The four skills that `ccd-speckit-run` dispatches must continue to omit the field, and that rule is now better founded than "the ambiguity is unresolved".

This finding does **not** bear on removing the field from `ccd-speckit-run` itself. Nothing dispatches that skill; the field governs only whether the model may start it, which is exactly what FR-008 changes.

**F13 — The `bin/` restriction is confirmed as organization-scoped.** "You can't include this directory in a plugin you distribute through claude.ai organization settings." The narrowing recorded at `docs/skill-authoring-practices.md:126` stands.

**F14 — The basename/`name` non-requirement is confirmed with an example.** A plugin skill at `review/` with `name: fancy` becomes `/my-plugin:fancy`. The recorded GAP resolves to a definite finding: the basename need not equal `name`.

**F15 — Everything else verified.** All five skill budgets, the `CLAUDE.md` 200-line target and 4 MiB skip, the add-an-entry triggers, the arbitrary-contradiction behaviour, the load-at-launch versus load-on-demand split, the four-hop import depth and code-fence skipping, `${CLAUDE_SKILL_DIR}` versus `${CLAUDE_PLUGIN_ROOT}`, `evals/evals.json` and the `skill-creator` plugin, settings precedence and list merging — all confirmed verbatim against the current documentation.

**F16 — The "pass-or-fail check" claim is supported.** `best-practices.md`: "Give Claude a check it can run: tests, a build, a screenshot to compare" and "The check is anything that returns a signal Claude can read in the conversation: a test suite, a build exit code, a linter, a script that diffs output against a fixture". `docs/claude-code-practices.md:109` cites this correctly and needs no change.

**F17 — No section order is prescribed for `CLAUDE.md`.** The documentation states what belongs in the file and that structure should use "markdown headers and bullets to group related instructions", but prescribes no ordering of sections. This settles Q-001 and is the evidence behind FR-007a.

## Decision 1 — the new project-structure document

**Decision**: add `docs/claude-code-project-structure.md`, matching the two existing practice documents in shape: a Contents list, per-section source citations, an "In this repository" paragraph grounding each topic in what this repository actually does, and a "Recorded gaps" section.

Sections: what `.claude/` holds and when each part loads; the instruction-file precedence chain with per-platform paths; `@path` imports; plugin layout and the extend-versus-replace behaviour of each manifest field including F2's exception; the documented size and count budgets gathered in one table; and what this repository's own tree looks like against that.

**Rationale**: FR-001 asks for project structure as its own subject. F1 shows the authoritative source exists and is uncited here. Splitting it out rather than growing `docs/claude-code-practices.md` keeps that document at its current size and gives the new `paths:` rule a single file to point at.

**Alternatives considered**: adding a section to `docs/claude-code-practices.md` — rejected, it is already 127 lines covering seven subjects and structure is a large eighth. Writing it into `CLAUDE.md` — rejected by FR-007a and by the derivability test.

## Decision 2 — corrections to the two existing practice documents

**Decision**: correct F10 (hook list), F4 (brace exemption) and add F3, F5, F6, F8, F9 to `docs/claude-code-practices.md`; correct F11 (description drop mechanism) and F12 (narrow the gap), add F7's eight fields, and promote F14 from GAP to finding, in `docs/skill-authoring-practices.md`.

Each correction is recorded in the existing "Corrections to this repository's earlier records" table style rather than by silently replacing text, per FR-003.

**Rationale**: FR-003 requires the re-check and requires corrections to be recorded. F11 is the one that matters most — a reader reasoning from "descriptions get shortened" would conclude the fix is a shorter description, when the documented behaviour is that an unused skill's description is dropped whole.

**Alternatives considered**: leaving the existing documents alone and recording the deltas only in this file — rejected, `research.md` is a feature artifact and the practice documents are what a contributor reads.

## Decision 3 — the path-scoped authoring rule

**Decision**: add `.claude/rules/repository-docs.md` with

```yaml
---
paths:
  - 'docs/**'
  - 'CLAUDE.md'
---
```

It states the authoring rules — the under-200-line target for the always-loaded file, the three-way choice between always-loaded file, path-scoped rule and skill, the cite-a-source-or-record-a-gap requirement, and the "In this repository" convention — and links to `docs/claude-code-practices.md` and the new structure document for the reasoning, exactly as `.claude/rules/skill-authoring.md:8` does.

**Rationale**: FR-004 and FR-005. The `paths:` key is mandatory here for a documented reason, not stylistic: "Rules without a `paths` field are loaded unconditionally and apply to all files", which would put this content into every session while it sits in a directory named `rules` looking scoped.

**Alternatives considered**: extending `.claude/rules/skill-authoring.md` — rejected, its `paths:` is `skills/**` and widening it would load skill-authoring rules when editing documentation. A single rule file covering both — rejected for the same reason.

**Note on scope**: `AGENTS.md` is deliberately excluded from the globs. FR-006's counterpart in feature 005 (`spec.md:99`) put the shared cross-agent file out of scope, and nothing here changes that.

## Decision 4 — skill reachability and the superseding contract

**Decision**: delete `disable-model-invocation: true` from `skills/ccd-speckit-run/SKILL.md`. Add no `user-invocable` field — its absence is what leaves the skill user-invocable, and `user-invocable: false` would hide it from the `/` menu, the opposite of FR-008. Write `specs/006-claude-code-guidance/contracts/skill-names.md` superseding `specs/005-merge-conflict-resolution/contracts/skill-names.md`, per that contract's own rule that a later feature supersedes rather than edits the number.

New invariant: **zero** of the six skills carry the field.

**Rationale**: FR-008 and FR-009. The safety property the field provided — that a long pipeline does not start on its own — is replaced by a stronger one: Decision 5 gates every phase individually, so reaching the skill automatically cannot cause any phase to run without approval. This is exactly the argument `specs/005-.../contracts/skill-names.md:47` already makes for `ccd-conflict-resolve`: "every mutation the skill makes is already gated on the user's approval... so being reached automatically cannot cause anything to be resolved automatically. The gate is in the workflow, not in the frontmatter."

**Alternatives considered**: keeping the field and finding another route to model reachability — rejected, there is none; the field is the switch. Setting `user-invocable: true` explicitly — rejected, the field's documented purpose is to set `false`, and adding it as `true` restates a default, which Principle V's reasoning treats as noise.

**What does not change**: `ccd-branch-push`, `ccd-commit-push`, `ccd-github-pr` and `ccd-gitlab-mr` must still never carry the field, now on F12's better-founded grounds. Their own SKILL.md warnings stay.

## Decision 5 — per-phase gating

**Decision**: Step 3 keeps drafting all eight prompt arguments together and keeps applying `reference/prompt-rules.md`'s leakage check across them, but presents them as a **plan** rather than taking approval. Before each of Phases 1–8, the run proposes: the command to be invoked, the verbatim argument, the artifacts the phase will write, and what changed since the plan — "nothing changed since the plan" stated explicitly when that is the case. Approval is `AskUserQuestion` with Proceed / Revise / Stop. Revise amends only that phase's argument and re-proposes, under the existing three-revision cap.

**Rationale**: FR-010 through FR-013. The leakage check is the load-bearing half of the old Step 3 and only works with all eight arguments visible at once — a technology leaking from the plan prompt into the specify prompt is invisible when the specify prompt is read alone. Approval is the half that FR-010 moves.

**The click-through objection, and what answers it.** `SKILL.md:140` argues "Twenty prompts trains click-through — worse than two real ones", and that argument is sound about _identical_ repeated gates. FR-013 is the answer: each proposal states what changed since the plan, so an unchanged proposal is visibly unchanged and a revised one is visibly revised. A gate that carries new information each time is a gate that stays read. This is recorded rather than dismissed, because the objection was this repository's own and a future reader deserves to see it answered rather than deleted.

**Alternatives considered**: dropping Step 3 entirely and drafting each argument at its own gate — rejected, it loses the cross-phase leakage check. Keeping the single gate — rejected by FR-010.

## Decision 6 — the subagent concurrency cap

**Decision**: `reference/subagents.md`'s cap becomes **ten concurrent readers in a single batch**, stated as a number in one place. It is a per-batch concurrency cap, not a per-run budget: a run may dispatch several batches and each is bounded independently of how many earlier batches used.

Every hard rule is unchanged: evidence returns and decisions stay in the main run, no writes, no `AskUserQuestion` from an agent, bounded reports, name what was searched. **The Phase 8 prohibition and its full reasoning are kept verbatim.**

**Rationale**: FR-018 and Q-002. A per-run budget would make a later fan-out point's available width depend on how many readers earlier points consumed, which the later point cannot reason about locally and which would silently starve it.

**Why the Phase 8 prohibition is untouched**: its argument is that delegating `tasks.md`'s `[P]` markers reimplements the `implement` command — bypassing its ordering and dependency handling, ticking checkboxes from outside the phase that owns them, racing several writers in one repository, and making `phases.8` record a command that never ran. None of that is a statement about how many agents are permitted, so raising the cap does not touch it. FR-020 restates the prohibition at the specification level.

**Alternatives considered**: ten in total per run — rejected by Q-002. Both caps — rejected, two numbers to keep consistent and two ways for a sweep to be narrowed without the narrowing being visible.

## Decision 7 — conflict detection

**Decision**: add `skills/ccd-speckit-run/scripts/conflict-state.sh`, POSIX `sh`, reading git's own state rather than parsing porcelain prose:

- unmerged paths from `git ls-files -u`
- an interrupted operation from the presence of `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD` or `REVERT_HEAD` under the git dir, and of a `rebase-merge` or `rebase-apply` directory

It prints a `verdict` line of `clean` or `conflicted`, the count of unmerged paths, and the interrupted operation if any. It follows `.claude/rules/shell-scripts.md`: POSIX `sh`, tabs, fail fast, invoked as `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/conflict-state.sh"`.

Run after each step and each phase. Conflicted → dispatch `Skill(skill: "claude-code-devkit:ccd-conflict-resolve")`. Clean → report "checked, clean" and continue. Every verdict is appended to `conflict_checks[]` in the run state.

**Rationale**: FR-014 through FR-017. Reading `MERGE_HEAD` and friends is how git itself decides; `git status` prose is localizable and its wording is not a contract.

**Why the check is cheap enough to run at every boundary**: it is two filesystem tests and one plumbing command, with no network and no working-tree scan.

**Alternatives considered**: parsing `git status --porcelain` for `U` states — rejected, it detects unmerged paths but not an interrupted rebase that has left no conflict in the working tree. Running the check only before Step 6 — rejected by FR-014, and it would let seven phases build on a broken tree.

## Decision 8 — workspace teardown

**Decision**: add **Step 6e** to `reference/ship.md`, entered after 6b returns a review-request URL, and fold the existing 6d into it so there is one teardown question rather than two.

Branch mode offers: switch to the review request's target branch and delete the feature branch; switch to the target and keep the feature branch; stay on the feature branch (**recommended**).

Worktree mode offers: exit, remove the worktree and delete the branch; exit and remove the worktree; exit and keep the worktree; stay in the worktree (**recommended**).

**Rationale**: FR-021 through FR-027. The trigger is review-request creation because that is the latest point at which the pipeline still has the floor — a human merges, and the pipeline is not there when they do.

**Why the least-destructive option is recommended rather than the tidiest.** `ship.md:6c` already argues it: review has not happened, and the branch is most wanted precisely while the review request is open, because a review comment means checking it out again. The user chose the creation-time trigger explicitly with that argument in front of them; the recommendation is where the argument still gets its say.

**The two guards, which are different guards** (see Decision 9, CHK031):

- **Deleting the feature branch** is guarded on its commits being pushed. `git branch -d` refuses an unmerged branch on its own, and that refusal is honoured rather than worked around; `git branch -D` is available only on an explicit request after 6b returned a URL.
- **Removing a worktree** is guarded on the directory having **no uncommitted paths at all**, whatever their origin, because `git worktree remove` discards the whole directory. `git worktree remove --force` is never used.

Neither guard is covered by a skip-approval phrase, per FR-027 and `worktree.md`'s existing "a skip phrase covers approval of proposed content, never a deletion".

Removal remains `ExitWorktree(action: "keep")` followed by `git worktree remove <path>`; `ExitWorktree(action: "remove")` does not apply to a worktree entered by path.

**Alternatives considered**: keeping 6d and adding 6e beside it — rejected, two teardown questions in one run is the click-through failure Decision 5 is trying to avoid. Triggering on merge — rejected, the pipeline has ended by then.

## Decision 9 — the five requirements-quality gaps

**CHK013 — make FR-028 a finite set.** A sweep of the whole repository found **42** statements falsified by this feature's four changes, in two buckets: 34 in live content and 8 in historical records. The list is committed as `contracts/falsified-statements.md` so FR-028 is checkable against an enumeration rather than against "every statement". Verification is a grep, recorded in that contract.

**CHK015 — the criterion separating correction from supersession.** A file under `specs/` that records what a _completed_ feature decided is a historical record: it is superseded by a new record and never edited, because editing it falsifies the account of what that feature actually shipped. Everything else — `CLAUDE.md`, `README.md`, `.claude/rules/`, `docs/`, `skills/` — is live content and is corrected in place. One exception, and it is important: a spec artifact **already marked superseded** is left entirely alone. `specs/002` and `specs/003` carry count-of-five language that is already disclaimed as no longer current; re-superseding it would add noise and no information.

**CHK021 — the conflict workflow reached, conflict survives.** The run **stops**. It records the dispatch and the surviving conflict in `conflict_checks[]`, reports the still-unmerged paths, and does not run the next step or phase. This follows the existing rule that a phase never advances with an unresolved conflict, and it keeps the decision with the user, whose conflict it is. Re-dispatching in a loop is explicitly rejected: the sub-skill already iterates internally, and a second dispatch that finds the same state is a loop, not a retry.

**CHK031 — what "anything uncommitted" counts.** Resolved by splitting the guard, per Decision 8: branch deletion is guarded on unpushed commits, worktree removal on any uncommitted path in that directory regardless of origin. The single ambiguous phrase is replaced by two unambiguous ones. In worktree mode the question is close to moot by construction — the dirty snapshot taken at Step 1c records a fresh worktree as near-empty — but the guard is written to the general case, because checkout mode has no such guarantee.

**CHK039 — replace SC-005.** "At the same rate as before" cannot be measured; no baseline rate was ever recorded, and inventing one now would be a number with no measurement behind it. SC-005 becomes: every phase's argument is drafted before the first phase runs, the leakage check is applied to all eight together, and its result is reported at the plan presentation. That is observable in a single run.

## Recorded gaps

Collected for convenience; each is explained above.

- Whether `disable-model-invocation` affects an explicit `Skill` call originating in another skill. **Narrowed, not closed** — see F12. Two documented passages now bear on it and they disagree.
- Whether the executable bit survives installation or copying. Unchanged; this is why scripts are invoked as `sh <path>`.
- Recursive `@path` import traversal order, beyond the four-hop maximum.
- Whether brace-expanded `paths` patterns count against the 1,000-pattern budget before or after expansion. F4 settles that brace-free patterns are exempt; the expansion-order question is separate and open.
- Precedence between a rule in `.claude/rules/*.md` with no `paths` key and `CLAUDE.md` content, when both load at launch and contradict.
- Any quantification of "measurably reduce adherence" for a `CLAUDE.md` over the 200-line target.
- Whether a description should be phrased in third person, or should state when _not_ to use the skill. This repository does both, by convention rather than by documented advice. Unchanged from feature 005.
