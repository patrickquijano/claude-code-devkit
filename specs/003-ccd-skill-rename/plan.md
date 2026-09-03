# Implementation Plan: Unambiguous skill names and a standards-conforming front page

**Branch**: `003-ccd-skill-rename` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-ccd-skill-rename/spec.md`

## Summary

Five skill directories move to a `ccd-` prefix, each `SKILL.md`'s frontmatter `name` moves with its directory, and every reference to the old names in the plugin's live content is rewritten. `README.md` is rebuilt to the Standard Readme section order and an MIT `LICENSE` is added to back the licence the manifest already declares. Two contract files under `specs/002-vendor-plugin-skills/` gain a superseded-by pointer and are otherwise untouched.

The whole change is text: Markdown, YAML frontmatter, and shell header comments. No script logic changes, no configuration changes, no new dependency, no new container image. The risk is not in any single edit but in the count — 328 occurrences across 33 files — and in the fact that a missed reference fails silently at dispatch time rather than loudly at install time.

## Technical Context

**Language/Version**: Markdown and YAML frontmatter throughout; POSIX `sh` for the six scripts whose header comments are touched. No compiled language, no runtime version to pin.

**Primary Dependencies**: Claude Code's plugin and skill loader, which resolves `skills/<dir>/SKILL.md` and namespaces each as `claude-code-devkit:<frontmatter name>`. No package dependency is added or removed.

**Storage**: N/A — the repository's files are the artifact.

**Testing**: `scripts/lint.sh`, the repository's existing aggregate quality check, which must exit `0`; plus `claude plugin validate . --strict` for manifest and structure. Neither is added by this feature.

**Target Platform**: Any machine running Claude Code with this plugin installed from its marketplace entry.

**Project Type**: Claude Code plugin — a documentation-and-skills repository, not an application.

**Performance Goals**: N/A. Nothing this feature touches runs in a hot path.

**Constraints**: The rename must be complete in one change; FR-016 forbids an alias or stub, so there is no partial-migration state to fall back to. `git mv` is required rather than delete-and-create, so that `git log --follow` still reaches each skill's history. Markdown is written one line per paragraph with no hard wrapping, matching every existing file in the repository.

**Scale/Scope**: 5 directories, 5 frontmatter `name` fields, 328 de-duplicated occurrences across 33 files, 1 new file (`LICENSE`), 1 rewritten file (`README.md`), 2 files gaining a single pointer line each.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Checked against `.specify/memory/constitution.md` v1.2.0.

| Principle                                | Bearing on this feature                                                                                                                                                                                            | Verdict                     |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------- |
| I. Tooling Independence (NON-NEGOTIABLE) | No new check is added, and no existing check's invocation changes. `scripts/lint.sh` keeps running under POSIX `sh` with its native-or-container fallback intact.                                                  | PASS                        |
| II. Fail Fast                            | No script's control flow is edited — only header comments. The existing first-failure exit behaviour is untouched.                                                                                                 | PASS                        |
| III. Pinned, Official Images             | No image reference is added, removed or repinned.                                                                                                                                                                  | PASS                        |
| IV. POSIX Shell Only                     | Six scripts are edited, in comment lines only. They must still pass shell static analysis in POSIX mode with zero findings; `scripts/lint-shell.sh` is the check.                                                  | PASS, verified by the check |
| V. Configuration Is Committed            | No linter or formatter configuration changes. In particular `.lintignore` gains no entry, so the five per-check ignore declarations stay in step and `scripts/lint-scope.sh` stays green.                          | PASS                        |
| VI. Spec-Driven Change                   | This feature has a spec, this plan, and will have a task list before any implementation.                                                                                                                           | PASS                        |
| Quality Gate Requirements                | No content kind gains a second governing configuration. `skills/` and `README.md` are already in scope for every check and stay in scope.                                                                          | PASS                        |
| Development Workflow                     | Branch `003-ccd-skill-rename` is cut from `main`, the repository's default branch. Artifacts live under `specs/003-ccd-skill-rename/`. The aggregate check runs before review. Machine-local state stays excluded. | PASS                        |
| Governance                               | Reviewers verify compliance; no added complexity to justify.                                                                                                                                                       | PASS                        |

No violations. The Complexity Tracking section is therefore omitted rather than left empty.

One point deserves stating rather than merely passing. Principle V's guarantee — the same verdict on every machine — is what makes the "no configuration change" line above load-bearing. The cheapest way to make a failing check pass is to add the failing path to `.lintignore`, and `scripts/lint-scope.sh` would then fail because the other five declarations no longer match. Neither is an acceptable route to SC-008; the spec's Assumptions section says so, and this plan restates it because Phase 8 is where the temptation actually arrives.

## Project Structure

### Documentation (this feature)

```text
specs/003-ccd-skill-rename/
├── plan.md                        # This file
├── research.md                    # Phase 0 output — the standards, cited, hard vs soft
├── data-model.md                  # Phase 1 output — the entities a rename moves
├── quickstart.md                  # Phase 1 output — how to prove the rename landed
├── contracts/
│   ├── skill-names.md             # supersedes 002's contract of the same name
│   └── branch-options.md          # supersedes 002's contract of the same name
├── checklists/
│   ├── requirements.md            # built-in spec-quality checklist, 16/16
│   └── requirements-quality.md    # reviewer-owned, 53 items
└── tasks.md                       # Phase 2 output — NOT created by /speckit-plan
```

### Source Code (repository root)

```text
skills/
├── ccd-speckit-run/               # RENAMED from speckit-run
│   ├── SKILL.md                   # name: ccd-speckit-run; keeps disable-model-invocation: true
│   ├── reference/                 # 13 files; base-branch, ship, preflight, worktree carry references
│   └── scripts/                   # 5 scripts; header comments name the skill
├── ccd-branch-push/               # RENAMED from auto-branch-push
│   ├── SKILL.md                   # name: ccd-branch-push
│   ├── evaluations.md
│   └── scripts/branch-options.sh  # THE single copy; 4 skills reference it at its new path
├── ccd-commit-push/               # RENAMED from auto-commit-push
├── ccd-github-pr/                 # RENAMED from auto-github-pr
│   └── templates/                 # unchanged; no skill name appears in them
└── ccd-gitlab-mr/                 # RENAMED from auto-gitlab-mr

