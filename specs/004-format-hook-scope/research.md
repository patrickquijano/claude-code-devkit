# Research: Format on modification, and one exclusion declaration per check

**Date**: 2026-09-03 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Every decision below that departs from a tool's or platform's default carries its reason here, following the convention `specs/001-quality-gate-plugin/research.md` established. A reader who wants to "fix" one of these should find the reason before changing it.

## Contents

1. Which hook event
2. Exec form versus shell form
3. Where the hook configuration lives
4. Reading the file path from stdin without a global install
5. Resolving a path safely in POSIX `sh`
6. Detecting a file that must not be rewritten
7. Which checks the hook may invoke, and in what order
8. How the hook reports: status, failure, and unavailable tooling
9. Recursion: why `PostToolUse` cannot re-fire from the hook's own writes
10. Extending the check CLI with a path list
11. Where each check's exclusions are declared
12. ShellCheck, the check with no exclusion mechanism
13. Hardening the promoted extractors
14. Proving no path changed coverage
15. What `citations` needs, and why the answer is nothing
16. Documents to correct
17. Co-existing with a formatter configured outside the repository

---

## 1. Which hook event

**Decision**: `PostToolUse`, with matcher `Edit|Write|MultiEdit|NotebookEdit`.

**Rationale**: `PostToolUse` fires after a file-editing tool call succeeds, and the tool input carries `tool_input.file_path` — exactly one file, already written. The official guide's worked example for this problem is this event with this shape of matcher ("Auto-format code after edits", `code.claude.com/docs/en/hooks-guide`), and the reference confirms `Edit|Write` is matched as a pipe-separated set of exact tool names against the tool name (`code.claude.com/docs/en/hooks`). FR-019 resolved "modified" to files the session edited directly, which is precisely the set of tools this matcher covers.

The reference also states that for `PostToolUse` the tool has already run and cannot be undone, and that the hook's **stderr is shown to Claude**. Both matter: the first means this hook can never block an edit (which FR-008's "refusal is not an error" depends on), and the second is the delivery mechanism FR-011 needs.

**Alternatives considered**:

