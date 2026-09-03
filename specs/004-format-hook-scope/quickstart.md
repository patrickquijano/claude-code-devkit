# Quickstart: validating format-on-modification and per-check exclusions

**Date**: 2026-09-03 | **Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](./plan.md)

Runnable scenarios that prove the feature works end to end. Each states what it proves, how to run it, and what a pass looks like. Scenario 1 must be run **before** any of half one's code changes are made — it captures the baseline everything else is compared against.

Implementation belongs in `tasks.md`; this file is the validation guide. Contracts: [check-cli.md](./contracts/check-cli.md), [format-file-cli.md](./contracts/format-file-cli.md), [exclusion-declaration.md](./contracts/exclusion-declaration.md).

## Prerequisites

- A git working tree of this repository. `git` is the only hard requirement — it is not a language runtime, so Principle I is untouched.
- Either the native tool for each check, or a container runtime. `editorconfig-checker` is absent natively on the development machine, so that check uses the container path; the others resolve natively.
- Run everything from the **repository root**. Every script in `scripts/` computes its own root, but the relative paths below assume it.
- `LINT_FORCE_CONTAINER=1` forces the container path for any check, which is how the native and container verdicts are shown to agree.

## Scenario 1 — The baseline, obtained at proof time

**Proves**: nothing on its own. It produces the "before" side scenario 2 compares against.

Nothing is captured in advance and nothing is committed. The baseline comes from a detached worktree of the base commit, measured and then removed:

```sh
SCRATCH=$(mktemp -d)
git worktree add --detach "$SCRATCH/base-tree" main
# for each of editorconfig, format, markdown, yaml, shell, python:
#   run the snapshot harness against "$SCRATCH/base-tree"   -> before
#   run the snapshot harness against the working tree        -> after
git worktree remove --force "$SCRATCH/base-tree"
```

Two properties of this make it worth the extra step over a committed snapshot, and both were decided after a committed snapshot was rejected:

- **The baseline cannot drift from what the code actually did.** It is the base commit's own extractors reading the base commit's own configuration. A hand-written or committed list proves only that somebody transcribed `.lintignore` correctly on the day.
- **Nothing perturbs the measurement.** `lint-editorconfig.sh` collects `'*'` — every file — so a baseline file or a harness stored inside the repository would enter the very lists it measures. The harness lives outside the tree for the same reason.

The harness reads each check's globs out of that check's own script rather than restating them, which is what lets one harness measure both trees: before the change the call is `collect '*.md'`, after it is `collect markdown '*.md'`, and either way it is that tree's own call.

**Pass**: six lists from each tree. `citations` is absent from both by design — it consumes no file list at all, so it has nothing to compare (research.md section 15).

## Scenario 2 — No path changed coverage (FR-024, FR-025, SC-002)

**Proves**: the feature's central correctness claim. The scenario to disbelieve last.

```sh
# the migration proof, run once, against the base commit
scope-equality.sh # the out-of-tree harness from scenario 1

# the durable property, on every run
scripts/selftest.sh # the scope-wiring and declaration-failure fixtures
```

Two different things, and conflating them is the mistake this scenario exists to prevent.

**The migration proof** compares the base commit's central-list mechanism against the current per-check declarations, per check. Its result is recorded in research.md section 14: six comparable lists, zero paths gained, zero lost. It is run once, because once this change is on the default branch its "before" side _is_ this change and the comparison passes unconditionally — a check that cannot fail.

Three exemptions are declared in it rather than left implicit: files this feature adds are asserted separately instead (they exist on one side only); `.lintignore` and `scripts/lint-scope.sh` are dropped from the before side, because this feature deletes them deliberately; and nothing else. Any other difference is a defect.

**The durable property** is what `scripts/selftest.sh` carries instead: each check's file list is built from **its own** declaration and no other. Every declaration in a fixture root gains a sentinel path of its own, and each check must not see files under its own sentinel while it must see files under all five others. That second half is what gives the fixture teeth — the six declarations hold identical path sets today, so a check wired to the wrong declaration would pass any assertion that only looked for absences. Two further fixtures require a missing declaration file, and a declaration block absent from a file that exists, each to exit non-zero naming the file.

