# Run state

`SKILL.md` is never re-read from disk, and compaction re-attaches an invoked skill only up to a token budget — so by Phase 6 the later half of it may be gone, and the facts it depended on survive only in scrollback that has itself been compacted. Everything needed later lives in one file instead.

Path: `.specify/.speckit-run-state.json`. Companion: `.specify/.speckit-dirty-snapshot`, written by `scripts/dirty-diff.sh`.

Both are internal bookkeeping. Never commit them. `scripts/dirty-diff.sh` reports them as `internal` so they are never counted as the run's output.

## Shape

```json
{
  "version": 2,
  "task": "one-line restatement of the task description",
  "command_form": "slash | skills",
  "skill_dir": "${CLAUDE_PLUGIN_ROOT}/skills/speckit-run",
  "tooling": {
    "lean_ctx": true,
    "graphify": false,
    "forge": "gitlab | github | other | none",
    "forge_host": "gitlab.com",
    "forge_cli": "glab | gh | none",
    "forge_cli_status": "ready | unauthenticated | absent | n-a",
    "forge_verdict": "ready | skip: <reason>",
    "review_skill": "claude-code-devkit:auto-gitlab-mr | claude-code-devkit:auto-github-pr | none",
    "commit_skill": true,
    "init": true,
    "subagent": "<agent type name> | none"
  },
  "previous_branch": "main",
  "stash_ref": null,
  "workspace": "checkout | worktree",
  "worktree": {
    "path": "/abs/path/.claude/worktrees/user-auth",
    "original_dir": "/abs/path",
    "created": true,
    "teardown": "stayed | exited-kept | exited-removed"
  },
  "base_branch": "dev",
  "feature_branch": "003-user-auth",
  "spec_dir": "specs/003-user-auth",
  "steps": {
    "0": "done",
    "1": "done",
    "2": "done",
    "2b": "done",
    "3": "done",
    "5": "pending",
    "6": "pending",
    "7": "pending"
  },
  "claude_md": {
    "path": "CLAUDE.md",
    "action": "created-init | created-import | updated | unchanged | skipped: <reason>",
    "entries": [],
    "rules_files": []
  },
  "phases": {
    "1": "skipped: ratified v1.2.0",
    "2": "done",
    "3": "skipped: no markers",
    "4": "done",
    "5": "done",
    "6": "done",
    "7": "done",
    "8": "pending"
  },
  "verify": {
    "command": "npm test",
    "result": "pass | fail | none",
    "attempts": 1,
    "consecutive_failures": 0,
    "override": null
  },
  "ship": {
    "review_request": {
      "forge": "gitlab | github",
      "kind": "merge request | pull request",
      "url": null
    },
    "uncommitted": [],
    "subskill_calls": { "6a": "invoked | skipped: <reason>", "6b": "invoked | skipped: <reason>" },
    "branches_deleted": [],
    "branches_kept": []
  },
  "findings": [
    {
      "id": "F1",
      "source": "hook | check | markers | tasks",
      "severity": "blocking | important | minor",
      "statement": "",
      "evidence": "",
      "status": "open | fixed | deferred",
      "resolution": ""
    }
  ],
  "conflicts": [{ "at": "Phase 5", "conflict": "", "resolution": "" }]
}
```

## Who writes what

| Field                                                                  | Written at                                                                                                |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `task`, `command_form`, `skill_dir`, `tooling`                         | Step 0                                                                                                    |
| `previous_branch`, `base_branch`, `stash_ref`, `workspace`, `worktree` | Step 1 — `workspace` the moment 1b's answer returns, `worktree` once 1d created and entered it            |
| `worktree.teardown`                                                    | Step 6d                                                                                                   |
| `claude_md`, `steps["2b"]`                                             | Step 2b                                                                                                   |
| `feature_branch`, `spec_dir`                                           | Phase 2, once `specify` created them                                                                      |
| `steps.N`                                                              | that step's gate, or its completion where it has none — `done`, `skipped: <reason>`, or `failed: <error>` |
| `phases.N`                                                             | that phase, on completion — `done`, `skipped: <reason>`, or `failed: <error>`                             |
| `verify`, `findings[]`, `steps.5`                                      | Step 5                                                                                                    |
| `ship`, `steps.6`                                                      | Step 6                                                                                                    |
| `conflicts[]`                                                          | wherever the conflict protocol resolves one                                                               |

## Rules

