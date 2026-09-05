# Research: Update an existing review request instead of refusing

**Feature**: 007-forge-review-request-update
**Date**: 2026-09-05
**Verified against**: `gh` 2.100.0 (released 2026-09-03) and `glab` 1.116.0, both installed and authenticated on the development machine at the time of writing.

Every command and flag below was read from the installed binaries' own help output, from the official documentation, or from both. Where the two disagreed, the binary won and the disagreement is recorded.

## Contents

- Decision 1 — Detection: which command, and what widens it
- Decision 2 — The fork trap on GitHub
- Decision 3 — Update: the two commands and their flag surfaces
- Decision 4 — The reviewer and assignee asymmetry
- Decision 5 — Description replacement is unconditional on both forges
- Decision 6 — Draft state is not an edit field
- Decision 7 — Reopen, and what merged forecloses
- Decision 8 — What each server does with a duplicate
- Decision 9 — Permissions and scopes
- Decision 10 — Where update mode lives in the workflow
- Decision 11 — Two skills, not one
- Decision 12 — The append fence
- Decision 13 — Detecting review activity
- Decision 14 — Documentation shape and placement
- Sources

## Decision 1 — Detection: which command, and what widens it

**Decision**: GitHub uses `gh pr list --head <branch> --state all --json number,url,state,isDraft,headRefName,baseRefName,isCrossRepository,author`. GitLab uses `glab mr list --source-branch <branch> --output json` widened with `-A`.

**Rationale**: Both skills already run a narrower form of exactly this command at Step 1, so detection moves from stop-signal to mode-signal without a new dependency or a new call site. Both tools default to open-only, and FR-002 requires closed and merged candidates to be seen — `gh pr list --help` states "By default, this only lists open PRs", and `glab mr list` takes `-A` for all, `-M` for merged and `-c` for closed. Passing the widening flag is the whole change.

**Alternatives considered**: `gh pr view` with no argument resolves to the current branch's pull request and `glab mr view` does the same, which is shorter. Rejected: both resolve to one review request and neither can express "several candidates", which FR-006 requires. `gh pr status` was rejected for the same reason plus an output shape that is not stable for scripting.

## Decision 2 — The fork trap on GitHub

**Decision**: Never pass a qualified head to `gh pr list`. Filter on `isCrossRepository` and the head repository's owner after the fact.

**Rationale**: `gh pr list --help` documents the `-H/--head` flag as `Filter by head branch ("<owner>:<branch>" syntax not supported)`. The underlying REST API does accept `user:ref-name` on its `head` parameter, which is what makes this trap convincing — the qualified form looks like it should work because the API it wraps supports it. A branch name shared between a fork and its parent therefore matches both, and FR-003 forbids treating another repository's review request as this branch's.

**Alternatives considered**: calling the REST API through `gh api` to get qualified-head filtering. Rejected: it introduces a second, differently shaped call path into a skill whose whole surface is `gh` subcommands, for a filter that a JSON post-filter already performs.

## Decision 3 — Update: the two commands and their flag surfaces

**Decision**: `gh pr edit <number>` and `glab mr update <iid>`.

`gh pr edit` accepts `--title`, `--body`, `--body-file`, `--base`, `--add-assignee`, `--remove-assignee`, `--add-reviewer`, `--remove-reviewer`, `--add-label`, `--remove-label`, `--add-project`, `--remove-project`, `--milestone`, `--remove-milestone`. There is **no** flag for the head branch.

`glab mr update <iid>` accepts `--title`, `--description`, `--description-file`, `--target-branch`, `--assignee`, `--reviewer`, `--unassign`, `--label`, `--unlabel`, `--milestone`, `--draft`/`--wip`, `--ready`, `--lock-discussion`/`--unlock-discussion`, `--remove-source-branch`, `--squash-before-merge`, `--fill`, `--yes`.

