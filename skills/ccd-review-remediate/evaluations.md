# Evaluations: Change-Request Review and Remediation

Validation scenarios for skill authors. Run these after editing SKILL.md or any reference/script to confirm the skill still behaves correctly.

## Prerequisites

- Git repository with GitHub or GitLab `origin` remote
- `gh` or `glab` CLI installed and authenticated
- Claude Code session with `claude-code-devkit` plugin loaded
- Clean working tree on a branch with at least one open change request

## Scenario 1: Review-only produces evidence-backed findings

```sh
/ccd-review-remediate
```

Expected:

- Preflight reports forge, CLI status, CR ID, head SHA
- Findings published with severity, confidence, category, file, line, evidence quote
- Verdict states per-criterion status against six G6 criteria
- Working tree unchanged (`git status` clean)
- No commits pushed (`git log --oneline origin/<branch>..HEAD` empty)

## Scenario 2: Preview mode suppresses all external state changes

```sh
/ccd-review-remediate --dry-run
```

Expected:

- Same findings and verdict as Scenario 1
- No comments published to CR
- No approval or request-changes recorded
- Audit entries show `preview-skipped` for publish actions
- Working tree, branch, remote, CR byte-identical before and after

## Scenario 3: Self-authored CR produces comment-only output

```sh
/ccd-review-remediate
```

Expected (authenticated user authored open CR):

- Findings published as comments only
- No approval or request-changes verdict recorded
- Output states "comment-only: reviewer is author" per FR-047

## Scenario 4: Remediation fixes findings and validates

```sh
/ccd-review-remediate --remediate
```

Expected:

- Prioritized plan shown before code changes
- Minimal root-cause fixes applied
- Regression tests added or updated
- Validation suite run; output shown
- Committed per repo conventions, pushed without force
- Remediation summary maps finding IDs to resolutions

## Scenario 5: Cycle bound stops at five

Expected (after five cycles with unresolved findings):

- Run stops at cycle 5
- Remaining findings listed with severity and status
- User asked whether to raise bound
- No further cycles without explicit answer

## Scenario 6: Merge executes only when all gates pass

```sh
/ccd-review-remediate --merge
```

Expected (all six G6 criteria pass):

- Head SHA confirmed matching reviewed SHA
- Multi-select: delete source branch, squash commits
- Merge executed via forge CLI
- Switched to target branch, fetched, fast-forwarded

## Scenario 7: Stopping conditions produce stated reasons

| Condition          | Invocation                                        | Expected stop message                        |
| ------------------ | ------------------------------------------------- | -------------------------------------------- |
| No open CR         | `/ccd-review-remediate` on branch with no CR      | `stopped: no-change-request`                 |
| Multiple open CRs  | `/ccd-review-remediate` on branch with 2+ CRs     | `stopped: ambiguous-cr` with CR list         |
| Dirty working tree | `/ccd-review-remediate --remediate` with changes  | `stopped: dirty-tree` with uncommitted paths |
| Unsupported forge  | `/ccd-review-remediate` with Bitbucket remote     | `stopped: unsupported-forge`                 |
| Missing permission | `/ccd-review-remediate` as read-only collaborator | `skipped: no-permission` for publish/approve |
| Stale head SHA     | `/ccd-review-remediate --merge` after force push  | `stopped: stale-sha`                         |

## Post-edit checklist

After editing SKILL.md or any file in this skill:

- [ ] All four scripts pass `shellcheck --shell=sh`
- [ ] All Markdown files pass `markdownlint`
- [ ] Frontmatter has `name` and `description` only — no `disable-model-invocation`, no `user-invocable`
- [ ] Shared scripts referenced via `${CLAUDE_PLUGIN_ROOT}`, never copied
- [ ] Forge detection happens only in `preflight.sh`, never re-detected
- [ ] Reference map table in SKILL.md matches actual files in `reference/`
