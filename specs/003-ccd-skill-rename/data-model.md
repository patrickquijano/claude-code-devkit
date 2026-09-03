# Data Model: the entities a rename moves

**Feature**: [003-ccd-skill-rename](./spec.md) | **Date**: 2026-09-03

There is no database and no runtime data here. The entities are files and the names that link them, and modelling them is worth doing for one reason: the rename's failure mode is a **broken link between two entities**, not a bad value inside one. Naming the links is what makes them countable.

## Distributed skill

One of the five things the plugin ships that a user can start by name.

| Field              | Value after this feature                              | Constraint                                                                |
| ------------------ | ----------------------------------------------------- | ------------------------------------------------------------------------- |
| `directory`        | `skills/ccd-<slug>/`                                  | Must exist; must be a direct child of `skills/`                           |
| `frontmatter_name` | `ccd-<slug>`                                          | **MUST equal `basename(directory)`** — FR-002                             |
| `resolvable_name`  | `claude-code-devkit:ccd-<slug>`                       | Derived: plugin name, colon, `frontmatter_name`                           |
| `bare_name`        | `ccd-<slug>`                                          | **MUST NOT collide** with the personal skill it was derived from — FR-003 |
| `description`      | unchanged except where it embeds a slash-command form | Governs automatic invocation                                              |
| `model_invocable`  | `true` for four; `false` for the pipeline skill       | Exactly one `false` — FR-004                                              |

### The five instances

| Directory                 | `frontmatter_name` | Resolvable name                      | Model-invocable | Was                |
| ------------------------- | ------------------ | ------------------------------------ | --------------- | ------------------ |
| `skills/ccd-speckit-run/` | `ccd-speckit-run`  | `claude-code-devkit:ccd-speckit-run` | no              | `speckit-run`      |
| `skills/ccd-branch-push/` | `ccd-branch-push`  | `claude-code-devkit:ccd-branch-push` | yes             | `auto-branch-push` |
| `skills/ccd-commit-push/` | `ccd-commit-push`  | `claude-code-devkit:ccd-commit-push` | yes             | `auto-commit-push` |
| `skills/ccd-github-pr/`   | `ccd-github-pr`    | `claude-code-devkit:ccd-github-pr`   | yes             | `auto-github-pr`   |
| `skills/ccd-gitlab-mr/`   | `ccd-gitlab-mr`    | `claude-code-devkit:ccd-gitlab-mr`   | yes             | `auto-gitlab-mr`   |

Note the two names that are **not** a mechanical `ccd-` + old name: `auto-branch-push` becomes `ccd-branch-push`, not `ccd-auto-branch-push`. The `auto-` prefix is dropped from all four `auto-*` skills; `speckit-run` keeps its whole name. A substitution rule of the form `s/^/ccd-/` would produce four wrong names, which is why the rename is a table lookup and not a pattern.

## Reference

Any place one entity names another. The unit that a rename breaks, and the unit SC-002 and SC-003 count over.

| Form                | Shape                                                   | Breaks how                                                                                    |
| ------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Bundled path        | `${CLAUDE_PLUGIN_ROOT}/skills/<name>/scripts/<file>.sh` | Script not found at run time, when the skill asks its first question                          |
| Namespaced dispatch | `claude-code-devkit:<name>`                             | `Skill` tool call fails; on the pipeline skill this lands at Step 6, at the end of a full run |
| Slash-command       | `/<name> <some request>`                                | A documented invocation the reader copies and it does nothing                                 |
| Frontmatter `name`  | `name: <name>`                                          | Skill answers to a name its directory contradicts                                             |
| Prose               | "…exists once, in `<name>`"                             | Nothing breaks; the reader is told something false                                            |

Relationships that must hold after the change:

- Every `Reference` whose target is one of the five resolves to an existing `Distributed skill`.
- No `Reference` in live content names a retired name (FR-006).
- A `Reference` inside `specs/001-*` or `specs/002-*` is **historical**, not live, and is left alone (FR-017).

## Shared helper

The single branch-candidate lister. One owner, four consumers.

| Field            | Value                                                                  |
| ---------------- | ---------------------------------------------------------------------- |
| `path`           | `skills/ccd-branch-push/scripts/branch-options.sh`                     |
| `owner`          | `ccd-branch-push`                                                      |
| `consumers`      | `ccd-branch-push`, `ccd-github-pr`, `ccd-gitlab-mr`, `ccd-speckit-run` |
| `copies_in_tree` | Exactly **1** — FR-008, SC-005                                         |

The cardinality is the invariant. Four consumers reaching one file is what makes them agree by construction; a second copy makes them agree only by comparison, which is how a divergent fork survived unnoticed once already.

## Superseded record

A published statement of the five names, or of the helper's location, as it stood before this change.

| Instance                                                     | Gains                                                       | Otherwise |
| ------------------------------------------------------------ | ----------------------------------------------------------- | --------- |
| `specs/002-vendor-plugin-skills/contracts/skill-names.md`    | one superseded-by line naming `specs/003-ccd-skill-rename/` | unchanged |
| `specs/002-vendor-plugin-skills/contracts/branch-options.md` | one superseded-by line naming `specs/003-ccd-skill-rename/` | unchanged |

## Excluded from the model

Named because they contain the string `speckit-run` and are deliberately **not** entities of this model — FR-014:

- `.specify/.speckit-run-state.json` — bookkeeping filename, referenced by `.gitignore:11` and by the pipeline skill's own scripts
- `.specify/.speckit-dirty-snapshot` — same
- `speckit-run-base-switch` — a git stash message

None of the three is addressable by a user, and none participates in any relationship above.

## Validation rules, gathered

1. `count(skills/*/) == 5`, and every basename matches `^ccd-`.
2. For each of the five, `frontmatter_name == basename(directory)`.
3. `count(disable-model-invocation across skills/) == 1`, on `ccd-speckit-run`.
4. `count(branch-options.sh in tree) == 1`, under `ccd-branch-push/scripts/`.
5. `count(old names in live content) == 0`, where live content excludes `specs/`.
6. No reference resolves to a path or name that does not exist.

`quickstart.md` turns each of these into a command.
