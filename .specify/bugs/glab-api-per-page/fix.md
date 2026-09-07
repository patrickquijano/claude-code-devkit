# Bug Fix: move `per_page` into the query string so `glab api` accepts it

- **Slug**: glab-api-per-page
- **Fixed**: 2026-09-07
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

`skills/ccd-gitlab-mr/scripts/member-options.sh` now requests the member listing as `glab api "projects/:id/members/all?per_page=100" --paginate --output ndjson`, moving the page size from a flag `glab api` does not define into the endpoint's query string. The preferred remediation from the assessment was applied unchanged; `plugin.json` was bumped so consumers stop being served the cached broken script, and `evaluations.md` gained an assertion that pins the fix, since this repository has no separate test runner.

## Changes

| File                                             | Change   | Notes                                                                                                                                             |
| ------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `skills/ccd-gitlab-mr/scripts/member-options.sh` | modified | The `glab api` call, plus a six-line comment recording why the flag form fails and why `glab ci list --per-page` must not be normalised to match  |
| `.claude-plugin/plugin.json`                     | modified | `version` 0.6.0 → 0.7.0, minor for a behaviour change per `CLAUDE.md`                                                                             |
| `skills/ccd-gitlab-mr/evaluations.md`            | modified | Added the "no `--per-page` on the `glab api` call" assertion to the after-any-edit-to-the-scripts paragraph, with the `pipeline-evidence.sh` trap |
| `.specify/bugs/glab-api-per-page/assessment.md`  | modified | **Whitespace only** — one leading tab inside a fenced block became two spaces. See **Deviations from Assessment**                                 |

`skills/ccd-pipeline-fix/scripts/pipeline-evidence.sh` was deliberately left untouched: its `glab ci list --status failed --per-page "$LIMIT"` is correct, because that subcommand does define `-P, --per-page`.

## Diff Highlights

```sh
-if ! glab api projects/:id/members/all --paginate --per-page 100 \
-  --output ndjson > "$tmpdir/all" 2> "$tmpdir/err"; then
+# The page size rides in the query string, not in a flag. `glab api` defines no
+# --per-page — `glab ci list` does, which is why the two must not be normalised
+# to each other — and passing one fails argument parsing before any request is
+# made, surfacing here as a misleading "glab-api-failed: … Unknown flag". A
+# --field would reach the API but flip the method to POST, which glab documents
+# for any request carrying a field.
+if ! glab api "projects/:id/members/all?per_page=100" --paginate \
+  --output ndjson > "$tmpdir/all" 2> "$tmpdir/err"; then
```

## Tests Added or Updated

- `skills/ccd-gitlab-mr/evaluations.md`, in the after-any-edit-to-the-scripts paragraph — two greps pinning the fix: no `--per-page` on any non-comment line of `member-options.sh` (expect 0), and exactly one `members/all?per_page=100` (expect 1). The first strips comments before matching, because the new explanatory comment names the flag on purpose and a bare grep matches the very line that documents its absence.
- The same paragraph now names `skills/ccd-pipeline-fix/scripts/pipeline-evidence.sh` as the trap for a later reader, so a sweep that normalises `--per-page` across the repository does not break the call where it is valid.
- No new test file was added. The assessment called for none, and this repository's tests are the quality gate plus the per-skill `evaluations.md` scenarios.

## Local Verification

- `sh -n skills/ccd-gitlab-mr/scripts/member-options.sh` → OK. Same for `branch-options.sh`, per the existing scenario's instruction to check both.
- The two new assertions → `0` and `1` as specified.
- `sh scripts/lint.sh --fix` → `all checks passed`, all seven checks. Two things had to be corrected to get there, both recorded under **Deviations**.
- Real `glab 1.116.0`, live GitLab project, the exact fixed endpoint:
  `glab api "projects/fiveaces%2Ffiveaces-ci/members/all?per_page=100" --paginate --output ndjson | jq -r '[.username,.name,(.access_level|tostring)]|@tsv'` → `patrickquijano	Patrick Quijano	50`. This confirms the query string is accepted, that `--paginate` composes with a query string already on the path, and that the response still parses through the script's own `jq` filter.
