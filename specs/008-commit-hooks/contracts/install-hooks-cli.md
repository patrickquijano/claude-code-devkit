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

It also ensures `.husky/commit-msg` and `.husky/pre-push` are executable, since a non-executable hook is silently skipped by git.

## Idempotence

Running it when everything is already in place changes nothing and says so, per line: `already set` versus `set`. Exit `0` either way. FR-011.

## Output

Always reports, on stdout, in this order:

1. `core.hooksPath` — the value now, and whether this run changed it
2. `commit.gpgsign` — the value now, and whether this run changed it
3. `gpg.format` — the value, or `not configured` with one line saying what to set and that this script will not set it
4. `user.signingkey` — the value, or `not configured`, same treatment
5. A final line stating whether the checks are **active** or **inactive**, which is what FR-013 requires be answerable from this command's own output

Reporting `not configured` for a signing identity is not a failure and does not affect the exit status. The contributor can commit; `pre-push` is where an unsigned commit is caught, and it names the remedy there.

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
