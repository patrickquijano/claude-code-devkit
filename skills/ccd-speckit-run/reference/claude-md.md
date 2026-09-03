# Step 2b — Project instructions: `CLAUDE.md`

Runs after Step 2, before Step 3 drafts the prompts and before Phase 1 classifies the constitution. Two branches: the repo has no project `CLAUDE.md` and one is created, or it has one and the question is whether this task states anything durable that it does not already record.

The position matters in one direction: `reference/constitution.md` reads `CLAUDE.md` as evidence when drafting principles, so running here means Phase 1 sees the current file rather than a stale one.

## Contents

- The default is no change
- Which file, and the ones never to touch
- Branch A — no project `CLAUDE.md`
- Branch B — one exists: the update test
- What belongs in `CLAUDE.md`, and the derivability test
- Routing: `.claude/rules/` and skills
- The boundary with the constitution
- Writing the change: the documented standard
- Gate
- State
- Never

## The default is no change

Say this first because it is the outcome most runs should reach. **A feature requirement is not a project rule.** The task describes work to do once; `CLAUDE.md` records how to work in this repository every time. Almost everything a task description contains belongs in `spec.md`, `plan.md` or `tasks.md`, and putting it here instead is both a leak and a loss — the spec no longer holds the requirement, and every future session pays context for it.

The cost of getting this wrong compounds. `CLAUDE.md` loads into every session in this repo, the documented target is **under 200 lines**, and longer files measurably reduce how reliably any of it is followed. A step that finds something to add on every run makes the file worse every run, and the entries that suffer are the ones that were already there and already right.

So: reaching this step and reporting "no change needed", with the reason, is a complete and correct outcome. It is not a step that failed to find work.

## Which file, and the ones never to touch

A project `CLAUDE.md` lives at `./CLAUDE.md` **or** `./.claude/CLAUDE.md`, relative to the repository root. Check both; if both exist, report that — it is worth the user knowing, and the one to edit is the one that already carries project rules.

```bash
ls CLAUDE.md .claude/CLAUDE.md 2> /dev/null
ls AGENTS.md .cursorrules .cursor/rules .github/copilot-instructions.md 2> /dev/null
```

**Never touch any of these**, whatever the task says:

| Path                                                                                                      | Why not                                                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `~/.claude/CLAUDE.md`                                                                                     | The user's own instructions for **every project on their machine**. A repo pipeline editing it changes how their unrelated work behaves. It is not in scope for any run. |
| `/Library/Application Support/ClaudeCode/CLAUDE.md`, `/etc/claude-code/CLAUDE.md`, the Windows equivalent | Managed policy, deployed by whoever administers the machine. Cannot be excluded by settings, and is not the repo's to edit.                                              |
| `CLAUDE.local.md`                                                                                         | Personal, gitignored, per-worktree. Someone's sandbox URLs and test data. A shared pipeline has no business writing one person's private file.                           |
| Any `CLAUDE.md` above the repository root                                                                 | Another project's, or the user's. Stay inside the repo.                                                                                                                  |

Not a git repo → this step still runs. `CLAUDE.md` needs no git, so unlike Step 1 there is nothing to skip; use the working directory as the root.

## Branch A — no project `CLAUDE.md`

Check for an existing instruction file from another agent **before** generating anything.

**`AGENTS.md` present** → do not generate a second file that says overlapping things. Claude Code reads `CLAUDE.md`, not `AGENTS.md`, and the documented answer is a `CLAUDE.md` that imports it, so both tools read one source:

```text
@AGENTS.md
```

That is the whole file, unless there is genuinely Claude-specific guidance to add beneath it — and on this step there usually is not. Propose it as a two-line file, say that `AGENTS.md` stays the single source, and stop there.

**No `AGENTS.md`** → dispatch `/init` through the `Skill` tool:

```text
Skill(skill: "init")
```

It analyses the codebase and writes a starting `CLAUDE.md` with the build commands, test instructions and conventions it discovers. It also reads Cursor rules (`.cursor/rules/`, `.cursorrules`) and Copilot instructions (`.github/copilot-instructions.md`) and folds the relevant parts in, so those need no handling here.

`/init` is a built-in reached through the `Skill` tool, the same as any sub-skill — **prose naming it invokes nothing.** Step 0 probes whether it is available and records it; unavailable → say so and continue without it, and never hand-write a substitute. A generated `CLAUDE.md` comes from reading the codebase; a hand-written one at this point would be a guess wearing the same filename.

`/init` writes a file into the repo, so it goes behind this step's gate like any other write here.

