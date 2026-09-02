# claude-code-devkit

A Claude Code plugin and developer toolkit for building custom agents, commands, skills, and MCPs. Includes templates, patterns, examples, and workflows to accelerate AI-powered automation, tool integration, context engineering, and scalable developer productivity.

## The skills

Installing the plugin gives you five skills. There is nothing further to copy, symlink, or add to `plugin.json` — `skills/<name>/SKILL.md` is auto-discovered, and each one resolves as `claude-code-devkit:<name>`.

| Skill              | What it does                                                                                        |
| ------------------ | --------------------------------------------------------------------------------------------------- |
| `speckit-run`      | Drives the eight Spec Kit phases from one task description, then verifies and ships the result      |
| `auto-branch-push` | Creates a branch off a chosen base and pushes it, with the branch name and collisions settled first |
| `auto-commit-push` | Commits the working tree — message convention, how the change splits, whether to push               |
| `auto-github-pr`   | Opens a GitHub pull request: base, assignee, reviewers, draft, auto-merge                           |
| `auto-gitlab-mr`   | Opens a GitLab merge request: target, assignee, reviewers, squash, delete-source-branch             |

`speckit-run` is the entry point and dispatches the other four at its Step 6; each of the four is equally usable on its own. Which forge skill runs is decided from `origin`, never from what the task description happens to call it.

Each skill carries its own scenario document (`evaluations.md`) stating what a correct run looks like and which regressions to check for after editing it. `specs/002-vendor-plugin-skills/` records how they came to be distributed and what changed in the process.

## Quality checks

One command checks everything this repository holds:

```sh
scripts/lint.sh
```

It exits `0` on a clean tree and non-zero at the first failing check, naming the file and line of every violation. Add `--fix` to rewrite what can be rewritten:

```sh
scripts/lint.sh --fix
```

Nothing needs installing first. Each check prefers the tool on your `PATH` and otherwise runs a digest-pinned container, so a contributor with none of the tools installed gets the same verdict as one with all of them. If neither is available the check fails loudly rather than skipping itself.

Individual checks, for re-running one in isolation:

| Command                        | Governs                                        | Configuration                                 |
| ------------------------------ | ---------------------------------------------- | --------------------------------------------- |
| `scripts/lint-scope.sh`        | that the checks agree on what is in scope      | `.lintignore` and the five files below        |
| `scripts/lint-citations.sh`    | that governance quotations still match source  | none; it reads the cited documents            |
| `scripts/lint-editorconfig.sh` | whitespace, line endings                       | `.editorconfig`, `.editorconfig-checker.json` |
| `scripts/lint-format.sh`       | formatting of JSON, Markdown, YAML, XML, shell | `.prettierrc.json`, `.prettierignore`         |
| `scripts/lint-markdown.sh`     | Markdown, apart from what the formatter owns   | `.markdownlint-cli2.jsonc`                    |
| `scripts/lint-yaml.sh`         | YAML, apart from what the formatter owns       | `.yamllint.yml`                               |
| `scripts/lint-shell.sh`        | shell scripts                                  | `.shellcheckrc`                               |
| `scripts/lint-python.sh`       | Python                                         | `ruff.toml`                                   |

Formatting and linting are separate concerns, so a content kind may be governed by one configuration for each — never by two of either. Markdown and YAML are formatted by `lint-format.sh` and linted by their own tools, which give up the rules the formatter rewrites.

`scripts/selftest.sh` proves the checks can actually fail: it runs each one against a deliberately broken fixture and succeeds only if every check rejects it.

## Proposing a change

Open a pull request and it arrives pre-filled from `.github/pull_request_template.md`: what changed, why, where to look first, whether the checks were run and passed, whether an agent produced it, and what the reviewer is obliged to verify. The last two sections quote [`.specify/memory/constitution.md`](.specify/memory/constitution.md) directly rather than summarising it, and `scripts/lint-citations.sh` fails the aggregate check when an amendment leaves one of those quotations behind.

Two further templates in `.github/PULL_REQUEST_TEMPLATE/` add the one question their kind of change raises and are opted into by appending to the URL — `?template=quality-gate.md` for a change to the checking machinery, `?template=spec-record.md` for a change to the spec-driven record. Each repeats every section of the general template, because only the general one is applied automatically.

`.lintignore` declares what the runner examines. Each check also declares its own skipped paths in its own configuration, for the contributor who runs a tool by hand; `scripts/lint-scope.sh` compares them and fails when they diverge. ShellCheck offers no such mechanism and is reported unverifiable rather than passing.

Every setting that departs from its tool's default has a written reason in [`specs/001-quality-gate-plugin/research.md`](specs/001-quality-gate-plugin/research.md), as does every default relied on without being restated; the rules the repository holds itself to are in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).
