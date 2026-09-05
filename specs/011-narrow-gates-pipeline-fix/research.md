# Phase 0 Research: Approvals, pipeline repair, and the question standard

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

Every decision below was forced by something concrete — a checklist item that showed a requirement was uncheckable, a committed contract that constrains the answer, or a survey of what the repository already does. Decisions are numbered `R<n>` and referenced from `plan.md` and `tasks.md`.

## Contents

- R1 — What "normative content" means, operationally
- R2 — What "shortened" means, numerically
- R3 — How "establishable by comparison" is actually established
- R4 — Where the gate decision lives
- R5 — How the run-level override is remembered
- R6 — Why the pipeline skill composes a report rather than driving the stages
- R7 — Evidence retrieval per forge, and the fallback
- R8 — Where the question standard lives, and what leaves the skills
- R9 — Why `disable-model-invocation` still stays off every skill
- R10 — The count contract, and what supersedes what

---

## R1 — What "normative content" means, operationally

**Problem**: FR-028 requires shortening to "preserve every behavioural rule, constraint, warning, prohibition and recorded rationale". Checklist items CHK004 and CHK013 established that this is a judgement no stated procedure produces, and therefore that FR-028, FR-029 and SC-010 could not be checked by anyone.

**Decision**: a line is **normative** if, after stripping fenced code blocks and YAML frontmatter, it matches any of:

1. A modal obligation token, case-sensitive as written in this repository: `MUST`, `MUST NOT`, `MAY`, `SHOULD`, `SHOULD NOT`.
2. A prohibition or absolute in prose: `never`, `Never`, `always`, `Always`, `only`, `forbidden`, `not optional`, `no exception`, `zero`.
3. A rationale marker: `Rationale:`, `because`, `the reason`, `which is why`, `so that`.
4. A named failure mode or warning: `WARNING`, `defect`, `regression`, `silently`, `breaks`, `fails`, `wrong`.
5. Any line containing a backticked identifier — a path, command, flag, filename, variable or tool name.
6. Any line containing a digit sequence that is a threshold or budget (`500`, `200`, `1,536`, `5,000`, `three`, `ten`).

Additionally, **every fenced code block is normative in its entirety** and is compared byte-for-byte, never reworded.

**Rationale**: the definition has to be mechanical, because the thing it guards against is a human — or a model — deciding under time pressure that a sentence "wasn't really a rule". An over-broad rule is the safe direction of error: it flags lines that did not need preserving, costing a reviewer a glance, whereas an under-broad rule silently loses an invariant that no check in this repository would ever catch again. Categories 3 and 4 exist because of a specific documented failure mode — `CLAUDE.md` and several rule files record _why_ an odd-looking rule exists, precisely so a later contributor does not "fix" it, and that rationale is the first thing a naive compaction deletes as padding.

**Alternatives considered**:

- _Human judgement with a written heuristic_ — rejected. It is what FR-028 already says, and CHK004 exists because it does not work.
- _Preserve only `MUST`/`MUST NOT` lines_ — rejected. It loses categories 3–6 entirely, including every code block and every recorded rationale.
- _Semantic diff by model_ — rejected. Unreproducible between runs, and it makes the audit's verdict depend on the same faculty the audit exists to check.

## R2 — What "shortened" means, numerically

**Problem**: FR-027 says documents "MUST be shortened" and SC-010 says each is "shorter than its previous version". CHK011 and CHK012 established both are satisfied by deleting one character.

**Decision**: a compacted document MUST lose **at least 15% of its non-code, non-frontmatter lines**, measured as lines outside fenced code blocks and outside YAML frontmatter, ignoring blank lines.

A document that cannot reach 15% without losing a line R1 classifies as normative is **exempt**. An exemption is recorded in `tasks.md` and reported at Step 5 with the reason and the percentage actually achieved. An exemption is a legitimate outcome, not a failure — FR-030 already requires this and R2 only supplies the number that triggers it.

**Rationale**: 15% is chosen to be large enough that it cannot be met by whitespace and small enough that it does not force rewriting dense reference text that is already at its information floor. The survey behind this feature found the largest documents are prose-heavy — `ccd-speckit-run/reference/evaluations.md` at 379 lines, `ship.md` at 246, `worktree.md` and `claude-md.md` at 186 — where 15% is comfortable; while the tightest, `constitution.md` at 37 and `tooling.md` at 42, are the ones most likely to claim the exemption, which is the correct outcome for them.

**Alternatives considered**:

