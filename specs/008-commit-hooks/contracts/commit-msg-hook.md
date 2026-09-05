# Contract: `scripts/hooks/commit-msg.sh`

The commit-message rule check. Invoked by git through `.husky/commit-msg`, and invoked directly by `scripts/selftest.sh` with a fixture.

## Invocation

```sh
sh scripts/hooks/commit-msg.sh <message-file>
```

`<message-file>` is a path to a file holding a candidate commit message. Git supplies `$1` when it runs the hook; `selftest.sh` supplies a fixture path. **The two callers are otherwise identical** — that is what makes the check testable without a temporary repository.

Exactly one argument. Zero arguments, or more than one, is a usage error.

## Configuration

Sources `.commit-msg.conf` from the repository root, located relative to the script's own directory. Absent, unreadable, or declaring an empty `COMMIT_MSG_TYPES` → exit `2` with a message naming the file. It never falls back to built-in defaults: a silent default is indistinguishable from a chosen value (Principle V).

## Rules, in order

| #   | Rule                                                                                                                                              | On failure                                           |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| 0   | Subject begins `Merge`, `Revert`, `fixup!`, `squash!` or `amend!`                                                                                 | not a failure — accept and exit `0` immediately      |
| 1   | Subject matches `<type>[(<scope>)][!]: <description>`, `<type>` ∈ `COMMIT_MSG_TYPES`, `<scope>` non-empty when present, `<description>` non-empty | refuse, naming the rule and reproducing the subject  |
| 2   | Scope present/absent as `COMMIT_MSG_SCOPE_POLICY` requires                                                                                        | refuse, naming the policy                            |
| 3   | Subject length ≤ `COMMIT_MSG_MAX_SUBJECT`                                                                                                         | refuse, naming the limit **and the measured length** |

Lines after the first are never examined for length or form.

Comment lines (`#` at column 1) are ignored when locating the subject, because git's own template puts them in the file.

## Exit status

| Code | Meaning |
| `0` | message accepted, or exempt under rule 0 |
| `1` | message refused — at least one rule broken |
| `2` | usage or configuration error; nothing was judged |

`1` and `2` are distinct on purpose. A contributor whose configuration file is missing must not read that as "my message was bad".

## Output

Nothing on stdout when the message is accepted. Silence is the success signal; a hook that prints on every commit trains contributors to stop reading it.

On refusal, stderr carries: the rule broken, the offending subject reproduced verbatim, the measured length where a length rule broke, and — once — the two bypass routes with the note that `--no-verify` is the per-invocation emergency route.

## Guarantees

- Never modifies `<message-file>`. A refused message is left exactly as the contributor wrote it, so their editor content survives.
- Never writes anywhere else, never reads outside the repository, never touches the network.
- Never consults `HUSKY`; that variable governs Husky's own shim, not this script.
- Exits non-zero whenever any rule was broken (Principle II).

## Selftest cases

| Fixture subject | Expected |
| `add the thing` | exit `1`, message names the format rule |
| `feat:` + 66 more characters (73 total) | exit `1`, message names the limit and prints `73` |
| `feat:` + 66 characters (72 total) | exit `0` |
| `feat: short subject` plus a 140-character body line | exit `0` |
| `Merge branch 'main' into feature` | exit `0` |
| `wibble: something` | exit `1`, message names the format rule |