**Pass**: the recorded migration result shows zero gained and zero lost per check, and `scripts/selftest.sh` reports every scope case holding.

**Fail, and what it means**: a difference is a defect in the change, never grounds for amending the claim. A path _gained_ by a check means it now examines a file the repository deliberately excludes — most likely an extractor returning an empty list where it should have failed loudly. A path _lost_ means a check has stopped examining something it should. A difference that nets to zero across checks is still a fail, which is why the comparison is per check.

## Scenario 3 — Whole-repository behaviour is unchanged (FR-017, SC-008)

**Proves**: no-argument and bare `--fix` invocations behave exactly as before.

```sh
scripts/lint.sh                        # expect: 0
LINT_FORCE_CONTAINER=1 scripts/lint.sh # expect: 0, same verdict
scripts/selftest.sh                    # expect: 0
```

**Pass**: `==> lint.sh: all checks passed`, exit `0`, and the run names **seven** checks — `citations`, `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python`. No `scope` line.

**Also check**: the tree is unmodified after the no-argument run (`git status --porcelain` unchanged). Check mode mounts the repository read-only in the container path, so this is a property of the boundary rather than a promise about seven tools.

## Scenario 4 — One named file, from the command line (FR-016)

**Proves**: the new optional path list narrows correctly, and narrows in the right direction.

```sh
scripts/lint-markdown.sh --fix -- README.md # expect: 0, formats README.md only
scripts/lint-python.sh --fix -- README.md   # expect: 0, "no files in scope"
scripts/lint-format.sh --fix -- .claude/settings.json
```

**Pass**: the first rewrites at most `README.md` and no other file — confirm with `git status --porcelain`, which must name that path and nothing else. The second exits `0` with `no files in scope`, because `README.md` is outside `lint-python.sh`'s globs. The third exits `0` with `no files in scope`, because every check's declaration excludes `.claude` — **a caller cannot reach an excluded file by naming it**, which is the property FR-006 rests on.

**Then the negative cases**:

```sh
scripts/lint-markdown.sh --badflag                  # expect: 2, usage on stderr
scripts/lint-markdown.sh --fix -- does-not-exist.md # expect: 0, "no files in scope"
```

## Scenario 5 — A modified file is formatted (FR-001, FR-012, SC-001, SC-004)

**Proves**: the hook works, end to end, and touches one file.

In a session where the hook is active, ask for an edit that leaves a Markdown file non-conformant — a heading with trailing spaces, or a list indented with the wrong width.

**Pass**: three things together.

1. The file is conformant afterwards, with no command run by hand. Confirm with `scripts/lint-markdown.sh -- <that file>` exiting `0`.
2. A status line appeared, of the form `==> format-file: <path> (format)`.
3. `git status --porcelain` names **that file and no other**. This is SC-004 and it is the one most easily broken by a well-meaning "format the directory while we're here".

**Then the quiet case**: ask for an edit to a file no rewriting check governs — `.shellcheckrc`, or `LICENSE`. Pass: the file is byte-identical to what the session wrote, and **no status line appears**. A line on every edit would be noise; the Assumptions section of the spec resolved this deliberately.

## Scenario 6 — Path safety (FR-008, FR-013, SC-005)

**Proves**: every rejection path refuses without writing, and without failing.

Drive the script directly rather than through a session — it reads stdin, so each case is one command:

```sh
printf '{"tool_input":{"file_path":"%s"}}' /etc/hosts | scripts/format-file.sh
echo "exit=$?"
printf '{"tool_input":{"file_path":"%s"}}' /nonexistent/x.md | scripts/format-file.sh
echo "exit=$?"
printf '{"tool_input":{"file_path":"%s"}}' "$PWD/scripts" | scripts/format-file.sh
echo "exit=$?"
printf '{"tool_input":{}}' | scripts/format-file.sh
echo "exit=$?"
printf 'not json at all' | scripts/format-file.sh
echo "exit=$?"
```

**Pass**: every one exits `0`, prints nothing, and leaves `git status --porcelain` unchanged and `/etc/hosts` untouched. Six cases, one outcome — refusal is normal, not an error.

**The symlink case** deserves its own run, since it is the one a string-prefix test would get wrong:

```sh
ln -s /etc/hosts ./escape.md
printf '{"tool_input":{"file_path":"%s"}}' "$PWD/escape.md" | scripts/format-file.sh
echo "exit=$?"
rm ./escape.md
```

**Pass**: exit `0`, nothing written, `/etc/hosts` unchanged. The directory portion is resolved with `pwd -P` before the containment test, so a link resolving outward is refused. If this one passes by _formatting_ `escape.md`, the resolution is happening after the test rather than before.

## Scenario 7 — Failure is actionable (FR-011, SC-006)

**Proves**: a formatting failure reaches the session with enough to act on.

Make a check fail on a file the session just edited — the self-test fixtures do this deterministically; by hand, a `.md` file carrying a violation markdownlint cannot fix will do.

**Pass**: exit `2`, and stderr naming three things — the repository-relative path, the check that failed, and the check's **own unmodified output**, which already carries the file and line. A reader must be able to act without consulting anything else. The edit itself still stands: `PostToolUse` cannot undo it, and exit `2` here is a reporting channel, not a veto.

**Fail, and what it means**: stderr that summarises rather than passes through has lost the location the constitution's Quality Gate section requires. Exit `1` or `3` from the hook is a bug — it returns only `0` or `2`.

## Scenario 8 — Unavailable tooling is a visible skip, not a failure (FR-018, SC-010)

**Proves**: a missing tool degrades loudly and does not fail the edit.

```sh
PATH=/usr/bin:/bin printf '{"tool_input":{"file_path":"%s"}}' "$PWD/README.md" \
  | env PATH=/usr/bin:/bin scripts/format-file.sh
echo "exit=$?"
```

with no container runtime reachable, so the check exits `3`.

**Pass**: exit `0`, and a status line naming both the missing native tool and the image that would have run — e.g. `markdown skipped: neither markdownlint-cli2 nor docker (davidanson/markdownlint-cli2:v0.23.2@sha256:...) available`. Visible, not silent: Principle I's own rationale is that a check needing a setup ritual is a check that silently stops running.

**Fail**: exit `2` means a container runtime has become a precondition for editing a governed file, which Principle I forbids. Silence means the failure mode the principle names has arrived.

## Scenario 9 — Recursion (FR-010)

**Proves**: formatting a file cannot cause it to be formatted again.

```sh
CCD_FORMAT_FILE_ACTIVE=1 printf '{"tool_input":{"file_path":"%s"}}' "$PWD/README.md" \
  | env CCD_FORMAT_FILE_ACTIVE=1 scripts/format-file.sh
echo "exit=$?"
```

**Pass**: exit `0`, no output, nothing written — the guard short-circuits a nested invocation.

**The primary guarantee is not this guard** and should be checked separately: after scenario 5, the log of hook invocations shows **one** per edit, not two. `PostToolUse` fires on tool calls, and the formatters write to disk without one, so the event cannot re-fire from the hook's own writes. The guard covers what that reasoning does not.

## Scenario 10 — Excluded, unsupported, and binary (FR-006, FR-007, FR-009)

**Proves**: three byte-identical cases, each through the mechanism that owns it.

```sh
# excluded path: every check's own declaration excludes .claude
printf '{"tool_input":{"file_path":"%s"}}' "$PWD/.claude/settings.json" | scripts/format-file.sh
# unsupported kind
printf '{"tool_input":{"file_path":"%s"}}' "$PWD/LICENSE" | scripts/format-file.sh
# binary
printf '\0binary' > /tmp/b.md && cp /tmp/b.md ./b.md
printf '{"tool_input":{"file_path":"%s"}}' "$PWD/b.md" | scripts/format-file.sh
rm ./b.md
```

**Pass**: each exits `0`; each file is byte-identical afterwards (`cmp` against a copy taken first); the first two print no status line. Note the first two are refused by `collect`'s `no files in scope`, not by logic in the hook — that is the design, and a hook that grew its own exclusion test would be a second declaration of a fact half one just consolidated.

## Scenario 11 — Subagent parity (FR-020, SC-011)

**Proves**: a subagent's edit is treated identically to the main session's.

Have a subagent write the same non-conformant content to a file the main session also writes, separately, and compare the two outcomes.

