# CLAUDE.md

This file guide Claude Code (claude.ai/code) in this repo.

## Project

`claude-code-devkit` — Claude Code plugin. Give reusable skill, agent, hook, command, config. Streamline dev across any app (see README.md).

## Current state

Repo scaffold only. No plugin code, no build, no linter, no test yet. No build/lint/test command run. `.claude/` hold local plugin-dev file, git-ignore except own `.gitignore` — plugin piece (skill, agent, hook, command) go there as built.

## Repository structure

- `README.md` — project overview.
- `LICENSE` — MIT.
- `.editorconfig` — 2-space indent, LF, UTF-8, trim trailing whitespace.
- `.github/PULL_REQUEST_TEMPLATE/` — one template per change type
  (`feature.md`, `bug_fix.md`, `documentation.md`, `refactoring.md`,
  `dependency_update.md`, `release.md`, `security.md`); GitHub prompt
  pick one when open PR.
- `.claude/` — local plugin dev workspace, git-ignored.

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