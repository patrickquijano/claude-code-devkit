# Skill authoring rules

Applies to any `SKILL.md` under `.claude/skills/` or, once promoted, a plugin's `skills/` directory. See `plugins.md` for how a skill moves from prototype to packaged plugin.

## Structure

Every skill is a directory containing a required `SKILL.md`. Add supporting files only when the skill needs them for progressive disclosure: `references/` for detailed material the agent should load on demand, `scripts/` for tested code the agent should run rather than reinvent, `assets/` or `templates/` for output templates. Reference every supporting file from `SKILL.md` and say when to load it — a generic "see references/ for details" is not enough; be specific, e.g. "Read `references/api-errors.md` if the API returns a non-200 status."

## Naming

The skill's directory name becomes its invocation name (kebab-case, e.g. `summarize-changes` → `/summarize-changes`). In a plugin, the frontmatter `name` field can override the final segment of the namespaced command (`my-plugin/skills/review/SKILL.md` with `name: fancy` → `/my-plugin:fancy`), but for a standalone project or personal skill, `name` only sets the display label in listings — the command still comes from the directory name.

## Frontmatter

Only `description` is recommended, but it carries the entire burden of triggering: Claude loads just `name` + `description` at startup and reads the full body only when the description matches the task. Write it as an instruction ("Use this skill when...") rather than a description of internals ("This skill does..."), describe user intent rather than implementation, and be explicit — including cases where the user doesn't name the domain directly. Keep `description` (plus `when_to_use` if used) concise; the combined text is truncated at 1,536 characters in the skill listing, and the spec hard-limits `description` alone to 1,024 characters. Other fields to reach for deliberately, not by default: `disable-model-invocation: true` for a workflow that should only run via explicit `/name` invocation; `user-invocable: false` to hide background-knowledge skills from the `/` menu; `allowed-tools` / `disallowed-tools` to pre-approve or forbid specific tools for the turn that invokes the skill; `paths` to auto-activate only when working with matching files; `context: fork` to run the skill in its own subagent context.

## Size and content quality

Keep the `SKILL.md` body under roughly 500 lines / 5,000 tokens — once a skill activates, its full body stays loaded in context for the rest of the session, competing with everything else for the agent's attention. Add only what the agent wouldn't already know: project-specific conventions, non-obvious edge cases, and the exact APIs or tools to use — not general explanations of well-known concepts. Pick a default approach and mention alternatives briefly rather than presenting a menu of equal options. Favor reusable procedures ("read the schema, join on the `_id` convention, apply filters, aggregate") over answers to one specific instance of the task. A "Gotchas" section — concrete, non-obvious project facts that contradict reasonable assumptions (e.g. "the `users` table uses soft deletes; queries need `WHERE deleted_at IS NULL`") — is often the highest-value content in a skill; add to it whenever you have to correct the agent for the same mistake twice.

## Testing and iterating

Before relying on a new or edited skill, sanity-check that it triggers on a handful of realistic prompts and stays silent on realistic near-miss prompts that need something else. For anything beyond a quick manual check, write eval queries (a mix of should-trigger and should-not-trigger, varied in phrasing and detail) and a small `evals/evals.json` with prompts, expected output, and assertions, then use the bundled `skill-creator` skill to run and grade them. Iterate from real execution transcripts, not assumptions — if the agent wastes steps or ignores an instruction, the instruction is probably too vague, inapplicable to that case, or presenting too many options without a clear default.
