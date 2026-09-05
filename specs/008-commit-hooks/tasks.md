---
description: 'Task list for feature 008-commit-hooks'
---

# Tasks: Commit Message and Signature Enforcement

**Input**: Design documents from `/specs/008-commit-hooks/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md — all present

**Note on numbering**: T056 and T057 were added after `speckit-analyze` and carry the next free IDs rather than being inserted mid-sequence. Renumbering fifty-five tasks to keep IDs in execution order would have been a large, error-prone diff for a cosmetic gain; each sits in the phase it belongs to and the phase order is what governs execution.

**Tests**: Test tasks ARE included. This repository's `scripts/selftest.sh` exists to prove each check can reject bad input, and research §10 records that a new check with no selftest case is a check nobody has shown can fail. Test tasks are therefore requirements here, not an option.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Exact file paths are given in every task

## Path Conventions

Repository root is the working copy root. This feature adds files under `.husky/`, `scripts/hooks/`, `scripts/`, `docs/` and `.claude/rules/`, and edits four existing files. No `src/` or `tests/` tree exists in this repository and none is introduced.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: the files and directories every later phase writes into

- [x] T001 [P] Create `.commit-msg.conf` at the repository root with `COMMIT_MSG_TYPES='build chore ci docs feat fix perf refactor revert style test'`, `COMMIT_MSG_SCOPE_POLICY='optional'` and `COMMIT_MSG_MAX_SUBJECT='72'`, each with the explanatory comment described in `contracts/commit-msg-conf.md`
- [x] T002 [P] Create the `scripts/hooks/` directory and `.husky/` directory
- [x] T003 [P] Add `.husky/_/` to `.gitignore`, in the existing agent-local/machine-local section, with a one-line comment saying Husky generates it and gitignores it itself

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: make the new shell files subject to the repository's own shell check _before_ any of them is written, so no file is ever committed unchecked

**⚠️ CRITICAL**: T004 and T005 block every user story phase. A hook written before the check covers it is a hook the constitution requires be checked and that nothing checks.

- [x] T004 In `scripts/lint-shell.sh`, change `collect shell '*.sh'` to `collect shell '*.sh' '.husky/commit-msg' '.husky/pre-push'` so the two extensionless dispatchers are checked. `file_list` already accepts multiple globs (`scripts/lib/scope.sh`); no other change is needed
- [x] T005 Verify the change with `sh scripts/lint-shell.sh` and confirm the two dispatcher paths appear in the checked file list once they exist. Then determine explicitly whether the `.shellcheckrc` `lint-exclude-begin`/`lint-exclude-end` block needs a new entry, and **record the answer either way** — "no entry needed, because none of the new paths is excluded" is the expected result and is a finding, not silence. A conditional task that produces no artifact when the condition is false is a task nobody can confirm ran (analyze finding U2)
- [x] T006 [P] Add a fixture helper to `scripts/selftest.sh` that writes a commit-message fixture file under the existing `.lint-selftest-tmp/` work directory and returns its path, following the file's existing fixture conventions

---

## Phase 3: User Story 1 — Message convention enforced locally (Priority: P1)

**Goal**: a commit message that breaks the convention is refused, naming the rule and the offending text; a conforming one is accepted silently.

**Independent test**: three commits — non-conforming subject, over-length subject, conforming subject — the first two refused with rule-naming messages, the third accepted.

### Tests for User Story 1

- [x] T007 [P] [US1] Add a selftest case to `scripts/selftest.sh`: subject `add the thing` → `scripts/hooks/commit-msg.sh` exits `1` and stderr names the format rule
- [x] T008 [P] [US1] Add a selftest case: a 73-character conforming-shape subject → exits `1`, stderr names the 72 limit **and** prints the measured length `73`
- [x] T009 [P] [US1] Add a selftest case: a 72-character conforming subject → exits `0` with no stdout
- [x] T010 [P] [US1] Add a selftest case: conforming subject plus a 140-character body line → exits `0`, proving the limit governs the first line alone
- [x] T011 [P] [US1] Add a selftest case: subject `Merge branch 'main' into feature` → exits `0` under the generated-message exemption
- [x] T057 [P] [US1] Add a selftest case pair for FR-005a: `Revert "feat: the thing"` exits `0` via the generated-message exemption, and `revert: undo the thing` exits `0` via the permitted-type route. Both shapes are acceptable and neither excludes the other (analyze finding A1)
- [x] T012 [P] [US1] Add a selftest case: subject `wibble: something` → exits `1`, stderr names the format rule (unknown type)

### Implementation for User Story 1

- [x] T013 [US1] Implement `scripts/hooks/commit-msg.sh` per `contracts/commit-msg-hook.md`: `set -eu`, tab indentation, POSIX `sh`; take exactly one argument, the message-file path; locate the repository root relative to the script's own directory; source `.commit-msg.conf` and validate its three fields, exiting `2` naming the file if it is missing or invalid
- [x] T014 [US1] In `scripts/hooks/commit-msg.sh`, implement rule 0 — accept and exit `0` immediately when the subject begins `Merge`, `Revert`, `fixup!`, `squash!` or `amend!` (data-model §2)
- [x] T015 [US1] In `scripts/hooks/commit-msg.sh`, implement rules 1 and 2 — the subject must match `<type>[(<scope>)][!]: <description>` with `<type>` drawn from `COMMIT_MSG_TYPES`, a non-empty `<scope>` when present, a non-empty `<description>`, and the scope present or absent as `COMMIT_MSG_SCOPE_POLICY` requires. Skip comment lines when locating the subject
- [x] T016 [US1] In `scripts/hooks/commit-msg.sh`, implement rule 3 — first line at most `COMMIT_MSG_MAX_SUBJECT` characters; never examine any later line
- [x] T017 [US1] In `scripts/hooks/commit-msg.sh`, implement the refusal output on stderr: the rule broken, the subject reproduced verbatim, the measured length where a length rule broke, and the two bypass routes once. Nothing on stdout on success. Exit `1` for a refused message, `2` for usage or configuration error
- [x] T018 [US1] Create `.husky/commit-msg` — a three-line POSIX `sh` dispatcher that `exec`s `scripts/hooks/commit-msg.sh "$@"`, resolving the repository root from the hook's own location. Make it executable (`chmod +x`)
- [x] T019 [US1] Run `sh scripts/lint-shell.sh` and `sh scripts/selftest.sh`; both must pass with the six new cases green

**Checkpoint**: the message rule is enforceable and proven able to reject bad input.

---

## Phase 4: User Story 3 — Enforcement works on a fresh clone (Priority: P1)

**Goal**: one argument-free command activates the checks with no package manager, is idempotent, and reports whether they are active.

**Independent test**: in a clone with nothing extra installed, run the command, confirm the hooks fire; run it again, confirm it reports no change; query the state, confirm it reports active.

### Tests for User Story 3

- [x] T020 [P] [US3] Add a selftest case: `scripts/install-hooks.sh --status` in the fixture repository exits `0` and prints a final `active` or `inactive` line
- [x] T021 [P] [US3] Add a selftest case: running `scripts/install-hooks.sh` twice in a fixture repository leaves identical `git config --local` output, and the second run reports `already set` on every line
- [x] T056 [P] [US3] Add a selftest case: in a fixture repository with `user.signingkey` and `gpg.format` unset, `scripts/install-hooks.sh` exits `0`, reports both as `not configured`, and does **not** write either. This is the gap between FR-012 (arrange for signing) and the non-goal disclaiming key provision — `contracts/install-hooks-cli.md` specifies the behaviour and nothing asserted it (analyze finding G1)

### Implementation for User Story 3

- [x] T022 [US3] Implement `scripts/install-hooks.sh` per `contracts/install-hooks-cli.md`: `set -eu`, POSIX `sh`, tabs; accept no arguments or the single flag `--status`; any other argument exits `2`
- [x] T023 [US3] In `scripts/install-hooks.sh`, implement the `core.hooksPath` decision from research §3 — `.husky/_` when it exists and holds shims or is already configured, `.husky` otherwise. **Detect; never assume**, or a Husky user breaks on their next `npm install`
- [x] T024 [US3] In `scripts/install-hooks.sh`, set `--local commit.gpgsign true`, and report `gpg.format` and `user.signingkey` without writing either — they identify a person and a key (research §7)
- [x] T025 [US3] In `scripts/install-hooks.sh`, `chmod +x` both `.husky/commit-msg` and `.husky/pre-push` if present, since git silently skips a non-executable hook
- [x] T026 [US3] In `scripts/install-hooks.sh`, implement the five-part report: `core.hooksPath`, `commit.gpgsign`, `gpg.format`, `user.signingkey`, and the final `active`/`inactive` line that satisfies FR-013. Each write reports `set` or `already set`
- [x] T027 [US3] Run `sh scripts/lint-shell.sh` and `sh scripts/selftest.sh`; both must pass

**Checkpoint**: a fresh clone can activate both checks with one command and no package manager. Combined with Phase 3, this is the MVP.

---

## Phase 5: User Story 2 — Unsigned work stopped before it is shared (Priority: P2)

**Goal**: a send carrying an unsigned or badly signed commit is refused, every offender named, and nothing rewritten.

**Independent test**: one signed and one unsigned commit on a branch; the send is refused naming only the unsigned one; `git rev-parse HEAD` is unchanged; after re-signing, the send proceeds.

### Tests for User Story 2

- [x] T028 [P] [US2] Add a selftest case: a synthesised ref-update line whose range contains one unsigned commit → `scripts/hooks/pre-push.sh` exits `1` and names that commit's abbreviated SHA
- [x] T029 [P] [US2] Add a selftest case: a range whose commits all report `E` → exits `0`, proving an unverifiable-but-present signature is accepted (research §6)
- [x] T030 [P] [US2] Add a selftest case: empty stdin → exits `0`
- [x] T031 [P] [US2] Add a selftest case: a ref-update line whose local oid is all zeroes (a deletion) → exits `0` with nothing examined
- [x] T032 [P] [US2] Add a selftest case asserting the fixture repository's `HEAD` is byte-identical before and after a refused run. **State in the case's own comment what it does and does not prove**: selftest invokes `pre-push.sh` directly with synthesised stdin, so the script never had the opportunity to rewrite anything and this is a cheap regression guard against a future edit that adds one — not proof of FR-008. The actual proof is `quickstart.md` scenario 5, driven through a real `git push`, covered by T051 (analyze finding U1)

### Implementation for User Story 2

- [x] T033 [US2] Implement `scripts/hooks/pre-push.sh` per `contracts/pre-push-hook.md`: `set -eu`, POSIX `sh`, tabs; accept and ignore the remote name and URL arguments; read zero or more ref-update lines from stdin
- [x] T034 [US2] In `scripts/hooks/pre-push.sh`, compute the outgoing range per data-model §3 — skip all-zero local oids, handle the new-ref case by excluding commits reachable from other remote refs, otherwise `<remote-oid>..<local-oid>`
- [x] T035 [US2] In `scripts/hooks/pre-push.sh`, read each commit's signature status with `git log --format='%G? %h %s'` and refuse exactly `N` and `B`; accept `G`, `U`, `X`, `Y`, `R` and `E`
- [x] T036 [US2] In `scripts/hooks/pre-push.sh`, collect **every** offending commit across **every** ref update before exiting once with `1` — FR-007 requires the full list, and FR-014 records that this is not a departure from failing fast
- [x] T037 [US2] In `scripts/hooks/pre-push.sh`, print one stderr line per offender (abbreviated SHA, subject, which state) plus the remediation and the `--no-verify` escape with its consequence stated
- [x] T038 [US2] Create `.husky/pre-push` — a three-line dispatcher that `exec`s `scripts/hooks/pre-push.sh "$@"`, passing stdin through. Make it executable
- [x] T039 [US2] Run `sh scripts/lint-shell.sh` and `sh scripts/selftest.sh`; both must pass

**Checkpoint**: unsigned work cannot reach the remote, and no commit was ever rewritten to achieve that.

---

## Phase 6: User Story 4 — The conventions are written down where they are read (Priority: P3)

**Goal**: a human and an agent are held to the same rule from the same source.

**Independent test**: read the documentation cold and activate, satisfy and emergency-bypass the checks without opening a script.

- [x] T040 [P] [US4] Write `docs/husky-git-hooks.md`: what Husky is and is not; the `core.hooksPath` mechanism; why `.husky/_` is generated and gitignored and what that means for a fresh clone; the two activation paths; the Conventional Commits grammar and the length rule; that a reverting commit is acceptable in either shape, generated or `revert:`-typed (FR-005a); git's `%G?` status table and which two states are refused; the two bypass routes and when each is legitimate; deactivation via `git config --unset core.hooksPath`. Follow `.claude/rules/repository-docs.md`.
      **Do not transcribe `research.md`** (analyze finding D1). The two documents have different jobs and must not carry the same prose: `research.md` is the dated decision record — what was chosen, why, and what was rejected — and stays as written; `docs/husky-git-hooks.md` is the contributor-facing explanation of how the thing behaves and what to do when it refuses you, and carries no alternatives-rejected sections. Where the reasoning is genuinely needed in both, `docs/` states the conclusion and cites `specs/008-commit-hooks/research.md` for the argument, exactly as `.claude/rules/repository-docs.md` cites `docs/claude-code-practices.md` today
- [x] T041 [P] [US4] Write `.claude/rules/husky-git-hooks.md` with `paths:` frontmatter covering `.husky/**`, `scripts/hooks/**`, `scripts/install-hooks.sh` and `.commit-msg.conf`. State the rules an agent must follow when editing these files, and reference `docs/husky-git-hooks.md` for the reasoning rather than restating it — the same one-place-for-reasoning rule `.claude/rules/repository-docs.md` already applies
- [x] T042 [US4] Add one line to `CLAUDE.md`'s build/lint/test section giving the activation command, in the file's existing voice. Additive only; do not reformat or restructure the surrounding file
- [x] T043 [US4] Add a short paragraph to `CLAUDE.md`'s non-obvious list noting that the shell check's glob list now carries two extensionless paths, and why — a future tidy-up that removes them silently stops checking the hooks
- [x] T044 [US4] Run `sh scripts/lint.sh`; the markdown, format and editorconfig checks must pass on all three new or edited documents

**Checkpoint**: the rules are discoverable without reading code.

---

## Phase 7: User Story 5 — The toolkit's own skills reviewed (Priority: P3)

**Goal**: defects, risks and improvements in the six distributed skills identified with evidence, presented with options and a recommendation, and only approved ones applied.

**Independent test**: findings enumerated with checkable evidence; a decision recorded for each; the repository changed in exactly the approved ways and no others.

- [x] T045 [US5] Review the six skills under `skills/` — `ccd-branch-push`, `ccd-commit-push`, `ccd-conflict-resolve`, `ccd-github-pr`, `ccd-gitlab-mr`, `ccd-speckit-run` — against `docs/skill-authoring-practices.md` and `.claude/rules/skill-authoring.md`, recording each finding with a `file:line` citation
- [x] T046 [US5] Check the four load-bearing invariants `CLAUDE.md` names: the `ccd-` prefix on every directory and frontmatter `name`; namespaced cross-skill dispatch; `branch-options.sh` existing exactly once, in `ccd-branch-push`; and **zero** skills carrying `disable-model-invocation`, which is a committed contract at `specs/006-claude-code-guidance/contracts/skill-names.md`
- [x] T047 [US5] Record the drift already observed during this run: the installed plugin copy of `ccd-speckit-run/SKILL.md` is older than the repository's working copy — single Step-3 gate versus per-phase gates, `6d` versus `6e`, no `conflict_checks[]`, and an authoring note whose `disable-model-invocation` guidance contradicts the current one. Cite both copies
- [x] T048 [US5] Present every finding with at least two options, their costs, a recommendation and its justification, and obtain an explicit approval or decline for each — FR-020. Change nothing before approval
- [x] T049 [US5] Apply exactly the approved findings; record each declined one as declined with its reason — FR-021, SC-007
- [x] T050 [US5] Run `sh scripts/lint.sh` after any applied change

**Checkpoint**: every finding has a recorded disposition and the repository changed only where approved.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T051 Run every scenario in `quickstart.md` 1–5 and 7 against this working copy and confirm the stated expectations, in particular scenario 5's `git rev-parse HEAD` invariance
- [x] T052 Run `sh scripts/lint.sh` — all seven checks pass with no eighth added
- [x] T053 Run `sh scripts/selftest.sh` — all pre-existing cases plus the thirteen new ones pass
- [x] T054 Run `LINT_FORCE_CONTAINER=1 sh scripts/lint-shell.sh` and confirm the containerised path returns the same verdict as the native one for the new files
- [x] T055 Confirm no `package.json`, no `node_modules`, and no dependency was added anywhere in the tree — the Principle I guarantee this whole design exists to keep

---

## Dependencies

```text
Phase 1 (Setup)  ──►  Phase 2 (Foundational)  ──┬──►  Phase 3 (US1, P1) ──┐
                                                 │                         ├──►  Phase 6 (US4, P3) ──►  Phase 8
                                                 ├──►  Phase 4 (US3, P1) ──┤
                                                 │                         │
                                                 └──►  Phase 5 (US2, P2) ──┘

Phase 7 (US5, P3) is independent of every other phase and may run at any point after Phase 1.
```

- **Phase 2 blocks everything.** T004 puts the new shell files inside the check before any of them exists; writing them first means committing unchecked scripts.
- **US1, US2 and US3 are mutually independent** once Phase 2 is done. US3's installer sets `core.hooksPath` whether or not either hook exists; US1 and US2 write disjoint files.
- **US4 depends on US1, US2 and US3** only in that it documents their finished behaviour.
- **US5 depends on nothing here.** It touches `skills/`, which no other phase reads or writes.

## Parallel execution examples

Within Phase 3: **T007–T012** are six independent selftest cases and can be written together, but each appends to the same file — treat `[P]` here as "no logical dependency", and serialise the writes.

Within Phase 5: **T028–T032** likewise.

Across phases: **T040 and T041** (US4) write different files with no shared state and are genuinely parallel. **T045–T047** (US5) are three independent read-only sweeps over `skills/` and are the best fan-out candidate in the whole list.

## Implementation strategy

**MVP = Phase 1 + Phase 2 + Phase 3 + Phase 4.** That is US1 and US3, both P1: the message rule is enforced and a fresh clone can turn it on with one command. Shipped alone it already delivers the feature's core value.

**Increment 2** adds Phase 5 (US2, P2) — signature enforcement at push.

**Increment 3** adds Phases 6 and 7 (US4 and US5, both P3) — the written record, and the skill review.

Phase 8 runs after whichever increment is being shipped, never skipped: T055 in particular is the one check that would catch this design quietly acquiring the npm dependency it was built to avoid.
