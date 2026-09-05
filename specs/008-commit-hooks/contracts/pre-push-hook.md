# Contract: `scripts/hooks/pre-push.sh`

The outgoing-signature check. Invoked by git through `.husky/pre-push`, and invoked directly by `scripts/selftest.sh` with synthesised stdin.

## Invocation

```sh
printf '%s\n' "<local-ref> <local-oid> <remote-ref> <remote-oid>" | sh scripts/hooks/pre-push.sh <remote-name> <remote-url>
```

Git passes the remote name and URL as `$1` and `$2` and writes one ref-update line per ref on stdin. Neither argument is used by this check; they are accepted so the signature matches git's and so a caller can pass them through unchanged.

Stdin may carry zero, one, or many lines. Zero lines means git found nothing to push: accept and exit `0`.

## Per-ref-update behaviour

| Condition | Outgoing range |
| `<local-oid>` is all zeroes | none — this is a deletion. Skip. |
| `<remote-oid>` is all zeroes | `<local-oid>` limited to commits not reachable from any other ref on that remote |
| otherwise | `<remote-oid>..<local-oid>` |

For each commit in the range, read `%G?` via `git log --format='%G? %h %s'`.

| `%G?` | Verdict |
| `G` `U` `X` `Y` `R` `E` | accept |
| `B` | **refuse** — bad signature |
| `N` | **refuse** — no signature |

`E` is accepted deliberately. It is the ordinary status of a correctly SSH-signed commit when `gpg.ssh.allowedSignersFile` is unset, which is the default; refusing it would block contributors who have done nothing wrong. Research §6.

## Enumeration, not first-failure

**Every** offending commit across **every** ref update is collected, then reported, then the hook exits non-zero once. Stopping at the first would satisfy Principle II's letter and break FR-007, which requires the contributor be told about all of them. Principle II governs whether a later check runs after an earlier one failed; it does not require a single check to stop mid-enumeration. Spec FR-014 states this explicitly.

## Exit status

| Code | Meaning |
| `0` | every commit in every outgoing range is acceptably signed, or there was nothing to check |
| `1` | at least one commit has no signature or a bad one |
| `2` | usage error, or git could not compute a range; nothing was judged |

## Output

Nothing on stdout when the push is permitted.

On refusal, stderr carries one line per offending commit — abbreviated SHA, subject, and which of the two states it is in — followed by the remediation: how to re-sign the offending commits, and the `--no-verify` escape with the note that it leaves unsigned work on the remote.

## Guarantees

- **Rewrites nothing.** No `commit --amend`, no `rebase`, no `filter-branch`, no re-signing. A signature changes a commit's identifier, and git has already computed the ref updates by the time this hook runs, so rewriting here would push the pre-rewrite objects and move the contributor's branch. Research §7, spec FR-008.
- Reads only; writes no git object, ref, index or configuration.
- Makes no network call of its own. It examines local objects.
- Exits non-zero whenever any commit was refused.

## Selftest cases

| Fixture | Expected |
| a range containing one unsigned commit | exit `1`, output names that commit's short SHA |
| a range whose commits all report `E` | exit `0` |
| empty stdin | exit `0` |
| a ref-update line whose local oid is all zeroes | exit `0`, nothing examined |
