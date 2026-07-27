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
| `lib/lintfmt_*.sh` | One function per file, `lintfmt_`-namespaced.                                   |

### lib/

| File                                 | Function                          | Purpose                                                                         |
| ------------------------------------ | --------------------------------- | ------------------------------------------------------------------------------- |
| `lintfmt_log_info.sh`                | `lintfmt_log_info`                | Print `[INFO] <msg>` to stdout.                                                 |
| `lintfmt_log_warn.sh`                | `lintfmt_log_warn`                | Print `[WARN] <msg>` to stderr.                                                 |
| `lintfmt_log_error.sh`               | `lintfmt_log_error`               | Print `[ERROR] <msg>` to stderr.                                                |
| `lintfmt_command_exists.sh`          | `lintfmt_command_exists`          | Validator: is a command on `PATH`.                                              |
| `lintfmt_run_step.sh`                | `lintfmt_run_step`                | Run + log a labeled command; returns its exit status without tripping `set -e`. |
| `lintfmt_read_file_path.sh`          | `lintfmt_read_file_path`          | Extract `tool_input.file_path` from the hook's JSON payload.                    |
| `lintfmt_read_cwd.sh`                | `lintfmt_read_cwd`                | Extract `cwd` from the hook's JSON payload.                                     |
| `lintfmt_is_blade_template.sh`       | `lintfmt_is_blade_template`       | True if basename ends in `.blade.php`.                                          |
| `lintfmt_extension_of.sh`            | `lintfmt_extension_of`            | Dispatch key: `dockerfile` for `Dockerfile*`, else lowercase extension.         |
| `lintfmt_eslint_config_exists.sh`    | `lintfmt_eslint_config_exists`    | Checks `cwd` for a real ESLint config.                                          |
| `lintfmt_stylelint_config_exists.sh` | `lintfmt_stylelint_config_exists` | Checks `cwd` for a real Stylelint config.                                       |
| `lintfmt_dotnet_project_exists.sh`   | `lintfmt_dotnet_project_exists`   | Checks `cwd` for a `.sln`/`.csproj`.                                            |
| `lintfmt_run_eslint.sh`              | `lintfmt_run_eslint`              | `npx eslint --fix` wrapper (TS/JS/Vue).                                         |
| `lintfmt_run_stylelint.sh`           | `lintfmt_run_stylelint`           | `npx stylelint --fix` wrapper.                                                  |
| `lintfmt_run_hadolint.sh`            | `lintfmt_run_hadolint`            | `hadolint` wrapper.                                                             |
| `lintfmt_run_markdownlint.sh`        | `lintfmt_run_markdownlint`        | `npx markdownlint-cli2 --fix` wrapper.                                          |
| `lintfmt_run_ruff.sh`                | `lintfmt_run_ruff`                | `ruff format` + `ruff check --fix` wrapper.                                     |
| `lintfmt_run_shfmt.sh`               | `lintfmt_run_shfmt`               | `shfmt -w -i 2 -ci` wrapper.                                                    |
| `lintfmt_run_shellcheck.sh`          | `lintfmt_run_shellcheck`          | `shellcheck` wrapper.                                                           |
| `lintfmt_run_yamllint.sh`            | `lintfmt_run_yamllint`            | `yamllint` wrapper.                                                             |
| `lintfmt_pint_binary.sh`             | `lintfmt_pint_binary`             | Resolves `vendor/bin/pint`, else global `pint`, else empty.                     |
| `lintfmt_run_pint.sh`                | `lintfmt_run_pint`                | Laravel Pint formatter wrapper.                                                 |
| `lintfmt_run_php_lint.sh`            | `lintfmt_run_php_lint`            | `php -l` syntax-check wrapper.                                                  |
| `lintfmt_run_dotnet_format.sh`       | `lintfmt_run_dotnet_format`       | `dotnet format --include` wrapper.                                              |
| `lintfmt_run_prettier.sh`            | `lintfmt_run_prettier`            | `npx prettier --write` wrapper (HTML).                                          |
| `lintfmt_run_htmlhint.sh`            | `lintfmt_run_htmlhint`            | `npx htmlhint` wrapper.                                                         |
| `lintfmt_run_xmllint_format.sh`      | `lintfmt_run_xmllint_format`      | `xmllint --format --output` wrapper.                                            |
| `lintfmt_run_xmllint_lint.sh`        | `lintfmt_run_xmllint_lint`        | `xmllint --noout` wrapper.                                                      |

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
