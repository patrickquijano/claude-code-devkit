# Claude Code practices

How this repository works with Claude Code, and why. Every practice below carries its source; where the official documentation settles nothing, that is recorded as a gap rather than filled with a guess.

Sources are the official documentation at <https://code.claude.com/docs>. Where a claim is marked **GAP**, it means no authoritative source was found — not that the opposite is true.

## Contents

- Where instructions live, and which file wins
- `CLAUDE.md`: what belongs in it
- Path-scoped rules, and the one mistake that wastes them
- Skills, rules and memory — choosing between them
- Settings and hooks
- Writing an instruction that is actually followed
- Plugin structure

## Where instructions live, and which file wins

Claude Code reads instruction files in a fixed precedence, broadest to most specific ([memory](https://code.claude.com/docs/en/memory.md)):

| Scope          | Path                                                                                                                                                     |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), `/etc/claude-code/CLAUDE.md` (Linux/WSL), `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows) |
| User           | `~/.claude/CLAUDE.md`                                                                                                                                    |
| Project        | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                                                                                   |
| Local          | `./CLAUDE.local.md`                                                                                                                                      |

Files above the working directory load at launch. Files in subdirectories load **on demand**, when Claude reads files in those directories.

`@path/to/import` pulls in another file. Relative and absolute paths both work — and a relative path "resolve[s] relative to the file containing the import, not the working directory". Imports recurse to a **maximum depth of four hops**, and import parsing skips code spans and fenced code blocks, so a path wrapped in backticks is mentioned rather than imported.

**Instruction files concatenate; they do not override one another.** "All discovered files are concatenated into context rather than overriding each other... instructions closer to where you launched Claude are read last." That is why the contradiction behaviour below is a consequence rather than a separate rule: nothing overrides anything, so two instructions that disagree are both present.

Auto memory has its own limit worth knowing: only "the first 200 lines of `MEMORY.md`, or the first 25KB, whichever comes first" load at the start of every conversation. Topic files load on demand.

The full layout — what each part of `.claude/` holds, when it loads, and how a plugin's manifest fields extend or replace the defaults — is in [`claude-code-project-structure.md`](./claude-code-project-structure.md).

**In this repository**: the project file is `./CLAUDE.md`. `AGENTS.md` and `LEAN-CTX.md` are deliberately **not** imported — they are read on demand when a task touches their subject. Importing them would put their whole contents into every session for the sake of the occasional task that needs them.

## `CLAUDE.md`: what belongs in it

**Target: under 200 lines.** Longer files consume more context and measurably reduce adherence. A file over 4 MiB is skipped entirely.

That number is the whole design constraint. Everything below follows from it.

Belongs — facts wanted in _every_ session:

- Build, test and lint commands, as commands.
- Conventions that differ from what the tooling would default to.
- Pitfalls: the thing that looks right and breaks.
- "Always do X" / "never do X" rules that hold repository-wide.
- Rationale, where a choice would otherwise look arbitrary and get "fixed".

Does not belong:

- Anything derivable by reading the code — directory layouts, dependency lists, architecture tours.
- A multi-step procedure. That is a skill.
- Anything true of only one area. That is a path-scoped rule.
- Feature requirements and acceptance criteria. Those belong in a spec.

The documentation's own trigger for adding an entry: when Claude makes the same mistake twice, when a review catches something Claude should have known, or when you type the same correction repeatedly.

**There is a tool for pruning it.** "For a checked-in CLAUDE.md, run `/doctor` and Claude proposes cuts for content it can derive from the codebase" — the derivability test, run by the tool rather than by hand.

**Emphasis is a scarce resource.** "If Claude keeps skipping one instruction, add emphasis such as 'IMPORTANT' to that line alone. If you emphasize many lines, none of them stands out." A file where several things are shouted has no way left to shout.

**Contradictions do not error — they get resolved arbitrarily.** "If two rules contradict each other, Claude may pick one arbitrarily." That is why an instruction file needs periodic review for stale entries, and why a rule recorded in two places is worse than a rule recorded in one: the copies agree the day they are written and drift silently afterwards.

## Path-scoped rules, and the one mistake that wastes them

`.claude/rules/*.md` is a documented feature, not a convention. A rule file carries YAML frontmatter with a `paths:` key:

```markdown
---
paths:
  - 'skills/**'
---

Rules that apply only when working on files under skills/.
```

- The key is `paths`, not `path`.
- Glob patterns work, including `**/*.ts`, `src/**/*`, and brace expansion like `src/**/*.{ts,tsx}`.
- A `paths` list shares a budget of **1,000 expanded patterns and 4 MiB**; each brace group multiplies the expanded count. **Patterns without braces do not count against it** — the budget exists for the expansion, so a list of plain globs cannot exhaust it.
- A rule with `paths` applies **only** when Claude is working with matching files.

**The mistake: a rule file with no `paths` key is loaded unconditionally at launch.** It then costs context in every session while sitting in a directory named `rules` and looking scoped. This is the failure the whole mechanism exists to avoid, and it is invisible — nothing errors, nothing warns, the file simply behaves like `CLAUDE.md` content with extra steps.

**In this repository**: every file under `.claude/rules/` declares `paths:`. Verify with `head -5 .claude/rules/*.md`.

Note that `.claude/` is excluded from most of this repository's quality checks, but `.claude/rules/` deliberately is **not** — those files are documentation the repository owns, so the `format`, `markdown` and `editorconfig` checks reach them. See [the exclusion contract](../specs/004-format-hook-scope/contracts/exclusion-declaration.md) for how each check declares its exclusions.

## Skills, rules and memory — choosing between them

| Shape                            | Goes to                                  | Loaded                            |
| -------------------------------- | ---------------------------------------- | --------------------------------- |
| Repository-wide, always relevant | `CLAUDE.md`                              | every session                     |
| Scoped to one area               | `.claude/rules/<topic>.md` with `paths:` | when matching files are worked on |
| A multi-step procedure           | a skill                                  | when invoked or judged relevant   |

The documentation is explicit about the third: "For task-specific instructions that don't need to be in context all the time, use skills instead." A procedure written into `CLAUDE.md` is paid for in every session; the same procedure as a skill is paid for when it is used.

## Settings and hooks

Settings precedence, highest first ([settings](https://code.claude.com/docs/en/settings.md)): managed settings, then `claude --settings`, then `.claude/settings.local.json`, then `.claude/settings.json`, then `~/.claude/settings.json`.

A key set at a higher level overrides the same key below it — but **lists merge rather than override**, so each file can add entries without removing another's.

**There are 32 documented hook events**, not the dozen this document used to list ([hooks](https://code.claude.com/docs/en/hooks-guide.md)). Alongside the tool and session events — `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `SessionStart`, `SessionEnd`, `Setup`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `SubagentStop`, `PreCompact`, `PostCompact`, `PermissionRequest`, `PermissionDenied` — there are events for the filesystem and the environment (`FileChanged`, `CwdChanged`, `DirectoryAdded`, `WorktreeCreate`, `WorktreeRemove`, `ConfigChange`, `InstructionsLoaded`), for models (`PreModelSwitch`, `PostModelSwitch`), for tasks and teammates (`TaskCreated`, `TaskCompleted`, `TeammateIdle`), for elicitation (`Elicitation`, `ElicitationResult`), and for display (`MessageDisplay`).

Consult the documentation rather than this list for the current set — the list grew by twenty between features 005 and 006, and there is no reason to think it has stopped.

**In this repository**: exactly one hook is registered, a `PostToolUse` hook in `.claude/settings.json` running `scripts/format-file.sh` after `Edit`, `Write`, `MultiEdit` and `NotebookEdit`. It reformats the file you just edited, which means **your edits are rewritten under you** — re-read a file after editing it if the exact bytes matter.

## Writing an instruction that is actually followed

Two rules, both from the documentation, and both worth more than any amount of emphasis.

**Be concrete enough to verify.** The documentation's own examples: "Use 2-space indentation" over "Format code properly"; "Run `npm test` before committing" over "Test your changes"; "API handlers live in `src/api/handlers/`" over "Keep files organized". An instruction that cannot be checked cannot be followed consistently either.

**Give Claude a pass-or-fail check.** "Tests, a build exit code, a linter, a script that diffs output against a fixture" — something that produces a verdict, so the work can be iterated against it rather than judged by eye ([best practices](https://code.claude.com/docs/en/best-practices.md)).

**In this repository** that check is `sh scripts/lint.sh`. It runs seven checks, stops at the first failure, and the constitution requires it to have passed before a change is proposed for review.

Structure matters too: Markdown headers and bullets grouped by topic, not dense paragraphs — "Claude scans structure the same way readers do".

## Plugin structure

`.claude-plugin/plugin.json` requires only `name`, in kebab-case. Optional fields cover metadata (`description`, `version`, `author`, `license`, `keywords`) and paths (`skills`, `commands`, `agents`, `hooks`, `mcpServers`) ([plugins reference](https://code.claude.com/docs/en/plugins-reference.md)).

Auto-discovery defaults: skills in `skills/`, commands in `commands/`, agents in `agents/`, hooks in `hooks/hooks.json`, MCP servers in `.mcp.json`.

**The `skills` field is additive.** It extends rather than replaces the default `skills/` directory, and both are loaded. For other path fields such as `commands` and `agents`, the field **replaces** the default.

**In this repository**: `plugin.json` declares no `skills` path and must not. Adding one would not redirect discovery, it would add a second location — so a new skill under `skills/` needs no manifest edit at all.

## Recorded gaps

- **Nested `CLAUDE.md` depth.** The four-hop limit applies to `@path` imports. No equivalent limit is documented for the filesystem hierarchy of `CLAUDE.md` files themselves; the documentation says only that files above the working directory load at launch and subdirectories load on demand.
