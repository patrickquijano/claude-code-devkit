# CLAUDE.md

This file guide Claude Code (claude.ai/code) in this repo.

## Project

`claude-code-devkit` — Claude Code plugin. Give reusable skill, agent, hook, command, config. Streamline dev across any app (see README.md).

## Current state

Plugin manifest at `.claude-plugin/plugin.json` (name `devkit`). `hooks/` hold `PostToolUse` lint/format hook (`hooks.json` + `hooks/scripts/` dispatcher + `lib/` helper, grouped by concern — see `hooks/README.md`). No build/test yet beyond the hook itself. Markdown lint config exist (`.markdownlint.jsonc` + `.markdownlintignore`) — see "Linting and formatting" below. `.claude/` hold local plugin-dev file, git-ignore except `.gitignore`, `settings.json`, `rules/` — remaining plugin piece (skill, agent, command) go there as built, follow `.claude/rules/`.

## Project rules

@LEAN-CTX.md
@.claude/rules/claude-components/plugins.md
@.claude/rules/claude-components/skills.md
@.claude/rules/claude-components/subagents.md
@.claude/rules/claude-components/hooks.md
@.claude/rules/github-actions.md

## Session behavior

- New session: activate `/caveman ultra` skill (fallback `/caveman`) before any task.
- Output: brief, concise, structured format.
- No hallucination.
- No assumption.
- Task unclear/ambiguous: ask for clarification.
- Any question to user: use `AskUserQuestion` tool.
- Always apply DRY and KISS principle.
- Simplest solution first; add complexity only when necessary.
- Issue resolved: remember issue + solution, avoid repeat.

## Linting and formatting

- Prerequisite (once per checkout): `npm install` (prettier + web linters) and `uv sync` (yamllint + ruff).
- Format (all files): `npx prettier --check .` to check, `npx prettier --write .` to format (config: `.prettierrc.json` + `.prettierignore`; plugins: `prettier-plugin-sh`, `prettier-plugin-markdown-html`, `prettier-plugin-yaml`, `@htnabe/prettier-plugin-go-template`).
- Markdown lint: `npx markdownlint-cli2 "**/*.md" "#node_modules" "#.venv"` to check, add `--fix` to autofix (excludes vendored trees markdownlint-cli2 doesn't ignore by default).
- YAML lint: `uv run yamllint .` (config + inline ignore patterns: `.yamllint.yaml`).
- Shell lint: `find . -type f -name "*.sh" | grep -vFf .shellcheckignore | xargs -I{} shellcheck {}` (config: `.shellcheckrc`).
- Dockerfile lint: `find . -iname "Dockerfile*" | grep -vFf .hadolintignore | xargs -I{} hadolint {}` (config: `.hadolint.yaml`).
- Python lint: `uv run ruff format` to format, `uv run ruff check --fix` to lint+fix (config: `.ruff.toml` + `.ruffignore`).
- Run order: format first, then lint each language — prettier reformat, linters verify style/rule compliance on top.
- Convenience script: `./scripts/format-and-lint.sh` run all of the above in one step (see `scripts/README.md`).
- Once `./scripts/install-git-hooks.sh` run, `pre-commit` git hook run this automatically before every commit.

## Repository structure

- `README.md` — project overview.
- `LICENSE` — MIT.
- `.editorconfig` — 2-space indent, LF, UTF-8.
- `.markdownlint.jsonc` / `.markdownlintignore` — markdown lint rule + ignore config; long line disabled, no manual wrap.
- `.yamllint.yaml` — YAML lint config; default ruleset, 160-char line length, inline ignore patterns.
- `.shellcheckrc` / `.shellcheckignore` — shell lint config (enterprise-hardened optional checks) + ignore patterns.
- `.hadolint.yaml` / `.hadolintignore` — Dockerfile lint config (strict, no ignored rules) + ignore patterns.
- `.ruff.toml` / `.ruffignore` — Python lint config (community rules + line-length override) + native ignore file.
- `pyproject.toml` / `uv.lock` — uv-managed dev dependencies (`yamllint`, `ruff`), invoked via `uv run`.
- `package.json` / `package-lock.json` — npm devDependencies for prettier, markdownlint-cli2, eslint, stylelint, htmlhint (pinned, caret ranges).
- `.prettierrc.json` / `.prettierignore` — Prettier format config (160-char line length; plugins: `prettier-plugin-sh`, `prettier-plugin-markdown-html`, `prettier-plugin-yaml`, `@htnabe/prettier-plugin-go-template`) + ignore patterns.
- `eslint.config.js` — ESLint flat config (`@eslint/js` recommended ruleset; scaffolded, no `.js`/`.ts` files yet).
- `.stylelintrc.yaml` — stylelint config (`stylelint-config-standard`; scaffolded, no `.css` files yet).
- `.github/PULL_REQUEST_TEMPLATE/` — one template per change type (`feature.md`, `bug_fix.md`, `documentation.md`, `refactoring.md`, `dependency_update.md`, `release.md`, `security.md`); GitHub prompt pick one when open PR.
- `.claude-plugin/plugin.json` — plugin manifest (`devkit`: schema, name, description, version, author, license, dependencies).
- `hooks/` — `hooks.json` (`PostToolUse` lint/format hook, matcher `Edit|Write`) + `hooks/scripts/lint-format.sh` (dispatcher, extension-based) + `hooks/scripts/lib/` (`lintfmt_*.sh` helper, grouped by concern); see `hooks/README.md`.
- `.claude/` — local plugin dev workspace, git-ignored except `.gitignore`, `settings.json`, `rules/`.
  - `.claude/rules/` — project rules, see "Project rules" below.
    - `.claude/rules/claude-components/` — Claude Code plugin component rules (plugins, skills, subagents, hooks).
    - `.claude/rules/github-actions.md` — GitHub Actions authoring rules.
- `scripts/setup-git-config.sh` — interactive per-repo `user.name` / `user.email` / `user.signingkey` / `gpg.format` / `commit.gpgsign` / `push.autoSetupRemote` setup.
- `scripts/format-and-lint.sh` — run all format/lint command above in one step.
- `scripts/install-git-hooks.sh` — point `--local` `core.hooksPath` at `.githooks/`.
- `.githooks/` — `pre-commit` (format + lint) and `commit-msg` (Conventional Commits) git hooks; see `.githooks/README.md`.

## Branch naming

- Descriptive, conventional: `type/short-description` (type match commit type — `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`).
- Name show real purpose of change, short, easy understand.
- No generic/vague name (`patch-1`, `update`, `fix-stuff`).

## Commit messages

- Conventional Commits format (`type: subject`).
- Imperative mood, short, ≤72 char.
- Say what change do, not file touch or why.
- No body, no footer, no attribution line.
- Once `./scripts/install-git-hooks.sh` run, `commit-msg` git hook enforce format above.

## Commit granularity

- Atomic, self-contained: one logic change per commit.
- Don't bundle unrelated change together.

## Pull requests

- Use match template from `.github/PULL_REQUEST_TEMPLATE/` for change type.
- PR title follow commit message rule above.
- PR description: clear short summary of change, relevant context/background, instruction for test or review.

## Documentation sync

- Update README.md when change affect what user/contributor need know.
- Keep README.md match this file — don't let two contradict.

## Self-healing

- Once build/lint/test command exist: when verify fail, find root cause self and fix. Don't stop on unresolved failure.