**Pass**: identical resulting file content, and a status line in both cases. Project-scoped hooks fire for a subagent's tool calls, so this is the default behaviour — the scenario exists to catch a change that accidentally special-cases it.

## Scenario 12 — Single authority (FR-030, SC-012)

**Proves**: the co-existence obligation is documented and, once applied, honoured.

```sh
grep -rn "format-file.sh" README.md CLAUDE.md specs/004-format-hook-scope/
```

**Pass**: the documentation contains the one-line stand-down test for an externally configured formatter, copy-pasteable, together with where it goes and why this repository does not apply it itself.

**Then, on a machine that has such a formatter**: after applying the line, one edit produces **one** formatting pass. Before applying it, two run concurrently — which is why the line exists. This is a documentation obligation rather than an enforceable property, and the docs must say so in those terms.

## Full gate

The check that actually governs whether this ships, and the one the constitution's Development Workflow requires before review:

```sh
scripts/lint.sh                        # expect 0
scripts/selftest.sh                    # expect 0
LINT_FORCE_CONTAINER=1 scripts/lint.sh # expect 0, same verdict as native
```

**Pass**: all three exit `0`, and `scripts/lint.sh` names seven checks. If `selftest.sh` passes while any scenario above fails, the self-test is missing a fixture — that is a defect in the self-test, not a reason to ship.

## Walk record

Every scenario above was walked against the finished implementation. Recorded here because a self-test that passes while a scenario fails means the self-test is missing a fixture — a defect in the self-test, not a reason to ship.

| Scenario | Outcome | Where the coverage lives |
| 1 — baseline at proof time | pass | out-of-tree harness; base worktree created and removed, `git worktree list` unchanged |
| 2 — no path changed coverage | pass | migration proof recorded in research.md section 14; `scope/*` fixtures in `scripts/selftest.sh` |
| 3 — whole-repository behaviour unchanged | pass | `scripts/lint.sh` and `scripts/lint.sh --fix` both exit 0; per-check lists identical |
| 4 — one named file from the command line | pass, **walked explicitly** | this task only; see below |
| 5 — a modified file is formatted | pass | `hook/eligible` fixture, plus an end-to-end run rewriting a Markdown fixture |
| 6 — path safety | pass | `hook/outside`, `hook/absent`, `hook/directory`, `hook/nofield`, `hook/nonjson`, `hook/symlink` |
| 7 — failure is actionable | pass | `hook/failure`: exit 2, stderr naming file, check and the check's own output |
| 8 — unavailable tooling is a visible skip | pass | `hook/notool`: exit 0, message naming the missing tool and the image |
| 9 — recursion | pass | `hook/recursion`: exit 0, no output, no write |
| 10 — excluded, unsupported, binary | pass | `hook/excluded`, `hook/unsupported`, `hook/binary`, each asserting byte equality |
| 11 — subagent parity | pass, **by inspection** | this task only; see below |
| 12 — single authority | pass | documented in `README.md`, `CLAUDE.md` and research.md section 17 |

**Scenario 4, walked.** `scripts/lint-markdown.sh --fix -- README.md` exited 0 and rewrote nothing, because `README.md` was already conformant; `cksum` was identical before and after, and `find -newermt` showed no file in the tree modified by the run. `scripts/lint-python.sh --fix -- README.md` exited 0 with `no files in scope` — outside that check's globs. `scripts/lint-format.sh --fix -- .claude/settings.json` exited 0 with `no files in scope`, which is the property FR-006 rests on: the file's extension **is** governed by that check, and only its path keeps it out, so a caller cannot reach an excluded file by naming it. Both negative cases held: `--badflag` exited 2 with `lint-markdown.sh: unrecognised argument: --badflag` on stderr, and a non-existent path exited 0 with `no files in scope`.

**Scenario 11, by inspection.** The hook reads exactly one field of the payload, `tool_input.file_path`, and `.claude/settings.json`'s matcher names tool names only. Neither reads any field that identifies the caller — no agent id, no session id, not even `tool_name` — so a subagent's `Edit` or `Write` produces the same payload shape and takes the same path through the script as the main session's. There is nothing to special-case, which is what SC-011 asserts. The scenario is retained to catch a future change that introduces such a distinction.
