# Contract: the check-script command-line interface, amended

**Date**: 2026-09-03 | **Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md)

Amends `specs/001-quality-gate-plugin/contracts/cli.md`. That document remains the contract for everything not restated here; where the two differ, this one governs for the checks that survive this feature, and `cli.md` is edited to match rather than left standing.

## What changes

Three things, and nothing else.

1. Every check script accepts an **optional trailing path list**, introduced by `--`.
2. `scripts/lint-scope.sh` **no longer exists**, and the aggregate runs seven checks rather than eight.
3. A check's scope no longer comes from `.lintignore`. It comes from that check's own configuration — see [exclusion-declaration.md](./exclusion-declaration.md).

Everything else in `cli.md`'s Common shape holds unchanged: invoked as `scripts/<name>.sh` from the repository root, violations on stdout, diagnostics on stderr, `0` on pass and non-zero on fail.

## Amended shape

```text
scripts/lint.sh            [--fix] [-- PATH...]
scripts/lint-<check>.sh    [--fix] [-- PATH...]
```

- `--fix` — unchanged. Rewrite files into conformance where the tool supports it.
- `-h`, `--help` — unchanged. Usage on stdout, exit `0`.
- `-- PATH...` — **new.** Narrow this run to the named paths.

`--` is the POSIX end-of-options marker, so a path beginning with `-` cannot be mistaken for a flag. Every argument after `--` is a path; none is interpreted.

**Any other argument remains a usage error**: exit `2`, usage on stderr. That rule is unchanged; it now applies to arguments before `--` only.

## Semantics of the path list

The path list **narrows** the run. It never widens it.

```text
files examined  =  git ls-files (cached + others, respecting .gitignore)
                 ∩  this check's own globs
                 ∖  this check's own exclusion declaration
                 ∩  PATH...                                (when given)
```

This is a filter applied to the file list the check already computes — **not** a substitute for computing it. The distinction is the whole contract:

- A path outside the check's globs is **not** examined. `scripts/lint-python.sh --fix -- README.md` formats nothing.
- A path the check's own declaration excludes is **not** examined, however explicitly it was named. A caller cannot reach an excluded file by naming it.
- A path that does not exist, or that git does not enumerate, is **not** examined.
- A path outside the repository is **not** examined.

A caller who wants to know whether a path was examined reads the exit status and the output, not the arguments it passed.

**Relative or absolute**, both accepted; both are resolved against the repository root before filtering, so `scripts/lint-markdown.sh --fix -- ./README.md` and the absolute form behave identically.

**Repeatable**: any number of paths. Order is not significant.

## Exit statuses

Unchanged from `cli.md`, with one clarification and no new codes.

| Status | Meaning |
| `0` | The check passed. In `--fix` mode this also covers "violations were found and rewritten". **Also covers a path list that matched nothing** — see below. |
| `1` | The check ran and found violations it did not fix. |
| `2` | Usage error — an unrecognised argument before `--`. |
| `3` | Neither the native tool nor the container runtime was available. Both are named on stderr. |
| `4` | The repository is not a git working tree, so the file list cannot be computed. |

**A path list that matches nothing is `0`, not `1` and not `2`.** The check prints its existing `no files in scope` line and exits `0` (`scripts/lib/common.sh:144-150`). This is deliberate and it is what makes three of the feature's safety requirements fall out of existing code rather than needing new logic: an excluded path (FR-006), an unsupported file kind (FR-007), and a path outside a check's globs all arrive here.

A caller that needs to distinguish "nothing to do" from "passed" must read the message, not the status. Nothing in this repository needs that distinction.

## Backward compatibility

Guaranteed, and mechanically checked.

- **No arguments**: identical behaviour to before this feature — same file list, same verdict, same output. Required by FR-017; proved per check by the before/after comparison in [quickstart.md](../quickstart.md) scenario 1.
- **Bare `--fix`**: likewise identical.
- The constitution's "Each check MUST be runnable from the repository root without arguments" is untouched: the path list is optional and trailing.

## The aggregate

`scripts/lint.sh` runs seven checks in this fixed order:

```text
citations  editorconfig  format  markdown  yaml  shell  python
```

`scope` is gone. The ordering rationale in `lint.sh`'s comment survives minus its `scope` paragraph: `citations` still leads because it needs no tool, so a stale governance quotation is reported before a container is pulled to check whitespace.

**Guarantees**, unchanged:

- Stops at the first check that returns non-zero. Later checks do not run.
- Returns the failing check's exit status, unchanged.
- Returns `0` only when every check returned `0`.
- With no arguments, modifies no file.
- The order is declared in the script, not derived from a directory listing, so two runs on the same tree fail at the same place.

**With a path list**, `lint.sh` passes it through to each check unchanged. Each check then self-filters by its own globs and its own exclusions, so `scripts/lint.sh --fix -- README.md` runs seven checks of which one or two do any work and the rest report `no files in scope` and exit `0`. That is the intended behaviour and is what `scripts/format-file.sh` relies on, except that the hook invokes the three rewriting checks directly rather than the aggregate — because the aggregate would also run the four report-only checks and fail the edit on violations it did not cause (FR-004).

## Removed: `scripts/lint-scope.sh`

Deleted. It compared six declarations of the same exclusion list and failed naming any divergence. With one declaration per check there is no second copy to diverge from, so the check has nothing left to compare — see [exclusion-declaration.md](./exclusion-declaration.md).

Its six extraction functions are **not** deleted. They are promoted into `scripts/lib/scope.sh` and become the source of each check's file list.

Callers that invoked `scripts/lint-scope.sh` get the usual shell "No such file or directory" and a non-zero status. There is no shim, and no deprecation period: this repository is the only caller, and `scripts/lint.sh` is updated in the same change.

## Reserved

`scripts/format-file.sh` has a different contract — it is a hook entry point, reads JSON on stdin, and takes no arguments. See [format-file-cli.md](./format-file-cli.md). It is deliberately **not** part of the shape above, and does not accept `--fix` or a path list.
