# Contract: Command-line interface

**Date**: 2026-09-02 | **Feature**: [spec.md](../spec.md) | **Data model**: [data-model.md](../data-model.md)

This repository's external interface is a set of shell commands. This file is their contract: what each accepts, what it writes, and what it returns. It is the thing a caller — a contributor, a hook, a CI job, or an agent — is entitled to rely on.

## Common shape

Every command below:

- is executable, and is invoked as `scripts/<name>.sh` from the **repository root**;
- accepts at most one argument, `--fix`, and `-h` / `--help`;
- reads its scope from `.lintignore` and nothing else;
- writes violations to **stdout**, diagnostics about its own operation to **stderr**;
- exits `0` on pass and non-zero on fail.

Any other argument is a usage error: exit `2`, usage on stderr.

## Exit statuses

| Status | Meaning                                                                                              |
| ------ | ---------------------------------------------------------------------------------------------------- |
| `0`    | The check passed. In `--fix` mode, this also covers "violations were found and rewritten" (FR-005a). |
| `1`    | The check ran and found violations it did not fix.                                                   |
| `2`    | Usage error — an unrecognised argument.                                                              |
| `3`    | Neither the native tool nor the container runtime was available (FR-011). Both are named on stderr.  |
| `4`    | The repository is not a git working tree, so the file list cannot be computed.                       |

A caller may treat any non-zero status as failure. The distinct codes exist so that a caller who wants to tell "your Markdown is wrong" from "you have no Docker" can.

## `scripts/lint.sh` — aggregate entry point

```text
scripts/lint.sh [--fix]
```

Runs every check in this fixed order: `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python`.

**Guarantees**

- Stops at the first check that returns non-zero (FR-007). Later checks do not run.
- Returns the exit status of the failing check, unchanged.
- Returns `0` only when every check returned `0`.
- With no arguments, **modifies no file** (SC-007).
- Order is declared in the script, not derived from a directory listing, so two runs on the same tree fail at the same place.

**Output**

One line per check as it starts, naming the check and how its tool resolved:

```text
==> editorconfig (native: editorconfig-checker)
==> format (container: node:22-alpine@sha256:...)
```

On failure, the tool's own output, unmodified, followed by one line naming the failing check.

`--fix` is passed through to every check.

## `scripts/lint-<standard>.sh` — per-standard checks

```text
scripts/lint-markdown.sh      [--fix]
scripts/lint-yaml.sh          [--fix]
scripts/lint-shell.sh         [--fix]
scripts/lint-python.sh        [--fix]
scripts/lint-format.sh        [--fix]
scripts/lint-editorconfig.sh  [--fix]
scripts/lint-scope.sh
```

**Guarantees, every one of them**

- Runnable standalone from the repository root with no arguments (FR-003).
- Same verdict whether the tool resolved native or containerised (FR-008).
- Prefers the native tool when it is present (FR-009).
- Names the file — and the line, where the tool reports lines — of every violation (FR-006).
- With no arguments, modifies no file. In container mode this is enforced by a read-only mount, not by trusting the tool.
- Empty file list → exit `0` and print `no files in scope`.
- Declares its own skipped paths in its own configuration, so a by-hand invocation of the underlying tool sees the same scope (FR-013a). The exception is `lint-shell.sh`: ShellCheck has no path-exclusion directive, and `lint-scope.sh` reports that on every run rather than counting it as agreement (FR-013c).

**`--fix` behaviour, per standard**

| Script                 | `--fix` does                                                                                                                                |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `lint-markdown.sh`     | `markdownlint-cli2 --fix`; rewrites what the rules can fix, reports the rest and exits non-zero if any remain                               |
| `lint-python.sh`       | `ruff check --fix` then `ruff format`; same rule for anything left                                                                          |
| `lint-format.sh`       | `prettier --write`                                                                                                                          |
| `lint-yaml.sh`         | prints `no automatic fix available for yaml; run without --fix to see violations`, changes nothing, exits `0` if the check passes (FR-012a) |
| `lint-shell.sh`        | as above, for shell                                                                                                                         |
| `lint-editorconfig.sh` | as above, for whitespace                                                                                                                    |

A `--fix` invocation that rewrites files and leaves nothing unresolved exits `0`.

`lint-scope.sh` takes **no** `--fix`: there is nothing it could rewrite that would not be a guess about which of two declarations is right. Invoked with `--fix` it reports that and exits `0` if the comparison passes, exactly as the three checks with no automatic fix do.

**Add-on components on the format check.** `lint-format.sh` prints one line naming each declared plugin and how it resolved:

```text
==> lint-format.sh (native: prettier) plugins: @prettier/plugin-xml=native prettier-plugin-sh=absent
==> lint-format.sh: shell files routed to the container path (prettier-plugin-sh absent natively)
```

The guarantee is that a resolved component and an absent one never produce the same output. An absent component sends its content kind to the container path, where the plugin is pinned — not a warning, and not a failure (FR-023). Absent _and_ no container reachable is FR-011's hard failure, naming both, and the aggregate stops.

## `scripts/lint-scope.sh` — the six declarations agree

```text
scripts/lint-scope.sh
```

Exists because FR-013a distributes the scope declaration across six configurations and FR-013b requires they nonetheless agree. Under the previous single declaration this script would have had nothing to compare.

**Guarantees**

- For each check, compares the files `.lintignore` puts in scope for that content kind against the files the tool itself reports it would visit. Exit `1` and name the differing paths on any mismatch.
- Where a tool can be asked what it would visit, it is asked. Where it cannot, the declaration is compared textually against `.lintignore` and the weaker guarantee is stated in the output.
- Where a tool has no exclusion mechanism at all — the shell check — reports it as unverifiable, on every run, and does not count it as agreeing.
- Part of the aggregate run, so a divergence fails `scripts/lint.sh` rather than waiting for someone to run it.

## `scripts/selftest.sh` — proof the checks can fail

```text
scripts/selftest.sh
```

For each standard, materialises a deliberately non-conforming file in a temporary directory outside the repository tree, runs that standard's check against it, and asserts the check exits non-zero and names the file.

**Guarantees**

- Creates nothing inside the repository. Fixtures live in `$(mktemp -d)` and are removed by an `EXIT` trap.
- Exits `0` only if **every** check failed on its bad fixture — a check that passes bad input is the failure this script exists to catch.
- Names any standard whose check did not fail.

This is what makes SC-002 a measurement rather than an assertion.

## Environment

| Variable               | Effect                                                                                                                                                                                                            |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NO_COLOR`             | Any non-empty value suppresses colour in the runners' own output. Tool output is passed through unchanged.                                                                                                        |
| `LINT_FORCE_CONTAINER` | Any non-empty value skips native resolution and goes straight to the container. Exists so `selftest.sh` and a reviewer can verify FR-008 — that both paths give the same verdict — without uninstalling anything. |

No other variable is read. Nothing is written to the environment.

## Stability

The exit statuses, the two environment variables, and the `--fix` flag are the contract. So is the fact that `lint-format.sh` reports plugin resolution: a caller may rely on an absent add-on being distinguishable from a clean run, though not on the exact wording. The check order in `lint.sh`, the per-line output format, and the image references are implementation detail and may change without notice — a caller that parses the runners' own output rather than reading the exit status is relying on something this contract does not promise.
