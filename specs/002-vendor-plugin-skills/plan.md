# Implementation Plan: Distribute the Toolkit's Own Skills

**Branch**: `002-vendor-plugin-skills` | **Date**: 2026-09-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-vendor-plugin-skills/spec.md`

## Summary

Five skills move from a personal, machine-local install into `skills/` at the repository root, where plugin auto-discovery already looks. Nothing about what they do changes. What changes is how they are found, and how they find each other: every reference by which one names another becomes the namespaced `claude-code-devkit:<name>`, every path by which one reaches a file it ships with becomes `${CLAUDE_PLUGIN_ROOT}`-rooted, and the entry point's start-of-run probe stops testing for a personal directory that a plugin install does not create.

Three decisions carry the design, and each is a decision the specification left open.

**First, the probe is the defect that matters, not the dispatch.** `speckit-run` decides at Step 0 whether it can hand work to its three companions by running `ls ~/.claude/skills/<name>/SKILL.md`. Under a plugin install those paths are absent, so all three read as missing, and the skill's own documented degradation takes over: the commit option disappears and the pull-request step is skipped with a recorded reason. The run then completes and **reports success** having produced neither. A broken dispatch would at least be visible; this is not. FR-008 exists for it, and `preflight.md` already names the right authority for the same question one paragraph earlier -- the session's own available-skills listing, with the path check as fallback.

**Second, one of the four helper copies is not a variant but a defective fork**, so FR-013's "which behaviour wins" has an evidence-based answer rather than a stylistic one. The 48-line copy in `speckit-run` emits the symbolic ref `origin` as though it were a branch, loses the current branch on an unborn HEAD, and cannot identify the default branch at all. The first of those was observed in this feature's own Step 1. The 88-line implementation the other three share fixes all three deliberately, with comments naming the traps. It wins, and the prose in `base-branch.md` documenting the old output contract has to be corrected as a consequence -- a behaviour change that FR-011 mandates and FR-023 therefore permits, which is the boundary CHK016 asked to see drawn.

**Third, the four nested lint configurations are dropped, and it costs nothing.** Measured before deciding: all 31 Markdown files already pass this repository's root configuration with 0 violations and Prettier with none, and all 11 shell scripts pass `shellcheck --shell=sh --severity=style` with 0 findings and are already tab-indented. So the constitution's one-configuration-per-concern rule is honoured by deletion rather than by negotiation, and no vendored file is edited to achieve it.

The plugin manifest gains nothing. `skills/` is auto-discovered, and whether a declared `skills` field would add to or replace that location is a documented gap this plan is deliberately insensitive to.

## Technical Context

**Language/Version**: POSIX `sh` (IEEE Std 1003.1) for the 8 distributed scripts, verified with `shell=sh`. Markdown with YAML frontmatter for the 5 instruction documents and their 18 supporting files. No compiled language, no runtime.

**Primary Dependencies**: none added. The distributed skills depend at run time on `git`, and optionally on `gh` (`auto-github-pr`), `glab` (`auto-gitlab-mr`), and a GitLab MCP server as `glab`'s documented fallback. Each already degrades explicitly when its own tool is absent; this feature adds no dependency and removes none.

**Storage**: N/A. The one exception worth naming is that `speckit-run` writes run state to `.specify/.speckit-run-state.json` in the repository it operates on, which is gitignored and is not this repository's concern.

**Testing**: `scripts/lint.sh` and `scripts/selftest.sh` -- the repository's existing checks, unchanged and unextended. The file list comes from `git ls-files --cached --others --exclude-standard`, so `skills/` is in scope from the moment the files exist rather than from the moment they are committed. Beyond the gate, two things are verified by inspection because no tool can check them: that all five skills resolve under their namespaced names, and that the frontmatter asymmetry survives. What is deliberately **not** claimed as tested is that the five skills still behave correctly end to end -- each carries its own scenario document, those scenarios are interactive, and running them is not something this feature can assert it did.

**Target Platform**: any POSIX shell on macOS or Linux, wherever the host tool runs.

**Project Type**: a Claude Code plugin. This feature adds its first component directory; the repository previously held only the manifest and its quality gate.

**Performance Goals**: none stated in the spec and none invented. Worth recording as a non-goal made real by the platform: a skill's body loads only when used, so distributing 154 KB of supporting material and 77 KB of scenario documents costs a session that never invokes these skills nothing at all.

**Constraints**: POSIX `sh` only (Principle IV); every configuration committed with no undeclared default (Principle V); exactly one governing configuration per content kind per concern (Quality Gate Requirements); the aggregate check must have been run and passed before review (Development Workflow); no top-level `bin/`, because marketplace distribution rejects it; `${CLAUDE_PLUGIN_ROOT}` substitution is documented only inside skill and agent content, so no other context is relied on.

**Scale/Scope**: 47 source files, of which **39 are distributed** and 8 withheld. The 8 are one `.DS_Store`, four per-skill `.markdownlint-cli2.jsonc`, and three of the four `branch-options.sh` copies -- the surviving copy counts as distributed, so three are withheld and not two. 5 skill directories, 8 shell scripts (from 11, after reconciling 4 helper copies into 1), 31 Markdown files under `skills/`, 8 template files. 27 functional requirements, 16 success criteria. 2 files in the merged feature 001's record are amended. `plugin.json` is unchanged. Repository holds 180 tracked paths at `c2aeb7e` before this feature.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Constitution **v1.2.0**, ratified 2026-09-02, last amended 2026-09-02. Unchanged by this feature. Two conflicts were found at Step 2 of this feature's run and both were resolved without amending governance, which is why Phase 1 was skipped rather than run.

| Principle                                | Gate                                                                                            | Verdict                                                                                                                                                                                                                                                                                         |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Tooling Independence (NON-NEGOTIABLE) | Does every check produce its verdict with only POSIX `sh` plus the native tool or a container?  | **Pass, unaffected.** This feature adds no check and alters no runner. The existing eight are untouched.                                                                                                                                                                                        |
| II. Fail Fast                            | Does every script exit non-zero on first failure without masking exit status?                   | **Pass.** All 8 distributed scripts open `#!/bin/sh` then `set -u`; none uses `set -o pipefail`, which is not POSIX. ShellCheck's `check-extra-masked-returns` and `check-set-e-suppressed` are enabled repository-wide and report 0 findings across all of them.                               |
| III. Pinned, Official Images             | Is every image official or upstream-published, pinned by tag and digest?                        | **Pass, unaffected.** No image is added, removed, or repinned.                                                                                                                                                                                                                                  |
| IV. POSIX Shell Only                     | Are all scripts POSIX `sh` and clean under static analysis in POSIX mode?                       | **Pass, verified rather than assumed.** `shellcheck --shell=sh --severity=style --external-sources` over all 11 source scripts: 0 findings. Every construct a bashism grep surfaced was awk syntax inside an embedded `awk` block -- `function tags(b)`, a variable named `local` -- not shell. |
| V. Configuration Is Committed            | Is every linter driven by a committed configuration file, with no undeclared default relied on? | **Pass, and strengthened.** No configuration is added. Four nested `.markdownlint-cli2.jsonc` files present in the source are **not** distributed, so no vendored file is governed by an uncommitted-at-this-level configuration or by a second one.                                            |
| VI. Spec-Driven Change                   | Did this work pass through the Spec Kit phases?                                                 | **Pass.** Constitution classified and skipped with reason; specify, clarify, checklist, this plan; tasks, analyze and implement to follow. No phase skipped except the conditional one, with its reason recorded.                                                                               |

