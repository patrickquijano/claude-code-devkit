# Research: One shared library directory for the checking machinery

**Date**: 2026-09-12 | **Feature**: [spec.md](./spec.md)

Every decision below that departs from a default carries its reason here, following the convention `specs/001-quality-gate-plugin/research.md` established. A reader who wants to "fix" one of these should find the reason before changing it.

## Contents

1. Why the bodies moved out of the entry points
2. How one check is invoked — the decision that carries the change
3. Why not `( c ) & wait "$!"`
4. Why the arguments are arguments and not environment
5. `SCRIPT_DIR` has one meaning
6. How the self-test reaches the invocation
7. The `-- PATH...` passthrough
8. Usage headers that over-promised
9. Why `scripts/selftest.sh` is exempt from the wrapper rule
10. Why every entry point now has a smoke case, and why not `-h`
11. `/bin/sh`, not a `PATH` lookup
12. Why `usage()` takes variables rather than one text per check
13. Why `citations` narrows, rather than being exempted from narrowing
14. Where a relative path in `-- PATH...` is resolved

---

## 1. Why the bodies moved out of the entry points

`lint.sh` executed its six siblings, `format-file.sh` executed three of them, and `selftest.sh` executed six entry points to test them. Each is a shared component declared nowhere: the aggregate depended on six other files being present, executable and on an expected relative path, and the same dependency sat inside the edit hook. Moving the bodies into `scripts/lib/` and leaving each entry point a wrapper makes the dependency a `.` of a named file.

## 2. How one check is invoked — the decision that carries the change

Each check is a separate `sh` process, spawned by `run_standard_isolated`.

The first attempt ran each in a subshell — `(run_standard_as …) || status=$?`. That is wrong, and it passed every self-test case while being wrong. POSIX ignores `-e` while executing any command of an AND-OR list other than the last, and the suppression propagates into the subshell:

```sh
set -eu
body() {
  false
  echo "CONTINUED"
}
st=0
(body) || st=$? # prints CONTINUED, st=0
```

Confirmed in `sh`, `bash` and `dash`. Neither `set -e` inside the subshell nor `set +e` around the call re-arms it — the option is set, but the ignore-context still applies. A command failing part-way through a check body would continue, and the aggregate could report success: exactly what Principle II forbids, which names a subshell explicitly.

A separate process restores what each check had before the move — its own live `set -eu` — and needs no argument about which POSIX corner applies. One `sh` per check is negligible beside a container pull.

## 3. Why not `( c ) & wait "$!"`

This form does preserve errexit, and was the one first proposed. It was rejected: POSIX sets SIGINT and SIGQUIT to ignored in an async subshell when job control is disabled, and the disposition is inherited by its children. Ctrl-C during a container pull would then leave the container running and orphaned, while the runner itself died. Measured, not assumed — a backgrounded `sleep` survived a SIGINT that killed its runner.

## 4. Why the arguments are arguments and not environment

`MODE` and `REQUESTED_PATHS` reach the child as `[--fix] [-- PATH...]`, re-parsed there by `check_main`. Passing them in the environment is silently wrong: `lib/common.sh` assigns both as it is sourced, so the child overwrites what it was given and every check runs over the whole tree. The self-test caught this — two hook cases went from silent to exit 2 — which is the first evidence the new aggregate cases were worth adding.

The upside is that the child is no longer an _equivalent_ of the contract's invocation in `specs/004-format-hook-scope/contracts/check-cli.md`. It is that invocation.

## 5. `SCRIPT_DIR` has one meaning

Every entry point sets `SCRIPT_DIR` to `scripts/`, and `lib/checks.sh` depends on it. The two wrappers in `scripts/hooks/` initially set it to `scripts/hooks/` and sourced `"$SCRIPT_DIR/../lib/…"`, while the self-test ran the same libraries with `SCRIPT_DIR` set to `scripts/`. Harmless only because neither reads it today; the first shared helper either needs makes it a divergence the self-test cannot see. Both now resolve one level up.

## 6. How the self-test reaches the invocation

The aggregate cases build a probe tree whose `lib/checks.sh` sources the committed one and then replaces `CHECKS` and `run_standard`. Everything above a check body — `lint_main`, `run_standard_isolated`, and the hook's use of both — stays the committed code.

Standing in for `run_standard_isolated` instead was rejected for the obvious reason: it is the code under test. The format-hook cases did stand in for its predecessor, which is why nothing noticed the subshell defect.

