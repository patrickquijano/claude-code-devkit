# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`claude-code-devkit` is a Claude Code plugin and developer toolkit for building custom agents, commands, skills, and MCP servers. The quality gate and the plugin manifests described below are on disk and working; the commands, agents and MCP servers the toolkit advertises are not built yet.

## Agent instructions

`AGENTS.md` holds the shared cross-agent instructions, and `LEAN-CTX.md` holds the full lean-ctx rules. Both are **read on demand, not auto-loaded** — open them when the task touches their subject, rather than importing them here. The short version: lean-ctx shadow mode routes native read/search/shell calls to the `ctx_*` MCP tools automatically, so no tool mapping is needed; `ctx_compose` is the exclusive entry point for understanding unfamiliar code and has no native equivalent.

## Spec-driven development

The repository is initialized for GitHub Spec Kit (`.specify/`), with the phase commands installed as project skills under `.claude/skills/speckit-*`. Feature work runs through them in order — `speckit-constitution`, `speckit-specify`, `speckit-clarify`, `speckit-checklist`, `speckit-plan`, `speckit-tasks`, `speckit-analyze`, `speckit-implement` — writing artifacts into `specs/NNN-slug/`. Repo-wide governance lives in `.specify/memory/constitution.md` and is read by the `plan` phase's gates at runtime, so amend it through `speckit-constitution` rather than by hand.

`.specify/scripts/bash/` holds the helper scripts those phases call; treat them as Spec Kit's, not the project's.

## Build, lint, test

There is no build step and no separate test runner. The checks are the tests.

```sh
scripts/lint.sh       # all eight checks; exits non-zero at the first failure
scripts/lint.sh --fix # rewrite what can be rewritten
scripts/selftest.sh   # prove each check still rejects bad input
```

Run one check in isolation with `scripts/lint-<standard>.sh`, where `<standard>` is one of `scope`, `citations`, `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python`. `scope` and `citations` run first and need no tool at all: `scope` compares the five per-check path declarations against `.lintignore`, and `citations` checks that every governance quotation in `.github/` still matches the document it cites.

Non-obvious things about these:

- Each check prefers the native tool and otherwise runs a digest-pinned container. `LINT_FORCE_CONTAINER=1` skips the native path, which is how you verify both give the same verdict.
- Check mode mounts the repository **read-only**, so a run without `--fix` cannot modify the tree even if a tool tried to.
- `.lintignore` drives the runner's file list, and each check **also** declares its own skipped paths in its own configuration — `ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `.prettierignore`, and `Exclude` (regexes, not globs) in `.editorconfig-checker.json`. Those declarations govern a contributor invoking a tool by hand, not the runner. Keep them in step with `.lintignore`: `scripts/lint-scope.sh` compares all five on every aggregate run and fails on divergence. ShellCheck has no such mechanism and is reported unverifiable rather than passing.
- `.github/pull_request_template.md` and `.github/PULL_REQUEST_TEMPLATE/` are change-proposal templates that quote the constitution; nothing excludes `.github/`, so they are formatted and linted like any other Markdown, and `scripts/lint-citations.sh` fails when a quotation goes stale. The specialised two repeat every section of the general one rather than referring to it, because only the general one is applied automatically.
- Shell scripts are POSIX `sh`, checked with `shell=sh`. No bashisms: no `[[ ]]`, no arrays, no `<<<`, no `set -o pipefail`. They indent with tabs, because `<<-` heredocs strip leading tabs and nothing else.
- Every setting that departs from its tool's default has a written reason in `specs/001-quality-gate-plugin/research.md`. Check there before "fixing" one.
