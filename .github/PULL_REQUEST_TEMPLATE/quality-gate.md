# Change proposal: the checking machinery

<!--
You opted into this structure by appending `?template=quality-gate.md` to the URL.
It repeats every section of the general structure rather than referring to it,
so nothing required goes missing when this one is used, and adds the question
below that only a change to the checking machinery raises.

If that question does not apply to your change, the general structure is the
right one: open the proposal without the `?template=` parameter.
-->

## What changed

<!-- What a reader would see if they read the difference. Facts, not intent. -->

## Why

<!-- The reason the change exists. What was wrong, or what was missing. -->

## Where to look first

<!--
The file and line a reviewer should open first, and what to look at there.
A proposal touching many files but turning on one decision should say so.
-->

## Checks

- [ ] `scripts/lint.sh` was run and passed
- [ ] `scripts/selftest.sh` was run and passed

<!--
If either was not run, or did not pass, say so here rather than leaving the box
unticked without explanation. An unticked box with no sentence beside it is
indistinguishable from an oversight.

This repository does not run the checks for you when a proposal opens, and does
not verify what you state here. The obligation is yours, and it is this:
-->

<!-- cite: .specify/memory/constitution.md -->

> Before a change is proposed for review, the aggregate quality check MUST have been run and MUST
> have passed. A change that has not been checked is not ready for review.

## How this was produced

- [ ] A coding agent produced this change
- [ ] A person typed this change

<!--
Where an agent produced it, link the session that did. A reviewer reading
unfamiliar work benefits from seeing what the author was actually asked to do,
and that is not recoverable from the difference itself.
-->

Session:

## For the reviewer

This review is obliged to verify compliance with the repository's six principles:

- **I. Tooling Independence** — a check runs with only POSIX `sh` plus a native tool or a container
- **II. Fail Fast** — a script exits non-zero on the first failure and does not continue
- **III. Pinned, Official Images** — every image pinned by tag and `sha256`; no floating tag
- **IV. POSIX Shell Only** — no bashisms, and shell static analysis passes with zero findings
- **V. Configuration Is Committed** — no undeclared default, no editor setting, no per-developer file
- **VI. Spec-Driven Change** — no implementation without a spec, a plan and a task list

The full text of each is in [`.specify/memory/constitution.md`](../../.specify/memory/constitution.md).
The obligation to verify them is this:

<!-- cite: .specify/memory/constitution.md -->

> All reviews MUST verify compliance with these principles. Added complexity MUST be justified
> against them; where it cannot be, the simpler alternative is taken.

## Proof the checks can still fail

<!--
A change to a check can weaken it in a way no passing run reveals: a check that
stopped examining anything at all passes every clean tree. `scripts/lint.sh`
exiting 0 is therefore not evidence about this change; `scripts/selftest.sh` is,
because it asserts every check still rejects a deliberately broken fixture.
-->

- [ ] `scripts/selftest.sh` passes, and every standard this change touches still rejects bad input
- [ ] A fixture was added or amended for any new or changed check
- [ ] Both resolution paths were exercised: native, and `LINT_FORCE_CONTAINER=1`

What the selftest reported:
