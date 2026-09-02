# Quickstart: Repository Quality Gate and Plugin Packaging

**Date**: 2026-09-02 | **Feature**: [spec.md](./spec.md) | **Contract**: [contracts/cli.md](./contracts/cli.md)

Runnable scenarios that prove the feature works. Each states what to run and what a pass looks like. Together they cover every success criterion in the spec.

## Prerequisites

- A POSIX shell and `git`. That is the floor.
- Optionally the native tools: `markdownlint-cli2`, `yamllint`, `shellcheck`, `ruff`, `prettier`, `editorconfig-checker`.
- Optionally Docker. **At least one of the two** must be available per check, or that check exits `3` by design (FR-011).

No install step. Nothing to bootstrap.

## Scenario 1 — the aggregate check passes on a clean tree

Covers SC-006, and FR-003 through FR-007.

```sh
cd "$(git rev-parse --show-toplevel)"
scripts/lint.sh
echo "exit: $?"
```

**Pass**: six `==>` lines, one per check, each naming how its tool resolved; no violations; `exit: 0`.

**Fail**: any non-zero exit. The output names the failing check and carries that tool's own violation report.

## Scenario 2 — a check run leaves the tree untouched

Covers SC-007 and FR-012's "reporting is the default".

```sh
git status --porcelain > /tmp/before.txt
scripts/lint.sh
git status --porcelain > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt && echo "unchanged"
```

**Pass**: `unchanged`. In container mode this is guaranteed by the read-only mount, not by the tools' good behaviour.

## Scenario 3 — every check actually catches a violation

Covers SC-002 and FR-006. This is the one that distinguishes a working check from a check that always passes.

```sh
scripts/selftest.sh
echo "exit: $?"
```

**Pass**: one line per standard reporting that its check failed on a deliberately bad fixture, and `exit: 0`. The self-test succeeds only when every check failed as it should.

**Fail**: `exit: 1` and a named standard whose check passed bad input. Treat that as a broken check, not a broken test.

To see it by hand for one standard:

```sh
tmp=$(mktemp -d)
printf '#!/bin/sh\nif [ "$a" == "$b" ]; then echo hi; fi\n' > "$tmp/bad.sh"
shellcheck -s sh "$tmp/bad.sh"
echo "exit: $?"
rm -rf "$tmp"
```

**Pass**: `SC3014` reported against `bad.sh` at a named line, non-zero exit. `==` is a bashism; POSIX `test` uses `=`. `SC2154` is also reported, for the unassigned `$a` — the fixture is two violations in one line, which is fine for a demonstration.

## Scenario 4 — the verdict does not depend on what is installed

Covers SC-003 and FR-008, and is the reason `LINT_FORCE_CONTAINER` exists.

```sh
scripts/lint.sh > /tmp/native.txt 2>&1
native=$?
LINT_FORCE_CONTAINER=1 scripts/lint.sh > /tmp/container.txt 2>&1
container=$?
[ "$native" -eq "$container" ] && echo "same verdict: $native"
```

**Pass**: `same verdict: 0`. The two logs differ on the `==>` resolution lines — that is expected and is the only permitted difference; the violation sets must match.

Requires Docker. Without it the second run exits `3`, which is the correct behaviour and not a comparison.

## Scenario 5 — fix mode rewrites, and says so

Covers FR-012, FR-012a and FR-005a.

```sh
printf '{"b":1,   "a":2}\n' > /tmp/scratch.json && cp /tmp/scratch.json ./scratch.json
scripts/lint-format.sh       # reports the violation, changes nothing
scripts/lint-format.sh --fix # rewrites it
cat scratch.json
rm -f scratch.json
```

**Pass**: the first run exits `1` naming `scratch.json`; the second exits `0` and the file is reformatted to `{ "b": 1, "a": 2 }`. Note that Prettier reformats whitespace and does not reorder keys — key order is not its business.

For a standard with no automatic fix:

```sh
scripts/lint-shell.sh --fix
echo "exit: $?"
```

**Pass**: a line saying no automatic fix is available for shell, no file modified, and `exit: 0` when the check itself passes. Not an error — FR-012a.

## Scenario 6 — a missing tool fails loudly

Covers FR-011.

```sh
PATH=/nonexistent LINT_FORCE_CONTAINER= scripts/lint-markdown.sh
echo "exit: $?"
```

**Pass**: `exit: 3`, and a stderr message naming both the missing command and the image that would have been used. Never a silent skip, and never a `0`.

## Scenario 7 — every check agrees on scope

Covers SC-008 and FR-013a.

```sh
grep -rn '\.specify\|node_modules\|\.remember' \
  .markdownlint-cli2.jsonc .yamllint.yml ruff.toml .shellcheckrc \
  && echo "SCOPE LEAK" || echo "scope declared in one place"
```

**Pass**: `scope declared in one place`. An exclusion appearing in a tool's own configuration means two sources of truth, which is the defect FR-013a names.

## Scenario 8 — the plugin is recognised

Covers SC-005 and FR-016.

```sh
python3 -c "import json;d=json.load(open('.claude-plugin/plugin.json'));print(d['name'])"
```

**Pass**: `claude-code-devkit`.

Then install it and confirm Claude Code lists it. `claude plugin install` resolves a name from a
configured marketplace rather than from a path, so a local repository is installed by registering it
as a marketplace first. That needs a second manifest: `.claude-plugin/marketplace.json`, which is a
_marketplace_ manifest listing the plugins a source offers, and is not the same file as
`plugin.json`. Without it, `marketplace add` fails with `Marketplace file not found`. The path also
has to be written `./` and not `.` — a bare dot is rejected as `Invalid marketplace source format`.

```sh
claude plugin marketplace add ./
claude plugin install claude-code-devkit
claude plugin list | grep claude-code-devkit
```

**Pass**: `claude-code-devkit` appears in the list, and in `/plugin`. Observed output:

```text
✔ Successfully added marketplace: claude-code-devkit (declared in user settings)
✔ Successfully installed plugin: claude-code-devkit@claude-code-devkit (scope: user)
  ❯ claude-code-devkit@claude-code-devkit
    Version: 0.1.0
    Scope: user
    Status: ✔ enabled
```

This step writes to the user's own Claude Code configuration (`~/.claude/plugins/` and user
settings), outside this repository, so it is not part of `scripts/lint.sh` and was run only after
the user asked for it explicitly. `claude plugin uninstall claude-code-devkit` and
`claude plugin marketplace remove claude-code-devkit` reverse it.

## Scenario 9 — the tooling is not exempt from itself

Covers FR-017 and the constitution's Quality Gate Requirements.

```sh
scripts/lint-shell.sh
```

**Pass**: exit `0` with `scripts/*.sh` and `scripts/lib/*.sh` among the files checked. Confirm they were in scope rather than skipped:

```sh
git ls-files --cached --others --exclude-standard -- 'scripts/*.sh' 'scripts/lib/*.sh'
```

**Pass**: every runner listed. `--others` matters: on a branch where the scripts are not committed yet, `git ls-files` alone lists nothing, and an empty list here would look like a passing check rather than an unchecked one. A shell checker that does not check the shell scripts enforcing it proves nothing.

## Scenario 10 — the six ignore declarations agree with each other

Covers FR-013a, FR-013b, FR-013c and SC-008. The reason this scenario exists: under the previous design there was one declaration and nothing to compare.

```sh
scripts/lint-scope.sh
```

**Pass**: exit `0`, one line per check saying how its declaration was verified, and an explicit line for the shell check saying its scope is unverifiable because ShellCheck has no path-exclusion directive.

Then break it deliberately and confirm the check earns its place:

```sh
# add a path to one tool's ignore list that .lintignore does not exclude
scripts/lint-scope.sh
echo "exit=$?"
```

**Pass**: exit `1`, naming the check and the differing paths. Undo the edit before continuing.

A `0` from this script with the shell line absent would mean the unverifiable case was silently counted as agreement — which is the failure FR-013c is written to prevent, so read that line rather than only the exit status.

## Scenario 11 — each tool skips what its own configuration says, invoked by hand

Covers FR-013a. The runner passes an explicit file list, so this scenario deliberately bypasses the runner.

```sh
markdownlint-cli2 '**/*.md' 2>&1 | head -2
yamllint .
ruff check --no-cache .
prettier --check .
```

**Pass**: every one exits `0`, having skipped the same paths the runner skips. A non-zero exit here means a tool visited an excluded file and found something in it.

None of the four announces which paths it skipped, and markdownlint-cli2 0.23.2 prints only its version banner — `noProgress: true` suppresses the rest. So this scenario is verified by the exit status, not by reading a list back. `scripts/lint-scope.sh` (Scenario 10) is what compares the declarations textually; this scenario confirms the declarations are actually in force.