**Quality Gate Requirements at v1.2.0** -- "exactly one governing configuration file" per content kind **and concern**. This is the clause the second conflict turned on, and it is satisfied by subtraction. Markdown under `skills/` is formatted by `.prettierrc.json` and linted by `.markdownlint-cli2.jsonc` at the repository root: one configuration per concern, the same two that govern every other Markdown file here. Distributing the four nested configurations would have made four more, and `scripts/lint-scope.sh` -- which compares five declarations against `.lintignore` -- inspects no nested file, so the divergence would have been invisible to the check built to catch precisely it. "Runnable from the repository root without arguments" and "MUST name the file and location of every violation": unaffected.

**"Every script committed under the repository's script directory MUST itself be subject to the shell static analysis check."** The 8 distributed scripts live under `skills/`, not `scripts/`, so a literal reading does not reach them. They are held to the standard anyway, and not by generosity: `.lintignore` excludes nothing under `skills/`, so the runner's file list includes them, and `lint-shell.sh` checks them like any other script. The clause's purpose -- the tooling is not exempt from the standards it enforces -- is served whether or not its wording covers the location. Recorded rather than relied on, because a future reader may reasonably ask.

**Development Workflow: "Before a change is proposed for review, the aggregate quality check MUST have been run and MUST have passed."** This is a precondition of FR-025's removal as well as of review, which is the unusual part: the check gates an irreversible deletion of files outside the repository, not merely a pull request.

**Post-design re-check**: passes against v1.2.0. Phase 1 added no configuration file, no image, no check and no dependency. It added one cross-skill file reference, one behaviour change mandated by FR-011, one mechanism resting on observed rather than documented host behaviour, and one irreversible action outside the repository -- all four recorded in Complexity Tracking rather than waved through.

## Project Structure

### Documentation (this feature)

