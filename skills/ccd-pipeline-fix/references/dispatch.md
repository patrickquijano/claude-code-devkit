# Composing the report, and handing it over

Read before Step 4. This is where the skill stops working and starts delegating, and the whole of its correctness is in doing that cleanly.

## Contents

- What the report carries
- Showing it before sending it
- The dispatch
- What travels, and what must not
- FR-015 and FR-016 are discharged here, not implemented
- After the handover
- Never

## What the report carries

Three things, in this order:

1. **The evidence** — which run, which job, and the failing output as displayed at Step 1, with any omission still marked.
2. **The approved root cause** — as approved at Step 2, with the specific evidence quoted beneath it.
3. **The chosen approach** — as chosen at Step 3, together with the alternatives that were offered and not taken.

The alternatives are included deliberately. `speckit-bug-assess` writes a **Proposed Remediation** section that `speckit-bug-fix` treats as its contract, and an assessment that can see what was rejected produces a better one than an assessment handed a single option with no context.

## Showing it before sending it

The report is **displayed verbatim and is revisable** before it is sent.

From the moment the user approves that text it is theirs, and it is passed on byte-identical. This is the same rule the bug workflow applies to a report a maintainer typed themselves — the fact that this one was composed here changes nothing about it afterwards. Never edit it after approval, never "tidy" it in passing, never summarise it into the dispatch.

## The dispatch

```text
Skill(skill: "claude-code-devkit:ccd-speckit-bug-run")
```

Namespaced, because a bare `ccd-speckit-bug-run` resolves to whichever copy the session picks when a personal skill shares the name.

**Dispatch is a tool call.** Writing the skill's name in prose loads nothing: its `SKILL.md` never opens, its preflight never runs, its three gated stages never happen, and the work then proceeds under none of its rules while appearing to have been delegated.

A slug travels only if the user supplied one. It is flat and user-named — no `NNN-` prefix, no `specs/` root; that convention belongs to mainline features, not to bugs.

## What travels, and what must not

| Travels                                | Does not travel                                                               |
| -------------------------------------- | ----------------------------------------------------------------------------- |
| The composed report, as report content | Any argument to `speckit-bug-assess`, `speckit-bug-fix` or `speckit-bug-test` |
| A user-supplied slug                   | A slug this skill invented                                                    |
| —                                      | The root cause restated as a stage argument                                   |

The root cause and approach travel **inside the report**, never as arguments to a stage. `reference/stages.md` in the bug-run skill is explicit that Stage 1 receives the report and Stages 2 and 3 receive nothing but the slug, because restating assessment content in an argument duplicates a file the stage is about to read — and the two copies disagree the moment either is revised.

**No URL inside the report is pre-fetched.** `speckit-bug-assess` applies its own host allowlist and untrusted-input policy to URLs it is given. Fetching one first hands it prose instead of a URL, and those rules never fire.

## FR-015 and FR-016 are discharged here, not implemented

Two of this feature's requirements have no implementation in this skill, and that is correct rather than an omission:

- **FR-015** — the assessment, fix and verification records on disk. `ccd-speckit-bug-run` produces all three by running the three stages. This skill produces none of them and must not.
- **FR-016** — the offer to return to diagnosis when validation does not clear the defect, uncapped, never taken on the run's own initiative, with the cycle count stated. That offer belongs to the dispatched workflow and is governed by `.claude/rules/spec-kit-bug-workflow.md`.

**Reimplementing either here would breach FR-014**, which forbids duplicating that workflow's stages. If a validation result needs handling, the workflow handles it; this skill has already ended.

Recorded so that a reader who greps this feature's requirements for coverage finds the answer rather than a gap. Reasoning: `specs/011-narrow-gates-pipeline-fix/research.md` R6.

## After the handover

The dispatched skill owns everything that follows: its three separately gated stages, the loop-back offer on a `partial` or `failed` result, its commit dispatch and its review request.

Report where things ended and stop. Do not summarise its stages as though this skill had run them, and do not report a fix as verified on the strength of the dispatch having returned — the workflow reports its own result.

## Never

- Never dispatch `speckit-bug-assess`, `speckit-bug-fix` or `speckit-bug-test` from here.
- Never edit a source file.
- Never send a report the user has not seen.
- Never alter the report after approval.
- Never pre-fetch a URL that appears in it.
- Never invent a slug.
- Never restate assessment content as a stage argument.
- Never claim the defect fixed. That is the dispatched workflow's finding to report.
