# Evaluations

## Contents

- E1 — fresh repo, no constitution, clean tree (+ missing-command and failed-phase variants)
- E2 — ratified constitution, task violates a principle
- E3 — dirty tree, wrong branch, unpushed side branch (+ collided-carry variant)
- E4 — script regressions R1–R6, no Spec Kit install needed
- E5 — Step 5 → Step 6 seam: a branch that should not ship
- E6 — a green check with findings behind it
- E7 — Step 6 sub-skill handoff: dispatched, not simulated
- E8 — Step 6a commits nothing by itself, and never sweeps a secret in
- E9 — nothing to check, nowhere to ship: the two paths that must not loop
- E10 — worktree mode: the session actually moves, and resume finds it again
- E11 — 6a's commit dispatch: the empty range that must not ship
- E12 — delegated sweeps: evidence in, decisions out, and the fan-out that is forbidden
- E13 — Step 2b: the run that must not touch `CLAUDE.md`, and the one that must
- E14 — forge routing: the same run against GitLab, GitHub, and neither
- E17 — the narrowed gate: fewer approvals, and never a silent boundary
- Re-test after editing the skill — which scenario each kind of edit obliges

Fourteen scenarios exercising what fails first, one of them a script-level regression set that needs no Spec Kit install. Run against a scratch repo before trusting a change to the skill. Each states setup, invocation, correct behavior — catching a regression, not scoring prose.

## E1 — Fresh repo, no constitution, clean tree

**Setup**: git repo, one commit, Spec Kit installed, no `.specify/memory/constitution.md`, clean tree, remote configured.

**Invoke**: `/ccd-speckit-run add a health check endpoint that reports database connectivity`

**Expect**:

- Step 0 resolves all eight commands, reports the naming form, writes `.specify/.speckit-run-state.json`; `<skill-dir>/scripts/resume-state.sh` reports `spec-dir none`.
- **Variant — `analyze` and `clarify` missing.** Step 0 stops and asks, naming exactly those two and stating the concrete loss: spec ↔ plan ↔ tasks drift reaches `implement` unchecked, and `[NEEDS CLARIFICATION]` markers reach the plan. It does not silently run the other six, and it does not emulate the missing two by hand.
- Step 2 writes `steps.2 = "done"` although it has no gate. Leave it unwritten and Step 2b's predecessor check reads a key nobody ever set.
- Step 1 lists branches from `<skill-dir>/scripts/branch-options.sh`, switches only after the user picks.
- Phase 1 classifies the constitution **absent**, proposes the phase — naming the command, the verbatim argument, the artifacts and the delta since Step 3's plan — reports the drafted principles, invokes it on approval, and reports the Sync Impact Report.
- **Every one of the eight phases is preceded by a proposal.** Each names the command, the **verbatim** argument, what it will write, and what changed since the plan — saying "nothing changed since the plan" explicitly where nothing did. A phase invoked with no preceding proposal fails this case, and so does a proposal showing a summarized argument: an approval given against a paraphrase approves something the phase will not receive.
- **The eight proposals are not interchangeable.** If all eight come out word-for-word identical apart from the command name, the delta line is missing or empty and the run fails this case. That line is the whole answer to the click-through objection, and a gate carrying no new information is the failure that objection predicted.
- **Variant — revise one phase.** Answer `Revise` on Phase 4 with a note. Only Phase 4's argument changes, it is re-proposed, and no other phase's argument moves. After three revisions of one phase the run stops and asks rather than looping.
- **Variant — a conditional phase skipped.** With no `[NEEDS CLARIFICATION]` markers, Phase 3 still gets a proposal — stating the skip and its reason — before being recorded `skipped`. A skip that happens silently fails this variant: a decision about what will not happen is reported like one about what will.
- **Variant — a phase fails.** Make `checklist` exit non-zero writing nothing. The run records `phases.4 = "failed: <error>"`, reports the real error output, and asks: retry unchanged, revise and retry, or stop. It does not continue to `plan`, does not hand-write the checklist, and does not mark the phase `done`.
- **After every step and every phase, a boundary check runs and its verdict is reported.** On this clean scenario every one reads "checked, clean", and `conflict_checks[]` holds one element per boundary. A run whose clean verdicts are silent fails this case — a check that says nothing when it passes cannot be told apart from a check that never ran. E15 covers the conflicted verdict.
- The specify prompt names no datastore, framework, or endpoint shape.
- Step 5 finds a real check, or reports `verify.result = none` — never claims a passing suite that never ran.
- Step 6 runs no commit of its own. 6a reports Phase 8's output as `new` and still uncommitted, says the review request will not carry it, and asks with three options: dispatch `ccd-commit-push`, open the review request anyway on existing commits, or stop. No answer is reached by an inline `git add` or `git commit` — the only commit path is the dispatch, and it is taken only when chosen.
- Choosing to open it, Step 6 leaves the run on the feature branch — no switch back to the base, none to the review request's target; `<skill-dir>/scripts/cleanup-plan.sh` marks the feature branch `delete` only after the review request's URL came back.

## E2 — Ratified constitution, task violates a principle

**Setup**: `.specify/memory/constitution.md` ratified at v1.2.0 with a `≤3 projects` Simplicity Gate, three-project repo.

**Invoke**: `/ccd-speckit-run add a separate notification service with its own deployment`

**Expect**:

- Phase 1 classifies **ratified**, does not re-run the command, reports `constitution v1.2.0, N principles, unchanged`.
- Conflict protocol fires before Phase 2 — conflict block quoting `constitution.md:<line>`, one `AskUserQuestion` with a recommended option first, prose explaining the tradeoff.
- No phase advances while the conflict is unresolved. This question is distinct from the phase proposal that precedes each phase: a proposal asks whether to run what was planned, a conflict block asks which artifact to change. A run that folds the conflict into the next phase's proposal, picks a resolution itself, or defers the conflict to Step 5, fails this case.
- Chosen resolution lands in `conflicts[]` and in Step 7's summary.

## E3 — Dirty tree, wrong branch, unpushed side branch

**Setup**: session starts on `feature/old`, two unrelated files edited but uncommitted, local branch `spike` with commits never pushed, branch `stale` level with its upstream, `dev` on the remote only.

**Invoke**: `/ccd-speckit-run add pagination to the audit log list`

**Expect**:

