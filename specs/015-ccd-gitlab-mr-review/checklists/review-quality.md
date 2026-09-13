# Checklist: GitLab MR Review Skill Requirements Quality

**Purpose**: Validate requirements completeness, clarity, consistency, and testability for the GitLab MR review skill specification
**Created**: 2026-09-13
**Feature**: [spec.md](../spec.md)
**Ownership**: Reviewer-owned requirements-quality artifact. `[x]` means the reviewer determined the criterion is satisfied; it does not mean implementation work is complete. `/speckit-implement` reads checklist state but does not modify markers.

## Requirement Completeness

- [ ] CHK001 - Are preflight validation requirements specified for all failure modes (missing CLI, auth failure, no open MR, not a git repo)? [Completeness, Spec §FR-001, FR-002]
- [ ] CHK002 - Are requirements defined for the reviewer-addition flow when the current user is already a reviewer vs. not? [Completeness, Spec §FR-003]
- [ ] CHK003 - Are code review best practices referenced with sufficient specificity to be testable, or are they left as an external standard? [Completeness, Spec §FR-004]
- [ ] CHK004 - Are requirements specified for how the skill determines the current user's identity for reviewer addition? [Gap, Spec §FR-003]
- [ ] CHK005 - Are requirements defined for the structure and content of the approval comment posted to the MR? [Gap, Spec §FR-006]
- [ ] CHK006 - Are requirements specified for the structured summary comment format when requesting changes (severity grouping, line reference format)? [Clarity, Spec §FR-016]
- [ ] CHK007 - Are requirements defined for what constitutes "only what is necessary" in structured output? [Clarity, Spec §FR-011]

## Requirement Clarity

- [ ] CHK008 - Is "thorough review" in FR-004 defined with measurable or observable criteria beyond referencing external best practices? [Ambiguity, Spec §FR-004]
- [ ] CHK009 - Is the distinction between "approval comment" and "change request" in FR-006/FR-007 specified in terms of GitLab's own review states or only as comments? [Ambiguity, Spec §FR-006, FR-007]
- [ ] CHK010 - Are the options presented to the user at FR-005 specified with their exact labels, or is that left to implementation? [Clarity, Spec §FR-005]
- [ ] CHK011 - Is "structured output" in FR-011 defined with a concrete format (e.g., table, list, JSON) or left abstract? [Ambiguity, Spec §FR-011]

## Requirement Consistency

- [ ] CHK012 - Do FR-012 (no hallucination) and FR-013 (no assumptions) align with FR-004 (thorough review applying best practices), or could thorough review require inference that conflicts with these prohibitions? [Consistency, Spec §FR-004, FR-012, FR-013]
- [ ] CHK013 - Does FR-014 (no scanning outside project directory) conflict with any requirement to read repository-level configuration or shared scripts referenced by changed files? [Consistency, Spec §FR-014]
- [ ] CHK014 - Are the non-goals consistent with all functional requirements (e.g., no forge support beyond GitLab vs. FR-001's CLI check)? [Consistency, Spec §Non-goals, FR-001]

## Acceptance Criteria Quality

- [ ] CHK015 - Can SC-002 ("within seconds of invocation") be objectively measured without specifying a threshold? [Measurability, Spec §SC-002]
- [ ] CHK016 - Is SC-003 ("only observations derived from actual diff") verifiable without access to the review generation process internals? [Measurability, Spec §SC-003]
- [ ] CHK017 - Does SC-004 ("sufficient context to make an informed choice") have measurable criteria for sufficiency? [Measurability, Spec §SC-004]

## Scenario Coverage

- [ ] CHK018 - Are requirements defined for the edge case where the MR has no changes (empty diff)? [Coverage, Spec §Edge Cases]
- [ ] CHK019 - Are requirements specified for handling a MR that was closed or merged between invocation and review posting? [Coverage, Spec §Edge Cases]
- [ ] CHK020 - Are requirements defined for network failure during review posting (retry, partial post, rollback)? [Coverage, Spec §Edge Cases]
- [ ] CHK021 - Are requirements specified for the scenario where the current directory is not inside a git repository? [Coverage, Spec §Edge Cases]
- [ ] CHK022 - Are recovery requirements defined if the skill fails mid-review after adding the user as reviewer but before posting a verdict? [Gap, Exception Flow]

## Dependencies & Assumptions

- [ ] CHK023 - Is the assumption that glab's configured credentials are always valid and current documented as a precondition or handled as a failure mode? [Assumption, Spec §Assumptions]
- [ ] CHK024 - Are dependencies on specific glab subcommands or output formats documented, given that glab versions may vary? [Dependency, Gap]
- [ ] CHK025 - Is the dependency on Google engineering practices for code review cited with a stable reference (URL, version, date) rather than an implicit standard? [Dependency, Spec §Assumptions]

## Notes

- Generated during Phase 4 (checklist) of speckit-run for feature 015.
- Prerequisite script (`check-prerequisites.sh`) requires `plan.md` which does not exist until Phase 5; checklist generated directly from `spec.md` to maintain pipeline ordering.
- All items unchecked; checkbox state belongs to the reviewer.
- `/speckit-implement` reads this file's state but does not modify markers.
