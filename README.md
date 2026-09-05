# claude-code-devkit

> A Claude Code plugin that takes a feature from one sentence to a reviewed pull request, and checks its own repository.

Installing the plugin gives you seven skills. `ccd-speckit-run` drives the eight [GitHub Spec Kit](https://github.com/github/spec-kit) phases from a single task description and ships the result; `ccd-speckit-bug-run` drives Spec Kit's bug-triage workflow from one bug report to a verified fix; four others handle the git and forge work those two hand off, and each is equally usable on its own; `ccd-conflict-resolve` walks you through resolving a merge conflict.

The repository also carries its own quality gate — one command, seven checks, no tool to install first.

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [The seven skills](#the-seven-skills)
  - [Running the pipeline](#running-the-pipeline)
  - [Running the quality checks](#running-the-quality-checks)
  - [Formatting on edit](#formatting-on-edit)
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

### The seven skills

Each resolves as `claude-code-devkit:<name>`, and each is also reachable by its bare name.

| Skill                  | What it does                                                                                                               |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `ccd-speckit-run`      | Drives the eight Spec Kit phases from one task description, then verifies and ships the result                             |
| `ccd-speckit-bug-run`  | Drives Spec Kit's three bug-triage stages from one bug report — assess, fix, test — approving each stage separately        |
| `ccd-branch-push`      | Creates a branch off a chosen base and pushes it, with the branch name and collisions settled first                        |
| `ccd-commit-push`      | Commits the working tree — message convention, how the change splits, whether to push                                      |
| `ccd-github-pr`        | Opens a GitHub pull request: base, assignee, reviewers, draft, auto-merge                                                  |
| `ccd-gitlab-mr`        | Opens a GitLab merge request: target, assignee, reviewers, squash, delete-source-branch                                    |
| `ccd-conflict-resolve` | Resolves an in-progress merge conflict: lists what is conflicted, proposes a resolution per path, applies what you approve |

The `ccd-` prefix is deliberate and is not redundant with the namespace. The namespace disambiguates `claude-code-devkit:ccd-github-pr`; nothing disambiguates a **bare** name, and the bare name is what you type. These skills grew out of personal skills with unprefixed names, which may still be installed on the same machine — the prefix is what keeps the two apart.

### Running the pipeline

`ccd-speckit-run` is the entry point. Give it a task description and it runs constitution, specify, clarify, checklist, plan, tasks, analyze and implement in order, then verifies the result with the repository's own checks and raises a review request:

```text
/ccd-speckit-run add pagination to the audit log list
```

It asks before anything irreversible — where the run happens, which branch to base it on, whether to commit and open the request, and where to leave you afterwards. It also proposes **each phase separately**, immediately before running it, naming the command, the exact argument it will receive and what changed since the plan it showed you at the start. After every step and phase it checks whether the working tree has become conflicted, and hands you to `ccd-conflict-resolve` when it has. It dispatches `ccd-commit-push` and one of the two forge skills at its shipping step; which forge skill runs is decided from `origin`, never from what the task description happens to call it.

The others are useful on their own:

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
| `scripts/lint-citations.sh`    | that governance quotations still match source  | none; it reads the cited documents            |
| `scripts/lint-editorconfig.sh` | whitespace, line endings                       | `.editorconfig`, `.editorconfig-checker.json` |
| `scripts/lint-format.sh`       | formatting of JSON, Markdown, YAML, XML, shell | `.prettierrc.json`, `.prettierignore`         |
| `scripts/lint-markdown.sh`     | Markdown, apart from what the formatter owns   | `.markdownlint-cli2.jsonc`                    |
| `scripts/lint-yaml.sh`         | YAML, apart from what the formatter owns       | `.yamllint.yml`                               |
| `scripts/lint-shell.sh`        | shell scripts                                  | `.shellcheckrc`                               |
| `scripts/lint-python.sh`       | Python                                         | `ruff.toml`                                   |

Formatting and linting are separate concerns, so a content kind may be governed by one configuration for each — never by two of either. Markdown and YAML are formatted by `lint-format.sh` and linted by their own tools, which give up the rules the formatter rewrites.

`scripts/selftest.sh` proves the checks can actually fail: it runs each one against a deliberately broken fixture and succeeds only if every check rejects it.

### Formatting on edit

Editing a file in Claude Code formats it. `.claude/settings.json` is committed and registers a `PostToolUse` hook, [`scripts/format-file.sh`](scripts/format-file.sh), so this applies to anyone who opens the repository — there is nothing to install or switch on.

**What it does.** After a successful `Edit`, `Write`, `MultiEdit` or `NotebookEdit`, the hook takes the one file that tool wrote and runs the three checks that can rewrite, in the aggregate's own order: `lint-format.sh`, then `lint-markdown.sh`, then `lint-python.sh`, each with `--fix` restricted to that file. It reports one line per check that examined the file:

```text
==> format-file.sh: README.md (lint-format.sh)
==> format-file.sh: README.md (lint-markdown.sh)
```

The order is not arbitrary. Markdown is governed by two of the three — Prettier formats it and markdownlint lints what Prettier does not rewrite — so running them the other way round would not settle.

**Dependencies: none beyond the checks themselves.** The hook shells out to the same check scripts you would run by hand, so each one prefers the tool on your `PATH` and otherwise runs its digest-pinned container. If a check can run neither way it says so, naming the missing tool and the image, and the edit stands:

```text
==> format-file.sh: notes.md - lint-format.sh skipped: ... Neither the native command "prettier" nor "docker" ... is available.
```

That is a visible skip, not a failure. Requiring a container runtime before you could edit a Markdown file would be worse than formatting nothing.

**Which files.** Whatever those three checks govern, and nothing else — the hook carries no list of its own. Today that is JSON, JSONC, Markdown, YAML, XML and shell through Prettier, Markdown through markdownlint, and Python through Ruff. A file no check governs is left alone and reports nothing, so most edits produce no output at all.

It also does nothing, silently, for a path that is outside the repository, deleted, a directory, a symlink, or binary. Those are ordinary outcomes rather than errors, and none of them writes anything.

**When formatting fails.** The hook exits 2 and puts the file, the check, its exit status and the check's own unmodified output on stderr, where Claude Code shows it to the session — enough to diagnose and retry. It never blocks or reverts the edit: `PostToolUse` runs after the tool has already written, so the edit stands and the report tells you what still needs fixing.

**Extending it to a new file kind.** There is no mapping table in the hook to edit, which is the point of its design. Either add the extension to an existing check's globs in that check's `collect` call, or add another rewriting check to the three calls at the bottom of `scripts/format-file.sh`. A new check needs to follow the existing convention: exit 0 with `no files in scope` when the file is not its business, since that is how the hook knows to stay quiet.

**One thing it cannot promise.** It is not necessarily the only formatter running. A formatter configured outside this repository — in your user-level Claude Code settings, say — can match the same event, and hooks for one event run in parallel, so two of them may write the same file at once. The repository cannot detect that from inside and must not edit configuration outside its own root. If you have such a hook, stand it down for this repository by adding one line near its top:

```sh
[ -x "$CLAUDE_PROJECT_DIR/scripts/format-file.sh" ] && exit 0
```

Put it before that script picks a tool. If it already resolves the workspace root into a variable of its own, test that instead of `$CLAUDE_PROJECT_DIR`. Until such a line is applied, both formatters do run — this repository can neither detect that nor fix it from inside, which is why it is documented here rather than enforced.

The reasoning is in [`specs/004-format-hook-scope/research.md`](specs/004-format-hook-scope/research.md); the full contract, including the path rules and the exit statuses, is in [`specs/004-format-hook-scope/contracts/format-file-cli.md`](specs/004-format-hook-scope/contracts/format-file-cli.md).

## Contributing

Open a pull request and it arrives pre-filled from [`.github/pull_request_template.md`](.github/pull_request_template.md): what changed, why, where to look first, whether the checks were run and passed, whether an agent produced it, and what the reviewer is obliged to verify. The last two sections quote [`.specify/memory/constitution.md`](.specify/memory/constitution.md) directly rather than summarising it, and `scripts/lint-citations.sh` fails the aggregate check when an amendment leaves one of those quotations behind.

Two further templates in [`.github/PULL_REQUEST_TEMPLATE/`](.github/PULL_REQUEST_TEMPLATE/) add the one question their kind of change raises, and are opted into by appending to the URL — `?template=quality-gate.md` for a change to the checking machinery, `?template=spec-record.md` for a change to the spec-driven record. Each repeats every section of the general template, because only the general one is applied automatically.

Before proposing a change, run `scripts/lint.sh` and make sure it passes. The constitution requires it, and the reviewer will check.

Arm the git hooks once per clone, before your first commit:

```sh
sh scripts/install-hooks.sh
```

That points git at the committed hooks in `.husky/`, which refuse a commit message that is not a Conventional Commits subject of at most 72 characters and refuse a push carrying an unsigned or badly signed commit. It needs nothing but POSIX `sh` and git — no `npm install`, no `package.json`, and Husky itself is optional. `sh scripts/install-hooks.sh --status` reports whether the checks are currently on. What each hook enforces, why Husky is optional, and how to bypass a check in an emergency are in [`docs/husky-git-hooks.md`](docs/husky-git-hooks.md).

Two things worth knowing before you edit:

- Each check declares its excluded paths in **one** place: the configuration file that already drives it. The runner reads that same declaration to build the file list, so running a tool by hand applies the exclusions the runner applies. ShellCheck has no exclusion mechanism of its own, so its declaration is a marked comment block in `.shellcheckrc` — read by the runner, invisible to the tool, which is a limitation stated in that file.
- Your edits are reformatted as you make them. `.claude/settings.json` registers a committed Claude Code hook, `scripts/format-file.sh`, which runs the rewriting checks over each file the session edits. It never blocks or undoes an edit; a failure is reported with the file and the check named.
- Every setting that departs from its tool's default has a written reason in [`specs/001-quality-gate-plugin/research.md`](specs/001-quality-gate-plugin/research.md), as does every default relied on without being restated. Check there before "fixing" one.

Feature work runs through Spec Kit and leaves its record under `specs/NNN-slug/`. The rules the repository holds itself to are in [`.specify/memory/constitution.md`](.specify/memory/constitution.md).

## License

[MIT](LICENSE) © Patrick Quijano.
