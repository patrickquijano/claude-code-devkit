# Research: Change-Request Review and Remediation

**Feature**: [spec.md](spec.md) | **Date**: 2026-09-13 | **Branch**: `013-review-remediate`

## Testability Gap Resolutions

### CHK001 — Confidence scale

- **Decision**: `high`, `medium`, `low`.
- **Rationale**: Matches evidence strength without false precision. Severity captures impact; confidence captures certainty.
- **Alternatives**: Numeric 1–5 (too granular), binary certain/uncertain (loses middle ground).

### CHK002 — Finding categories

- **Decision**: Eleven categories matching FR-010 dimensions: `correctness`, `security`, `reliability`, `performance`, `maintainability`, `compatibility`, `tests`, `accessibility`, `observability`, `configuration`, `documentation`.
- **Rationale**: Direct 1:1 mapping to spec review dimensions. No orphan categories.
- **Alternatives**: Free-form tags (inconsistent), OWASP-only subcategories (too narrow).

### CHK003 — Blocking discussion

- **Decision**: Blocks when platform marks unresolved AND ≥1 comment carries Critical/High/Medium/Low severity from non-author reviewer. Suggestion/Question never block. Platform-native resolve state authoritative.
- **Rationale**: Ties blocking to observable platform state + severity. Prevents suggestions gating merges.
- **Alternatives**: All unresolved block (too strict), only platform-flagged "blocking" threads (GitHub lacks this).

### CHK004 — Credential identification

- **Decision**: Regex patterns on diff content only: AWS keys (`AKIA[0-9A-Z]{16}`), generic API keys (`api[_-]?key`, `secret[_-]?key`, `password`, `token` + assignment), private keys (`-----BEGIN.*PRIVATE KEY-----`), credential connection strings, base64 secrets >20 chars.
- **Rationale**: Covers common shapes, low false positives. Diff-scoped avoids flagging pre-existing secrets. Deterministic and testable.
- **Alternatives**: Entropy-based (high FP on minified code), external scanners (violates Principle I).

### CHK005 — Validation-command precedence

- **Decision**: Priority: (1) explicit `validate`/`check` target in Makefile/package.json/scripts/, (2) CI config entry point, (3) repo docs, (4) conventional defaults. Same-priority multiples → report all, ask. No source → criterion fails per FR-048.
- **Rationale**: Explicit beats inferred. CI beats docs. Documented in reference/validation.md.
- **Alternatives**: Always CI (some repos have faster local checks), always ask (unnecessary friction).

### CHK006 — Preview mode invocation

- **Decision**: `--dry-run` flag on skill invocation. Parsed at Step 0, sets `preview=true`. Suppresses publish/commit/push/approve/merge only; findings and verdicts still produced.
- **Rationale**: CLI convention, discoverable, scriptable. Matches FR-041.
- **Alternatives**: Interactive prompt (not scriptable), separate subcommand (fragments surface).

### CHK007 — Change-request identifier format

- **Decision**: Numeric ID, full URL, or branch name. Numeric/URL passed to `gh pr view`/`glab mr view`. Branch triggers lookup via `gh pr list --head`/`glab mr list --source-branch`. Ambiguous → stop with list per FR-001.
- **Rationale**: Covers all identification methods. Delegates parsing to forge CLI.
- **Alternatives**: URL-only (inconvenient), numeric-only (breaks cross-repo refs).

### CHK008 — Partial remediation recovery

- **Decision**: On failure, working tree left as-is with uncommitted changes intact. Report addressed/remaining findings and failed validation. No auto-rollback. State records `remediation.partial=true` with completed finding IDs.
- **Rationale**: Auto-rollback risks data loss. Partial progress enables informed user decision. Matches FR-029.
- **Alternatives**: Auto-stash (hides state), auto-reset (destroys valid partial fixes).

### CHK009 — Cycle count persistence

- **Decision**: Resets between invocations. Each starts at cycle 1. Five-cycle bound per invocation only.
- **Rationale**: Cross-session persistence requires durable state outside run file. Within-invocation bound satisfies FR-034. User raises at stop per FR-034.
- **Alternatives**: Persistent across invocations (complex, unclear semantics), no bound (violates FR-034).

### CHK010 — Permission pre-check

