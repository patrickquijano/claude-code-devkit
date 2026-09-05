---
paths:
  - 'docs/**'
  - 'CLAUDE.md'
---

# Authoring this repository's documentation and instructions

Reasoning and sources: [`docs/claude-code-practices.md`](../../docs/claude-code-practices.md) and
[`docs/claude-code-project-structure.md`](../../docs/claude-code-project-structure.md).

## Where a rule goes

- Repository-wide and wanted in every session: `CLAUDE.md`.
- Scoped to one area: `.claude/rules/<topic>.md` with `paths:` globs, so it loads only when those
  files are worked on.
- A multi-step procedure: a skill. A procedure written into `CLAUDE.md` is paid for in every
  session; the same procedure as a skill is paid for when it is used.

Recording the same rule in two of these is worse than recording it in none. Instruction files
concatenate rather than override, so both copies are present, they agree the day they are written,
and nothing catches the drift afterwards.

## `CLAUDE.md`

- Stays under 200 lines. Longer files consume more context and reduce adherence; a file over 4 MiB
  is skipped entirely.
- Holds only what is wanted in every session: build, test and lint commands as commands;
  conventions that differ from the tooling's defaults; pitfalls; repository-wide always/never
  rules; and the rationale behind a choice that would otherwise look arbitrary and get "fixed".
- Does not hold anything derivable by reading the code, any multi-step procedure, anything true of
  only one area, or any feature requirement.
- Has no prescribed section order. The documentation states what belongs in such a file and that
  structure should group related instructions under headers and bullets; it prescribes no ordering.
  Do not invent one, and do not reorder the existing sections while editing.
- Grows by the entry, not by the pass. Add a bullet; do not reformat, retitle or "improve" the
  surrounding file. An unrelated diff in a file every session loads buries the line that mattered.
- The trigger for adding an entry is documented: Claude made the same mistake twice, a review
  caught something Claude should have known, or you typed the same correction again.

## The one exception: a deliberate compaction pass

Everything above forbids revising a file as a side effect of other work, and that stays forbidden.
A **compaction pass** is different and is permitted: a deliberate, reviewed change whose entire
purpose is to make a document cost less to read. The distinction is not the size of the diff, it is
what the change is for — a pass that IS the change cannot bury the line that mattered, because
there is no other line.

A compaction pass MUST satisfy all of the following. A change meeting none of them is drive-by
tidying, which the rules above still forbid.

- It is the stated purpose of the change, not incidental to a feature touching the same file.
- It is audited: `sh scripts/compaction-audit.sh <baseline-ref> <path>` reports `pass`, or the
  document is recorded exempt with its reason and its actual percentage.
- It drops **no** normative content. A `fail-lost` verdict is fixed, never waived — an exemption
  covers failing the length floor and never covers losing a rule.
- Section order is still not reordered, and section titles are still not rewritten, unless the
  section itself is being removed as redundant.

### What "normative content" means

Mechanical, so that it is not decided under time pressure. Outside fenced code blocks and YAML
frontmatter, a line is normative if it carries any of: a modal obligation (`MUST`, `MUST NOT`,
`MAY`, `SHOULD`, `SHOULD NOT`); a prohibition or absolute (`never`, `always`, `only`, `forbidden`,
`no exception`, `zero`); a rationale marker (`Rationale:`, `because`, `the reason`, `which is why`,
`so that`); a named failure mode (`WARNING`, `defect`, `regression`, `silently`, `breaks`, `fails`,
`wrong`); a backticked identifier; or a numeric threshold.

**Every fenced code block is normative in its entirety** and is compared byte-for-byte.

The definition is deliberately over-broad. Flagging a line that did not need preserving costs a
reviewer a glance; missing one loses an invariant that no check in this repository would ever catch
again. Rationale markers are included because several files here record _why_ an odd-looking rule
exists precisely so a later contributor does not "fix" it, and that reasoning is the first thing a
naive compaction deletes as padding.

### The length floor

A compacted document loses **at least 15%** of its non-code, non-frontmatter, non-blank lines. A
document that cannot reach 15% without dropping a normative line is exempt, and the exemption is
recorded with the percentage actually achieved. Reasoning and the alternatives rejected:
[`specs/011-narrow-gates-pipeline-fix/research.md`](../../specs/011-narrow-gates-pipeline-fix/research.md)
decisions R1, R2 and R3.

## `docs/`

- Every claim of fact about Claude Code names the source it came from. Where no authoritative
  source settles a question, record it as a **GAP** — "no authoritative source was found", never
  "the opposite is true".
- Each document carries a Contents list, per-section source citations, and a "Recorded gaps"
  section collecting every gap its body raises.
- Each topic carries an **"In this repository"** paragraph grounding the general practice in what
  this repository actually does. That paragraph is what makes the document usable rather than a
  restatement of the upstream docs.
- Correcting an earlier claim goes in a corrections table, with what was claimed and what the
  source says. Never replace the text silently — the earlier artifacts stay as the record of what
  each feature believed and shipped.

## Markdown mechanics

- Never hard-wrap prose. `MD013` is off deliberately and Prettier's `proseWrap` is unset, so it
  preserves what you write. One line per paragraph, however long it runs.
- Never indent with a tab inside a fenced code block. `.editorconfig`'s `[*.md]` section overrides
  only `indent_size` and `trim_trailing_whitespace`, so `indent_style = space` still governs the
  fences, and the `editorconfig` check rejects the tab. Use two spaces.
- Table pipes must align with the header row: `MD060` is enabled. `sh scripts/lint.sh --fix`
  aligns them.
- Avoid `<placeholder>` inside a `sh` fence. Prettier's shell plugin parses it as a redirect and
  rewrites the line. Use a variable or a literal path instead.
- Your edits are reformatted under you by the committed `PostToolUse` hook. Re-read a file after
  editing it when the exact bytes matter.
