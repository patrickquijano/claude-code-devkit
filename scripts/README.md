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

## lib/

One function per file, named `gitcfg_<name>.sh` → defines `gitcfg_<name>()`.
Every function and the one global (`GITCFG_CONFIG_KEYS`, in
`gitcfg_print_config.sh`) is `gitcfg_`-namespaced on purpose: `scripts/lib/`
is a shared sourcing target for other scripts in this repo, and a generic
name like `prompt_text` or `is_non_empty` would be free to collide with an
unrelated same-named function defined by another script's own lib files.

| File                        | Function                 | Purpose                                                              |
| --------------------------- | ------------------------ | -------------------------------------------------------------------- |
| `gitcfg_require_repo.sh`    | `gitcfg_require_repo`    | Exit 1 if not inside a git work tree.                                |
| `gitcfg_local_get.sh`       | `gitcfg_local_get`       | Read a `--local` config value (empty string if unset).               |
| `gitcfg_local_set.sh`       | `gitcfg_local_set`       | Idempotently write a `--local` config value; prints the status line. |
| `gitcfg_print_config.sh`    | `gitcfg_print_config`    | Print all 5 managed keys' current values.                            |
| `gitcfg_is_non_empty.sh`    | `gitcfg_is_non_empty`    | Validator: non-empty string.                                         |
| `gitcfg_is_valid_email.sh`  | `gitcfg_is_valid_email`  | Validator: basic email syntax check.                                 |
| `gitcfg_prompt_text.sh`     | `gitcfg_prompt_text`     | Free-text prompt with default + validator, re-prompts on failure.    |
| `gitcfg_prompt_choice.sh`   | `gitcfg_prompt_choice`   | Numbered choice-list prompt for fields with a fixed value set.       |
| `gitcfg_edit_user_name.sh`  | `gitcfg_edit_user_name`  | Prompt + idempotently set `user.name`.                               |
| `gitcfg_edit_user_email.sh` | `gitcfg_edit_user_email` | Prompt + idempotently set `user.email`.                              |
| `gitcfg_edit_signingkey.sh` | `gitcfg_edit_signingkey` | Prompt + idempotently set `user.signingkey`.                         |
| `gitcfg_edit_gpg_format.sh` | `gitcfg_edit_gpg_format` | Prompt + idempotently set `gpg.format`.                              |
| `gitcfg_edit_gpgsign.sh`    | `gitcfg_edit_gpgsign`    | Prompt + idempotently set `commit.gpgsign`.                          |

Every file documents its own args / stdout / exit status in a header
comment — read the file directly for the exact contract before reusing a
function.

### Reusing a function in another script

Source only the file(s) you need (each is self-contained aside from the
documented dependencies noted in its header):

```sh
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

`bash`, `git`. No other dependencies.

## Linting

Covered by the repo-wide shell lint command in `CLAUDE.md`
(`shellcheck`, config `.shellcheckrc`) — no separate setup needed for
scripts added here.