- **`FileChanged`** — the guide recommends it "to reformat a specific file however it changes, including when a `Bash` command rewrites it". Rejected on two grounds. It fires on _any_ on-disk change, including the formatter's own write, so it is a recursion source that would have to be defused explicitly (FR-010). And FR-019 put shell-rewritten files out of scope, so its only advantage does not apply. Recorded here rather than dismissed silently, because it is the right answer to a slightly different requirement and a future amendment of FR-019 should start from this paragraph.
- **`Stop`** — fires once when Claude finishes responding, so one invocation could format every file touched in the turn. Rejected: it has no per-file input, so the hook would have to discover what changed, which means either a whole-repository scan (forbidden by FR-002 and the non-goals) or a git diff (which cannot distinguish this turn's edits from pre-existing dirt). It also delays formatting past the point the contributor is reading the result.
- **Matching `Bash` as well** — rejected. `PostToolUse` on `Bash` fires after every shell command in the session, and `tool_input` then carries a command string, not a file path. There is nothing to format and the matcher would fire hundreds of times per session.
- **`PostToolBatch`** — fires after a batch of parallel tool calls. Rejected for the same reason as `Stop`: no per-file input.

## 2. Exec form versus shell form

**Decision**: exec form — `"command"` plus `"args": []`.

**Rationale**: the reference distinguishes the two: with `args` set, the command is spawned directly with no shell; with `args` omitted, a shell interprets the command string. The security section's first item is shell quoting, and its unsafe example is exactly the shape this hook would otherwise have — a path interpolated into a shell command line. Exec form removes shell interpolation of the file path as a **class** of problem rather than quoting it correctly and hoping the next editor does too. The troubleshooting section recommends the same thing for the same reason: "To avoid shell quoting entirely, add `"args": []` to switch to exec form."

The hook takes its input on stdin, not as an argument, so `args` is legitimately empty — nothing is lost by using the form that needs no quoting.

**Alternatives considered**: shell form with the path double-quoted. Rejected: correct today, one careless edit from a command injection through a filename, and the reference names it as the unsafe pattern.

## 3. Where the hook configuration lives

**Decision**: `.claude/settings.json` at the repository root, committed.

**Rationale**: the reference's scope table gives exactly one location that is per-project and shareable: `.claude/settings.json` — "Single project / Yes, can be committed to the repo". FR-014 requires the behaviour be shared with everyone working in the repository rather than depending on one machine.

**Alternatives considered**:

- **`.claude/settings.local.json`** — the same table marks it "No, gitignored when Claude Code saves a setting to it", and this repository's `.gitignore` already ignores it explicitly. It cannot satisfy FR-014.
- **`~/.claude/settings.json`** — "All your projects / No, local to your machine". Wrong scope twice over, and out of bounds for a repository change.
- **The plugin manifest's `hooks` key, or a `hooks/hooks.json`** — the table's entry for these is "When plugin is enabled / Yes, bundled with the plugin". That would ship the behaviour to every consumer of this plugin, which FR-015 forbids and the spec's non-goals name. `specs/001-quality-gate-plugin/research.md` §10 already decided that this repository's authored plugin content lives in top-level `skills/`, `commands/` and `agents/`, and a hook directory would be a component this feature was not asked to add.
- **Skill or subagent frontmatter** — session-scoped and invocation-scoped respectively. Neither is repository-wide.

**Note on `.lintignore` and this file**: `.lintignore` excludes `.claude` in its entirety, on the stated rationale that "nothing this repository authors is lost by excluding the whole directory". `.claude/settings.json` is authored content, so that clause becomes false. Half one deletes `.lintignore` outright, which removes the false sentence along with the file; the per-check declarations that replace it each keep their own `.claude` exclusion, so the committed hook config remains outside the format and lint checks. That is consistent with the 36 already-tracked, already-unlinted files under `.claude/skills/`.

## 4. Reading the file path from stdin without a global install

**Decision**: `sed` on the hook's stdin, with no dependency on `jq`, `python3`, or any language runtime.

Extract exactly one well-known scalar field from a single-line-or-multi-line JSON object:

```sh
file_path=$(sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
```

**Rationale**: Principle I is non-negotiable and says no check "MAY require a language package manager, a virtual environment, or a global install step as a precondition for running it". `jq` is a global install. The guide's own example uses `jq` and the troubleshooting section anticipates "jq: command not found" — which is precisely the failure Principle I exists to prevent, and it would arrive on every single edit.

This is not general JSON parsing and must not be presented as such. It is the extraction of one field whose value is a filesystem path, from a payload this repository does not author. The constraint that makes it safe is that the field's value cannot contain an unescaped `"` — a double quote in a path would be escaped as `\"` in JSON, and the pattern's `[^"]*` stops at the backslash, producing a truncated path. A truncated path fails the "must exist and be a regular file" test in §5 and is refused. So the failure mode of the parser's one blind spot is a refusal, not a wrong file. `head -n 1` bounds it to the first match, because `tool_input.file_path` is the only `file_path` the matched tools emit and a second occurrence would indicate a payload shape this hook does not understand.

**Alternatives considered**:

- **`jq`** — the documented approach and the obvious one. Rejected on Principle I. Recorded because a future reader will reach for it.
- **`python3`** — same objection; also slower to start, on a path that runs after every edit.
- **A vendored POSIX JSON parser** — a dependency this repository would then own and test, to read one field.
- **Requiring `jq` and reporting its absence as FR-018's visible skip** — considered seriously, since FR-018 already defines a non-fatal, visible degradation. Rejected because FR-018 is about a _formatter_ being unavailable, where the fallback container is the designed remedy; a missing `jq` would disable the hook entirely rather than one check, and there is no fallback for it. Making the whole feature conditional on a tool the constitution forbids requiring is worse than a bounded `sed` expression whose failure mode is a refusal.

## 5. Resolving a path safely in POSIX `sh`

**Decision**: resolve the directory with `cd -- "$(dirname -- "$p")" && pwd -P`, re-attach the basename, then require the result to be prefixed by the repository root followed by `/`.

**Rationale**: `pwd -P` is POSIX and resolves symbolic links in the directory portion, which is what makes the containment test meaningful — a symlink inside the repository pointing outward must not become a write outside it (FR-013). `realpath` is not in POSIX Issue 7 and `readlink -f` is a GNU extension that BSD only grew recently, so neither is safe under Principle IV's "smallest common shell" rationale.

The prefix test is a string comparison against `$REPO_ROOT/`, with the trailing slash present so that a sibling directory whose name merely begins with the repository's name cannot pass. `$REPO_ROOT` is computed the way every existing script computes it — `cd -- "$SCRIPT_DIR/.." && pwd` — so the hook and the checks agree on where the repository is.

**Worked cases**, all refused with exit 0 and no write:

| Input | Refused because |
| A path under another repository | prefix test fails |
| `../../etc/passwd` | prefix test fails after resolution |
| A path inside the repository that no longer exists | `cd` to its directory may succeed, but the regular-file test fails |
| A path whose directory no longer exists | `cd` fails |
| A directory, a symlink to a directory, a device node, a socket | regular-file test fails |
| A symlink inside the repository resolving outside it | prefix test fails on the resolved directory |

**On the worktree case**: the reference states that `${CLAUDE_PROJECT_DIR}` "stays at project root (doesn't follow worktree)" while the `cwd` field in the hook input follows Claude into a worktree. This feature deliberately does not read `cwd`: the hook resolves the repository root from its own location on disk, so a hook invoked from `${CLAUDE_PROJECT_DIR}` formats files against the checks and configuration in that same tree. A session working in a worktree of this repository gets the main checkout's hook script and the main checkout's containment test, and a path inside the worktree is therefore refused rather than formatted with the wrong configuration. That is a conservative outcome and the correct one for a first version; recorded because it is a real limitation and a reader will otherwise treat it as a bug.

## 6. Detecting a file that must not be rewritten

**Decision**: two tests, in order — the regular-file test from §5, then a NUL-byte test on the first 8 KiB.

```sh
if od -An -v -c -N 8192 -- "$p" | grep -q '\\0'; then exit 0; fi
```

**Rationale**: FR-009 requires a file whose content is not text to be left byte-identical. In practice the three rewriting checks match only text extensions, so a binary file is already outside their globs and would be skipped by `collect()` — the NUL test is defence rather than the primary mechanism, and it is written that way in the plan. `od` is POSIX; `grep -I`, `file --mime`, and `grep -q $'\0'` are not portable enough to rely on.

8 KiB rather than the whole file: this runs after every edit, and a NUL byte in the first 8 KiB is how every tool that makes this distinction makes it.

**Alternatives considered**: trusting the globs alone (rejected — FR-009 is a stated requirement and must be verifiable per SC-005); `file(1)` output parsing (rejected — its wording is not stable across implementations).

## 7. Which checks the hook may invoke, and in what order

**Decision**: `lint-format.sh`, then `lint-markdown.sh`, then `lint-python.sh` — each with `--fix -- <file>`. No others.

**Rationale**: FR-004 restricts the hook to standards that can rewrite. From the existing scripts:

| Check | Can rewrite? | Evidence |
| format | yes | `lint-format.sh:59-60` sets `--write` under `--fix` |
| markdown | yes | `lint-markdown.sh:21` passes `--fix` |
| python | yes | `lint-python.sh:21-22` runs `ruff check --fix` then `ruff format` |
| editorconfig | no | `lint-editorconfig.sh:22` calls `no_automatic_fix` |
| yaml | no | `lint-yaml.sh:21` calls `no_automatic_fix` |
| shell | no | `lint-shell.sh:21` calls `no_automatic_fix` |
| citations | no | `lint-citations.sh:51` calls `no_automatic_fix` |

Invoking a report-only check per edit would report violations the modification did not cause and fail the session for them, which is the outcome FR-004 exists to prevent.

**Order** is `lint.sh`'s own, and it is load-bearing for Markdown, which both `format` and `markdown` govern. `.markdownlint-cli2.jsonc` disables 22 rules that conflict with Prettier, so markdownlint's remaining fixes are ones Prettier does not have an opinion about; running Prettier first and markdownlint second therefore converges. The reverse order does not reliably converge, and the constitution's Quality Gate rationale names exactly this hazard: "two tools rewriting the same file, where the verdict depends on the order they ran in". FR-005 requires the order be fixed and declared; taking it from `lint.sh` means there is one order in the repository, not two.

**No extension-to-check mapping in the hook.** Each check's `collect()` already declares its own globs (`lint-format.sh:25`, `lint-markdown.sh:18`, `lint-python.sh:18`) and exits 0 with `no files in scope` when a path matches none of them (`common.sh:144-150`). Invoking all three unconditionally and letting each self-filter means the mapping exists once, in the check that owns it. A table in the hook would be a second declaration of the same fact — the exact duplication half one of this feature removes.

## 8. How the hook reports: status, failure, and unavailable tooling

**Decision**: three distinct outcomes, mapped onto the documented `PostToolUse` output contract.

| Outcome | Mechanism | Requirement |
| A check rewrote or examined the file | exit 0, JSON on stdout with `systemMessage` naming the file and the check | FR-012 |
| No check governs the file | exit 0, no `systemMessage` | FR-007, plus the Assumptions entry on status frequency |
| A check failed (exit 1, or 2, or 4) | exit 2, with the file, the check, and the check's own unmodified output on stderr | FR-011 |
| A check could run neither natively nor in its container (exit 3) | exit 0, JSON on stdout with `systemMessage` naming the missing native tool and the image | FR-018 |

**Rationale**: the reference states that `systemMessage` is "Shown to user on most events" and lists `PostToolUse` among the events supporting `additionalContext`, while for `PostToolUse` the exit-2 path's "blocking message comes from ... stderr text" and stderr "is shown to Claude". So the two audiences FR-011 and FR-012 name are addressable separately and by documented means: `systemMessage` reaches the contributor, stderr reaches the session. `PostToolUse` cannot block, so exit 2 here is a reporting channel rather than a veto — which is what makes it safe to use for a failure that must not undo the edit.

Building the JSON with a printf of a fixed shape rather than a JSON encoder is acceptable only because the only interpolated value is the check name (a fixed word from a known set) and the file path. The reference warns that a malformed payload produces a parse notice even on exit 0, so the path is emitted with its backslashes and double quotes escaped before interpolation. That escaping is two `sed` substitutions and is written out in the plan.

The status line's prefix is `==>`, matching `say()` in `common.sh:61-64`, so hook output and check output read as one system.

**Exit 3 is deliberately not a failure.** `common.sh:172` exits 3 when neither the native tool nor `docker` is available, naming both. Passing that through as exit 2 would make a container runtime a precondition for editing any governed file, which Principle I forbids — and `editorconfig-checker` is already absent natively on the development machine, so this is a real path, not a hypothetical. Reporting it visibly satisfies Principle I's own rationale that "a check that only runs after a setup ritual is a check that silently stops running".

**Exit 4** (not a git working tree) is treated as a failure rather than a skip: the hook only ever runs inside this repository, so exit 4 means something is genuinely wrong.

## 9. Recursion: why `PostToolUse` cannot re-fire from the hook's own writes

**Decision**: rely on the event's semantics as the primary guarantee, and add an environment-variable guard as a second, independent one.

**Rationale**: `PostToolUse` fires after a **tool call**. The hook rewrites files by invoking check scripts, which invoke formatters, which write to disk directly — no `Edit`, no `Write`, no tool call of any kind. So the formatter's write produces no `PostToolUse` event and the loop the requirement names cannot form. This is a property of the chosen event, and it is the reason §1 rejected `FileChanged`, which does fire on plain on-disk writes and would form exactly that loop.

FR-010 is a hard requirement, so it does not rest on one argument. The guard is a variable the hook exports before invoking anything and tests on entry; a second invocation inside the first exits 0 immediately. It costs two lines and covers the cases the reasoning above does not: a formatter that itself invoked Claude Code, a future edit that adds a tool-calling step, and a nested invocation through some path nobody has thought of yet.

**Alternatives considered**: a lock file (rejected — needs cleanup on every abnormal exit, and a stale lock disables formatting silently, which is the FR-018 failure mode arriving by another route); a content hash compared before and after (rejected — solves a different problem, namely detecting whether anything changed, and does not bound invocations).

## 10. Extending the check CLI with a path list

**Decision**: an optional trailing `-- <path>...` on every check script, parsed in `common.sh`'s `parse_args()`, intersected with the computed scope in `collect()`.

**Rationale**: this is the one change that makes reuse possible at all. Today `parse_args()` rejects every argument but `--fix`, `-h` and `--help` (`common.sh:97-114`), and `file_list()` enumerates the whole repository (`scope.sh:39-49`). FR-016 needs one named file; FR-002 forbids touching any other.

**Intersection, not substitution.** The paths narrow the scope; they never widen it. A path outside the check's globs, or excluded by the check's own declaration, is not checked — which is what makes FR-006 (excluded paths left byte-identical) and FR-007 (unsupported kinds left byte-identical) fall out of `collect()` rather than needing separate logic in the hook. Implementation: keep `file_list()`'s output as the authority and filter it by the requested paths, rather than validating the requested paths and passing them through. The difference matters — the second form would let a caller reach an excluded file.

**Backward compatibility.** No arguments and bare `--fix` behave exactly as today, so FR-017 holds and the constitution's "Each check MUST be runnable from the repository root without arguments" is untouched. `--` as the separator is the POSIX convention for "options end here", so a path that begins with a dash cannot be mistaken for a flag.

**Exit statuses** gain one case, documented in the amended contract: a requested path that survives no filter yields the existing `no files in scope` message and exit 0 (`common.sh:144-150`). That is already the right answer and needs no new code.

**Alternatives considered**:

- **An environment variable, `LINT_PATHS`** — no CLI change at all, which looked like it preserved the contract. Rejected: `contracts/cli.md:161-166` states "No other variable is read", so this breaks the same contract by a less visible route, and an invisible input is worse than a documented argument.
- **A separate `scripts/format-one.sh` that calls the tools directly** — rejected as the primary design at Step 2 of this run, because it re-implements the native-or-container resolution, the pinned digests, the globs and the exclusions in a second place. Four things that can drift, and Principle I's container fallback is the first to be dropped for latency.
- **Passing paths positionally with no `--`** — rejected: ambiguous against a future flag, and a filename beginning with `-` becomes a parse error.

## 11. Where each check's exclusions are declared

**Decision**: each check reads its exclusions from the configuration file that already drives it. `collect()` takes the check's exclusion source; `scope.sh` holds one extractor per source.

| Check | Declaration | Syntax | Extractor |
| format | `.prettierignore` | gitignore-style | `extract_plain` |
| markdown | `ignores` in `.markdownlint-cli2.jsonc` | JSONC array, globs with `/**` on directories | `extract_markdownlint` |
| yaml | `ignore` in `.yamllint.yml` | YAML block scalar | `extract_yamllint` |
| python | `exclude` in `ruff.toml` | TOML array | `extract_ruff` |
| editorconfig | `Exclude` in `.editorconfig-checker.json` | JSON array of **regexes** | `extract_editorconfig` |
| shell | `.shellcheckrc`, marker block | see §12 | new, modelled on `extract_plain` |
| citations | none needed | see §15 | — |

**Rationale**: FR-021 requires exactly one declaration per check, FR-022 requires it be the tool's own mechanism where one exists, and FR-027 requires a contributor invoking a tool by hand to get the same exclusions. Reading the tool's own file satisfies all three at once: there is one copy, it is the copy the tool itself honours, and a hand invocation therefore cannot diverge from the runner.

**The extractors already exist and must not be rewritten.** `lint-scope.sh:55-100` holds all six, written and working, because comparing the six declarations required parsing all six. They normalise each syntax to one plain path per line, sorted — which is exactly the form `exclude_pathspecs()` needs to emit `:(exclude)` pathspecs. Promoting them into `scope.sh` turns a cross-check into a source. Deleting the file they live in without promoting them first would throw away the only part of the old design worth keeping.

Two syntax facts the extractors already handle, recorded because they look like bugs:

- `.editorconfig-checker.json` holds **regexes**, not globs. `extract_editorconfig` strips the leading `^`, the trailing `$` or `/`, and then deletes every backslash — the comment at `lint-scope.sh:88-93` explains that a single unescaping pass would leave one behind, because JSON writes an escaped dot as two characters.
- `ruff.toml`'s `exclude` **replaces** Ruff's defaults rather than extending them, as its own comment says. That is pre-existing and unchanged by this feature; it is noted so nobody "fixes" it into an extension.

**Alternatives considered**:

- **Keeping `.lintignore` and dropping the five sibling declarations** — the mirror image, and it was the design before FR-013a. Rejected: it fails FR-027, since a hand invocation of Prettier would then ignore nothing. It is also not what was asked for.
- **One new shared file in a neutral format, read by all seven** — that is `.lintignore` again under another name. Rejected as the change that this feature exists to undo.

## 12. ShellCheck, the check with no exclusion mechanism

**Decision**: a marked comment block in `.shellcheckrc`, read by a new extractor.

```sh
# lint-exclude-begin
# .git
# .specify/scripts
# ...
# lint-exclude-end
```

**Rationale**: `.shellcheckrc` has no path-exclusion directive at all — its own lines 38-56 document that, and it is why `lint-scope.sh:146` reports shell as `UNVERIFIABLE` rather than pass or fail. FR-023 requires the exclusions be declared "in a place a reader can find from that check alone", and Principle V requires every linter be "driven by a configuration file committed to this repository at a documented path".

`.shellcheckrc` satisfies both better than any alternative: it is the file a reader looking for ShellCheck's configuration opens, it is committed, it is at a documented path, and ShellCheck itself ignores comment lines, so the block is inert to the tool while being authoritative for the runner. The markers make the block machine-readable without a format the reader has to learn.

**Alternatives considered**:

- **A list inside `lint-shell.sh`** — the obvious alternative and the one the plan prompt asked to have weighed. Rejected on Principle V: a shell script is not "a configuration file committed at a documented path", and the principle's rationale is that behaviour must not depend on something a reader would not think to look at. It also breaks the symmetry every other check now has — six checks reading a config file and one reading its own source is a shape that invites the seventh reader to reintroduce a central list.
- **A `.shellcheckignore` file** — inventing a filename ShellCheck does not read. Rejected: it looks like a tool mechanism and is not one, which is worse than a comment block that is honestly a repository convention. It is also a seventh top-level dotfile for one check.
- **`shellcheck --exclude`** — excludes _rule codes_, not paths. Not applicable.

**Cost, stated plainly**: this is the one declaration in the feature that is a repository convention rather than a tool mechanism, so a contributor running `shellcheck` by hand across the tree does **not** get these exclusions — FR-027 cannot be satisfied for this check, because the tool provides no way to satisfy it. That was already true before this feature (nothing excluded paths from a hand-run ShellCheck) and is unchanged by it. It is documented in `.shellcheckrc` next to the block.

## 13. Hardening the promoted extractors

**Decision**: fix two fragilities during the promotion, and cover them in the self-test.

1. **`extract_ruff` requires a trailing comma.** Its pattern is `s/^[[:space:]]*"\(.*\)",$/\1/p` — an array whose last element has no trailing comma silently loses that element. It passes today only because every entry in `ruff.toml` happens to carry one. As a cross-check that was a latent bug; as the **source** of the file list it becomes a silent scope hole. Make the comma optional, as `extract_markdownlint` already does with `",\{0,1\}$"`.
2. **No extractor fails loudly on a missing or unparseable file.** Today a missing config yields an empty list, the comparison fails, and `lint-scope.sh` names the difference. With the extractor as the source, an empty list means "exclude nothing" and every excluded path silently enters scope. Each extractor must therefore distinguish "file present, no exclusions declared" from "file absent or the block not found", and the second must exit non-zero naming the file. This is Principle II applied to the new code path: a partial result that exits zero is indistinguishable from a pass.

**Rationale**: promoting a comparison to a source changes the consequence of every one of its failure modes from a loud mismatch to a silent widening of scope. That inversion is the main risk half one carries, and it is worth two explicit fixes and two self-test fixtures.

## 14. Proving no path changed coverage

**Decision**: capture each check's file list before and after -- the base commit's tree for "before", the current tree for "after" -- and require byte equality after sorting. Keep the comparison as a self-test fixture, not a one-off.

**Rationale**: FR-024 states the equivalence, FR-025 requires it be demonstrated mechanically, SC-002 quantifies it as zero paths gained and zero lost. CHK012 and CHK013 sharpened two details this decision has to settle:

- **Per check, not in aggregate.** A path lost by `markdown` and gained by `yaml` sums to zero and is a defect. The comparison is run once per check and reported per check.
- **The file list, not the exclusion set.** Two exclusion sets can differ while producing identical file lists — an exclusion for a path that does not exist, or one subsumed by another. The file list is what a check actually examines, so it is what the claim is about. The exclusion sets are compared too, as a diagnostic, but equality of file lists is the requirement.

**Sorted, not ordered.** `git ls-files` output order is not part of any contract, and requiring the same order would fail on a difference that changes no behaviour — the same reasoning `lint-scope.sh:50-51` already applies to the exclusion sets.

**Mechanically, and repeatably.** A before/after diff run once during implementation proves the change was correct on the day. A fixture proves it stays correct, which is what SC-008 needs. Capture the "before" lists from the base commit rather than from a hand-written file, so the baseline cannot drift from what the code actually did.

**The mechanism, settled (T004).** The "before" side comes from a detached worktree of the base commit, created in the scratchpad, measured, and removed:

```sh
git worktree add --detach "$SCRATCH/base-tree" main
"$SCRATCH/scope-snapshot.sh" "$SCRATCH/base-tree" "$check" # before
"$SCRATCH/scope-snapshot.sh" "$REPO_ROOT" "$check"         # after
git worktree remove --force "$SCRATCH/base-tree"
```

Nothing is stored in the working tree, so nothing perturbs the lists being measured — `lint-editorconfig.sh` collects `'*'`, so a baseline file or a harness committed inside the repository would enter the very lists it measures. `--force` on removal is safe only because that tree is detached scratch that is never edited.

**The comparison is restricted to paths that existed at the base commit.** This is a correction to the naive reading of the paragraph above, and it is not optional. This feature adds files of its own — its `specs/004-format-hook-scope/*.md` artifacts and `scripts/format-file.sh` — and untracked files enter the list, because `file_list()` passes `--others --exclude-standard` to `git ls-files`. An unfiltered before/after comparison therefore reports this feature's own output as paths "gained", which is not evidence about the exclusion mechanism. Measured before either half landed: `editorconfig` is 115 paths in the current tree, 104 filtered to base-tracked paths, and 104 in the base tree — the 11-path gap is exactly this feature's artifacts. So the "after" list is intersected with `git -C base-tree ls-files` before comparison.

**The new files get their own assertion instead.** Equality says nothing about a path that exists on only one side, so each file this feature adds is asserted into the lists it belongs in and out of the ones it does not. `.claude/settings.json` must appear in **no** check's list, because every check's exclusion declaration excludes `.claude` (section 11); `scripts/format-file.sh` must appear in `editorconfig`, `format` and `shell`. That assertion is what catches an exclusion declaration that lost `.claude` during promotion — a defect equality alone would pass, because `.claude/settings.json` does not exist at the base commit and so is filtered out of the equality comparison entirely.

**Result, run against the finished change (T039).** Six comparable lists, zero paths gained, zero lost, per check:

| Check | Paths before | Paths after | Difference |
| `editorconfig` | 102 | 102 | none |
| `format` | 96 | 96 | none |
| `markdown` | 69 | 69 | none |
| `yaml` | 2 | 2 | none |
| `shell` | 20 | 20 | none |
| `python` | 0 | 0 | none |

Six, not seven. `citations` consumes no file list at all, so it has nothing to compare — section 15. `python` is legitimately zero on both sides: the repository contains no Python, and the check reports `no files in scope` and exits 0.

Three exemptions are declared in the comparison rather than left implicit, because each one would otherwise read as a coverage change:

- **Paths this feature adds** are excluded from the equality comparison and asserted separately (the paragraphs above). They exist on one side only.
- **`.lintignore` and `scripts/lint-scope.sh`** are excluded from the "before" side. This feature deletes them, so every check that matched them reports a path lost — the feature working, not a regression. Naming exactly those two keeps any _other_ lost path a failure.
- **Nothing else.** A difference outside those two lists is a defect in the change, never grounds for amending FR-024.

**Why this proof does not survive as a fixture, and what does.** The comparison's "before" side is the base commit. Once this change is on the default branch, that side _is_ this change, so the comparison holds trivially and can no longer fail — a fixture that cannot fail is worse than no fixture, because it reads as coverage. So the base-commit comparison is a migration proof, run here, recorded here.

What replaced it in `scripts/selftest.sh` is a permanently falsifiable property: each check's file list is built from **its own** declaration and no other. Every declaration in a fixture root gains a sentinel path of its own, and each check must not see files under its own sentinel while it must see files under all five others. The second half is what gives the fixture teeth — the six declarations currently hold identical path sets, so a check wired to the wrong one would pass any assertion that only looked for absences. Two further fixtures cover the failure inversion this change carries: a declaration file that is missing, and a declaration block that is absent, each of which must exit non-zero naming the file.

That trio caught a real defect during implementation, which is the argument for it. The first version of `file_list` read the exclusions **inside** the pipeline feeding `xargs`, so the extractors ran in a subshell; `die` there ended only the subshell, `xargs` received the globs with no exclusions and exited 0, and an unreadable declaration silently widened the check's scope — the exact failure mode this section and the contract's Error-behaviour section exist to forbid. The two loud-failure fixtures reported `DID NOT FAIL on a bad fixture (exit 0)` and the exclusions are now read, and validated, before the pipeline is built.

## 14a. Decisions the implementation made that this research did not anticipate

The convention `specs/001-quality-gate-plugin/research.md` established: every setting that departs from a tool's or a platform's default carries a written reason. Audited against the finished code, five decisions were made while implementing that no section above had settled. Each is recorded here rather than only in a code comment, because each was a real choice with a rejected alternative.

**A symlink is refused, not resolved** (`scripts/format-file.sh`, rule 5). Section 5 settled path resolution as `cd` plus `pwd -P` and treated containment as sufficient against symlinks. It is not: `pwd -P` resolves the _directory_ portion, so a link whose parent directory is genuinely inside the repository passes containment while its final component points anywhere at all, and `-f` then follows it. The implementation adds a distinct rule that refuses any symlink. Refused rather than resolved because resolution needs `readlink`, which is not POSIX and whose `-f` the macOS build lacks — the same objection `lib/common.sh` already records — and because Prettier refuses a symlink argument outright, so following one would turn an ordinary edit into an exit `2` instead of a silent skip. A link pointing inside the repository loses nothing: editing the file it points at formats it through its real path. This was found by the self-test fixture, which reported exit `2` where the contract required silence.

**The exclusions are read before the pipeline, not inside it** (`scripts/lib/scope.sh`, `file_list`). Section 13's hardening and the contract's Error-behaviour section require an unreadable declaration to be fatal. The first implementation read the exclusions inside the pipeline feeding `xargs`, which put the extractors in a subshell: `die` there ended only the subshell, `xargs` received the globs with no exclusions and exited 0, and the check ran with its scope silently widened — the exact failure the hardening exists to forbid, reintroduced by where the call sat rather than by what it did. The exclusions are now extracted and validated first, and `file_list` propagates the status itself because a command substitution is also a subshell.

**The path list filters the computed list, and the filter is line-oriented with a guard** (`scripts/lib/common.sh`, `filter_list`). `contracts/check-cli.md` requires filtering rather than pass-through; it does not say how. A shell variable cannot hold a NUL byte, so the requested paths are newline-separated and a path containing a newline is a usage error rather than a silent mis-parse. The file list itself is NUL-separated, and comparing it line-wise would let a file name containing a newline match the wrong record — so the number of NUL bytes and the number of lines after translation must agree, and disagreement is fatal. `grep -z` would avoid the guard and is not POSIX; `awk` with `RS="\0"` was tested on this machine and does not work in the BSD build, which reads the whole input as one record.

**Exit `1` is the status for an unreadable declaration.** The documented set is `0`, `1`, `2`, `3`, `4` and this feature adds none. A missing declaration is a defect in the repository's own configuration, which is what the check reports, so `EX_VIOLATION` is the closest documented meaning; `2` is reserved for an unrecognised argument and `3` for absent tooling, and inventing a sixth status would break `contracts/cli.md`'s closed set for a case the aggregate already handles by stopping.

**The scope fixture runs `file_list` in a separate process, not a subshell** (`scripts/selftest.sh`, `scope_list`). The fixture has to point `REPO_ROOT` at a fixture root. A subshell assignment is correct at runtime and makes every later use of `REPO_ROOT` in that file suspect — to a reader, and to ShellCheck, which reports SC2030/SC2031 and cannot see that the change was meant to be contained. An assignment prefix on an external `sh` is genuine isolation, needs no suppression, and additionally contains the `die` that two of the fixtures deliberately trigger.

One further note, on a thing that is _not_ a departure: the status line's prefix, the `==>` from `say()`, and the choice of `sed` over `jq` are both already recorded in sections 8 and 4 and are unchanged by the implementation.

## 15. What `citations` needs, and why the answer is nothing

**Decision**: `lint-citations.sh` gets no exclusion declaration and no change.

**Rationale**: it does not use `collect()` or `file_list()` at all. Its scope is a fixed directory, `TEMPLATE_DIR=.github` (`lint-citations.sh:59`), and it enumerates the governance-quotation markers inside it. There is nothing for an exclusion declaration to exclude, so FR-021's "exactly one place" is satisfied trivially — the check has no exclusions to declare.

Recorded explicitly because the count matters elsewhere: after half one, `lint.sh` runs **seven** checks, of which **six** consume a file list and therefore need a declaration. A reader who assumes seven declarations will look for a seventh that should not exist.

## 16. Documents to correct

Half one deletes a file and a check that several committed documents describe as present. FR-029 requires each be corrected and any superseded requirement marked as such.

| Document | What is now false |
| `specs/001-quality-gate-plugin/contracts/cli.md:12` | "reads its scope from `.lintignore` and nothing else" — for every command |
| `specs/001-quality-gate-plugin/contracts/cli.md:11,17` | "accepts at most one argument, `--fix`" and "Any other argument is a usage error" — the `-- <path>...` list is new |
| `specs/001-quality-gate-plugin/contracts/cli.md:37` | lists the aggregate's checks; already out of date (six named, eight run) and becomes seven |
| `specs/001-quality-gate-plugin/contracts/cli.md` | the `scripts/lint-scope.sh` section, for a script that no longer exists |
| `specs/001-quality-gate-plugin/spec.md` | FR-013, FR-013a, FR-013b, FR-013c — the single-declaration-plus-mirrors design this feature replaces. Marked superseded, following how `specs/003-ccd-skill-rename/` superseded 002's two interface contracts |
| `CLAUDE.md` | "all eight checks"; `scope` in the list of per-standard scripts; the bullet stating `.lintignore` drives the runner's file list while each check also declares its own; and the sentence naming `scope` and `citations` as the two checks needing no tool |
| `.gitignore` | the comment on `.lint-selftest-tmp/` says "Also in `.lintignore` -- both are required" |
| `scripts/selftest.sh` | the scope-divergence fixture, which tests a check that will not exist |
| `scripts/lint.sh:33` and its preceding comment | `CHECKS` drops `scope`; the comment explaining why `scope` leads goes with it |
| `README.md` | to be checked during implementation for the same three claims |

`cli.md:37` is worth one extra note: it already disagrees with the code, naming six checks where `lint.sh:33` runs eight. The sub-agent sweep found this and it is a pre-existing defect, not one this feature introduces. Correcting it is in scope because this feature is editing the same line for the same reason.

### Sweep result (T045a, T045b)

Every document in the table above was corrected, plus the six exclusion configurations' own header comments, which mattered most: each one explained that the runner computed the file list from `.lintignore` while the configuration merely mirrored it for a by-hand invocation. That is now exactly backwards — the configuration **is** the declaration, and the runner reads it — so a contributor following the old comment would have drawn the wrong conclusion about where to add an excluded path.

Counted over tracked files, before and after:

| Pattern | Files before | Files after | Where the remainder is |
| `.lintignore` | 28 | 16 | all in `specs/001-`, `specs/002-`, `specs/003-` |
| `lint-scope` | 25 | 14 | 13 in those same historical directories, 1 live |

The one live remainder is deliberate: `scripts/lib/scope.sh`'s header records that the extractors were **promoted verbatim from the deleted `scripts/lint-scope.sh`**. That is provenance, not a stale claim — it tells a reader where the code came from and why it is not rewritten, which is the one thing about the old design worth keeping.

The historical directories are left unedited except for FR-013's supersession markers, per SC-009 as narrowed. Rewriting three features' records would contradict the supersession approach itself and produce a large diff of changes to decisions nobody is revisiting.

One false positive is worth naming so the next sweep does not chase it: `.claude/skills/speckit-implement/SKILL.md` matches a loose search for `lintignore` because it mentions `.eslintignore`. It is Spec Kit's own file and has nothing to do with this repository's scope arrangement.

## 17. Co-existing with a formatter configured outside the repository

**Decision**: publish a documented stand-down marker — the existence of `scripts/format-file.sh` — and rely on the external formatter testing for it. Change nothing outside the repository root.

**Rationale**: this is not hypothetical, and it was found by observation rather than by reasoning. While this plan was being written, a `PostToolUse` hook configured in the developer's own `~/.claude/settings.json` — matcher `Edit|Write`, command `~/.claude/hooks/post-tool-use.sh` — fired on a newly written file in this repository and rewrote it. That script maps extension to tool and rewrites in place: `.md` through `markdownlint-cli2 --no-globs --fix`, `.yaml`/`.yml` and `.json` through `prettier --write`, `.py` through `ruff format`, plus several kinds this repository does not govern.

The reference is explicit about what happens when a second hook is added for the same event: _"All matching hooks run in parallel for a given event"_, and deduplication applies only to _"Same handler defined in multiple settings files"_ — two different handlers both run. So a project hook would not supersede the external one; it would run beside it, concurrently, on the same file. Two processes invoking `prettier --write` on one path is not just the order-dependence the constitution's Quality Gate rationale warns about — it risks a truncated file, and FR-005's determinism requirement cannot hold.

Nothing in a project settings file can disable one specific user-level hook. `disableAllHooks` is all-or-nothing and would disable the project's own hook too, so it is not a mechanism for this.

**Why the external formatter is the wrong authority for this repository**, recorded so that "just keep the one that already works" is a weighed and rejected option rather than an unconsidered one:

| | External hook, as found | This repository's checks |
| Tool resolution | native only | native, then the digest-pinned container (Principles I and III) |
| Prerequisite | `python3`, or it skips | POSIX `sh` and `git` |
| `.sh`, `.jsonc`, `.xml` | not handled | Prettier with `prettier-plugin-sh` and `@prettier/plugin-xml` |
| Markdown exclusions | `--no-globs` bypasses `ignores` in `.markdownlint-cli2.jsonc` | honours it — and after half one that array _is_ markdown's single declaration |
| Shell dialect | bash: `[[ ]]`, arrays, `set -o pipefail` | POSIX `sh`, zero ShellCheck findings (Principle IV) |

**The mechanism.** FR-030 forbids this repository from editing configuration outside its own root, which rules out the obvious fix of patching the external script. What the repository can do is offer something stable to test for. `scripts/format-file.sh` is executable, at a fixed path, and its presence means "this repository formats its own files". An external formatter stands down with one line:

```sh
[ -x "$WORKSPACE_REAL/scripts/format-file.sh" ] && exit 0
```

placed after that script resolves its workspace and before it selects a tool. The developer applies it; this feature documents it and does not apply it. That keeps the external formatter working for every other project — including the `.cs`, `.js`/`.ts`, `.php`, `.css` and Dockerfile kinds this repository has no equivalent for — while making this repository's own checks the single authority here.

**Alternatives considered**:

- **Remove the external hook entirely.** Clean for this repository, and it silently removes formatting from every other project the developer works in. Rejected as disproportionate; offered as a choice and declined.
- **Ship the project hook and accept concurrent writers.** Rejected: a truncation risk on the developer's own files, with FR-005 unsatisfiable. It was on the table and was not chosen.
- **Have the project hook detect the external one and defer to it.** Inverts the authority the wrong way — the external formatter does not honour this repository's exclusions or its pinned versions, so deferring to it would mean this repository's standards stop being applied in this repository.
- **Narrow the project hook's matcher to the kinds the external one misses** (`.sh`, `.jsonc`, `.xml`). Rejected: the division of labour would live in a machine-local file this repository cannot see, and would break the moment either side gained a file kind.
- **Environment variable handshake** — the project hook exporting something the external one tests. Rejected: hooks run in parallel as sibling processes, so neither can see the other's environment.

**Residual limitation, stated plainly**: until the stand-down line is applied, both formatters run. The repository cannot detect that from inside, cannot warn about it, and must not fix it by editing the developer's file. This is therefore a documentation obligation (SC-012) rather than an enforceable property, and the documentation says so in those terms.
