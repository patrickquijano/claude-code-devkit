# Quickstart: validating this feature

There is no test runner. The repository's own position is that the checks are the tests, and each skill additionally carries an `evaluations.md` of scenarios run by hand. Validation is therefore: the quality gate passes, the contracts' verification blocks pass, and the scenarios below behave as described.

## Prerequisites

- A git repository with a remote at GitHub or GitLab, for the scenarios that reach a review request.
- The Spec Kit `bug` extension installed, supplying `speckit-bug-assess`, `speckit-bug-fix`, `speckit-bug-test`. Without it, `bug-preflight.sh` reports `capability undetermined` and the run stops — itself scenario 8.
- `gh` or `glab` authenticated, for scenario 5.

## The gate

```sh
sh scripts/lint.sh
```

Seven checks, exits non-zero at the first failure. Run one in isolation with `sh scripts/lint-<check>.sh`, and narrow it with `-- <path>`:

```sh
sh scripts/lint-markdown.sh -- skills/ccd-speckit-bug-run/SKILL.md
sh scripts/lint-shell.sh
sh scripts/lint-citations.sh
```

`citations` matters here: `docs/spec-kit-extensions.md` gains quoted material, and a quotation that drifts from its source fails this check by design.

## The contract checks

Run the verification block in [`contracts/skill-names.md`](./contracts/skill-names.md). Checks 1–5 pass today. **Check 6 fails today and must pass after implementation** — two files still cite feature 006's superseded contract. **Check 7** encodes FR-029a: `ccd-gitlab-mr` must show no diff against the base branch.

## Scenarios

Each is run by hand against a real bug report. Expected outcomes are stated so a deviation is visible without knowing the implementation.

| #   | Scenario                                                                      | Expected                                                                                                                                                                                                                    |
| --- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Clean tree, defect fixes and validates first time                             | Workspace asked before Stage 1; three stages run; commit dispatched to `ccd-commit-push`; review request raised through the skill matching the remote; teardown asked; URL and all three report paths in the closing report |
| 2   | Same, declining the commit at Step 4a                                         | No review request. The run says why, and does not raise one on uncommitted work                                                                                                                                             |
| 3   | Validation returns `failed`, maintainer chooses to reassess                   | Run re-enters Stage 1 rather than ending; `cycles` reads 2; the count is stated at the next such choice; validation's findings reach the reassessment                                                                       |
| 4   | Validation returns `partial`                                                  | Treated identically to `failed`. Never described as success                                                                                                                                                                 |
| 5   | Remote at Bitbucket                                                           | Step 4b skipped with the host named; Step 4c skipped for want of a review request; the run still finishes and says so                                                                                                       |
| 6   | Assessment verdict `invalid`                                                  | Stages 2 and 3 skipped with the reason; shipping steps skipped — nothing was remediated                                                                                                                                     |
| 7   | Worktree mode, uncommitted file present at teardown                           | Removal options withheld, reason stated. `git worktree remove` is not run                                                                                                                                                   |
| 8   | Bug extension absent                                                          | Preflight reports it and the run stops. No stage is emulated by hand                                                                                                                                                        |
| 9   | Session already inside a worktree                                             | Worktree creation not offered; `worktree.created` is false; Step 4c offers no removal                                                                                                                                       |
| 10  | `ccd-github-pr` invoked directly, choosing branch deletion but not auto-merge | Both settings take the chosen values. Auto-merge is not armed                                                                                                                                                               |
| 11  | `ccd-github-pr` against a repo with `deleteBranchOnMerge: true`               | The run says it is already the repository default rather than offering a choice that changes nothing                                                                                                                        |
| 12  | `ccd-github-pr` in update mode                                                | The merge options are not asked at all; the five-field rule is unchanged                                                                                                                                                    |

## What a failure looks like

- A commit or review request appearing with no `ship.subskill_calls` entry means the work was done inline and the sub-skill's gates never ran. That is a failure even if the output looks right.
- A worktree created but not entered: every stage runs in the original checkout while the run reports isolation. The verification step after `EnterWorktree` is what catches it.
- A stage recorded `done` whose report is not on disk.
- The run re-entering assessment without having been told to.
