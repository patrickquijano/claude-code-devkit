# Research: Distribute the Toolkit's Own Skills

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-02

Every decision in [plan.md](./plan.md) that is not forced by the specification has its reason here, in the same form feature 001 established: what was chosen, why, what was rejected. Two things are stated explicitly throughout, because this feature's subject is a platform whose documentation is incomplete in the exact places this design depends on:

- **Where the documentation answers a question, it is cited.** The citation is the whole point; a design resting on remembered platform behaviour is a design that breaks on the next release with no record of what it assumed.
- **Where the documentation does not answer a question, that is said plainly, and the evidence used instead is named.** Six such gaps were found. A gap papered over with a confident sentence is worse than a gap, because the next reader cannot tell which sentences were verified.

## 1. Working with the host tool: the practices this feature relies on

**Sources**: [Claude Code best practices](https://code.claude.com/docs/en/best-practices), [Extend Claude with skills](https://code.claude.com/docs/en/skills).

Feature 001 recorded two of these already (its `research.md` §11); they are not repeated. Three more shaped decisions here:

- **A skill's body costs nothing until it is used.** The skills documentation states that "unlike CLAUDE.md content, a skill's body loads only when it's used, so long reference material costs almost nothing until you need it." This is the fact that makes distributing five test-scenario documents free, and it is why the clarification session resolved FR-024 the way it did. `speckit-run`'s instruction document is 30,942 bytes and its supporting material another 154,000; none of it is paid for by a session that does not invoke the skill.
- **Descriptions are how a skill gets chosen.** "Claude matches your task against skill descriptions to decide which are relevant. If descriptions are vague or overlap, Claude may load the wrong skill or miss one that would help." The five descriptions already follow this closely -- each opens "Use when...", names concrete trigger phrases, and ends with a negative case ("Not for a plain branch push with no merge request"). FR-023 protects them, and this is the reason: they are load-bearing behaviour, not prose.
- **The verification loop is what makes agentic work land.** Feature 001 took this as the argument for a single aggregate check with a meaningful exit status. It applies again here as the argument for FR-016 being a real gate rather than an assertion: the distributed content is checked by running `scripts/lint.sh`, not by reasoning about whether it would pass.

**Not acted on, recorded so it is not mistaken for an oversight**: the documentation offers no guidance on how long a `SKILL.md` should be. `speckit-run`'s is 267 lines and 30,942 bytes, which is large, and it manages that size with its own reference-map indirection rather than with any documented budget. Nothing in this feature changes it, and nothing in the documentation says it should.

## 2. Skill authoring: frontmatter, triggering, progressive disclosure

**Sources**: [Extend Claude with skills](https://code.claude.com/docs/en/skills), [Plugins reference](https://code.claude.com/docs/en/plugins-reference).

**Frontmatter fields, as documented**:

| Field                                  | Meaning                                                                | Required                                          |
| -------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------- |
| `name`                                 | the skill's invocation name, kebab-case; overrides the directory name  | no -- falls back to the directory name            |
| `description`                          | what Claude matches a task against to decide whether the skill applies | recommended wherever the skill is model-invocable |
| `allowed-tools`                        | tools that may run without per-use approval while the skill is active  | no                                                |
| `disable-model-invocation`             | when true, Claude cannot invoke the skill automatically                | no; defaults false                                |
| `compatibility`, `license`, `metadata` | Agent Skills standard fields                                           | no                                                |

**Progressive disclosure** is documented as three levels: frontmatter metadata, always loaded, roughly 50-100 tokens per skill; the `SKILL.md` body, loaded when the skill is judged relevant; and supporting files, "the third level (and beyond) of detail, which Claude can choose to navigate and discover only as needed."

All five skills already match that shape. `speckit-run` is the clearest case: its `SKILL.md` carries a reference-map table pointing at 14 files under `reference/`, each read only at the step that needs it, which is the documented pattern implemented deliberately.

**Gap 1 -- whether unread supporting files cost context.** The documentation implies they do not ("costs almost nothing until you need it") but does not state it as a guarantee. The decision this would affect -- FR-024, distributing five test-scenario documents -- is insensitive to it: each of the five is referenced only from a sentence telling the reader not to read it during a run.

**Gap 2 -- `argument-hint` is not a documented field.** `speckit-run`'s frontmatter carries `argument-hint: <task description>`, and `argument-hint` appears in none of the documented field lists; one account flags it as unexpected under validation. It works today. **Decision: leave it.** FR-023 forbids changing a skill's content except where distribution requires it, and this is not required by distribution -- an unknown-but-tolerated field is a smaller risk than removing a field the entry point may depend on for its argument prompt. Recorded as a risk rather than fixed, so that a future validation failure has a written history instead of looking like a new defect.

## 3. Plugin authoring: manifest, auto-discovery, substitution

**Sources**: [Create plugins](https://code.claude.com/docs/en/plugins), [Plugins reference](https://code.claude.com/docs/en/plugins-reference), [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces).

**Auto-discovery**: a `skills/` directory at the plugin root, holding one folder per skill with a `SKILL.md` inside, is discovered with no manifest declaration -- "Add a `skills/` directory at your plugin root with Skill folders containing `SKILL.md` files." A flat `commands/` directory of Markdown files is also discovered and is described as legacy, with new plugins directed to `skills/`.

**Substitution variables**, and the contexts documented for them:

| Variable                | Expands to                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `${CLAUDE_PLUGIN_ROOT}` | the plugin's installation directory                                                                                |
| `${CLAUDE_PLUGIN_DATA}` | a persistent per-plugin directory under `~/.claude/plugins/data/{id}/`, surviving updates and removed on uninstall |
| `${CLAUDE_PROJECT_DIR}` | the project root                                                                                                   |

Inline substitution is documented to work in **skill and agent content**, hook and monitor commands, `stdio` MCP servers' `command`/`args`/`env`, and LSP servers' `command`/`args`/`env`/`workspaceFolder`. All three are additionally exported to spawned processes as environment variables.

"Skill and agent content" is the entry this feature turns on: it is what makes `${CLAUDE_PLUGIN_ROOT}` usable inside a `SKILL.md` body, which is where FR-009's paths live.

**Gap 3 -- the documentation does not enumerate where substitution does _not_ happen.** It lists the contexts that work and stops. This feature only relies on the listed one.

**Gap 4 -- whether `plugin.json`'s `skills` field adds to or replaces the default directory is not documented**, and this repository has a prior record asserting that it is. Feature 001's `research.md:208` states, citing the plugins reference: "Path fields **replace** the default directory for `commands`, `agents`, `workflows`, `outputStyles`; `skills` **adds** to it." Re-reading the same reference for this feature did not find that distinction stated. One of the two readings is wrong and this feature does not resolve which.

**Decision: `plugin.json` declares no `skills` field, and gains no component-path field of any kind.** The decision is deliberately insensitive to Gap 4: auto-discovery of the default `skills/` location is documented independently of the field, so under the "adds" reading the declaration would be redundant, and under the "replaces" reading it would be redundant at best and a footgun if the path were ever mistyped. Either way the correct action is the same, which is why the unresolved gap does not block the plan. This also keeps feature 001's manifest decision intact for every field except the directory's existence.

## 4. Plugin skill namespacing, and the cross-skill dispatch this feature depends on

**Sources**: [Create plugins](https://code.claude.com/docs/en/plugins), [Extend Claude with skills](https://code.claude.com/docs/en/skills).

**Documented**: a skill shipped by a plugin is addressed with the plugin's name as a prefix, colon-separated -- "Each skill folder name becomes the skill name, prefixed with the plugin's namespace (e.g., `hello/` in a plugin named `my-first-plugin` creates `/my-first-plugin:hello`)." Personal and project skills are addressed bare.

**Documented**: the namespace removes the collision question entirely. "If two Skills have the same name, the higher row wins: enterprise overrides personal, personal overrides project, and project overrides plugin. Plugin skills use a `plugin-name:skill-name` namespace, so they can't conflict with other levels."

This settles FR-006 more cleanly than the specification anticipated. The specification requires deterministic resolution where a distributed and a personal copy are both present; the platform provides it structurally, because the two are addressed by different names and neither shadows the other. FR-006 is satisfied by _using the namespaced name_, and the record it requires is the name itself.

So the five resolve as:

```text
claude-code-devkit:speckit-run
claude-code-devkit:auto-branch-push
claude-code-devkit:auto-commit-push
claude-code-devkit:auto-github-pr
claude-code-devkit:auto-gitlab-mr
```

**Gap 5, and it is the significant one -- how one skill invokes a sibling skill in the same plugin is not documented.** The published documentation covers how a _user_ addresses a plugin skill and says nothing about a `Skill` tool call made from inside another skill: not the name to use, not whether the plugin name can be omitted for a sibling, and not whether an unresolved name is an observable error or a silent failure.

`speckit-run` makes exactly such calls, at its Step 6a and 6b, and today it makes them with bare names.

**Decision: dispatch by the fully namespaced name, `claude-code-devkit:<name>`, and treat non-resolution as an observable failure that Step 0's probe is responsible for catching before eight phases of work depend on it.**

**Evidence, since documentation is unavailable**: the host presents plugin skills to the model under their namespaced names. In the session in which this plan was written, the available-skills listing rendered plugin-supplied skills as `plugin-dev:skill-development`, `superpowers:brainstorming`, `caveman:caveman-commit` and so on, while personal skills appeared bare (`auto-branch-push`, `graphify`) and project skills appeared bare (`speckit-analyze`). The namespaced form is therefore the name the tool is offered under, which is the form a call must use. This is observation, not documentation, and it is recorded as such.

**Consequence for FR-008, and why the probe matters more than the call.** `speckit-run`'s Step 0 currently decides whether its companions exist by running `ls ~/.claude/skills/auto-gitlab-mr/SKILL.md` and two similar commands (`reference/preflight.md:40-42`). Under a plugin install those paths do not exist, so the probe reports all three companions missing, and the skill's own documented degradation then takes over: 6a drops its commit option and 6b is skipped with a reason. The run completes, reports success, and silently produces neither a commit nor a pull request. **This is the single worst defect in vendoring these skills unchanged**, because nothing about it looks like a failure.

**Decision**: replace the filesystem probe with a check against the session's own available-skills listing, which is what `preflight.md` already treats as authoritative for the eight Spec Kit commands in the same step -- "treat the session's own available-skills listing as authoritative and the path check as the fallback." The fallback path check is retained for a personal install and widened to cover both locations. This is a change to a skill's documented steps, and FR-023 requires it be traceable: it is required by FR-008, which exists because of this defect.

## 5. Where the one shared helper lives

**Sources**: [Plugins reference](https://code.claude.com/docs/en/plugins-reference).

FR-011 requires one implementation of `branch-options.sh` where four exist. Four placements were considered.

**Rejected -- plugin root `bin/`.** This was the most attractive option before the documentation was read: `bin/` is auto-discovered and added to the Bash tool's `PATH`, so every consumer could invoke `branch-options.sh` as a bare command with no path at all. It is **not available**: a plugin carrying a top-level `bin/` directory is refused by marketplace sync and by organization-settings upload, reported as "Plugin contains a top-level bin/ directory", and the documented workaround is to put executables elsewhere and reference them through `${CLAUDE_PLUGIN_ROOT}`. This repository publishes itself through a marketplace entry (`.claude-plugin/marketplace.json`), so the restriction applies directly.

**Rejected -- the repository's existing top-level `scripts/`.** That directory holds this repository's own quality-gate runners. Putting a script that the plugin distributes to consumers beside `lint.sh` and `selftest.sh` conflates repository tooling with shipped content, and the constitution's requirement that every script under the script directory be shell-checked would then be satisfied for the wrong reason.

**Rejected -- a new top-level `shared/`.** Clean ownership and no collision, but it is a new top-level directory created to hold one file, and its contents would have no other reader. The simpler option below reuses structure that already exists.

**Chosen -- `skills/auto-branch-push/scripts/branch-options.sh`**, referenced by the other three consumers as `${CLAUDE_PLUGIN_ROOT}/skills/auto-branch-push/scripts/branch-options.sh`.

**Rationale**: `auto-branch-push` is the skill whose entire subject is choosing a branch and creating one, so the behaviour belongs to it by ownership rather than by convenience; it already holds one of the three identical copies; and substitution inside skill content is the one documented context, so the reference form is the documented one rather than an inference.

**Cost, accepted and recorded in the plan's Complexity Tracking**: three skills now reach into a fourth skill's directory, and all three currently assert self-containment. The coupling is bounded -- the four are distributed together in one plugin, always, and FR-025 removes the install form in which one could exist without the others -- but it is real, and the assertions must be corrected rather than left standing (see §7).

**Gap 6 -- whether the executable bit survives installation is not documented.** It does not matter here. Every invocation in all five skills is already of the form `sh <path>/scripts/<name>.sh`, with the explicit note that "the executable bit does not survive every install path"; the skills were written for this uncertainty before it was documented anywhere.

## 6. Reconciling the four copies: which behaviour wins

Four copies existed at the start of this feature. Three were byte-identical at 88 lines (`md5 70edb6aeff4841a992b13a0a66ba0ac0`), one divergent at 48 (`md5 c92eb52d812fdd6232e2e84740180843`, in `speckit-run`).

**Decision: the 88-line implementation is the one distributed.** This is not a preference between two designs. The 48-line version has three defects the 88-line version fixes deliberately, and one of them was observed during this very run.

**Defect 1, observed.** The 48-line version reads remote refs with `%(refname:short)` and strips a leading `<remote>/`. Git shortens `refs/remotes/origin/HEAD` to plain `origin`, which contains no slash, so the strip does nothing and the symbolic HEAD is emitted as though it were a branch. Run in this repository at Step 1 of this feature's own delivery, it printed:

```text
main	both	2026-09-02	current
origin	remote	2026-09-02	-
```

`origin` is not a branch. The 88-line version reads `%(refname)` in full, with the comment "git shortens `refs/remotes/origin/HEAD` to plain `origin`, which is indistinguishable from a branch named `origin`", and adds a guard for the case where the substitution matched nothing. Run against the same repository it emits no such row.

**Defect 2.** The 48-line version derives the current branch with `git rev-parse --abbrev-ref HEAD`, falling back to treating the literal `HEAD` as "no current branch". On an unborn HEAD -- a fresh repository with no commits -- that command errors, so the fallback fires and the current branch is lost. The 88-line version uses `git symbolic-ref --short -q HEAD`, which is empty on a detached HEAD and still names the branch on an unborn one.

**Defect 3, an absence rather than a bug.** The 48-line version cannot identify the repository's default branch. The 88-line version resolves it from `refs/remotes/origin/HEAD`, falls back to the first of `main`, `master`, `develop` that exists, tags it `default`, and sorts it first.

**Output contract change, and it is a real behaviour change.** The fourth column changes from `current|-` to a comma-joined subset of `default` and `current` (or `-`), and the ordering changes from newest-commit-first to default-branch-first-then-newest. `speckit-run`'s `reference/base-branch.md` documents the old contract in prose -- "branch, `local` / `remote` / `both`, last commit date, `current` marker" and "Newest first" -- and both sentences become wrong.

**This is the conflict CHK014 identified, and it is resolved rather than waved through.** FR-023 forbids changing a skill's behaviour except where distribution requires it. Reconciling divergent copies changes `speckit-run`'s behaviour, and duplication is a maintenance defect rather than a distribution blocker, so the exemption does not obviously cover it. It is nonetheless in scope, because **FR-011 and FR-013 require it explicitly** -- the specification asks for one implementation and for a record of which behaviour was kept. FR-023's protection is against unrequested redesign, not against a change a numbered requirement mandates. The prose correction in `base-branch.md` is therefore traceable to FR-011, which is the traceability FR-023 demands, and it is the boundary CHK016 asked to be drawn: a found defect is in scope when a requirement names it, and out of scope when only the author's judgement does.

**How the single copy is verified, since the drift check it replaces is now meaningless.** Three of the four skills carry a scenario that compares their copies with `cmp -s` and reports "COPIES HAVE DRIFTED" (`auto-gitlab-mr/evaluations.md:96-97`, `auto-github-pr/evaluations.md:110-112`, `auto-branch-push/evaluations.md:104-105`). Those scenarios compared three of the four copies and never the fourth, which is why the divergent one went unnoticed. With one copy there is nothing to compare, so the check is replaced rather than deleted: each affected scenario now asserts that exactly one implementation exists in the distributed tree and that each consumer's reference resolves to it. That is what FR-012 and SC-005 are checkable against -- a count and a set of resolutions, not a byte comparison.

## 7. Statements in the distributed content that this feature makes false

Distributing these skills changes facts they assert about themselves. FR-023 protects wording; it does not license leaving a false sentence in place, and CHK022 named the first of these.

| Location                                                                                                                                 | Current assertion                                                                                                                                | Why it becomes false                                                                                                                                                                                     | Requirement forcing the correction |
| ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `auto-github-pr/SKILL.md:227`                                                                                                            | "`scripts/branch-options.sh` is byte-identical in `auto-branch-push`, `auto-gitlab-mr`, and this skill by design, so each stays self-contained." | There is one copy, and this skill no longer contains it                                                                                                                                                  | FR-011                             |
| `speckit-run/reference/base-branch.md`                                                                                                   | the fourth column is a "`current` marker"; ordering is "Newest first"                                                                            | the contract is now `default`/`current` tags, default-branch-first                                                                                                                                       | FR-011                             |
| `speckit-run/reference/preflight.md:40-42`                                                                                               | availability is decided by `ls ~/.claude/skills/<name>/SKILL.md`                                                                                 | that path does not exist under a plugin install                                                                                                                                                          | FR-008                             |
| `speckit-run/SKILL.md:76` and the three `auto-*` equivalents                                                                             | "e.g. `sh ~/.claude/skills/<name>/scripts/...` for a personal install"                                                                           | the personal install is removed by FR-025, and the plugin form is unaddressed                                                                                                                            | FR-010                             |
| the three drift-detection scenarios                                                                                                      | three copies must remain byte-identical                                                                                                          | there is one copy                                                                                                                                                                                        | FR-011                             |
| the seven `auto-github-pr` templates and `auto-gitlab-mr`'s                                                                              | each begins at a second-level heading                                                                                                            | `MD041` rejects a file whose first line is not a top-level heading, and this repository enforces it                                                                                                      | FR-016                             |
| `auto-github-pr/scripts/reviewer-options.sh:41`, `auto-gitlab-mr/scripts/member-options.sh:36`, `speckit-run/scripts/resume-state.sh:35` | a command substitution masking an exit status                                                                                                    | `.shellcheckrc` enables `check-extra-masked-returns`, so `SC2312` fires and Principle IV requires zero findings                                                                                          | FR-016                             |
| `speckit-run/scripts/copy-env-files.sh:34-40`                                                                                            | continuation lines indented with a tab followed by spaces                                                                                        | `.editorconfig` sets `indent_style = tab` for `*.sh`                                                                                                                                                     | FR-016                             |
| `speckit-run/SKILL.md:4`                                                                                                                 | carried `argument-hint`, which no documentation defines as a skill frontmatter field                                                             | Removed at Step 5. Safe because the field's information already survives in `description`, which says "from a single task description" -- the host reads that                                            | F4                                 |
| `auto-github-pr/evaluations.md:50,60`                                                                                                    | named the maintainer's own GitHub handle as an example fork owner                                                                                | Replaced with `contributor`, so a skill distributed to other users does not name a specific person in its scenarios                                                                                      | F6                                 |
| `spec.md` FR-003 and FR-004                                                                                                              | read as one requirement stated twice, and CHK035 asked whether the duplication was deliberate                                                    | Kept as two, with the relationship made explicit: FR-003 is the observable outcome, FR-004 the structural prohibition that guarantees it. Numbering unchanged, so every existing citation still resolves | F5                                 |

**Three of those five were not predicted at planning time**, and the reason is recorded in §13: the measurements taken before the decision were run with the wrong tool invocations. `shellcheck` was run without `.shellcheckrc`'s four `enable=` directives, so `check-extra-masked-returns` never fired; `prettier --check` was reported as clean when it in fact rewrites `*emphasis*` to `_emphasis_` throughout; and the space-indented continuation lines in `copy-env-files.sh` were missed by an indentation scan that only looked at first characters. All three were found by running the repository's own gate, which is the point of FR-016 being a requirement rather than an assumption. None of them changes any skill's behaviour.

**Not corrected, deliberately**: the six occurrences of `~/.claude/CLAUDE.md` in `speckit-run`'s content. That path names the _user's own machine-wide instructions file_, which the skill names precisely in order to forbid touching it. It is correct, install-independent, and rewriting it would break the prohibition it carries. This is why SC-003's count was corrected from 22 to 16 during planning: the criterion is scoped to "instructions a reader is meant to follow", and these six are not that.

## 8. The four per-skill lint configurations, and why none is distributed

Four of the five skills carry a `.markdownlint-cli2.jsonc`: `speckit-run` (2,524 B), `auto-github-pr` (2,165 B), `auto-gitlab-mr` (2,075 B), `auto-branch-push` (1,702 B). `auto-commit-push` carries none.

**Decision: none is distributed.** The conflict and its resolution are recorded in this feature's run state; the governing sentence is the constitution's Quality Gate Requirements at v1.2.0: "Each combination of content kind and concern MUST have exactly one governing configuration file, where the concerns are formatting and linting." Four nested configurations would be four further linting configurations for Markdown. Worse, `scripts/lint-scope.sh` compares five declarations against `.lintignore` and knows nothing about nested files, so the divergence would be invisible to the check that exists to detect exactly this.

They are also not equivalent to the repository's own configuration, which is why "just copy them" was never the safe option. The skill configurations switch off `MD014`, `MD025`, `MD034`, `MD041`, and `MD024` entirely; the repository leaves all four of the former on and scopes `MD024` to siblings.

**What made the decision free, measured rather than assumed.** All 31 Markdown files across the five source trees were run against this repository's root configuration and against Prettier before the decision was taken:

| Check            | Command                                                                         | Result                                       |
| ---------------- | ------------------------------------------------------------------------------- | -------------------------------------------- |
| Markdown lint    | `markdownlint-cli2 --config .markdownlint-cli2.jsonc` over all 31 files         | 0 violations                                 |
| Formatting       | `prettier --config .prettierrc.json --check` over all 31 files                  | "All matched files use Prettier code style!" |
| Shell lint       | `shellcheck --shell=sh --severity=style --external-sources` over all 11 scripts | 0 findings                                   |
| Shell formatting | `prettier --config .prettierrc.json --check` over all 11 scripts                | clean                                        |
| Whitespace       | last byte and CRLF scan over all 47 files                                       | 0 missing final newlines, 0 CRLF             |

The configuration was verified to be in force rather than silently ignored, by running it against a file with a known `MD041`, `MD034` and `MD040` violation and confirming all three were reported. So dropping the four configurations costs **zero** edits to the vendored Markdown. `MD013` is off at the repository root for its own recorded reason, which is what lets these files keep one line per paragraph -- the convention `speckit-run`'s authoring note mandates, and which feature 001's `research.md:21` already cites this skill as the model for.

**A hazard this feature found the hard way, and the reason it is written down.** `scripts/lint.sh --fix` runs Prettier with `prettier-plugin-sh`, which formats the contents of fenced `bash` blocks inside Markdown. A placeholder written `<name>` in such a block is valid documentation and invalid shell: the plugin parses `<` and `>` as redirection operators and **moves them to the end of the command**. Running `--fix` over the freshly copied content silently rewrote

```text
gh pr create --base <base> --head <head> --title '<title>' --assignee <login> ...
```

into a command whose `--base` had no argument and whose placeholders had migrated past `--draft`. Eleven lines across six files were damaged this way, and two of them -- the `gh pr create` and `glab mr create` invocations, the single most important command in each of those two skills -- were left unrunnable. Nothing failed: the tree passed every check afterwards, because a mangled command is still well-formed shell.

The fix is to quote every placeholder in a shell fence (`'<base>'`), which the plugin then treats as an ordinary word and leaves alone; `${CLAUDE_PLUGIN_ROOT}` needs no quoting to survive but is quoted anyway, because a plugin root containing a space would otherwise split. It was found by comparing every fenced block against its source rather than by reading the diff, which is why the verification in `tasks.md` T047 is a block-by-block comparison and not an eyeball.

Also not distributed: `speckit-run/.DS_Store`, 6,148 bytes of macOS directory metadata. It is binary, machine-local, already covered by `.gitignore`, and FR-017 forbids it.

## 9. The frontmatter asymmetry, and why normalising it is the trap

`speckit-run` carries `disable-model-invocation: true`. The four companions carry no such field. This is the asymmetry FR-014 and FR-015 protect, and the reason is that it is load-bearing in **both** directions:

- **Added to a companion**, it would stop `speckit-run` dispatching it. `speckit-run`'s own authoring note states this outright: "That field blocks the `Skill` tool, not merely automatic loading, so setting it on any of the three breaks Step 6's dispatch at 6a or 6b -- and it breaks it silently, at the end of a full pipeline run." Each of the three companions repeats the warning in its own file (`auto-gitlab-mr/SKILL.md:184`, `auto-github-pr/SKILL.md:229`, `auto-branch-push/SKILL.md:149`).
- **Removed from the entry point**, `speckit-run` becomes model-invocable and can start an eight-phase pipeline unbidden.

**Gap, and it is why the asymmetry is preserved rather than reasoned about.** The documentation states that `disable-model-invocation: true` prevents Claude from invoking the skill automatically. It does **not** confirm the stronger claim `speckit-run` makes -- that the field also blocks an explicit `Skill` tool call from another skill. The two accounts may both be right, if "automatic" covers a model-initiated call from within a skill; or the skill's note may be stricter than the platform.

**Decision: change nothing, and treat the skill's stricter reading as binding.** If the skill's claim is correct, preserving the asymmetry is required. If the platform is more permissive, preserving it costs nothing. The asymmetry is safe under both readings and only one of them survives normalisation, so there is no version of this question whose answer argues for uniform frontmatter. FR-015 requires the reason be written where someone editing frontmatter would meet it, which the existing authoring notes already do -- so this is a requirement satisfied by _not_ removing something, and the verification is that all four warnings are still present after distribution.

## 10. Amendment to feature 001's research record

Feature 001's `research.md` §10 contains two statements this feature contradicts, and FR-020 and FR-021 require them amended rather than left to be reconciled by a later reader.

**`research.md:210`**: "**Decision**: commit `.claude-plugin/plugin.json` with [...] Declare **no** component-path fields and create **no** component directories."

The first half stands: this feature declares no component-path field either (§3). The second half was scoped to feature 001, whose own `spec.md:226` says "none are invented for this feature; the plugin becomes installable, and **its contents grow later**." The amendment records that scoping, so the sentence reads as a decision about feature 001 rather than a standing prohibition.

**`research.md:216`**: "[...] `.claude/skills/speckit-*` must not be vendored into the plugin: it is Spec Kit's generated output, not this repository's authored content."

The reasoning is right and the pattern is too broad. `.claude/skills/` in this repository holds 36 directories, every one of them generated by `specify init`, and **`speckit-run` is not among them** -- it is authored, and it is not a Spec Kit command. The amendment narrows the prohibition to Spec Kit's generated output by its provenance rather than by a name pattern, and names `speckit-run` as authored so that the resemblance does not read as a violation. FR-021 exists for this: a prohibition written as a glob catches things the reasoning behind it never meant to.

Both are edits to a committed record of a merged feature, made because leaving them would leave the repository contradicting itself -- which is what SC-010 counts.

## 11. Scope declarations: whether any needed an entry

**Answer: none.** Recorded because FR-019 requires the answer either way, and "we checked and nothing changed" is a result rather than an absence of work.

`.lintignore` declares what is **out** of scope, and the new `skills/` tree is meant to be **in** it -- so no entry is added there, and none is added to the five per-check declarations that mirror it (`ignores` in `.markdownlint-cli2.jsonc`, `ignore` in `.yamllint.yml`, `exclude` in `ruff.toml`, `.prettierignore`, `Exclude` in `.editorconfig-checker.json`). Neither side of `scripts/lint-scope.sh`'s comparison changes, so its verdict is unaffected, which is what SC-013 counts.

Two things make this hold rather than merely appear to. The runner's file list comes from `git ls-files --cached --others --exclude-standard`, so files in `skills/` are in scope from the moment they exist, before they are committed -- FR-016's check is real during implementation, not only after. And `.lintignore:54` already anticipated this layout, describing where authored plugin content goes: "The plugin's own authored content lives in top-level `skills/`, `commands/` and `agents/`."

## 12. Ordering: why the removal is last, and what confirms it

FR-025 removes the personal copies; FR-026 forbids doing it while anything still depends on them and requires confirmation immediately beforehand.

The dependency is concrete rather than theoretical: **this feature's own delivery executes from the copies it removes.** `speckit-run`'s Step 6 invokes `dirty-diff.sh compare` and `cleanup-plan.sh` from the personal install, after implementation is complete. A removal placed among the implementation tasks would delete the tooling that has not finished running.

**Decision**: the removal is the last action of the delivery, after shipping completes, and it is not an implementation task. Two preconditions are checked immediately before it, because once it is done the distributed copies are the only copies: the aggregate check has passed, and each of the five distributed skills has been confirmed present and invocable. The confirmation FR-026 requires is separate from the specification-time answer that chose the removal -- the approval recorded in the clarification session authorised a requirement, not an executing deletion of files outside the repository.

**Recorded as an accepted irreversibility**: nothing in this feature backs the personal copies up. The clarification chose removal over retention with the drift cost stated, and a backup would reintroduce the second copy the removal exists to eliminate. The safety comes from the preconditions and from the distributed copies being committed and pushed, not from a second copy on the same machine.

## 13. Corrections made during planning

Recorded in the form feature 001's §12 established, because a decision whose history is invisible gets "corrected" back.

| What was wrong                                                                    | What it is now                                                              | How it surfaced                                                                                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SC-003 counted 22 literal install locations to eliminate                          | 16, with the other 6 named as correct and out of scope                      | Splitting the 22 by whether a reader follows them showed 6 name the user's own `CLAUDE.md`, which the skills must keep naming                                                                                                                                                                                                       |
| Plugin `bin/` was the intended home for the shared helper                         | `skills/auto-branch-push/scripts/`, referenced via `${CLAUDE_PLUGIN_ROOT}`  | The plugins reference documents that a top-level `bin/` is rejected by marketplace sync, which is how this repository distributes                                                                                                                                                                                                   |
| Feature 001's §10 was read as a standing prohibition on component directories     | Amended to record it as scoped to feature 001                               | The conflict check at Step 2 of this feature's run                                                                                                                                                                                                                                                                                  |
| The three drift-detection scenarios were assumed to cover the helper              | They compared three copies of four, never the divergent one                 | Comparing all four checksums rather than the three the scenarios name                                                                                                                                                                                                                                                               |
| The source was counted as 46 files, 38 distributed                                | 47 files, 39 distributed -- `speckit-run/reference/` holds 14 files, not 13 | Enumerating the source directory at the start of implementation, before the first `cp`. The withheld set is unchanged, still exactly the 8 paths T009 names; only the distributed figure moved. `plan.md` also said 22 Markdown files under `skills/`, where the measured figure is 31 -- the same figure §8 had recorded all along |
| `shellcheck` reported 0 findings over all 11 scripts                              | 3 `SC2312` findings                                                         | The measurement was run as `shellcheck --shell=sh --severity=style --external-sources`, which omits `.shellcheckrc`'s four `enable=` directives. `check-extra-masked-returns` is one of them, and it is the check that fires. Fixed by splitting three command substitutions                                                        |
| All 31 Markdown files passed Prettier unmodified, making the config decision free | Prettier rewrites 31 of them                                                | Prettier normalises `*emphasis*` to `_emphasis_`, which the earlier `--check` run did not report. `scripts/lint.sh --fix` applied it. The decision to drop the four `.markdownlint-cli2.jsonc` files is unaffected -- those are lint configs, not formatter configs -- but the "measured cost is zero" claim was wrong              |
| All 11 scripts were tab-indented with 0 space-indented lines                      | `copy-env-files.sh` had 7                                                   | The scan looked at leading characters and missed a tab followed by alignment spaces, which `.editorconfig`'s `indent_style = tab` rejects                                                                                                                                                                                           |
| Dropping the four lint configs cost no Markdown edits                             | It cost 8 files a top-level heading                                         | The four configs each switched `MD041` off. With them gone the root config's `MD041` rejects all 8 template files, every one of which starts at `##`. FR-027 was narrowed from "unchanged" to "content intact, plus a heading"                                                                                                      |
| `SC-014` counted 6 references to the scenario documents                           | 7                                                                           | Two instruction documents name their own scenario file twice, not one. The source already held 7, so the figure was wrong when written rather than changed by this feature                                                                                                                                                          |
| `quickstart.md` Scenario 6 tested the field with `grep -l`                        | An `awk` frontmatter scan with a per-file counter reset                     | `grep -l` matches the three companions' warnings about the field as readily as the field itself, and the first `awk` replacement omitted `FNR==1{n=0}`, so its counter carried across files and it printed nothing while appearing to pass                                                                                          |

## 14. FR-007's premise, checked rather than assumed

FR-007 requires the behaviour of an unresolvable dispatch to be specified, and `speckit-run` discharges part of that by deferring to "that skill's documented rule for an unavailable companion". T047b exists to check that this phrase names something real for each of the three dispatch targets. It does for two, and not for the third:

| Dispatch target    | Rule in its own `SKILL.md`                                                                            | Verdict                    |
| ------------------ | ----------------------------------------------------------------------------------------------------- | -------------------------- |
| `auto-github-pr`   | "`gh` unavailable → stop and say so", with the reason it does not invent a `curl` fallback            | Satisfied                  |
| `auto-gitlab-mr`   | "`glab` unavailable → MCP `save_merge_request`", with the `merge_request_iid` trap named              | Satisfied                  |
| `auto-commit-push` | **None.** It depends on no external CLI, so the condition its siblings document does not arise for it | **Rests on an assumption** |

For the third, the rule exists but lives in the dispatcher rather than the companion: `reference/ship.md` states that 6a's commit option "is unavailable when Step 0 recorded `auto-commit-push` as missing. Drop it, say why, and offer only 2 and 3 — never fall back to an inline `git commit`." That is a complete rule and it is what actually governs, so no run is left undefined. What is not true is the general claim that all three companions document their own unavailability. Recorded here rather than smoothed over, because the phrase in `speckit-run` invites a reader to go looking for a rule that, for one of the three, is not where they are told to look.

## Open questions

None blocking. Six documentation gaps are recorded above -- §2 (two), §3 (two), §4 (one), §5 (one), §9 (one) -- and each is either designed around or shown not to affect the decision it touches. The one worth revisiting when the documentation improves is **Gap 5**, cross-skill dispatch inside a plugin: this feature's central mechanism rests on observed host behaviour rather than a published guarantee, and a future release that changed how a skill addresses a sibling would break FR-005 with nothing in the documentation having promised otherwise.