- _A token target rather than a line target_ — rejected. No tool in this repository counts tokens, so the criterion would be unmeasurable by the same argument that produced this decision.
- _A fixed absolute target (e.g. "at least 20 lines")_ — rejected. It is trivial for a 379-line file and impossible for a 37-line one.
- _No threshold, reviewer judgement_ — rejected; that is the status quo CHK011 flagged.

## R3 — How "establishable by comparison" is actually established

**Problem**: FR-029 requires that it be establishable that nothing normative was dropped, and named no procedure.

**Decision**: a new review-aid script, `scripts/compaction-audit.sh <git-ref> <path>`, which extracts the R1 normative line set from the document at `<git-ref>` and from the working-tree version, and reports lines present in the former and absent in the latter, plus the R2 percentage. Exit 0 when nothing normative was lost and the threshold is met; non-zero otherwise. Contract: `contracts/compaction-audit-cli.md`.

**It is deliberately NOT wired into `scripts/lint.sh`.** The seven-check gate stays seven checks.

**Rationale**: the audit answers a question that is only meaningful across two versions of one file during one deliberate pass. `lint.sh` answers "is the tree correct right now", runs on every commit, and would have to be given a baseline ref it has no way to choose. Adding it as an eighth check would also create a new content-kind/concern pairing under the constitution's Quality Gate Requirements, obliging a governing configuration file for a concern that exists for the duration of one feature. The plugin's own description says "seven-check quality gate"; keeping it seven means that sentence stays true and `lint-citations.sh` has nothing new to go stale against.

**Alternatives considered**:

- _An eighth `lint.sh` check_ — rejected for the reasons above.
- _A `git diff` convention and a written review instruction_ — rejected. That is a procedure a reviewer must remember to follow correctly; a script is one they run.
- _Bake the check into the `PostToolUse` format hook_ — rejected. That hook rewrites a file after an edit; an audit that blocks or rewrites mid-compaction would fight the very edits it is auditing.

## R4 — Where the gate decision lives

**Decision**: the condition governing whether Step 4 asks is written once, in `contracts/gate-decision.md`, as an ordered evaluation with a fixed always-gate set. `SKILL.md` states the rule briefly and points at the contract; `reference/` files do not restate it.

**Rationale**: feature 006's FR-010–FR-013 were prose spread across `SKILL.md` and its reference files, and this feature is superseding three of them — which required a survey to even locate. A single contract makes the next supersession a one-file change, and makes it possible for `speckit-analyze` to check the rule against `tasks.md` rather than against paraphrases.

## R5 — How the run-level override is remembered

**Decision**: FR-007's override is a run-level mode, offered at Step 3 with the plan and recorded in `.specify/.speckit-run-state.json` as `gate_mode`, valued `narrowed` (default) or `every-phase`. Read before each phase; never inferred from the conversation.

**Rationale**: the state file exists because only the first 5,000 tokens of a skill survive compaction and a run spans many turns. An override held only in conversation is exactly the class of fact the state file was created to hold — and a run that forgot it would silently revert to narrowed gating, which is the failure mode this feature must not introduce. `gate_mode` is per run and not per phase because a maintainer asking to be consulted on everything is making a statement about the run, and offering the choice again at each phase would reintroduce the ceremony the feature removes.

## R6 — Why the pipeline skill composes a report rather than driving the stages

**Decision**: `ccd-pipeline-fix` gathers evidence, proposes a root cause, takes the maintainer's choice of approach, composes a bug report carrying all three, and dispatches `claude-code-devkit:ccd-speckit-bug-run`. It never invokes `speckit-bug-assess`, `speckit-bug-fix` or `speckit-bug-test` directly.

**Rationale**: `.claude/rules/spec-kit-bug-workflow.md` governs those three stages — the closed outcome vocabularies, the `bug-outcome.sh` extraction contract, the `partial` handling, the uncapped loop-back, the byte-identical report rule. Dispatching the stages directly would mean reimplementing all of it in a second place, and the rule's own text says a fork is the regression. Dispatching the wrapper gets the whole of that governance, plus its commit and review-request steps, for one `Skill` call.

The consequence worth stating: the root cause and approach chosen in the pipeline skill travel **as report content**, not as arguments to a stage. `reference/stages.md` is explicit that Stages 2 and 3 receive nothing but the slug, and that restating assessment content in an argument duplicates a file the stage is about to read.

**Alternatives considered**:

- _Dispatch the three stages directly_ — rejected as above.
- _Extend `ccd-speckit-bug-run` with a pipeline mode_ — rejected. It would put forge-specific log retrieval inside a skill whose scope is defect remediation, and FR-014's "MUST NOT duplicate that workflow's stages" is satisfied more cleanly by a caller than by a mode flag.

