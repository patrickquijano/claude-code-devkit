# Gathering the failing evidence

Read before Step 1. Each forge gets its own section, in its own vocabulary. **Never write one instruction covering both** — `.claude/rules/forge-review-requests.md` records that `gh` and `glab` disagree on the shape of every operation these skills perform, and that the wrong one succeeds rather than erroring, which is worse.

Which section applies was decided at Step 0 from the remote. Read it from there.

## Contents

- GitHub
- GitLab
- Choosing among several failures
- Displaying the log
- When retrieval does not work
- A log that arrives degenerate
- Never

## GitHub

The unit is a **workflow run**, containing **jobs**, each containing steps. A run is identified by a numeric run ID.

```sh
gh run list --status failure --limit 10 --json databaseId,name,headBranch,conclusion,createdAt
gh run view <run-id>
gh run view <run-id> --log-failed
```

`--log-failed` is the one that matters: it returns only the failing steps' output, which is the evidence, rather than the whole run's log, which is mostly noise. Use it in preference to `--log` every time.

Scope to the current branch with `--branch <name>` when the user has not named a run. A pasted run URL ends in the run ID.

`gh auth status` establishes authentication. Unauthenticated `gh` fails per call rather than at startup, so probe it at Step 0 rather than discovering it here.

## GitLab

The unit is a **pipeline**, containing **jobs**. A pipeline is identified by a pipeline ID, a job by its own job ID — and the two are not interchangeable, which is the mistake this section exists to prevent.

```sh
glab ci list --status failed --per-page 10
glab ci get --pipeline-id <pipeline-id>
glab ci trace <job-id>
```

`glab ci trace` takes a **job** ID, not the pipeline ID. Get the failing job's ID from `glab ci get` first. Passing a pipeline ID to `trace` does not error usefully.

Scope with `--branch <name>`. `glab auth status` establishes authentication.

## Choosing among several failures

More than one failed run, or more than one failing job within the chosen run → **`AskUserQuestion`**. Never choose.

Present the candidates with what distinguishes them — branch, job name, when it failed — and let several be selected together where the user thinks they share a cause. A report covering three failing jobs is legitimate; a report covering the one that happened to be listed first is a guess.

The recommendation, where one is defensible, is the most recent failure on the current branch. Say why: it is the one whose cause is most likely still present in the working tree. Where the candidates look unrelated to each other, say that no recommendation is defensible rather than picking the newest for the sake of picking.

## Displaying the log

The failing output is shown **before** any cause is proposed. That ordering is not cosmetic — a cause proposed first and evidence produced afterwards invites the evidence to be selected to fit.

A long log is shown as its failing region with the omission explicitly marked:

```text
… 412 lines omitted …
```

**Never silently truncate.** A reader who cannot see that something was cut cannot know to ask for it.

## When retrieval does not work

Four distinct cases, and the report names which one occurred rather than collapsing them into "could not fetch":

| Case                            | What to say                                                                         |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| No CLI on `PATH`                | the CLI is not installed, and the run continues from pasted output                  |
| CLI present, not authenticated  | the CLI is installed but not logged in, naming `gh auth login` or `glab auth login` |
| The call failed                 | the command and its actual error output                                             |
| Forge unsupported, or no remote | the host that was found, or that no remote is configured                            |

In every case: ask for the failing output, and **continue**. None of them stops the run. The distinction matters because the fix differs — installing a CLI, logging in, retrying, and doing nothing are four different actions, and "could not fetch" tells the user which of them to take: none.

## A log that arrives degenerate

Retrieved successfully but empty, truncated by the forge, or expired past its retention window → the same path as a failed retrieval. Report what arrived and ask for the output.

**An empty log is reported as empty.** It is not evidence that nothing failed, it is not evidence that the failure was transient, and it is never the basis for a root cause. A run that proposes a cause from an empty log has invented one.

## Never

- Never write one instruction covering both forges.
- Never re-detect the forge here. Step 0 decided it.
- Never pass a pipeline ID to `glab ci trace`.
- Never fetch the whole log when the failing-steps log is available.
- Never choose among candidates without asking.
- Never propose a cause before the evidence has been displayed.
- Never truncate without marking the omission.
- Never treat an empty or truncated log as a finding.