```text
specs/002-vendor-plugin-skills/
├── plan.md              # This file
├── research.md          # Phase 0 output -- 13 sections, 6 documentation gaps named
├── data-model.md        # Phase 1 output -- 6 structural entities
├── quickstart.md        # Phase 1 output -- validation scenarios
├── contracts/           # Phase 1 output
│   ├── skill-names.md   # the resolvable names, and the dispatch contract between them
│   └── branch-options.md # the shared helper's output contract
├── checklists/
│   ├── requirements.md  # spec-quality, 16/16
│   └── spec-quality.md  # CHK001-CHK055, reviewer-owned
└── tasks.md             # Phase 2 output (/speckit-tasks -- NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
skills/                                       # new; auto-discovered, no manifest entry
├── speckit-run/
│   ├── SKILL.md                              # disable-model-invocation: true -- the only one
│   ├── reference/                            # 14 files, incl. evaluations.md
│   └── scripts/                              # 5 files; branch-options.sh no longer among them
│       ├── cleanup-plan.sh
│       ├── copy-env-files.sh
│       ├── dirty-diff.sh
│       ├── forge-detect.sh
│       └── resume-state.sh
├── auto-branch-push/
│   ├── SKILL.md
│   ├── evaluations.md
│   └── scripts/
│       └── branch-options.sh                 # THE single copy; 3 skills reference it here
├── auto-commit-push/
│   ├── SKILL.md
│   └── evaluations.md
├── auto-github-pr/
│   ├── SKILL.md
│   ├── evaluations.md
│   ├── scripts/reviewer-options.sh
│   └── templates/
│       ├── default-pr-template.md            # the skill's own fallback; never installed
│       └── github/                           # drop-in set for OTHER repositories
│           ├── pull_request_template.md
│           └── PULL_REQUEST_TEMPLATE/{feature,bugfix,hotfix,docs,refactor}.md
└── auto-gitlab-mr/
    ├── SKILL.md
    ├── evaluations.md
    ├── scripts/member-options.sh
    └── templates/default-mr-template.md

.claude-plugin/plugin.json                    # UNCHANGED -- no skills field
.lintignore                                   # UNCHANGED -- skills/ is deliberately in scope
specs/001-quality-gate-plugin/research.md     # amended: section 10 (FR-020, FR-021)
CLAUDE.md                                     # amended: line 7 no longer true after this feature
README.md                                     # amended: the plugin now ships components
```

**Structure Decision**: `skills/<name>/` at the repository root, one directory per skill, with each skill's own layout preserved exactly as the source has it -- `reference/` for `speckit-run`, a root-level `evaluations.md` for the other four, `scripts/` and `templates/` where they already exist. The placement inconsistency in the scenario documents is **kept**, not normalised: moving `speckit-run`'s from `reference/evaluations.md` to the skill root would change a path its `SKILL.md` reference map and authoring note both name, and FR-023 permits changes distribution requires, which this is not.

`skills/` is not declared in `plugin.json`. Auto-discovery of that location is documented independently of the field, and whether the field adds or replaces is not documented at all ([research.md](./research.md) §3), so declaring it would be redundant under the reading that helps and a hazard under the reading that does not.

The shared helper lives under `auto-branch-push`, whose entire subject is branch selection, and the other three consumers reach it as `${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh`. Plugin `bin/` would have been better -- bare-command invocation, no path -- and is unavailable: marketplace distribution rejects a plugin with a top-level `bin/`, and this repository distributes through a marketplace entry ([research.md](./research.md) §5).

## Complexity Tracking

Four costs this design accepts. Each is here because the simpler alternative was considered and found to be worse or unavailable, not because the cost is small.

| Violation                                                                                                                   | Why Needed                                                                                                                                                                                                                                                                    | Simpler Alternative Rejected Because                                                                                                                                                                                                                                                                                                                                                                           |
| --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Three skills reference a fourth skill's file, against their own stated self-containment                                     | FR-011 requires one implementation of `branch-options.sh`; something has to own it, and the alternatives are a rejected `bin/`, the repository's own `scripts/` (which would conflate shipped content with repository tooling), or a new top-level directory holding one file | Keeping four copies was the status quo, and it is what let a defective fork sit unnoticed in one of them -- the three drift-detection scenarios compare three copies and never the fourth ([research.md](./research.md) §6). The coupling is bounded: the four always ship together, and FR-025 removes the install form in which one could exist without the others                                           |
| `speckit-run`'s behaviour changes -- helper output contract and ordering -- against FR-023's default of no behaviour change | FR-011 and FR-013 mandate reconciling the copies and recording which behaviour won. The winning implementation emits a different fourth column and a different order                                                                                                          | Adopting the 48-line fork instead would preserve `speckit-run`'s behaviour and propagate three defects to the other three skills, including one -- the phantom `origin` row -- observed during this feature's own Step 1                                                                                                                                                                                       |
| FR-005's dispatch mechanism rests on observed host behaviour, not on documentation                                          | How a skill invokes a sibling skill inside the same plugin is undocumented, and `speckit-run` makes exactly such calls at 6a and 6b                                                                                                                                           | There is no documented alternative to choose instead. The evidence used is named in [research.md](./research.md) §4, and Gap 5 is flagged as the one to revisit when the documentation improves. Leaving the bare names would guarantee failure rather than risk it                                                                                                                                            |
| FR-025 irreversibly deletes files outside the repository, which nothing else in this feature does                           | The clarification session chose removal over retention, with the drift cost of the alternative stated                                                                                                                                                                         | A backup would reintroduce the second copy the removal exists to eliminate. Safety comes instead from three preconditions -- the aggregate check passed, all five distributed skills confirmed invocable, commits pushed -- plus a confirmation immediately before the deletion, since the specification-time answer authorised a requirement rather than an executing `rm` ([research.md](./research.md) §12) |