The three libraries `checks.sh` sources are symlinked rather than copied, because `SCRIPT_DIR` must name the probe tree — that is what `run_standard_isolated` hands the `sh` it spawns — and the committed `checks.sh` resolves its own sources through `SCRIPT_DIR`.

## 7. The `-- PATH...` passthrough

`lint.sh` parsed a trailing `-- PATH...`, built a `--fix` argument from it and dropped the path list, so every check ran over the whole tree. `specs/004-format-hook-scope/contracts/check-cli.md` says the list passes through. It now does.

## 8. Usage headers that over-promised

`citations`, `editorconfig`, `yaml` and `shell` call `no_automatic_fix` and rewrite nothing; `citations` has no tool at all. Their new usage headers promised `--fix   rewrite what the tool can rewrite`. The shared `usage()` already words it correctly. The four headers now say what they do.

## 9. Why `scripts/selftest.sh` is exempt from the wrapper rule

The rule as first written — "every entry point under `scripts/` is a wrapper with no logic of its own" — was broken by `scripts/selftest.sh` in the same commit that stated it: it is an entry point, it sources three libraries, and it holds the whole suite.

Moving its body to `scripts/lib/selftest.sh` would satisfy the letter and buy nothing. The rule exists because a shared component reached by executing a sibling is a dependency declared nowhere, and because a body inside an entry point cannot be tested without executing that entry point. Neither applies here: the suite has exactly one caller — a person or a CI job — and the thing that would test it behind a wrapper is itself.

So the exemption is stated instead, in `README.md` and in FR-001/FR-002, with its reason. A rule the repository visibly breaks teaches contributors that the rules are decorative.

## 10. Why every entry point now has a smoke case, and why not `-h`

Removing the sibling execution removed the only thing that ran the wrappers. `lint.sh` used to execute all seven `lint-<standard>.sh` and `selftest.sh` used to execute six entry points; afterwards twelve of the fourteen had no automated caller at all.

A wrapper is three assignments, one `.` and one call, and the call is the part no static check can reach. Demonstrated: changing `scripts/lint-markdown.sh`'s last line to `check_main markdwon "$@"` passes `scripts/lint-shell.sh` with this repository's own `.shellcheckrc` — `external-sources=true` follows the source, and nothing there knows the argument is wrong — and fails only when the script is run.

`-h` was rejected as the smoke invocation: `parse_args` answers it and exits before any check is named, so the typo above would still pass. Each lint case instead narrows the run to a path inside `.lint-selftest-tmp/`, which every check's exclusion declaration names. The check is reached and dispatched, finds nothing in scope, and exits 0 — no tool and no container. The seven are enumerated by globbing `scripts/lint-*.sh` rather than by reading `CHECKS`, so an eighth wrapper is covered the day it is added.

`compaction-audit.sh` is the one case that asserts a non-zero status: it takes its documented usage exit for missing arguments, because a real run needs a baseline commit and a document, and the property under test is the wrapper's call — a wrong function name ends at 127 and a wrong argument ends somewhere other than 2.

## 11. `/bin/sh`, not a `PATH` lookup

`run_standard_isolated` spawns the child as `/bin/sh -c`. Every entry point declares `#!/bin/sh`, so resolving the child through `PATH` would let a check run under a different shell than the wrapper that invoked it on any machine where `PATH`'s `sh` is not `/bin/sh`. For a repository whose fourth principle is POSIX shell only, that is the one thing not to leave to the environment, and the absolute path costs nothing.

## 12. Why `usage()` takes variables rather than one text per check

FR-009 was written against the file header comments and satisfied there; `scripts/lint-citations.sh -h` went on offering `-- PATH... Narrow this run to the named paths`, a `--fix` described in terms of a tool it does not run, and exit statuses 3 and 4 it cannot return. `-h` is where a user is actually told what a command does, so that is where the requirement had to be met.

Only three lines differ, and only one check differs on them. A second heredoc would duplicate the four lines that do not differ, and two copies of a usage text agree the day they are written. A per-check usage function would put seven near-identical texts where there is one. So `usage()` interpolates `USAGE_FIX` and `USAGE_EXIT`, whose defaults in `lib/common.sh` describe a check that filters a file list and resolves a tool — what `lint.sh` and six of the seven do — and `check_main` overwrites them for `citations`.

The assignment has to happen in `check_main` rather than in `standard_citations`: `parse_args` answers `-h` and exits, so anything `run_standard` sets is too late. `lint_main` never touches them, which is correct — the aggregate does narrow, and it can return both 3 and 4.