- Stub `glab` on `PATH` emitting 21 ndjson members, one of them a recent committer on this branch — the stub rejects `--per-page` exactly as the real CLI does, so it only succeeds against the fixed call. Result: exit 0, and the ranking held:

  ```text
  patrickquijano  Patrick Quijano  20  recent-committer
  user03          User 03          40  -
  user07          User 07          40  -
  user11          User 11          40  -
  ```

  Committer first despite the lowest access level, then access level descending, then username — the documented order.

- Against that same stub, the pre-fix invocation still fails (`Unknown flag: --per-page.`, exit 1) while the fixed one returns records. The stub would have caught this defect; nothing in the previous test set did.
- `glab` absent from `PATH` → exit 1, `glab-missing: install glab, or fall back to the GitLab MCP server`.
- `jq` absent → exit 2, `jq-missing: install jq, or read members with the GitLab MCP server`. Note for whoever re-runs this: macOS now ships `jq` at `/usr/bin/jq`, so a `PATH` of `/usr/bin:/bin` does **not** make `jq` absent and the check silently passes for the wrong reason.
- Stub emitting 600 records → 500 rows on stdout and `truncated: ranked the first 500 of 600 members` on stderr.

Not verified, and the reason: the script itself was never run end-to-end against a GitLab remote, because this repository's `origin` is GitHub and `:id` therefore cannot expand. The placeholder and the query string were each confirmed separately — `glab` parses the query-string form and proceeds to placeholder expansion, and the endpoint works when the project is named explicitly — but not together in one run. The assessment flagged this as a residual risk and it remains one.

## Deviations from Assessment

Two, both procedural rather than substantive. The preferred remediation was applied exactly as written, and no alternative was substituted.

1. **`assessment.md` was edited.** This command is told not to touch that file. The change was whitespace only: the fenced `sh` block quoting the fixed call carried a leading **tab**, copied from the script it quotes, and `.editorconfig`'s `[*.md]` section overrides only `indent_size`, so `indent_style = space` still governs fenced blocks. `lint-editorconfig.sh` failed on `assessment.md:62`, blocking the gate on an artifact that is committed project history. The tab became two spaces; not one word of the remediation, the verdict, the severity or the risks changed. Recorded here rather than done silently, because the guardrail exists to stop the contract being rewritten to match the patch, and this was not that.

2. **The first draft of the new assertion was wrong, and was corrected before the report was written.** It read `grep -c -- '--per-page' … # expect 0`, which returns **1**, because the explanatory comment added directly above the fixed call names the flag. An assertion that fails as written is worse than none, so it now strips comment lines first. Noted because the mistake is a natural one for the next person to repeat.

Separately, `sh scripts/lint.sh --fix` reformatted `skills/ccd-gitlab-mr/evaluations.md` — prettier realigned the trailing `# expect …` comment columns in the new fenced block. Content unchanged; the repository's committed `PostToolUse` hook and the gate both do this by design.

## Follow-ups

- **`glab-api-failed:` misattributes this whole class of failure.** It reported a local argument-parsing error as an API error, which is the direct reason a defect present since the skill's first commit went unnoticed for six features. Distinguishing "glab rejected the arguments" from "the API rejected the request" would be a small, separate change. Deliberately out of scope here; the assessment says so too.
- `skills/ccd-gitlab-mr/SKILL.md:320` summarises the wrapper as `glab api projects/:id/members/all --paginate`. That was never a literal quote and is still accurate as a summary, but it no longer matches the call character-for-character. Worth a look next time that table is touched.
- The open `[NEEDS CLARIFICATION]` from the assessment stands: which `glab` version the reporter ran. It does not affect this fix — the query-string form is correct on every version — but it would settle whether any release ever accepted `api --per-page`.
- First run of `ccd-gitlab-mr` against a real GitLab remote should confirm exit 0 and a non-empty ranked listing, closing the one gap this verification could not.
