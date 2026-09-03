# Delegating sweeps to subagents

Context is the binding constraint across eight phases. Several steps need to read a lot of the repo to answer one question, and the reading — not the answer — is what fills the window. A subagent reads in its own context and returns the finding, so the main run keeps artifacts, gate decisions and state instead of the files it took to reach them.

That is the whole of the benefit, and it bounds the whole of the practice: **delegate the search, never the decision.**

## Contents

- The threshold — when an agent pays for itself
- Choosing an agent type: probe and degrade
- Hard rules
- Fan-out 1 — Step 2 and conflict detection
- Fan-out 2 — Step 5e, two of the four sources
- Phase 8 is not a fan-out point
- Worktree mode
- When a delegated sweep comes back empty or not at all

## The threshold — when an agent pays for itself

An agent costs a dispatch, a prompt, and a report you then have to read. It pays for itself when the reading it replaces is larger than that, and not before.

Delegate when **all** of these hold:

- The question is a **sweep**, not a lookup — "does anything here already implement this?", "which modules would this touch?", "where is this concern enforced?" Answering it means opening files you cannot name in advance.
- The answer is **evidence**, not a judgment — file paths, line numbers, quoted text, a yes with proof or a no with what was searched.
- It is **independent** of the other sweeps in the same batch, so they can run at once.

Do it inline when any of these holds:

- You can name the file. `ctx_search` for a marker, `ctx_read` on `constitution.md`, a `grep` for one symbol — an agent for these is slower and costs more than the read.
- The repo is small enough that the sweep is a few files. A four-file repo does not need four agents.
- The question is really "what should we do about it?" That is a decision; see the hard rules.

One dispatched batch, not a habit. Two fan-out points in the whole run are named below, and they are the only two.

## Choosing an agent type: probe and degrade

Agent types come from what is installed in the session. Never hardcode a plugin's agent name — a skill that names `feature-dev:code-explorer` or any other plugin agent loses its fan-out on the next machine, and loses it **at dispatch time, mid-run**, not at Step 0 where it could have been reported.

Resolve once at Step 0, alongside the other tooling probes, and record it under `tooling.subagent`:

1. A **read-only explorer** agent, if the session lists one — an agent whose tools are reads and searches only. Best choice: it cannot write, so the "evidence only" rule below is enforced by the agent's own tool list rather than by its prompt.
2. Otherwise a **general-purpose** agent, with the read-only constraint stated in the prompt instead. State it explicitly: this sweep reads and reports, it edits nothing.
3. Otherwise **inline**. No agent available is not a reason to skip a sweep — the sweep is the work, the agent is only where it happens. Record `tooling.subagent: none` and read the files in the main context, which is exactly how the run behaved before this file existed.

Say which of the three applies once, at the prompt-review gate, so the user knows whether this run's reads were delegated.

## Hard rules

- **Evidence comes back, decisions stay here.** An agent reports what it found and where. The conflict protocol, every gate, every `AskUserQuestion`, and every write to state or to a file happen in the main run. An agent that returns "you should amend the spec" has answered a question that was not its to answer — take its evidence, discard its conclusion.
- **No writes, ever.** A delegated sweep does not edit files, does not run a phase command, does not touch git, does not write the state file. Two agents writing in parallel is a race in the user's repo, and a phase command run by an agent is a phase this run cannot account for.
- **No `AskUserQuestion` from an agent.** Questions belong to the run that holds the gates. An agent that needs a decision to continue should report the ambiguity as its finding.
- **Bounded reports.** Ask for a capped list — paths with line numbers and one line of quoted evidence each, a stated cap on how many. An agent that returns file dumps has moved the context problem rather than solved it.
- **Name what was searched, including when nothing was found.** "No existing rate limiting, searched `src/middleware`, `src/api`, and every `*.config.*`" is a usable finding. A bare "nothing found" is not, because it cannot be distinguished from a sweep that looked in the wrong place.
- **Never delegate to work around a stop.** A phase that failed, a conflict that needs resolving, an open finding — none of these become tractable by handing them to an agent. They stop the run because the decision is the user's.

## Fan-out 1 — Step 2 and conflict detection

The highest-value point, because Step 2 and the conflict check ask the same kind of question — _does this repo already contradict, or already implement, what the task describes?_ — and answering it well means reading widely before a single artifact exists.

Up to four independent sweeps, dispatched in **one** batch so they run at once:

| Sweep              | Question                                                                                  | Returns                                                                                      |
| ------------------ | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Prior art          | Does the repo already implement any part of this task?                                    | paths and line numbers of anything overlapping, or a stated no with the directories searched |
| Governance         | What does `.specify/memory/constitution.md` constrain that this task touches?             | principle names and their text, quoted                                                       |
| Existing artifacts | Do `specs/NNN-*/spec.md`, `plan.md` or `tasks.md` already settle any of this differently? | the conflicting statement, quoted with `file:line`                                           |
| Conventions        | What do `CLAUDE.md`, linter and formatter config, and CI require or forbid here?          | the rule and where it is stated                                                              |

Each returns evidence into the main run, which then applies `reference/conflicts.md` to it. Every conflict block, every `AskUserQuestion`, and every `conflicts[]` entry is written here — the sweeps supply the quotes those blocks are built from.

`graphify` and `ctx_*`, per `reference/tooling.md`, remain the right tools **inside** a sweep and are often enough on their own: `graphify query` answers "where is this enforced?" in one call, and when it does, that sweep needs no agent. Probe with the cheap tool first; delegate what it does not settle.

Re-checking conflicts at the start of each later phase is a **lookup**, not a sweep — by then you know which artifact to re-read. Do those inline. This fan-out happens once.

## Fan-out 2 — Step 5e, two of the four sources

`reference/findings.md` names four sources. Two can be delegated, and two cannot:

| Source                                                                                | Delegable?                                                                                                                                                                         |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Surviving `[NEEDS CLARIFICATION]` markers across `spec.md` and the planning artifacts | **Yes** — a read-only sweep returning every marker with `file:line` and its question text                                                                                          |
| Unchecked items in `tasks.md`                                                         | **Yes** — a read-only sweep returning each unchecked item verbatim with its line number                                                                                            |
| `after_implement` hooks in `.specify/extensions.yml`                                  | **No.** Hooks run commands and can write files. Dispatching them is an action, and it stays in the main run.                                                                       |
| Step 5b's own check output                                                            | **No.** It is already in the main context; re-reading it costs nothing and delegating it would mean handing an agent the output to interpret, which is classification, not search. |

Dispatch the two together, in one batch, while you work the hook dispatch yourself. Then classify severity and write `findings[]` **here** — severity is a judgment, and a delegated severity is a delegated decision.

An agent must never mark a finding fixed, deferred, or resolved. It reports what it found; 5f and 5g are the main run's.

## Phase 8 is not a fan-out point

`tasks.md` carries `[P]` markers naming tasks that could run in parallel. This is the most tempting fan-out in the run, and it is forbidden.

The `[P]` markers are instructions to the `implement` command, which owns executing `tasks.md`. Dispatching agents against them means **reimplementing `implement`** — the one thing every phase rule in this skill forbids. The consequences are not theoretical: the phase's own ordering and dependency handling are bypassed, `tasks.md` checkboxes are ticked by something other than the phase that owns them, several agents write to the repo at once, and `phases.8` records a command that never ran. A run that does this has no honest value to write there.

If `implement` parallelises internally, that is its business and it needs nothing from this skill. Pass Phase 8 an argument only for a scope limit, exactly as `reference/prompt-rules.md` says.

The same reasoning rules out delegating any of the eight phases. A phase is a command invocation, not a sweep.

## Worktree mode

Agents inherit the session's working directory, so in worktree mode a delegated sweep reads the worktree — which is correct, and is what makes the fan-out safe there: every sweep is read-only, so there is no writer to race with, in this tree or the main one.

Two things to state in a sweep's prompt when `workspace` is `worktree`:

- The tree it is reading is the worktree, and the user's own uncommitted work lives in a different directory that is **not** part of this feature. A sweep that wanders into the main checkout reports the user's unrelated edits as prior art.
- It must not read or write another worktree's `.specify/`. One run, one tree, one state file, per `reference/run-state.md`.

## When a delegated sweep comes back empty or not at all

A sweep that returns nothing usable is not a sweep that is done.

- **Empty with what was searched named** → a real result. Record it, say so at the gate.
- **Empty with nothing named** → unusable. Re-dispatch once with the directories to search stated explicitly, or do it inline.
- **Failed, timed out, or never dispatched** → do the sweep inline. Never record a source as searched because an agent was asked about it; `reference/findings.md`'s rule that an unswept source is worse than a loud failure applies here exactly.
- **Returned a conclusion instead of evidence** → keep the evidence, drop the conclusion, and make the decision here. If it returned a conclusion and no evidence, it has told you nothing you can act on: re-dispatch asking for paths and quotes.

Never let a delegated sweep become the reason a gate is skipped or a finding goes unrecorded. The agent changes where the reading happens and nothing else.
