# Data model: Update an existing review request instead of refusing

**Feature**: 007-forge-review-request-update
**Date**: 2026-09-05

Nothing here is stored. These are the values a run holds while it is running, and the states it moves between. They are written down because the two skills must agree on them and because `evaluations.md` is checked against them.

## Entities

### Candidate

A review request the forge returned for the current branch, whose head is that branch.

- **identifier** — the number on GitHub, the internal id on GitLab. Displayed to the user; passed to the update command.
- **url** — the web address. Reported at the end of the run whether the run created or updated.
- **state** — one of `open`, `closed`, `merged`.
- **target** — the branch it merges into. Displayed when there is a choice to make, because two candidates from one branch differ only by this.
- **title** — displayed when there is a choice to make.
- **is_cross_repository** — GitHub only. True when the head lives in a fork. Used to reject candidates whose head branch merely shares a name, per FR-003.
- **head_owner** — GitHub only. The owner of the repository the head branch lives in.

A candidate is admissible only when its head is the current branch **in the repository this run is acting on**. A same-named branch in a fork or parent is not a candidate.

### Mode

Which path the run takes. Derived at Step 1, read at Steps 4, 5, 7, 8 and 9.

- `create` — no admissible candidate, or the user chose to open a fresh one.
- `update` — an admissible candidate was selected.

There is no third mode. Reopening is an action taken before entering `update`, not a mode of its own.

### Field change

One proposed difference, presented for approval.

- **field** — one of `title`, `description`, `target`, `reviewers`, `assignees`. This list is closed; FR-012 fixes it.
- **current** — the value read from the forge during this run.
- **proposed** — the value this run would set.
- **operation** — for `reviewers` and `assignees`, one of `add` or `remove`; for the other three, `replace`.

A field whose current and proposed values are equal produces no field change. A run with no field changes reports that and issues no update, per FR-019.

### Review activity

Evidence that suppresses rewriting the branch's published history.

- Present when the candidate carries a submitted review, an approval, or a comment thread anchored to a line of the diff.
- Absent when the candidate carries only conversation comments, or comments written by automation, or nothing.

Read once, in `update` mode, before Step 5 decides whether to rebase.

### Description region

The part of a description this feature may replace.

- **fence** — a begin marker and an end marker, both HTML comments naming the writing skill.
- **well-formed** — exactly one begin marker and exactly one end marker, begin before end.
- Any other arrangement — one marker alone, or more than one pair — is **not found**, and the run appends a fresh region rather than inferring a boundary. It never deletes a region it did not write.

## State transitions

### Selecting a mode

```text
detect candidates for the current branch, all states
│
├─ none admissible ─────────────────────────────► mode = create
│
├─ exactly one open ────────────────────────────► mode = update, against it
│                                                  (other closed/merged ones reported, not offered)
│
├─ more than one open ──────────────────────────► ask which ──► mode = update, against the pick
│
├─ none open, exactly one closed ───────────────► ask: reopen and update, or leave and create
│                                                  ├─ reopen ──► reopen it ──► mode = update
│                                                  └─ leave ───► mode = create
│
├─ none open, more than one closed or merged ───► ask which ──► then as the single case above
│
└─ none open or closed, all merged ─────────────► report that merged cannot be reopened
                                                   ──► mode = create
```

### The description, in update mode

```text
read the live description
│
├─ identical to what this run would generate ──► no field change
│
└─ differs ──► show the difference, ask:
               ├─ leave it              (default) ──► no field change
               ├─ replace it                      ──► field change, operation = replace
               └─ append                          ──► locate this skill's fence
                                                      ├─ well-formed pair ──► replace that region only
                                                      └─ anything else ────► append a fresh region
```

A blanket skip-approval instruction does not reach this question when the live description is non-empty, per FR-020.

### The rebase, in update mode

```text
read review activity on the selected candidate
│
├─ present ──► do not rebase, do not force-push
│              report the suppression, the reason, and the alternatives FR-022 names
│              carry both into the approval summary
│
└─ absent ──► rebase and force-push exactly as the create path does
```

## Validation rules

- A candidate whose head is not the current branch is rejected before it reaches any question (FR-003).
- Detection is not bounded by time or count (FR-010a).
- The values shown at approval are the values read this run; a candidate that changed underneath is re-read and re-approved, not overwritten (FR-012b).
- `add` on `reviewers` or `assignees` never removes anyone already present (FR-016); `remove` is reachable only as an explicit choice (FR-017).
- Nothing outside the five fields is written to an existing review request (FR-018).
- The target branch defaults to the candidate's existing target (FR-018a).
