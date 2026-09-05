# Design review: `ccd-speckit-bug-run`

Covers FR-026. Written after T001–T032 built the skill, and before the feature's verification step — the order matters, because most of what follows was only visible once the thing existed.

Every finding below was put to the maintainer with options before anything was changed. The resolutions are theirs; the evidence and the recommendations are this document's.

## Contents

- [What was checked and cleared](#what-was-checked-and-cleared)
- [R1 — the preflight concluded absence from a filesystem test](#r1--the-preflight-concluded-absence-from-a-filesystem-test)
- [R2 — bare-name dispatch against directory-scoped variants](#r2--bare-name-dispatch-against-directory-scoped-variants)
- [R3 — no detection of an existing run](#r3--no-detection-of-an-existing-run)
- [R4 — no regression scenario for a slug collision](#r4--no-regression-scenario-for-a-slug-collision)
- [R5 — severity extracted but never shown](#r5--severity-extracted-but-never-shown)
- [Defects found during implementation](#defects-found-during-implementation)
- [What was deliberately not changed](#what-was-deliberately-not-changed)

## What was checked and cleared

Recorded because a review that reports only what it found gives no sense of what it looked at.

**`${CLAUDE_SKILL_DIR}` was suspected of being an unverified convention** and is not. `ccd-speckit-run` contains zero occurrences of it, which is what raised the suspicion — but `skills/ccd-conflict-resolve/SKILL.md` uses it **nine times** with zero `${CLAUDE_PLUGIN_ROOT}`, and `specs/006-claude-code-guidance/research.md:78` records the variable as confirmed verbatim against the current documentation. There is precedent and it is verified. No change.

## R1 — the preflight concluded absence from a filesystem test

**Severity: HIGH.** The one finding that would have shipped a wrong refusal.

`bug-preflight.sh` decided `capability absent` by testing for `.claude/skills/speckit-bug-*/SKILL.md`, and that verdict stopped the run outright.

Its own sibling forbids exactly this, in words written for the same problem — `skills/ccd-speckit-run/reference/preflight.md:39`:

> A filesystem test is not the probe and never the sole evidence of absence — where a skill's files live is an install detail, and a companion can be listed and dispatchable with nothing on disk where a probe thought to look.

The consequence is asymmetric, which is what made it the priority. A false `present` fails loudly at the first dispatch and says what is wrong. A false `absent` refuses the whole run with a confident sentence — "the Spec Kit bug extension is not available here" — that is untrue, and it fires precisely on the consumers whose install layout differs from the author's, which is the population a distributed plugin exists to serve.

**Options weighed**

|                                                                    | Cost                                                                                                                                                          |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A — listing authoritative, filesystem corroborating** _(chosen)_ | The script gains `undetermined` and loses `absent`; the skill resolves it against the session's available-skills listing                                      |
| B — keep blocking, add an override question                        | Asks a question the maintainer cannot answer better than the tool can, on every differing install, and still frames a layout difference as a probable absence |
| C — leave it                                                       | Correct here and for any standard install; wrong, confidently and totally, for the rest                                                                       |

**Resolution: A.** `bug-preflight.sh` now reports `capability` as `present` or `undetermined` and **never `absent`** — a probe can establish presence and cannot establish absence. Its `verdict` is `ready` or `undetermined: <reason>`, never `blocked`, because blocking requires having determined absence and the script cannot. `SKILL.md` gained a "Resolving `undetermined`" section: check the session listing; all three listed → proceed noting the layout differs; not listed → _now_ absence is determined, report and stop per FR-023; listing inconclusive → proceed, because a dispatch that fails is visible and a refusal that guessed is not.

FR-023 is unchanged. What changed is what counts as having determined the thing FR-023 acts on.

Also updated: `contracts/bug-preflight-cli.md` (the `capability` and `verdict` rows, the caller's obligation, and a new "Reintroducing `absent`" regression note) and `.claude/rules/spec-kit-bug-workflow.md`.

## R2 — bare-name dispatch against directory-scoped variants

**Severity: MEDIUM.** Correct behaviour, undocumented reasoning — which is how correct behaviour gets "fixed".

The three stages are dispatched by bare name because they are Spec Kit project skills and `claude-code-devkit:` does not address them. In a repository with worktrees the session lists **both** `speckit-bug-assess` and `<some/dir>:speckit-bug-assess`. This run's own session did exactly that. The bare name resolves to the unscoped skill, which is right, but nothing said so.

**Resolution:** stated in `reference/stages.md` and in the path-scoped rule — the bare name is correct even where variants are listed, the unscoped skill is the one to dispatch unless the defect lives in that subtree, and namespacing does not disambiguate them because it addresses nothing.

## R3 — no detection of an existing run

**Severity: MEDIUM.**

`reference/run-state.md` says resuming is re-invoking with the same slug, but `SKILL.md`'s Step 0 never read an existing `.specify/.speckit-bug-run-state.json`. A second run in one session overwrote the first's state silently. The three reports survive — they are on disk and committed — but the record of what an interrupted run had done did not.

**Resolution:** Step 0 now reads the file if present, reports which bug it describes and how far it got, and asks before overwriting: resume that bug, start the new one, or stop. The section also states that resuming needs nothing from that file beyond the slug, so the state file remains a convenience rather than the source of resumability.

## R4 — no regression scenario for a slug collision

**Severity: LOW-MEDIUM.**

`slug-taken yes` is a branch with a user gate (FR-003) and no test. `evaluations.md` covered the script fixtures and the three main paths but not this one.

**Resolution:** Scenario G added — the run reports the collision and asks before Stage 1, and never overwrites an existing `assessment.md`. Scenario H added alongside it for R3. Both name what failure looks like, not only what success looks like.

## R5 — severity extracted but never shown

**Severity: LOW.**

`bug-outcome.sh` extracts `severity`, the state file stores it, and `data-model.md` says it "informs the maintainer's decision at the Stage 2 boundary" — but `SKILL.md` never told the run to state it there. A field that is read, stored, and never surfaced is dead weight that looks like a feature.

**Resolution:** one clause at the Stage 2 boundary. The run states the recorded severity whichever verdict applies, and the text says explicitly that the run never branches on it — `critical` and `low` take the same path — so a later reader does not add a branch that was never intended.

## Defects found during implementation

Not review findings; caught while building, and recorded because they are the kind that recur.

**A `set -e` trap in the preflight.** `[ -f "$path" ] && stage=found` at top level exits the script when the file is absent — which is exactly the case the check exists to report. A missing stage would have produced silence instead of a `missing` line. Rewritten as `if`/`then`, with a comment saying why the terse form is wrong here.

**The contract's own verification did not test its invariant.** Checks 1 and 2 were inherited from feature 006 as whole-file greps for `disable-model-invocation`. Six of the seven skills discuss the field in their Maintenance prose, so the command reported six hits while every frontmatter block was clean — it failed on a healthy repository and would have failed identically on a broken one. Both checks are now scoped to the frontmatter block, and `contracts/skill-names.md` carries a correction section explaining what the predecessor's command actually did.

**Stale text after R1.** Changing the verdict vocabulary left three references to `blocked` behind — two in `SKILL.md`, one in the script's header comment. Found by grepping for the removed term rather than by trusting the edit. Worth naming: a vocabulary change is never confined to the place the value is produced.

## What was deliberately not changed

- **The dirty-path list is captured at Step 0 and reported at the Stage 2 boundary**, so it is a snapshot taken before Stage 1 rather than immediately before the edit. Stage 1 cannot modify source, so the two moments are equivalent, and re-running the probe would suggest a precision that adds nothing.
- **No `when_to_use` field.** The 1,536-character budget is shared between it and `description`; one field spends the budget once, and the description already leads with the trigger.
- **No CHANGELOG.** Upstream's authoring standards call for one in a _Spec Kit extension_. This is a Claude Code plugin skill, and the repository keeps its per-feature history under `specs/`.
- **`bug-outcome.sh` matches the first occurrence of each label with a loose prefix.** A line of prose quoting `**Verdict**:` _before_ the declared field would win. The templates emit the field early and the fixture in `evaluations.md` covers the ordinary case; tightening the pattern would couple it harder to Markdown that gap G3 already records as unstable.
