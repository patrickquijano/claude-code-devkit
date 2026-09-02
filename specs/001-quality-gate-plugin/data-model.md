# Data Model: Repository Quality Gate and Plugin Packaging

**Date**: 2026-09-02 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

No database, no persisted records. The entities below are configuration and process shapes — the things the implementation must keep consistent with each other. Field names are the literal keys or variables the implementation uses, so a reader can trace an entity to the file that holds it.

## Content standard

One kind of content, its rule set, and the one check that evaluates it. Six instances, fixed at design time.

| Field            | Type                     | Notes                                                                           |
| ---------------- | ------------------------ | ------------------------------------------------------------------------------- |
| `id`             | slug                     | `markdown`, `yaml`, `shell`, `python`, `format`, `editorconfig`                 |
| `config_path`    | repo-relative path       | exactly one per standard — Quality Gate Requirements demands one governing file |
| `file_globs`     | list of glob             | passed to `git ls-files` as the positive pathspec                               |
| `native_command` | command name             | resolved with `command -v`                                                      |
| `image_ref`      | `name:tag@sha256:digest` | from `scripts/lib/images.sh`                                                    |
| `supports_fix`   | boolean                  | false for `shell`, `yaml`, `editorconfig`                                       |
| `runner_path`    | repo-relative path       | `scripts/lint-<id>.sh`                                                          |

Instances:

| id             | config_path                | file_globs           | native_command         | supports_fix |
| -------------- | -------------------------- | -------------------- | ---------------------- | ------------ |
| `markdown`     | `.markdownlint-cli2.jsonc` | `*.md`, `*.markdown` | `markdownlint-cli2`    | yes          |
| `yaml`         | `.yamllint.yml`            | `*.yml`, `*.yaml`    | `yamllint`             | no           |
| `shell`        | `.shellcheckrc`            | `*.sh`               | `shellcheck`           | no           |
| `python`       | `ruff.toml`                | `*.py`, `*.pyi`      | `ruff`                 | yes          |
| `format`       | `.prettierrc.json`         | `*.json`, `*.jsonc`  | `prettier`             | yes          |
| `editorconfig` | `.editorconfig`            | all in-scope files   | `editorconfig-checker` | no           |

**Validation rules**

- `config_path` MUST exist and MUST be inside the checked scope. A configuration file exempt from its own standard is a standard nobody checks.
- `image_ref` MUST match `^[a-z0-9./-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$`. A reference without both a tag and a digest fails Principle III.
- Exactly one standard MAY claim any given `native_command`.
- `supports_fix = false` MUST NOT mean `--fix` errors; it means `--fix` reports and leaves files untouched (FR-012a).

## Scope declaration

One instance: `.lintignore`.

| Field      | Type                 | Notes                                                   |
| ---------- | -------------------- | ------------------------------------------------------- |
| `patterns` | list of path or glob | one per line; `#` starts a comment; blank lines ignored |

**Validation rules**

- MUST be the only declaration of exclusion used for scope (FR-013a). A pattern added to a tool's own configuration instead is a defect, not a shortcut.
- Every pattern MUST be interpretable as a git pathspec after `:(exclude)` is prefixed.
- The set MUST cover, at minimum: `.git`, `.specify/`, `.claude/logs/`, `.claude/settings.local.json`, `.claude/skills/speckit-*`, `.remember/`, `node_modules/`, `.venv/`.

## File list

Derived, never stored. Produced by `scope.sh` per invocation.

| Field   | Type                              | Notes                                                                              |
| ------- | --------------------------------- | ---------------------------------------------------------------------------------- |
| `paths` | NUL-separated repo-relative paths | NUL-separated because a path may contain whitespace and the runners are POSIX `sh` |

**Validation rules**

- MUST be computed once per check, from the scope declaration plus the standard's `file_globs`.
- An empty list MUST produce a success verdict with an explicit "no files in scope" line, not a failure and not silence.

## Check invocation

The runtime shape of one check running.

| Field         | Type                                     | Notes                                                    |
| ------------- | ---------------------------------------- | -------------------------------------------------------- |
| `standard`    | content standard                         | which check                                              |
| `mode`        | `check` \| `fix`                         | `fix` only when `--fix` was passed                       |
| `resolution`  | `native` \| `container` \| `unavailable` | the outcome of the three-step resolution                 |
| `mount`       | `ro` \| `rw` \| none                     | `ro` in check mode, `rw` in fix mode, absent when native |
| `exit_status` | integer                                  | 0 pass, non-zero fail                                    |

**State transitions** — the resolution order is fixed and total:

```text
start
  ├─ command -v <native_command> succeeds ──────────→ resolution = native
  ├─ else command -v docker succeeds ───────────────→ resolution = container
  └─ else ──────────────────────────────────────────→ resolution = unavailable
                                                       exit non-zero, name both (FR-011)
```

**Validation rules**

