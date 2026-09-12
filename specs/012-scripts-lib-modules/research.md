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