**Rationale**: These are the operations FR-012's five fields need, and both are single calls. The absence of a head-branch flag on either is why the spec's Edge Cases treat a review request whose head is a different branch as not this branch's review request: it is not a limitation to work around, it is the forge's model.

**Alternatives considered**: the GitLab MCP server's `save_merge_request` for the update path. Kept as a fallback rather than the primary, unchanged from today's arrangement — with the important correction that for an update `merge_request_iid` must be **supplied**, which is the exact inverse of the create-path rule already recorded in the skill. That inversion is a trap worth stating in both directions.

## Decision 4 — The reviewer and assignee asymmetry

**Decision**: Express reviewer and assignee changes separately per forge. Never write one instruction covering both.

**Rationale**: This is the sharpest difference between the two tools and the one most likely to be undone by a well-meaning edit. `gh pr edit` has explicit `--add-reviewer` and `--remove-reviewer` flags, so adding is additive by construction. `glab mr update --reviewer a,b` **replaces** the entire reviewer set; adding requires a `+` prefix on each username and removing requires `-` or `!`. An instruction written once for both forges, in the natural phrasing "add the reviewer", is correct on GitHub and silently strips every existing reviewer on GitLab. FR-016 forbids exactly that outcome, and SC-004 is the criterion it is checked against.

**Alternatives considered**: reading the existing reviewer set and passing the union without a prefix, so the same phrasing works on both. Rejected: it is a replace that happens to be a superset, so it still loses anyone added between the read and the write, and it reintroduces the race FR-012b exists to prevent.

## Decision 5 — Description replacement is unconditional on both forges

**Decision**: Read the live description, diff it against the generated one, and default to leaving it alone.

**Rationale**: Neither tool merges. `gh pr edit --body`/`--body-file` sets the body; `glab mr update --description`/`--description-file` sets the description. There is no append mode on either, and no forge-side merge. A skill that regenerates and writes therefore destroys whatever a person put there — including checklist items a reviewer ticked, which are description content on both forges and not recoverable from anywhere else. This is the only irreversible loss the feature can cause, which is why US2 shares priority P1 with the feature's main purpose.

**Alternatives considered**: always replacing, on the argument that the description should track the branch. Rejected on the evidence above. Never touching the description, on the argument that it is the safest rule. Rejected because refreshing a stale description is a legitimate reason to re-run the skill, and a rule that forbids it pushes the user back to the browser this feature exists to keep them out of.

## Decision 6 — Draft state is not an edit field

**Decision**: Neither skill changes draft state on an existing review request.

**Rationale**: On GitHub, draft state is not reachable through `gh pr edit` at all — it is `gh pr ready` to mark ready and `gh pr ready --undo` to return to draft. On GitLab it is a first-class attribute set by `glab mr update --draft` or `--ready`; the historical `Draft:` title prefix is not the authority. The two forges therefore need different calls for the same intent, and the intent is outside FR-012's five fields. FR-018 excludes it, and excludes the create path's draft question from being asked in update mode, because a question whose answer cannot be acted on is worse than no question.

**Alternatives considered**: supporting the transition, since `gh pr ready` is one call. Rejected as scope: the spec's Non-goals exclude it, and adding a sixth field would drag merge options in behind it.

## Decision 7 — Reopen, and what merged forecloses

**Decision**: A closed review request can be reopened and then updated. A merged one cannot be reopened on either forge, so the only action is a new review request.