## R7 — Evidence retrieval per forge, and the fallback

**Decision**: GitHub uses `gh run list`, `gh run view <id>` and `gh run view <id> --log-failed`; GitLab uses `glab ci list`, `glab ci get` and `glab ci trace`. The forge comes from the shared `forge-detect.sh`, never re-detected. Availability is probed at preflight and the chosen path is announced before the run begins (FR-011c). Absent, unauthenticated or failing CLI degrades to asking the maintainer to paste the failing output (FR-011b), which is a reported skip of the retrieval path and not a failure of the run.

Each forge's rule is written in its own vocabulary and in its own section, per `.claude/rules/forge-review-requests.md`'s standing prohibition on one instruction covering both.

**Rationale**: this mirrors what the repository already does for review requests, including the "a missing CLI is a reported skip" pattern that `ccd-speckit-run`'s Step 6b established. The prohibition on cross-forge instructions is not stylistic: the rule records that `gh` and `glab` disagree on the shape of every operation, and that the wrong one _succeeds_ rather than erroring.

**Alternatives considered**:

- _A forge REST API called directly_ — rejected. It would need a credential the maintainer does not currently supply, contradicting FR-011a's "no additional credential".
- _Require the maintainer to paste logs always_ — rejected at Phase 3 by the maintainer's clarification.

## R8 — Where the question standard lives, and what leaves the skills

**Decision**: the contract goes in `.claude/rules/skill-authoring.md`, which is already path-scoped to `skills/**` and already holds the naming, dispatch, bundled-file and budget rules. The four skills currently carrying _"Every question in this skill goes through `AskUserQuestion`. Never ask in prose, never wait on an untooled 'confirm?'."_ lose that sentence.

**Rationale**: `.claude/rules/repository-docs.md` states that recording the same rule in two places is worse than recording it in neither, because instruction files concatenate rather than override and nothing catches the drift. Four copies of a sentence that is about to become repository-wide is four drift sites. Removing them is not a loss of emphasis; it is the mechanism the rule prescribes.

**Alternatives considered**:

- _A new `.claude/rules/asking-questions.md`_ — rejected. It would need `paths: skills/**`, identical to `skill-authoring.md`'s, and two rule files loading on the same glob is the duplication the same rule forbids.
- _Leave the four sentences and add the rule_ — rejected for the drift reason above.

## R9 — Why `disable-model-invocation` still stays off every skill

**Decision**: no skill gains the field, including the new one. `ccd-speckit-run` keeps it off.

**Rationale**: `skills/ccd-speckit-run/SKILL.md` and `specs/006-claude-code-guidance/contracts/skill-names.md` both record that the field's absence was justified by the per-phase gates, and that removing the gates would revive the argument for restoring it — "the two are a pair". **This feature narrows the gates rather than removing them**, and the property the pairing actually depended on survives intact: the workflow still cannot reach implementation, or any irreversible step, without an explicit approval for that step (FR-005). A skill that engages on its own still cannot _do_ anything on its own, which is what the original argument was about.

The new skill is in the same position for the same reason: every stage it reaches is gated by the workflow it dispatches, and its own root-cause and approach approvals precede any change.

This decision discharges FR-034, and it is recorded here rather than only in a contract because the reasoning — not the conclusion — is what a future feature will need.

## R10 — The count contract, and what supersedes what

**Decision**: `contracts/skill-names.md` in this feature supersedes `specs/010-bug-run-ship/contracts/skill-names.md`, recording **eight** skills, all `ccd-`-prefixed, none carrying `disable-model-invocation`, and the widened dispatch set. Feature 006's FR-010, FR-011 and FR-013 are recorded as superseded by this feature's FR-001–FR-005; FR-012 is recorded as surviving unchanged. Feature 006's spec stays on disk untouched.

**Rationale**: this is the pattern the repository has used four times — 003 superseded 002's contracts, 005 superseded 003's, 009 superseded 006's, 010 superseded 009's — and `CLAUDE.md` records that the reason each supersession happened was a live pointer citing a stale contract. Two live pointers cite 010's count today; both must move.

**The `plugin.json` bump is 0.4.0 → 0.5.0, minor.** `CLAUDE.md` requires a bump in any feature that changes `skills/`, minor for a behaviour change. This feature changes behaviour in every skill. Feature 008 caught a stale cached copy being served silently under an unchanged version, which is why this is not optional.
