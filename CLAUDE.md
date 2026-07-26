# CLAUDE.md

This file guide Claude Code (claude.ai/code) when work in this repo.

## Project

`claude-code-devkit` — Claude Code plugin. Give reusable skills, agents, hooks, commands, configs. Streamline dev across any app (see README.md).

## Current state

Repo scaffold only. No plugin source code, no build system, no linter, no test suite yet. No build/lint/test commands to run. `.claude/` hold local plugin-dev files, git-ignored except own `.gitignore` — plugin pieces (skills, agents, hooks, commands) go there as built.

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

- Descriptive, conventional: `type/short-description` (types match commit
  types — `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`).
- Name reflect actual purpose of change, concise, easy to understand.
- No generic/ambiguous names (`patch-1`, `update`, `fix-stuff`).

## Commit messages

- Conventional Commits format (`type: subject`).
- Imperative mood, concise, ≤72 char.
- Describe change made, not file touched or reason why.
- No body, no footer, no attribution line.

## Commit granularity

- Atomic, self-contained: one logical change per commit.
- Don't bundle unrelated changes together.

## Pull requests

- Use matching template from `.github/PULL_REQUEST_TEMPLATE/` for change type.
- PR title follow commit message rules above.
- PR description: clear concise summary of change, relevant context/background, instructions for test or review.

## Documentation sync

- Update README.md whenever change affect what user/contributor need know.
- Keep README.md match this file — don't let two contradict.

## Self-healing

- When verify (build, lint, test) fail, diagnose and fix root cause self. Don't stop on unresolved failure.