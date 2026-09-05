# Evaluations — ccd-branch-push

Five scenarios exercising what fails first. Run against a scratch repo before trusting a change to the skill. Each states setup, invocation, and correct behavior — catching a regression, not scoring prose.

## Contents

- E1 — Many branches, option-set cap
- E2 — Named base that does not exist
- E3 — Repo convention conflicting with a hard rule
- E4 — Derived name already taken, including by another worktree
- E5 — Invoked from inside a git worktree, and a repo with no `origin`
- Re-test after editing the skill

## E1 — Many branches, option-set cap

**Setup**: clone with 13 branches at staggered commit dates, `origin/HEAD` → `main`, current branch is a local-only branch, two files edited but uncommitted.

**Invoke**: `/ccd-branch-push create a branch for these changes`

**Expect**:

- Step 1 passes preflight: work tree, attached HEAD, remote present.
- Step 3 runs `scripts/branch-options.sh` and asks with **exactly four** options, never thirteen.
- `main` is the first option, carries `(Recommended)`, and its `description` names its last-commit date and `both`.
- The question text says the candidate list was truncated.
- `header` is `Base`, 4 characters.
- Step 6 asks a two-option Yes/No with `header: "Create?"` — not a prose "shall I proceed?".
- Nothing is created before that `Yes`. Declining leaves the branch list unchanged.

## E2 — Named base that does not exist

**Setup**: same clone. No branch named `staging` locally or on the remote.

**Invoke**: `/ccd-branch-push branch off staging for this work`

**Expect**:

- Step 3 checks `staging` against the script output, does not find it, and **asks** rather than creating `staging` or silently substituting `main`.
- The question explains that the named base was not found, and the four ranked candidates are offered.
- Contrast case: invoking with `branch off develop` — which _is_ in the output — skips the question entirely and uses `develop`. One `AskUserQuestion` call for the whole run, not two.

## E3 — Repo convention conflicting with a hard rule

**Setup**: same clone plus `CONTRIBUTING.md` mandating `users/<name>/<jira-id>-<long-description>`, a pattern whose realistic instances exceed the 72-character cap. Existing remote branches already follow it.

**Invoke**: `/ccd-branch-push make a branch for the audit-log pagination work`

**Expect**:

- Step 4 detects the convention from both the branch names and `CONTRIBUTING.md`.
- The contradiction with the 72-character cap fires an `AskUserQuestion` with `header: "Convention"` and three options: follow the repo convention first as `(Recommended)` with the observed evidence quoted, follow the skill's cap, abort.
- No branch name is chosen before that answer — the skill does not silently truncate or silently obey.
- Every option `description` carries a justification and the cost of not picking it.

## E4 — Derived name already taken, including by another worktree

**Setup**: same clone. Three variants, run each separately. (a) A local branch `feat/audit-log-pagination` already exists, not checked out anywhere. (b) That branch does not exist locally but does on the remote. (c) It exists locally **and is checked out in a second worktree** at `../hotfix`.

**Invoke**: `/ccd-branch-push make a branch for the audit-log pagination work` — phrased so Step 5 derives that exact name.

**Expect, all three**:

- Step 5b runs **before** Step 6, with all three probes: `git show-ref --verify --quiet refs/heads/<name>`, `git ls-remote --heads origin <name>`, `git worktree list --porcelain`. Probing after the gate, or not at all, is the headline regression — `git switch -c` is fatal on an existing name, so the run then asks for approval, receives it, and dies on something that was never possible.
- The collision fires an `AskUserQuestion` with `header: "Name taken"` that states **where** the name is taken, and offers a suffixed variant the skill has itself verified free, recommended first and quoted by name.
- No branch is created, and no name is chosen, before that answer. A silent `-2` suffix fails this scenario even though the resulting name is free: the user never saw that their intended name was taken.
- `git branch -f`, `git switch -C`, and any `--force` are absent throughout.

**Per variant**:

- (a) local only → the "switch to the existing branch instead" option **is** offered; the branch is not checked out anywhere, so git can check it out here.
- (b) remote only → `git switch -c` would in fact succeed locally, but the Step 7 `git push -u` then pushes onto someone else's branch. The question still fires, and the option to reuse is framed as tracking the existing remote branch, not as creating a new one.
- (c) checked out in `../hotfix` → the question **names that path**, because it is what tells the user this is their own parallel work rather than a stale leftover. The "switch to the existing branch" option is **absent**: git cannot check the same branch out in two worktrees, so offering it would offer a command that must fail.

