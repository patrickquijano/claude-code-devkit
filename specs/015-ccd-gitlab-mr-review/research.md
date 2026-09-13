# Research: GitLab MR Review Skill

**Feature**: 015-ccd-gitlab-mr-review
**Date**: 2026-09-13
**Status**: Complete

## R-001: glab CLI Commands for MR Review Operations

**Decision**: Use `glab mr diff`, `glab mr view`, `glab mr approve`, `glab mr revoke`, and `glab mr note create` as the primary command set for review operations.

**Rationale**: These commands cover the full review lifecycle — reading changes, viewing metadata, posting approval or rejection, and adding structured comments. All default to the current branch when no IID is supplied, matching the skill's single-MR-per-invocation scope. The `--output json` flag enables structured parsing for scripts.

**Alternatives considered**:

- GitLab MCP server (`mcp__plugin_gitlab_gitlab__*`): viable fallback but not primary; `glab` is faster, scriptable in POSIX sh, and already used by `ccd-gitlab-mr`. MCP reserved for environments where `glab` is unavailable.
- Direct REST API calls via `curl`: rejected due to credential handling complexity and duplication of what `glab` already provides.

**Key commands identified**:

| Operation        | Command                                               | Notes                                                                                                           |
| ---------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Get MR diff      | `glab mr diff [<iid>] --color=never`                  | `--color=never` for script parsing; defaults to current branch                                                  |
| View MR metadata | `glab mr view [<iid>] --output json`                  | Returns title, description, reviewers, state, source/target branches                                            |
| Approve MR       | `glab mr approve [<iid>]`                             | Defaults to current branch; optional `--sha` for safety                                                         |
| Revoke approval  | `glab mr revoke [<iid>]`                              | Alias: `glab mr unapprove`                                                                                      |
| Post comment     | `glab mr note create [<iid>] -m "<body>"`             | Creates a top-level note; `--body-file` not available on `note create`, use `-m` with file content via `$(cat)` |
| List open MRs    | `glab mr list --source-branch <branch> --output json` | Filter by source branch to find current branch's MR                                                             |
| Check auth       | `glab auth status`                                    | Must pass before any other glab call                                                                            |
| Current user     | `glab api user --output json`                         | Returns username for reviewer-self-add check                                                                    |
| Add reviewer     | `glab mr update <iid> --reviewer '+<username>'`       | `+` prefix adds; bare name replaces entire set (dangerous)                                                      |

**Reviewer addition caveat**: `glab mr update --reviewer` without `+` prefix **replaces** the entire reviewer list. The skill MUST always use `+<username>` when adding, and MUST read the current reviewer list first to avoid accidental removal. This matches the pattern documented in `ccd-gitlab-mr` SKILL.md lines 133–147.

## R-002: Code Review Best Practices (Google Engineering Practices)

**Decision**: Adopt Google's engineering practices for code review as the skill's review framework, adapted for AI-assisted review constraints.

**Rationale**: Provides a well-established, publicly documented standard that covers what to look for, how to phrase feedback, and when to approve. Aligns with FR-004's requirement for "established code review best practices."

**Key principles extracted**:

### What to look for (from looking-for.html)

1. **Design fit** — does the change belong in the system as designed?
2. **Functionality** — does it do what the author intended, including edge cases?
3. **Complexity** — is it more complex than necessary? Over-engineered for speculative futures?
4. **Tests** — correct, sensible, useful? Clear naming?
5. **Naming** — clear, descriptive, consistent with codebase conventions?
6. **Comments** — explain "why", not "what"? Updated when code changes?
7. **Style guide compliance** — formatting follows project standards?
8. **Documentation** — updated when behavior changes?
9. **System health** — does the change improve overall code health?

### How to write comments (from comments.html)

1. **Focus on code, not developer** — never blame; explain technical impact.
2. **Explain rationale** — every suggestion carries the "why" behind it.
3. **Severity labels** — distinguish mandatory fixes from optional suggestions:
   - No label = must fix before approval
   - "Nit:" = minor, non-blocking
   - "Optional:" or "Consider:" = beneficial but not required
   - "FYI:" = informational for future work