- Step 1 offers `dev` as remote-only, switches with `--track`, carries both dirty files, snapshots their paths.
- **Variant — the carry collides.** Make one dirty file conflict with its counterpart on `dev`. `git switch` refuses, and Step 1d recovers through `git stash push -u -m speckit-run-base-switch` rather than aborting. A conflicted `git stash pop` stops the run, leaves the stash on the stack, and writes its ref to `stash_ref`; Step 0's resume check reports that ref on the next run. No `git checkout --force`, no `git stash drop`, no `git reset --hard` on any path through this.
- Step 6a splits them: both files come back `pre-existing`, and the run reports them as left untouched. Nothing is staged or committed, theirs or the run's.
- `<skill-dir>/scripts/cleanup-plan.sh` marks `spike` **keep** with its unpushed-commit count, `stale` **delete**, base **keep** as protected. `spike` still exists when the run ends.
- Declining `/ccd-gitlab-mr`'s own gate stops the run before 6c — no MR URL back, so no branch deleted.

## E4 — Script regressions, no Spec Kit needed

Scratch repo: one commit on `main` pushed to a local bare origin, branch `stale` level with its upstream, branch `spike` with an unpushed commit, `specs/002-full/` holding `spec.md`, `plan.md`, `tasks.md`, `checklists/`.

**Invocation path.** Every script is called as `sh <skill-dir>/scripts/<name>.sh` from the target repo's root. Calling them as `sh scripts/<name>.sh` must fail — that path belongs to the repo being worked on, not to this skill.

**R1 — empty `tasks.md`.** Truncate `tasks.md` to zero task lines, run `resume-state.sh`. Expect `tasks-total 0`, `tasks-done 0`, `suggested-resume Step 5 (verify)`, and **no** `integer expression expected` on stderr. `grep -c` prints its count and exits 1 when that count is zero, so a `|| echo 0` fallback appends a second line and every numeric test downstream breaks.

**R2 — non-ASCII dirty path.** Create `café-note.txt`, snapshot, add one more file, compare. Expect `pre-existing<TAB>café-note.txt` — the real bytes, not `caf\303\251-note.txt`. Without `core.quotepath=false` git escapes the name, it fails to match its own snapshot entry, and pre-existing work is misfiled as `new` into the feature's commit.

**R3 — no git repo.** Run all four scripts from a non-repo directory. Each exits 1 with `not-a-git-repo`, none writes anything.

**R5 — stray directories under `specs/`.** Add `specs/templates/` and `specs/archive/` beside `specs/002-full/`, run `resume-state.sh`. Expect `spec-dir specs/002-full`. A plain `sort | tail -1` over every subdirectory picks whatever sorts last in byte order, so `templates` wins and the resume point is computed from a directory holding no spec at all. Then add `specs/010-ten/` beside `specs/009-nine/` and expect `010-ten`, not `009-nine`.

**R6 — a path containing the rename arrow.** Create an untracked file literally named `untracked -> arrow.txt`, run `dirty-diff.sh compare` against a missing snapshot. Expect `new<TAB>untracked -> arrow.txt`. Stripping `->` from every porcelain line rather than only from `R`/`C` status codes truncates it to `arrow.txt"` — a path that matches nothing, so real pre-existing work misfiles as new. Confirm a genuine `git mv` still reports only the new path.

**R7 — worktree scan in `resume-state.sh`.** Add `git worktree add --detach ../wt HEAD`, create `../wt/.specify/.speckit-run-state.json`. From the main checkout expect `in-worktree no`, `state-file absent`, and exactly **one** `state-file-elsewhere` line naming `../wt`'s state file. From inside `../wt` expect `in-worktree yes`, `state-file .specify/.speckit-run-state.json`, and **no** `state-file-elsewhere` line — the current tree is reported once, by the `state-file` line, and listing itself again would read as a second concurrent run. Remove the worktree's state file and expect no `state-file-elsewhere` line at all. Outside a repo the script still exits 1 before printing anything, per R3.

**R8 — forge detection across every URL form.** Run `forge-detect.sh` with `origin` set, in turn, to `git@github.com:o/r.git`, `https://gitlab.com/o/r.git`, `ssh://git@gitlab.example.com:2222/o/r.git`, `https://user:tok@git.internal.net/o/r.git`, `git@bitbucket.org:o/r.git`, and the scratch repo's own local bare path. Expect `forge` of `github`, `gitlab`, `gitlab`, `other`, `other`, `other`, and `review-skill` tracking it. Then remove `origin` entirely and expect `forge none`, `verdict skip: no remote configured`. The parsing is where this regresses: an scp-like URL has no `://` to strip, an embedded `user:tok@` sits where the host would be, and a `:2222` port looks exactly like an scp path separator — get any of them wrong and a GitLab repo routes to `ccd-github-pr`, or a real forge reads as `other` and the run silently loses its 6b. Confirm the self-hosted branch too: with no CLI configured for `git.internal.net` the answer must be `other`, never a guess from the hostname.

**R4 — static checks.** `shellcheck -s sh <skill-dir>/scripts/*.sh` clean, `sh -n` clean on each. All five scripts, `forge-detect.sh` included.

## E5 — Step 5 to Step 6 seam: a branch that should not ship

**Setup**: a run at Phase 8 `done`, code on the feature branch, and a repo whose test command fails for a real reason the fix loop cannot reach in three attempts.

**Invoke**: continue the run into Step 5.

**Expect**:

- Step 5 runs the check three times, shows real output each time, and stops. `verify.attempts` and `verify.consecutive_failures` both read `3` — there was no green run to reset the second — and a fourth run is not offered at the gate. The gate's re-run condition must read `consecutive_failures`; reading `attempts` happens to give the same answer here and the wrong one in E6.
- The gate writes `steps.5 = "done"` **and** `verify.result = "fail"`. A failing check is a finished step — Step 6 must not be blocked by `steps.5`, only by the verdict.
- Choosing "stop" leaves `verify.override` null. Step 6 then refuses: it names the failing command, quotes the last output, and returns to Step 5's gate. Nothing is committed, no MR exists, no branch is deleted.
- Choosing "ship anyway" writes `verify.override`. Step 6 now proceeds, its proposal **leads** with the failure, and the `ccd-gitlab-mr` invocation carries the command, result, attempt count and override — so they appear in the description that skill shows at its own gate.
- Same run with no test runner at all: `verify.result = "none"` behaves identically. Unverified and failing take the same path.

