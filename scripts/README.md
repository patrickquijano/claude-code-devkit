# scripts

Standalone dev-workflow scripts for this repo. Each entrypoint is a
directly executable `bash` script at the top of this directory; shared
logic lives in `lib/`.

## setup-git-config.sh

Interactively view and idempotently set the **`--local`** (per-repo, not
global) git config keys most contributors need: `user.name`, `user.email`,
`user.signingkey`, `gpg.format`, `commit.gpgsign`.

Run from the repo root or any subdirectory of this git work tree:

```sh
./scripts/setup-git-config.sh
```

It prints the current value of all 5 keys, then loops a numbered menu to
pick one to change:

```text
Current --local git config:
  user.name        (not set)
  user.email       (not set)
  user.signingkey  (not set)
  gpg.format       (not set)
  commit.gpgsign   (not set)

Select a config key to set:
  1) user.name
  2) user.email
  3) user.signingkey
  4) gpg.format
  5) commit.gpgsign
  0) Exit
```

Each field shows its current value as the default (press Enter to keep
it):

| Key               | Input style          | Valid values / rule                         |
| ----------------- | -------------------- | ------------------------------------------- |
| `user.name`       | free text            | non-empty                                   |
| `user.email`      | free text            | non-empty, must match a basic email pattern |
| `user.signingkey` | free text            | non-empty (a GPG key ID or SSH key path)    |
| `gpg.format`      | numbered choice list | `openpgp` \| `ssh` (default `openpgp`)      |
| `commit.gpgsign`  | numbered choice list | `true` \| `false` (default `false`)         |

Invalid input re-prompts instead of exiting. Exiting the repo guard
(`gitcfg_require_repo`) aborts with exit status 1 if you're not inside a
git work tree.

**Idempotent**: setting a key to the value it already has is a no-op — no
`git config` call is made, and the script reports `<key> already set to
<value> (no change)` instead of `<key> set to <value>`. Re-running the
script with the same answers any number of times is always safe.

## format-and-lint.sh

Format then lint every supported file type in this repo, using the exact
commands documented in root `CLAUDE.md`'s "Linting and formatting"
section, as one entrypoint instead of six copy-pasted commands.

Run from the repo root or any subdirectory of this git work tree:

```sh
./scripts/format-and-lint.sh
```

Steps, in order (format first, then lint each language):

1. `prettier --write .` (via `npx`)
2. `markdownlint-cli2 --fix "**/*.md"` (via `npx`)
3. `yamllint .` — skipped with a warning if `yamllint` isn't on PATH
4. `shellcheck` on every `*.sh` file not in `.shellcheckignore` — skipped
   with a warning if `shellcheck` isn't on PATH
5. `hadolint` on every `Dockerfile*` not in `.hadolintignore` — skipped
   with a warning if `hadolint` isn't on PATH
6. `ruff format .` then `ruff check --fix .` — skipped with a warning if
   `ruff` isn't on PATH

All steps run even if an earlier one fails, so one pass gives the full
picture; the script exits non-zero if any step that ran failed.

**Idempotent**: re-running against an already-formatted, lint-clean repo
is a no-op pass — `prettier`/`markdownlint-cli2` make no further changes,
and every lint step is read-only.

## install-git-hooks.sh

