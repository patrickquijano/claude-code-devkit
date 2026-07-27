# claude-code-devkit

A Claude Code plugin offering reusable skills, agents, hooks, commands, and configurations to streamline development across any application.

## Status

This repository is currently a scaffold. Plugin components (skills, agents, hooks, commands) are under active development in `.claude/` and not yet published.

## Repository structure

- `README.md` — this file.
- `LICENSE` — MIT.
- `CLAUDE.md` — guidance for Claude Code when working in this repo.
- `.editorconfig` — shared editor formatting rules.
- `.markdownlint.jsonc` / `.markdownlintignore` — markdown lint config (no line-length limit).
- `.yamllint.yaml` — YAML lint config (default ruleset, 160-char line length, inline ignore patterns).
- `.shellcheckrc` / `.shellcheckignore` — shell lint config + ignore patterns.
- `.hadolint.yaml` / `.hadolintignore` — Dockerfile lint config + ignore patterns.
- `.prettierrc.yaml` / `.prettierignore` — Prettier format config (160-char line length) + ignore patterns.
- `.github/PULL_REQUEST_TEMPLATE/` — per-change-type PR templates (feature, bug fix, documentation, refactoring, dependency update, release, security).
- `.claude/` — local plugin development workspace (git-ignored except `.gitignore`, `settings.json`, `rules/`).
- `scripts/setup-git-config.sh` — interactive per-repo `user.name` / `user.email` / `user.signingkey` / `gpg.format` / `commit.gpgsign` setup.
- `scripts/format-and-lint.sh` — runs prettier, markdownlint-cli2, yamllint, shellcheck, and hadolint in one step.

## Installation

Not yet published. Once the plugin is packaged, it will be installable as a Claude Code plugin (via a plugin marketplace or by cloning into your Claude Code plugin directory). This section will be updated with exact steps at first release.

## Usage

Once installed, the plugin's skills, agents, hooks, and commands will be available inside Claude Code for the application you're working on. Usage details will be documented here as components are built.

## Contributing

- Branch names follow `type/short-description` (e.g. `feat/add-hook-x`, `chore/scaffold-project-docs`).
- Commit messages follow Conventional Commits: imperative, ≤72 characters, no body/footer/attribution. See `CLAUDE.md`.
- Open pull requests using the template matching your change type from `.github/PULL_REQUEST_TEMPLATE/`.
- Keep this README and `CLAUDE.md` consistent with each other.
- Follow the component guidelines in `.claude/rules/` when adding or updating skills, agents, hooks, or plugin structure.
- Format all files with `npx prettier --check .` and lint with `markdownlint-cli2`, `yamllint`, `shellcheck`, and `hadolint` before opening a PR.

## License

MIT — see [LICENSE](LICENSE).