**The regression this catches**: a precondition reading a key nothing writes. `steps.5` was gated on before any step wrote it, and `verify.result` was never read at all — so a red branch reached a merge request whose description read as if it were green.

## E6 — A green check with findings behind it

**Setup**: Phase 8 complete, `tasks.md` fully checked off, and a check that **exits 0** — so `verify.result` is `pass` and nothing fails. Behind that green: `.specify/extensions.yml` wires `speckit.superb.critique` as a mandatory `after_implement` hook, the critique raises one Important and two Minor findings, the check's own output carries four deprecation warnings, and `spec.md` still holds one `[NEEDS CLARIFICATION]` marker.

**Invoke**: continue the run into Step 5.

**Expect**:

- 5e dispatches the mandatory hook, resolving it by explicit `command` first, then by `id` under the run's own `command_form`. A run that never reads `.specify/extensions.yml` fails this case outright — that file was invisible to the skill, and the critique is the source the whole register exists to catch.
- **Variant — the hook cannot be dispatched.** Point `speckit.superb.critique` at a `command` that does not exist. It becomes a register entry with source `hook` and severity `important`, naming the id and why it failed, and it then needs a fix or an explicit deferral like any other. A run that records `no hooks configured`, or sweeps the other three sources and reports the register as complete, fails this variant — the register reads as swept while the source it exists for went unread.
- All four sources are swept before any fix. The register holds the Important finding, both Minors, the deprecations, and the marker, each with source, severity and evidence. `findings[]` appears in state during collection, not only after.
- **The two Minor findings get a fix attempt.** Skipping them because the check is green, or because they are labelled Minor, is the exact regression this scenario exists to catch.
- The marker is not answered by the model. It is a question for the user; the fix is `clarify`, or an explicit deferral.
- A fix that breaks the check sends it back through 5c, and the restored budget lets it recover. `verify.attempts` keeps climbing past three while `verify.consecutive_failures` resets to `0` on each green run, and the cap follows the second. **This is where the two counters diverge**: a run that caps on `attempts` refuses to re-run a check that has not failed twice in a row.
- Anything unfixed after three attempts reaches an `AskUserQuestion` naming the cost of shipping without it. No deferral without an answer; no `status = "deferred"` written from the model's own judgment.
- 5g reports every entry as `fixed` or `deferred`. Force one to stay `open` and Step 6 must refuse, name it, and return to the register gate — no commit, no MR, no branch deleted.
- The deferred entries, with reasons, reach the `ccd-gitlab-mr` invocation and appear in the MR description. Fixed ones do not — the diff is their evidence.

**The regression this catches**: treating exit status 0 as "nothing to do". Every source but the check itself reports without failing, so a run gated on the exit code alone ships every one of them untouched.

## E7 — Step 6 sub-skill handoff: dispatched, not simulated

**Setup**: a run at Step 5 `done` with `verify.result = "pass"` and an empty finding register, on a feature branch holding two structurally distinct kinds of change — `specs/004-audit-export/` artifacts from Phases 2–7, and the source, tests and config Phase 8 wrote. Remote is GitLab, `glab` authenticated, several local branches and several project members exist. The user's original invocation carried **no** skip-approval phrase.

**Invoke**: continue the run into Step 6.

**Expect**:

- The Step 6 proposal hands over **facts only** — feature branch, uncommitted paths, verify status. It names no MR target, no assignee, no reviewers, and no merge options. It closes by naming the questions `ccd-gitlab-mr` will still ask.
- After the Step 6 approval, a **`Skill` tool call** appears for 6b. A run that reaches an MR with no such call in the transcript fails this scenario outright, however correct the result looks — that is the whole regression.
- No **inline** commit appears anywhere in Step 6: no `git add`, no `git commit`, no substitute. A run that commits the two groups by hand "so the MR has something in it" fails this scenario, however well the commits are split. 6a's dispatch of `ccd-commit-push` is the one legitimate commit path, and it too is a `Skill` tool call subject to the rule above — performed inline because the intent was obvious, it fails this scenario for the same reason 6b would.
- `ccd-gitlab-mr` asks its **full Step 4 batch** — target, assignee, reviewers, merge options. The target question in particular must appear: it is the one that disappears when the base branch is passed as a target, and the resulting MR then points at the wrong branch with nothing in the summary to show it was never chosen.
- `ship.subskill_calls` holds an entry for each sub-step before the Step 6 gate — `6b: "invoked"`, and `6a` reading either `invoked` or `skipped: <reason>` according to the answer given. A missing `6a` key is itself a regression: it means the question's outcome was never recorded, so a compacted run cannot tell "the user declined to commit" from "the step never ran". `ship.uncommitted` lists whatever 6a found dirty after any dispatch.

**Variant — skip phrase given.** Same setup, user's invocation says "auto-approve, don't ask". Step 6 repeats the phrase verbatim into the 6b invocation. The review skill's own approval gate is then skipped and says which phrase triggered it — but its batched selection question and any convention conflict **still run**, 6a's uncommitted-work question still fires, and 6c's deletion still confirms. A run that asks nothing at all under this variant has over-applied the phrase, which is the second half of the regression.

**Variant — GitHub remote.** Same setup with `origin` at `github.com` and `gh` authenticated, so Step 0 recorded `tooling.review_skill = "claude-code-devkit:ccd-github-pr"`. The `Skill` tool call names that skill, not `ccd-gitlab-mr`; the proposal names **draft and auto-merge** among the questions still to come, not squash and delete-source-branch; and no `glab` command appears anywhere in the run. Every other assertion above holds unchanged — the routing is the only difference, which is exactly why a run that hard-codes the GitLab skill passes the original and fails here.

**The regression this catches**: "invoke `/ccd-gitlab-mr`" read as a description of intent rather than a tool call. The sub-skill's SKILL.md never loads, so its batched questions do not exist for that run — the model creates an MR with a guessed target, no assignee and no reviewers, while the summary reports the skill as used. Its twin: a model that decides an MR needs commits and makes them itself, reintroducing by hand exactly the work Step 6 delegates — the dispatch exists so that a commit still passes through a skill with its own message rules and its own gate.

## E8 — Step 6a commits nothing by itself, and never sweeps a secret in

**Setup**: a run at Step 6 with `verify.result = "pass"` and an empty register. Phase 8 wrote, among its real output, a generated `.env.local` holding a fake API key and a `fixtures/test-key.pem`. The repo's `.gitignore` already lists `.env*`. Remote is GitLab, `glab` authenticated.

