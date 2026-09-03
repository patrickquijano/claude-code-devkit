# claude-code-devkit

> A Claude Code plugin that takes a feature from one sentence to a reviewed pull request, and checks its own repository.

Installing the plugin gives you five skills. `ccd-speckit-run` drives the eight [GitHub Spec Kit](https://github.com/github/spec-kit) phases from a single task description and ships the result; the other four handle the git and forge work it hands off, and each is equally usable on its own.

The repository also carries its own quality gate — one command, eight checks, no tool to install first.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [The five skills](#the-five-skills)
  - [Running the pipeline](#running-the-pipeline)
  - [Running the quality checks](#running-the-quality-checks)
- [Contributing](#contributing)
- [License](#license)

## Install

Requires [Claude Code](https://code.claude.com/docs/en/overview). Nothing else — the skills are Markdown and POSIX `sh`, and the quality checks fall back to digest-pinned containers when a tool is not on your `PATH`.

Add the marketplace, then install the plugin:

```text
/plugin marketplace add patrickquijano/claude-code-devkit
/plugin install claude-code-devkit
```

That is the whole install. `skills/<name>/SKILL.md` is auto-discovered, so there is nothing further to copy, symlink, or add to `plugin.json`.

Confirm it worked:

```text
/claude-code-devkit:ccd-speckit-run
```

To work on the plugin itself rather than use it, clone the repository and run `scripts/lint.sh` — see [Running the quality checks](#running-the-quality-checks).

## Usage

### The five skills

Each resolves as `claude-code-devkit:<name>`, and each is also reachable by its bare name.

| Skill             | What it does                                                                                        |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| `ccd-speckit-run` | Drives the eight Spec Kit phases from one task description, then verifies and ships the result      |
| `ccd-branch-push` | Creates a branch off a chosen base and pushes it, with the branch name and collisions settled first |
| `ccd-commit-push` | Commits the working tree — message convention, how the change splits, whether to push               |
| `ccd-github-pr`   | Opens a GitHub pull request: base, assignee, reviewers, draft, auto-merge                           |
| `ccd-gitlab-mr`   | Opens a GitLab merge request: target, assignee, reviewers, squash, delete-source-branch             |

The `ccd-` prefix is deliberate and is not redundant with the namespace. The namespace disambiguates `claude-code-devkit:ccd-github-pr`; nothing disambiguates a **bare** name, and the bare name is what you type. These skills grew out of personal skills with unprefixed names, which may still be installed on the same machine — the prefix is what keeps the two apart.

### Running the pipeline

`ccd-speckit-run` is the entry point. Give it a task description and it runs constitution, specify, clarify, checklist, plan, tasks, analyze and implement in order, then verifies the result with the repository's own checks and raises a review request:

```text
/ccd-speckit-run add pagination to the audit log list
```

It asks before anything irreversible — where the run happens, which branch to base it on, what the eight phase prompts will say, and whether to commit and open the request. It dispatches `ccd-commit-push` and one of the two forge skills at its shipping step; which forge skill runs is decided from `origin`, never from what the task description happens to call it.

The other four are useful without the pipeline:

```text
/ccd-branch-push branch off staging for this work
/ccd-commit-push group these into commits and push
/ccd-github-pr open a PR for this branch
```

Each skill carries an `evaluations.md` stating what a correct run looks like and which regressions to check for after editing it.

### Running the quality checks

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

## Contributing

Open a pull request and it arrives pre-filled from [`.github/pull_request_template.md`](.github/pull_request_template.md): what changed, why, where to look first, whether the checks were run and passed, whether an agent produced it, and what the reviewer is obliged to verify. The last two sections quote [`.specify/memory/constitution.md`](.specify/memory/constitution.md) directly rather than summarising it, and `scripts/lint-citations.sh` fails the aggregate check when an amendment leaves one of those quotations behind.

Two further templates in [`.github/PULL_REQUEST_TEMPLATE/`](.github/PULL_REQUEST_TEMPLATE/) add the one question their kind of change raises, and are opted into by appending to the URL — `?template=quality-gate.md` for a change to the checking machinery, `?template=spec-record.md` for a change to the spec-driven record. Each repeats every section of the general template, because only the general one is applied automatically.

Before proposing a change, run `scripts/lint.sh` and make sure it passes. The constitution requires it, and the reviewer will check.

Two things worth knowing before you edit:

- `.lintignore` declares what the runner examines. Each check **also** declares its own skipped paths in its own configuration, for the contributor who runs a tool by hand; `scripts/lint-scope.sh` compares them and fails when they diverge. ShellCheck offers no such mechanism and is reported unverifiable rather than passing.
- Every setting that departs from its tool's default has a written reason in [`specs/001-quality-gate-plugin/research.md`](specs/001-quality-gate-plugin/research.md), as does every default relied on without being restated. Check there before "fixing" one.

Feature work runs through Spec Kit and leaves its record under `specs/NNN-slug/`. The rules the repository holds itself to are in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## License

[MIT](LICENSE) © Patrick Quijano.
