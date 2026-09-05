# Evaluations

## Contents

- E1 — the happy path: evidence, cause, approach, dispatch
- E2 — no CLI, no auth, no forge: three skips that must not stop the run
- E3 — the two terminal exits
- E4 — ambiguity: more than one failure
- E5 — degenerate evidence
- E6 — the dispatch is real, and nothing past it is this skill's
- E7 — script regressions, no forge needed
- Re-test after editing the skill

Seven scenarios. Run against a scratch repository before trusting a change. Each states setup, invocation and the behaviour that must hold — catching a regression, not scoring prose.

**This repository cannot run E1 through E6 against itself.** It has no CI pipeline — no `.github/workflows/`, no `.gitlab-ci.yml` — so a repository with a real failed run is required. Only E7 runs here. Say so rather than reporting the others as passed.

## E1 — The happy path

**Setup**: a repository on GitHub with at least one failed workflow run on the current branch, `gh` installed and authenticated, the Spec Kit bug extension installed, `ccd-speckit-bug-run` available.

**Invoke**: `/ccd-pipeline-fix`

**Expect, in this order**:

- Step 0 names the forge and announces `retrieval-path cli` **before** anything is gathered.
- The failing log is displayed **before** any cause is proposed. A run that proposes first and shows evidence afterwards has inverted the ordering that stops evidence being selected to fit.
- The root cause arrives with specific evidence quoted from what was displayed, and nothing has changed yet.
- At least two remediation approaches, each with effect and cost, exactly one marked recommended, with its reason.
- The composed report is shown verbatim and can be revised.
- `claude-code-devkit:ccd-speckit-bug-run` is dispatched as a **tool call**, visible as a skill invocation.

**Then**: `.specify/bugs/<slug>/` holds `assessment.md`, `fix.md` and `test.md`, and `git diff` shows no file this skill edited itself.

**Fails if**: any source file changed before the dispatch; a cause was proposed before the log was shown; only one "alternative" was offered; the report was sent without being displayed.

**Repeat the whole scenario on GitLab.** Two of these legs pass trivially when the commands are hard-coded to one forge, which is exactly why the second leg is the test.

## E2 — No CLI, no auth, no forge

Three variants, and **none of them stops the run**.

**V1 — CLI absent.** Remove `gh` from `PATH`. Expect: Step 0 says the CLI is not installed, announces `maintainer-supplied`, asks for the failing output, and continues to Step 2 from what is pasted.

**V2 — CLI present, not authenticated.** `gh auth logout` first. Expect the same, but naming _not authenticated_ and `gh auth login` — a different fix from V1, which is why the two are reported differently rather than as "could not fetch".

**V3 — unsupported forge.** A Bitbucket or local-path remote. Expect the host named, `maintainer-supplied`, and the run continuing.

**Fails if**: any variant halts; any two report the same message; the retrieval path is discovered partway rather than announced at Step 0.

## E3 — The two terminal exits

**V1 — cause outside the repository.** Point the skill at a failure caused by an expired registry token or a provider outage. Expect: reported as the finding, run stops, **nothing dispatched**, and the report does not apologise for producing no code change. A successful diagnosis is a result.

**V2 — the fix would alter a requirement.** A failure whose only fix adds a configuration option nobody specified. Expect: reported as feature work, `/ccd-speckit-run` named as its path, Constitution Principle VI cited, and the defect path **not entered**.

**Fails if**: either case dispatches the bug workflow anyway; V2 is treated as a small enough change to push through.

## E4 — More than one failure

**Setup**: three failed runs, one of them with two failing jobs.

**Expect**: the candidates are listed with what distinguishes them, and the skill **asks**. Selecting several jobs together is accepted and the report covers all of them. Where the candidates look unrelated, no recommendation is given and that is said explicitly rather than defaulting to the newest.

**Fails if**: a candidate is chosen silently. This is the regression that gets the wrong failure fixed and looks like a working run.

## E5 — Degenerate evidence

Retrieval succeeds but returns an empty log, a truncated one, or one expired past retention.

**Expect**: what arrived is reported as such, the user is asked for the output, and **no cause is proposed from it**.

**Fails if**: an empty log produces a root cause, or is read as evidence that the failure was transient. A cause invented from nothing is the worst output this skill can produce, because it looks exactly like a real one.

## E6 — The dispatch is real

**Expect**: a `Skill` tool call. Prose naming `claude-code-devkit:ccd-speckit-bug-run` is not a dispatch — the target's `SKILL.md` never loads, its preflight never runs, its three gated stages never happen, and the work proceeds under none of its rules while appearing delegated.

**Also expect**: after the dispatch returns, this skill reports where things ended and stops. It does not restate the stages as though it ran them, and it does not report the defect fixed — the dispatched workflow reports its own result.

**Fails if**: the skill summarises a fix as verified on the strength of the dispatch having returned; any of the three `speckit-bug-*` stages is dispatched directly.

## E7 — Script regressions

Runs anywhere, no forge and no failed run needed.

```sh
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" sh skills/ccd-pipeline-fix/scripts/pipeline-evidence.sh
```

Set `PLUGIN_ROOT` to the installed plugin's directory first. It is written as a variable rather than as a bracketed placeholder because Prettier's shell plugin parses `<…>` inside a `sh` fence as a redirect and rewrites the line — a trap `.claude/rules/repository-docs.md` records and this file walked into once.

- **R1** — outside a git work tree: `verdict skip: not a git repository`, **exit 0**. Not a failure.
- **R2** — in a repository with no failed run: `verdict skip: no failed run found`, exit 0, `candidates 0`.
- **R3** — `forge`, `forge-cli`, `cli-status`, `retrieval-path`, `candidates` and `verdict` are all emitted, tab-separated, on every path.
- **R4** — `CLAUDE_PLUGIN_ROOT` unset or `forge-detect.sh` unreachable: emits a `note` line and still produces a verdict rather than dying.
- **R5** — the script never calls `git` for anything but `rev-parse` and `symbolic-ref`, and writes nothing.
- **R6** — `sh scripts/lint-shell.sh` reports zero findings under `shell=sh` with the four opt-in rules.

**Read the `verdict` line, never the exit status.** Every skip above exits 0, and a test asserting non-zero on a skip has encoded the opposite of the contract.

## Re-test after editing the skill

Any edit touching the per-forge commands in `reference/evidence.md`: run **E1 on both forges**, not one. A single-forge test passes on an instruction that is wrong for the other, and the wrong CLI succeeds rather than erroring.

Any edit touching Step 0, the CLI probe, or the retrieval-path announcement: run **E2 in all three variants** and R1–R4. The three variants exist because collapsing them into "could not fetch" tells the user which of three different fixes to apply: none.

Any edit touching the terminal exits: run **E3**. V2 is the one that regresses quietly — a fix that alters a requirement is easy to wave through as small.

Any edit touching the dispatch, the composed report, or `reference/dispatch.md`: run **E6**, and re-read the diff for a prose mention of the sub-skill that replaced a tool call.

Any edit touching candidate selection: run **E4**. Silent selection is invisible in a transcript that otherwise looks correct.

Any edit touching the outcome vocabulary: confirm it is still a closed set of six and that no seventh value was introduced as a convenience.

Any edit to the frontmatter: confirm `name` still equals the directory basename, both still carry the `ccd-` prefix, and **neither `disable-model-invocation` nor `user-invocable` has appeared**. The count is a committed contract at `specs/011-narrow-gates-pipeline-fix/contracts/skill-names.md`.

Any edit rewriting prose: re-run E1 and E3 end to end, and re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for one is too terse for another.
