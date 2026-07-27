# Plugin structure and packaging rules

These rules apply once a component (skill, agent, or hook) is ready to move from a standalone `.claude/` prototype into a packaged, shareable plugin. See `skills.md`, `subagents.md`, and `hooks.md` in this same directory for rules on each component type individually.

## Repo workflow

Per `CLAUDE.md`, new components are prototyped first as standalone config under `.claude/skills/`, `.claude/agents/`, or in `.claude/settings.json` hooks — this is the fast-iteration path and isn't shared outside this machine except through `.claude/rules/` and `.claude/settings.json`, which are tracked in git. Once a component is stable and worth sharing or versioning independently, promote it into a proper plugin directory at the repo root (or a dedicated package) using the plugin layout below, then delete the `.claude/` copy so there's a single source of truth.

## Directory layout

A plugin is a self-contained directory. Only the manifest goes inside `.claude-plugin/`; every other component directory lives at the plugin root, not nested inside `.claude-plugin/`:

```text
my-plugin/
├── .claude-plugin/
│   └── plugin.json       # manifest only
├── skills/                # skills/<name>/SKILL.md
├── agents/                # one Markdown file per agent
├── hooks/
│   └── hooks.json
├── .mcp.json               # optional MCP server config
├── bin/                    # optional executables added to PATH
└── README.md                # install/usage docs for this plugin
```

A plugin that ships exactly one skill can place `SKILL.md` directly at the plugin root instead of creating a `skills/` directory — use the `skills/` layout as soon as a plugin might grow to more than one skill. The manifest itself is optional: if omitted, Claude Code auto-discovers components from these default locations and derives the plugin name from the directory name. Add a manifest when you need explicit metadata or non-default component paths.

## Manifest (`plugin.json`)

`name` is the only required field — kebab-case, unique, and used to namespace every component the plugin ships (a skill named `hello` in a plugin named `my-plugin` becomes `/my-plugin:hello`; an agent `reviewer` becomes `my-plugin:reviewer`). Always set `description` and `version` explicitly rather than relying on the git-commit-SHA fallback, so consumers get predictable, opt-in updates instead of a new "version" on every commit. Unrecognized top-level fields are ignored (with a `claude plugin validate` warning), so it's safe to let `plugin.json` double as metadata for another tool if needed — but don't rely on that for anything load-bearing.

## Naming and versioning

- Plugin `name`: kebab-case, descriptive of what it does, not the org or repo name.
- Skill/agent names inside a plugin: kebab-case directory or file names; the plugin namespace prefix is automatic, so don't repeat the plugin name inside the skill/agent name itself (`skills/hello/`, not `skills/my-plugin-hello/`).
- Version explicitly with semver once a plugin has any external consumer; bump on every user-facing change.

## Testing before sharing

- `claude --plugin-dir ./my-plugin` loads the plugin directly for local testing, without requiring a marketplace install; it takes precedence over any installed plugin of the same name for that session.
- `/reload-plugins` picks up changes without restarting.
- Test skills with `/plugin-name:skill-name`, confirm agents appear in `/context` under Custom Agents, and verify hooks fire as expected.
- Run `claude plugin validate ./my-plugin --strict` before sharing — `--strict` turns manifest field warnings (e.g. a misspelled field) into hard failures, which is worth catching before publishing even though the plugin would still load without it.

## Documentation

Every plugin intended for sharing ships its own `README.md` with installation and usage instructions — this is separate from (and more detailed than) the repo-level `README.md`, which only needs to describe the devkit as a whole.
