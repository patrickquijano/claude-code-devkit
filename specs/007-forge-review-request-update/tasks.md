---
description: 'Task list for feature implementation'
---

# Tasks: Update an existing review request instead of refusing

**Input**: Design documents from `/specs/007-forge-review-request-update/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md — all present

**Tests**: The repository has no test runner. Its regression instrument is each skill's `evaluations.md`, and its check is `scripts/lint.sh`. Tasks that write evaluation scenarios are therefore the test tasks, and they sit inside the story whose behaviour they cover.

**Organization**: Tasks are grouped by user story. Two files — `skills/ccd-github-pr/SKILL.md` and `skills/ccd-gitlab-mr/SKILL.md` — are touched by every story, so within a story the two skills are parallel with each other and across stories they are not.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on an incomplete task
- **[Story]**: Which user story the task belongs to
- Every task names its exact file path

## Path Conventions

Repository root. Skills under `skills/<name>/`, documentation under `docs/`, path-scoped agent rules under `.claude/rules/`. There is no `src/` and no `tests/`.

---

## Phase 1: Setup

**Purpose**: Establish the baseline the change is measured against.

- [x] T001 Run `scripts/lint.sh` from the repository root and record that it passes before any edit, so a later failure is attributable to this feature
- [x] T002 [P] Record the current line counts of `skills/ccd-github-pr/SKILL.md` and `skills/ccd-gitlab-mr/SKILL.md` against the 500-line budget, so the budget can be checked after the edits rather than discovered at review

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The written source both skills' edits quote. Every later phase cites these two files rather than restating what `gh` and `glab` do, so both must exist before any skill text claims a command's behaviour.

**⚠️ CRITICAL**: No story phase may state a forge command's behaviour that is not first recorded in `docs/forge-review-requests.md`.

- [x] T003 Create `docs/forge-review-requests.md` in the house style of the existing `docs/*-practices.md` files — a Contents list, topic headings, a Recorded gaps section, sources cited by URL — covering: detecting an existing review request on each forge, updating one, the reviewer and assignee asymmetry, description replacement being unconditional, draft state, reopen and what merged forecloses, duplicate rejection, permissions and scopes, and the MCP fallback's inverted `merge_request_iid` rule. State the verified versions `gh` 2.100.0 and `glab` 1.116.0 once at the top per FR-026, and state each forge difference in one place naming both forges per FR-027
- [x] T004 Create `.claude/rules/forge-review-requests.md` with `paths:` frontmatter listing `skills/ccd-github-pr/**` and `skills/ccd-gitlab-mr/**`, matching the shape of `.claude/rules/skill-authoring.md`, carrying the short imperative rules only and citing `docs/forge-review-requests.md` for the reasoning rather than repeating it (depends on T003)

**Checkpoint**: the two skills can now be edited against a written source.

---

## Phase 3: User Story 1 — Re-running after amending the branch (Priority: P1) 🎯 MVP

**Goal**: A second run against a branch that already has one open review request updates it rather than stopping.

**Independent Test**: On a branch with exactly one open review request, the run reaches an approval summary describing an update; approving leaves the identifier and the comment history intact and creates no second review request.

- [x] T005 [P] [US1] In `skills/ccd-github-pr/SKILL.md` Step 1, widen the existing detection call to `gh pr list --head <branch> --state all --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author`, and replace the stop-on-existing-PR outcome with mode selection per contract C1 and C3. Record the head-qualification trap: `--head` does not accept `owner:branch`, so a fork is separated by post-filtering `isCrossRepository` and the head owner. State the ordering and the absence of a bound per FR-010a — detection runs after the branch is known to be on the remote and before any question, candidate fetch or description generation, and is not limited to a time window or a number of recent PRs. State per FR-004 that a detection call which fails for any reason stops the run with that reason and is never read as "no PR exists"
- [x] T006 [P] [US1] In `skills/ccd-gitlab-mr/SKILL.md` Step 1, widen the existing detection call to `glab mr list --source-branch <branch> --all --output json`, and replace the stop-on-existing-MR outcome with the same mode selection per C1 and C3. Add the GitLab half of the admissibility rule per FR-003: `glab mr list` searches the current project only, so an MR whose source project is a fork must be rejected on its source project rather than admitted on a source-branch name match. Carry the same FR-010a ordering and no-bound statement and the same FR-004 failure rule as T005
- [x] T007 [US1] In `skills/ccd-github-pr/SKILL.md` Step 9, add the update branch: `gh pr edit <number>` carrying only the flags whose field changed, `--body-file` never an inline `--body`, and the head branch documented as uneditable. Report the same URL shape as the create branch (depends on T005)
- [x] T008 [US1] In `skills/ccd-gitlab-mr/SKILL.md` Step 9, add the update branch: `glab mr update <iid> --yes`, `--description-file` never an inline argument, plus the MCP fallback's inverted rule — `merge_request_iid` supplied for an update, omitted for a create — with the note that each direction fails silently into the other (depends on T006)
- [x] T009 [P] [US1] In `skills/ccd-github-pr/SKILL.md` Step 8, make the approval summary state the mode and list every field change with current and proposed values, and add the re-read requirement for a review request that changed between the read and the approval, per C7
- [x] T010 [P] [US1] In `skills/ccd-gitlab-mr/SKILL.md` Step 8, make the same two changes per C7
- [x] T011 [P] [US1] In `skills/ccd-github-pr/SKILL.md`, fix the three statements FR-029 names: the "When NOT to use" bullet saying it does not update existing PRs, the Boundaries line "Only creates PRs; never edits, reviews, merges, or closes existing ones", and the Step 1 stop reason "since this skill only creates PRs". Restate each as the update behaviour, keeping the boundaries that still hold — it still never reviews, merges or closes
- [x] T012 [P] [US1] In `skills/ccd-gitlab-mr/SKILL.md`, fix the same three statements
- [x] T011a [P] [US1] In `skills/ccd-github-pr/SKILL.md` Steps 4 and 9, write the reviewer and assignee rule per C6 and FR-016 and FR-017: naming a reviewer or an assignee **adds** them and never removes anyone already present. On GitHub this is `--add-reviewer` and `--add-assignee`; `--remove-reviewer` and `--remove-assignee` are issued only on an explicit removal, which is always the user's choice and never a consequence of naming a different set
- [x] T011b [P] [US1] In `skills/ccd-gitlab-mr/SKILL.md` Steps 4 and 9, write the same rule with GitLab's flag semantics, which are the opposite shape and are the sharpest trap in this feature: `glab mr update --reviewer a,b` **replaces the whole reviewer set**. Adding requires a `+` prefix per username and removing requires `-` or `!`. State this as a hard rule with the consequence named — an instruction phrased "add the reviewer" without the prefix silently strips every existing reviewer — and state the same for `--assignee`
- [x] T011c [P] [US1] In `skills/ccd-github-pr/SKILL.md`, write the field boundary per C4 and FR-018 and FR-018a: in update mode the skill changes exactly title, description, target branch, reviewers and assignees, and nothing else — not draft state, not merge options, not labels, not milestone. A create-path question whose answer update mode cannot act on is not asked in update mode. The target branch defaults to the value the existing PR already holds, and a differing selection appears in the Step 8 summary as a change with both values rather than being applied on the strength of the selection. Add the no-op rule per FR-019: when no field in that set would change, say so and issue no edit, noting that pushing and bringing the branch up to date are governed separately
- [x] T011d [P] [US1] In `skills/ccd-gitlab-mr/SKILL.md`, write the same field boundary, target-branch default and no-op rule. On GitLab, note specifically that `--draft`, `--ready`, `--squash-before-merge` and `--remove-source-branch` are available on `glab mr update` and are deliberately not used in update mode — the flag existing is not a reason to pass it
- [x] T013 [US1] In `skills/ccd-github-pr/evaluations.md`, rewrite E2 from "the run stops" to the update path: detection finds `#42`, the run continues in update mode, Step 8 shows a field-by-field summary, and after approval `#42` carries the new values with no second PR. Remove the assertion that no attempt is made to edit it (depends on T005, T007, T009)
- [x] T014 [US1] In `skills/ccd-gitlab-mr/evaluations.md`, rewrite E2 the same way for `!42` (depends on T006, T008, T010)

**Checkpoint**: the feature's primary failure is fixed and independently testable.

---

## Phase 4: User Story 2 — The description survives (Priority: P1)

**Goal**: No description content a person wrote is lost on a run where the user did not choose to replace it.

**Independent Test**: Put a hand-written paragraph and a ticked checklist item in an existing review request's description, run the skill, approve; both are still there.

- [x] T015 [P] [US2] In `skills/ccd-github-pr/SKILL.md` Step 7, add the description decision per C5: read the live body, diff it against the generated one, and offer leave / replace / append with **leave as the default**. State that `--body` and `--body-file` replace outright and that there is no append mode on the forge
- [x] T016 [P] [US2] In `skills/ccd-gitlab-mr/SKILL.md` Step 7, add the same decision, stating the same about `--description` and `--description-file`
- [x] T017 [P] [US2] In `skills/ccd-github-pr/SKILL.md`, specify the append fence: a begin and an end HTML comment naming the skill, invisible when rendered; exactly one well-formed pair means replace that region; one marker alone or more than one pair means not-found, report what was found and append fresh, never infer a boundary and never delete a region the skill did not write
- [x] T018 [P] [US2] In `skills/ccd-gitlab-mr/SKILL.md`, specify the same fence with its own skill name in the markers
- [x] T019 [P] [US2] In `skills/ccd-github-pr/SKILL.md` Step 0, narrow the skip-approval rule per C8 so it never covers replacing a non-empty description, removing a reviewer or assignee, or changing the target branch, and so it says why the skip was not honoured
- [x] T020 [P] [US2] In `skills/ccd-gitlab-mr/SKILL.md` Step 0, narrow the same rule
- [x] T021 [US2] In `skills/ccd-github-pr/evaluations.md`, add E7 — an existing PR whose body carries a hand-written paragraph and a ticked checklist item; expect the diff shown, leave-it defaulted, the paragraph and tick intact, and on a second run choosing append, one region replaced rather than two accumulated (depends on T015, T017)
- [x] T022 [US2] In `skills/ccd-gitlab-mr/evaluations.md`, add the equivalent E7 (depends on T016, T018)

**Checkpoint**: the only irreversible loss this feature can cause is guarded.

---

## Phase 5: User Story 3 — A review request that is not open (Priority: P2)

**Goal**: Closed and merged candidates each reach a stated outcome and neither is chosen silently.

**Independent Test**: Close a review request and re-run — both options offered. Merge one and re-run — reopening declared impossible, then the create path.

- [x] T023 [P] [US3] In `skills/ccd-github-pr/SKILL.md` Step 1, add the closed and merged branches per C3: a single closed candidate offers reopen-and-update via `gh pr reopen` or leave-and-create; all-merged states that GitHub treats merge as terminal and continues to create
- [x] T024 [P] [US3] In `skills/ccd-gitlab-mr/SKILL.md` Step 1, add the same two branches using `glab mr reopen`, citing `gitlab-org/gitlab#9428` for why a merged merge request cannot be reopened
- [x] T025 [P] [US3] In `skills/ccd-github-pr/SKILL.md`, add the permission rule per C11 — able to create but not to edit is reported specifically and never falls back to creating a second PR without asking
- [x] T026 [P] [US3] In `skills/ccd-gitlab-mr/SKILL.md`, add the same rule, naming the GitLab-specific cause: the Developer role is required regardless of token scope, so a Reporter with a full `api` scope is still refused
- [x] T027 [US3] In `skills/ccd-github-pr/evaluations.md`, add E8 covering the closed and the merged branch, including that no change is made before the pick (depends on T023)
- [x] T028 [US3] In `skills/ccd-gitlab-mr/evaluations.md`, add the equivalent E8 (depends on T024)

---

## Phase 6: User Story 4 — Several candidates (Priority: P2)

**Goal**: More than one candidate is presented, never chosen for the user.

**Independent Test**: Two review requests for one branch; both listed with identifier, state, target and title, and nothing written before a pick.

- [x] T029 [P] [US4] In `skills/ccd-github-pr/SKILL.md` Step 1, add the several-candidates branch per C3 and the truncation note per FR-007, and record why it is real rather than theoretical: GitHub forbids two open PRs with the same head **and base**, so two open PRs from one branch to two bases are legal
- [x] T030 [P] [US4] In `skills/ccd-gitlab-mr/SKILL.md` Step 1, add the same branch, noting that GitLab allows one open MR per source-and-target pair
- [x] T031 [US4] In `skills/ccd-github-pr/evaluations.md`, add E9 for two open PRs from one branch to different bases (depends on T029)
- [x] T031a [US4] In `skills/ccd-gitlab-mr/evaluations.md`, add the equivalent E9. GitLab permits one open MR per source-and-target pair, which is precisely why two open MRs from one branch to two different targets are legal there — the several-candidates case is real on both forges and must not be asserted on GitHub alone (depends on T030)

---

## Phase 7: User Story 5 — Not rewriting history under a review (Priority: P2)

**Goal**: A review request carrying diff-anchored review activity is updated without rewriting the branch's published history.

**Independent Test**: Leave a review comment on a line of the diff, note the branch's remote tip, run the skill; the previous tip is still reachable and the suppression is reported.

- [x] T032 [P] [US5] In `skills/ccd-github-pr/SKILL.md` Step 5, make the rebase and force-push conditional in update mode: probe the selected PR for submitted reviews, approvals and diff-anchored threads first; found means no rebase and no force-push, with the suppression, its reason and the three alternatives FR-022 names reported and carried into Step 8. State that conversation comments and bot comments are not review activity, and that the create path is unchanged
- [x] T033 [P] [US5] In `skills/ccd-gitlab-mr/SKILL.md` Step 5, make the same change
- [x] T034 [US5] In `skills/ccd-github-pr/evaluations.md`, add E10 as its own scenario — not folded into another — asserting that the previous remote tip remains reachable from the new one, that no force-push was issued, and that the suppression with its reason and alternatives appears in the Step 8 summary (depends on T032)
- [x] T035 [US5] In `skills/ccd-gitlab-mr/evaluations.md`, add the equivalent E10 (depends on T033)

---

## Phase 8: User Story 6 — Checking a claim without leaving the repository (Priority: P3)

**Goal**: Every forge claim either skill makes is traceable to the repository's own documentation.

**Independent Test**: Take the commands and flags named in `contracts/forge-commands.md` and find each in `docs/forge-review-requests.md` with its source.

- [x] T036 [US6] Cross-check `specs/007-forge-review-request-update/contracts/forge-commands.md` against `docs/forge-review-requests.md` and against both `SKILL.md` files: every command named and every flag whose behaviour is relied on appears in the documentation with a cited source, per SC-007. Add whatever is missing to `docs/forge-review-requests.md` (depends on T003 and every skill edit)
- [x] T037 [P] [US6] In both `skills/ccd-github-pr/SKILL.md` and `skills/ccd-gitlab-mr/SKILL.md`, add a reference from the Tool Reference section to `docs/forge-review-requests.md` so a reader of either skill can reach the reasoning, matching how `.claude/rules/skill-authoring.md` points at its docs file
- [x] T038 [US6] Confirm `CLAUDE.md` is unchanged by this feature — `git diff --stat main -- CLAUDE.md` is empty, per SC-008 — and that `.claude/rules/forge-review-requests.md` declares paths covering both skill directories

---

## Phase 9: Polish & Cross-Cutting Concerns

- [x] T039 Update the Contents list of both `evaluations.md` files so the new scenarios are listed, and update each file's "Re-test after editing the skill" section to name the update path as something to walk after any Step 1, Step 5, Step 7, Step 8 or Step 9 edit
- [x] T039a Verify FR-030's seven preserved guarantees against both changed `SKILL.md` files, one by one: structured questions never prose; at most four options per question and four questions per call; related questions batched into one call; recommended option first with its justification and the cost of not taking it; nothing written to the forge before the gate returns yes; no branch switch, no directory change, no acting on another working tree; and no fabricated branch, handle, team or label. Report each as held or broken — a guarantee this feature quietly relaxed is the regression least likely to be noticed at review
- [x] T040 [P] Confirm both `SKILL.md` files are still under 500 lines; where either is over, move the reference material a step names into a sibling file rather than trimming the rules
- [x] T041 Run `scripts/lint.sh` and fix every finding it reports; re-run until it passes
- [x] T042 Walk `specs/007-forge-review-request-update/quickstart.md` half one end to end, and walk half two against the changed text, reporting the live-forge scenarios as walked rather than passed where no scratch forge is available

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies
- **Foundational (Phase 2)**: depends on Setup; blocks every story phase, because no story may state a forge command's behaviour before T003 records it
- **US1 (Phase 3)**: depends on Foundational. The MVP
- **US2 (Phase 4)**: depends on Foundational. Touches the same two files as US1, so it follows US1 rather than running beside it
- **US3, US4, US5 (Phases 5–7)**: depend on Foundational, and on US1 having established the mode the branches hang off
- **US6 (Phase 8)**: depends on Foundational and on every skill edit being written, since it verifies their claims
- **Polish (Phase 9)**: depends on everything

### Within a story

The two skills are independent of each other and are marked `[P]`. Within one skill, a step's edit precedes the evaluation scenario that asserts it.

### Parallel opportunities

- T005 with T006, T009 with T010, T011 with T012, T011a with T011b, T011c with T011d — the two skills, same story
- T015 with T016, T017 with T018, T019 with T020
- T023 with T024, T025 with T026
- T029 with T030, T032 with T033

Nothing across two stories is parallel, because every story edits both `SKILL.md` files.

---

## Implementation Strategy

### MVP

Phases 1, 2 and 3. That delivers detection, mode selection, the edit call and the update summary on both forges — the second-run failure fixed — with the documentation and rules that justify it already in place.

Stop there and validate against quickstart scenarios 1 and 2 before continuing.

### Incremental delivery

US2 next, because it is the other P1 and it is the only irreversible loss. Then US3, US4 and US5 in order. US6 and Polish close the feature.

### Ordering note

US2 is priority P1 but sequenced second. Both P1 stories are required for the feature to be shippable; US1 is sequenced first because US2's description decision is a step inside the update path that US1 establishes, and there is nothing to guard until the update path exists.

---

## Notes

- `[P]` means different files with no incomplete dependency
- Every task names its file path
- Two files carry most of this feature; check the line budget as you go rather than at the end
- Commit after each phase, not after each task — the phases are the reviewable units
- Never indent with a tab inside a fenced code block: `.editorconfig`'s `[*.md]` section leaves `indent_style = space` in force and the `editorconfig` check rejects it
- Wide Markdown tables trip `MD060`; prefer lists