- `mode = check` MUST imply `mount = ro` when `resolution = container`. This is what makes SC-007 structural rather than behavioural.
- `resolution = unavailable` MUST exit non-zero and MUST name both the missing command and the missing runtime.
- `exit_status = 0` after a `fix` run that rewrote files (FR-005a). Rewriting is success, not a violation left standing.

## Aggregate run

One instance per invocation of `scripts/lint.sh`.

| Field           | Type                        | Notes                                     |
| --------------- | --------------------------- | ----------------------------------------- |
| `mode`          | `check` \| `fix`            | passed through to every check             |
| `order`         | ordered list of standard id | fixed, so failures are reproducible       |
| `first_failure` | standard id \| none         | the run stops here                        |
| `exit_status`   | integer                     | 0 only if every check that ran returned 0 |

**Validation rules**

- MUST stop at `first_failure` (FR-007). A combined report at the end is a different requirement and not this one.
- `order` MUST be deterministic and declared in the script, not derived from directory listing order.

## Plugin manifest

One instance: `.claude-plugin/plugin.json`.

| Field                    | Type                 | Required | Value                 |
| ------------------------ | -------------------- | -------- | --------------------- |
| `name`                   | kebab-case string    | yes      | `claude-code-devkit`  |
| `displayName`            | string               | no       | human-readable name   |
| `description`            | string               | no       | from `README.md`      |
| `version`                | semver string        | no       | `0.1.0`               |
| `author`                 | `{name, email, url}` | no       | repository owner      |
| `homepage`, `repository` | URL                  | no       | the GitHub repository |
| `license`                | SPDX identifier      | no       |                       |
| `keywords`               | list of string       | no       | discovery tags        |

**Validation rules**

