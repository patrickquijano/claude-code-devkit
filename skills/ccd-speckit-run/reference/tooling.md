# Tooling policy

This skill reads the repo constantly — classifying the constitution, hunting `[NEEDS CLARIFICATION]` markers, checking `tasks.md` progress, gathering conflict evidence. Route that reading through the better tools when Step 0 found them. Governs this skill's own reads and edits, not what the Spec Kit phase commands do internally.

**Nothing named here is a dependency.** The tools below are accelerators for reading, and the run behaves identically without them — every step's rules, gates and artifacts are the same on plain `Read`, `Grep` and `Glob`. A host whose own instructions name different tools, or forbid these, wins over this file; substitute the equivalent and carry on. Step 0 probes for them so the prompt-review gate can say which reads were assisted, not so their absence can block anything.

## lean-ctx

Available → prefer over the native equivalents:

| Instead of                      | Use                                                                                                                                           |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `Read` or `cat` for exploration | `lean-ctx:ctx_read` — `mode=signatures` or `mode=map` to orient, `mode=lines:N-M` for a window, `mode=full` only when verbatim text is needed |
| `Grep` or `rg`                  | `lean-ctx:ctx_search` — regex, for markers and placeholders. Search by meaning is a separate tool, `lean-ctx:ctx_semantic_search`             |
| `Glob` or `find`                | `lean-ctx:ctx_glob`                                                                                                                           |
| `ls` or directory walks         | `lean-ctx:ctx_tree`                                                                                                                           |
| shell commands                  | `lean-ctx:ctx_shell`                                                                                                                          |
| editing project files           | `lean-ctx:ctx_read` with `mode=anchored`, then `lean-ctx:ctx_patch`                                                                           |

Native `Read` is reserved for the read-before-write edit gate.

## graphify

Available → prefer for codebase comprehension over ad-hoc file reading:

- `graphify query <question>` — codebase questions, such as where a cross-cutting concern is enforced, while drafting the plan prompt.
- `graphify path "<A>" "<B>"` — component relationships, such as whether a task touches a subsystem the plan never mentioned.
- `graphify explain "<concept>"` — focused concepts, when a spec requirement names a domain concept the repo already implements.

Use both in Step 2 and in conflict detection, where the question is "does the repo already contradict this?" — a graph query answers that in one call where file reading would not.

Neither available → use native tools, say so once at the prompt-review gate so the user knows the reads were unassisted, and change nothing else.

## Delegate broad sweeps

Context is the binding constraint across eight phases, and conflict detection wants to read half the repo. Sweep rather than lookup — "does anything here already implement this?", "which modules would this touch?" — delegate to a subagent, keep only the finding.

Main context holds artifacts, gate decisions, state. Not the files the sweep read to get there.

Delegate the search, never the decision. A subagent reports evidence; the conflict protocol, the gates, and every write stay in the main run.

**`reference/subagents.md` is the full rule.** It names the threshold at which an agent pays for itself, the cap of **ten concurrent readers per batch**, how to pick an agent type without hardcoding a plugin's, the points in the run that fan out, and what must never be delegated — every phase command, the hook dispatch, the boundary check, and Phase 8's `[P]` markers. Read it before dispatching anything. The tools above are what a sweep uses; that file is when a sweep becomes an agent.
