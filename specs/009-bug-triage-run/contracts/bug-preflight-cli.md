# Contract: `bug-preflight.sh`

Ships at `skills/ccd-speckit-bug-run/scripts/bug-preflight.sh`. Invoked as `sh "${CLAUDE_SKILL_DIR}/scripts/bug-preflight.sh" [slug]`.

Answers, in one call, the three factual questions the run needs before it invokes anything: is the bug-triage capability here, is the working tree already dirty, and is this slug already in use.

## Why one script and not three checks in prose

They are needed at the same moment and nowhere else, and each is a question with a wrong answer rather than a judgement. Collapsing them means one invocation before Stage 1 instead of three, and it means `evaluations.md` can exercise them against a fixture. See [research.md D5](../research.md#d5-two-scripts-not-zero-and-not-three).

## Arguments

| Position | Meaning                            | Required                                       |
| -------- | ---------------------------------- | ---------------------------------------------- |
| `$1`     | the bug slug to test for collision | no — omitted when the maintainer supplied none |

No flags. No environment variables read.

## Output

Tab-separated `key<TAB>value` lines on stdout, one per fact. Stable key order. Diagnostics to stderr.

```text
capability	present
extension-dir	.specify/extensions/bug
stage-assess	found
stage-fix	found
stage-test	found
bugs-root	.specify/bugs
slug	login-timeout
slug-taken	no
dirty	yes
dirty-count	2
dirty-path	src/auth.ts
dirty-path	src/session.ts
verdict	ready
```

### Keys

| Key                                       | Values                            | Notes                                                                                                                                                                                                                                                                                                                               |
| ----------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `capability`                              | `present`, `undetermined`         | **Never `absent`.** `present` requires all three compiled stage skills to be found. Anything else is `undetermined`: a filesystem probe can establish presence and cannot establish absence, because where a compiled skill's files live is an install detail. The caller settles it against the session's available-skills listing |
| `extension-dir`                           | a path, or `-`                    | where `.specify/extensions/bug` was found, for the report                                                                                                                                                                                                                                                                           |
| `stage-assess`, `stage-fix`, `stage-test` | `found`, `missing`                | one line each, always all three, so a partial install is visible rather than collapsed into `absent`                                                                                                                                                                                                                                |
| `bugs-root`                               | a path                            | `.specify/bugs`, whether or not it exists yet                                                                                                                                                                                                                                                                                       |
| `slug`                                    | the slug, or `-`                  | echoed back after normalisation to lowercase kebab-case                                                                                                                                                                                                                                                                             |
| `slug-taken`                              | `yes`, `no`, `n-a`                | `n-a` when no slug was supplied. `yes` means `.specify/bugs/<slug>/` already exists                                                                                                                                                                                                                                                 |
| `dirty`                                   | `yes`, `no`, `unknown`            | `unknown` when the working directory is not a git repository                                                                                                                                                                                                                                                                        |
| `dirty-count`                             | an integer                        | `0` when clean                                                                                                                                                                                                                                                                                                                      |
| `dirty-path`                              | a path                            | **zero or more lines**, one per already-modified path. Absent entirely when clean                                                                                                                                                                                                                                                   |
| `verdict`                                 | `ready`, `undetermined: <reason>` | Never `blocked`. Blocking requires having determined absence, which this script cannot do; the caller decides                                                                                                                                                                                                                       |

## Exit status

`0` when the check ran. `1` only when the script could not run at all — an unreadable working directory, or arguments it cannot parse.

**Exit status is not the verdict.** `exit 0` means the check completed, not that the run may proceed. Read the `verdict` line. Conflating them turns a repository with no bug extension installed into one that is ready, silently, which is the single worst way to misuse this script.

## Behaviour

- **Read-only.** It creates no directory, writes no file, and runs no git command that changes anything. It does not create `.specify/bugs/`.
- **Fails fast.** `set -e`; no pipeline or subshell masks a status (Principle II).
- **POSIX `sh`.** No bashisms; passes `shellcheck -s sh` with zero findings (Principle IV).
- **No package manager.** `git`, `test`, `sed` and `grep` only (Principle I).
- **Not a git repository** is a normal result, not a failure: `dirty` is `unknown`, the run continues, and the closing report says the dirty-path check could not be made.

## What the caller does with it

| Line                                | Caller's obligation                                                                                                                                                                                                                       |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `verdict undetermined: …`           | Do NOT stop on this alone. Check the session's available-skills listing for `speckit-bug-assess`, `speckit-bug-fix` and `speckit-bug-test`. Listed → proceed, noting the layout differs. Not listed → report absence and stop, per FR-023 |
| `stage-* missing`                   | Name which stage is missing. A partial install is a different problem from an absent one                                                                                                                                                  |
| `slug-taken yes`                    | Report it and ask before Stage 1. FR-003 — never let an existing report be overwritten unasked                                                                                                                                            |
| `dirty yes` with `dirty-path` lines | Report the paths before Stage 2. FR-029 — warn, name them, and continue                                                                                                                                                                   |
| `dirty unknown`                     | Say so in the closing report rather than implying the tree was clean                                                                                                                                                                      |

## Regressions this contract exists to catch

**Reading the exit status.** Covered above; it is the reason the `verdict` line exists at all.

**Collapsing the three `stage-*` lines into `capability`.** A repository where the extension directory exists but the skills were never compiled reports `capability undetermined` and three `missing` lines. Dropping the per-stage lines loses the distinction between "not installed" and "installed but not compiled", which are fixed differently.

**Reintroducing `absent`.** The obvious "simplification" is to have the script conclude absence when it finds nothing, sparing the caller a listing check. That is the defect this contract was revised to remove: a filesystem miss means the files are not where this script looked, which on a differing install layout is not the same as the capability being unavailable. The refusal it produces is confident, total, and wrong.

**Making it create `.specify/bugs/`.** It is a preflight. The assess stage creates the directory, and a preflight that creates it makes `slug-taken` permanently `yes` on the second run.

**Treating `dirty unknown` as `no`.** They differ: one is a clean tree, the other is no information. The closing report must not claim a check it did not make.