## 13. Why `citations` narrows, rather than being exempted from narrowing

`scripts/lint-citations.sh` carried a comment saying `specs/004-format-hook-scope/contracts/check-cli.md` "exempts it from the scope machinery". It does not. That contract opens by amending the shape for **every** check script, gives one semantics formula for the path list, and its `## Reserved` section names exactly one entry point as outside the shape: `scripts/format-file.sh`. `citations` appears in it once, in the ordering rationale. The belief most likely came from `specs/001-quality-gate-plugin/contracts/cli.md`, whose `lint-citations.sh` section lists two invocations and not the path list — an omission in a superseded document, read as a carve-out in the superseding one.

So the check was non-conforming, not exempt, and FR-006 is what made it visible: once `lint.sh` forwarded the path list, `scripts/lint.sh -- README.md` ran `citations` over all of `.github/` and could fail on a file the caller never named.

Two routes were available.

**Route through `lib/scope.sh`**, so the check computes its list the way the other six do, was rejected. `exclusions_for` would need a `citations` branch declaring no exclusions — defensible — but `file_list` requires a git working tree and enumerates through `git ls-files`, and the fixture in `scripts/selftest.sh` is a plain directory built under `.lint-selftest-tmp/`. Inside a git tree that directory is ignored, so `--others --exclude-standard` would return nothing and the fixture would report a pass where it must report a failure. Making the fixture a repository to satisfy the implementation is the wrong direction; the rule in `.claude/rules/husky-git-hooks.md` — a case that needs a temporary git repository is a case that gets deleted the first time it is slow — points the same way.

**Filter the list the check already builds**, which is what shipped. It is the same operation `filter_list` performs, over `find` output instead of `git ls-files` output. No new dependency for the check, and the fixture stays a directory.

Round five asked why `filter_list` itself was not reused, since — unlike `file_list` — it needs no git working tree. The answer is that only half of it is reusable. `filter_list` operates on a NUL-separated list and carries a guard that refuses to filter when the NUL count and the line count disagree, which is how it detects a name containing a newline. This check's list comes from `find`, which separates with newlines; converting it to NUL form would make those two counts agree by construction and turn the guard into decoration. So the half that is genuinely common — resolving `REQUESTED_PATHS` to repository-relative paths through `repo_relative`, dropping what falls outside — is now `requested_relative` in `lib/common.sh`, called by both, and each keeps the comparison its own list shape requires.

The newline case is guarded here too, and differently: every record must name an existing file. Before that guard a split name reached `citations_extract`, where `awk` could not open it and the check ended at exit 2 with the tool's own message — not a silent pass, but a refusal that named neither the check's reason nor the file that caused it. `scripts/selftest.sh`'s `citations/newline-in-name` case asserts the named refusal, and reports `exit 2, and the refusal was not reported` when the guard is removed.

What conforming bought is mostly subtraction: the false comment, `USAGE_PATHS`, `check_main`'s third override, the `ep_expect` status set, and two of the four `-h` cases all went. The two `USAGE_*` variables that remain describe the one thing still true of `citations` alone — it runs no tool, so it rewrites nothing and can reach neither the no-tool nor the no-git exit.

## 14. Where a relative path in `-- PATH...` is resolved

`specs/004-format-hook-scope/contracts/check-cli.md` says a relative path is "resolved against the repository root". `repo_relative` resolves it against the caller's working directory, by `cd`-ing to the path's own directory part and comparing `pwd -P` with the root. The two coincide whenever a check is invoked from the repository root, which `specs/001-quality-gate-plugin/contracts/cli.md` states as the common shape, so nothing in this repository has ever been able to tell them apart.

`standard_citations` can: it `cd`s to `REPO_ROOT` before filtering, so it alone matches the contract's wording.

```text
$ cd .github && ../scripts/lint-citations.sh -- pull_request_template.md
==> lint-citations.sh: no files in scope                   (resolved against the root)

$ cd .github && ../scripts/lint-markdown.sh -- pull_request_template.md
Finding: .github/pull_request_template.md                  (resolved against the cwd)
```

Left as it is, and recorded rather than fixed, for two reasons. It predates this feature, and changing it would change a documented CLI, which FR-007 forbids of this change. And the second run above shows a larger effect of the same cause — `xargs` runs the native tool in the caller's working directory with a repository-relative path, so it lints zero files and exits `0` — which is a defect of running a check from anywhere but the root, not of the path list. Both belong to a change that can carry a CLI amendment; this one names them so the next reader does not have to rediscover that the divergence is known.
