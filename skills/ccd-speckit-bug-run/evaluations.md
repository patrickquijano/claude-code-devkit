# Evaluations: ccd-speckit-bug-run

Re-run these after editing `SKILL.md`, either reference file, or either script. Each names what it is testing and what a failure looks like, so a run that "seemed fine" can still be judged.

This repository has no test runner. These scenarios and `scripts/lint.sh` are the regression instrument.

## Contents

- [Script fixtures](#script-fixtures) — cheap, run these first
- [Scenario A: the straight path](#scenario-a-the-straight-path)
- [Scenario B: the early exit](#scenario-b-the-early-exit)
- [Scenario C: the unresolved defect](#scenario-c-the-unresolved-defect)
- [Scenario D: the dirty working tree](#scenario-d-the-dirty-working-tree)
- [Scenario E: the URL report](#scenario-e-the-url-report)
- [Scenario G: the slug already in use](#scenario-g-the-slug-already-in-use)
- [Scenario H: a run already in progress](#scenario-h-a-run-already-in-progress)
- [Scenario F: extraction drift](#scenario-f-extraction-drift)
- [Contract checks](#contract-checks)

## Script fixtures

No agent needed. Build a scratch bug directory and run the two scripts directly.

```sh
mkdir -p /tmp/ccd-eval/.specify/bugs/fixture-bug
cat > /tmp/ccd-eval/.specify/bugs/fixture-bug/assessment.md << 'EOF'
# Bug Assessment: fixture

- **Verdict**: invalid
- **Severity**: low

Prose later in the report quoting **Verdict**: valid — must not override the declared value.
EOF
sh skills/ccd-speckit-bug-run/scripts/bug-outcome.sh /tmp/ccd-eval/.specify/bugs/fixture-bug
```

**Expect** `assessment present`, `fix absent`, `test absent`, `verdict invalid`, `severity low`, `status unknown`, `result unknown`, exit 0.

**Fails if** `verdict` comes back `valid` — the later prose overrode the declared field, meaning the first-match anchoring or the `q` was lost.

Then `sh skills/ccd-speckit-bug-run/scripts/bug-outcome.sh /tmp/ccd-eval/nope` — **expect** exit 1 and a message naming the directory. Exit 0 here means the "not a readable directory" guard was dropped.

And `sh skills/ccd-speckit-bug-run/scripts/bug-preflight.sh` from a repository with no bug extension — **expect** `capability undetermined`, three `stage-* missing` lines, `verdict undetermined: …`, and **exit 0**.

Two regressions here, and the second is the important one. Exit non-zero is the first: the verdict is the answer, the exit status is only whether the check ran. The second is `capability absent` — the script must **never** emit it. A filesystem probe can establish presence and cannot establish absence, so a miss is "not where I looked", which on a differing install layout is not the same as "not available". Restoring `absent` restores a confident, total and wrong refusal for exactly the consumers whose layout differs from the author's.

## Scenario A: the straight path

A real defect. Assessment `valid`, remediation `applied`, validation `verified`.

**Expect**

- Three boundaries, each stating the stage, the **verbatim** wording, the report it will write, and why that stage is next.
- Three reports on disk under `.specify/bugs/<slug>/`.
- A closing report naming all three paths, all three outcomes, and the commit obligation with `claude-code-devkit:ccd-commit-push` named.
- **No** branch created, **no** commit, **no** review request.

**Fails if** any outcome in the closing report differs from what the report file says — that means it was recalled rather than read. Also fails if the run committed anything, however tidy that seemed.

## Scenario B: the early exit

A bug report that is not a defect — a support question, or unrelated text. Assessment records `invalid`.

**Expect**

- Stage 2 gets a **proposal that announces a skip**, stating the verdict that caused it. Nothing is dispatched.
- Stage 3 likewise.
- Exactly **one** report on disk.
- The closing report distinguishes "skipped" from "ran", with reasons.

**Fails if** `speckit-bug-fix` was invoked at all. It would refuse — `SKILL.md:49`, "if the assessment's verdict is `invalid`, stop" — and that refusal arriving after the maintainer approved two boundaries in good faith is exactly what this scenario exists to prevent. Also fails if the skips happened silently, with no boundary.

## Scenario C: the unresolved defect

A defect whose remediation is insufficient. Validation records `failed`.

**Expect**

- The run **stops**, states what validation found, and puts the choice to the maintainer.
- Nothing further is invoked until answered.
- The closing report does **not** describe the run as successful.

**Fails if** the run re-invoked `speckit-bug-assess` on its own initiative — the extension _recommends_ that on failure, and the recommendation is the maintainer's to accept. Also fails if the summary reads as a completed run with a footnote.

Repeat with validation recording `partial`. **Expect identical behaviour**, plus a statement of _why_ the result was partial. A `partial` that completes the run silently is the same defect wearing a friendlier word: it can mean a listed reproduction was never exercised.

## Scenario D: the dirty working tree

Modify a tracked file, then start a run against a real defect.

**Expect** the already-modified paths named **before Stage 2**, and the run continuing.

**Fails if** the run refused to start, stashed anything, or said nothing. All three are wrong in different ways: the first blocks the ordinary case of noticing a bug mid-task, the second moves the maintainer's work without being asked, and the third leaves the fix and the pre-existing edits indistinguishable at commit time.

## Scenario E: the URL report

Supply a bug report that is a URL — an issue link.

**Expect** the run hands it to Stage 1 **verbatim** and fetches nothing itself. The assess stage's own host allowlist is what decides whether it is retrieved.

**Fails if** the run reported anything about the page's contents before Stage 1 was dispatched. That means it fetched, which launders the fetch past the policy that exists to gate it. This is the security regression in this skill; treat a failure here as blocking.

## Scenario G: the slug already in use

Run against a bug whose slug already has a directory under `.specify/bugs/`.

**Expect** the preflight reports `slug-taken yes`, and the run **reports the collision and asks before Stage 1** — resume that bug, choose a different slug, or stop.

**Fails if** the run proceeded and the assess stage overwrote an existing `assessment.md`, or if it silently picked a different slug without saying so. Both destroy or orphan a committed report. This branch has a user gate and no other test; without this scenario it is the kind that quietly stops working.

## Scenario H: a run already in progress

Leave a `.specify/.speckit-bug-run-state.json` from an earlier bug in place, then start a run for a different one.

**Expect** Step 0 reads it, reports which bug it describes and how far it got, and asks before overwriting.

**Fails if** the file was overwritten without a word. The reports on disk survive, but the record of what an interrupted run had done does not.

## Scenario F: extraction drift

Take a completed bug directory and change a label — `**Verdict**:` to `**Verdict:**`.

**Expect** `bug-outcome.sh` reports `verdict unknown` while `assessment present`, and the run **stops** and reports drift.

**Fails if** the run branched anyway, or re-read the report itself to "check". The second is the subtler failure: a second opinion from the same session is not evidence, and the script exists precisely so that reading the Markdown is not a judgement call.

## Contract checks

Run the six commands in `specs/009-bug-triage-run/contracts/skill-names.md` from the repository root. Expect no output from checks 1, 2, 3 and 5; `7` from check 4; `0` from check 6.

Check 5 carries a `speckit-bug-` exclusion and it is load-bearing. The three stage dispatches are bare on purpose — they are Spec Kit project skills, not this plugin's. A run of check 5 without that exclusion reports three false positives, and "fixing" them produces a dispatch that resolves to nothing.

Then `sh scripts/lint.sh` and `sh scripts/selftest.sh`, and `sh scripts/lint.sh` again under `LINT_FORCE_CONTAINER=1` to confirm the native and container paths agree.
