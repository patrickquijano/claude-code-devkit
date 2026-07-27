# Subagent authoring rules

Applies to any Markdown subagent definition under `.claude/agents/` or, once promoted, a plugin's `agents/` directory. See `plugins.md` for how an agent moves from prototype to packaged plugin.

## Scope and location

Use `.claude/agents/` for anything project-specific and team-shared — it's checked into git and discovered by walking up from the working directory, so it also applies from subdirectories. Use `~/.claude/agents/` only for genuinely personal agents you want in every project on this machine; don't put project-specific behavior there since teammates won't have it. Keep `name` values unique across the whole `agents/` tree (including subfolders) — Claude Code only loads one definition per duplicate name, chosen by filesystem read order, not a documented precedence.

## Frontmatter

`name` and `description` are the only required fields — `name` is a unique, lowercase-hyphenated identifier; `description` is what Claude reads to decide when to delegate to this agent, so write it as concretely as a skill's description (what task, what signal it should trigger on). Scope `tools` to the minimum the agent actually needs rather than leaving it to inherit everything, and use `disallowedTools` to carve out specific tools from an otherwise-broad set (e.g. remove `AskUserQuestion` from a background/autonomous agent that can't wait for a reply). Set `model` deliberately: `inherit` (the default) is right for agents whose work benefits from the same capability as the main conversation; a cheaper model like `haiku` is right for narrow, high-volume, low-reasoning work. Only set `isolation: worktree` when the agent needs its own copy of the repository to avoid clobbering the main checkout, since a worktree has real setup cost.

## Design

One clear responsibility per agent, matching the "coherent unit" principle used for skills — an agent that tries to both research and refactor is harder to trigger precisely and harder to trust with a narrow tool set. Write the `description` so Claude (or a human) can tell from it alone when to delegate here instead of handling the task inline, using a different built-in agent (`Explore`, `Plan`, `general-purpose`), or using a different custom agent. Prefer read-only tool access (`Read`, `Grep`, `Glob`) for agents whose job is investigation or review; only grant `Write`/`Edit`/`Bash` to agents that are meant to make changes.

## Testing

After adding or editing an agent, confirm it's picked up: it should appear in `/context` under Custom Agents, or be invokable directly by @-mentioning its scoped name. Delegate a realistic task to it and confirm it only reaches for the tools you scoped it to, and that its system prompt produces the shape of output you expect (a summary, a diff, a report) rather than something that needs re-prompting to fix.
