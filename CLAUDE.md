# CLAUDE.md

This file guide Claude Code (claude.ai/code) in this repo.

## Project

`claude-code-devkit` — Claude Code plugin. Give reusable skill, agent, hook, command, config. Streamline dev across any app (see README.md).

## Current state

Repo scaffold only. No plugin code, no build, no test yet. Markdown lint config exist (`.markdownlint.jsonc` + `.markdownlintignore`) — see "Linting and formatting" below. `.claude/` hold local plugin-dev file, git-ignore except `.gitignore`, `settings.json`, `rules/` — plugin piece (skill, agent, hook, command) go there as built, follow `.claude/rules/`.

## Project rules

@LEAN-CTX.md
@.claude/rules/plugins.md
@.claude/rules/skills.md
@.claude/rules/subagents.md
@.claude/rules/hooks.md

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

- Markdown lint: `npx markdownlint-cli2 "**/*.md"` to check, `npx markdownlint-cli2 --fix "**/*.md"` to autofix.
- Markdown format: `npx prettier --check "**/*.md"` to check, `npx prettier --write "**/*.md"` to format.
- Run format before lint — prettier reformat, then markdownlint verify style rule.

## Repository structure

- `README.md` — project overview.
- `LICENSE` — MIT.
- `.editorconfig` — 2-space indent, LF, UTF-8.
- `.markdownlint.jsonc` / `.markdownlintignore` — markdown lint rule + ignore config; long line disabled, no manual wrap.
- `.github/PULL_REQUEST_TEMPLATE/` — one template per change type
  (`feature.md`, `bug_fix.md`, `documentation.md`, `refactoring.md`,
  `dependency_update.md`, `release.md`, `security.md`); GitHub prompt
  pick one when open PR.
- `.claude/` — local plugin dev workspace, git-ignored except `.gitignore`, `settings.json`, `rules/`.
  - `.claude/rules/` — plugin component rules, see "Project rules" below.

## Branch naming

- Descriptive, conventional: `type/short-description` (type match commit
  type — `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`).
- Name show real purpose of change, short, easy understand.
- No generic/vague name (`patch-1`, `update`, `fix-stuff`).

## Commit messages

- Conventional Commits format (`type: subject`).
- Imperative mood, short, ≤72 char.
- Say what change do, not file touch or why.
- No body, no footer, no attribution line.

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
