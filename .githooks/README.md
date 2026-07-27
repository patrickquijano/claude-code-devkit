# .githooks

Repo git hooks (not the Claude Code plugin hooks in `hooks/` — see that
directory's own README for the `PostToolUse` lint/format hook). These run
via git's native hook mechanism once installed.

## Install

```sh
./scripts/install-git-hooks.sh
```

Idempotently sets `git config --local core.hooksPath .githooks` so git
looks here instead of `.git/hooks/` (which isn't version-controlled).

## pre-commit

Runs `scripts/format-and-lint.sh` against the whole repo before every
commit. Aborts the commit if:

- the run fails (a real lint failure), or
- the run changed any file's working-tree status (a formatter rewrote
  something) — review the changes, `git add` them, and commit again.
  Never silently re-stages files for you.

## Requirements

`bash`, `git`. Same requirements as `scripts/format-and-lint.sh` for
`pre-commit` (see `scripts/README.md`).
