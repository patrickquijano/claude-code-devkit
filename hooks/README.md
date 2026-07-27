# hooks

Claude Code hook config for this plugin. `hooks.json` wires event →
matcher → command; the command scripts live in `scripts/`.

## PostToolUse: lint-format.sh

Runs right after Claude edits or writes a file (`Edit` / `Write`
matcher), lints and formats that one file based on its extension, and
reports the outcome. Never blocks the edit — `PostToolUse` can't deny a
call anyway — so the hook always exits `0`; a missing or unconfigured
tool is a logged skip, not a failure.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/lint-format.sh"
          }
        ]
      }
    ]
  }
}
```

### Extension → tool dispatch

| Extension(s)                      | Covers                | Tool(s)            | What runs                                                                                           |
| --------------------------------- | --------------------- | ------------------ | --------------------------------------------------------------------------------------------------- |
| `.ts .tsx .mts .cts`              | TypeScript + related  | eslint             | `npx eslint --fix` — only if an eslint config is found in `cwd`                                     |
| `.js .jsx .mjs .cjs`              | JavaScript + related  | eslint             | `npx eslint --fix` — only if an eslint config is found in `cwd`                                     |
| `.vue`                            | Vue.js / Nuxt.js SFC  | eslint             | `npx eslint --fix` — only if an eslint config is found in `cwd`                                     |
| `Dockerfile*` (basename match)    | —                     | hadolint           | `hadolint`                                                                                          |
| `.md .markdown`                   | —                     | markdownlint-cli2  | `npx markdownlint-cli2 --fix`                                                                       |
| `.py .pyi`                        | —                     | ruff               | `ruff format` then `ruff check --fix`                                                               |
| `.sh .bash`                       | —                     | shfmt, shellcheck  | `shfmt -w -i 2 -ci` (format) then `shellcheck` (lint)                                               |
| `.yml .yaml`                      | —                     | yamllint           | `yamllint` (lint-only)                                                                              |
| `.php .phtml` (not `*.blade.php`) | PHP + Laravel         | Pint, `php -l`     | `vendor/bin/pint` (or global `pint`) then `php -l`                                                  |
| `*.blade.php`                     | Laravel Blade         | —                  | skipped — Blade mixes HTML + directives, not valid PHP syntax, so no tool here is safe to run on it |
| `.css .scss .sass .less`          | Stylesheets + related | stylelint          | `npx stylelint --fix` — only if a stylelint config is found in `cwd`                                |
| `.cs .csx`                        | C# + related          | dotnet format      | `dotnet format --include` — only if a `.sln`/`.csproj` is found in `cwd`                            |
| `.html .htm`                      | HTML + related        | prettier, htmlhint | `npx prettier --write` (format) then `npx htmlhint` (lint)                                          |
| `.xml`                            | XML + related         | xmllint            | `xmllint --format --output` (format) then `xmllint --noout` (lint/validate)                         |
| anything else                     | —                     | —                  | no-op                                                                                               |

Every wrapper checks its tool is actually usable before running it:
`npx`-based tools (eslint, stylelint, markdownlint-cli2, prettier,
htmlhint) need `npx` on `PATH`; direct binaries (hadolint, shellcheck,
shfmt, yamllint, ruff, php, pint, dotnet, xmllint) need themselves on
`PATH`; eslint and stylelint additionally need a real config file in
`cwd` (they hard-error otherwise); `dotnet format` additionally needs a
`.sln`/`.csproj` in `cwd` (it requires project context). Anything
missing is a `[WARN]`/`[INFO]` skip, never a crash.

## scripts/

| File               | Purpose                                                                         |
| ------------------ | ------------------------------------------------------------------------------- |
| `lint-format.sh`   | Entrypoint — reads the hook's JSON payload from stdin, dispatches by extension. |
| `lib/lintfmt_*.sh` | Grouped by concern, `lintfmt_`-namespaced (see table below).                    |

### lib/

| File                    | Functions                                                                                                                                                        | Purpose                                                                                                                           |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `lintfmt_log.sh`        | `lintfmt_log_info`, `lintfmt_log_warn`, `lintfmt_log_error`                                                                                                      | Print `[INFO]`/`[WARN]`/`[ERROR] <msg>` to stdout/stderr.                                                                         |
| `lintfmt_util.sh`       | `lintfmt_command_exists`, `lintfmt_run_step`, `lintfmt_read_file_path`, `lintfmt_read_cwd`, `lintfmt_extension_of`, `lintfmt_is_blade_template`                  | `PATH` check; labeled step runner; hook-payload parsing (`tool_input.file_path`, `cwd`); dispatch-key + Blade-template detection. |
| `lintfmt_run_web.sh`    | `lintfmt_run_eslint`, `lintfmt_eslint_config_exists`, `lintfmt_run_stylelint`, `lintfmt_stylelint_config_exists`, `lintfmt_run_htmlhint`, `lintfmt_run_prettier` | eslint/stylelint (+ config-exists gates), htmlhint, prettier (HTML) — all via `npx`.                                              |
| `lintfmt_run_shell.sh`  | `lintfmt_run_shfmt`, `lintfmt_run_shellcheck`                                                                                                                    | `shfmt -w -i 2 -ci` (format) + `shellcheck` (lint).                                                                               |
| `lintfmt_run_php.sh`    | `lintfmt_pint_binary`, `lintfmt_run_pint`, `lintfmt_run_php_lint`                                                                                                | Resolves `vendor/bin/pint`/global `pint`, runs Pint, then `php -l`.                                                               |
| `lintfmt_run_dotnet.sh` | `lintfmt_dotnet_project_exists`, `lintfmt_run_dotnet_format`                                                                                                     | Checks for `.sln`/`.csproj`, then `dotnet format --include`.                                                                      |
| `lintfmt_run_xml.sh`    | `lintfmt_run_xmllint_format`, `lintfmt_run_xmllint_lint`                                                                                                         | `xmllint --format --output` (format) + `xmllint --noout` (lint).                                                                  |
| `lintfmt_run_simple.sh` | `lintfmt_run_ruff`, `lintfmt_run_markdownlint`, `lintfmt_run_yamllint`, `lintfmt_run_hadolint`                                                                   | Single-command linters with no config-check helper: ruff, markdownlint-cli2, yamllint, hadolint.                                  |

Every file documents its own args / stdout / exit status in a header
comment. Lib files never call `set -euo pipefail` themselves — sourcing
one won't silently flip strict mode on in the caller.

This directory is self-contained on purpose (no sourcing from the
repo's top-level `scripts/lib/`) so the `devkit` plugin stays a portable,
standalone directory per `.claude/rules/claude-components/plugins.md`.

## Requirements

`bash`, `jq` (to parse the hook's JSON payload). Every lint/format tool
itself is optional — each is skipped with a warning if not on `PATH`,
and eslint/stylelint/dotnet-format additionally need project config
before they run at all. See the dispatch table above for which binary
each extension needs.
