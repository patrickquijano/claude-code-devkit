# Contract: when `ccd-speckit-run` Step 4 asks, and when it does not

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

**Supersedes**: `specs/006-claude-code-guidance/spec.md` FR-010, FR-011 and FR-013, which required a proposal and an approval before **every** phase. Feature 006's specification stays on disk unchanged as the record of what it shipped. **FR-012 of feature 006 is not superseded** and survives verbatim: all eight arguments are still drafted together at Step 3 and still checked across each other for cross-phase leakage.

This contract is the single home of the rule. `SKILL.md` states it briefly and points here; no `reference/` file restates it.

## The decision

Evaluated fresh at each phase and step boundary, in this order. The first `true` decides, and evaluation stops.

1. **Is this boundary in the always-gate set?** → ask.
2. **Is `gate_mode` equal to `every-phase`?** → ask.
3. **Does the verbatim argument differ from Step 3's drafted argument for this phase?** → ask.
4. Otherwise → **proceed without asking, and print why.**

Order matters only for the reason string; the outcome is the boolean OR of the three. The always-gate test is first so that its reason is the one reported, since it is the one that cannot be overridden.

## The always-gate set

Fixed. Membership is a property of the step, never of the run.

| Boundary                           | Why it always gates                                                                |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| Step 1 — workspace and base branch | Creates a working directory, or moves the maintainer's own tree and may stash it   |
| Step 2b — project `CLAUDE.md`      | Writes a committed repository-wide instruction file governing every future session |
| Phase 2 — `specify`                | Cuts the feature branch and creates the spec directory                             |
| Phase 5 — `plan`                   | Fixes the technical approach every later phase and task is built on                |
| Phase 8 — `implement`              | Writes source                                                                      |
| Step 6 — ship                      | Commits, pushes, opens a review request, deletes branches, removes worktrees       |

**A boundary in this set can never compute "do not ask".** No argument comparison, no `gate_mode`, and no maintainer skip-approval phrase reaches it. This is the invariant FR-005 rests on, and it is what preserves the reasoning in `research.md` R9 that keeps `disable-model-invocation` off every skill.

Step 2b keeps the one exception it already had: a verdict of "no change needed" reports and continues without a gate, because changing nothing needs no approval. That is not an override of this contract — the step never reaches a write.

## The auto-proceed set

Phases 1, 3, 4, 6 and 7. Each auto-proceeds **only** when its argument is byte-identical to the Step 3 draft and `gate_mode` is `narrowed`.

Any of these puts the phase back behind a gate:

- The argument was revised after Step 3 for any reason.
- A conflict resolution changed the argument.
- A preceding phase's result changed what this phase will receive.
- The phase is about to be **skipped** rather than run — a skip is still announced under FR-008, but a skip whose reason was not in the Step 3 plan is a difference and therefore gates.

## What is printed when it does not ask

FR-004 forbids silence. Every auto-proceeded boundary prints one line, before the phase runs:

```text
Phase 6 (tasks) — proceeding without asking: argument byte-identical to the approved plan, effect readily undone.
```

The line names the boundary and the reason. A boundary that proceeds with no line is a defect, because it is indistinguishable from a boundary that was forgotten.

## What is still printed when it does ask

Unchanged from feature 006: the four-row proposal — command, verbatim argument, artifacts written, and what changed since the plan — followed by `AskUserQuestion` with `Proceed` / `Revise` / `Stop`. The delta row still says "nothing changed since the plan" explicitly when nothing did.

The delta row survives narrowing for a reason worth stating: under this contract, a gated Phase 3/4/6/7 is gated _precisely because_ something changed, so the row is now the most informative line in the proposal rather than a formality.

## Counting

On a run where nothing is revised and `gate_mode` is `narrowed`, the always-gate set produces **six** approvals — Steps 1, 2b, 6 and Phases 2, 5, 8 — against **thirteen** boundaries. SC-001 requires strictly fewer approvals than phases run; six against eight phases satisfies it.

Under `gate_mode = every-phase`, all thirteen gate, and the run behaves exactly as feature 006 specified.

## Prohibited

- Adding a boundary to the always-gate set without amending this contract.
- Removing one, for any reason short of a superseding contract.
- Inferring `gate_mode` from the conversation instead of reading it from run state.
- Treating an approval given at one boundary as covering a later one.
- Suppressing the FR-004 line to reduce output. The line is the mechanism by which a narrowed gate stays auditable; it is not ceremony, and it is explicitly out of scope for FR-027's compaction.