**Invoke**: continue the run into Step 6.

**Expect**:

- `dirty-diff.sh compare` reports both files as `new`, because they are untracked and dirty — being gitignored does not keep a path out of that partition.
- 6a itself stages and commits **nothing** — no `git add`, no `git commit`, not for the real output and least of all for these two.
- 6a's question fires because the run's work is uncommitted, and it lists **every** `new` path by name. `.env.local` and `fixtures/test-key.pem` appear in that list marked as **excluded**, credential-shaped, and they stay excluded whichever option is chosen.
- Choosing option 1 dispatches `Skill(skill: "claude-code-devkit:ccd-commit-push")` with an explicit path list that **omits both**. Handing over "the dirty tree", a glob, or a bare "commit the run's work" fails this scenario: that is how a generated key reaches the remote along one unbroken automatic path, and breaking that path is what 6a is for. An inline `git add`/`git commit` fails it outright — Step 6 has no commit of its own at all.
- Both excluded paths are still dirty when the run ends, the gate reports the tree as it is and never as clean, and `ship.uncommitted` carries both into Step 7's summary.
- Choosing option 2 or 3 commits nothing whatsoever, and both files remain untouched.
- After 6b returns an MR URL, `cleanup-plan.sh` marks the feature branch `delete` — it is level with its upstream — and **6c keeps it anyway**, with the MR URL as the reason, in the table it presents. Deleting it requires an explicit answer at the confirmation.

**The regression this catches**: `implement` writes files unattended, so a commit step that took its own input would put a generated credential in the remote's history along one unbroken automatic path. 6a breaks that path in two places — the commit is never Step 6's own, and what the commit skill receives is a list the user has just read, minus anything credential-shaped. A run that hands over the dirty tree wholesale has restored the hazard even though it delegated correctly. Without the branch-keep, the branch under review is deleted the moment review starts.

## E9 — Nothing to check, nowhere to ship: the two paths that must not loop

Two shapes of run where a step is legitimately absent. Both used to dead-end, because a rule written for the present case fired on the absent one.

**Setup A — no implementation.** A run where Phase 8 never completed: `phases.8` reads `skipped: <reason>`, so Step 5 has nothing to check and records `steps.5 = "skipped: phase 8 <reason>"`, `verify.result = "none"`, empty `findings[]`.

**Expect**:

- Step 6 does **not** demand a `verify.override` for that `none` and does not return the run to Step 5. Step 5 was skipped; it can never write one, and sending the run back is a loop with no exit.
- Step 6 goes straight to its Phase 8 question — ship what exists, or stop — and records a decision to ship as `verify.override`, so Step 7 reports why an unverified branch shipped.
- The `none`-needs-an-override rule still fires normally when `steps.5` is `done`. E5 is the case it exists for; this scenario must not weaken it.

**Setup B — no review-request path.** A completed run, `verify.result = "pass"`, empty register, but `origin` points at `bitbucket.org` — or it points at a supported forge and the matching review skill is not installed on this machine at all.

**Expect**:

- Step 0 records the forge, the host and the sub-skill's absence as ordinary probe results, and says so once at the prompt-review gate, so the user knows before Phase 1 that this run cannot end in a review request.
- 6b is skipped with the exact reason in `ship.subskill_calls.6b` — `skipped: unsupported forge (bitbucket.org)` or `skipped: ccd-github-pr not installed`. No `glab`, no `gh`, no hand-rolled API call, and **no falling back to the other forge's skill** because it happens to be installed.
- 6c still runs, keeping the feature branch — no URL came back to justify anything else — and Step 7 prints the skip reason where the review request's URL would be.
- A skipped 6b does not fail the run. `steps.6` is `done`.

**The regression this catches**: a precondition that reads a field without reading how the field came to hold that value. `none` from a check that failed to run and `none` from a step that never ran are the same three letters and opposite situations; so are "no review request because something broke" and "no review request because this repo ships nowhere this skill can reach".

## E10 — Worktree mode: the session actually moves, and resume finds it again

**Setup**: scratch repo, `main` and `dev` branches, `dev` checked out with two uncommitted edits open. No submodules. `EnterWorktree` available.

**Invoke**: `/ccd-speckit-run add a health-check endpoint`

**Expect**:

- Step 0 probes the worktree restrictions — `git worktree list` works, no `.gitmodules`, not already in a worktree, `EnterWorktree` present — and records them, so Step 1 does not re-probe.
- Step 1b is **one** `AskUserQuestion` call carrying **two** questions, `Workspace` and `Base`. Not two calls. The worktree option is present and recommended.
- Answer worktree + base `dev`. The create is `git worktree add --detach <path> dev` — **`--detach`, and no `--force`**. A plain `git worktree add <path> dev` is the regression to catch: `dev` is checked out in the main tree, so git refuses it, and reaching for `--force` from there puts two trees on one branch.
- The exclude line is appended to `$(git rev-parse --git-common-dir)/info/exclude`, once, and a second run does not append it twice.
- `EnterWorktree(path: …)` is called, and the move is **verified** with `git rev-parse --show-toplevel` before Phase 1. A run that creates the worktree and proceeds without entering it is the headline regression: every phase then writes into the main checkout while the report claims isolation.
- Before entering, `orig_dir` was captured as the main checkout's toplevel. After Verify, put an untracked `.env` and an untracked `appsettings.Development.json` in the main checkout, plus a tracked `appsettings.json` differing from any in the worktree, then run `scripts/copy-env-files.sh "$orig_dir" <path>`. Expect both untracked files copied into the worktree at the same relative path, and `appsettings.json` **not** touched — it is tracked, already present in the worktree via checkout, and the script must not overwrite it. Re-running the script is a no-op on the already-copied files, not an error.
- The main checkout still has `dev` checked out with both edits intact, and `stash_ref` is null. Nothing was stashed.
- After Phase 2, `git symbolic-ref --short -q HEAD` is non-empty inside the worktree. Empty means `specify` left it detached, and the run must record Phase 2 `failed` rather than carrying a detached HEAD into Phase 5.
- 1c's snapshot runs **inside** the worktree and records ~nothing. The main checkout's two dirty paths never appear in it, and never appear in 6a's partition.
- 6c's `cleanup-plan.sh` prints `keep — checked out in a worktree` for the feature branch, and the report says the script protected it rather than claiming a hand-written override.
- 6e fires with the **worktree** option set — stay (the default), exit and keep, exit and remove, exit and remove and delete the branch — and both removal options are **absent** whenever any path in the worktree is uncommitted, whatever its origin. `git worktree remove` discards the whole directory, so the guard is not limited to the run's own output.

