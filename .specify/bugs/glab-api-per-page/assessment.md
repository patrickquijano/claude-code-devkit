# Bug Assessment: `glab api` rejects `--per-page`, breaking `ccd-gitlab-mr`'s member ranking

- **Slug**: glab-api-per-page
- **Created**: 2026-09-07
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

> Fix the `ccd-gitlab-mr's bundled scripts/member-options.sh fails with Unknown flag: --per-page against your glab version.`

No URL was supplied, so the URL trust policy did not apply and nothing was fetched.

## Symptom

`skills/ccd-gitlab-mr/scripts/member-options.sh` passes `--per-page 100` to `glab api`, which has no such flag. `glab` exits non-zero before issuing any request, the script's error branch fires, and it exits 1 with `glab-api-failed: … Unknown flag: --per-page.` Expected: a tab-separated ranked member listing on stdout and exit 0.

The failure is total and unconditional — the listing is never produced on any glab version whose `api` command lacks the flag, which includes the current release.

## Reproduction

1. Have `glab` and `jq` on `PATH`, authenticated to a GitLab host (`glab auth status` reports logged in).
2. From a checkout of this repository, run `sh skills/ccd-gitlab-mr/scripts/member-options.sh`.
3. Observe exit status 1, empty stdout, and the `glab-api-failed:` line on stderr quoting `Unknown flag: --per-page.`

Reproduced on `glab 1.116.0 (e8436ca8a)`, macOS (Darwin 25.6.0). Running the underlying command directly gives the same result:

```console
$ glab api projects/:id/members/all --paginate --per-page 100 --output ndjson
   ERROR
  Unknown flag: --per-page.
  Try --help for usage.
```

`glab api --help` on that version lists exactly these flags, with no `--per-page` among them: `--field`, `--form`, `--header`, `--help`, `--hostname`, `--include`, `--input`, `--method`, `--output`, `--paginate`, `--raw-field`, `--silent`.

## Suspected Code Paths

- `skills/ccd-gitlab-mr/scripts/member-options.sh:34` — the defect. `glab api projects/:id/members/all --paginate --per-page 100` passes a flag `glab api` does not define.
- `skills/ccd-gitlab-mr/scripts/member-options.sh:35-39` — the error branch that catches it and mislabels it `glab-api-failed`, attributing a local argument-parsing error to the remote API.
- `skills/ccd-gitlab-mr/SKILL.md:108` — the only consumer, invoked for the reviewer/assignee option set.
- `skills/ccd-gitlab-mr/SKILL.md:320` — documents the wrapper as `glab api projects/:id/members/all --paginate`, without `--per-page`. The documentation already describes the working form; only the script disagrees with it.

Two nearby call sites were checked and are **not** affected:

- `skills/ccd-pipeline-fix/scripts/pipeline-evidence.sh:112` uses `glab ci list --status failed --per-page "$LIMIT"`. `glab ci list` does define `-P, --per-page`, so this is correct and must not be changed.
- `skills/ccd-github-pr/scripts/reviewer-options.sh` uses `gh repo view --json assignableUsers` and calls no `gh api` and no per-page flag.

## Root Cause Hypothesis

**Confidence: high.** `--per-page` is a `gh`-shaped and `glab ci list`-shaped idiom that `glab api` never accepted; on that subcommand, per-page is a REST query parameter, not a CLI flag. The line was written that way in its first commit — `f01bd22 feat: distribute five authored skills with the plugin (#2)`, when the file was still `skills/auto-gitlab-mr/scripts/member-options.sh` — so this is a long-standing defect present since the skill was first distributed, not a regression from a `glab` upgrade. The report's phrase "against your glab version" is consistent with, but not required by, that reading: no released `glab` is known to have carried the flag on `api`, and the remediation below is version-independent either way.

The defect has been invisible because the consumer degrades rather than fails. `skills/ccd-gitlab-mr/evaluations.md:63` records that a non-zero exit from this script makes the skill fall back to the GitLab MCP server instead of failing the run, so `ccd-gitlab-mr` still opens merge requests — it has simply never once ranked members through `glab`.

## Proposed Remediation

