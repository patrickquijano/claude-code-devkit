# Validation Command Precedence

Per CHK005: when multiple validation sources exist, use this priority order.

## Priority order

1. **Explicit targets**: `validate` or `check` target in Makefile, package.json scripts, or scripts/ directory.
2. **CI configuration entry point**: `.github/workflows/*.yml` test job, `.gitlab-ci.yml` test stage.
3. **Repository documentation**: CONTRIBUTING.md, DEVELOPING.md, README.md stating validation commands.
4. **Conventional defaults**: `npm test`, `make test`, `cargo test`, `go test ./...`, `pytest`.

## Same-priority conflicts

When multiple sources exist at the same priority level, report all candidates and ask the user to select. Never choose silently.

## No source found

Per FR-048: when no validation command is declared, the validation pass-criterion fails. The user may explicitly override it with a stated reason recorded in CriterionStatus.override_reason. An unchecked criterion is never reported as satisfied (SC-012).

## CI-only validation

When the only declared validation runs in CI (priority 2 with no local equivalent), report `verdict=informational` from verify-repository.sh. The ci-pass criterion uses the platform-reported status check rollup instead of a local command. The validation-pass criterion fails unless overridden per FR-048.

## Override protocol

To override a failed validation criterion:

1. State which criterion is being overridden and why.
2. Record the reason in CriterionStatus.override_reason.
3. Continue verdict evaluation with the overridden criterion treated as satisfied for this cycle only.
4. Write an audit entry with action `validation-overridden` and the stated reason as evidence.

Overrides are per-cycle, not permanent. Each re-review re-evaluates the criterion from scratch.