4. **Praise good work** — explicitly highlight clean algorithms, exemplary tests, good patterns.
5. **Balance guidance with autonomy** — let authors devise solutions when possible; provide direct code only when necessary.

### Approval standard (from standard.html)

1. **Approve when the change improves overall code health**, even if imperfect.
2. **Perfection is not required** — continuous improvement over blocking for polish.
3. **Data over opinion** — technical facts override personal preferences.
4. **Style guide is authoritative** — unlisted style points defer to author preference.
5. **Consistency with codebase** — default to existing patterns unless they degrade health.

### Adaptation for AI-assisted review

- The skill MUST NOT infer intent beyond what the diff evidences (FR-013). Where Google's practices assume human judgment about author intent, the skill flags uncertainty rather than guessing.
- Severity classification uses the same labels but applies them conservatively: only issues with clear evidence in the diff receive mandatory severity.
- The skill asks the user for the pass/fail verdict (FR-005) rather than making it autonomously, because approval involves value judgments about tradeoffs that require human context.

## R-003: Existing Skill Structure Patterns (ccd-gitlab-mr)

**Decision**: Follow `ccd-gitlab-mr`'s directory structure, script invocation pattern, and question batching approach.

**Rationale**: Consistency across forge-related skills reduces cognitive load and maintenance cost. The existing skill has proven patterns for glab interaction, member resolution, and safe reviewer management.

**Patterns to adopt**:

1. **Directory layout**: `SKILL.md` + `scripts/` + `templates/` + `evaluations.md` at skill root.
2. **Script invocation**: `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-gitlab-mr-review/scripts/<name>.sh"` — quoted variable, explicit `sh`, relative to plugin root.
3. **Preflight order**: `command -v glab` → `glab auth status` → `git rev-parse` → MR detection. Fail fast on any missing prerequisite.
4. **Question batching**: Related decisions collected in one `AskUserQuestion` call (max 4 questions, max 4 options each).
5. **Reviewer safety**: Always use `+` prefix for additions; read current state before modifying.
6. **Description handling**: Write to temp file, pass via `--description-file` or `$(cat "$tmp")` to avoid shell expansion of backticks and `$`.
7. **No `disable-model-invocation`**: Per contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`.
8. **Forge detection**: Delegated to `scripts/forge-detect.sh` at Step 0 of `speckit-run`; this skill assumes GitLab context.

**Patterns NOT adopted**:

- Branch ranking and target-branch selection — this skill reviews an existing MR, does not create one.
- Rebase logic — out of scope; the skill reviews whatever state the MR is in.
- Description generation templates — this skill posts review comments, not MR descriptions.

## R-004: Comment Format for Change Requests

**Decision**: Single structured summary comment with severity-grouped findings and line references, per user clarification response.

**Rationale**: User selected "Single summary comment (Recommended)" during Phase 2 clarification. Avoids MR notification spam, provides clear overview, and is easier to update on re-review. Line references embedded in the summary body preserve inline context without generating separate threads.

**Format structure**:

```markdown
## Code Review Summary

**Verdict**: Changes Requested
**Reviewed by**: [AI-assisted review via ccd-gitlab-mr-review]
**Date**: YYYY-MM-DD

### Critical (must fix)

- `path/to/file.ext:42` — [finding description with rationale]
- `path/to/file.ext:87` — [finding description with rationale]

### Suggestions (consider)

- `path/to/file.ext:15` — Nit: [minor observation]

### Positive observations

- [something done well, per Google practices guidance]
```

**Alternatives rejected**: Individual line comments (too many notifications), both summary and line comments (highest noise). Decision recorded in spec FR-016.

## R-005: Authentication Approach

**Decision**: glab CLI only; direct API token authentication out of scope.

**Rationale**: User selected "glab CLI only (Recommended)" during Phase 2 clarification. Delegates credential management to glab's own config, matches existing `ccd-gitlab-mr` pattern, and avoids adding credential handling complexity to the skill. Decision recorded in spec FR-015.

## Resolved NEEDS CLARIFICATION Markers

| Marker                 | Resolution             | Source                         |
| ---------------------- | ---------------------- | ------------------------------ |
| FR-015: auth method    | glab CLI only          | User decision, Phase 2 clarify |
| FR-016: comment format | Single summary comment | User decision, Phase 2 clarify |