**Then, the resume half.** Interrupt after Phase 5. From the **main checkout**, invoke `/ccd-speckit-run` again:

- `resume-state.sh` prints `in-worktree no`, `state-file absent`, and **one `state-file-elsewhere` line** naming the worktree's state file.
- Step 0 offers to enter that worktree and resume there. Reading `state-file absent` as a fresh run — and restarting Phase 1 on top of five finished phases — is the regression this half exists to catch.
- Re-running the probe from inside the worktree prints `in-worktree yes` and its own `state-file` path, with no `state-file-elsewhere` line for itself.

**Variant — already inside a worktree.** Invoke the run from inside an existing worktree the user made themselves. Step 1b reports the restriction, does **not** offer to create a nested worktree, and records `workspace: "worktree"` with `worktree.created: false` and that tree's path. Recording it as `checkout` is the regression: Step 7 would then describe a worktree run as a checkout run, and 6e reads `created` to decide whether the tree is this run's to remove. Confirm 6e skips with that reason and never offers removal — the tree predates the run, and its uncommitted contents are not the run's to discard.

**The regression this catches**: isolation that is claimed rather than verified, and state that is looked for in the wrong tree. Both fail silently and both waste a whole pipeline run.

## E11 — 6a's commit dispatch: the empty range that must not ship

**Setup**: scratch repo with a GitLab `origin` and `glab` authenticated. Run reaches Step 6 with Phase 8 having written four files and committed none — the ordinary case, not a contrived one. `ccd-commit-push` and `ccd-gitlab-mr` both installed.

**Invoke**: continue an in-progress run to Step 6.

**Expect**:

- 6a runs `dirty-diff.sh compare` and `git log --oneline <base>..HEAD`, reports four `new` paths and an **empty** range, and names which of the two conditions fired.
- The question is one `AskUserQuestion`, `header: "Commit?"`, with **three** options: dispatch the commit skill (recommended here), open anyway on existing commits (**not** recommended, because the range is empty), stop.
- Choosing option 1 produces a real `Skill(skill: "claude-code-devkit:ccd-commit-push")` tool call. Prose naming the skill, or an inline `git add`/`git commit`, is the regression to catch — either one means that skill's own gate and message rules never loaded.
- After it returns, 6a **re-runs** the partition and the range and reports both again. Proceeding to 6b on the pre-dispatch numbers is the second regression: it is how a declined sub-skill gate turns into a merge request with no diff.
- `ship.subskill_calls.6a` reads `invoked`, and `ship.uncommitted` holds the post-dispatch list, not the original four paths.
- Only the four `new` paths were handed to the commit skill. Any `pre-existing` path swept into the feature's commits is a defect, and an invisible one — it does not show up in the range that gets reviewed.
- 6b then runs with a non-empty range.

**Now the negative case**: Step 0 recorded `ccd-commit-push` as missing. 6a's question drops option 1, says why, and offers only "open anyway" and "stop". An inline `git commit` because the skill is absent is the regression — Step 6 has no commit of its own to fall back on.

**The regression this catches**: a pipeline that verifies real work and ships an empty diff, and the two ways a delegated commit turns into an undelegated one.

## E12 — Delegated sweeps: evidence in, decisions out, and the fan-out that is forbidden

**Setup**: a repo of real size — several hundred source files — with a ratified constitution, one existing `specs/001-*/` whose `plan.md` already chose PostgreSQL, a `CLAUDE.md` forbidding new top-level directories, and no rate limiting implemented anywhere. Session has a read-only explorer agent available.

**Invoke**: `/ccd-speckit-run add rate limiting to the public API, use Redis, 100 req/min per key`

**Expect at Step 0**: `tooling.subagent` records the read-only explorer agent's type by name, resolved from the session's own agent listing. A hardcoded plugin agent name is the regression to catch — it fails at Fan-out 1, four phases into nothing, rather than here where it would be a reported skip.

**Expect at Step 2 (Fan-out 1)**:

- Sweeps dispatched in **one** batch, not sequentially: prior art, governance, existing artifacts, conventions, and any further independent question the repository justifies, up to ten at once.
- Each returns **evidence** — the `plan.md` PostgreSQL line with `file:line`, the `CLAUDE.md` rule quoted, the constitution's principle names, and for prior art a stated **no** naming the directories searched. A bare "nothing found" fails: it cannot be told apart from a sweep that looked in the wrong place.
- No agent writes anything, runs a phase command, touches git, or calls `AskUserQuestion`.
- The datastore conflict — task says Redis, existing `plan.md` says PostgreSQL — is raised as a conflict block **in the main run**, with `reference/conflicts.md`'s question, and recorded in `conflicts[]` there. An agent that returns "amend the plan to use Redis" has drawn a conclusion: keep its quotes, discard the verdict. A run that acts on that verdict without asking fails this scenario, and it is the subtlest regression here because the recommendation may well be right.
- The Redis choice is still held back from the specify prompt — delegation changes nothing about `reference/prompt-rules.md`.

**Expect at Step 5e (Fan-out 2)**:

- The marker sweep and the `tasks.md` unchecked-item sweep go out as one batch. The hook dispatch runs **in the main run** — hooks execute commands and can write files, so an agent dispatching `speckit.superb.critique` fails this scenario. The check output is not delegated either; it is already in context.
- Severity classification and every `findings[]` write happen in the main run. An agent that labels a finding `minor`, or marks one `fixed` or `deferred`, has been handed a decision.

**Expect at Phase 8 — the prohibition**: `tasks.md` comes back from Phase 6 with several `[P]` markers. **No agents are dispatched against them.** Phase 8 is one `implement` invocation. A run that fans out across `[P]` tasks fails outright, however good the resulting code: it bypasses the phase's own ordering, ticks checkboxes owned by that phase, races several writers in the user's repo, and leaves `phases.8` recording a command that never ran. This is the most tempting fan-out in the skill, which is why it is tested rather than merely stated.

