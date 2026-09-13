# Review Checklist: Eleven Dimensions

Guidance for each review dimension. Every finding MUST classify under exactly one.

## correctness

Logic errors, off-by-one mistakes, incorrect conditionals, wrong return values, missing null checks, race conditions. Evidence must quote the specific code that produces incorrect behavior.

## security

Injection vulnerabilities, authentication bypasses, authorization gaps, credential exposure, insecure defaults, path traversal, XSS, CSRF. Cite OWASP category when applicable. Never flag pre-existing secrets unrelated to the change.

## reliability

Unhandled error paths, missing retries on transient failures, resource leaks, timeout misconfiguration, inadequate error messages, silent failures. Evidence must show the failure mode.

## performance

Algorithmic complexity regressions, N+1 queries, unnecessary allocations, missing caching where documented, blocking I/O on hot paths. Must cite measurable impact or documented threshold.

## maintainability

Dead code introduced by the change, duplicated logic, naming that obscures intent, functions exceeding repository conventions, missing comments on non-obvious decisions. Style preferences without functional impact are Suggestions, not findings.

## compatibility

Breaking API changes, schema migrations without backward compatibility, dependency version conflicts, platform-specific assumptions. Evidence must cite the contract or interface being broken.

## tests

Missing test coverage for new code paths, tests that do not assert meaningful outcomes, flaky test patterns introduced, test infrastructure changes without validation. Absence of tests is a finding only when the repository's own rules require them.

## accessibility

Missing ARIA attributes, keyboard navigation gaps, color contrast violations, screen reader incompatibility. Applies only when the change touches user-facing output and the repository has accessibility requirements.

## observability

Missing logging on error paths, metrics not updated for new operations, tracing context lost across boundaries, alerting gaps for new failure modes. Applies only when the repository defines observability standards.

## configuration

Hardcoded values that should be configurable, missing environment variable validation, undocumented configuration options, configuration precedence violations. Evidence must cite the repository's configuration policy.

## documentation

Public API changes without doc updates, README instructions contradicted by the change, changelog entries missing for user-visible changes, inline comments contradicting actual behavior. Documentation drift is a finding only when the repository requires docs to track code.

## Applying dimensions

- Read the diff against each dimension in order.
- A single line may produce findings in multiple dimensions; create separate Finding entities.
- If no finding exists for a dimension, do not invent one.
- Repository-specific guidance in CONTRIBUTING.md or equivalent overrides generic dimension guidance; document the override as evidence.