- Every step writes its own `steps.N`, the way every phase writes `phases.N`. A precondition can only read what some step actually wrote; a key nobody writes makes the check decorative. Phases are not gated — `phases.N` is written when the phase finishes and its artifacts have been seen on disk.
- `findings[]` is written as each finding is collected in 5e, not once at the end of 5f. Collection can be interrupted; a register that only exists after the fixes cannot survive that.
- A finding leaves the register `fixed` or `deferred`, never by deletion. Removing an entry to shorten the register destroys the only record that the issue was reported at all.
- `steps.N` records whether the step **ran**, never whether its outcome was good. Step 5 is `done` on a failing check too — the verdict lives in `verify`.
- Step 2 has no gate, so it writes `steps.2 = "done"` the moment it finishes reading the task. Every other `steps.N` is written at a gate, or — for a 2b that changed nothing — at its verdict; this one is not, and skipping it would leave Step 2b's predecessor check reading a key nobody ever writes.
- No `steps.4`. Step 4 _is_ Phases 1–8, tracked in `phases`; a step checking its predecessor treats `steps.3` as what precedes Step 5.
- `steps["2b"]` sits between `steps.2` and `steps.3`, so **Step 3's predecessor is `steps["2b"]`**, not `steps.2`. It is written on every run — `done` for a change and for a no-change verdict alike, or `skipped: <reason>`. A no-change verdict is `done` with `claude_md.action = "unchanged"`: the step ran and reached a result, which is not the same as never having run.
- `claude_md.action` distinguishes the five outcomes, and Step 7 reports it verbatim. `unchanged` is the expected value on most runs and means the four tests in `reference/claude-md.md` were applied and none passed — never that the step was quietly bypassed. `claude_md.entries` holds each added instruction in one line, so a compacted run can still report what it wrote into a file that governs every future session.
- `verify.attempts` is the **total** number of times the check ran in Step 5, across 5c's fix loop and 5f's per-finding re-runs. `verify.consecutive_failures` is the separate counter the three-attempt cap actually governs: it increments on each failing run and resets to `0` on a green one. The gate offers a re-run only while `consecutive_failures` is under three. Deriving the cap from `attempts` is wrong once 5f has re-run the check even once.
- `phases.8` records a scope limit in the value: `done: scope-limited to <what>`. Plain `done` means `implement` executed the whole of `tasks.md`. Step 6 reads that prefix to decide whether the partial-ship question fires, so a scope limit recorded only in the conversation is a scope limit Step 6 cannot see.
- `tooling.subagent` holds the agent type Step 0 resolved for delegated sweeps, or `none`. Read it rather than re-deriving the session's agent list at dispatch time: an agent named from recollection after a compaction is an agent that may not exist. `none` means every sweep runs inline, which changes no rule and no artifact.
- `workspace` decides which 1d ran, which teardown exists, and where this file itself lives. In `worktree` mode the state file is inside the worktree, because every path in the run is relative to it — which is why `resume-state.sh` scans sibling worktrees rather than trusting the current directory. Write it the moment 1b's answer returns, before 1c: a mode held only in the conversation is a mode a compacted run cannot read.
- `worktree` is null in checkout mode. In worktree mode `worktree.original_dir` is the directory the session started in, kept because 6d's exit needs somewhere to return to and `previous_branch` does not answer that. `worktree.created` distinguishes a worktree this run made from one the session was already inside — 6d never offers to remove the latter.
- `worktree.teardown` is written by 6d and is one of `stayed`, `exited-kept`, `exited-removed`. Absent after a worktree run means 6d never ran, which Step 7 reports rather than glossing.
- `stash_ref` holds a stash this run created and could not restore — checkout-mode 1d's conflicted `git stash pop`. Null the rest of the time, and **always** null in worktree mode, which stashes nothing. A non-null `stash_ref` on a worktree run is a bug, not a stash. A stash left on the stack with nothing in state pointing at it is uncommitted work that the next run, and the summary, both fail to mention.
- Step 0 creates the file. Missing at a later step → the run never started, or the file was deleted; say so and restart from Step 0 rather than guessing.
- Before acting, every step reads it and checks its predecessor is `done` or `skipped`. Predecessor `pending` or `failed` → do not run. Name the unfinished step, stop.
- Update as each step or phase finishes, before asking anything it needs to ask — an interrupted run then leaves accurate state behind.
- A value here always beats a recollection from earlier in the conversation. Base branch, command form, skill directory: read them, never remember them.
- Never write a phase `done` on the assumption it worked. `done` means its artifacts were seen on disk.
- `ship.subskill_calls` records whether Step 6 actually dispatched each sub-skill through the `Skill` tool. `6a` is `auto-commit-push`, and is `skipped: <reason>` on every run where the user did not choose to commit — that is the ordinary value, not a failure. `6b` is whichever skill `tooling.review_skill` named, `skipped: <reason>` covering an unsupported forge, a missing CLI, or that skill not being installed. In both cases `invoked` is written only after the tool call returned. A run that opened a review request, or produced commits, with no entry here did the work inline, which means the sub-skill's rules were never loaded — treat it as unfinished, not as done.
- `tooling.forge` decides which sub-skill 6b may dispatch, and `tooling.review_skill` names it. Read them; never re-run the detection at Step 6 and never infer a forge from the task description or from a remembered remote. `other` and `none` are ordinary values meaning this run has no review-request step, not that detection failed — `tooling.forge_verdict` carries the reason verbatim, which is what `ship.subskill_calls.6b` records when 6b is skipped.
- `ship.review_request` holds the outcome of 6b: the forge it went to, whether that forge calls the result a merge request or a pull request, and the URL. `url` stays null when 6b was skipped — the reason lives in `subskill_calls.6b`, not here. Step 7 reports `kind` verbatim so a summary never calls a pull request a merge request.
- **A `version: 1` state file predates forge detection.** Read `ship.mr` as `ship.review_request.url`, `tooling.glab`/`tooling.gitlab_remote` as evidence that the forge was GitLab, then re-run `<skill-dir>/scripts/forge-detect.sh` once and write the `version: 2` fields before Step 6 acts on them. Never carry a `version: 1` file into 6b unmigrated: `tooling.review_skill` is absent there, and an absent skill name is exactly what a guess fills in.
- `ship.uncommitted` holds every path 6a found still dirty **after** any 6a dispatch, the run's own output and pre-existing work alike. Step 6 runs no commit of its own, so this list is the run's output record: empty here after a run that wrote code and never dispatched 6a means the check never ran, not that the tree was clean.
