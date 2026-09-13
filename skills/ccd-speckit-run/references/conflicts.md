# Conflict detection and resolution protocol

Two different things share the word "conflict", and this file covers both. **Artifact conflicts** are contradictions between the task and what is already committed — the protocol below. **Working-tree conflicts** are unmerged paths or an interrupted git operation — the boundary check at the end. They are detected differently, they are resolved differently, and confusing them is how one gets skipped.

## Artifact conflicts

Every phase, not just the constitution. After Step 2 identifies the task, and again at the start of each phase, check it against everything already committed. Stop on any contradiction.

## Where conflicts come from

| Source                                                                                | Example conflict                                                               |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `.specify/memory/constitution.md`                                                     | task needs a fourth project against a `≤3 projects` Simplicity Gate            |
| existing `specs/NNN-*/spec.md` on the current branch                                  | task restates a requirement the spec already settled differently               |
| existing `plan.md`                                                                    | task implies a different stack, datastore, or architecture than the plan chose |
| existing `tasks.md`, partly checked off                                               | task changes scope for work already implemented                                |
| repo conventions — `CLAUDE.md`, linter or formatter config, CI, existing architecture | task mandates a pattern the repo forbids                                       |
| the task text itself                                                                  | two stated requirements are mutually exclusive                                 |
| `analyze` output                                                                      | spec ↔ plan ↔ tasks drift, or a requirement with no covering task              |

## Gathering the evidence

The first check — after Step 2, against everything already committed — is a sweep across all the sources above at once, and `reference/subagents.md` allows fanning it out to read-only agents that return quoted evidence. The re-check at the start of each later phase is a lookup: by then you know which artifact to re-read, so do it inline.

Delegated or not, what comes back is evidence. Every conflict block below, every question, and every `conflicts[]` entry is written in the main run.

## On any conflict, do not choose

1. **Emit a conflict block** — per conflict: one-line statement of the contradiction; evidence quoted with `file:line`; the task requirement it contradicts; downstream impact of leaving it, naming which later artifacts inherit the error.
2. **Ask with `AskUserQuestion`** — one question per conflict, two to four options, recommended first and labeled `(Recommended)`. Each description states what it changes, its justification, its cost — choice made on tradeoffs, not labels. Typical set: amend the conflicting artifact / narrow or restate the task / proceed with an explicit justification, which for a constitution conflict goes in `plan.md`'s Complexity Tracking section.
3. **Explain the recommendation** in prose beside the question: why that option, what it costs. Default bias — change the cheapest artifact upstream of the most work: task wording over spec, spec over plan, plan over already-implemented code. Recommend amending the constitution only when the principle is genuinely wrong, not merely inconvenient here.
4. **Record the decision** in the state file's `conflicts[]` and in Step 7's summary, so the resolution stays auditable.
5. **Never advance a phase with an unresolved conflict.** Never widen the task to make a conflict disappear.

## Working-tree conflicts — the boundary check

**After every step and after every phase**, determine whether the working tree is conflicted. Not once, not only before Step 6: at every boundary, because a phase that builds on a broken tree is the failure this prevents and there is no cheaper moment to catch it.

```bash
sh "${CLAUDE_PLUGIN_ROOT}/skills/ccd-speckit-run/scripts/conflict-state.sh"
```

Two filesystem tests and one plumbing call. No network, no working-tree scan — which is what makes it affordable at fifteen boundaries.

Full output contract: `specs/006-claude-code-guidance/contracts/conflict-state-cli.md`. What the caller needs:

| Verdict      | Do                                                                                                                  |
| ------------ | ------------------------------------------------------------------------------------------------------------------- |
| `clean`      | record it, report **"checked, clean"**, continue                                                                    |
| `conflicted` | record it, dispatch `Skill(skill: "claude-code-devkit:ccd-conflict-resolve")`, then re-run the script               |
| `unknown`    | record it with the reason and continue — a run outside a git repository is supported, and Step 1 skips itself there |

**Read the `verdict` line, never the exit status.** `exit 0` means the check ran, not that the tree is clean. Conflating them turns every conflicted tree into a clean one, silently, which is the single worst way to misuse this script.

**A clean verdict is reported, not swallowed.** A check that says nothing when it passes is indistinguishable from a check that never ran, and the whole value of running it fifteen times is that the fifteen results are visible.

**After a dispatch, re-run the script.** Clean → record `resolved: true` and continue. Still conflicted → record `resolved: false`, report the unmerged paths, and **stop the run**. Do not dispatch again: the sub-skill iterates internally until nothing is left, so a second dispatch finding the same state is a loop rather than a retry, and the decision at that point is the user's.

**Resolving the conflict is never this skill's own work.** It dispatches and reads the result. Editing a conflicted file here bypasses the sub-skill's approval gate, which is the property that skill is built around.

Every verdict is appended to `conflict_checks[]` in the state file **as it happens**, per `reference/run-state.md` — one element per boundary, so a compacted run can still report them and the count can be compared against the count of boundaries.

### Why not `git status`

`conflict-state.sh` reads git's own state: `git ls-files -u` for the unmerged index, and the presence of `MERGE_HEAD`, `REBASE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `rebase-merge/` or `rebase-apply/` under the git dir.

The second condition is the reason it exists. **A rebase whose conflicts were resolved but never continued leaves a clean-looking working tree and a repository still mid-operation.** `git status --porcelain` reports `M  file` there — no unmerged marker at all — so a porcelain grep walks straight past it and the next phase commits into an interrupted rebase. Porcelain wording is also localizable and is not a stability contract.