**Preferred**: move the page size out of the flag and into the endpoint's query string, leaving `--paginate` and `--output ndjson` as they are:

```sh
if ! glab api "projects/:id/members/all?per_page=100" --paginate \
  --output ndjson > "$tmpdir/all" 2> "$tmpdir/err"; then
```

This keeps every property the current line was reaching for: 100 records per request, all pages fetched, newline-delimited output for the `jq` filter below it. Verified on `glab 1.116.0` that the query string is accepted, that `--paginate` composes with a query string already present on the path, and that the exact endpoint returns parseable ndjson:

```console
$ glab api "projects/fiveaces%2Ffiveaces-ci/members/all?per_page=100" \
    --paginate --output ndjson | jq -r '[.username,.name,(.access_level|tostring)]|@tsv'
patrickquijano	Patrick Quijano	50
```

**Alternatives**:

- Drop `--per-page 100` and nothing else, letting `--paginate` walk the API's default 20 records per page. Correct and the smallest possible diff, but it costs five times the HTTP requests to reach the script's own 500-member cap — 25 round trips where the preferred form needs 5. The comment above `MAX_MEMBERS` exists because large groups run to thousands of inherited members, so this is the case the script was tuned for.
- Pass it as a field, `-F per_page=100`. **Rejected, and it must not be used**: `glab api`'s own documentation states the default method is `GET` when no parameters are added and `POST` otherwise, so adding a field flag would turn a member listing into a `POST` against `projects/:id/members/all`.

**Files likely to change**:

- `skills/ccd-gitlab-mr/scripts/member-options.sh`
- `.claude-plugin/plugin.json` — `version` bump. `CLAUDE.md` requires this in any change that touches `skills/`, minor for a behaviour change, because the version is the only cache key a consumer has and a stale copy is served silently.
- `skills/ccd-gitlab-mr/evaluations.md` — a scenario that pins the fix, since this repository has no separate test runner.

**Tests to add or update**:

- An assertion in `skills/ccd-gitlab-mr/evaluations.md` that the `glab api` invocation carries no `--per-page`, phrased so the next reader sees why: `glab api` has no such flag, and `glab ci list` in `ccd-pipeline-fix` does, so the two must not be normalised to each other.
- The existing stub-`glab` scenario at `skills/ccd-gitlab-mr/evaluations.md:191` re-run: 20 ndjson members ranked committers-first then access level descending then username, exit 1 with no `glab`, exit 2 with no `jq`, and the `truncated:` note past 500 records.
- `sh -n skills/ccd-gitlab-mr/scripts/member-options.sh`, then `scripts/lint.sh` for the ShellCheck pass.
- An end-to-end run of the script against a GitLab remote, confirming exit 0 and a non-empty ranked listing — the check that would have caught this and currently exists nowhere.

## Risks & Considerations

- **Low blast radius.** One line in one script consumed by one skill, with no API surface, no migration and no data risk.
- **The `:id` placeholder alongside a query string was verified only indirectly.** This repository's `origin` is GitHub, so `:id` cannot expand here; the run confirmed `glab` parses the query-string form and reaches placeholder expansion, and separately confirmed `members/all?per_page=100` works against a real GitLab project by explicit path. A first run in a GitLab checkout should confirm the two together.
- **Do not "fix" `ccd-pipeline-fix` to match.** A sweep that normalises `--per-page` across the repository would break a correct `glab ci list` call. The asymmetry is real and belongs in a comment.
- **The `glab-api-failed:` label misattributes this class of failure**, reporting an argument-parsing error as an API error, which is part of why the defect went unnoticed. Correcting that message is a separate improvement and is deliberately left out of scope here.
- **Version bump is load-bearing, not bookkeeping.** Without it consumers keep serving the cached broken script; feature 008 caught exactly that.

## Open Questions

- [NEEDS CLARIFICATION: which `glab` version the reporter ran. It does not change the remediation — the query-string form is correct on every version, including 1.116.0 as verified here — but it would settle whether any release ever accepted `api --per-page`, and therefore whether this is worth noting as a compatibility shim rather than a plain defect.]