- **Decision**: Read-only probe before write actions: `gh api repos/{owner}/{repo}/collaborators/{user}/permission` (GitHub), `glab api projects/{id}/members/{user}` (GitLab). Missing permission → skip action per FR-020. Result cached per invocation.
- **Rationale**: Fail fast on permission. Cached result avoids repeated API calls. Matches FR-018, FR-020.
- **Alternatives**: Attempt-and-catch (wastes calls, confusing output), no pre-check (violates FR-010).

### CHK011 — Audit record format

- **Decision**: JSON array `audit[]` in state file. Entry: `{timestamp, action, target, outcome, evidence}`. Actions: `review-published`, `remediation-committed`, `merge-executed`, `permission-denied`, `cycle-bound-reached`. Written at action completion/failure.
- **Rationale**: Machine-readable, co-located with run artifacts, timestamp correlates with forge logs.
- **Alternatives**: Markdown log (harder to parse), separate file (fragments artifacts).

## CLI Syntax Verification

### GitHub (`gh`)

- Approve: `gh pr review [<number>] --approve --body "<summary>"`
- Request changes: `gh pr review [<number>] --request-changes --body "<findings>"`
- Comment: `gh pr review [<number>] --comment --body "<text>"`
- Inline comment: `gh api repos/{owner}/{repo}/pulls/{number}/comments -f path=<file> -f line=<line> -f body=<text>`
- View PR: `gh pr view [<number>] --json author,assignees,reviewers,headRefOid,statusCheckRollup,mergeable,reviews,comments`
- List PRs: `gh pr list --head <branch> --json number,title,author`
- Merge: `gh pr merge [<number>] --squash --delete-branch`
- Assign: `gh pr edit [<number>] --add-assignee <user>`
- Add reviewer: `gh pr edit [<number>] --add-reviewer <user>`

### GitLab (`glab`)

- Approve: `glab mr approve [<id>]`
- Revoke: `glab mr revoke [<id>]`
- Comment: `glab mr note create [<id>] --message "<text>"`
- Inline discussion: `glab mr note create [<id>] --message "<text>" --path <file> --line <line>`
- Resolve: `glab mr note resolve [<id>] --discussion-id <did>`
- View MR: `glab mr view [<id>]` (parse text or use `glab api`)
- List MRs: `glab mr list --source-branch <branch>`
- Merge: `glab mr merge [<id>] --squash --delete-source-branch`
- Update assignee: `glab mr update [<id>] --assignee <user>`

### Forge-agnostic

Both CLIs accept numeric ID or branch name positionally. `gh` accepts URLs directly; `glab` requires `--repo` or cwd context. Both return non-zero on auth failure with distinguishable messages.

## Existing Skill Patterns

From `ccd-pipeline-fix` and `ccd-github-pr`:

- Frontmatter: `name` + `description` only; no `disable-model-invocation`, no `user-invocable`
- Scripts: `sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"`; shared via `${CLAUDE_PLUGIN_ROOT}`
- References: lazy-loaded table in SKILL.md
- Forge detection: single `forge-detect.sh` call at Step 0, verdict stored
- Outcomes: closed vocabulary, no free-form status
- Red flags table + authoring note standard

## Constitution Compliance

| Principle                  | Application                     | Status    |
| -------------------------- | ------------------------------- | --------- |
| I. Tooling Independence    | POSIX sh + native CLI only      | Compliant |
| II. Fail Fast              | Non-zero exit on first failure  | Compliant |
| III. Pinned Images         | N/A for this skill              | N/A       |
| IV. POSIX Shell Only       | shellcheck --shell=sh clean     | Compliant |
| V. Configuration Committed | All models/templates committed  | Compliant |
| VI. Spec-Driven Change     | Spec → plan → tasks → implement | Compliant |

## Sources

CLI syntax verified via local `--help` 2026-09-13. Skill patterns from `skills/ccd-pipeline-fix/SKILL.md` and `skills/ccd-github-pr/SKILL.md`. Constitution v1.3.0 from `.specify/memory/constitution.md`. Gaps from `specs/013-review-remediate/checklists/testability.md`.
<!-- token-budget: compacted (level=medium) on 2026-09-13T09:59:00Z; original at research.full.md -->
