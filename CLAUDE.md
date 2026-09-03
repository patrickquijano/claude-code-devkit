# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

`claude-code-devkit` is a Claude Code plugin and developer toolkit for building custom agents, commands, skills, and MCP servers. The quality gate, the plugin manifests described below, and five skills under `skills/` are on disk and working; the commands, agents and MCP servers the toolkit advertises are not built yet.

## The distributed skills

`skills/` holds the plugin's own authored skills, auto-discovered by installing the plugin — `plugin.json` declares no `skills` path and must not, because that field adds to the default directory rather than replacing it. Installed, they resolve as `claude-code-devkit:<name>`.

`ccd-speckit-run` is the entry point: it drives the eight Spec Kit phases from one task description and ships the result. `ccd-branch-push`, `ccd-commit-push`, `ccd-github-pr` and `ccd-gitlab-mr` are the git and forge skills it dispatches at its Step 6, and each is usable on its own.

Four things about them are load-bearing and easy to undo by tidying:

- Every distributed skill carries the `ccd-` prefix in its directory name and its frontmatter `name`. The prefix looks redundant under the `claude-code-devkit:` namespace and is not — it is what makes the **bare** name unambiguous when a personal copy of the same skill is also installed.
- Cross-skill dispatch uses the **namespaced** name. A bare name resolves to whatever the session decides when a personal copy is also installed.
- `branch-options.sh` exists **once**, in `ccd-branch-push`, reached by all four consumers through `${CLAUDE_PLUGIN_ROOT}`. Its header comment records the three defects of the fork that was rejected.
- Only `ccd-speckit-run` carries `disable-model-invocation`. Adding it to the other four breaks Step 6's dispatch silently. `skills/ccd-speckit-run/SKILL.md`'s authoring note says why the strict reading binds.

Their own history is in `specs/002-vendor-plugin-skills/`, which distributed them, and `specs/003-ccd-skill-rename/`, which gave them the `ccd-` prefix and supersedes 002's two interface contracts.

## Agent instructions

`AGENTS.md` holds the shared cross-agent instructions, and `LEAN-CTX.md` holds the full lean-ctx rules. Both are **read on demand, not auto-loaded** — open them when the task touches their subject, rather than importing them here. The short version: lean-ctx shadow mode routes native read/search/shell calls to the `ctx_*` MCP tools automatically, so no tool mapping is needed; `ctx_compose` is the exclusive entry point for understanding unfamiliar code and has no native equivalent.

## Spec-driven development

The repository is initialized for GitHub Spec Kit (`.specify/`), with the phase commands installed as project skills under `.claude/skills/speckit-*`. Feature work runs through them in order — `speckit-constitution`, `speckit-specify`, `speckit-clarify`, `speckit-checklist`, `speckit-plan`, `speckit-tasks`, `speckit-analyze`, `speckit-implement` — writing artifacts into `specs/NNN-slug/`. Repo-wide governance lives in `.specify/memory/constitution.md` and is read by the `plan` phase's gates at runtime, so amend it through `speckit-constitution` rather than by hand.

`.specify/scripts/bash/` holds the helper scripts those phases call; treat them as Spec Kit's, not the project's.

## Build, lint, test

There is no build step and no separate test runner. The checks are the tests.

```sh
scripts/lint.sh       # all seven checks; exits non-zero at the first failure
scripts/lint.sh --fix # rewrite what can be rewritten
scripts/selftest.sh   # prove each check still rejects bad input
```

Run one check in isolation with `scripts/lint-<standard>.sh`, where `<standard>` is one of `citations`, `editorconfig`, `format`, `markdown`, `yaml`, `shell`, `python`. `citations` runs first and needs no tool at all: it checks that every governance quotation in `.github/` still matches the document it cites.

Non-obvious things about these:

- Each check prefers the native tool and otherwise runs a digest-pinned container. `LINT_FORCE_CONTAINER=1` skips the native path, which is how you verify both give the same verdict.
- Check mode mounts the repository **read-only**, so a run without `--fix` cannot modify the tree even if a tool tried to.
- Each check declares its excluded paths in **one** place: the configuration file that already drives it — `.prettierignore`, `ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `Exclude` (regexes, not globs) in `.editorconfig-checker.json`, and a marked comment block in `.shellcheckrc` for the one tool with no exclusion mechanism of its own. The runner reads that same declaration to build the file list, so a contributor invoking a tool by hand gets the exclusions the runner applies. There is no central list and no check comparing copies; feature 004 deleted both. Adding an excluded path means editing the declaration of each check that should skip it, and two checks legitimately differing is now expressible rather than a build failure.
- **Your own edits are reformatted under you.** `.claude/settings.json` registers a committed `PostToolUse` hook, `scripts/format-file.sh`, which runs after `Edit`, `Write`, `MultiEdit` and `NotebookEdit` and rewrites the edited file through the three checks that can rewrite — `format`, then `markdown`, then `python`, in that order. A file no check governs is left untouched and reports nothing. Re-read a file after editing it if the exact bytes matter; a formatting failure arrives on stderr naming the file and the check, and never undoes the edit. Details: `specs/004-format-hook-scope/contracts/format-file-cli.md`.
- `.github/pull_request_template.md` and `.github/PULL_REQUEST_TEMPLATE/` are change-proposal templates that quote the constitution; nothing excludes `.github/`, so they are formatted and linted like any other Markdown, and `scripts/lint-citations.sh` fails when a quotation goes stale. The specialised two repeat every section of the general one rather than referring to it, because only the general one is applied automatically.
- Shell scripts are POSIX `sh`, checked with `shell=sh`. No bashisms: no `[[ ]]`, no arrays, no `<<<`, no `set -o pipefail`. They indent with tabs, because `<<-` heredocs strip leading tabs and nothing else.
- Every setting that departs from its tool's default has a written reason in `specs/001-quality-gate-plugin/research.md`. Check there before "fixing" one.
