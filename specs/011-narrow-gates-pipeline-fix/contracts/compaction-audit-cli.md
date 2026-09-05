# Contract: `scripts/compaction-audit.sh`

**Feature**: `011-narrow-gates-pipeline-fix` | **Date**: 2026-09-05

A review aid that turns FR-028, FR-029, FR-031 and SC-010 from judgement calls into a command with output. It answers one question about one document: **did this compaction lose anything normative, and did it actually shorten the file?**

**It is not a `lint.sh` check.** The quality gate stays at seven checks, for the reasons in `research.md` R3.

## Invocation

```sh
sh scripts/compaction-audit.sh <baseline-ref> <path>
```

| Argument         | Meaning                                                                                  |
| ---------------- | ---------------------------------------------------------------------------------------- |
| `<baseline-ref>` | any git ref resolving to the pre-compaction version, typically the feature's base commit |
| `<path>`         | repository-relative path to one document                                                 |

Both required. Wrong argument count → usage on stderr, exit 2.

Compares the document at `<baseline-ref>` against the **working tree**, not against `HEAD`, so it can be run mid-edit before anything is committed.

## What counts as a line

Before any comparison, both versions are reduced identically:

1. YAML frontmatter — the leading `---` block — is removed.
2. Fenced code blocks are **extracted, not discarded** (see below), then removed from the prose stream.
3. Blank lines are dropped.

What remains is the **prose stream**, and it is what the R2 percentage is measured on.

## Normative extraction (R1)

A prose-stream line is normative if it matches any of:

| Class                   | Pattern                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| Modal obligation        | `MUST`, `MUST NOT`, `MAY`, `SHOULD`, `SHOULD NOT` (case-sensitive)                                |
| Prohibition or absolute | `never`, `Never`, `always`, `Always`, `only`, `forbidden`, `not optional`, `no exception`, `zero` |
| Rationale marker        | `Rationale:`, `because`, `the reason`, `which is why`, `so that`                                  |
| Failure mode            | `WARNING`, `defect`, `regression`, `silently`, `breaks`, `fails`, `wrong`                         |
| Identifier              | any backtick-quoted span                                                                          |
| Threshold               | any digit sequence, or `three`, `ten`                                                             |

**Every fenced code block is normative in its entirety**, compared byte-for-byte and never reworded. A code block present in the baseline and absent or altered in the working tree is a loss, whatever the prose says.

Comparison is by **normalized line content** — leading and trailing whitespace collapsed, list markers stripped — so that re-indenting a rule or moving it between a bullet and a table row is not reported as a loss. Reordering is not a loss. Deletion is.

## Output

Tab-separated `key<TAB>value` lines on stdout, in this order. Machine-readable and stable; **read the `verdict` line, never the exit status alone.**

```text
path        .claude/rules/repository-docs.md
baseline    a96e95f
lines-before        61
lines-after         49
chars-before        4233
chars-after         3421
reduction-pct       19
normative-before    38
normative-after     38
normative-lost      0
verdict     pass
```

**`reduction-pct` is computed from the characters, not from the lines.** `chars-before` and `chars-after` are the pair the verdict turns on; `lines-before` and `lines-after` are reported for orientation and nothing reads them. The unit is characters because this repository forbids hard-wrapping prose, so a compaction pass shortens lines rather than removing them — the reasoning and the measurement that forced the change are in [`../research.md`](../research.md) decision R2.

When `normative-lost` is non-zero, each lost line follows, one per line, prefixed `lost<TAB>`:

```text
lost        - Never hard-wrap prose. `MD013` is off deliberately …
```

## Verdicts

| `verdict`    | Condition                                                 | Exit |
| ------------ | --------------------------------------------------------- | ---- |
| `pass`       | `normative-lost` is 0 **and** `reduction-pct` ≥ 15        | 0    |
| `fail-lost`  | `normative-lost` > 0                                      | 1    |
| `fail-short` | `normative-lost` is 0 but `reduction-pct` < 15            | 1    |
| `unreadable` | path missing in the working tree, or ref does not resolve | 3    |

**`fail-lost` is never waivable.** An exemption under FR-030 covers failing the threshold — `fail-short` — and never losing a rule. A document that cannot reach 15% without dropping a normative line is recorded exempt with its actual percentage and reason; a document that dropped one is fixed.

`fail-short` on a file whose prose stream is under 20 lines is expected rather than interesting: there is little to remove. Record the exemption and move on.

## Behaviour

- POSIX `sh`, `#!/bin/sh` then `set -eu`, tab-indented. Zero `shellcheck` findings under `shell=sh` with the four opt-in rules — including `SC2312`, so every command substitution assigns to a variable on its own line before use.
- Exits non-zero at the first failing step and masks no status behind a pipeline or subshell (Principle II).
- Needs only POSIX `sh` and `git`. No package manager, no virtual environment, no install step (Principle I).
- Reads only. Writes no file, creates no temporary file outside `${TMPDIR:-/tmp}`, and never modifies the document.
- Deterministic: the same two versions produce the same output every run.

## Self-test

`scripts/selftest.sh` gains a fixture proving the script **rejects bad input**, which is that script's whole purpose:

1. A document with a `MUST` line removed → `fail-lost`, exit 1, and the lost line appears in the output.
2. A document with only blank lines removed → `fail-short`, exit 1.
3. A document with 20% of non-normative prose removed → `pass`, exit 0.
4. A code block altered by one character → `fail-lost`, exit 1.
5. A missing path → `unreadable`, exit 3.

A fixture that only proves the pass case proves nothing; case 1 and case 4 are the ones that matter, because they are the failures the whole feature is guarding against.

## Prohibited

- Wiring it into `scripts/lint.sh` or the `PostToolUse` format hook.
- Widening the R1 pattern set to make a stubborn document pass.
- Reporting `pass` with a non-empty `normative-lost`.
- Treating a reordered line as lost, or a reworded code block as equivalent.