## Branch B — one exists: the update test

`/init` is not the tool for this branch. Run against an existing `CLAUDE.md` it suggests improvements rather than overwriting, which sounds harmless and is the wrong shape of question: it asks "what could this file say about this codebase?" where the question here is narrower — **does this task state a durable rule the file does not already record?**

Read the file, then apply all four tests. An entry is warranted only when **every** one passes:

1. **Stated, not inferred.** The task says it as a rule — "from now on", "always", "never", "all X must". A requirement about what the feature does is not a rule about how the repo is worked in. Inferring a convention from a feature description is how this step turns into the accretion problem above.
2. **Durable.** It outlives this feature. "Every public endpoint declares its limit in the route table" survives; "this endpoint allows 100 requests a minute" belongs in `spec.md`.
3. **Not already recorded.** Not in `CLAUDE.md`, not in `.claude/rules/`, not in the constitution. A duplicate is worse than an omission: the documented failure mode is that two instructions covering the same behaviour get resolved arbitrarily.
4. **Not derivable from the codebase.** This is the sharpest test and the one that rejects the most. Directory layouts, dependency lists, architecture overviews — anything a reader could establish by opening the repo — do not belong. What belongs is the opposite: pitfalls, the rationale behind a choice, and conventions that **differ from the tool defaults** someone would otherwise assume.

Worked, from the task the rest of this skill uses as its example:

- _"add rate limiting to the public API, use Redis, 100 req/min per key"_ → **no change.** Every part of it is a feature requirement. `Redis` is held for Phase 5 by `reference/prompt-rules.md`; the rate belongs in `spec.md`.
- _"…and from now on every public endpoint must declare its limit in the route table"_ → **one bullet.** Stated as a rule, outlives the feature, not derivable, not recorded.

While reading, note any entry that **contradicts** another, or that the repo has since outgrown. That is a genuine finding and worth reporting even on a run that adds nothing — a stale instruction is followed as readily as a current one. Removing it is a change like any other and goes through the same gate; never delete an instruction silently on the way past.

## What belongs in `CLAUDE.md`, and the derivability test

Belongs — facts wanted in every session:

- Build, test and lint commands, as commands.
- Conventions that differ from what the tooling would default to.
- Pitfalls: the thing that looks right and breaks.
- "Always do X" / "never do X" rules that hold repo-wide.
- Rationale, where a choice would otherwise look arbitrary and get "fixed".

Does not belong:

- Anything derivable by reading the code — layout, dependencies, architecture tours.
- A multi-step procedure. That is a skill.
- Anything true of only one area of the codebase. That is a path-scoped rule.
- Feature requirements, acceptance criteria, task lists. Those are the artifacts this pipeline exists to produce.
- Personal preference. That is the user's own file, which this step does not touch.

## Routing: `.claude/rules/` and skills

Content that passes the four tests but is not `CLAUDE.md`-shaped gets placed rather than stuffed:

| Shape                                                          | Goes to                                                                                                                                          |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Repo-wide, always relevant                                     | `CLAUDE.md`                                                                                                                                      |
| Scoped to one area — "all API handlers must validate input"    | `.claude/rules/<topic>.md` with `paths:` frontmatter listing the globs, so it loads only when those files are read                               |
| A multi-step procedure — a release sequence, a migration dance | a skill. **Propose it; do not write it here.** Authoring a skill is its own task with its own review, and it is not what this run was asked for. |

A path-scoped rule is the answer to almost every "this is important but only for `src/api`" case, and using it is what keeps `CLAUDE.md` under its target by construction rather than by later trimming. Name the file and the globs in the proposal.

## The boundary with the constitution

Both are durable and repo-wide, which is exactly why the line has to be drawn explicitly rather than left to judgment on the day.

|           | `CLAUDE.md`                                           | `.specify/memory/constitution.md`             |
| --------- | ----------------------------------------------------- | --------------------------------------------- |
| Kind      | **Operational** — how to work in this repository      | **Normative** — governance                    |
| Content   | commands, conventions, pitfalls, defaults that differ | testable `MUST` / `MUST NOT` principles       |
| Read by   | every Claude Code session in this repo                | the `plan` phase's gates, at runtime          |
| Versioned | no                                                    | semver, with ratification and amendment dates |

Two rules, and they point in opposite directions on purpose:

- **2b never writes constitution-shaped content.** A testable `MUST` principle that a plan gate should check is Phase 1's, and `reference/constitution.md` owns how it gets there. Writing it here puts governance in a file no gate reads.
- **Phase 1 never restates `CLAUDE.md`.** It reads the file as _evidence_ — that is already in its instructions — and evidence is what a principle is drawn from, not something to copy across. Two files carrying the same rule agree on the day they are written and drift silently afterwards, which no conflict check will catch, because at no point do they contradict.

And the rule that keeps Phase 5's hold-back intact: **2b records only what is already true of the repository, never what the task proposes.** The task naming a datastore is a proposal; it belongs in the Phase 5 prompt. The repo already using that datastore is a fact, and even then only worth recording if it is not derivable — which, from a lockfile and a config file, it usually is.

A genuine contradiction between the task's stated rule and the constitution is not this step's to settle: it is a conflict, and it goes through `reference/conflicts.md` like any other.

## Writing the change: the documented standard

For any file this step writes or edits:

- **Under 200 lines.** Over that, adherence drops. If an addition pushes it over, that is the signal to move something to `.claude/rules/`, not to accept a longer file.
- **Markdown headers and bullets**, grouped by topic. Not dense paragraphs.
- **Concrete enough to verify.** "Use 2-space indentation", not "format code properly". "Run `npm test` before committing", not "test your changes". An instruction that cannot be checked cannot be followed consistently either.
- **One entry per rule**, in the file's existing voice and structure. Match what is there; a section in a different style reads as bolted on and gets ignored as such.
- **Additive and minimal.** Add the bullet. Do not reformat, reorder, retitle, or "improve" the surrounding file — an unrelated diff in a repo-wide instruction file is a review burden nobody asked for, and it buries the one line that mattered.

## Gate

This step writes a committed, repo-wide file that governs every future session, so it takes the **full proposal cycle** — propose, approve, execute — the same as Step 1 and Step 6. Step 2 has no gate; 2b does, and this is why.

Propose, before writing anything:

- Which branch applies, and which file path — including that it is the project file and not the user's.
- Branch A: `/init`, or the `@AGENTS.md` import with the file's exact two lines.
- Branch B: **the verdict first.** "No change needed", with which of the four tests the candidate failed, is the common case and is stated plainly. Otherwise, the exact text of each addition, where it goes in the file, and which test each entry passes.
- Any file routed to `.claude/rules/` instead, with its `paths:` globs; any skill proposed rather than written.
- Any contradiction or stale instruction found while reading, whether or not this run acts on it.
- The resulting line count against the 200-line target.

Approve with `AskUserQuestion`: `Proceed` / `Revise` / `Skip this step`. "Skip" is a legitimate answer and records `steps["2b"] = "skipped: <reason>"` — the run continues to Step 3 unaffected. Nothing here is load-bearing for the phases.

A no-change verdict still reports; it does not need approval to change nothing. Write `steps["2b"] = "done"` with `claude_md.action = "unchanged"` and continue.

## State

Record under `claude_md`: the `path` acted on or checked, the `action` — `created-init`, `created-import`, `updated`, `unchanged`, or `skipped: <reason>` — and, for `updated`, the entries added in one line each. `rules_files` lists anything written under `.claude/rules/`.

This step's own precondition is `steps.2` being `done`, and Step 3's predecessor check reads `steps["2b"]` rather than `steps.2` — 2b sits between them, so a run that leaves this key unwritten stalls Step 3 exactly as an unwritten `steps.2` would have stalled this one.

The file this step touches is uncommitted when it is written, so 6a's partition reports it as `new` alongside the run's code, and a 6a commit dispatch carries it into the feature's merge request. That is correct — the rule changed because of this feature — but say so at 6a rather than letting a governance change ride along unremarked.

## Never

- Never touch `~/.claude/CLAUDE.md`, a managed policy `CLAUDE.md`, a `CLAUDE.local.md`, or any `CLAUDE.md` outside the repository root.
- Never write a feature requirement, acceptance criterion, or task into `CLAUDE.md`. Those have artifacts, and this pipeline exists to write them.
- Never record what the task _proposes_ as though it were true of the repo. Phase 5 is where proposals go.
- Never add an entry that duplicates the constitution, an existing bullet, or a `.claude/rules/` file.
- Never reformat or restructure the file while adding to it.
- Never delete or rewrite an existing instruction without proposing it — including one that looks stale. Someone wrote it for a reason that may not be visible.
- Never run `/init` against an existing `CLAUDE.md` to "refresh" it. Branch B is a targeted read and a targeted edit.
- Never write a skill here. Propose it.
- Never let this step block the run. Every outcome — created, updated, unchanged, skipped, `/init` unavailable — continues to Step 3.
