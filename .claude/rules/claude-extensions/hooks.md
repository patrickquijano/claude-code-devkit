# Hook authoring rules

Applies to hooks defined in `.claude/settings.json`, `.claude/settings.local.json`, or, once promoted, a plugin's `hooks/hooks.json`. See `plugins.md` for how a hook moves from prototype to packaged plugin.

## Location

Put anything team-shared in `.claude/settings.json` so it's committed and applies to every collaborator; put personal-only hooks in `.claude/settings.local.json`, which stays gitignored. A plugin ships its hooks in `hooks/hooks.json` at the plugin root (or inline in `plugin.json`) using the same schema.

## Configuration shape

A hook configuration is event → matcher group(s) → handler(s): pick a lifecycle event (e.g. `PreToolUse`, `PostToolUse`, `Stop`), narrow it with a `matcher` (an exact tool name like `Bash`, an alternation like `Edit|Write`, or a regex for broader matches like `mcp__.*`), then define one or more handlers. Prefer the narrowest matcher that expresses the intent — an exact tool name over a broad regex — and use a handler's `if` field (permission-rule syntax, e.g. `"Bash(git *)"` or `"Edit(*.ts)"`) to narrow further instead of doing that filtering inside the script itself; `if` only applies to tool events (`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`). Matching an MCP tool requires the `mcp__<server>__<tool>` form, and matching every tool from a server requires the trailing `.*` (`mcp__memory__.*`, not the bare `mcp__memory`, which is compared as an exact string and matches nothing).

## Security

Hooks run unsandboxed, with the same permissions as the rest of the session, so treat every hook script like production code that handles untrusted input: quote `${CLAUDE_PLUGIN_ROOT}` and any other path substitution, validate and sanitize anything extracted from the JSON input (e.g. via `jq`) before using it in a shell command, and never build a shell command by concatenating unsanitized fields. Default to failing closed rather than open — a hook that can't parse its input should exit non-zero or return no decision rather than silently approving. Reserve `PreToolUse` deny decisions for the specific, narrow condition you actually want to block; a hook can only deny a call, it can't be relied on to positively approve one, so don't use it as the only gate for something that must never happen — pair it with `permissions.deny` for hard enforcement.

## Testing

After adding or editing a hook, use the `/hooks` menu or `claude --debug` to confirm it fires on the expected event and returns the decision or output you intended, rather than assuming the matcher and `if` condition behave as written. Check the exit-code and JSON-output conventions for the specific event you're hooking — they differ per event (for example, `Stop`/`StopFailure` ignore output and exit code differently than `PreToolUse`) — before depending on either one.