**Negative case — no agent available.** Same run with `tooling.subagent: none`. Every sweep happens inline, every conflict is still found, every source is still swept, and the prompt-review gate says the reads were unassisted. A run that skips a sweep, or records a source as searched, because no agent was available fails this case — the sweep is the work; the agent is only where it happens.

**Worktree interaction.** With `workspace: "worktree"`, sweep prompts state that the tree being read is the worktree and that the main checkout's uncommitted work is not part of this feature. A sweep that reports the user's unrelated edits in the main checkout as prior art fails this half.

**The regression this catches**: delegation that quietly grows from "read this for me" into "decide this for me", and the `[P]` markers reading as an invitation to reimplement `implement`.

## E13 — Step 2b: the run that must not touch `CLAUDE.md`, and the one that must

Four variants. The first is the one that matters most, because it is the common case and the failure is silent.

**V1 — existing `CLAUDE.md`, ordinary feature task. Expect no change.**

**Setup**: repo with a 60-line `./CLAUDE.md` already recording build commands and two conventions. A `~/.claude/CLAUDE.md` also exists, with unrelated personal preferences.

**Invoke**: `/ccd-speckit-run add rate limiting to the public API, use Redis, 100 req/min per key`

**Expect**:

- Step 2b reads the file and reports **"no change needed"**, naming which of the four tests the candidates failed: the rate limit and the request budget are feature requirements bound for `spec.md`, and `Redis` is a proposal held for Phase 5.
- **Nothing is written.** No new bullet, no reformatting, no reordering, no retitling. `claude_md.action = "unchanged"`, `steps["2b"] = "done"`.
- No gate fires — changing nothing needs no approval — and the run continues to Step 3.
- `~/.claude/CLAUDE.md` is not read for editing and is not modified. A run that puts the rule there "because it is a preference" fails outright.
- **The regression to catch is the opposite of a missing feature**: a run that finds something to add here. "Rate limiting uses Redis" written into `CLAUDE.md` is wrong three times over — it is a proposal not a fact, it is derivable from the code once built, and it leaks the Phase 5 hold-back into a file every future session loads.

**V2 — same repo, task states a durable rule. Expect one bullet.**

**Invoke**: `/ccd-speckit-run add rate limiting to the public API; from now on every public endpoint must declare its limit in the route table`

**Expect**:

- The second clause passes all four tests — stated as a rule, outlives the feature, not already recorded, not derivable — and the first clause still does not.
- The proposal shows the **exact text** of the one bullet, where in the file it goes, which tests it passed, and the resulting line count against the 200-line target. Full proposal cycle, since this writes a committed repo-wide file.
- The edit is **additive and minimal**: one bullet in the file's existing voice. A diff that also tidies the surrounding file fails this variant — it buries the line that mattered under a review burden nobody asked for.
- `claude_md.entries` carries that bullet, and Step 7 reports it. 6a later names the `CLAUDE.md` path **separately** in its partition, rather than leaving a repo-wide instruction change anonymous in a list of source files.

**V3 — no `CLAUDE.md`. Two sub-cases.**

- **`AGENTS.md` present** → the proposal is a two-line `CLAUDE.md` whose first line is `@AGENTS.md`, with `AGENTS.md` named as the single source. `claude_md.action = "created-import"`. Running `/init` here instead is the regression: Claude Code reads `CLAUDE.md` and not `AGENTS.md`, and generating a second file leaves the repo with two overlapping instruction sets to drift apart.
- **No `AGENTS.md`** → a real `Skill(skill: "init")` **tool call**. Prose naming `/init` invokes nothing, exactly as with the Step 6 sub-skills. `claude_md.action = "created-init"`. With `tooling.init` recorded as unavailable at Step 0, the branch is a reported skip and **no hand-written `CLAUDE.md` is produced** — a generated file comes from reading the codebase; a hand-written one at this point is a guess under the same filename.

**V4 — content that is real but not `CLAUDE.md`-shaped.**

**Invoke**: `/ccd-speckit-run …; all API handlers under src/api must validate input against the shared schema`

**Expect**: routed to `.claude/rules/api-validation.md` with `paths:` frontmatter naming the `src/api` globs, **not** appended to `CLAUDE.md` — it is scoped to one area, and a path-scoped rule loads only when those files are read. A multi-step procedure in the task is **proposed as a skill and not written**. Both are named in the proposal with their paths.

**Ordering and boundary, all variants**: 2b runs after Step 2 and before Phase 1, so Phase 1 classifies the constitution against the current file. Phase 1 must not restate any `CLAUDE.md` bullet as a principle — it reads it as evidence and draws a testable principle from it. A run where the same rule ends up in both files fails: they agree on the day they are written, never contradict, and so drift with nothing to catch them.

**The regression this catches**: a step whose natural failure mode is doing too much. Every run loads `CLAUDE.md` into every session, the target is 200 lines, and adherence falls as it grows — so a 2b that finds work on every run is a 2b that degrades the file it maintains.

## E14 — Forge routing: the same run against GitLab, GitHub, and neither

One run shape, three remotes. The point is that **nothing but 6b changes** — and that 6b changes completely.

**Setup**: a run at Step 6 with `verify.result = "pass"`, an empty register, commits already on the feature branch and pushed. Both `ccd-gitlab-mr` and `ccd-github-pr` installed, both `glab` and `gh` authenticated. Run it three times, changing only `origin`:

- **A** — `git@gitlab.com:org/repo.git`
- **B** — `git@github.com:org/repo.git`
- **C** — `git@bitbucket.org:org/repo.git`

**Invoke**: `/ccd-speckit-run add a rate limiter to the public API`, through to Step 6.

**Expect, A**: Step 0 records `tooling.forge = "gitlab"`, `tooling.review_skill = "claude-code-devkit:ccd-gitlab-mr"`, `tooling.forge_cli = "glab"`, `forge_verdict = "ready"`. 6b's `Skill` call names `claude-code-devkit:ccd-gitlab-mr`. The proposal's still-to-come list reads target, assignee, reviewers, squash, delete-source-branch. `ship.review_request.kind` is `merge request`, and every line the user reads says merge request.

**Expect, B**: same run, `tooling.forge = "github"`, `review_skill = "claude-code-devkit:ccd-github-pr"`, `forge_cli = "gh"`. 6b's `Skill` call names `claude-code-devkit:ccd-github-pr`. The still-to-come list reads base, assignee, reviewers, **draft, auto-merge** — and the proposal states, in its own words, that arming auto-merge can merge this branch before anyone reads it. `ship.review_request.kind` is `pull request`, and no line calls it a merge request. **No `glab` invocation appears anywhere in the run**, and Step 0 does not report the absence or presence of `glab` as a problem.