**Rationale**: `gh pr reopen <number>` exists and takes an optional comment; GitHub does not permit reopening a merged pull request, merge being terminal. `glab mr reopen` accepts one or more identifiers; reopening a merged merge request has been reported as impossible for years and remains open upstream as `gitlab-org/gitlab#9428` (also filed as #26372 and #61482). Neither forge blocks creating a **new** review request for a branch whose previous one was merged, which is what makes FR-009's answer available.

**Alternatives considered**: treating merged as "no candidate" and creating silently. Rejected: the user is entitled to know that a previous review request for this branch exists and was merged, because it usually means the branch should have been deleted or restarted.

## Decision 8 — What each server does with a duplicate

**Decision**: Rely on detection rather than on the server's rejection.

**Rationale**: Both servers refuse a second open review request for the same head-and-target pair, but they refuse differently and neither message is a stable machine-readable code. GitHub returns HTTP 422 with `A pull request already exists for <owner>:<branch>.` under the generic `custom` error code. GitLab returns HTTP 409 with `Cannot Create: This merge request already exists`. Parsing either is fragile, and by the time it fires the skill has already generated a title, a description, and asked the user four questions. Detection at Step 1 is cheap and happens before any of that.

The corollary matters for FR-006: GitHub forbids two open pull requests with the same head **and base**, not two with the same head. Two open pull requests from one branch to two different bases are legal, so the several-open case is real rather than theoretical.

## Decision 9 — Permissions and scopes

**Decision**: Report a permission failure on the update path specifically, and never fall back to creating.

**Rationale**: On GitHub the `repo` scope covers creating and editing pull requests including assignees, labels, milestones and reviewers; only `--add-project`/`--remove-project` needs the additional `project` scope, and those are outside FR-012's five fields. On GitLab, scope is not the whole story: the `api` scope grants full API access, but creating and updating a merge request additionally requires the Developer role or above, so a Reporter with a full-scope token still cannot update. The two failure modes look identical from the command line and have different remedies, which is why FR-020a requires the report to be specific.

Creating instead is the tempting fallback and is forbidden: a user who cannot edit the existing review request is very often a user who should not be opening a second one.

## Decision 10 — Where update mode lives in the workflow

**Decision**: A mode selected at Step 1 and read by Steps 4, 5, 7, 8 and 9. Not a second skill, not a second entry point, not a branch taken at Step 9.

**Rationale**: Step 1 is already where the existing review request is found, so the information arrives there whether or not it is used there. Deciding the mode late — at Step 9, say — would mean Steps 3 through 8 had already asked questions the update path cannot act on and generated a description the update path must not write unasked. Deciding it at Step 1 lets each later step ask the narrower question instead of asking the wider one and discarding the answer.

Only the first 5,000 tokens of a skill survive compaction, so the mode must be recoverable at Step 9 rather than remembered from Step 1. It is: Step 9 re-reads the selected review request's identifier, which is the same value the mode is derived from.

**Alternatives considered**: a separate `ccd-github-pr-update` skill. Rejected: it doubles the surface, forces the user to know which to invoke before knowing the branch's state, and duplicates Steps 2 through 8 verbatim.

## Decision 11 — Two skills, not one

**Decision**: No shared file, no shared script, no shared abstraction between the two skills.

**Rationale**: The evidence for this is Decisions 4, 6 and 7 taken together. On the three operations this feature adds, the two tools differ in flag shape, in default semantics, and in which command performs the operation at all. A shared layer would have to special-case each of the three, which means the abstraction carries the difference rather than hiding it — with the added cost that a reader of either skill must open a third file to find out what their own forge does. `branch-options.sh` is genuinely shared because branch listing is genuinely identical; nothing this feature adds is.

**Alternatives considered**: a shared `review-request-detect.sh`. Rejected on the above, and separately on Decision 1: the two detection commands differ in flag name, in state-widening flag, and in output field names, so the script would be two scripts behind one name.

## Decision 12 — The append fence

**Decision**: A begin/end pair of HTML comments naming the writing skill.

**Rationale**: Both forges render Markdown in the description, so HTML comments are invisible to every reader — the marker costs the reviewer nothing. A fence gives an exact region to replace, where a heading gives only a start and leaves the end to be guessed at from the next heading, which a person adding their own section underneath would then have silently swallowed. Any state other than exactly one well-formed pair is treated as not-found, per FR-015a, because the alternative is deleting text the skill did not write.

**Alternatives considered**: a visible dated heading, rejected on the boundary problem above; a horizontal rule plus a bold label, rejected because generated descriptions already contain horizontal rules, so the match is most ambiguous exactly where the description is longest.

## Decision 13 — Detecting review activity

**Decision**: Review activity means submitted reviews, approvals, and comment threads anchored to lines of the diff. Plain conversation comments and comments written by automation do not count.

**Rationale**: The reason to suppress a history rewrite is that rewriting detaches review threads from the commits they point at. A conversation comment is attached to the review request, not to a commit, and survives a rewrite intact — counting it would suppress the rebase on nearly every run for no protection at all. A bot comment counts for even less, and on a repository with commenting automation it would suppress the rebase from the first push onward, which is indistinguishable from removing the rebase.

**Alternatives considered**: any human comment, rejected on the above; any comment at all, rejected more strongly for the same reason.

## Decision 14 — Documentation shape and placement

**Decision**: One combined reference at `docs/forge-review-requests.md`, and one path-scoped rule file at `.claude/rules/forge-review-requests.md` whose `paths:` cover both skill directories.

**Rationale**: FR-027 requires each difference between the forges to be stated as a difference. A combined document does that structurally — Decision 4 lives in one paragraph naming both tools — where two per-forge documents can only cross-reference, and the reader who needs the warning most is the one reading the file that omits it. The placement follows what the repository already does: `docs/` holds the reasoning and the sources, `.claude/rules/` holds the short imperative rules and cites the docs file, exactly as `.claude/rules/skill-authoring.md` cites `docs/skill-authoring-practices.md`. `CLAUDE.md` gains nothing, which is what SC-008 measures.

**Alternatives considered**: one file per forge, rejected on FR-027; adding the rules to `CLAUDE.md`, rejected because they are relevant to two directories and `CLAUDE.md` is loaded for every session regardless of subject.

## Recorded gaps

- Neither tool exposes a documented, machine-readable way to distinguish a bot comment from a person's. Decision 13's boundary is stated in terms of what is anchored to the diff, which both forges do expose, so the bot question does not arise for the suppressing kind. It remains an open question for any future rule that counts conversation comments.
- GitLab's published rate limits for gitlab.com name issue creation and note creation but do not state a separate limit for merge request creation or update. No limit is assumed; nothing in this feature loops.
- `glab mr note` is marked EXPERIMENTAL in 1.116.0. Nothing in this feature depends on it, and nothing should be built on it until that marking changes.
- `glab mr merge --auto-merge` defaults to **true** when a pipeline is running. This feature does not call `glab mr merge`, but the default is recorded because it is surprising and because any future work on merge options will meet it.

## Sources

- `gh pr list`, `gh pr edit`, `gh pr ready`, `gh pr reopen`, `gh pr merge`, `gh auth status`, `gh help exit-codes`, `gh help environment` — help output of the installed `gh` 2.100.0, corroborated against <https://cli.github.com/manual/>
- <https://docs.github.com/en/rest/pulls/pulls> — the `head` parameter's `user:ref-name` support that `gh pr list --head` does not expose
- <https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps> — the `repo` scope
- <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-auto-merge-for-pull-requests-in-your-repository> — auto-merge preconditions
- `glab mr list`, `glab mr update`, `glab mr view`, `glab mr reopen`, `glab mr merge`, `glab auth status`, `glab config` — help output of the installed `glab` 1.116.0, corroborated against <https://docs.gitlab.com/cli/>
- <https://docs.gitlab.com/user/permissions/> — Developer role required to create and update a merge request
- <https://docs.gitlab.com/security/tokens/access_token_scopes/> — the `api` scope
- <https://gitlab.com/gitlab-org/gitlab/-/issues/9428> — reopening a merged merge request
- <https://forum.gitlab.com/t/409-this-merge-request-already-exists-api/21212> — the duplicate-merge-request response
- <https://gitlab.com/gitlab-org/cli> — the CLI's current home, after migration from `profclems/glab`