**Also**: the Step 0 skip-approval phrase does **not** suppress Step 5b's question. Re-run variant (a) with "auto-approve, don't ask" and confirm the collision question still fires while Step 6's gate is skipped.

**The regression this catches**: a name derived, approved, and only then discovered to be impossible. Every probe here is cheap and read-only; the cost of skipping them is paid after the user has already said yes.

## E5 — Invoked from inside a git worktree, and a repo with no `origin`

**Setup**: main checkout on `main`; a second worktree at `../feature-b` with `dev` checked out and two files edited. **Invoke from inside `../feature-b`.**

**Invoke**: `/ccd-branch-push create a branch for these changes`

**Expect**:

- Step 1's `git rev-parse --git-dir --git-common-dir` returns two **different** paths, and Step 6's summary names `../feature-b` as the tree whose `HEAD` will move. Omitting it is the regression: with several worktrees open, "created and checked out" does not say where, and the user cannot tell which tree just moved.
- Step 2's `git status` / `git diff` read **this** worktree's changes, so the derived name describes the two edited files here — not anything in the main checkout.
- Choosing `main` as the base works even though `main` is checked out in the main checkout. `git switch -c <name> main` cuts from that base's commit and does not check the base out, so there is nothing to refuse. A skill that blocks here, or that reaches for `--force`, has misread the constraint — it applies to `git worktree add`, not to `git switch -c`.
- The uncommitted changes travel onto the new branch inside this worktree. The main checkout is untouched and unmentioned.
- Nothing `cd`s, nothing uses `git -C`, and no `git worktree add` appears anywhere.

**Second half — no `origin`.** Same repo, but the only remote is named `upstream`.

- Step 1's `git remote get-url origin` fails, and the run **asks** which remote to push to rather than proceeding. A bare "is there a remote" check passes here and the run then dies at Step 7's `git push -u origin` — after the approval gate, which is the same class of failure as E4.
- The chosen remote name is used in Step 7 and named in Step 6's summary. A hardcoded literal `origin` anywhere in the executed commands fails this half.

**The regression this catches**: two assumptions that hold in the common case and fail silently outside it — that there is one working tree, and that the remote is called `origin`.

## Re-test after editing the skill

`branch-options.sh` exists **once**, in this skill, and the other three consumers reach that one copy through `${CLAUDE_PLUGIN_ROOT}`. There are no copies to drift apart, so the check is no longer a comparison — it is that the single implementation is still single, and that every consumer still resolves to it:

```bash
test "$(find skills -name branch-options.sh | wc -l)" -eq 1 || echo "MORE THAN ONE IMPLEMENTATION"
find skills -name branch-options.sh                                             # expect skills/ccd-branch-push/scripts/branch-options.sh
grep -rl 'ccd-branch-push/scripts/branch-options\.sh' skills/*/SKILL.md | wc -l # expect 4
```

A second copy appearing anywhere under `skills/` is the regression this replaces the old `cmp` check with. The old check compared three of the four copies that used to exist and never the fourth, which is how a divergent fork survived in `ccd-speckit-run` unnoticed; a count cannot miss a copy the way a comparison can.

After any edit to `SKILL.md`: walk E1–E5 against the changed text and confirm each still prescribes the stated behavior. Any edit touching Step 5b, Step 7's create command, or the Boundaries name rules: walk E4, all three variants. Any edit touching Step 1's probes, the remote handling, or the worktree rules: walk E5, both halves, from inside a real worktree. After any edit to `scripts/branch-options.sh`: `sh -n` it, then run it in a work tree, in a repo with no commits (expect silent exit 0), in a detached-HEAD checkout (expect no `current` tag), and outside a git repo (expect exit 1 with a message). Re-read the diff for rules softened from imperative into description. Test on the models that will run it — terse enough for Opus can be too terse for a smaller model.

## The question standard

Every ask in this skill goes through `AskUserQuestion` with options, per-option effect and cost, exactly one `(Recommended)` and the reason for it — or an explicit statement that no recommendation is defensible. The rule lives once, in `.claude/rules/skill-authoring.md`; this skill restates none of it.

**Regression to re-check after any edit that touches a question**: no ask site instructs asking without naming the tool, no question offers options with no recommendation and no explanation of why none is given, and no local copy of the rule has crept back in. Run:

```sh
grep -n "Every question in this skill goes through" SKILL.md
```

Zero hits is correct. A hit means the repository-wide rule now has a second copy, which is the drift `.claude/rules/repository-docs.md` calls worse than having no rule at all.
