# Phase prompt rules

How to write the prompt argument for each Spec Kit phase. Each phase wants a different _kind_ of content; mixing them is the failure mode this file prevents.

## Contents

- Naming forms
- Phase 1 — constitution
- Phase 2 — specify
- Phase 3 — clarify
- Phase 4 — checklist
- Phase 5 — plan
- Phase 6 — tasks
- Phase 7 — analyze
- Phase 8 — implement
- Leakage check before the prompt-review gate

## Naming forms

Both `/speckit.<cmd>` (slash command) and `speckit-<cmd>` (skills mode) exist, depending how Spec Kit was installed for this agent. Step 0 of `SKILL.md` resolves which. Everything here is the prompt _argument_, identical under either form.

## Phase 1 — constitution

Governing principles for the whole repository, not for this feature.

**DO**

- Durable, repo-wide principles in imperative form: "MUST", "MUST NOT".
- Each principle testable, so the plan phase's gates can check it. "Every public endpoint MUST have a contract test" is checkable; "code should be clean" is not.
- Repo-wide engineering standards: mandated test framework, coverage floor, review requirement, dependency policy.
- Respect a principle count if the user named one.

**DON'T**

- No feature requirements — they belong in `spec.md`.
- No per-feature tech choices — they change next feature, belong in `plan.md`. A repo-wide standard ("all services MUST expose OpenAPI") is fine; a feature's library pick is not.
- Never invent a ratification date. Run `date +%Y-%m-%d`.

## Phase 2 — specify

WHAT users need and WHY. The phase people corrupt most often.

**DO**

- User needs, user stories, measurable acceptance criteria.
- Explicit non-goals.
- Mark every unknown as `[NEEDS CLARIFICATION: the specific question]` instead of assuming an answer. Task description silent on something → mark it.

**DON'T**

- No languages, frameworks, libraries, versions.
- No database or schema choices.
- No API endpoint shapes, class names, file layout.
- No implementation sequencing.

Hold every tech choice the user stated for the Phase 5 prompt. Dropping it here is not losing it.

**Worked example.** Task: "add rate limiting to the public API, use Redis, 100 req/min per key".

Leaked specify prompt — names the datastore, so `spec.md` inherits an implementation decision it can never justify:

```text
Add Redis-backed rate limiting to the public API at 100 requests per minute per API key.
```

Corrected — same requirement, no technology:

```text
Public API consumers must be limited to 100 requests per minute per API key. Over the limit, a request is rejected with a response that states when the caller may retry. Non-goals: per-endpoint limits, per-user limits, quota purchasing. [NEEDS CLARIFICATION: are limits enforced per API key only, or also per source IP?]
```

The held-back choice reappears in the Phase 5 prompt, where it belongs:

```text
Enforce the spec's rate limit with Redis, using a sliding-window counter keyed by API key. Redis is already the session store — reuse that connection pool rather than adding a second client.
```

## Phase 3 — clarify

Only when the spec carries `[NEEDS CLARIFICATION]` markers, or the previous phase asked for clarification. Otherwise skip, say why at the gate.

**DO**

- Name the specific ambiguous areas rather than asking for a general review.
- Quote the markers verbatim with file locations, so the phase resolves the real ambiguities and not adjacent ones.

**DON'T**

- Never answer the markers yourself in the prompt. The point of the phase is that the user answers.

## Phase 4 — checklist

**DO**

- State the validation dimension — requirements completeness, clarity, consistency, testability.
- Keep it about the spec's quality, not the feature's content.

**DON'T**

- Never restate the feature. A checklist prompt describing the feature produces a feature summary instead of a validation instrument.

## Phase 5 — plan

Where every held-back technical decision goes.

**DO**

- Language, framework, versions.
- Datastore, integration points, external services.
- Testing strategy, performance or scale constraints.
- Consistent with the spec.

**DON'T**

- Never introduce a requirement absent from `spec.md`. Plan needs one → the spec is wrong; revise the spec rather than smuggling it in here.
- Never restate user stories; the phase reads `spec.md` itself.

## Phase 6 — tasks

Normally argument-free. Pass one only for an ordering preference — tests before implementation — or to cap scope.

## Phase 7 — analyze

Argument-free. After `tasks`, before `implement`.

Read its findings carefully — they are the cross-artifact drift check. Every finding is a conflict to route through `reference/conflicts.md`, not a note to pass along.

## Phase 8 — implement

Normally argument-free; executes `tasks.md`. Pass one only for an explicit scope limit — a single user story, or one phase of the task list — when the user asked for partial implementation.

## Leakage check before the plan presentation

This check is why all eight arguments are drafted together at Step 3 even though each one is approved separately at its own phase. A technology leaking out of the plan prompt and into the specify prompt is invisible when the specify prompt is read alone; it is visible only with both in front of you. Drafting together catches it. Report its result with the plan.

Before presenting the eight drafted prompts, verify:

- Specify prompt names no language, framework, library, datastore, endpoint, or file path.
- Plan prompt names the stack, and every tech choice the user stated appears there rather than in the specify prompt.
- Constitution prompt contains nothing specific to this feature.
- Every unknown appears as a `[NEEDS CLARIFICATION: question]` marker rather than a guessed answer.
- No prompt restates content the phase reads from an artifact on disk.
