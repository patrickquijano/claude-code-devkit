# Quickstart: validating update mode

**Feature**: 007-forge-review-request-update
**Date**: 2026-09-05

How to establish that this feature works. There is no test runner and no way to exercise either skill end to end without a live forge, so validation has two halves: what the repository can check on its own, and what needs a scratch repository on GitHub or GitLab.

## Prerequisites

- This branch checked out.
- For the repository half: nothing beyond what `scripts/lint.sh` already needs — the native tool for each check, or a container runtime.
- For the forge half: `gh` 2.100.0 or later authenticated to a scratch GitHub repository, `glab` 1.116.0 or later authenticated to a scratch GitLab project, and write access to both.

## Half one — what the repository checks

```sh
scripts/lint.sh
```

Runs all seven checks and stops at the first failure. Every file this feature adds is Markdown, so `format`, `markdown` and `editorconfig` are the three that govern it. A failure names the file and the check.

Then the claims that are checkable by reading:

```sh
# Neither skill still says it only creates.
grep -n "only creates" skills/ccd-github-pr/SKILL.md skills/ccd-gitlab-mr/SKILL.md

# Both skills still forbid the frontmatter field that would break dispatch.
grep -c "disable-model-invocation" skills/ccd-github-pr/SKILL.md skills/ccd-gitlab-mr/SKILL.md

# The new rule file declares paths covering both skills.
sed -n '1,8p' .claude/rules/forge-review-requests.md

# Neither SKILL.md exceeds the 500-line budget.
wc -l skills/ccd-github-pr/SKILL.md skills/ccd-gitlab-mr/SKILL.md

# CLAUDE.md gained nothing (SC-008).
git diff --stat main -- CLAUDE.md
```

Expected: the first `grep` finds nothing outside a sentence describing the old behaviour; the line counts are under 500; `CLAUDE.md` shows no change.

The reviewer-facing check for SC-007 is a reading one: take the commands and flags named in `specs/007-forge-review-request-update/contracts/forge-commands.md` and confirm each appears in `docs/forge-review-requests.md` with its source.

## Half two — against a live forge

These are the written scenarios in each skill's `evaluations.md`, which is the repository's regression instrument. Run them against a scratch repository; where a scratch forge is unavailable, walk them against the text and report them as walked, not passed.

The order below is the cheapest path through the states, reusing one branch.

1. **Create, unchanged.** Push a branch with no review request. Run the skill. Expect today's behaviour exactly: same questions, same count, a review request created. This is the regression that matters most, because it is the path every first run takes.
2. **One open candidate.** Amend the branch, force-push, run the skill again. Expect update mode announced at Step 1, a field-by-field summary at Step 8, and after approval the same review request identifier and URL — not a second one.
3. **The description is preserved.** Before re-running, edit the review request's description in the browser: add a paragraph and tick a checklist item. Run the skill. Expect the difference shown, leave-it offered as the default, and after choosing it, the paragraph and the tick still present.
4. **Append, then append again.** Re-run twice choosing append. Expect one fenced region, replaced on the second run rather than duplicated, and the hand-written paragraph outside it untouched both times.
5. **Reviewers are added.** Add a reviewer in the browser. Run the skill and name a different reviewer. Expect both present afterwards. On GitLab this is the scenario that catches a missing `+` prefix, and it is the one to run first after any edit to that skill's Step 9.
6. **Review activity suppresses the rebase.** Leave a review comment on a line of the diff. Note the branch's remote tip. Run the skill. Expect no rebase, no force-push, the suppression and its alternatives reported at Step 8, and the previous tip still reachable from the new one.
7. **Closed.** Close the review request. Run the skill. Expect the choice between reopening and creating fresh, and no change before the pick.
8. **Merged.** Merge it. Run the skill on the same branch. Expect the statement that a merged review request cannot be reopened, then the create path.
9. **Several open.** On GitHub only: open a second pull request from the same branch to a different base. Run the skill. Expect both listed with identifier, state, target and title, and a question rather than a choice made for you.

## What a failure looks like

- A second review request where step 2, 3, 4, 5 or 6 expected an update — the detection or the mode selection is wrong.
- A description shorter than it was — the default was not applied, or the fence was mis-parsed.
- A reviewer missing after step 5 on GitLab — the `+` prefix. This is the defect the contract exists to prevent.
- A rewritten history after step 6 — the review-activity probe ran too late, or read the wrong kind of comment.
- Questions asked in update mode that update mode cannot act on — draft state or merge options leaking past C4.
