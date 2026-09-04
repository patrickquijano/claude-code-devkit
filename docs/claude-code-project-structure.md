# Claude Code project structure

How a Claude Code project is laid out on disk: what the tool discovers without being told, what a plugin adds, and where instruction files sit relative to each other. Every claim carries its source; where the official documentation settles nothing, that is recorded as a **GAP** rather than filled with a guess.

Sources are the official documentation at <https://code.claude.com/docs>, principally [the `.claude` directory](https://code.claude.com/docs/en/claude-directory.md), [memory](https://code.claude.com/docs/en/memory.md), [settings](https://code.claude.com/docs/en/settings.md) and the [plugins reference](https://code.claude.com/docs/en/plugins-reference.md).

## Contents

- What `.claude/` holds, and when each part loads
- Instruction files and their precedence
- `@path` imports
- Plugin layout, and which manifest fields extend rather than replace
- The budgets, in one table
- This repository's own tree
- Recorded gaps

## What `.claude/` holds, and when each part loads

Sources: [the `.claude` directory](https://code.claude.com/docs/en/claude-directory.md) and [memory](https://code.claude.com/docs/en/memory.md).

A project's `.claude/` directory is discovered without configuration. The distinction that matters is **when** each part enters context, because that is what it costs.

| Path                          | Holds                                 | Loaded                                                      |
| ----------------------------- | ------------------------------------- | ----------------------------------------------------------- |
| `.claude/settings.json`       | shared project settings               | session start                                               |
| `.claude/settings.local.json` | personal project settings, gitignored | session start                                               |
| `.claude/rules/*.md`          | instructions, optionally path-scoped  | **depends on `paths:`** — see below                         |
| `.claude/skills/*/SKILL.md`   | procedures                            | when invoked as `/name`, or when Claude judges one relevant |
| `.claude/commands/*.md`       | slash commands                        | when the user types `/command-name`                         |
| `.claude/agents/*.md`         | subagent definitions                  | at launch, into the agent listing                           |
| `.mcp.json` (repository root) | MCP server definitions                | servers connect when the session begins                     |

The one with a condition attached is `.claude/rules/`: "Rules without `paths:` load at session start... Rules with `paths:` load when a matching file enters context." A rule file that omits `paths:` therefore behaves exactly like always-loaded instruction content while sitting in a directory whose name suggests it is scoped — the trap recorded in [`claude-code-practices.md`](./claude-code-practices.md).

**In this repository**: `.claude/` holds `settings.json` (one `PostToolUse` hook), `rules/` (three files, every one declaring `paths:`), and `worktrees/`, which is not a Claude Code location at all — it is where `EnterWorktree` puts worktrees, and it is excluded from `git status` through `.git/info/exclude` rather than `.gitignore`. There is no `.claude/skills/` of this repository's own authorship; the `speckit-*` skills there arrive from the Spec Kit installation. There is no `.mcp.json`.

## Instruction files and their precedence

Claude Code reads instruction files in a fixed order, broadest to most specific ([memory](https://code.claude.com/docs/en/memory.md)):

| Scope          | Path                                                                                                                                                     |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), `/etc/claude-code/CLAUDE.md` (Linux/WSL), `C:\Program Files\ClaudeCode\CLAUDE.md` (Windows) |
| User           | `~/.claude/CLAUDE.md`                                                                                                                                    |
| Project        | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                                                                                   |
| Local          | `./CLAUDE.local.md`                                                                                                                                      |

**These concatenate; they do not override one another.** "All discovered files are concatenated into context rather than overriding each other... instructions closer to where you launched Claude are read last."

That is what makes the contradiction behaviour a consequence rather than a separate rule: because nothing overrides anything, two instructions that disagree are both present, and "if two rules contradict each other, Claude may pick one arbitrarily". A rule recorded in two places is worse than a rule recorded in one — the copies agree the day they are written and drift silently afterwards, and no check will catch it, because at no single moment do they contradict.

Files above the working directory load at launch. Files in subdirectories load **on demand**, when Claude reads files in those directories.

**In this repository**: the project file is `./CLAUDE.md`. There is no `./.claude/CLAUDE.md` and no `CLAUDE.local.md`.

## `@path` imports

Source: [memory](https://code.claude.com/docs/en/memory.md).

`@path/to/import` pulls another file into an instruction file.

- Imports recurse to a **maximum depth of four hops**.
- Both relative and absolute paths work. "Relative paths resolve relative to the file containing the import, not the working directory."
- Import parsing **skips Markdown code spans and fenced code blocks**. "To mention a path in your CLAUDE.md without importing it, wrap it in backticks."

**In this repository**: nothing is imported. `AGENTS.md` and `LEAN-CTX.md` are deliberately read on demand instead — importing them would put their whole contents into every session for the sake of the occasional task that needs them.

## Plugin layout, and which manifest fields extend rather than replace

Sources: [plugins reference](https://code.claude.com/docs/en/plugins-reference.md) and [plugins](https://code.claude.com/docs/en/plugins.md).

`.claude-plugin/plugin.json` requires only `name`, in kebab-case. Auto-discovery defaults:

| Component   | Default location   |
| ----------- | ------------------ |
| Skills      | `skills/`          |
| Commands    | `commands/`        |
| Agents      | `agents/`          |
| Hooks       | `hooks/hooks.json` |
| MCP servers | `.mcp.json`        |

**The behaviour of the manifest's path fields is not uniform, and the asymmetry is the thing to know.**

For `skills`: "The default `skills/` is always scanned. Custom paths are loaded **alongside** the default." Declaring a path adds a location; it does not redirect discovery.

For everything else — `commands`, `agents`, `hooks`, `mcpServers`: "When you specify a manifest field, the default directory is **NOT** scanned. To keep the default AND add more, list it explicitly."

One documented exception cuts against the `skills` rule: "For marketplace entries with `source` resolving to marketplace root, declaring specific subdirectories **replaces** the default `skills/` scan."

**In this repository**: `plugin.json` declares no `skills` path and must not. Adding one would not redirect discovery — it would add a second location — so a new skill under `skills/` needs no manifest edit at all. No `commands`, `agents`, `hooks` or `mcpServers` field is declared either, and the repository ships none of those components yet.

## The budgets, in one table

Sources: [memory](https://code.claude.com/docs/en/memory.md) for the first four, [skills](https://code.claude.com/docs/en/skills.md) for the last three.

Gathered here because they are documented in four different places and each one shapes a layout decision.

| Budget                                 | Value                                               | Consequence                                                            |
| -------------------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------- |
| `CLAUDE.md` target length              | under 200 lines                                     | longer files "consume more context and reduce adherence"               |
| `CLAUDE.md` hard limit                 | 4 MiB                                               | a larger file is **skipped entirely**                                  |
| `MEMORY.md` load                       | first 200 lines **or** 25 KB, whichever comes first | auto-memory topic files load on demand; only the index is always there |
| `paths:` list, per rule                | 1,000 expanded patterns and 4 MiB                   | **patterns without braces don't count against it**                     |
| `@path` import depth                   | 4 hops                                              | a five-deep import chain silently stops                                |
| Skill `description` plus `when_to_use` | 1,536 characters                                    | the listing truncates past it                                          |
| `SKILL.md` body                        | under 500 lines                                     | move reference material to sibling files                               |
| Skill re-attachment after compaction   | first 5,000 tokens each, 25,000 combined            | a long skill loses its **later half** first                            |

The brace exemption is easy to misread: it is patterns _containing_ brace groups that consume the budget, multiplied by their expansion, and plain patterns that do not.

**In this repository**: `CLAUDE.md` is 54 lines. The longest `SKILL.md` is under 500. The compaction budget is why `ccd-speckit-run` keeps its run state in a file rather than in its own prose — see [`skill-authoring-practices.md`](./skill-authoring-practices.md).

## This repository's own tree

What the above amounts to here, with the reasoning for the parts that are a choice rather than a default:

```text
CLAUDE.md                    # project instructions, always loaded
AGENTS.md                    # shared cross-agent instructions, read on demand
LEAN-CTX.md                  # tool-owned, read on demand, excluded from linting
README.md
.claude/
├── settings.json            # one PostToolUse hook
├── rules/                   # every file declares paths:
└── worktrees/               # EnterWorktree's location, not a Claude Code one
.claude-plugin/
├── plugin.json              # declares no skills path, deliberately
└── marketplace.json
docs/                        # this documentation set
skills/                      # the plugin's own skills, auto-discovered
scripts/                     # the quality gate
specs/                       # Spec Kit feature artifacts
.specify/                    # Spec Kit's own machinery
```

There is no `src/` and no `tests/`. This repository holds no application code, and inventing either would be scaffolding for its own sake — a decision recorded at `specs/001-quality-gate-plugin/plan.md` and unchanged since.

## Recorded gaps

- **Recursive `@path` traversal order.** The four-hop maximum is documented; the order in which a chain of imports is resolved is not.
- **Brace expansion and the pattern budget.** Brace-free patterns are documented as exempt. Whether a brace group counts before or after expansion is not stated.
- **Rules versus `CLAUDE.md` on a contradiction.** A `.claude/rules/` file with no `paths:` and `CLAUDE.md` both load at session start. Which wins when they disagree is not documented, and the general answer — that Claude "may pick one arbitrarily" — is the only guidance available.
- **Nested `CLAUDE.md` depth.** The four-hop limit applies to `@path` imports. No equivalent limit is documented for the filesystem hierarchy of `CLAUDE.md` files themselves.
- **No prescribed section order for `CLAUDE.md`.** This is a definite finding rather than a gap, and it is recorded here because it is the question people expect an answer to: the documentation states what belongs in the file and that structure should use "markdown headers and bullets to group related instructions", but prescribes **no ordering of sections**.
