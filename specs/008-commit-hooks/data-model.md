# Phase 1 Data Model: Commit Message and Signature Enforcement

**Feature**: `008-commit-hooks` | **Date**: 2026-09-05

This feature has no database and no persisted records. Its "data" is four things: a configuration record, a message under examination, a set of ref updates, and the activation state of the working copy. Each is defined here with its fields, its validation rules and — where it has one — its state transitions.

## 1. Commit message rule set

**Where it lives**: `.commit-msg.conf`, repository root, POSIX `sh`-sourceable.

| Field                     | Type                                       | Value                                                          | Source      |
| ------------------------- | ------------------------------------------ | -------------------------------------------------------------- | ----------- |
| `COMMIT_MSG_TYPES`        | space-separated word list                  | `build chore ci docs feat fix perf refactor revert style test` | spec FR-004 |
| `COMMIT_MSG_SCOPE_POLICY` | one of `required`, `optional`, `forbidden` | `optional`                                                     | spec FR-004 |
| `COMMIT_MSG_MAX_SUBJECT`  | positive integer                           | `72`                                                           | spec FR-002 |

**Validation rules**:

- The file MUST exist. Its absence is fatal, not a fallback to built-in defaults — Principle V, and the same reasoning `scripts/lib/scope.sh` applies to a missing exclusion declaration: a silent default is indistinguishable from a chosen value.
- `COMMIT_MSG_TYPES` MUST be non-empty.
- `COMMIT_MSG_MAX_SUBJECT` MUST be a positive integer.
- `COMMIT_MSG_SCOPE_POLICY` MUST be one of the three named values.

**Relationships**: read by `scripts/hooks/commit-msg.sh`; quoted by `docs/husky-git-hooks.md` and `.claude/rules/husky-git-hooks.md`. It is the single source; neither document restates the values as literals it maintains separately.

## 2. Commit message under examination

**Where it comes from**: git passes the path of the message file as `$1` to `commit-msg`. The file is the message as the contributor left it, including comment lines git will later strip.

| Field            | Derivation                                                        |
| ---------------- | ----------------------------------------------------------------- |
| `subject`        | first line of the file                                            |
| `subject_length` | character count of `subject`                                      |
| `body`           | every line after the first                                        |
| `is_generated`   | true when `subject` matches a merge, revert, fixup or squash form |

**Validation rules** (applied in this order):

1. If `is_generated`, accept and stop. Spec FR-005.
2. `subject` MUST match `^(<type>)(\(<scope>\))?(!)?: <description>` where `<type>` is a member of `COMMIT_MSG_TYPES`, `<scope>` is non-empty, and `<description>` is non-empty. Spec FR-004a.
3. `subject_length` MUST be ≤ `COMMIT_MSG_MAX_SUBJECT`. Spec FR-002.
4. `body` is not examined. Spec FR-002.

**Generated-message forms recognised for rule 1**. Each prefix below is followed by a space, which is part of the test; Markdown formatting strips a trailing space from a code span, so it is stated here rather than shown:

| Form | Subject begins |
| merge | `Merge` |
| revert | `Revert` |
| fixup | `fixup!` |
| squash | `squash!` |
| amend-fixup | `amend!` |

**State transitions**: a message is `unexamined` → `accepted` or `refused`. A refused message is never modified; the contributor's editor content is preserved and git aborts the commit.

## 3. Ref update

**Where it comes from**: git writes one line per ref to `pre-push` on stdin, in the documented format `<local ref> <local oid> <remote ref> <remote oid>`.

| Field        | Meaning                                                           |
| ------------ | ----------------------------------------------------------------- |
| `local_ref`  | the ref being pushed, or `(delete)`                               |
| `local_oid`  | tip being sent, or all-zeroes for a deletion                      |
| `remote_ref` | the ref on the remote                                             |
| `remote_oid` | current remote tip, or all-zeroes when the remote has no such ref |

**Derived**: `outgoing_range` — the commits this update would add.

- `local_oid` all-zeroes → deletion; nothing to examine, accept.
- `remote_oid` all-zeroes → new ref; the range is `local_oid` limited to commits not reachable from any other remote ref.
- otherwise → `remote_oid..local_oid`.

**Validation rule**: every commit in `outgoing_range` MUST have a `%G?` status other than `N` and `B`. Spec FR-006, research §6.

| `%G?` | Meaning | Verdict |
| `G` | good signature | accept |
| `U` | good, unknown validity | accept |
| `X` | good, expired | accept |
| `Y` | good, expired key | accept |
| `R` | good, revoked key | accept |
| `E` | present, cannot check | accept |
| `B` | bad signature | **refuse** |
| `N` | no signature | **refuse** |

**State transitions**: a push is `pending` → `permitted` or `refused`. A refused push leaves every commit, ref and object untouched. Spec FR-008.

## 4. Activation state

**Where it lives**: the working copy's own git configuration. Not a file this feature writes.

| Field              | Read from                          | Values                                                             |
| ------------------ | ---------------------------------- | ------------------------------------------------------------------ |
| `hooks_path`       | `git config --get core.hooksPath`  | `.husky/_` (Husky path), `.husky` (fallback path), other, or unset |
| `signing_enabled`  | `git config --get commit.gpgsign`  | `true`, `false`, or unset                                          |
| `signature_format` | `git config --get gpg.format`      | `openpgp`, `ssh`, `x509`, or unset                                 |
| `signing_key`      | `git config --get user.signingkey` | any, or unset                                                      |

**Derived**: `active` is true when `hooks_path` is `.husky` or `.husky/_` **and** the corresponding hook file is executable.

**Rules**:

- `install-hooks.sh` MAY write `core.hooksPath` and `commit.gpgsign`.
- `install-hooks.sh` MUST NOT write `gpg.format` or `user.signingkey` — they identify a person and a key. It reports their absence. Research §7.
- All writes are `--local`: this feature never touches a contributor's global configuration.
- Running the installer when `active` is already true changes nothing and says so. Spec FR-011.

**State transitions**: `inactive` → `active` by running the installer. `active` → `inactive` by `git config --unset core.hooksPath`, which is Husky's own documented removal step and works identically on the fallback path.

## 5. Skill review finding

**Where it lives**: the feature's own record for user story 5 — an entry per finding, produced during implementation and reported at completion.

| Field            | Meaning                                  |
| ---------------- | ---------------------------------------- |
| `id`             | stable identifier within the review      |
| `skill`          | which distributed skill it concerns      |
| `evidence`       | quoted location, precise enough to check |
| `options`        | at least two, each with its cost         |
| `recommendation` | one option, with its justification       |
| `disposition`    | `approved` or `declined`                 |

**Validation rules**: `options` MUST hold at least two entries (FR-020). `disposition` MUST be set before the feature completes (FR-021, SC-007). A `declined` finding leaves the repository unchanged.
