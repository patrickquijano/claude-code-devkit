# Contract: statements this feature renders untrue

**Feature**: 006-claude-code-guidance | **Date**: 2026-09-05

FR-028 requires that every statement in this repository which this feature renders untrue is corrected as part of this feature. As written that is an obligation nobody can prove was met — CHK013. This contract makes it finite: **42 statements**, enumerated below, each with its location, its cause, and its bucket.

FR-028 is satisfied when every `live` row is corrected and every `record` row is superseded. It is checked against this list, not against a search of the whole repository.

## The four changes

|       | Change                                                                                                                                                                                                            |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A** | `disable-model-invocation: true` is deleted from `skills/ccd-speckit-run/SKILL.md`. Zero of the six skills then carry it                                                                                          |
| **B** | `ccd-speckit-run` dispatches `claude-code-devkit:ccd-conflict-resolve`, conditionally, at every step and phase boundary. Previously nothing dispatched it                                                         |
| **C** | Each phase is proposed and approved on its own. Previously one approval at Step 3 covered all eight and phases then ran without stopping                                                                          |
| **D** | The subagent cap becomes ten concurrent per batch and new fan-out points may be added. Previously the documentation named exactly two fan-out points and called them "the only two", with batches of four and two |

## The criterion (CHK015)

```text
live   → corrected in place
record → superseded by a new record, never edited
         └─ unless ALREADY marked superseded → left entirely alone
```

A file under `specs/` recording what a **completed** feature decided is a `record`: editing it would falsify the account of what that feature actually shipped. Everything outside `specs/` is `live`.

## Bucket: live content — 34 statements, corrected in place

### `CLAUDE.md`

| #   | Location       | Statement                                                                                                                   | Cause |
| --- | -------------- | --------------------------------------------------------------------------------------------------------------------------- | ----- |
| 1   | `CLAUDE.md:13` | "`ccd-conflict-resolve` is dispatched by nothing"                                                                           | B     |
| 2   | `CLAUDE.md:20` | "Only `ccd-speckit-run` carries `disable-model-invocation`. Adding it to the other five breaks Step 6's dispatch silently." | A     |

Both are corrected in place. **No other line of `CLAUDE.md` is touched and its section order is unchanged**, per FR-007a.

### `README.md`

| #   | Location       | Statement                                                                                                                                                                      | Cause |
| --- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| 3   | `README.md:66` | "It asks before anything irreversible — where the run happens, which branch to base it on, what the eight phase prompts will say, and whether to commit and open the request." | C     |

Borderline and included deliberately: it does not say "in one batch", but it lists the phase-prompt review as a single item alongside the Step 1 questions, which is true only of the old design.

### `.claude/rules/skill-authoring.md`

| #   | Location | Statement                                                                            | Cause |
| --- | -------- | ------------------------------------------------------------------------------------ | ----- |
| 4   | `:17-19` | "Exactly one skill carries `disable-model-invocation`, and it is `ccd-speckit-run`." | A     |

### `docs/skill-authoring-practices.md`

| #   | Location | Statement                                                                                                                                  | Cause                                          |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| 5   | `:61`    | "exactly one of six skills carries it, and it is `ccd-speckit-run` — the entry point a user invokes, which dispatches three of the others" | A (the count) and B (the "three" becomes four) |
| 6   | `:63`    | "`ccd-conflict-resolve` omits the field for a different reason: nothing dispatches it, so the ambiguity does not arise"                    | B                                              |

### `skills/ccd-speckit-run/SKILL.md`

