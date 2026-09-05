# Contract: update mode

**Feature**: 007-forge-review-request-update
**Applies to**: `skills/ccd-github-pr/SKILL.md` and `skills/ccd-gitlab-mr/SKILL.md`

The behaviour both skills implement identically. Forge-specific commands are in [forge-commands.md](./forge-commands.md); nothing in this file names a command or a flag.

This contract **supersedes**, for these two skills only, the statement in `specs/002-vendor-plugin-skills/` that each forge skill only creates. Where an earlier artifact says a skill stops on finding an existing review request, this contract is the current behaviour.

## C1 — Detection is unconditional

Each skill establishes, at Step 1, every review request whose head is the current branch, in every state. Detection runs after the branch is known to be on the remote and before any question is asked, any candidate list is fetched, or any description is generated.

Detection that cannot run stops the skill with the reason. It is never treated as "no review request exists".

## C2 — Admissibility

A review request is a candidate only when its head branch is the current branch in the repository this run acts on. A same-named branch in a fork or a parent is not a candidate, and no candidate is admitted on a name match alone.

## C3 — Mode selection

- No admissible candidate: `create`.
- Exactly one open candidate: `update` against it. Closed and merged candidates are reported as present and are not offered as alternatives.
- More than one open candidate: the user picks; then `update`.
- No open candidate and exactly one closed: the user chooses between reopening and updating, or leaving it closed and creating. No change is made before the pick.
- No open candidate and more than one closed or merged: the user picks one, then the rule above applies to it.
- All candidates merged: the skill states that a merged review request cannot be reopened on this forge, then `create`.

When more candidates exist than a question can display, the skill states the total found and the number shown.

## C4 — The five fields

In `update` mode a skill may change exactly these: title, description, target branch, reviewers, assignees.

It changes nothing else on an existing review request — not the draft or ready state, not merge options, not labels, not milestone. A question the create path asks whose answer update mode cannot act on is not asked in update mode.

## C5 — The description

The live description is read before anything is proposed. Where it differs from what this run would generate, the difference is shown and the user chooses: leave it, replace it, or append. **Leave it is the default.**

An append writes into a region fenced by a begin marker and an end marker naming the writing skill, both invisible when rendered. Exactly one well-formed pair means that region is replaced. Any other arrangement — one marker alone, more than one pair — means the region was not found: the skill reports what it found and appends a fresh region. It never deletes text it did not write, and never infers a missing boundary.

## C6 — Reviewers and assignees

Naming a reviewer or an assignee adds them. It never removes anyone already present, and never replaces the existing set as a side effect.

Removal is available and is always an explicit choice.

## C7 — The approval gate

Nothing reaches the forge before the user approves.

The summary states which mode the run is in, and lists every field change with its current and its proposed value. A field that would not change is shown as unchanged or named as untouched.

The values presented are the values read during this run. Where the review request changed on the forge between the read and the approval, the skill re-reads, reports the difference, and asks again rather than writing over the newer state.

## C8 — What a blanket skip-approval instruction does not cover

A blanket instruction to skip confirmation never covers:

- replacing a description that already contains content,
- removing a reviewer or an assignee,
- changing the target branch of an existing review request.

Each of these is asked anyway, with the reason the skip was not honoured.

## C9 — Published history

In `update` mode, before bringing the branch up to date with its target, the skill establishes whether the selected candidate carries **review activity**: a submitted review, an approval, or a comment thread anchored to a line of the diff. Conversation comments and comments written by automation are not review activity.

Review activity present: the branch's published history is not rewritten. The skill reports the suppression and its reason, and names at least these alternatives — let the forge report any conflict on the review request itself; merge the target into the branch rather than replaying the branch onto it; rewrite deliberately once the review threads are resolved. The suppression appears in the approval summary.

Review activity absent: the branch is brought up to date exactly as on the create path.

## C10 — No-op

Where no field in C4's set would change, the skill says so and issues no update. Pushing the branch and bringing it up to date are governed by C9 and are unaffected.

## C11 — Permission

Where the user can create a review request but cannot edit the existing one, the skill reports that specifically. It does not present a generic failure, and it does not fall back to creating a second review request without asking.

## C12 — Preserved guarantees

Unchanged by this contract, and checked as part of it:

- every question goes through the structured question mechanism, never prose;
- at most four options per question, at most four questions per call;
- related questions are batched into one call;
- the recommended option comes first, carrying its justification and the cost of not taking it;
- nothing is written to the forge before the approval gate returns yes;
- neither skill switches branch, changes directory, or acts on a working tree other than the one it was invoked in;
- neither skill fabricates a branch, handle, team or label that a live listing did not return.

## C13 — Call budget

The create path's question count is unchanged. Update mode adds at most two calls beyond it: one to pick among several candidates or to decide a closed candidate's fate, and one for the description decision. Neither fires when it has nothing to ask.
