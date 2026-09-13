# Feature Specification: GitLab MR Review Skill

**Feature Branch**: `feat/015-ccd-gitlab-mr-review`

**Created**: 2026-09-13

**Status**: Draft

**Input**: User description: "A Claude plugin skill that performs code reviews on a GitLab merge request."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Review an Open Merge Request (Priority: P1)

A developer working on a feature branch invokes the review skill to perform a thorough code review of their open merge request. The skill verifies the MR exists, ensures the developer is listed as a reviewer, analyzes the changes against established code review best practices, and asks the developer whether the review has passed before posting the result to the MR.

**Why this priority**: This is the core value proposition of the skill. Without the ability to review an open MR and post a verdict, the skill has no purpose.

**Independent Test**: Can be fully tested by invoking the skill on a branch with an open MR and verifying that a review comment or change request appears on the MR after the user confirms the verdict.

**Acceptance Scenarios**:

1. **Given** a branch with an open MR and the current user is already a reviewer, **When** the skill is invoked, **Then** the skill proceeds directly to reviewing the changes without modifying the reviewer list.
2. **Given** a branch with an open MR and the current user is not a reviewer, **When** the skill is invoked, **Then** the skill adds the current user as a reviewer before proceeding with the review.
3. **Given** a branch with no open MR, **When** the skill is invoked, **Then** the skill reports the absence and stops without error.
4. **Given** a completed review where the user approves, **When** the user selects the approval option, **Then** the skill posts an approval comment to the MR.
5. **Given** a completed review where the user requests changes, **When** the user selects the changes-requested option, **Then** the skill posts a change request to the MR.

---

### User Story 2 - Preflight Validation (Priority: P2)

A developer invokes the skill and receives immediate feedback about whether the environment is ready for a review, including whether the required CLI tool is available and whether an open MR exists on the current branch.

**Why this priority**: Fail-fast validation prevents wasted time running a review that cannot complete. It is secondary to the core review flow because it supports rather than delivers the primary value.

**Independent Test**: Can be tested by invoking the skill in an environment without the CLI tool installed and verifying that the skill reports the missing dependency and exits without attempting a review.

**Acceptance Scenarios**:

1. **Given** the required CLI tool is not installed, **When** the skill is invoked, **Then** the skill reports the missing tool and stops.
2. **Given** the CLI tool is installed but not authenticated, **When** the skill is invoked, **Then** the skill reports the authentication failure and stops.

---

### Edge Cases

- What happens when the MR has no changes (empty diff)?
- How does the skill handle a MR that was closed or merged between invocation and review posting?
- What happens when network access to the GitLab instance is unavailable during review posting?
- How does the skill behave when the current directory is not inside a git repository?

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: System MUST check for the availability of the GitLab CLI tool before performing any operations.
- **FR-002**: System MUST verify that the current branch has an open merge request before starting a review.
- **FR-003**: System MUST add the current user as a reviewer if they are not already listed on the MR.
- **FR-004**: System MUST perform a thorough review of the MR changes applying established code review best practices.
- **FR-005**: System MUST ask the user whether the review has passed, presenting options with explanation, recommendation, and justification.
- **FR-006**: System MUST post an approval comment to the MR when the user indicates the review has passed.
- **FR-007**: System MUST post a change request to the MR when the user indicates the review has not passed.
- **FR-008**: System MUST delegate templates and output formats to a templates subdirectory within the skill directory.
- **FR-009**: System MUST delegate commands and scripts to a scripts subdirectory within the skill directory.
- **FR-010**: All shell scripts MUST be POSIX-compliant and MUST fail fast on the first error.
- **FR-011**: System MUST produce structured output showing only what is necessary.
- **FR-012**: System MUST NOT hallucinate content not present in the MR diff or repository artifacts.
- **FR-013**: System MUST NOT make assumptions about code intent or behavior not evidenced in the changes.
- **FR-014**: System MUST NOT scan files outside the project directory.
- **FR-015**: System MUST support authentication exclusively via the GitLab CLI tool's configured credentials; direct API token authentication is out of scope.
- **FR-016**: When requesting changes, system MUST post a single structured summary comment containing all findings grouped by severity, with line references included in the summary body; individual line-level comments are out of scope.

### Key Entities

- **Merge Request**: The unit of work being reviewed, identified by its IID within the project, carrying metadata about source branch, target branch, reviewers, and status.
- **Review Verdict**: The outcome of the review process, either approval or request-for-changes, determined by user decision after analysis.
- **Finding**: An individual observation from the review, carrying severity, location, and description, used to construct the review feedback.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Users can initiate a code review on an open MR with a single command invocation.
- **SC-002**: The skill completes preflight validation and reports readiness or failure within seconds of invocation.
- **SC-003**: Every review posted to an MR contains only observations derived from the actual diff and repository content.
- **SC-004**: Users receive a clear pass/fail decision prompt with sufficient context to make an informed choice.
- **SC-005**: The skill produces no output beyond what is necessary for the user to understand the review status and findings.

## Assumptions

- The GitLab CLI tool is the supported interface for all GitLab interactions; direct API calls are out of scope unless clarified otherwise.
- Code review best practices follow established industry standards such as those documented in Google's engineering practices for code review.
- The skill operates within a git repository context and has access to the local working tree for reading changed files.
- Authentication credentials are managed externally by the CLI tool's own configuration; the skill does not handle credential storage or rotation.
- The skill reviews one MR per invocation; batch review of multiple MRs is out of scope.
- The skill does not modify source code; it is read-only with respect to the repository content.
- Automated merging on approval is out of scope; the skill posts a verdict but takes no merge action.
