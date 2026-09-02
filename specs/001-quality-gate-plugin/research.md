# Phase 0 Research: Repository Quality Gate and Plugin Packaging

**Date**: 2026-09-02 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Every configuration decision below was taken against documentation fetched during this phase, not from recall. Each entry states the decision, the rationale, and what else was considered. Where a setting departs from the tool's documented default, the departure is called out explicitly — that is what FR-014 requires.

## 1. markdownlint-cli2

**Sources**: [markdownlint-cli2 README](https://github.com/DavidAnson/markdownlint-cli2), Context7 `/davidanson/markdownlint-cli2`.

**Configuration file**: `.markdownlint-cli2.jsonc`. Accepted top-level properties are `config`, `customRules`, `fix`, `frontMatter`, `gitignore`, `globs`, `ignores`, `markdownItPlugins`, `modulePaths`, `noBanner`, `noInlineConfig`, `noProgress`, `outputFormatters`, `overrides`, `showFound`.

**Decision**: commit `.markdownlint-cli2.jsonc` carrying only a `config` object plus `noProgress: true`. Do not use `globs`, `ignores`, or `gitignore`; the runner passes an explicit file list instead (see §8).

**Rationale**: `markdownlint-cli2 .` silently maps to `*.{md,markdown}` in the current directory only — the full tree needs `**`. That footgun is the reason the runner supplies paths rather than relying on glob defaults. Keeping `ignores` out of this file keeps scope in one place, as FR-013a requires.

**Non-default settings, with reasons**:

| Rule                         | Default                 | Chosen                                                       | Why                                                                                                                                                                                           |
| ---------------------------- | ----------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MD013` line-length          | enabled, 80 columns     | `false`                                                      | This repository's own instruction files are written one line per paragraph on purpose — the speckit-run skill it is modelled on mandates it. A line-length rule would fail every one of them. |
| `MD033` no-inline-html       | enabled                 | `{ "allowed_elements": ["!--"] }` is not valid; kept enabled | Comment syntax is not an element, so the Sync Impact Report comment in the constitution passes without loosening the rule.                                                                    |
| `MD024` no-duplicate-heading | enabled, whole document | `{ "siblings_only": true }`                                  | Spec and plan documents legitimately repeat headings such as `Acceptance Scenarios` under different user stories. Sibling scoping catches real duplicates without punishing structure.        |
| `MD041` first-line-heading   | enabled                 | left enabled                                                 | Every document this repository holds starts with a heading.                                                                                                                                   |
| `noProgress`                 | progress shown          | `true`                                                       | Progress output is noise in a check whose only useful output is violations.                                                                                                                   |

**Container image**: `davidanson/markdownlint-cli2` — published by the tool's own author, confirmed present in the registry. This is the upstream-official image Principle III asks for.

**Alternatives considered**: `markdownlint-cli` (`igorshubovych/markdownlint-cli`) is a separate, older CLI for the same library; `markdownlint-cli2` is the configuration-file-first successor and is what its author packages as a container. `.markdownlint.json` (the library's own config file) was rejected because it cannot express CLI-level settings such as `noProgress`.

## 2. yamllint

**Sources**: [yamllint configuration documentation](https://yamllint.readthedocs.io/en/stable/configuration.html), Context7 `/adrienverge/yamllint`.

**Configuration file**: `.yamllint.yml`. yamllint searches `.yamllint`, `.yamllint.yaml`, `.yamllint.yml` upward from the working directory, then `$YAMLLINT_CONFIG_FILE`, then `$XDG_CONFIG_HOME/yamllint/config`, then its built-in default.

**Decision**: `extends: default`, with three rule overrides.

**Rationale**: the `default` preset is strict, which is the right starting point for a repository that holds only a handful of YAML files. `relaxed` was rejected: it disables the rules most likely to catch a real mistake.

**Non-default settings, with reasons**:

| Rule             | Default                  | Chosen                                | Why                                                                                                                                                                                                                                   |
| ---------------- | ------------------------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `line-length`    | enabled, 80              | `disable`                             | Same reason as `MD013`. Consistency between the Markdown and YAML standards matters more than either individual limit.                                                                                                                |
| `document-start` | warning, `present: true` | `disable`                             | A leading `---` adds nothing to a single-document config file, and warning about its absence produces noise on every file in the repository.                                                                                          |
| `truthy`         | warning                  | `{ level: error, check-keys: false }` | `yes`/`no`/`on`/`off` parsing as booleans is a genuine source of silent misconfiguration, so it should fail rather than warn. `check-keys: false` because GitHub Actions' `on:` key is a legitimate exception that cannot be renamed. |

Left at default deliberately: `indentation`, `new-line-at-end-of-file`, `trailing-spaces`, `key-duplicates`, `comments`. `empty-values`, `quoted-strings` and `document-end` are disabled in the default preset and stay that way.

**Scope**: no `ignore` or `ignore-from-file` key. Scope is the runner's job (§8). Note that yamllint forbids using `ignore` and `ignore-from-file` together, so keeping both out avoids the question entirely.

**Container image**: **yamllint publishes no official image.** `cytopia/yamllint` has not been pushed in over two years; `pipelinecomponents/yamllint` is actively maintained but third-party. Decision: run yamllint inside the Docker **Official** `python` image with the tool version pinned in the install command. See §9 for why, and Complexity Tracking in plan.md for the deviation this represents.

## 3. ShellCheck

**Sources**: [ShellCheck Ignore wiki](https://github.com/koalaman/shellcheck/wiki/Ignore), [Optional checks wiki](https://github.com/koalaman/shellcheck/wiki/Optional) (v0.11.0), [SC2039](https://www.shellcheck.net/wiki/SC2039).

**Configuration file**: `.shellcheckrc`, read from the project base directory and from `~`. Directives include `disable=`, `enable=`, `source=`, `source-path=`, `shell=`, `external-sources=`, `severity=`.

**Decision**: commit `.shellcheckrc` setting `shell=sh`, `severity=style`, `external-sources=true`, `source-path=SCRIPTDIR`, and four `enable=` optional checks.

**Rationale**: `shell=sh` is the load-bearing line — it is what makes ShellCheck enforce Principle IV rather than assume bash. `severity=style` means every finding fails the check, which is what FR-005 demands; a laxer severity would let style findings pass silently. `source-path=SCRIPTDIR` plus `external-sources=true` lets ShellCheck follow the runner scripts' shared helper, so the helper's definitions are checked in context instead of producing "cannot follow source" findings.

**Optional checks enabled, and why not `enable=all`**:

| Check                        | Why enabled                                                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `add-default-case`           | An unhandled `case` branch in a tool-resolution function is a silent no-op, which is exactly the failure Principle II forbids. |
| `check-extra-masked-returns` | Directly enforces Principle II: finds the places where an exit status is swallowed.                                            |
| `check-set-e-suppressed`     | Same reason — `set -e` not applying inside a function call is the classic way fail-fast stops being fail-fast.                 |
| `deprecate-which`            | `command -v` is POSIX; `which` is not, and its exit status is unreliable.                                                      |

`enable=all` was rejected because it includes `require-double-brackets`, which mandates `[[ ]]` — a bashism, and therefore in direct conflict with `shell=sh`. `quote-safe-variables` and `require-variable-braces` were also left off: both are stylistic, and neither prevents a defect the other checks miss.

**POSIX constructs to avoid** (from SC2039, recorded here so implementation does not have to rediscover them): `==` in `test` (use `=`), `$'…'` C-style escapes (use `printf`), `${var:offset}` substring expansion, `for ((;;))` loops, `**` exponentiation, bare `((…))` arithmetic, `select`, here-strings `<<<` (use a here-document), `${var/pattern/replacement}`, `printf %q`, `local` (not POSIX, though universally supported — see §7), `SIG`-prefixed trap names (use `TERM`, not `SIGTERM`).

**Container image**: `koalaman/shellcheck` — the author's own image, confirmed present. Upstream-official.

## 4. Prettier

**Sources**: [Prettier options](https://prettier.io/docs/options), [Prettier configuration](https://prettier.io/docs/configuration), [prettier/prettier#15206](https://github.com/prettier/prettier/issues/15206) on the absence of an official image.

**Configuration file**: `.prettierrc.json`. Prettier's search order is the `prettier` key in `package.json`, then `.prettierrc`, then `.prettierrc.json` / `.yml` / `.yaml` / `.json5`, then the JS/TS variants, then `.prettierrc.toml`.

**Decision**: commit `.prettierrc.json` with `endOfLine: "lf"`, `printWidth: 100`, `proseWrap: "preserve"`, plus an `overrides` entry pinning `tabWidth: 2` for JSON. Commit `.prettierignore` as well, since Prettier's own ignore file is the documented way to keep it away from files another standard owns.

**Rationale**: Prettier's job in this repository is narrow — JSON and JSONC formatting. Markdown is markdownlint's and YAML is yamllint's; letting three tools format the same file is how they start fighting.

**Non-default settings, with reasons**:

| Option              | Default      | Chosen                          | Why                                                                                                                                                         |
| ------------------- | ------------ | ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `endOfLine`         | `"lf"`       | `"lf"` (explicit)               | Already the default, written out anyway so it agrees visibly with `.editorconfig`'s `end_of_line = lf`. Two files disagreeing silently is the failure mode. |
| `printWidth`        | `80`         | `100`                           | 80 is tight for JSON with URL values and digest-pinned image references, which this repository has by construction.                                         |
| `proseWrap`         | `"preserve"` | `"preserve"` (explicit)         | Already the default; stated explicitly because reflowing prose would fight the one-line-per-paragraph convention.                                           |
| `tabWidth` for JSON | `2`          | `2` (explicit, via `overrides`) | Matches `.editorconfig`, for the same visibility reason.                                                                                                    |

**`.prettierignore`**: Markdown and YAML are excluded there, so that a contributor invoking Prettier directly — not through the runner — still gets the same division of labour.

**Container image**: **Prettier publishes no official image** and the request for one is still open upstream. `tmknom/prettier` and `wesleydeanflexion/prettier` are third-party. Decision: the Docker **Official** `node` image with the Prettier version pinned in the invocation. See §9.

## 5. Ruff

**Sources**: [Ruff configuration](https://docs.astral.sh/ruff/configuration/), [Ruff settings](https://docs.astral.sh/ruff/settings/), [Ruff rules](https://docs.astral.sh/ruff/rules/), [Ruff installation](https://docs.astral.sh/ruff/installation/).

**Configuration file**: `ruff.toml`. Documented defaults: `line-length = 88`, `indent-width = 4`, `target-version = "py310"`, `lint.ignore = []`, `lint.preview = false`, `respect-gitignore = true`, `format.quote-style = "double"`, `format.indent-style = "space"`, `format.line-ending = "auto"`, `format.docstring-code-format = false`. The default `lint.select` enables the `F`, `E`, `B`, `UP` and `RUF` categories "as well as many more, omitting any stylistic rules that overlap with the use of a formatter".

**Decision**: commit `ruff.toml` with `line-length = 100`, `target-version = "py39"`, `[format] line-ending = "lf"`, `docstring-code-format = true`, and an explicit `[lint] select` that names the default categories plus `I`, `SIM`, `PTH` and `S`. Leave `exclude` alone.

**Rationale**: the repository holds no Python yet. That is precisely why the configuration is worth committing now — the first Python file that lands is governed from its first commit rather than from whenever someone remembers. An explicit `select` is preferred over relying on the default set because Ruff's default set is documented as changing between releases; naming the categories makes an upgrade a visible diff rather than a silent behaviour change.

**Non-default settings, with reasons**:

| Setting                        | Default                    | Chosen                                                 | Why                                                                                                                                                                                                                                                             |
| ------------------------------ | -------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `line-length`                  | `88`                       | `100`                                                  | Agrees with Prettier's `printWidth`. One number for the repository beats two defensible numbers.                                                                                                                                                                |
| `target-version`               | `"py310"`                  | `"py39"`                                               | Nothing here needs 3.10 syntax, and the lower floor keeps any future helper script runnable on the older interpreters still shipped by long-term-support distributions.                                                                                         |
| `format.line-ending`           | `"auto"`                   | `"lf"`                                                 | `auto` infers per file. Explicit `lf` agrees with `.editorconfig` and Prettier, and makes the setting checkable.                                                                                                                                                |
| `format.docstring-code-format` | `false`                    | `true`                                                 | This is a toolkit repository; example code in docstrings is likely, and unformatted examples in a formatting toolkit read badly.                                                                                                                                |
| `lint.select`                  | the documented default set | that set named explicitly, plus `I`, `SIM`, `PTH`, `S` | `I` (isort) because import order is otherwise unenforced; `SIM` and `PTH` because they catch the two things that most often make a small script hard to read; `S` (flake8-bandit) because this repository's Python, if any, will be tooling that runs commands. |

**Container image**: `ghcr.io/astral-sh/ruff` — published by Astral for each release, confirmed present. Official.

## 6. EditorConfig

**Sources**: [EditorConfig specification](https://spec.editorconfig.org/).

**Configuration file**: `.editorconfig`. Specified properties: `root`, `indent_style`, `indent_size`, `tab_width`, `end_of_line`, `charset`, `trim_trailing_whitespace`, `insert_final_newline`, `max_line_length`, `spelling_language`. Any property accepts `unset`. Section headers are Unix-shell globs; `/` in a glob makes it relative to the `.editorconfig`'s own directory. `root = true` stops the upward search.

**Decision**: commit `.editorconfig` with `root = true`, a `[*]` section setting `charset = utf-8`, `end_of_line = lf`, `insert_final_newline = true`, `trim_trailing_whitespace = true`, `indent_style = space`, `indent_size = 2`, and per-type sections: `[*.{py,sh}] indent_size = 4`, `[*.md] trim_trailing_whitespace = false`, `[Makefile] indent_style = tab`.

**Rationale**: `root = true` is what stops a contributor's home-directory `.editorconfig` from changing the repository's answer — the same reasoning as Principle V. `trim_trailing_whitespace = false` for Markdown is deliberate: two trailing spaces is Markdown's hard line break, and trimming it silently changes rendered output. `indent_size = 4` for shell and Python matches ShellCheck and Ruff conventions rather than fighting them.

**Enforcement**: `.editorconfig` is a declaration that editors read, not a check. FR-003 requires every content standard to be checkable, so the whitespace standard needs a checker of its own: `editorconfig-checker`, whose upstream author publishes `mstruebing/editorconfig-checker`, confirmed present in the registry.

**Alternatives considered**: relying on Prettier and the linters to catch trailing whitespace and missing final newlines. Rejected — that covers only the file types those tools handle, leaving `.shellcheckrc`, `.gitignore`, `LICENSE` and every future plain-text file unchecked, and it would leave `.editorconfig` itself as an unverified claim.

## 7. POSIX shell scripts

**Sources**: [SC2039](https://www.shellcheck.net/wiki/SC2039), ShellCheck optional checks wiki.

**Decisions**:

- `#!/bin/sh` with `set -eu` on the line after. `set -o pipefail` is **not** POSIX and is not used; where a pipeline's failure matters, the pipeline is restructured so the significant command is last, or its status is captured explicitly.
- `command -v` for tool detection, never `which` — `which` is not POSIX and its exit status is unreliable. ShellCheck's `deprecate-which` is enabled to enforce this.
- Every variable expansion quoted. Unquoted expansion under `set -u` is the most common way a POSIX script breaks on a path containing a space.
- `local` is used, with a note: it is not in POSIX, but it is implemented by every shell that matters (dash, ash, ksh, bash, zsh) and ShellCheck under `shell=sh` accepts it. The alternative — global variables in every helper — trades a theoretical portability gain for a real correctness risk.
- `trap` handlers use bare signal names (`INT`, `TERM`, `EXIT`), never the `SIG` prefix.
- No arrays, no `[[ ]]`, no `<<<`, no `${var/…/…}`, no `$'…'`, no `for ((;;))`, no `select`. All are SC2039 findings under `shell=sh`.
- Each script is idempotent and takes no positional arguments other than the documented `--fix` flag, so that FR-003's "no arguments" promise holds.

**Rationale**: the scripts are the one part of this feature that must run everywhere the checks are meant to run, including inside a minimal container where `/bin/sh` is dash or busybox ash. A bashism in the runner would make Principle I unenforceable by the very tooling that enforces it.

## 8. Scope: one declaration, one file list

**Decision**: commit `.lintignore` — one path or glob per line, `#` comments — as the single declaration of what is out of scope. A shared helper turns each line into a git pathspec exclusion and produces the file list every check consumes:

```sh
git ls-files -z --cached --others --exclude-standard -- '*.md' ':(exclude).specify' ':(exclude).claude'
```

Every check then receives explicit paths. No tool's own ignore mechanism is used for scope.

**Rationale**: FR-013a requires all checks to agree on scope, and the only way to guarantee agreement is to compute the list once. Six tools with six ignore syntaxes cannot be kept in agreement by review. The cost is a dependency on `git` for file enumeration — acceptable, since the repository is a git repository by construction, and `git` is not a language runtime or package manager, so FR-010 is untouched. `.prettierignore` still exists, but for a different purpose: it protects a contributor who runs Prettier directly, outside the runner.

**Excluded set**, per FR-013: `.git`, `.specify/` (Spec Kit's generated scripts and templates — content this repository does not own, which the spec's Out of Scope section already excludes), `.claude/logs/`, `.claude/settings.local.json`, `.claude/skills/speckit-*` (generated), `.remember/`, and any dependency directory (`node_modules/`, `.venv/`).

**Alternatives considered**: `gitignore: true` in markdownlint-cli2 plus `ignore-from-file: .gitignore` in yamllint plus `respect-gitignore` in Ruff. Rejected: it conflates "not committed" with "not checked", and it leaves committed-but-generated content such as `.specify/scripts/` in scope.

## 9. Containerised linters, and the two tools with no official image

**Sources**: registry probes run during this phase (all six images confirmed present); [prettier/prettier#15206](https://github.com/prettier/prettier/issues/15206); [cytopia/docker-yamllint](https://github.com/cytopia/docker-yamllint); [pipeline-components/yamllint](https://gitlab.com/pipeline-components/yamllint).

**Resolution order** in every runner: native command on `PATH` first, container second, hard failure third. FR-009 mandates the preference; FR-011 mandates the failure.

**Image assignment**:

| Check      | Image                                                   | Provenance  |
| ---------- | ------------------------------------------------------- | ----------- |
| Markdown   | `davidanson/markdownlint-cli2`                          | tool author |
| Shell      | `koalaman/shellcheck`                                   | tool author |
| Python     | `ghcr.io/astral-sh/ruff`                                | tool vendor |
| Whitespace | `mstruebing/editorconfig-checker`                       | tool author |
| YAML       | `python` (Docker Official Image) + `yamllint==<pinned>` | see below   |
| Formatting | `node` (Docker Official Image) + `prettier@<pinned>`    | see below   |

**The deviation, stated plainly**: Principle III requires the tool's official or upstream-published image. yamllint and Prettier publish none. Three options existed:

1. A third-party image (`pipelinecomponents/yamllint`, `tmknom/prettier`). Rejected: an unaudited third party deciding what runs against this repository is a worse trade than the alternative, and "official" would then be a claim the configuration cannot support.
2. Drop the container fallback for those two checks, requiring a native install. Rejected: it breaks FR-008, which is the whole point of the feature.
3. A Docker Official Image for the language, with the tool's own version pinned in the invocation. **Chosen.**

Option 3 keeps both halves of Principle III's guarantee, in two places instead of one: the image is official and pinned by tag _and_ digest, and the tool version is pinned exactly (`yamllint==X.Y.Z`, `prettier@X.Y.Z`). The residual cost is real and worth naming: those two containers fetch the tool at run time, so they need network access and are slower than the four that do not. Recorded in plan.md's Complexity Tracking.

**Digest pinning**: every image is referenced as `name:tag@sha256:digest`. Digests are resolved during implementation from the live registry — `docker manifest inspect <name>:<tag>` — never copied from documentation or recalled, because a digest recalled is a digest that pins the wrong thing while looking rigorous. A single committed file holds the image references so an upgrade is one visible diff.

**Mount discipline**: check mode mounts the repository **read-only** (`-v "$PWD:/work:ro"`); fix mode mounts it read-write. This makes SC-007 — "running with no arguments leaves the working tree unchanged" — a property of the container boundary rather than a promise about the tool's behaviour.

**Also**: `--rm` always, so runs leave no containers behind; `-u` with the calling user's id in fix mode, so rewritten files are not left owned by root.

## 10. Claude Code plugin structure

**Sources**: [Claude Code plugins reference](https://code.claude.com/docs/en/plugins-reference), [Claude Code best practices](https://code.claude.com/docs/en/best-practices).

**Manifest**: `.claude-plugin/plugin.json`. `name` is the only required field — a unique kebab-case identifier. Optional fields include `displayName`, `version`, `description`, `author` (`{name, email, url}`), `homepage`, `repository`, `license`, `keywords`, `defaultEnabled`, and the component-path fields `skills`, `commands`, `agents`, `workflows`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`.

**Auto-discovered layout**: `skills/<name>/SKILL.md`, `commands/*.md`, `agents/*.md`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `bin/` (added to the Bash tool's `PATH`). Path fields **replace** the default directory for `commands`, `agents`, `workflows`, `outputStyles`; `skills` **adds** to it. `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` and `${CLAUDE_PROJECT_DIR}` are available for substitution.

**Decision**: commit `.claude-plugin/plugin.json` with `name`, `displayName`, `description`, `version`, `author`, `homepage`, `repository`, `license`, `keywords`. Declare **no** component-path fields and create **no** component directories.

**Rationale**: the repository ships no commands, agents, skills, hooks or MCP servers of its own, and the spec's Out of Scope section says none are to be invented for this feature. A declared path to an empty directory is worse than no declaration: auto-discovery already handles the directories once they exist, and a `commands` field pointing at nothing replaces the default rather than extending it.

**`marketplace.json` is a different file** with a different purpose — it lives in a marketplace entry, carries a `source` describing how to fetch the plugin, and overrides `plugin.json` values for that one marketplace. Out of scope per the spec.

**The `.claude/` collision, and why there is none**: this repository's `.claude/` directory holds _consumer_ state — `settings.local.json`, hook logs, the Spec Kit skills generated in Step 0 of this run. The plugin's own content would live in top-level `skills/`, `commands/`, `agents/`. The two do not overlap, and `.claude/skills/speckit-*` must not be vendored into the plugin: it is Spec Kit's generated output, not this repository's authored content.

## 11. Working effectively with Claude Code

**Source**: [Claude Code best practices](https://code.claude.com/docs/en/best-practices).

Recorded because it shaped two decisions in this plan, not as general reading:

- **"Give Claude a way to verify its work."** The documentation is explicit that a check producing a pass or fail is what closes the agentic loop, and names a linter as one such check. This is the strongest argument for the aggregate entry point being a single command with a meaningful exit status — it is the artifact that makes the loop close, so its exit status has to mean something. It is also why FR-005a matters: a fix run that exits non-zero after succeeding would poison exactly this loop.
- **"Keep CLAUDE.md concise."** The documented test is _"Would removing this cause Claude to make mistakes?"_, with the stated failure mode that a bloated file causes Claude to ignore the instructions in it. Two consequences here: the `CLAUDE.md` written in Step 2b stays short and points at `AGENTS.md` and `LEAN-CTX.md` as read-on-demand rather than importing them; and the check commands, once they exist, are the kind of content the documentation puts in the **include** column — "Bash commands Claude can't guess".
- Also relevant, and deliberately not acted on: hooks are described as deterministic where `CLAUDE.md` is advisory, which makes a `PostToolUse` hook running the relevant check the natural next step after this feature. Out of scope here; worth a follow-up.

## 12. Corrections made during implementation

Six decisions in sections 1-11 turned out to be wrong, and were caught by the checks themselves on their first run. Recorded here because a configuration whose history is invisible gets "corrected" back.

| What was wrong                                                                                                  | What it is now                                  | How it surfaced                                                                                                                                                                                                                                                                                                           |
| --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.editorconfig` set `indent_style = space` for `*.sh` (section 6) while the runners are written with tabs       | `[*.{py,pyi}]` keeps spaces; `[*.sh]` uses tabs | The whitespace check reported 36 violations across every runner. Tabs win on merit, not convenience: `<<-` heredocs strip leading **tabs and nothing else**, so a space-indented script cannot indent a heredoc body at all. It is also shfmt's default, so a contributor running that formatter will not fight the file. |
| `.editorconfig` applied `indent_size = 2` to `*.md`                                                             | `indent_size = unset` for `*.md`                | The check flagged an aligned ASCII diagram inside a fenced block in `data-model.md`. Markdown's meaningful indentation does not follow one multiple: nested lists step by the parent marker's width, fenced blocks carry the enclosed language's indentation, and aligned diagrams line up on content.                    |
| `MD036` (no-emphasis-as-heading) left enabled (section 1)                                                       | disabled, with the reason in the config         | It failed every spec document. Those documents use bold inline labels -- **Guarantees**, **Validation rules** -- to mark parts of a subsection; promoting each to a real heading would pollute the outline with entries nobody navigates to.                                                                              |
| `.lintignore` excluded `.claude/logs`, `.claude/settings.local.json` and `.claude/skills` piecemeal (section 8) | excludes `.claude` wholesale                    | A scratch file at `.claude/prompt.md` was in scope and failed MD041. `.claude/` is consumer-side state in its entirety; the plugin's authored content lives in top-level `skills/`, `commands/` and `agents/` per section 10, so nothing authored is lost.                                                                |
| `LEAN-CTX.md` was in scope                                                                                      | excluded                                        | It failed MD041 and MD032, and it carries its own `lean-ctx-owned` marker: it is generated by that tool, so edits made to satisfy a linter would be overwritten on its next write.                                                                                                                                        |
| `usage()` printed a space-indented option list                                                                  | flush-left                                      | The whitespace check flagged the heredoc body. Those leading spaces are printed output, not code indentation, but no whitespace checker can tell the difference -- and exempting shell from the standard for the one file that failed it would have been the wrong trade.                                                 |

One further departure, from plan.md rather than from this file: **the self-test's fixtures live in `.lint-selftest-tmp/` at the repository root, not in `$(mktemp -d)`.** The container path has to mount the fixture directory, and on Docker Desktop for macOS the default `TMPDIR` lives under `/var/folders`, which is not shared with the VM -- the mount then succeeds and arrives _empty_, the tool reports zero problems, and the self-test cannot distinguish that from a real pass. Verified directly: a marker file in a `mktemp -d` directory was not visible inside a container. The repository directory is mountable by definition, since every runner already mounts it. The fixture directory is in **both** `.gitignore` and `.lintignore`, and both are required: the first keeps a deliberately broken file from being committed, the second keeps the aggregate check from ever seeing it. Building fixtures inside the container instead was tried and rejected -- the ShellCheck and Ruff images ship no shell, so `--entrypoint sh` exits 127.

The same class of bug then appeared a second time, in the fixture directory that was supposed to have
solved it, and this one was caught by the self-test rather than reasoned about in advance. Running the
container path repeatedly, the markdown check reported `DID NOT FAIL on a bad fixture (exit 0)` on two
runs out of three, while the identical `docker run` issued by hand against a settled directory failed
correctly four times out of four. The difference was the `rm -rf "$WORK"` followed immediately by
`mkdir -p "$WORK"` at the top of the script: on Docker Desktop for macOS a directory recreated moments
before it is mounted can arrive in the VM stale and empty, and `markdownlint-cli2` handed a filename it
cannot see exits `0`. So the self-test was not flaky about a broken check -- it was reporting a verdict
about the mount and attributing it to the tool.

The first fix was a gate: `require_visible` wrote a sentinel into the fixture directory and required a
container to see it before any container verdict was trusted. **It was not enough, and the way it
failed is the useful part of this finding.** Running the native self-test immediately before the
container one reproduced `markdown: DID NOT FAIL` three times out of three, with the sentinel gate
passing every time. `docker run --entrypoint ls` against the same mount printed `total 0`: the
directory was empty inside the VM while the sentinel was visible. Creating a new name forces a refresh
for that name alone, so a sentinel written after the first mount appeared while fixtures written before
it stayed invisible. A sentinel proves a sentinel is visible and nothing else.

Two changes, addressing the cause and the detection separately:

1. **The fixture path is never reused.** `WORK` is now `.lint-selftest-tmp/run-$$`, a fresh
   subdirectory per run, and the parent is created if absent rather than removed and recreated.
   Recreating one fixed path is what produced the stale answer; a path the VM has never seen cannot be
   stale. Reproduced 3 of 3 before, 0 of 5 after.
2. **The gate counts files instead of probing a sentinel.** `require_visible` compares
   `find -maxdepth 1 -type f` inside the container against the same count on the host, retrying for
   ten attempts and calling `die` if they never agree. That asks the question that matters. The
   runners' own captured `*.out` files are excluded, because the redirect creates them at the moment
   docker starts and counting them would compare two moving numbers.

A third change came out of the same investigation and is a fragility in the test rather than a mount
problem. The three formatting fixtures were each checked in their own container, so each repeated the
npm install of Prettier and its two plugins; one transient registry failure exits `1` with npm's error
text, which `verdict` correctly reports as "exit 1 but the output never names `bad-fmt.sh`" -- a
failing self-test about a working check. All three now go through one invocation, with one assertion
per fixture, so a fixture still has to be named individually but the install happens once.

Verified after all three: the full `lint.sh` and `selftest.sh` matrix on both the native and
`LINT_FORCE_CONTAINER=1` paths, five consecutive sequences, all twenty runs at exit `0`.

One file the plan did not anticipate: **`.claude-plugin/marketplace.json`**. Section 10 established
`plugin.json` as the manifest Claude Code requires, which is correct for a plugin that is already
resolvable, but `claude plugin install` takes a _name_ resolved through a configured marketplace, not
a path -- so a local repository cannot be installed until it is registered as a marketplace, and
`marketplace add` reads a separate manifest. `claude plugin marketplace add ./` failed with
`Marketplace file not found at .../.claude-plugin/marketplace.json` until that file existed. Two
smaller surprises came with it: the source argument must be written `./`, since a bare `.` is
rejected as `Invalid marketplace source format`; and the CLI printed the format error while still
exiting `0`, so a script that trusts the exit status alone would read that failure as a success. The
marketplace manifest names the owner by name and GitHub URL only, matching `plugin.json` and carrying
no address.

Two smaller findings, recorded but not acted on: the `v3.11.2` editorconfig-checker image self-reports `v3.11.1` (an upstream version-string discrepancy, not something this repository can fix), and `npx` writes an npm upgrade notice to stderr on the container format path (noise, and not a verdict difference).

## 13. Per-check ignore declarations (amendment, FR-013a / FR-013c)

FR-013a now requires each check to declare its own skipped paths. `.lintignore` is unchanged and still
drives the runner's file list, so this section is about what a contributor gets when they invoke a tool
**by hand**, outside `scripts/`. Every mechanism below was verified by running the tool against a
fixture tree with a `sub/` directory holding one deliberately bad file per content kind.

| Check                | Mechanism                                                                 | Verified behaviour                                                                                                                                                                                                                                                     |
| -------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| markdownlint-cli2    | `ignores` array in `.markdownlint-cli2.jsonc`                             | `"ignores": ["sub/**"]` printed `Finding: **/*.md !sub/**` and linted 1 of 2 files. Per the user's instruction this is the `ignores` property, **not** a separate `.markdownlintignore`                                                                                |
| yamllint             | `ignore` key in `.yamllint.yml`, block scalar of gitignore-style patterns | `ignore: \|` with `sub/` skipped `sub/bad.yml` entirely                                                                                                                                                                                                                |
| Ruff                 | `exclude` array in `ruff.toml`                                            | `exclude = ["sub"]` skipped `sub/bad.py`; `All checks passed!`                                                                                                                                                                                                         |
| Prettier             | `.prettierignore`                                                         | Already present; gitignore syntax                                                                                                                                                                                                                                      |
| editorconfig-checker | `Exclude` array in `.editorconfig-checker.json`                           | Config generated with `-init`. `Exclude` holds **regexes**, not globs -- combine with `\|`. The help text states the configured excludes still apply when explicit files are passed, which is what makes this compose with the runner's file list rather than fight it |
| ShellCheck           | **none**                                                                  | See below                                                                                                                                                                                                                                                              |

**ShellCheck has no path-exclusion directive, and this is FR-013c's case.** Verified against
`shellcheck --version 0.11.0`, `--help`, and the `RC FILES` section of the man page. `.shellcheckrc`
accepts `shell`, `severity`, `source-path`, `external-sources`, `enable` and `disable` -- all of them
directives about _rules and interpretation_, none about which files to visit. The `-e/--exclude` flag
excludes **warning codes**, not paths; a reader who assumes otherwise from its name gets silent
under-checking rather than an error.

Consequence, spelled out as FR-013c requires: for the shell check, and only for it, the scope a
by-hand invocation sees is whatever the caller passes on the command line. `scripts/lint-shell.sh`
passes the `.lintignore`-derived list, so the runner is unaffected; a contributor running
`shellcheck **/*.sh` by hand may check files the repository excludes. Nothing in the tool can prevent
that. It is recorded rather than worked around because the alternatives are worse: a wrapper that
filters ShellCheck's input would be a second scope source with no configuration file behind it, which
is the failure FR-013b exists to catch.

**Non-obvious property of the whole arrangement.** Six declarations can disagree. Under the previous
FR-013a they could not, because there was one. That trade is the point of FR-013b, and it is why the
scope-agreement comparison has to exist as a runnable check rather than a claim in this document.

## 14. Prettier: which keys are decisions and which were restated defaults (FR-019)

Defaults confirmed against Prettier's own documentation via Context7 (`prettier.io/docs/options`,
`prettier.io/docs/configuration`) at the pinned version 3.9.6. The configuration page publishes an
`.editorconfig` equivalent of Prettier's defaults, which pins three of these directly:
`end_of_line = lf`, `indent_size = 2`, `max_line_length = 80`.

| Key             | Documented default      | Was in `.prettierrc.json`                   | Verdict                                                                                                                                                               |
| --------------- | ----------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `endOfLine`     | `"lf"`                  | `"lf"`                                      | **Remove** -- restated default                                                                                                                                        |
| `proseWrap`     | `"preserve"`            | `"preserve"`                                | **Remove** -- restated default. Docs: "The default behavior is 'preserve' to ensure compatibility with line-break sensitive renderers"                                |
| `tabWidth`      | `2`                     | `2`, inside the `*.json`/`*.jsonc` override | **Remove** -- restated default, and it was the override's only option, so the override goes with it                                                                   |
| `printWidth`    | `80`                    | `100`                                       | **Keep** -- a real decision, reason already in section 4                                                                                                              |
| `trailingComma` | `"all"` since 3.0.0     | absent                                      | **Add `"none"`** -- confirmed non-default                                                                                                                             |
| `singleQuote`   | `false` (double quotes) | absent                                      | **Add `true`** -- confirmed non-default. Docs' Rationale page: on a tie or with no quotes present Prettier "defaults to double quotes, though this can be configured" |

Relied-on defaults, recorded here because the amended Principle V requires a default to be _declared_
somewhere even when it is not restated in the configuration file: `endOfLine: "lf"`, `proseWrap:
"preserve"`, `tabWidth: 2`, and `jsxSingleQuote: false`, `semi: true`, `bracketSpacing: true`,
`arrowParens: "always"`, `quoteProps: "as-needed"`, `embeddedLanguageFormatting: "auto"` for the
options this repository never sets. All of them are guaranteed by the exact version pin, which is the
condition the principle attaches.

One thing worth stating because it looks like a mistake otherwise: **`singleQuote` has no effect on
any file this repository currently holds.** JSON mandates double quotes and Prettier ignores the option
there; Markdown and YAML are unaffected in practice. It is set because FR-020 fixes it as a repository
style decision for the formats that do honour it -- the same forward-looking reasoning as the
markup-tree standard in FR-021.

### The four `parser` declarations in `overrides` are a measured exception to FR-019

Measured, not assumed. With the whole `overrides` array deleted, every content kind still resolved:
Markdown, YAML and XML formatted identically, and `*.sh` **and** `*.bash` both reached
`prettier-plugin-sh` -- the plugin registers those extensions itself, so extension inference alone
produces the same parser the overrides name. The verdict over the repository was unchanged, 14 files
either way.

So `"parser": "markdown"` for `*.md`, `"parser": "yaml"` for `*.yml`, `"parser": "xml"` for `*.xml`
and `"parser": "sh"` for `*.sh` are, strictly, restatements -- the thing FR-019 exists to remove.
They are kept anyway, and FR-019 was narrowed rather than quietly violated:

- `parser` is not an option with a default _value_. It is the binding between a content kind and the
  code that formats it, resolved per file from a plugin's own extension registry. Omitting it does not
  fall back to a documented default; it defers to a registry that is not in this repository.
- The four kinds FR-021 names are then visible in the file that governs them. Without the overrides, a
  reader of `.prettierrc.json` sees two plugin names and has to consult two npm packages' registries to
  learn that shell scripts are covered at all.
- `xmlWhitespaceSensitivity: "ignore"` is genuinely non-default (the plugin's default is `"strict"`)
  and has to live in an override, so the XML override exists regardless. Three siblings that spell out
  the same binding read better than one that appears arbitrary.

FR-019's omission rule therefore applies to formatting option _values_, and SC-010 counts those.
`overrides[].files` and `overrides[].options.parser` are outside it. Nothing else in
`.prettierrc.json` equals a default.

## 15. Prettier plugins for markup-tree documents and shell scripts (FR-021, FR-023)

Resolved from the npm registry rather than from memory:

| Plugin                 | Version | Peer requirement  | Notes                                                                                        |
| ---------------------- | ------- | ----------------- | -------------------------------------------------------------------------------------------- |
| `@prettier/plugin-xml` | 3.4.2   | `prettier@^3.0.0` | Official Prettier-org plugin                                                                 |
| `prettier-plugin-sh`   | 0.19.0  | `prettier@^3.6.0` | Depends on `sh-syntax` and `@reteps/dockerfmt`; wraps `mvdan/sh`, the same engine as `shfmt` |

The pinned Prettier is 3.9.6, which satisfies both peers. Markdown and YAML need **no** plugin --
Prettier's core handles both -- so their overrides configure core options only, and only XML and shell
depend on an add-on.

**Container path.** One invocation installs all three, so a run never fetches plugins separately from
the tool they must match:

```sh
npx --yes --package prettier@3.9.6 \
          --package @prettier/plugin-xml@3.4.2 \
          --package prettier-plugin-sh@0.19.0 \
          prettier --check <files>
```

**Native path, and FR-023 as clarified.** Principle I is unamended: no install is a precondition on
either path. A contributor with `prettier` on `PATH` but without a plugin is the normal case, not an
error. The runner resolves each declared plugin and prints which ones it found; a content kind whose
plugin is missing is handed to the container path, where the plugin is pinned. That is the clarified
FR-023 -- treat an absent add-on exactly as an absent tool -- and it is the only option of the three
that preserves FR-008. Warn-and-continue would let two machines reach different verdicts on the same
file, and hard failure would block a native run over a content kind the contributor may not even have.
If neither the plugin nor the container is reachable, FR-011's existing hard failure applies unchanged.

## 16. Which formatting-adjacent rules leave the linting standards (FR-022)

FR-022's hazard is two tools **rewriting** the same file, not two tools observing it. Rules that
Prettier does not itself rewrite therefore stay where they are; disabling them would drop a check that
nothing replaces.

**Markdown.** markdownlint ships the answer: `markdownlint/style/prettier.json`, whose own comment
reads "Disables rules that may conflict with Prettier". Counted from the file installed with
markdownlint-cli2 0.23.2, it holds 24 keys: the `comment` key just quoted, which is metadata rather
than a rule, and **23 rules**. 22 of those are inlined here; the 23rd is `line-length`, which this
repository already disables for its own reason (section 4: one line per paragraph). So the coverage is
complete, and the number to look for in `.markdownlint-cli2.jsonc` is 22, not 23. The 22 are:
`blanks-around-fences`,
`blanks-around-headings`, `blanks-around-lists`, `code-fence-style`, `emphasis-style`,
`heading-start-left`, `heading-style`, `hr-style`, `line-length`, `list-indent`, `list-marker-space`,
`no-blanks-blockquote`, `no-hard-tabs`, `no-missing-space-atx`, `no-missing-space-closed-atx`,
`no-multiple-blanks`, `no-multiple-space-atx`, `no-multiple-space-blockquote`,
`no-multiple-space-closed-atx`, `no-trailing-spaces`, `ol-prefix`, `strong-style`, `ul-indent`.

Decision: **inline those 23 entries** in `.markdownlint-cli2.jsonc` with a comment citing the upstream
file, rather than using `"extends": "markdownlint/style/prettier"`. The `extends` form resolves through
Node's module lookup from the config file's directory, and this repository has no `node_modules`; it
would work where markdownlint-cli2 happens to be installed as a local dependency and fail elsewhere,
which is precisely the machine-dependent behaviour Principle V forbids. Inlining costs one block and
works identically on the native and container paths. `line-length` was already disabled for its own
reason (section 1); it stays disabled and is now over-determined.

Note what upstream does **not** disable, and neither do we: `ul-style`, `single-trailing-newline`,
`code-block-style`, `table-column-style` and the other table rules. markdownlint's maintainer judges
these not to conflict, and section 12 already records `table-column-style` catching a real
inconsistency in `plan.md`.

**YAML.** yamllint has no equivalent preset, so its `conf/default.yaml` was read directly and each rule
classified by whether Prettier rewrites that property:

Leaves yamllint (Prettier rewrites it): `braces`, `brackets`, `colons`, `commas`, `hyphens`,
`indentation`, `empty-lines`, `new-line-at-end-of-file`, `new-lines`, `trailing-spaces`. Ten rules.

Stays in yamllint (Prettier does not rewrite it): `key-duplicates` and `anchors`, which are semantic
and which Prettier does not detect at all; `truthy`, kept at error level with `check-keys: false` per
section 2; and -- the two that look like they should go and must not -- `comments` and
`comments-indentation`. Prettier preserves YAML comments and does not enforce a space after `#` or a
minimum gap before an inline comment, so those two rules govern properties nothing else checks.
`line-length` and `document-start` were already disabled for their own reasons.

## 17. Spec Kit extensions: catalogs, provenance and effects (FR-024, FR-026)

`specify extension search` classifies each catalog. The `default` catalog is installable by name; the
`community` catalog is **discovery-only**, and the tool states plainly that this flag _is_ the vetting
boundary: "Don't flip a discovery-only catalog to install_allowed."

| ID              | Version installed | Source                                      | Effect                                | Provenance                                                                                                                  |
| --------------- | ----------------- | ------------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `agent-context` | 1.0.0             | `default` catalog, author `spec-kit-core`   | writes agent instruction files        | `specify extension add agent-context`                                                                                       |
| `assess`        | 1.0.0             | `default` catalog, `spec-kit-core`          | writes `.specify/assessments/<slug>/` | `specify extension add assess`                                                                                              |
| `bug`           | 1.0.0             | `default` catalog, `spec-kit-core`          | writes `.specify/bugs/<slug>/`        | `specify extension add bug`                                                                                                 |
| `git`           | 1.0.0             | `default` catalog, `spec-kit-core`          | creates branches, commits             | `specify extension add git`                                                                                                 |
| `superb`        | **1.9.0**         | community, `RbBtSn0w/spec-kit-extensions`   | **read-write**, 7 commands, 2 hooks   | `--from https://github.com/RbBtSn0w/spec-kit-extensions/releases/download/superpowers-bridge-v1.9.0/superpowers-bridge.zip` |
| `token-budget`  | **1.1.0**         | community, `tinesoft/spec-kit-token-budget` | **read-write**, 5 commands, 6 hooks   | `--from https://github.com/tinesoft/spec-kit-token-budget/archive/refs/tags/v1.1.0.tar.gz`                                  |

Two discrepancies between the catalog and upstream, both found by querying the repositories rather
than trusting the catalog entry. The catalog lists `superb` at v1.6.0; its latest release is
`superpowers-bridge-v1.9.0`, carrying a single asset `superpowers-bridge.zip`. The catalog lists
`token-budget` at v1.0.1; its latest release is v1.1.0 -- and **none of its releases publish an asset
at all**, so the archive URL has to be GitHub's generated tag tarball rather than a release artifact.
That is a weaker pin than a published asset: a re-tagged release would change the bytes at the same
URL. It is recorded here as the provenance FR-026 requires, including that weakness.

The command and hook counts above are the installed ones, read from `specify extension list` after
installing. They are a third discrepancy: the catalog advertises 10 commands and 5 hooks for `superb`
and 4 commands for `token-budget`, where v1.9.0 registers 7 commands and 2 hooks and v1.1.0 registers
5 commands. A catalog entry is not evidence of what an extension does; the manifest on disk is.

The user was shown the vetting boundary, the read-write effect, and the 12 commands and 8 hooks these
two add to every future phase, and chose to install all six. That decision is recorded in the run's
conflict register as K4.

## 18. Hook execution order (FR-025, FR-025a)

Read from the installed `specify` 1.0.2.dev0 rather than inferred. `ExtensionManager` /
`HookExecutor` in `specify_cli/extensions/__init__.py`:

- `.specify/extensions.yml` holds `hooks.<event>` as a **list** of entries, each with `extension`,
  `command`, `enabled`, `optional`, `priority`, `prompt`, `description`, `condition`.
- `get_hooks_for_event()` filters to `enabled` and returns `sorted(..., key=priority)`. Docstring:
  "Lower `priority` runs first. Ties keep insertion order via a stable sort."
- `normalize_priority()` coerces to an integer `>= 1`; anything missing, non-numeric, boolean, zero or
  negative falls back to `DEFAULT_HOOK_PRIORITY`, which is **10**.

Three findings that change the design:

1. **`specify extension add --priority` and `specify extension set-priority` do not set hook order.**
   Both set the _extension's_ resolution priority -- which template or command wins when two
   extensions provide the same one. Hook order is the per-hook `priority` inside
   `.specify/extensions.yml`. Using `set-priority` and expecting the hooks to reorder would produce no
   change and no error.
2. **No extension in the set declares a hook priority.** Every hook therefore registers at the default
   10, every hook at a given event ties, and the tie-break is insertion order -- which is install
   order. That is exactly the discovery-order dependence FR-025 forbids, and it is the reason this
   requirement exists rather than being satisfied out of the box.
3. **`register_hooks()` purges and re-adds an extension's entries from its manifest on every
   install.** Hand-set priorities in `extensions.yml` are therefore lost on reinstall, update, or
   `--force`. This must be stated where the ranks live, or the first `specify extension update`
   silently restores tie-on-10.

**The principle, written down beside the numbers** (FR-025a): lower number runs first; hooks that only
observe run before hooks that modify the repository; the hook that commits runs last of all, because
it must capture what every earlier hook wrote.

| Rank | Extension       | Why this rank                                                                                                              |
| ---- | --------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 10   | `superb`        | Evidence-first trust gates. Observational, and a gate is worthless if it runs after the thing it gates                     |
| 20   | `token-budget`  | Reports usage and compacts artifacts. Reads before the mutating hooks, and its in-place compaction must precede any commit |
| 30   | `agent-context` | Rewrites the agent instruction file at `after_specify` and `after_plan`. First genuinely mutating hook                     |
| 40   | `assess`, `bug` | Write their own artifacts under `.specify/`, and only on their own commands                                                |
| 50   | `git`           | Commits. Last unconditionally, so the commit contains what ranks 10-40 produced                                            |

Gaps of ten leave room for a later extension to be placed without renumbering. The two mandatory
`git` hooks are worth flagging: `before_constitution` runs `speckit.git.initialize` and
`before_specify` runs `speckit.git.feature`, both `optional: false`. Installing `git` therefore changes
how every future run of those two phases behaves -- and it closes the gap that forced the v1.1.0
constitution amendment, since branch creation now exists as an installed capability rather than as an
absent optional extension.

## 19. Version-control disposition of extension-created paths (FR-018, FR-027)

Every path the six extensions create, classified. The rule from the clarification: per-item artifacts
are project history and are committed; machine-local run state is not.

| Path                                                                   | Created by          | Disposition | Reason                                                                                                                                                                                      |
| ---------------------------------------------------------------------- | ------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.specify/extensions.yml`                                              | all six, on install | **commit**  | Principle V: it holds the hook ranks, so it is configuration, not state                                                                                                                     |
| `.specify/extensions/<id>/`                                            | all six, on install | **commit**  | The installed extension's own files, including its manifest and commands. Committing them is what makes a clone reproduce the run                                                           |
| `.specify/assessments/<slug>/`                                         | `assess`            | **commit**  | FR-027. A killed idea's reasoning is the record that cannot be reconstructed later                                                                                                          |
| `.specify/bugs/<slug>/`                                                | `bug`               | **commit**  | FR-027, same reasoning                                                                                                                                                                      |
| `CLAUDE.md`, other agent instruction files                             | `agent-context`     | **commit**  | Already committed; the extension edits an existing tracked file                                                                                                                             |
| `.specify/.speckit-run-state.json`, `.specify/.speckit-dirty-snapshot` | the run skill       | **ignore**  | Already ignored. Machine-local bookkeeping                                                                                                                                                  |
| `.specify/feature.json`                                                | `specify` core      | **ignore**  | Already ignored. A per-checkout pointer to the active feature                                                                                                                               |
| token-budget report output                                             | `token-budget`      | **ignore**  | A measurement of one run on one machine, not a decision. Exact path confirmed at install time                                                                                               |
| `<artifact>.full.md`                                                   | `token-budget`      | **ignore**  | A restore point for `/speckit.token-budget.restore`: one machine's pre-compaction copy of a file that is itself committed                                                                   |
| `.specify/extensions/.cache/`                                          | `specify` core      | **ignore**  | A 212 KB snapshot of the upstream catalog with a `cached_at` timestamp. Refetched on demand and stale as soon as upstream publishes                                                         |
| `.specify/extensions/.registry`                                        | all six, on install | **commit**  | Records which extensions are installed at which version and manifest hash -- exactly what another checkout needs to reproduce this one. Deliberately NOT lumped in with `.cache/` beside it |

Committing `.specify/assessments/` and `.specify/bugs/` puts them in lint scope, which is intended:
FR-027 says so explicitly, and it means those documents are held to the same Markdown standard as
every other document here. `.lintignore` currently excludes `.specify` wholesale, so that exclusion
has to narrow -- the generated scripts and templates stay excluded, the human-authored artifacts do
not.

## 20. Change-proposal template mechanics (amendment, FR-028, FR-032, FR-033)

Fetched from GitHub's own documentation rather than recalled, because the whole design turns on one
behaviour that is easy to get backwards.

**Supported locations.** A single template may live at `pull_request_template.md` in the repository
root, at `docs/pull_request_template.md`, or at `.github/pull_request_template.md`. Multiple templates
live in a `PULL_REQUEST_TEMPLATE/` subdirectory of any of those three, which the documentation writes
in upper case while writing the single file in lower case. Templates take effect only once merged:
"Templates are available to collaborators when they are merged into the repository's default branch."

**The decisive asymmetry.** Only the single file is applied automatically. The directory form is
reachable only through a query parameter: "You can create a _PULL_REQUEST_TEMPLATE/_ subdirectory in
any of the supported folders to contain multiple pull request templates, and use the `template` query
parameter to specify the template that will fill the pull request body." The parameter takes the
filename including its `.md` extension, matching the issue-template form documented as
`?template=issue_template.md`.

**Decision**: `.github/pull_request_template.md` is the general structure; `.github/PULL_REQUEST_TEMPLATE/`
holds the two specialised ones.

**Rationale**: a repository with only a directory gets an **empty** default proposal body, because
nothing selects a template on the author's behalf. Everything required has to sit in the single file.
This is the mechanical fact behind FR-033, and FR-033 exists because the requirement would otherwise be
satisfiable by a layout that silently drops it.

**Alternatives rejected**: the repository root and `docs/` are both supported and both were rejected --
`.github/` is where a reader looks for repository metadata, and the root is already carrying eleven
configuration files. A directory with no single file was rejected on the finding above.

### Issue forms are not available here, and that is documented rather than assumed

**Decision**: Markdown only. No YAML, no structured fields, no required-field validation.

**Rationale**: quoted from GitHub's issue-forms syntax page: "Issue forms are not supported for pull
requests." The `config.yml` chooser is likewise documented for `.github/ISSUE_TEMPLATE` alone. So the
form-based features -- typed inputs, a `required: true` flag, a dropdown -- are simply unavailable, and
every requirement in the amendment had to be designed for prose an author can freely edit or delete.
That constraint is the reason spec.md's Assumptions section says these structures are advisory in
enforcement and mandatory in content: it is a platform limit, not a decision.

**Alternatives rejected**: none available. This was checked rather than assumed precisely because a
design that assumed forms would have produced requirements nothing could satisfy.

## 21. What a proposal description carries: adopted and declined (FR-029, FR-030, FR-031, FR-034)

GitHub's own best-practice guidance for pull requests makes six recommendations. Each was taken as a
candidate and decided on, rather than adopted wholesale:

| Recommendation                                                                                                                       | Disposition         | Reason                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------ | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Provide context and guidance" -- explain "why the change is needed, what changed, and where reviewers should pay special attention" | **adopt**           | This is FR-029 almost verbatim, and the third clause -- where to look -- is worth more than the first two for a reviewer arriving cold                                                                                                                   |
| "Review your own pull request first", including "making sure relevant builds or tests have run"                                      | **adopt**           | Already an obligation here, at `constitution.md:167`, which is stronger than a recommendation. FR-030 carries it                                                                                                                                         |
| "Write small pull requests"                                                                                                          | **decline**         | Not a property of the description, so a template cannot record or check it. A checkbox asserting a change is small measures nothing                                                                                                                      |
| "Link to related issues or projects", with closing keywords                                                                          | **decline for now** | This repository has no issues and no project board. A field nobody can fill is a field that trains authors to skip fields                                                                                                                                |
| "Highlight the status with labels"                                                                                                   | **decline**         | Labels are routing, and spec.md's Out of Scope excludes routing a proposal                                                                                                                                                                               |
| "Review for security"                                                                                                                | **partial**         | Not a separate section. The reviewer section names the six principles, and where a change touches the checking machinery the specialised structure asks how it was proven still able to fail -- which is this repository's actual security-adjacent risk |

**Decision on agent authorship (FR-034)**: the general structure asks whether a coding agent produced
the change and, if so, for a reference to the session.

**Rationale**: this repository's own history is agent-produced, and the commits already carry a
`Claude-Session:` trailer, so the information exists either way -- but in the commit trailers, where a
reviewer has to know to look. Surfacing it in the proposal body puts it where the reviewer already is.
What a reviewer gains is not the authorship label but the ability to see what the author was actually
asked to do, which the difference itself never shows.

**Alternatives rejected**: asking for the fact without the reference, which leaves the reviewer knowing
there is context and not where it is; and asking for nothing, on the argument that a diff is reviewed
on its merits regardless -- true, and it still leaves the reviewer unable to distinguish a deliberate
choice from an artefact of how the work was requested.

## 22. How the templates survive this repository's own checks (FR-037)

Every finding here is from running the committed configuration against candidate content, not from
reading the configuration and reasoning about it.

| Concern                                                                             | Result                                                                      | Consequence for the design                                                                                         |
| ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Prettier, on HTML comments, task lists, blockquotes and an em-dash attribution line | **no rewrite**                                                              | The template shapes are stable under formatting; no content had to change                                          |
| **MD041** `first-line-heading`                                                      | **fails** a template that opens with an HTML comment then `## What changed` | Every template opens with a level-one heading. This is a design change, not a relaxed rule                         |
| **MD024** `no-duplicate-heading`, configured `siblings_only: true`                  | passes across files, fails within one                                       | The three templates may all use `## What changed`; a single template may not repeat a heading at one level         |
| `scripts/lint-scope.sh` with `.github/` present                                     | **passes**, five declarations agreeing, shell unverifiable                  | Nothing excludes `.github/`, so the files enter scope with **0 declarations changed**, which is what SC-020 counts |
| `scripts/lint.sh` end to end with the probe files in place                          | **exit 0**                                                                  | Verified before any template was written                                                                           |

The MD041 finding is worth stating as a trade-off rather than a fix. A level-one heading in a proposal
body sits under the proposal's own title field, so the title is effectively stated twice. The
alternative was disabling MD041 for `.github/`, which the amendment forbids: FR-037 says a structure
that has to be excluded from a check is written in the wrong form. The heading also does useful work --
it names which of the three structures the author is looking at, which is otherwise invisible once the
content is in the proposal body.

## 23. Citation-staleness detection (FR-036)

FR-036 required a mismatch to be "detectable by running something", which the Phase 4 checklist flagged
as unverifiable as written (CHK010, CHK011). Resolved here with a concrete mechanism.

**Decision**: a new check, `scripts/lint-citations.sh`, registered in `scripts/lint.sh`'s `CHECKS`
immediately after `scope`. It needs no tool and no container. Each citation in a template is marked by
an HTML comment naming the cited file, followed by a blockquote:

```markdown
<!-- cite: .specify/memory/constitution.md -->

> Before a change is proposed for review, the aggregate quality check MUST have been run and MUST have passed.
```

The check extracts each marker's blockquote, joins it to one line, and requires it to appear verbatim in
the cited file after whitespace normalisation. Exit `0` when every citation matches, `1` naming each
that does not, with the same statuses as every other check. No `--fix`: which of the two texts is wrong
is a judgement, so it reports and leaves both alone.

**Rationale**: whitespace normalisation is the load-bearing part, and it was measured rather than
assumed. `constitution.md` hard-wraps its prose, so the sentence FR-030 quotes is split across
`constitution.md:167` and `:168`. A naive `grep -F` for the one-line quotation returns **0 matches** --
the check would fail on a citation that is perfectly accurate. Flattening the cited file with
`tr '
' ' '` and collapsing runs of spaces makes both target sentences match, and a negative control --
the same sentence with `MUST` changed to `SHOULD` -- correctly does not match. All three results were
run before this was written down.

**Alternatives rejected**: a markdownlint custom rule, which resolves through Node module lookup and
would work on some machines and not others -- the same reasoning that kept the Prettier preset inline in
section 16. Folding the comparison into `scripts/lint-scope.sh`, which verifies agreement among the six
path declarations and would become two unrelated checks under one name. Requiring quotations to be
single-line in the constitution, which is a worse document to make a checker's life easier.

### Whether a prose artifact can be self-tested, and on what terms

**Decision**: yes, and `scripts/selftest.sh` gains a fixture for it. What is tested is the citation's
fidelity -- a template whose quotation has been altered must be rejected and named. What is **not**
tested, and cannot be, is whether the prose is clear, useful, or the right length.

**Rationale**: this is the same line the Phase 4 checklist drew, and it is the reason the checklist
exists. A requirement about an artifact's content can fail a check; a requirement about its wording
quality cannot. The citation check is the one part of this feature that has a decidable failure
condition, so it is the one part that gets a fixture. Claiming a self-test for the rest would be
claiming a verification that did not happen.

### Why this is not a second linting configuration for Markdown

Worth stating because it is the first thing a reviewer should challenge. The Quality Gate Requirements
section at v1.2.0 allows one governing configuration per content kind **per concern**, and names the
concerns as formatting and linting. Markdown already has both: `.prettierrc.json` and
`.markdownlint-cli2.jsonc`.

`lint-citations.sh` adds neither. It has **no configuration file of its own** and governs no content
kind; it verifies an invariant between two files. `scripts/lint-scope.sh` set that precedent in the
first amendment -- it too has no configuration and no content kind, and compares declarations to one
another. The constitutional limit counts configurations per content kind and concern, and this check
contributes zero of them.

## 24. What the templates cannot do, recorded so it is not mistaken for a gap

Three limits, each a platform fact rather than a decision:

1. **The proposal that adds the templates cannot use them.** "Templates are available to collaborators
   when they are merged into the repository's default branch." So the first proposal to carry this
   structure is the one after it.
2. **Nothing prevents an author deleting a section.** With issue forms unavailable for pull requests,
   there is no required field and no validation. The structures are designed so an omission is visible
   to a reviewer -- a missing answer under a heading that is still there -- rather than impossible.
3. **The check result FR-030 records is the author's statement, not a verified fact.** Verifying it
   would mean running the check when a proposal opens, which spec.md's Out of Scope excludes along with
   continuous integration. FR-030 is deliberately a record, and `lint-citations.sh` verifies the
   quotation's accuracy, never the claim beside it.

## Open questions

None. All three spec clarifications were resolved in Phase 3, and every Technical Context field in plan.md is filled.
