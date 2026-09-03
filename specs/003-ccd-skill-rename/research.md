# Research: the standards this feature relies on

**Feature**: [003-ccd-skill-rename](./spec.md) | **Date**: 2026-09-03

FR-018 requires that every external rule this feature relies on carries its authoritative source and a statement of whether the rule is **enforced by tooling** or is **only a convention**. SC-009 makes that 100 per cent, with no uncited claim. This file is that record.

Two classifications are used throughout, and the difference matters at Phase 8:

- **HARD** — enforced by the tool. Getting it wrong produces a failure, whether loud or silent.
- **SOFT** — a documented convention or recommendation. Getting it wrong produces something that still works and is worse.

Where no authoritative source could be found, that is stated as a finding rather than filled in from general knowledge. Those gaps are the entries most worth re-checking when Claude Code's documentation next changes.

## 1. Skill naming and the frontmatter `name` field

| #   | Rule                                                                                                                                                                                     | Class | Source                                                                              |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ----------------------------------------------------------------------------------- |
| 1.1 | For a **plugin** skill, the frontmatter `name` supplies the final command segment: the skill is addressed as `/<plugin-name>:<frontmatter-name>`, not `/<plugin-name>:<directory-name>`. | HARD  | <https://code.claude.com/docs/en/plugins-reference>                                 |
| 1.2 | For a **personal** or **project** skill the directory name drives invocation and `name` acts as a display label; matching them anyway is recommended.                                    | SOFT  | <https://code.claude.com/docs/en/skills>                                            |
| 1.3 | `description` is what the model reads to decide whether a skill is relevant, so it governs automatic invocation.                                                                         | SOFT  | <https://code.claude.com/docs/en/skills>                                            |
| 1.4 | `disable-model-invocation: true` stops automatic invocation; the skill remains reachable when a user names it.                                                                           | HARD  | <https://code.claude.com/docs/en/skills>                                            |
| 1.5 | Skills are discovered from `~/.claude/skills/` (personal), `.claude/skills/` (project, searched upward from the working directory), and `<plugin>/skills/` (plugin).                     | HARD  | <https://code.claude.com/docs/en/skills>, <https://code.claude.com/docs/en/plugins> |

**Decision**: move each directory and its frontmatter `name` in the same step, never separately.

**Rationale**: 1.1 is the rule that makes this feature a two-part edit rather than a directory move. A directory renamed without its `name` field produces a skill that lives at `skills/ccd-github-pr/` and answers to `claude-code-devkit:auto-github-pr` — no error at load time, and the mismatch only surfaces when someone tries to invoke it or dispatch to it. FR-002 exists for this.

**Alternatives considered**: renaming only the frontmatter `name` and leaving the directories. Rejected — it satisfies 1.1 but leaves the tree unreadable, and every `${CLAUDE_PLUGIN_ROOT}` path in the repository would then point at a directory whose name contradicts the skill it holds.

**Gap, stated rather than filled**: no authoritative source was found for a character-set, regex, or length constraint on the `name` field, nor for a documented length limit on `description`. `ccd-`-prefixed kebab-case names are well within what every documented example uses, but this feature does not claim the docs guarantee it.

## 2. Plugin manifest and component discovery

| #   | Rule                                                                                                                                                                                     | Class | Source                                              |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------------------------- |
| 2.1 | `name` is the only required field in `plugin.json`, and must be kebab-case.                                                                                                              | HARD  | <https://code.claude.com/docs/en/plugins-reference> |
| 2.2 | A `skills` field **adds to** the default `skills/` scan rather than replacing it.                                                                                                        | HARD  | <https://code.claude.com/docs/en/plugins-reference> |
| 2.3 | `commands`, `agents`, `workflows`, `outputStyles` **replace** their default directories — the opposite of 2.2.                                                                           | HARD  | <https://code.claude.com/docs/en/plugins-reference> |
| 2.4 | Without any component-path field, a plugin's `skills/` subdirectories each containing a `SKILL.md` are auto-discovered.                                                                  | HARD  | <https://code.claude.com/docs/en/plugins>           |
| 2.5 | `license` takes an SPDX identifier.                                                                                                                                                      | SOFT  | <https://code.claude.com/docs/en/plugins-reference> |
| 2.6 | `claude plugin validate <path> [--strict]` validates manifest and structure; unrecognised fields are warnings, wrong field types are errors, and `--strict` promotes warnings to errors. | HARD  | <https://code.claude.com/docs/en/plugins-reference> |

