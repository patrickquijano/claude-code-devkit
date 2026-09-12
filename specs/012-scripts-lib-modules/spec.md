# Feature Specification: One shared library directory for the checking machinery

**Feature Branch**: `refactor/scripts-lib-modules`

**Created**: 2026-09-12

**Status**: Retrospective — written after the change, at review's request

**Input**: Remove script-to-script references under `scripts/`, share components through `scripts/lib/`, keep every script fail-fast and POSIX, delete dead implementations.

## Why this record exists

Principle VI carves out no exception for refactors, and the change is not purely internal: `scripts/lint.sh`'s handling of `-- PATH...` changed behaviour, the `scripts/lib/` boundary became a rule stated in `README.md`, and how a check is invoked turned out to be load-bearing. The reviewer of the change asked for the record; [research.md](./research.md) holds the decisions.

## User Scenarios & Testing

### User Story 1 - A contributor adds a check (Priority: P1)

A contributor adding an eighth standard edits one file. They add the name to the declared list and a branch to the dispatcher, and the aggregate, the per-standard entry point and the edit hook all reach it without any of them being edited.

**Independent Test**: Add a probe check to the declared list and a body for it; confirm `scripts/lint.sh` runs it with no other file changed.

**Acceptance Scenarios**:

1. **Given** a new check registered in one place, **When** the aggregate runs, **Then** it runs the new check in its declared position.
2. **Given** an entry point under `scripts/`, **When** it is read, **Then** it resolves the repository root, sources one file from `scripts/lib/`, and calls it — and contains no other logic.
3. **Given** a wrapper that names a check that does not exist, **When** the self-test runs, **Then** it fails and names that entry point.

### User Story 2 - A check fails part way through its body (Priority: P1)

A command inside a check body fails. The check stops there, the aggregate stops at that check, and the aggregate's exit status is the check's own.

**Independent Test**: A probe body whose first command fails and which would print afterwards. The aggregate must exit non-zero and the later output must never appear.

**Acceptance Scenarios**:

1. **Given** a check body whose non-final command fails, **When** the aggregate runs it, **Then** the aggregate exits non-zero and no later command of that body ran.
2. **Given** a check that exits 3, **When** the aggregate runs it, **Then** the aggregate exits 3 and no later check ran.
3. **Given** a narrowed run, **When** each check is invoked, **Then** it receives the path list the caller named.

### User Story 3 - The self-test reaches the code without copying it (Priority: P2)

`scripts/selftest.sh` exercises the committed libraries, not copies of them, and stands in only for the one function a case needs to control.

**Acceptance Scenarios**:

1. **Given** a self-test case, **When** it runs, **Then** the code under test is the committed file, reached by the same source path its wrapper uses.
2. **Given** a case that substitutes a check body, **When** it runs, **Then** everything above that body — the aggregate loop and the invocation — is the committed code.

## Requirements

- **FR-001**: No entry point under `scripts/` MUST reach a shared component by executing another script under `scripts/`. `scripts/selftest.sh` is exempt: it executes an entry point as the subject of a test, not as a component.
- **FR-002**: Every entry point under `scripts/` except `scripts/selftest.sh` MUST be a wrapper that resolves the repository root, sources one file from `scripts/lib/`, and calls it. The self-test is exempt because moving its body to `scripts/lib/` would leave the tester behind a wrapper nothing tests, and it shares its body with no other caller.
- **FR-003**: `SCRIPT_DIR` MUST mean `scripts/` in every entry point, including those nested in `scripts/hooks/`.
- **FR-004**: A check invoked by the aggregate or by the edit hook MUST run with `set -e` live, so a failing command inside its body ends it.
- **FR-005**: The aggregate MUST stop at the first failing check and exit with that check's own status.
- **FR-006**: The aggregate MUST pass a trailing `-- PATH...` through to every check, per `specs/004-format-hook-scope/contracts/check-cli.md`.
- **FR-007**: Every documented CLI — arguments, output and all five exit statuses — MUST be unchanged.
- **FR-008**: The self-test MUST cover FR-004 and FR-005 against the committed invocation, not a stand-in for it.
- **FR-009**: A usage header MUST NOT promise a behaviour its check does not have — neither a `--fix` that rewrites nothing nor a `-- PATH...` that narrows nothing.
- **FR-010**: Dead implementations MUST be removed, not left unreferenced.
- **FR-011**: Every entry point under `scripts/` MUST be executed by at least one self-test case, so that a wrapper whose call into its library is wrong fails a gate rather than only a run.
- **FR-012**: A check MUST run under the same shell its entry point declares.

## Success Criteria

- **SC-001**: `scripts/lint.sh` and `scripts/selftest.sh` both pass, natively and with `LINT_FORCE_CONTAINER=1`.
- **SC-002**: Reverting the invocation to the subshell form makes the self-test fail, and naming the case that caught it.
- **SC-003**: `grep` for a `scripts/` path being executed from another `scripts/` file returns nothing outside `scripts/selftest.sh`, whose only such lines are smoke cases.
- **SC-004**: Renaming the check a wrapper asks for — `check_main markdwon` — passes `scripts/lint-shell.sh` and fails `scripts/selftest.sh`.