`shellcheck` is not in this list, and that is the point: it has no way to be. Passing it a glob checks whatever the glob matched.

## Scenario 12 — formatting covers Markdown, YAML, XML and shell

Covers FR-021, FR-022 and SC-009.

```sh
scripts/lint-format.sh
```

**Pass**: the output names each declared plugin and how it resolved, and the check covers `.md`, `.yml`, `.yaml`, `.xml`, `.sh` and `.json` files. Confirm no rule is enforced twice by checking that the markdown and YAML linters no longer carry the rules Prettier rewrites:

```sh
grep -cE '^\s*"[a-z][a-z0-9-]*": false' .markdownlint-cli2.jsonc
grep -cE '^  [a-z-]+: disable$' .yamllint.yml
```

**Pass**: `22` and `12`.

Both numbers need their explanation, or a reader will think one of them is wrong. Upstream's `markdownlint/style/prettier.json` lists 23 rules; 22 are inlined here and the 23rd, `line-length`, is disabled separately for a reason that predates Prettier. The yamllint count is 12 because it includes `line-length` and `document-start`, also disabled for their own reasons; the rules Prettier rewrites are the 10 below them.

`comments` and `comments-indentation` are **still enabled** — Prettier does not rewrite them, so moving them out would have deleted a check rather than relocated it.

## Scenario 13 — a missing plugin changes the path, not the verdict

Covers FR-023 as clarified, FR-008 and SC-013.

```sh
# with the plugins absent natively
scripts/lint-format.sh
echo "exit=$?"
# with everything containerised
LINT_FORCE_CONTAINER=1 scripts/lint-format.sh
echo "exit=$?"
```

**Pass**: identical verdict and identical violation list from both. The first run states which content kinds it routed to the container path because their plugin was absent.

**Fail**, and worth naming because it is the failure mode the clarification ruled out: a run that says nothing about the absent plugin and reports success, having simply not formatted XML at all.

## Scenario 14 — the formatting configuration carries no restated defaults

Covers FR-019 and SC-010.

```sh
cat .prettierrc.json
```

**Pass**: three option values — `printWidth`, `trailingComma`, `singleQuote` — plus `plugins` and `overrides`. `endOfLine`, `proseWrap` and the JSON override's `tabWidth` are absent, because each equalled Prettier 3.9.6's documented default; each is recorded in [`research.md`](./research.md) §14 instead, which is what the constitution at v1.2.0 requires in exchange for omitting it.

Every option value present must be justifiable as a departure. One that matches the default is an SC-010 failure even though nothing misbehaves.

The `parser` inside each override is deliberately **not** counted, and knowing why matters before reading this as a violation: deleting the whole `overrides` array was measured, and every content kind still resolved — the plugins register `.xml`, `.sh` and `.bash` themselves. Those four bindings are kept so the content kinds FR-021 names are legible in the file that governs them, rather than implied by two npm packages' registries. FR-019 was narrowed to say so; `research.md` §14 records the measurement.

## Scenario 15 — the six extensions are installed, enabled and deterministically ordered

Covers FR-024, FR-025, FR-025a, SC-011 and SC-012.

```sh
specify extension list
```

**Pass**: `agent-context`, `assess`, `bug`, `git`, `superb` and `token-budget`, all six enabled.

```sh
specify extension list
specify extension list # again
```

**Pass**: identical hook ordering both times (SC-011).

```sh
grep -cE '^ +priority: [0-9]+$' .specify/extensions.yml
grep -E '^ +priority: [0-9]+$' .specify/extensions.yml | sort | uniq -c
```

**Pass**: `28`, then `2` at 10, `6` at 20, `2` at 30 and `18` at 50. Every hook entry carries an explicit `priority` and no entry is left at the default.

The ranks follow the written principle — `superb` 10, `token-budget` 20, `agent-context` 30, `assess` and `bug` 40, `git` 50 — with observing hooks before mutating ones and the committing hook last (SC-012). **Rank 40 does not appear, and that is correct**: `assess` and `bug` register 0 hooks, so their rank is reserved rather than used. A grep that expects five distinct numbers will report a false failure.

Do not grep for `priority` unanchored: the file's header comment discusses hook priority in prose, and those lines match first.

Two things to know before trusting a passing run here. `specify extension set-priority` sets **resolution** priority, not hook order — running it and expecting the hooks to reorder produces no change and no error. And `specify extension update` re-registers an extension's hooks from its manifest, which returns them to the default `10`; after any update, re-apply the ranks and re-run this scenario.