| #   | Location   | Statement                                                                                                                           | Cause |
| --- | ---------- | ----------------------------------------------------------------------------------------------------------------------------------- | ----- |
| 7   | `:4`       | the `disable-model-invocation: true` frontmatter field itself                                                                       | A     |
| 8   | `:11`      | "Phases run start to finish without stopping — every prompt was reviewed at Step 3, so there is nothing left to approve per phase." | C     |
| 9   | `:34`      | checklist: "Step 3: eight phase prompts drafted, prompt-review gate passed"                                                         | C     |
| 10  | `:37`      | checklist: "Proposals: Step 1 and Step 6 each proposed and approved before executing"                                               | C     |
| 11  | `:67`      | reference-map row: "the two fan-out points"                                                                                         | D     |
| 12  | `:114`     | "the first of two fan-out points: up to four independent read-only sweeps"                                                          | D     |
| 13  | `:134`     | "Present all eight in one block, get approval at the **prompt-review gate**."                                                       | C     |
| 14  | `:138`     | "This is the run's one review of what the phases will do. Phases 1–8 then execute without stopping"                                 | C     |
| 15  | `:140`     | "Gates work only while still read. Twenty prompts trains click-through — worse than two real ones."                                 | C     |
| 16  | `:142-144` | "Step 4 — Execute Phases 1–8. This order, straight through. No proposal before a phase, no gate after one"                          | C     |
| 17  | `:163`     | "Phases 1–8 write only inside the repo's spec directory ... so they do not propose."                                                | C     |
| 18  | `:172`     | "continue straight to the next phase. No question"                                                                                  | C     |
| 19  | `:217`     | "Phases were not gated, so the last column is `done` ... not a decision the user made."                                             | C     |
| 20  | `:235`     | red-flag premise: "Phases are not gated, so nothing should stop"                                                                    | C     |
| 21  | `:264`     | "This skill carries the field because it is the entry point a user invokes"                                                         | A     |
| 22  | `:266`     | "the asymmetry between this skill's frontmatter and the four companions' is deliberate"                                             | A     |

Item 15 is not deleted. The click-through argument was correct about identical repeated gates and is preserved as a rewritten paragraph, answered by the delta requirement in FR-013 — see `research.md` Decision 5. Deleting an argument this repository made against its own new design would leave a future reader unable to see that it was considered.

### `skills/ccd-speckit-run/reference/subagents.md`

| #   | Location | Statement                                                                         | Cause |
| --- | -------- | --------------------------------------------------------------------------------- | ----- |
| 23  | `:34`    | "Two fan-out points in the whole run are named below, and they are the only two." | D     |
| 24  | `:61`    | "Up to four independent sweeps, dispatched in **one** batch"                      | D     |

### `skills/ccd-speckit-run/reference/evaluations.md`

| #   | Location | Statement                                                                                             | Cause |
| --- | -------- | ----------------------------------------------------------------------------------------------------- | ----- |
| 25  | `:32`    | "It does **not** ask before writing — Step 3 approved that prompt."                                   | C     |
| 26  | `:36`    | "Phases 1–8 run start to finish with no `AskUserQuestion` between them."                              | C     |
| 27  | `:38`    | "A run that treats 'no gates on Step 4' as 'never stop during Step 4' fails this variant"             | C     |
| 28  | `:54`    | "This question survives the removal of the per-phase gates: phases run unattended, conflicts do not." | C     |
| 29  | `:250`   | "Up to four sweeps dispatched in **one** batch"                                                       | D     |
| 30  | `:341`   | "either fan-out point"                                                                                | D     |

### Other reference files

| #   | Location                       | Statement                                                                                     | Cause |
| --- | ------------------------------ | --------------------------------------------------------------------------------------------- | ----- |
| 31  | `reference/constitution.md:17` | "Phase 1 is not gated — the constitution prompt was approved at Step 3 with the other seven." | C     |
| 32  | `reference/run-state.md:118`   | "Phases are not gated — `phases.N` is written when the phase finishes"                        | C     |
| 33  | `reference/tooling.md:42`      | "It names ... the **two** points in the run that fan out"                                     | D     |

### `skills/ccd-conflict-resolve/SKILL.md`

| #   | Location | Statement                                                                                                                                                    | Cause |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----- |
| 34  | `:194`   | "The plugin's count of exactly one skill carrying that field ... is a committed contract at `specs/005-merge-conflict-resolution/contracts/skill-names.md`." | A     |

Corrected to point at this feature's contract and to state the count of zero.

## Bucket: historical records — 8 statements, superseded not edited

