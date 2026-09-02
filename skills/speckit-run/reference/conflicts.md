# Conflict detection and resolution protocol

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
