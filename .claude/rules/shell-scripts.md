---
paths:
  - '**/*.sh'
---

# Writing a shell script in this repository

The verdict is `sh scripts/lint-shell.sh`, which runs `shellcheck` with `shell=sh` and
`severity=style`. Zero findings, no exceptions.

## Dialect

- POSIX `sh`, IEEE Std 1003.1. No `[[ ]]`, no arrays, no `<<<`, no `set -o pipefail`, no `which`.
- Start with `#!/bin/sh`, then `set -eu` — or `set -u` alone when the script inspects and returns
  every exit status itself, as the `ccd-conflict-resolve` scripts do.
- Indent with tabs. `<<-` heredocs strip leading tabs and nothing else, so tabs are the only
  indentation that survives inside one.

## The four opt-in ShellCheck rules

`.shellcheckrc` enables four checks beyond the defaults, each catching something the others miss.
Two of them reject code that looks correct:

- `check-extra-masked-returns` (SC2312) — a command substitution whose exit status is discarded is
  a finding. Assign the output to a variable on its own line first, with `|| true` when a non-zero
  status is expected, then use the variable.
- `add-default-case` (SC2249) — every `case` needs a `*)` branch. An unhandled branch is a silent
  no-op.

The other two are `check-set-e-suppressed` and `deprecate-which`.

## Failing

Exit non-zero at the first failing step, and never mask a status behind a pipeline or a subshell.
A script that reports success after a step failed is the defect the whole check exists to prevent.

## Shipping a script with a skill

Scripts live in the owning skill's own `scripts/` directory and are invoked as
`sh "${CLAUDE_SKILL_DIR}/scripts/<name>.sh"` — see
[`.claude/rules/skill-authoring.md`](skill-authoring.md). There is no top-level `bin/`.