**Decision**: `plugin.json` gains no `skills` field, and gains no component-path field of any kind.

**Rationale**: 2.4 already discovers all five, so 2.2 means declaring `skills` would list them a second time. This restates the decision feature 002 made and records why it survives a rename: the trap is that 2.3 makes the opposite true for four sibling fields, so anyone reasoning by analogy from `commands` reaches the wrong conclusion about `skills`.

## 3. Namespacing and the collision this feature exists to fix

| #   | Rule                                                                                                                                                           | Class | Source                                    |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ----------------------------------------- |
| 3.1 | Plugin skills are addressed as `/<plugin-name>:<skill-name>`, which is what prevents two plugins' same-named skills from colliding.                            | HARD  | <https://code.claude.com/docs/en/plugins> |
| 3.2 | A plugin skill and a personal skill sharing a base name **both remain available**; neither overrides the other, and they are invoked under different prefixes. | HARD  | <https://code.claude.com/docs/en/plugins> |

**Decision**: prefix the five bare names with `ccd-`.

**Rationale**: 3.2 is the whole justification, and it is the fact that makes the prefix look redundant while not being redundant. The namespace already disambiguates the **namespaced** form; nothing disambiguates the **bare** form, and the bare form is what a user types. On a machine that also has the personal `speckit-run` these skills were derived from, `ccd-speckit-run` is unambiguous where `speckit-run` is not. `CLAUDE.md` records this rationale so a later tidy-up does not remove the prefix as redundant.

**Alternatives considered**: relying on the namespace alone and changing nothing. Rejected — it leaves the bare name ambiguous, which is FR-003.

## 4. `${CLAUDE_PLUGIN_ROOT}`

| #   | Rule                                                                                                                | Class                        | Source                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------- |
| 4.1 | Expands to the absolute path of the plugin's installation directory.                                                | HARD                         | <https://code.claude.com/docs/en/plugins-reference>                       |
| 4.2 | Available in hook commands, MCP and LSP server configs, and component path fields.                                  | HARD                         | <https://code.claude.com/docs/en/plugins-reference>                       |
| 4.3 | Reported not to expand in hook commands defined in `hooks.json`, and not to be set in the hook's shell environment. | HARD, but community-reported | <https://gist.github.com/gofullthrottle/dca4f8fd46a32fb2a3c4561b6c7d137f> |

**Decision**: every bundled-path reference keeps using `${CLAUDE_PLUGIN_ROOT}/skills/<new-name>/...`; only the `<new-name>` segment changes.

**Rationale**: 4.1 is why no install location is written down anywhere in the five skills, and that property must survive the rename. 4.3 does not apply here — this plugin ships no `hooks.json` — but it is recorded because it is the one documented place the variable does not behave as 4.1 says, and a future hook in this plugin would hit it.

## 5. Renaming a skill: what couples

**No authoritative source found** enumerating what breaks when a skill is renamed. This is a genuine documentation gap, and the coupling points below are derived from the rules above rather than quoted from a page that lists them.

| Coupling point                        | Derived from                                                   |
| ------------------------------------- | -------------------------------------------------------------- |
| Frontmatter `name`                    | 1.1 — it is the command segment                                |
| Directory basename                    | 2.4 — it is what discovery walks                               |
| Cross-skill dispatch strings          | 3.1 — the namespaced name embeds the skill name                |
| Bundled `${CLAUDE_PLUGIN_ROOT}` paths | 4.1 — the path embeds the directory name                       |
| A user's typed invocation             | 1.1, 3.2 — the old name now reaches a different skill, or none |
| `marketplace.json` entries            | see 6.2 — not applicable here                                  |

**Decision**: treat the enumeration above as the rename's checklist, and verify it by counting rather than by inspection — see `quickstart.md`.

**Rationale**: an omission cannot be seen in a diff of the files that _were_ changed. Every check that matters here is a count over the whole tree.

## 6. Marketplace

| #   | Rule                                                                                                       | Class | Source                                                |
| --- | ---------------------------------------------------------------------------------------------------------- | ----- | ----------------------------------------------------- |
| 6.1 | `marketplace.json` requires `name`, `owner` and `plugins`; each plugin entry requires `name` and `source`. | HARD  | <https://code.claude.com/docs/en/plugin-marketplaces> |
| 6.2 | A `renames` field maps a **former plugin name** to its current name, or to `null` if removed (v2.1.193+).  | HARD  | <https://code.claude.com/docs/en/plugin-marketplaces> |