- `name` MUST be `claude-code-devkit` (FR-016) and MUST be kebab-case.
- No component-path field (`skills`, `commands`, `agents`, `workflows`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`) is declared while the corresponding directory does not exist. For `commands`, `agents`, `workflows` and `outputStyles` a declared path _replaces_ the default directory, so a path to nothing is worse than silence.
- The file MUST be valid JSON and MUST pass the `format` standard, since it is in scope.
- Spec Kit's generated `.claude/skills/speckit-*` MUST NOT be vendored into the plugin.

## Concern

Added by the 2026-09-02 amendment. What a check evaluates _about_ a content kind. The constitution at v1.2.0 permits one governing configuration per content kind per concern, and forbids two of either.

**Values**: `format` — how the content is laid out, and something rewrites it. `lint` — properties of the content that no formatter can produce or repair.

**Guarantees**:

- A content kind has at most one configuration governing `format` and at most one governing `lint`.
- A rule that the `format` concern rewrites MUST NOT also be enforced by the `lint` concern for the same content kind. The hazard is not duplicate reporting, which is harmless; it is two tools rewriting one file, where the result depends on which ran last.
- A rule the formatter does not rewrite stays with `lint` even when it looks like formatting. `comments` and `comments-indentation` in the YAML linting standard are the worked example: Prettier preserves YAML comments and enforces nothing about them, so moving those rules out would delete a check rather than relocate it.

**Present assignment**:

| Content kind             | `format`                                    | `lint`                                                                                                                         |
| ------------------------ | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Markdown                 | `.prettierrc.json`                          | `.markdownlint-cli2.jsonc`, less the 22 rules Prettier rewrites                                                                |
| YAML                     | `.prettierrc.json`                          | `.yamllint.yml`, less the 10 rules Prettier rewrites                                                                           |
| JSON, JSONC              | `.prettierrc.json`                          | none                                                                                                                           |
| XML                      | `.prettierrc.json`, via an add-on component | none                                                                                                                           |
| Shell                    | `.prettierrc.json`, via an add-on component | `.shellcheckrc`                                                                                                                |
| Python                   | `ruff.toml`                                 | `ruff.toml` — one tool, one file, both concerns; permitted, since the limit is one configuration per concern, not one per tool |
| Whitespace, line endings | `.editorconfig`                             | `.editorconfig-checker.json` for its own exclusions                                                                            |

## Add-on component

A unit extending the formatting tool to a content kind its base does not handle.

**Attributes**: package identifier; exact pinned version; the content kind it serves; a resolution state at run time, one of `resolved-native`, `resolved-container`, `absent`.

**Guarantees**:

- Pinned by exact version, never a range, for the same reason images carry a digest.
- Its peer requirement is satisfied by the pinned base tool. `@prettier/plugin-xml@3.4.2` requires `prettier@^3.0.0`; `prettier-plugin-sh@0.19.0` requires `prettier@^3.6.0`; the pin is `3.9.6`.
- Never a precondition. `absent` on the native path routes that content kind to the container path, where the component is pinned — the same handling as an absent tool (FR-023).
- Its resolution state is reported on every run. A component that resolved and one that was absent must not produce identical output, or an absent component reads as a clean result.

**Validation rules**:

- A declared component with no pinned version is invalid.
- A component whose peer requirement excludes the pinned base tool version is invalid, and is a configuration error rather than a run-time fallback.

## Capability extension

A unit adding commands and lifecycle hooks to the repository's spec-tooling.

**Attributes**: identifier; version; source catalog, `default` or `community`; provenance, a name for a vetted-catalog install or an exact archive URL otherwise; declared effect, `read-only` or `read-write`; enabled flag; resolution priority; and a set of hook registrations.

**Guarantees**:

- Installed _and_ enabled. Installed-but-disabled does not satisfy FR-024 — the capability is not available, which is what the requirement is about.
- Provenance recorded in the written record when the source is anything other than the vetted catalog (FR-026), including the exact URL, the version, and the effect.
- Its configuration is committed, including the hook ranks, so a clone reproduces the ordering.

**Note on the two priorities, because they are easy to confuse**: the extension's _resolution_ priority decides which extension wins when two provide the same template or command, and is what `specify extension set-priority` sets. It is not the hook order.

## Hook registration

One entry in `.specify/extensions.yml` under `hooks.<event>`.

**Attributes**: `extension`, `command`, `enabled`, `optional`, `priority`, `prompt`, `description`, `condition`.

**Guarantees**:

- `priority` is an integer of at least 1. Anything missing, non-numeric, boolean, zero or negative is normalised to 10.
- Execution order at one event is `priority` ascending, lower first, with a stable tie-break on insertion order. A tie is therefore resolved by install order, which is why FR-025 requires the ranks be explicit rather than left at the default.
- Ranks follow the written principle: observe before mutate, commit last (FR-025a).

**State transition worth stating, because it destroys configuration**: installing, reinstalling, updating or `--force`-ing an extension purges its entries for each event and re-adds them from its manifest. Since no extension in this set ships a hook priority, every re-install returns its hooks to 10. The ranks are therefore a committed artifact that must be re-applied after any extension update, and the principle is written beside them so that re-applying does not require re-deriving.

## Proposal structure

The content a change proposal arrives pre-filled with. Three exist, and they are not interchangeable:
one is applied automatically and two are selected by URL.

| Field        | Value                                                                                                                                                |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Identity     | its path. `.github/pull_request_template.md` for the general one; a filename inside `.github/PULL_REQUEST_TEMPLATE/` for each specialised one        |
| Application  | **automatic** for the general one, **opt-in** for the specialised ones, selected as `?template=<filename>.md`                                        |
| Content kind | Markdown. Not YAML: issue forms are not supported for pull requests, so there are no typed or required fields                                        |
| Sections     | a level-one heading, then the author-facing sections, then the reviewer-facing section                                                               |
| Citations    | zero or more, each a `<!-- cite: <path> -->` marker followed by a blockquote                                                                         |
| Governed by  | `.prettierrc.json` for formatting, `.markdownlint-cli2.jsonc` for linting, `.editorconfig` for whitespace — one configuration per concern, unchanged |
| Verified by  | `scripts/lint-citations.sh` for citation fidelity only                                                                                               |

Invariants, each traceable to a requirement:

- Exactly one structure is applied automatically (FR-028). A layout with only specialised structures
  yields an empty proposal body.
- No obligation carried by FR-030 or FR-031 appears only in a specialised structure (FR-033, SC-019).
  This is why the specialised files repeat the general one's sections rather than referring to them.
- A specialised structure asks at least one question the general one does not (FR-032, SC-021).
- Every structure opens with a level-one heading (MD041, research.md §22). Not a requirement of the
  feature — a consequence of the repository's own Markdown standard.

## Governance obligation

A normative requirement in the constitution that applies before or during review. Two exist.

| Field      | Value                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------- |
| Source     | a path and a section in `.specify/memory/constitution.md`                                     |
| Wording    | the sentence as currently written there, which is **hard-wrapped across lines**               |
| Applies    | before review (the check must have run and passed) or during it (compliance must be verified) |
| Carried by | the general structure, always. Never only by a specialised one                                |

The two: Development Workflow's pre-review check requirement, and Governance's principle-compliance
requirement. Both are quoted rather than paraphrased, so that `lint-citations.sh` can compare them.

## Citation

A quotation of a governed document inside a proposal structure, in a form a script can find.

| Field      | Value                                                                                           |
| ---------- | ----------------------------------------------------------------------------------------------- |
| Marker     | `<!-- cite: <repo-relative path> -->` on its own line                                           |
| Quotation  | the blockquote lines immediately following, joined to one line with `>` stripped                |
| Match rule | the quotation must appear in the cited file after both sides are whitespace-normalised          |
| Failure    | `scripts/lint-citations.sh` exits `1` and names the template, the cited path, and the quotation |

State transitions: a citation is **matching** until the cited document is amended, at which point it
becomes **stale**. Nothing detects the transition at the moment it happens; the next aggregate check run
does. There is no third state — a citation whose cited file does not exist is reported as stale with the
missing path named, not skipped.
