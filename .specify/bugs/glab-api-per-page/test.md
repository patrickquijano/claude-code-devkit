# Bug Verification: `glab api` member listing no longer rejects the page size

- **Slug**: glab-api-per-page
- **Tested**: 2026-09-07
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The assessment's reproduction was exercised in full, post-fix, in a real GitLab-remote repository with the real `glab` — exit 0 and a non-empty ranked listing, where the pre-fix script in the same repository and the same shell still exits 1 with `Unknown flag: --per-page`. The symptom does not reproduce, the whole quality gate and its self-test pass, and the one call deliberately left alone still works.

The residual that the assessment and the fix report both flagged is now closed: `:id` placeholder expansion and the query string were verified **together**, in one run, rather than only separately.

## Checks Performed

| Check                              | Command / Action                                                                                                                   | Result           | Notes                                                                                                                |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------- |
| Reproduction (post-fix)            | Fixed script run from `~/source/repos/gitlab.com/patrickquijano-infra/docker-swarm-monitoring`, real `glab 1.116.0`, authenticated | pass             | exit 0, one ranked row, empty stderr. `:id` expanded for real                                                        |
| Reproduction (pre-fix control)     | Unfixed script from the main checkout, **same repo, same shell**                                                                   | fail as expected | exit 1, empty stdout, `Unknown flag: --per-page.` — confirms the reproduction is real and the fix is what changed it |
| Pinning assertions from the fix    | The two greps added to `skills/ccd-gitlab-mr/evaluations.md`                                                                       | pass             | `0` non-comment `--per-page` lines, `1` occurrence of `members/all?per_page=100`                                     |
| Ranking logic, stub `glab`         | Stub emitting 21 ndjson members; the stub rejects `--per-page` as the real CLI does                                                | pass             | Recent committer first despite lowest access level, then access level descending, then username                      |
| Guard: `glab` absent               | `PATH` without `glab`                                                                                                              | pass             | exit 1, `glab-missing: …`                                                                                            |
| Guard: `jq` absent                 | `PATH` holding only the stub                                                                                                       | pass             | exit 2, `jq-missing: …`                                                                                              |
| Cap and truncation note            | Stub emitting 600 records                                                                                                          | pass             | 500 rows on stdout, `truncated: ranked the first 500 of 600 members` on stderr                                       |
| Syntax                             | `sh -n` on `member-options.sh` and `branch-options.sh`                                                                             | pass             | Both clean                                                                                                           |
| Regression: untouched sibling call | `glab ci list --per-page 3` in the same GitLab repo                                                                                | pass             | Still valid — `glab ci list` does define the flag, so leaving `pipeline-evidence.sh` alone was correct               |
| Lint / quality gate                | `sh scripts/lint.sh` (check mode, tree mounted read-only)                                                                          | pass             | exit 0, all seven checks                                                                                             |
| Gate self-test                     | `sh scripts/selftest.sh`                                                                                                           | pass             | exit 0; 17 standards, 13 format-hook cases, 20 git-hook cases, 5 compaction-audit cases                              |
| `ccd-gitlab-mr` end-to-end (E1/E2) | Creating a real merge request through the whole skill                                                                              | skipped          | Needs a scratch GitLab project, and no MR should be raised as a side effect of validating this defect                |

## Output Excerpts

Post-fix, in the GitLab-remote repository:

```text
$ sh …/member-options.sh
patrickquijano  Patrick Quijano  50  recent-committer
exit=0
```

Pre-fix, same repository, same shell:

```text
$ sh …/member-options.sh
exit=1
glab-api-failed: … ERROR Unknown flag: --per-page. Try --help for usage.
```

Gate and self-test:

```text
==> lint.sh: all checks passed
==> selftest.sh: every check rejected its bad fixture, the format hook held every
    safety property, and the compaction audit refused to certify a lost rule
```

## Residual Risks

- **One `glab` version.** Everything was verified against `glab 1.116.0 (e8436ca8a)`. The query-string form is the documented way to pass query parameters and is not expected to be version-sensitive, but no other version was exercised.
- **gitlab.com only.** The verification repository is on GitLab SaaS. A self-hosted instance was not tested; nothing in the change is host-dependent, but the claim is narrower than "all GitLab".
- **One member returned.** The verification project has a single visible member, so the ranking order was proved against the 21-member and 600-member stubs rather than against real data at scale. Pagination past page one was therefore never crossed with a real remote — `--paginate` composing with a query string was confirmed separately against a multi-page `projects?per_page=3` listing.
- **The misleading error label survives.** `glab-api-failed:` still reports argument-parsing errors as API errors. It is why this defect went unnoticed from the skill's first commit, it is recorded as a follow-up in `fix.md`, and it is deliberately not part of this change.
- **The assessment's open question stands.** Which `glab` version the reporter ran is still unknown. It does not affect this result.

## Recommendation

Close the bug — verified end-to-end. The original symptom no longer reproduces in a repository that satisfies the assessment's own preconditions, a pre-fix control in the identical environment still fails exactly as reported, and the full gate plus its self-test pass. Carry the two follow-ups from `fix.md` forward separately: correcting the `glab-api-failed:` label so this class of failure is not misattributed again, and confirming the `SKILL.md` summary line the next time that table is edited.