**Decision**: `marketplace.json` is unchanged, and no `renames` entry is added.

**Rationale**: 6.2 covers plugin names. This feature renames skills inside a plugin whose own name is unchanged (FR-014), so there is nothing for the map to map. Adding an entry would assert a plugin rename that did not happen.

**Alternatives considered**: adding `renames` anyway as a migration hint for the old skill names. Rejected — it would be a false statement in a manifest field with defined semantics.

## 7. README standards

| #   | Rule                                                                                                                                                                                                 | Class | Source                                                                                                                                      |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| 7.1 | Standard Readme's required sections, in order: Title; short description (under 120 characters); Table of Contents (required once the file exceeds 100 lines); Install; Usage; Contributing; License. | SOFT  | <https://github.com/RichardLitt/standard-readme/blob/main/spec.md>                                                                          |
| 7.2 | Optional sections and their recommended placement: Banner, Badges, Long Description, Security, Background, Extra Sections, API, Maintainers, Acknowledgements.                                       | SOFT  | <https://github.com/RichardLitt/standard-readme/blob/main/spec.md>                                                                          |
| 7.3 | The License section states the licence's full name or SPDX identifier, the owner, and the location of the licence text.                                                                              | SOFT  | <https://github.com/RichardLitt/standard-readme/blob/main/spec.md>                                                                          |
| 7.4 | GitHub's community profile checklist: description, README, CODE_OF_CONDUCT, CONTRIBUTING, LICENSE, security policy, issue templates, pull request template.                                          | SOFT  | <https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories> |
| 7.5 | Make a README and Awesome README are community resources, illustrative rather than prescriptive.                                                                                                     | SOFT  | <https://www.makeareadme.com>, <https://github.com/matiassingers/awesome-readme>                                                            |

**Decision**: follow 7.1 exactly for the section set and order; satisfy 7.3 by adding the `LICENSE` file; take only the LICENSE item from 7.4.

**Rationale**: 7.3 is the one that turns a presentation change into a correctness fix. `plugin.json` declares `"license": "MIT"` and no licence document exists, so today the claim is unbacked and the section required by 7.1 has nowhere to point. The rest of 7.4 — CONTRIBUTING, SECURITY, CODE_OF_CONDUCT — is explicitly out of scope per the spec's non-goals; the repository already carries a pull request template and two specialised variants, which is the part of 7.4 it does satisfy.

The existing quality-checks content is placed under Usage rather than dropped or given a section of its own. Standard Readme has no slot for it, 7.2's Extra Sections are permitted between Usage and API, and FR-013 requires it survive; putting it under Usage keeps the mandated order intact.

**Gap, stated rather than filled**: **no authoritative specification was found for how a Claude Code plugin's README should be structured.** Anthropic's plugin repositories show description, installation, usage, contributing and licence sections by example, but publish no spec. Standard Readme is therefore adopted as the external standard, with "Install" read as marketplace-and-plugin installation rather than a package manager command.

## 8. Repository-local rules that constrain the edit

These are not external standards, but they bind the implementation and are recorded so the plan's verification section can be taken at face value.

| #   | Rule                                                                                                                                                           | Class | Source                                                          |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------------------------------------- |
| 8.1 | `.lintignore` excludes neither `skills/` nor `README.md`, so both are fully governed by every check before and after this change.                              | HARD  | `.lintignore`                                                   |
| 8.2 | Each check also declares its own ignore list, and `scripts/lint-scope.sh` fails when any of the five diverges from `.lintignore`.                              | HARD  | `scripts/lint-scope.sh`                                         |
| 8.3 | `scripts/lint-citations.sh` scans only `.github/*.md` for `<!-- cite: -->` markers, so `README.md`'s plain links to the constitution are not citation-checked. | HARD  | `scripts/lint-citations.sh`                                     |
| 8.4 | `MD013` line-length is off; Markdown in this repository is one line per paragraph, deliberately.                                                               | HARD  | `.markdownlint-cli2.jsonc`                                      |
| 8.5 | Shell scripts are POSIX `sh` with zero static-analysis findings; no bashisms.                                                                                  | HARD  | `.specify/memory/constitution.md` Principle IV, `.shellcheckrc` |

**Decision**: change no lint configuration, and add no `.lintignore` entry.

**Rationale**: 8.1 and 8.2 together mean the cheapest way to silence a failing check is also the way that fails a different check. That is the mechanism Principle V exists to provide, and this feature relies on it rather than working around it.
