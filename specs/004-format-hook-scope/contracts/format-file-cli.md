# Contract: `scripts/format-file.sh`

**Date**: 2026-09-03 | **Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md)

The hook entry point. Deliberately **not** part of the check-script shape in [check-cli.md](./check-cli.md): it takes no arguments, reads JSON on stdin, and its exit statuses mean something different because its caller is the Claude Code hook runner rather than a contributor or the aggregate.

## Invocation

```text
scripts/format-file.sh          # arguments: none. Input: JSON on stdin.
```

Configured in `.claude/settings.json`, committed:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/scripts/format-file.sh",
            "args": []
          }
        ]
      }
    ]
  }
}
```

Three parts of that block are load-bearing:

- **`args: []`** selects exec form. The script is spawned directly with no shell, so no value from the payload is ever shell-interpreted. Omitting `args` would select shell form and reintroduce quoting as a live concern.
- **`${CLAUDE_PROJECT_DIR}`**, never a literal path. A hardcoded absolute path is correct on exactly one machine and silently breaks the hook everywhere else.
- **The matcher** is a pipe-separated set of exact tool names. It must not include `Bash`: `PostToolUse` on `Bash` carries a command string rather than a file path, and would fire on every shell command in the session.

Any argument passed to the script is ignored rather than rejected. The hook runner supplies none, and a script that fails on an argument it will never receive fails only in the one place it is hard to debug.

## Input

One JSON object on stdin, as delivered by the hook runner. Exactly one field is read:

| Field | Read | Treatment |
| `tool_input.file_path` | yes | Untrusted. A **candidate** path, not a path, until it has passed every rule under Path rules |
| everything else | no | `cwd` is ignored deliberately — see below |

**`cwd` is not read.** The reference states that `${CLAUDE_PROJECT_DIR}` stays at the project root while `cwd` follows the session into a worktree. This script resolves the repository root from its own location on disk (`cd -- "$SCRIPT_DIR/.." && pwd`), the same way every other script in `scripts/` does, so the hook, the checks and the configuration always agree on which tree they are in. The consequence is recorded in research.md §5: a session working in a separate worktree gets the project-root script and the project-root containment test, so a path inside that worktree is refused rather than formatted against the wrong configuration.

**Extraction** uses `sed`, not `jq` and not `python3`. Principle I forbids making a global install a precondition, and this path runs after every edit. The single blind spot — a path containing an escaped double quote yields a truncated value — is safe by construction: a truncated path fails the must-exist-and-be-a-regular-file rule and is refused. Full reasoning in research.md §4.

## Path rules

Applied in this order. The **first** rule that rejects ends the invocation with exit `0` and no output.

| # | Rule | Rejects |
| 1 | `tool_input.file_path` present and non-empty | a payload this hook does not understand |
| 2 | the directory portion can be entered | a path whose parent no longer exists |
| 3 | resolved with `pwd -P`, the path is prefixed by `<repo root>/` | anything whose directory portion is outside the repository |
| 4 | the path exists | a file just deleted, or one that never existed |
| 5 | the path is not a symbolic link | a symlink, wherever it points — including one inside the repository resolving outward |
| 6 | the path is a regular file | a directory, a device node, a socket, a FIFO |
| 7 | no NUL byte in the first 8 KiB | binary content |

**Rejection is exit `0`, silent.** It is a normal outcome, not a failure: FR-008 requires it, and `PostToolUse` cannot undo the edit anyway, so a non-zero exit here would report a problem nobody can act on.

**No rejection writes anything, anywhere**, inside the repository or out.

The containment test in rule 3 includes the trailing `/`, so a sibling directory whose name merely begins with this repository's name cannot pass.

**Rule 3 alone does not stop a symlink**, which is why rule 5 exists. Rule 3 resolves the _directory_ portion; a link whose parent directory is genuinely inside the repository passes containment while its final component still points anywhere at all, and `-f` in rule 6 would follow it. Rule 5 refuses the link rather than resolving it: resolution would need `readlink`, which is not POSIX and whose `-f` the macOS build lacks, and Prettier refuses a symlink argument outright — so following one would turn an ordinary edit into an exit `2` instead of a silent skip. A symlink pointing inside the repository loses nothing, because editing the file it points at formats it through its real path.

## Behaviour on an eligible path

Invoke three checks, in this order, each with the resolved absolute path:

```text
scripts/lint-format.sh   --fix -- <path>
scripts/lint-markdown.sh --fix -- <path>
scripts/lint-python.sh   --fix -- <path>
```

- **Only these three.** They are the checks that can rewrite; the other four report and cannot fix, so invoking them per edit would fail the session on violations the edit did not cause (FR-004).
- **This order**, taken from `scripts/lint.sh`'s own `CHECKS`. It matters for Markdown, which both `format` and `markdown` govern: Prettier first, then markdownlint over the 22 rules `.markdownlint-cli2.jsonc` leaves it. There is one order in the repository, not two (FR-005).
- **No file-kind test in this script.** Each check's `collect` already declares its globs and exits `0` with `no files in scope` when the path is not its business. The mapping stays in the one place that owns it.
- **Stop at the first stopping status.** The remaining checks do not run (Principle II).

## Output

Two audiences, two channels, both as documented for `PostToolUse`.

**To the contributor** — a JSON object on stdout carrying `systemMessage`:

```text
==> format-file.sh: <repo-relative path> (<check>)
```

The `==>` prefix matches `say()` in `scripts/lib/common.sh`, so hook output and check output read as one system. The path is escaped for JSON before interpolation; the reference warns that a malformed payload produces a parse notice even on exit `0`.

Emitted only when a check actually examined the file. A modification no check governs produces **no message** — a status line on every edit, including the many nothing governs, would be noise rather than status.

**To the session** — the failure path, on stderr, because the reference states a `PostToolUse` hook's stderr is shown to Claude. That is the delivery mechanism FR-011's diagnose-and-retry requirement depends on. Contents: the repository-relative path, the check that failed, its exit status, and the check's own output **unmodified**. Unmodified because it already names the file and the location, which the constitution's Quality Gate section requires, and re-wrapping it risks losing that.

## Exit statuses

| Status | When | Meaning to the caller |
| `0` | every invoked check returned `0`; or the path was rejected; or no check governs the file; or a check returned `3` | Nothing further to do |
| `2` | a check returned `1`, `2` or `4` | Formatting did not complete. Details are on stderr, addressed to the session |

**Only two.** The script never returns `1`, `3` or `4` of its own.

**Exit `2` is a report, not a veto.** `PostToolUse` cannot block — the tool has already run — so exit `2` here delivers stderr to the session and leaves the edit standing. That is exactly what FR-011 asks for and why exit `2` is safe to use for a failure that must not be undone.

**A check's exit `3` is not a failure.** `common.sh` exits `3` when neither the native tool nor `docker` is available, naming both. Passing that through as `2` would make a container runtime a precondition for editing any governed file, which Principle I forbids — and `editorconfig-checker` is already absent natively on the development machine, so this is a live path. Instead the hook reports it visibly and continues:

```text
==> format-file.sh: <path> - <check> skipped: <the check's own exit-3 message, which names the native tool and the image>
```

Visible rather than silent, because Principle I's own rationale is that "a check that only runs after a setup ritual is a check that silently stops running" (FR-018).

**A check's exit `4`** (not a git working tree) **is** a failure. This script only ever runs inside this repository, so exit `4` means something is genuinely wrong.

## Recursion

`CCD_FORMAT_FILE_ACTIVE` — set to `1` before any check is invoked, tested on entry. Set on entry ⇒ exit `0` immediately, no output.

The guard is the second of two independent guarantees, not the only one. The first is the event: `PostToolUse` fires on **tool calls**, and this script's writes go through formatters that write to disk directly, with no tool call. So the loop FR-010 names cannot form through the designed path — which is also why `FileChanged`, which does fire on plain disk writes, was rejected in research.md §1.

FR-010 is a hard requirement and does not rest on a single argument, so the guard covers what the reasoning does not: a formatter that itself invoked Claude Code, a future edit that introduces a tool-calling step, and any path nobody has thought of. It is an environment variable rather than a lock file precisely because it needs no cleanup — a stale lock would disable formatting silently, which is the failure mode FR-018 exists to prevent, arriving by another route.

## Guarantees

- Reads and writes **exactly one file** per invocation: the one named in the payload (FR-002).
- Touches nothing outside the repository root (FR-013).
- Rewrites nothing on any rejection path (FR-006, FR-007, FR-008, FR-009).
- Causes no further invocation of itself (FR-010).
- Never blocks or undoes an edit — it cannot, and does not try.
- POSIX `sh`, tab-indented, zero ShellCheck findings in `sh` mode. It lives under `scripts/`, which the shell check covers, so this is enforced rather than asserted (Principle IV and the Quality Gate clause).

## Not guaranteed

Stated because a reader will otherwise assume them.

- **That it is the only formatter running.** A formatter configured outside the repository can also match the same event, and hooks for one event run in parallel. The repository cannot detect that from inside and must not edit configuration outside its own root (FR-030). The documented stand-down mechanism is the existence of this script; research.md §17 has the one-line test and the reasoning.
- **That formatting a file makes the whole repository conformant.** It formats one file with the three rewriting checks. The four report-only checks, and the whole-repository verdict, remain `scripts/lint.sh`'s job — which the constitution's Development Workflow already requires before review.
