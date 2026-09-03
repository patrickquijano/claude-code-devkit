# Pull request: hotfix

## Incident

<!-- What is broken in production right now, since when, and who is affected. -->

## Why this must ship before a normal review cycle

<!-- The cost of waiting. If there isn't one, use bugfix.md instead. -->

## The change

<!-- Keep it minimal. A hotfix is the smallest diff that stops the bleeding. -->

## Verification

<!-- What was run against this branch, and what will be watched after deploy. -->

## Rollback

<!-- Exact revert or disable step, and who can execute it. -->

## Follow-up

<!-- Issue link for the durable fix, if this one is a stopgap. -->

## Hotfix checklist

- [ ] Diff is the minimum needed to resolve the incident.
- [ ] Targets the correct base branch (release/production, not `main`, if they differ).
- [ ] A follow-up issue exists for anything deferred.
- [ ] On-call and incident channel are aware of this PR.