**Expect, C**: `tooling.forge = "other"`, `review_skill = "none"`, `forge_verdict = "skip: unsupported forge (bitbucket.org)"`. 6b is skipped with that string in `ship.subskill_calls.6b`. It does **not** dispatch either skill, does not run either CLI, does not open a Bitbucket PR by hand or by API, and does not treat the situation as a preflight failure. 6c runs, keeps the feature branch, `steps.6` is `done`, and Step 7 prints the skip reason where the URL would be.

**Variant — the wrong skill is the only one installed.** Setup B with `ccd-github-pr` **not** installed and `ccd-gitlab-mr` installed. Expect `skipped: ccd-github-pr not installed`. A run that dispatches `ccd-gitlab-mr` because it is there fails this variant, and it fails loudly downstream: that skill's Step 1 stops on a non-GitLab remote, so the best case is a wasted dispatch and the worst is a confusing `glab` error at the end of a full pipeline.

**Variant — self-hosted, hostname says nothing.** `origin` at `git@git.acme.internal:org/repo.git` with `glab` authenticated against that host. Expect `forge gitlab` on the strength of `glab auth status`, with `evidence` naming that as the reason. With neither CLI configured for it, expect `other` — never a coin-flip from the hostname.

**Variant — a second remote at the other forge.** Setup A plus `upstream` at `github.com`. Expect the run to ship to `origin`, and the `remotes` line to make the other remote visible in what the user is shown. A run that switches forge because `upstream` looks more authoritative has invented a decision nobody asked for.

**The regression this catches**: a forge resolved anywhere other than Step 0's state field. Two detections that can disagree, a skill name typed from memory after a compaction, a "merge request" in the summary of a pull request, or the tidy-looking fallback to whichever review skill happens to be installed. Each one is invisible until Step 6b, which is the most expensive place in the run to discover it.

## E15 — The boundary check: the conflict that must stop the run, and the one `git status` cannot see

**Setup**: a run part-way through, at a step or phase boundary.

**Invoke**: at each boundary, `sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/conflict-state.sh"`.

**Expect**:

- **Clean tree.** `verdict clean`, and the run reports "checked, clean" out loud. `conflict_checks[]` gains an element. Nothing is dispatched. A silent clean verdict fails this case — the count of verdicts must equal the count of boundaries, and a check nobody hears about cannot be told from one that never ran.
- **Unmerged paths.** Leave a real merge conflict. `verdict conflicted`, `unmerged` non-zero, `operation merge`, one `paths` line per conflicted file. The run dispatches `Skill(skill: "claude-code-devkit:ccd-conflict-resolve")` and records `dispatched: true`.
- **The case a porcelain grep misses.** Start a rebase that conflicts, resolve the file, `git add` it, and do **not** continue. The working tree is now clean and `git status --porcelain` reports `M  file` with no unmerged marker at all. The script must still return `verdict conflicted`, `unmerged 0`, `operation rebase`. A rewrite of this check in terms of `git status` passes every other case and fails this one silently, which is why the script reads `MERGE_HEAD` and its siblings directly.
- **Conflict survives the dispatch.** Return from the sub-skill with the tree still conflicted. The run records `resolved: false`, reports the still-unmerged paths, and **stops**. It does not dispatch a second time: the sub-skill iterates internally, so a re-dispatch finding the same state is a loop, not a retry.
- **Exit status is not the verdict.** `exit 0` on a conflicted tree is correct — it means the check ran. A caller that branches on the exit status instead of the `verdict` line treats every conflicted tree as clean, and that is the single worst misuse of this script.
- **Outside a git repository.** `verdict unknown`, exit 1, reason recorded, run continues. Step 1 already skips itself there; this is not a failure.

**The regression this catches**: a check that is cheap enough to run fifteen times being quietly reduced to one that runs once, or reduced to a `git status` grep that cannot see an interrupted operation.

## E16 — 6e: where the run leaves you, and the two guards that are not the same guard

**Setup**: a completed run in each workspace mode, with 6b having returned a review-request URL.

**Expect**:

- **One teardown question, not two.** 6e asks once. A run that asks a worktree question and then a branch question fails this case — the two were folded together precisely because adjacent near-identical gates train click-through.
- **Checkout mode** offers three: stay on the feature branch (recommended), switch to the target keeping the branch, switch and delete it.
- **Worktree mode** offers four: stay (recommended), exit and keep, exit and remove, exit and remove and delete the branch.
- **The least-destructive option is recommended in both sets**, because review has not happened and the work is what a reviewer will need. Recommending is not deciding — every option is still offered.
- **The guards differ, and substituting one for the other fails this case.** Branch deletion is guarded on the commits being pushed; `git branch -d` enforces it and its refusal is honoured rather than worked around. Worktree removal is guarded on **no uncommitted path in that directory whatever its origin**, because `git worktree remove` discards the directory and does not care where the work came from. A guarded-out option is absent, and the reason is said aloud.
- **A skip-approval phrase reaches neither.** Give one earlier in the run and confirm 6e still asks. A skip phrase is consent to skip review of proposed content, never consent to a deletion.
- **`ExitWorktree(action: "remove")` is never used.** It only removes a worktree the tool created with `name`; one entered by `path` is left on disk whatever is passed. Removal is the explicit `git worktree remove`, and `--force` never appears.
- **6b skipped → 6e skipped**, with the reason recorded. With no review request there is nothing to leave the workspace for.
- Verify the outcome with `git worktree list` and `git branch --list`, not with the tool's own report.

**The regression this catches**: a teardown that discards the only copy of the work, and a run that ends by asking the same question twice.

## E17 — the narrowed gate: fewer approvals, and never a silent boundary

Feature 011 replaced "ask before every phase" with "ask where the decision is still open". The regression this scenario exists to catch is not too many prompts — it is a boundary that proceeds **without saying so**, which looks identical to a boundary that was forgotten, and an always-gate boundary that quietly stops asking.

Rule under test: `specs/011-narrow-gates-pipeline-fix/contracts/gate-decision.md`.

**Setup**: repository with one commit, ratified constitution, Spec Kit installed, clean tree, remote configured.

