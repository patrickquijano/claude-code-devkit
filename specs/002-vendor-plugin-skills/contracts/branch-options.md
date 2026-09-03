# Contract: `branch-options.sh`

**Feature**: [../spec.md](../spec.md) | **Research**: [../research.md](../research.md) §6

> **Superseded** by [`specs/003-ccd-skill-rename/contracts/branch-options.md`](../../003-ccd-skill-rename/contracts/branch-options.md), which moved the helper to `skills/ccd-branch-push/scripts/branch-options.sh` without changing the script. The path below is a true record of what shipped under this feature and is no longer current.

The one shared helper, distributed once and consumed by four skills. This file states the contract the four rely on, because until this feature they relied on four separate implementations of it and one of them did not honour it.

## Location and invocation

```text
skills/auto-branch-push/scripts/branch-options.sh
```

| Consumer           | Invocation                                                                   |
| ------------------ | ---------------------------------------------------------------------------- |
| `auto-branch-push` | `sh ${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh` |
| `auto-github-pr`   | same path                                                                    |
| `auto-gitlab-mr`   | same path                                                                    |
| `speckit-run`      | same path                                                                    |

`sh` is explicit in every case, because the executable bit is not documented to survive installation and the skills were already written not to rely on it.

## Output

Tab-separated, one branch per line, no header.

| Column | Value                                                                                                    |
| ------ | -------------------------------------------------------------------------------------------------------- |
| 1      | branch name, remote prefix stripped                                                                      |
| 2      | `local`, `remote`, or `both`                                                                             |
| 3      | last commit date, `YYYY-MM-DD`                                                                           |
| 4      | `<tags>` -- a comma-joined subset of `default` and `current`, in that order, or `-` when neither applies |

Order: the repository's default branch first, then by commit date descending, then by name.

Example, from this repository during this feature's delivery:

```text
main	both	2026-09-02	default
002-vendor-plugin-skills	local	2026-09-02	current
chore/unwrap-md-and-push-autosetupremote	local	2026-07-30	-
chore/install-official-plugins	local	2026-07-28	-
```

**Guarantees**

- Every line names a branch. Symbolic refs are excluded -- specifically `refs/remotes/<remote>/HEAD`, which git's short form renders as a bare remote name indistinguishable from a branch called `origin`.
- The default branch is resolved from `refs/remotes/origin/HEAD`, falling back to the first of `main`, `master`, `develop` that exists, and then to no branch tagged `default`.
- The current branch is resolved with `git symbolic-ref --short -q HEAD`: empty on a detached HEAD, and still correct on an unborn HEAD.
- Read-only with respect to the working tree. It fetches every configured remote first so remote-only branches are current.
- A failed fetch goes to stderr as `fetch-failed: <remote> (listing continues from local refs)` and the listing continues from refs already on disk.
- Exit 1, with a message, when not inside a git work tree. Exit 0 with an empty listing is legitimate -- a repository with no branches and no remotes.

**Consumer conventions**, not enforced by the script: take the first four lines for a question's option set; the asking tool supplies its own "Other" entry for anything beyond them.

## What changed, and what a reader should not expect

This is the 88-line implementation the three `auto-*` skills shared (`md5 70edb6aeff4841a992b13a0a66ba0ac0`). The 48-line implementation `speckit-run` carried (`md5 c92eb52d812fdd6232e2e84740180843`) is **not** the contract, and three of its behaviours are gone:

| Old behaviour                                                     | Now                                               |
| ----------------------------------------------------------------- | ------------------------------------------------- |
| column 4 was `current` or `-`                                     | `default`/`current` tags, or `-`                  |
| order was commit date descending only                             | default branch first, then commit date descending |
| `refs/remotes/origin/HEAD` was emitted as a branch named `origin` | excluded                                          |
| current branch lost on an unborn HEAD                             | resolved correctly                                |

`speckit-run`'s `reference/base-branch.md` documented the old column 4 as a "`current` marker" and the old order as "Newest first". Both sentences are corrected by this feature, traceable to FR-011.

## Verification

The three drift-detection scenarios that compared copies with `cmp -s` have nothing left to compare, and are replaced rather than deleted. What is checked instead:

- **One implementation exists** in the distributed tree: `find skills -name branch-options.sh` returns exactly 1 path (SC-004).
- **Every consumer's reference resolves** to that path: 4 of 4 (FR-012).
- **All consumers see the same candidates**: for one repository state, the output is identical for every consumer, because there is one script and one invocation (SC-005, 0 differences). This is now true by construction rather than by comparison, which is the point of the change.
