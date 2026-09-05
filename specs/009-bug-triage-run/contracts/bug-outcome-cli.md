# Contract: `bug-outcome.sh`

Ships at `skills/ccd-speckit-bug-run/scripts/bug-outcome.sh`. Invoked as `sh "${CLAUDE_SKILL_DIR}/scripts/bug-outcome.sh" <bug-dir>`.

Reports which of the three reports exist in a bug directory, and what outcome each one records. This is the determinism point for FR-016: the run's closing report is drawn from this script's output, never from recollection of what a stage said in conversation.

## Arguments

| Position | Meaning                                               | Required |
| -------- | ----------------------------------------------------- | -------- |
| `$1`     | the bug directory, e.g. `.specify/bugs/login-timeout` | yes      |

Missing or unreadable → exit 1 with a message on stderr. Nothing is guessed.

## Output

Tab-separated `key<TAB>value` lines on stdout. Stable key order. One line per fact.

```text
bug-dir	.specify/bugs/login-timeout
assessment	present
fix	present
test	absent
verdict	valid
severity	high
status	partial
result	unknown
```

### Keys

| Key                         | Values                                                            | Source                             |
| --------------------------- | ----------------------------------------------------------------- | ---------------------------------- |
| `bug-dir`                   | the path as given                                                 | —                                  |
| `assessment`, `fix`, `test` | `present`, `absent`                                               | one line each, always all three    |
| `verdict`                   | `valid`, `likely valid, needs reproduction`, `invalid`, `unknown` | `**Verdict**:` in `assessment.md`  |
| `severity`                  | `critical`, `high`, `medium`, `low`, `unknown`                    | `**Severity**:` in `assessment.md` |
| `status`                    | `applied`, `partial`, `not-applied`, `unknown`                    | `**Status**:` in `fix.md`          |
| `result`                    | `verified`, `partial`, `failed`, `unknown`                        | `**Result**:` in `test.md`         |

A field whose report is `absent` is `unknown`, not omitted. Every key is always printed, so a caller can distinguish "not yet run" from "ran and produced nothing readable" only by reading the report's own `present`/`absent` line alongside it — which is why both are always emitted.

## `unknown` is a stop, never a default

`unknown` is printed when the label is missing, when the line is unparseable, **and when the value found is outside its vocabulary**. The script never picks the nearest legal value and never infers one from surrounding prose.

The caller stops on `unknown` for a report that is `present`. It does not branch, does not assume the benign value, and does not re-read the file itself to "check". A `present` report whose outcome cannot be read means the extraction contract has drifted, which is a condition for a human to look at.

This matters because the labels are Markdown emitted by the extension's output templates, not a published schema — see [research.md G3](../research.md#recorded-gaps). The dependency is real and is accepted deliberately; `unknown` is how it fails loudly instead of quietly.

## Matching

The value is whatever follows the label on its line, with surrounding whitespace and any trailing punctuation stripped, lowercased for comparison against the vocabulary. Matching is on the **first** occurrence of each label in its file, because the templates emit each field once and a later occurrence is prose quoting the field rather than declaring it.

## Exit status

`0` when the directory was readable and the scan completed, whatever it found — including when every field is `unknown`. `1` only when `$1` is missing or is not a readable directory.

**Exit status is not the outcome.** A run whose assessment is `invalid` exits `0`; so does one whose reports are all unreadable. Read the lines.

## Behaviour

- **Read-only.** Opens three files for reading and writes nothing.
- **Fails fast.** `set -e`; no masked statuses (Principle II).
- **POSIX `sh`.** `shellcheck -s sh` clean (Principle IV). `grep` and `sed` only — no `awk` arrays, no bashisms.
- **No package manager** (Principle I).

## What the caller does with it

| Situation                                  | Caller's obligation                                                                                 |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| a report is `absent` after its stage ran   | Do not record that stage `done` — FR-015                                                            |
| `verdict invalid`                          | Skip Stage 2 and Stage 3, announcing each with the reason — FR-007                                  |
| `verdict likely valid, needs reproduction` | Proceed to Stage 2, and state at its boundary that the defect was not reproduced — FR-007           |
| `status not-applied`                       | Skip Stage 3 with the reason — FR-008                                                               |
| `status partial`                           | Proceed to Stage 3, carry the status into the closing report — FR-008                               |
| `result partial` or `failed`               | Stop, present the finding, put the choice to the maintainer, do not report success — FR-010, FR-028 |
| any `unknown` on a `present` report        | Stop and report the drift. Never branch on a guess                                                  |

## Regressions this contract exists to catch

**Defaulting `unknown`.** Someone decides an unreadable verdict "probably means valid" and lets the run continue. That converts a loud failure into a source edit nobody authorised.

**Dropping the `present`/`absent` lines** on the grounds that `unknown` implies absence. It does not: a present-but-unreadable report and an absent one are different problems, and only the first indicates drift.

**Matching the last occurrence** rather than the first, or matching without anchoring to the label, so that prose in a report body quoting `**Result**: failed` overrides the declared field.

**Adding a fourth vocabulary value** because a run encountered one. The vocabularies belong to the extension; a new value means the extension changed, and the change is what needs reviewing.