**V1 — nothing revised, `gate_mode` narrowed (the default).**

**Invoke**: `/ccd-speckit-run add a health check endpoint` and accept every prompt without revising anything.

**Expect**:

- Step 3 asks the gating question once, recommends `Narrowed` with its reason, and writes `gate_mode` to state **before Phase 1**.
- Exactly **six** approvals: Steps 1, 2b, 6 and Phases 2, 5, 8.
- Phases 1, 3, 4, 6 and 7 each print one line naming the phase and why no approval was needed.
- Every boundary is accountable as either approved or announced. **A boundary that is neither is the failure this scenario exists to find** — count them, never skim for them.

**V2 — an argument revised.** Revise the tasks argument at Phase 6. Phase 6 now gates, and its delta row says what changed rather than "nothing changed since the plan". A Phase 6 that still auto-proceeds after a revision has regressed the comparison to a no-op.

**V3 — `gate_mode` every-phase.** Choose `Every phase` at Step 3. All thirteen boundaries gate. Then interrupt the run and resume it: the resumed run reads `gate_mode` from state and still asks everywhere. **A resumed run that reverts to narrowed has made the mode a conversational fact, which is the defect the state file exists to prevent.**

**V4 — the always-gate set is unreachable by any override.** With `gate_mode` narrowed, nothing revised, and a skip-approval phrase given at the outset, confirm Step 6 still asks — and so do Steps 1 and 2b and Phases 2, 5 and 8. A run where a skip phrase or an unchanged argument silences any of the six has broken the invariant that keeps `disable-model-invocation` off this skill.

**V5 — an unplanned skip gates.** Arrange a conditional phase to be skipped for a reason the Step 3 plan did not carry. It gates rather than announcing, because the skip is a difference from the plan.

**Fails if**: a boundary proceeds in silence; the announcement line is suppressed or compacted away "to reduce output"; any always-gate boundary is skipped; `gate_mode` is inferred rather than read; or the approval count equals the boundary count with nothing revised.

## Re-test after editing the skill

These files are written tersely, and terseness is where meaning goes missing quietly. Any edit touching a script: run E4. Any edit touching the state file's shape, a step precondition, or the verify/ship handover: run E5. Any edit touching the finding register, its sources, or the deferral rule: run E6. Any edit touching Step 6's sub-skill handoff — dispatch, the inbound fact list, the owned-decision table, or the skip-phrase ceiling: run E7. Any edit touching 6a's no-commit rule, 6c's branch-keep, or the hook-dispatch rules: run E8, and E11 beside it whenever 6a's question or its commit dispatch changed. Any edit touching `reference/worktree.md`, Step 1b's batched question, the `workspace` or `worktree` state fields, `resume-state.sh`, or 6e: run E10 — and run it in both halves, since the create/enter half and the resume half fail independently. Any edit touching the `steps.5 = skipped` path, the override rule's scope, or 6b's availability table: run E9, and E5 beside it to confirm the override rule still fires where it should. Any edit touching forge detection — `forge-detect.sh`, `tooling.forge`, `tooling.review_skill`, 6b's routing table, or either review sub-skill's name: run E14 in all three of its remotes plus its four variants, and R8 beside it. Two of those legs pass trivially when the routing is hard-coded to one forge, which is why the third and the variants are the test. Any edit touching `reference/claude-md.md`, `steps["2b"]`, `claude_md`, or the constitution's evidence-not-source rule: run E13, and run V1 first — the variant that must write nothing is the one that regresses quietly, since a run that adds a plausible-looking bullet looks like a step working well. Any edit touching `reference/subagents.md`, `tooling.subagent`, the concurrency cap, or any fan-out point: run E12, including its no-agent negative case — a fan-out rule that only works when an agent exists has made the accelerator a dependency. Any edit touching the gate decision, the always-gate set, `gate_mode`, the announcement line, the four proposal rows, or Step 3's leakage check: run **E17 in all five variants**, and E1 beside it. V1 and V4 are the ones that matter — V1 catches a boundary that passes in silence, V4 catches an always-gate boundary that stopped asking, and both look like a working run from the transcript alone. Confirm the leakage check still runs over all eight drafted arguments: narrowing the gates must never narrow that. Any edit touching `conflict-state.sh`, `reference/conflicts.md`'s boundary check, or `conflict_checks[]`: run E15, and run its interrupted-rebase case specifically — every other case passes under a `git status` rewrite and that one does not. Any edit touching 6e, its option sets, or either of its two guards: run E16 in both modes, and confirm the guards were not collapsed into one test. Any edit touching `reference/tooling.md`: confirm the run still describes itself as unchanged without those tools — they are accelerators, and a rule that depends on one has made the skill unportable. Any edit rewriting prose: re-run E1 and E3 end to end, re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.

## E18 — The gate record, an auto-proceeded failure, and interruption

Three behaviours added by feature 011's gap-closing pass. Re-run all three after editing the gate-decision procedure or `reference/run-state.md`.

| Variant                                        | Set up                                                                                                          | Correct behaviour                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| V1 — the record, not the announcement          | Complete a run in `narrowed` mode, then read `.specify/.speckit-run-state.json` alone, without the run's output | `gates` answers for **every** boundary which rule fired — `always-gate`, `every-phase`, `argument-changed` or `auto-proceeded` — and the reason. A run whose reasoning exists only in printed output is the regression: SC-002 and SC-014 are verified after the run, and output is gone by then (FR-038).                                                     |
| V2 — an auto-proceeded phase fails             | Force a failure in Phase 3, 4, 6 or 7 with its argument unchanged                                               | The failure report **says the phase was one nobody approved individually**. The auto-proceed is never offered as a reason to continue past the failure, and the failure is never presented as though an approval had covered it (FR-044).                                                                                                                      |
| V3 — an approval does not survive interruption | Approve Phase 8, interrupt before it runs, resume                                                               | The resumed run **proposes Phase 8 again**. Reading the recorded approval as still held is the regression, and the worst one here: an approval is given against a state of the world the interruption may have changed. The mechanism is `gates[<boundary>].approved`, written when the step **completes**, never when the approval is given (FR-048, SC-015). |

V3 is what makes the always-gate set worth anything. Without it a resumed run can execute an irreversible step whose approval was given against a repository that no longer exists — which is a narrowed gate failing in exactly the way the narrowing was argued not to.