Idempotently points this repo's `--local` `core.hooksPath` at
`.githooks/` (see that directory's own README) so the `pre-commit`
(format + lint) hook actually runs.

Run from the repo root or any subdirectory of this git work tree:

```sh
./scripts/install-git-hooks.sh
```

**Idempotent**: reuses `gitcfg_local_set`'s own idempotent-write
behavior — re-running when `core.hooksPath` is already `.githooks` is a
no-op.

## lib/

Mostly one function per file (a couple group a handful of closely-related
steps), named `<namespace>_<name>.sh` → defines
`<namespace>_<name>()`. Two namespaces live here: `gitcfg_` (git-config
specific, used only by `setup-git-config.sh`) and `devkit_` (repo-wide —
logging, command checks, a step runner — reusable by any script in this
directory). Every function and the one global (`GITCFG_CONFIG_KEYS`, in
`gitcfg_print_config.sh`) is namespaced on purpose: `scripts/lib/` is a
shared sourcing target for every script in this repo, and a generic name
like `prompt_text` or `is_non_empty` would be free to collide with an
unrelated same-named function defined by another script's own lib files.

| File                        | Function                                                                                     | Purpose                                                                         |
| --------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `gitcfg_require_repo.sh`    | `gitcfg_require_repo`                                                                        | Exit 1 if not inside a git work tree.                                           |
| `gitcfg_local_get.sh`       | `gitcfg_local_get`                                                                           | Read a `--local` config value (empty string if unset).                          |
| `gitcfg_local_set.sh`       | `gitcfg_local_set`                                                                           | Idempotently write a `--local` config value; logs the outcome.                  |
| `gitcfg_print_config.sh`    | `gitcfg_print_config`                                                                        | Print all 5 managed keys' current values.                                       |
| `gitcfg_is_non_empty.sh`    | `gitcfg_is_non_empty`                                                                        | Validator: non-empty string.                                                    |
| `gitcfg_is_valid_email.sh`  | `gitcfg_is_valid_email`                                                                      | Validator: basic email syntax check.                                            |
| `gitcfg_prompt_text.sh`     | `gitcfg_prompt_text`                                                                         | Free-text prompt with default + validator, re-prompts on failure.               |
| `gitcfg_prompt_choice.sh`   | `gitcfg_prompt_choice`                                                                       | Numbered choice-list prompt for fields with a fixed value set.                  |
| `gitcfg_edit_user_name.sh`  | `gitcfg_edit_user_name`                                                                      | Prompt + idempotently set `user.name`.                                          |
| `gitcfg_edit_user_email.sh` | `gitcfg_edit_user_email`                                                                     | Prompt + idempotently set `user.email`.                                         |
| `gitcfg_edit_signingkey.sh` | `gitcfg_edit_signingkey`                                                                     | Prompt + idempotently set `user.signingkey`.                                    |
| `gitcfg_edit_gpg_format.sh` | `gitcfg_edit_gpg_format`                                                                     | Prompt + idempotently set `gpg.format`.                                         |
| `gitcfg_edit_gpgsign.sh`    | `gitcfg_edit_gpgsign`                                                                        | Prompt + idempotently set `commit.gpgsign`.                                     |
| `devkit_log_info.sh`        | `devkit_log_info`                                                                            | Print `[INFO] <msg>` to stdout.                                                 |
| `devkit_log_success.sh`     | `devkit_log_success`                                                                         | Print `[OK] <msg>` to stdout.                                                   |
| `devkit_log_warn.sh`        | `devkit_log_warn`                                                                            | Print `[WARN] <msg>` to stderr.                                                 |
| `devkit_log_error.sh`       | `devkit_log_error`                                                                           | Print `[ERROR] <msg>` to stderr.                                                |
| `devkit_command_exists.sh`  | `devkit_command_exists`                                                                      | Validator: is a command on PATH.                                                |
| `devkit_run_step.sh`        | `devkit_run_step`                                                                            | Run + log a labeled command; returns its exit status without tripping `set -e`. |
| `devkit_format.sh`          | `devkit_format_prettier`, `devkit_format_markdownlint`, `devkit_format_ruff`                 | Thin `devkit_run_step` wrappers for each formatting step.                       |
| `devkit_lint.sh`            | `devkit_lint_yamllint`, `devkit_lint_shellcheck`, `devkit_lint_hadolint`, `devkit_lint_ruff` | Thin `devkit_run_step` wrappers for each lint step.                             |

Every file documents its own args / stdout / exit status in a header
comment — read the file directly for the exact contract before reusing a
function.

### Reusing a function in another script

Source only the file(s) you need (each is self-contained aside from the
documented dependencies noted in its header):

```sh
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/devkit_log_info.sh disable=SC1091
source "${script_dir}/../scripts/lib/devkit_log_info.sh"
# shellcheck source=lib/devkit_log_success.sh disable=SC1091
source "${script_dir}/../scripts/lib/devkit_log_success.sh"
# shellcheck source=lib/devkit_log_error.sh disable=SC1091
source "${script_dir}/../scripts/lib/devkit_log_error.sh"
# shellcheck source=lib/gitcfg_local_get.sh disable=SC1091
source "${script_dir}/../scripts/lib/gitcfg_local_get.sh"
# shellcheck source=lib/gitcfg_local_set.sh disable=SC1091
source "${script_dir}/../scripts/lib/gitcfg_local_set.sh"

gitcfg_local_set user.email "you@example.com"
```

Lib files never call `set -euo pipefail` themselves — sourcing one won't
silently flip strict mode on in your script; set it yourself if you want
it.

## Requirements

`bash`, `git` for `setup-git-config.sh` and `install-git-hooks.sh`. `format-and-lint.sh` additionally
needs `npx` (for `prettier` and `markdownlint-cli2`, fetched on demand);
`yamllint`, `shellcheck`, `hadolint`, and `ruff` are optional — each step is
skipped with a warning if its binary isn't on PATH.

## Linting

Covered by the repo-wide shell lint command in `CLAUDE.md`
(`shellcheck`, config `.shellcheckrc`) — no separate setup needed for
scripts added here.