README.md                          # REWRITTEN to Standard Readme
LICENSE                            # NEW — MIT, copyright Patrick Quijano
CLAUDE.md                          # amended: five names, plus the ccd- rationale bullet added at Step 2b
.claude-plugin/plugin.json         # UNCHANGED — still no skills field
.claude-plugin/marketplace.json    # UNCHANGED — renames maps plugin names, not skill names
.gitignore                         # UNCHANGED — line 11 keeps .specify/.speckit-run-state.json
specs/002-vendor-plugin-skills/contracts/skill-names.md      # +1 line, superseded-by pointer
specs/002-vendor-plugin-skills/contracts/branch-options.md   # +1 line, superseded-by pointer
```

**Structure Decision**: No new source layout. The repository is a Claude Code plugin whose components are auto-discovered from `skills/`, so the directory names under `skills/` _are_ the interface — which is why this feature is a directory move rather than a configuration edit. `.claude-plugin/plugin.json` deliberately declares no `skills` field: that field adds to the default scan rather than replacing it, so declaring it would be redundant, and the redundancy is the documented trap.

## Approach

### The rename mechanism

`git mv skills/<old> skills/<new>` for each of the five, so `git log --follow` still reaches each skill's history and the diff reads as a rename rather than a deletion plus an addition.

Directory basename and frontmatter `name` move together, in the same task, for each skill. For a plugin skill it is the frontmatter `name` that supplies the command segment, so a directory renamed without its `name` field yields a skill that lives at one path and answers to another — which is FR-002's failure mode and is invisible until someone tries to invoke it.

### The reference sweep

Five reference forms, each needing its own pass because a single search pattern catches only some of them:

| Form                | Example                                                                   | Where it appears                                                             |
| ------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Bundled-path        | `${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh` | each `SKILL.md`, `ccd-speckit-run/reference/*.md`                            |
| Namespaced dispatch | `claude-code-devkit:auto-commit-push`                                     | `ccd-speckit-run/reference/ship.md`, `forge-detect.sh`, cross-skill pointers |
| Slash-command       | `/auto-github-pr open a PR for this branch`                               | every `evaluations.md`, `ccd-speckit-run/SKILL.md` frontmatter `description` |
| Frontmatter `name`  | `name: auto-gitlab-mr`                                                    | the five `SKILL.md` files                                                    |
| Prose               | "`branch-options.sh` exists once, in `auto-branch-push`"                  | `CLAUDE.md`, `README.md`, `SKILL.md` bodies, script header comments          |

`forge-detect.sh` is the one script whose **output** carries a skill name — it prints `review-skill claude-code-devkit:auto-github-pr` — so its edit is to a string literal, not only to a comment. It still must remain POSIX `sh`.

### What is deliberately not renamed

`.specify/.speckit-run-state.json`, `.specify/.speckit-dirty-snapshot`, and the `speckit-run-base-switch` stash message all contain the string `speckit-run` and are none of them addressable names. Renaming the state file would require a matching `.gitignore` edit and would orphan the state of any run already in flight. `.gitignore:11` therefore stays exactly as it is. This is FR-014, and it is the reason the implementation cannot be a blind global substitution.

### README and LICENSE

`README.md` is rebuilt to the Standard Readme section order: title, a description under 120 characters, table of contents, Install, Usage, Contributing, License. Install covers adding the marketplace and installing the plugin. Usage presents the five skills under their new names with `ccd-speckit-run` as the entry point. Contributing points at the three existing templates in `.github/` rather than restating them. License names MIT, the copyright holder, and the `LICENSE` file.

The existing quality-checks content is not dropped. It moves under Usage, because running the checks is a thing a user of this repository does — FR-013 requires it survive, and Standard Readme has no separate section for it.

`LICENSE` is the MIT text, copyright Patrick Quijano, matching `plugin.json`'s `"license": "MIT"`. Adding it is what lets FR-012's licence statement point at something.

### The superseded records

One line each, added to `specs/002-vendor-plugin-skills/contracts/skill-names.md` and `contracts/branch-options.md`, naming `specs/003-ccd-skill-rename/`. Nothing else in `specs/001-quality-gate-plugin/` or `specs/002-vendor-plugin-skills/` changes — those directories record what shipped at the time, and rewriting them would make 002's own rationale stop matching its own tables.

### Verification

`scripts/lint.sh` must exit `0`. It is not modified, and no path is added to `.lintignore` to make it pass.

`claude plugin validate . --strict` checks the manifest and structure, and treats unrecognised fields as errors under `--strict`.

Beyond the two commands, the checks that matter are counting ones, because the failure mode here is an omission rather than an error: exactly one `branch-options.sh` in the tree; exactly five directories under `skills/`, all `ccd-`-prefixed; each `SKILL.md`'s `name` equal to its directory basename; exactly one `disable-model-invocation`; and zero occurrences of the five old names in live content. `quickstart.md` carries these as runnable commands with expected outputs.

## Phase 0: research.md

Records each external rule this feature relies on with its authoritative source URL and a `HARD` or `SOFT` classification, per FR-018 and SC-009. The material rules are: frontmatter `name` driving a plugin skill's command segment; `skills` adding to rather than replacing the default scan; plugin skill namespacing and the personal-skill collision behaviour; `${CLAUDE_PLUGIN_ROOT}` semantics; `marketplace.json`'s `renames` covering plugin names only; `claude plugin validate --strict`; and the Standard Readme section order and the GitHub community-profile checklist. Where no authoritative source exists — notably a documented enumeration of what breaks when a skill is renamed — research.md says so rather than filling the gap.

## Phase 1: Design & Contracts

`data-model.md` describes the entities a rename moves: the distributed skill and its two names, the reference and its five forms, the shared helper and its four consumers, and the superseded record.

`contracts/skill-names.md` and `contracts/branch-options.md` restate, at the new names, the two interfaces 002 fixed. They are the reason 002's copies get a pointer rather than an edit.

`quickstart.md` carries the counting checks above as commands a reviewer can paste, each with its expected output.

## Complexity Tracking

Not applicable. The Constitution Check records no violation, so there is nothing to justify.
