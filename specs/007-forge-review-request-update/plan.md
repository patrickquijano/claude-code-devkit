# Implementation Plan: Update an existing review request instead of refusing

**Branch**: `007-forge-review-request-update` | **Date**: 2026-09-05 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-forge-review-request-update/spec.md`

## Summary

Both forge skills already detect an existing review request at their Step 1 and stop on finding one. This feature turns that stop into a mode: the run continues in **update mode** against the existing review request instead of refusing. The change is entirely within the two skills' existing nine-step workflows — Step 1 selects the mode, Steps 4, 5, 7 and 8 read it, and Step 9 branches to an edit call instead of a create call. Alongside it the repository gains one combined reference under `docs/` recording what each forge's command-line tool actually does, and one path-scoped rule file under `.claude/rules/` carrying the durable authoring rules that reference produces.

Nothing executable is added. Every file this feature writes is Markdown.

## Technical Context

**Language/Version**: Markdown only. No code is added. The skills are Markdown instruction documents; the tools they instruct an agent to run are already dependencies.

**Primary Dependencies**: `gh` 2.100.0 and `glab` 1.116.0, both already required by their respective skill and both verified authenticated on the development machine on 2026-09-05. The GitLab MCP server remains `ccd-gitlab-mr`'s documented fallback and is extended to cover update, not only create.

**Storage**: N/A. The forge holds the state; the skills hold none.

**Testing**: The repository has no test runner. `scripts/lint.sh` is the check, and each skill's `evaluations.md` is its written regression suite. Both are updated by this feature.

**Target Platform**: Claude Code sessions with either forge skill installed, on macOS and Linux.

**Project Type**: Claude Code plugin — a set of Markdown skills plus a POSIX `sh` quality gate.

**Performance Goals**: N/A. The bound that matters is the number of interactive questions, which this feature must not increase on the create path and must keep to at most two additional calls on the update path.

**Constraints**: `SKILL.md` stays under 500 lines each; only the first 5,000 tokens of a skill survive compaction, so anything Step 9 needs must be reachable at Step 9; `markdownlint` `MD013` is disabled, so one line per paragraph is the house style; a tab inside a fenced code block fails the `editorconfig` check; `scripts/lint.sh` must pass before review.

**Scale/Scope**: Two `SKILL.md` files, two `evaluations.md` files, one new `docs/` file, one new `.claude/rules/` file, and this feature's own `specs/` directory. Six files changed or added outside `specs/`.

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

Evaluated against constitution v1.2.0, six principles, ratified 2026-09-02.

- **I. Tooling Independence (NON-NEGOTIABLE)** — applies to repository quality checks; this feature adds none. **PASS**: the quality gate is untouched. `gh` and `glab` are runtime dependencies of two skills, not preconditions of any check, and both skills already stop cleanly when theirs is absent.
- **II. Fail Fast** — applies to committed scripts; this feature adds none. **PASS**: no script is added or modified. The skills' own stop-on-failure behaviour is preserved and extended, since FR-004 forbids continuing as though detection had succeeded.
- **III. Pinned, Official Images** — applies to container images; none added. **PASS**.
- **IV. POSIX Shell Only** — applies to committed shell scripts; none added or changed. **PASS**: the shell snippets inside the two `SKILL.md` files are instruction text, not committed scripts, and remain POSIX-compatible in form.
- **V. Configuration Is Committed** — applies to linter and formatter configuration; none added or changed. **PASS**: the new `.claude/rules/` file is agent instruction, not tool configuration, and every check that governs the new Markdown files is already configured and already covers them.
- **VI. Spec-Driven Change** — applies directly. **PASS**: spec, plan and task list all reach disk before implementation.
- **Quality Gate Requirements** — applies to content kinds and their configurations. **PASS**: Markdown is already governed by exactly one formatting configuration and one linting configuration; this feature adds files of an existing kind, not a new kind.
- **Development Workflow** — applies directly. **PASS**: branch `007-forge-review-request-update` cut from `main` before review; artifacts under `specs/007-forge-review-request-update/`; `scripts/lint.sh` runs and passes before the change is proposed.

**Post-design re-evaluation**: PASS, unchanged. Phase 1 introduced no new file kind, no dependency, and no script. The one design decision with any constitutional weight — keeping the two skills separate rather than extracting shared logic — moves in the direction Governance requires, since the simpler alternative is the one taken.

**Complexity Tracking**: empty. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/007-forge-review-request-update/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── update-mode.md   # The behavioural contract both skills implement
│   └── forge-commands.md # The exact commands and flags each forge's tool takes
├── checklists/
│   ├── requirements.md  # Built-in spec-quality checklist
│   └── update-mode.md   # Requirements-quality checklist, 37 items
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source (repository root)

```text
skills/
├── ccd-github-pr/
│   ├── SKILL.md         # MODIFIED — Steps 0, 1, 4, 5, 7, 8, 9, Boundaries, When NOT to use, Tool Reference
│   └── evaluations.md   # MODIFIED — E2 rewritten; E7, E8, E9, E10 added
└── ccd-gitlab-mr/
    ├── SKILL.md         # MODIFIED — the same steps and sections
    └── evaluations.md   # MODIFIED — E2 rewritten; E7, E8, E9, E10 added

docs/
└── forge-review-requests.md   # NEW — the combined reference (FR-025 to FR-027)

.claude/rules/
└── forge-review-requests.md   # NEW — path-scoped rules for the two skills (FR-028)
```

**Structure Decision**: The two skills stay separate, with no shared file and no shared script. `branch-options.sh` remains the only file either skill reaches for outside its own directory, and this feature adds nothing to that category. The new `docs/` file and the new `.claude/rules/` file take the names their existing siblings would predict: `docs/` already holds `claude-code-practices.md`, `merge-conflict-practices.md` and `skill-authoring-practices.md`, and `.claude/rules/` already holds `shell-scripts.md` and `skill-authoring.md`. The rules file cites the docs file rather than repeating it, which is the relationship `.claude/rules/skill-authoring.md` already has with `docs/skill-authoring-practices.md`.

## Design decisions

The full reasoning, alternatives and sources are in [research.md](./research.md). The decisions themselves:

1. **Update is a mode within the existing workflow**, not a second skill and not a second entry point. Step 1 sets it; Steps 4, 5, 7, 8 and 9 read it.
2. **Detection widens rather than moves.** Both skills already list review requests for the branch at Step 1. The list becomes state-inclusive and the result becomes a mode rather than a stop.
3. **The five fields are fixed.** Title, description, target branch, reviewers, assignees. Everything else about an existing review request is out of scope, which is what keeps the update path from quietly becoming an editor.
4. **The description is read before it is written**, always. Both tools replace the whole field, so a diff against the live value is the only thing standing between a routine re-run and destroyed work.
5. **Reviewers and assignees are expressed per forge, never once for both.** This is the single most dangerous difference between the two tools and it is written into the skill, the contract, the rule file and both evaluation suites.
6. **The rebase is conditional in update mode only.** The create path is untouched, which keeps the first run identical to today.
7. **Nothing new is executable.** Every rule this feature adds is enforced by reading, by the written evaluations, and by the existing lint gate.

## Complexity Tracking

No constitutional violations. This section is intentionally empty.