All eight are in `specs/005-merge-conflict-resolution/`, the most recent not-yet-superseded record. **None of these files is edited.** [`contracts/skill-names.md`](./skill-names.md) supersedes the contract; the `research.md` entry is a record of what feature 005's research concluded and remains accurate as that.

| #   | Location                                              | Statement                                                                     | Cause |
| --- | ----------------------------------------------------- | ----------------------------------------------------------------------------- | ----- |
| 35  | `contracts/skill-names.md:13`                         | table row: `ccd-speckit-run` reachable by "a user only"                       | A     |
| 36  | `contracts/skill-names.md:24`                         | "`ccd-speckit-run` is reachable by a user and not by automatic invocation."   | A     |
| 37  | `contracts/skill-names.md:25`                         | "Exactly one of the six carries `disable-model-invocation: true`"             | A     |
| 38  | `contracts/skill-names.md:47`                         | "Nothing dispatches it, so the ambiguity above does not arise."               | B     |
| 39  | `contracts/skill-names.md:49`                         | "The asymmetry across the six is therefore now threefold"                     | A     |
| 40  | `contracts/skill-names.md:73-77`                      | verification script expecting exactly one match                               | A     |
| 41  | `contracts/skill-names.md:87`                         | "`disable-model-invocation` ... being removed from it" listed as a regression | A     |
| 42  | `specs/005-merge-conflict-resolution/research.md:138` | "a normalising pass would break Step 6's dispatch silently"                   | A     |

## Deliberately excluded, with reasons

These were found by the sweep and are **not** in the enumeration. Recorded so a later reader can tell an exclusion from an omission.

- **`specs/002-vendor-plugin-skills/` and `specs/003-ccd-skill-rename/`** carry count-of-five language throughout, but both are **already marked superseded** with disclaimers stating the count is no longer current. Re-superseding adds noise and no information.
- **`specs/001-quality-gate-plugin/` and `specs/004-format-hook-scope/`** — every "exactly one" and "count of" hit concerns one governing configuration per content kind, unrelated to skills, dispatch, gating or fan-out.
- **`specs/006-claude-code-guidance/`** is this feature. Its requirements describe the target state; they become true on implementation rather than false.
- **`ccd-branch-push`, `ccd-commit-push`, `ccd-github-pr`, `ccd-gitlab-mr`** each warn "Never add `disable-model-invocation: true` to this skill". Still true, and more firmly so — see `contracts/skill-names.md`. Their internal "Step 3" references are their own numbering, unrelated to `ccd-speckit-run`'s.
- **`docs/claude-code-practices.md`, `docs/merge-conflict-practices.md`, `AGENTS.md`, `.claude-plugin/*.json`, `.claude/rules/shell-scripts.md`** — read in full, no statement touching A, B, C or D.

`docs/claude-code-practices.md` **is** modified by this feature, but under FR-003 — the documentation re-check — not under FR-028. Different obligation, different reason.

## Verification

```sh
# A: no skill carries the field.
grep -rln 'disable-model-invocation' skills/*/SKILL.md
# expect: no output

# B: the claim that nothing dispatches ccd-conflict-resolve is gone from live content.
# Scoped to that skill deliberately. A bare 'dispatched by nothing' also matches a TRUE
# sentence about ccd-speckit-run, which nothing does dispatch, and a grep that flags correct
# prose gets ignored the second time it fires.
grep -rn 'ccd-conflict-resolve` is dispatched by nothing' CLAUDE.md README.md docs/ .claude/rules/ skills/
grep -rn 'omits the field for a different reason: nothing dispatches it' docs/ skills/
# expect: no output from either

# C: the not-gated claims are gone from live content.
grep -rn 'without stopping\|Phases are not gated\|no gate after one\|the run.s one review' skills/ CLAUDE.md README.md
# expect: no output

# D: the two-fan-out-point claim is gone.
grep -rn 'two fan-out\|they are the only two\|up to four independent sweeps' skills/
# expect: no output

# The record bucket is untouched.
git diff --name-only main -- specs/005-merge-conflict-resolution/
# expect: no output
```

The last check is the one that matters most and is easiest to fail by accident: a global find-and-replace of "exactly one" would edit the superseded contract, which is precisely what FR-029 forbids.
