# Contract: `.commit-msg.conf`

The single committed declaration of the commit-message rule set. Repository root, POSIX `sh`-sourceable.

Principle V requires every linter be driven by a committed configuration file at a documented path; the Quality Gate Requirements allow one linting configuration per content kind. Commit messages are a content kind this repository did not previously govern, and this is its only linting configuration. It has no formatter.

## Format

`sh` assignments, one per line, with comments. Sourced with `.` by `scripts/hooks/commit-msg.sh`, and readable at a glance by a person. Not JSON and not YAML: the consumer is POSIX `sh`, and Principle I forbids requiring a parser that is not already there.

```sh
# Permitted commit types. Space-separated, in a single word.
COMMIT_MSG_TYPES='build chore ci docs feat fix perf refactor revert style test'

# Scope policy: required | optional | forbidden
COMMIT_MSG_SCOPE_POLICY='optional'

# Maximum length of the first line, in characters.
COMMIT_MSG_MAX_SUBJECT='72'
```

## Fields

| Name | Type | Required | Value | Requirement |
| `COMMIT_MSG_TYPES` | space-separated words | yes | the eleven Angular types | FR-004 |
| `COMMIT_MSG_SCOPE_POLICY` | `required` \| `optional` \| `forbidden` | yes | `optional` | FR-004 |
| `COMMIT_MSG_MAX_SUBJECT` | positive integer | yes | `72` | FR-002 |

## Validation

The consumer validates before using:

- File missing or unreadable → exit `2`, naming the file. **Never** fall back to built-in defaults; a silent default is indistinguishable from a chosen value, and this is the same rule `scripts/lib/scope.sh` applies to a missing exclusion declaration.
- `COMMIT_MSG_TYPES` empty → exit `2`.
- `COMMIT_MSG_MAX_SUBJECT` not a positive integer → exit `2`.
- `COMMIT_MSG_SCOPE_POLICY` not one of the three → exit `2`.

## Consumers

| Consumer | Reads it how |
| `scripts/hooks/commit-msg.sh` | sources it |
| `docs/husky-git-hooks.md` | cites it as the authority; does not restate the values as literals it maintains separately |
| `.claude/rules/husky-git-hooks.md` | same |

## Changing the rules

Editing this file changes the rules for every contributor at their next commit — no code change, no reinstall, no `npm install`. That is the point of Principle V's "documented path": the decision is in one visible place rather than distributed through a script.

Widening `COMMIT_MSG_TYPES` is backward-compatible. Narrowing it, or lowering `COMMIT_MSG_MAX_SUBJECT`, refuses messages that were previously acceptable and should be proposed rather than merged quietly — existing history is never re-examined, but contributors' habits are.
