# Contract: `scripts/install-hooks.sh`

Activates both hooks for this working copy, and reports the resulting state. The one command FR-009 requires.

## Invocation

```sh
sh scripts/install-hooks.sh          # activate, then report
sh scripts/install-hooks.sh --status # report only; write nothing
```

Runnable from the repository root with no arguments. `--status` is the only flag. Any other argument is a usage error.

## What it decides

It reads the environment and picks the correct `core.hooksPath` rather than assuming one. Writing `.husky` unconditionally would break a Husky user on their next `npm install`, when `husky` sets the value back to `.husky/_` and the two disagree about which file git runs. Research §3.

| Found | Sets `core.hooksPath` to | Why |
| `.husky/_` exists and holds hook shims | `.husky/_` | Husky owns the arrangement; leave it owning it |
| `core.hooksPath` is already `.husky/_` | unchanged | same |
| otherwise | `.husky` | git executes `.husky/<hook>` directly; no package manager involved |

## What it writes

All writes are `--local`. This script never touches a contributor's global or system git configuration.

| Setting | Written | Note |
| `core.hooksPath` | yes | per the table above |
| `commit.gpgsign` | yes, `true` | so commits are signed when created — FR-012 |
| `gpg.format` | **no** | identifies a signing scheme the contributor chose |
| `user.signingkey` | **no** | identifies a person and a key; guessing produces commits signed by the wrong identity |
| the forge's signing-key list | **no** | registering a key on someone's account is an account-level act, not a repository one |

It also ensures `.husky/commit-msg` and `.husky/pre-push` are executable, since a non-executable hook is silently skipped by git.

## Idempotence

Running it when everything is already in place changes nothing and says so, per line: `already set` versus `set`. Exit `0` either way. FR-011.

## Output

Always reports, on stdout, in this order:

1. `core.hooksPath` — the value now, and whether this run changed it
2. `commit.gpgsign` — the value now, and whether this run changed it
3. `gpg.format` — the value, or `not configured` with one line saying what to set and that this script will not set it
4. `user.signingkey` — the value, or `not configured`, same treatment
5. `forge signing key` — whether the forge has that key registered **for signing**
6. A final line stating whether the checks are **active** or **inactive**, which is what FR-013 requires be answerable from this command's own output

Reporting `not configured` for a signing identity is not a failure and does not affect the exit status. The contributor can commit; `pre-push` is where an unsigned commit is caught, and it names the remedy there.

### `forge signing key`

Added after a signing key that pushed successfully for eighteen commits turned out never to have been registered for signing, so every commit its owner authored read `Unverified` on GitHub with reason `unknown_key`. A forge keeps **authentication** keys and **signing** keys in two separate lists and consults only the second when it verifies a commit. Nothing local can see the difference: `git verify-commit` answers from `allowed_signers` on this machine and says `Good signature` either way, and the `pre-push` check reads `%G?`, which is the same local answer.

| Reported | Meaning |
| `github: registered` / `already set` | the configured key's fingerprint is in `user/ssh_signing_keys` |
| `github: NOT registered` / `not configured` | it is not, so commits will read `Unverified`; the remedy line names the `gh ssh-key add --type signing` command |
| `(<reason>)` / `not checked` | the question could not be answered — no `gh`, no origin remote, an origin that is not GitHub, a non-SSH `gpg.format`, an unreadable key, or a forge that could not be reached |

`gh` is **optional**. Without it the line reports `not checked` and the script still requires nothing but POSIX `sh` and git, so the Principle I guarantee below is unchanged. This check never affects the exit status: the signature is real and the contributor can commit, and a non-zero exit would break the one command that diagnoses the problem.

The remedy line names a **public key file**, and only ever one whose contents it has read. `gh ssh-key add` sends whatever file it is handed without validating it locally, while `user.signingkey` may legitimately name a _private_ key — git accepts one — or hold the key material itself with no file behind it. So the remedy resolves the configured path to the public half beside it when it can, and otherwise names the command's shape and leaves the path to the contributor. It never names the configured path unread.

The account's key list is read with `--paginate`: the endpoint returns 30 per page, and a key past the first page reported as unregistered would be exactly the confident wrong answer the rest of this check is built to avoid. The call is bounded by `timeout` where that command exists, so `--status` cannot hang on a stalled network; `timeout` is not POSIX and its absence is not an error.

GitLab draws the same distinction under a `usage_type` field on `/user/keys`, but reading it needs a JSON parser this script does not require, so a GitLab origin reports `not checked` rather than half an answer.

## Exit status

| Code | Meaning |
| `0` | activation succeeded, or `--status` reported successfully |
| `1` | activation failed — a git configuration write was rejected, or a hook file is missing |
| `2` | usage error |

## Guarantees

- Requires only POSIX `sh` and git. No package manager, no virtual environment, no install step. Principle I, FR-010.
- Never removes or rewrites a hook file.
- Never runs `npm`, `npx`, `node` or `husky`.
- Never enables anything globally.

## Deactivation

Not this script's job, and deliberately so. Deactivation is `git config --unset core.hooksPath` — Husky's own documented removal step, which works identically on both paths. Documented in `docs/husky-git-hooks.md`; a repository-specific uninstall command would be a third thing to learn for no gain.
