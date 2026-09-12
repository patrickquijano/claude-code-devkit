#!/bin/sh
# verify-repository.sh — Resolve validation command per CHK005 precedence, execute, report result
# Usage: sh verify-repository.sh
# Output: key=value lines for validation_command, exit_code, output_excerpt, verdict
set -e

# CHK005 precedence: (1) explicit validate/check target, (2) CI config, (3) docs, (4) conventional defaults
VALIDATION_CMD=""
SOURCE=""

# Priority 1: Makefile/package.json/scripts explicit targets
if [ -f "Makefile" ] && grep -qE '^(validate|check|test):' Makefile 2> /dev/null; then
	if grep -qE '^validate:' Makefile; then
		VALIDATION_CMD="make validate"
		SOURCE="makefile-validate"
	elif grep -qE '^check:' Makefile; then
		VALIDATION_CMD="make check"
		SOURCE="makefile-check"
	elif grep -qE '^test:' Makefile; then
		VALIDATION_CMD="make test"
		SOURCE="makefile-test"
	fi
elif [ -f "package.json" ]; then
	if grep -q '"validate"' package.json 2> /dev/null; then
		VALIDATION_CMD="npm run validate"
		SOURCE="package-json-validate"
	elif grep -q '"check"' package.json 2> /dev/null; then
		VALIDATION_CMD="npm run check"
		SOURCE="package-json-check"
	elif grep -q '"test"' package.json 2> /dev/null; then
		VALIDATION_CMD="npm test"
		SOURCE="package-json-test"
	fi
fi

# Priority 2: CI config entry point
if [ -z "$VALIDATION_CMD" ]; then
	if [ -d ".github/workflows" ]; then
		for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
			[ -f "$wf" ] || continue
			if grep -qE '^\s*(name:\s*test|test:)' "$wf" 2> /dev/null; then
				VALIDATION_CMD="see-ci-config:$wf"
				SOURCE="github-actions"
				break
			fi
		done
	elif [ -f ".gitlab-ci.yml" ]; then
		if grep -qE '^\s*test:' .gitlab-ci.yml 2> /dev/null; then
			VALIDATION_CMD="see-ci-config:.gitlab-ci.yml"
			SOURCE="gitlab-ci"
		fi
	fi
fi

# Priority 3: Repository documentation
if [ -z "$VALIDATION_CMD" ]; then
	for doc in CONTRIBUTING.md DEVELOPING.md README.md docs/developing.md; do
		[ -f "$doc" ] || continue
		CMD="$(grep -iE '(run|execute)\s+(.*)(test|validate|check|lint)' "$doc" 2> /dev/null | head -1 | sed 's/.*\(make\|npm\|cargo\|go\|pytest\)/\1/' | sed 's/[[:space:]]*$//')" || true
		if [ -n "$CMD" ]; then
			VALIDATION_CMD="$CMD"
			SOURCE="docs:$doc"
			break
		fi
	done
fi

# Priority 4: Conventional defaults
if [ -z "$VALIDATION_CMD" ]; then
	if [ -f "package.json" ]; then
		VALIDATION_CMD="npm test"
		SOURCE="conventional-npm"
	elif [ -f "Cargo.toml" ]; then
		VALIDATION_CMD="cargo test"
		SOURCE="conventional-cargo"
	elif [ -f "go.mod" ]; then
		VALIDATION_CMD="go test ./..."
		SOURCE="conventional-go"
	elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
		VALIDATION_CMD="pytest"
		SOURCE="conventional-pytest"
	elif [ -f "Makefile" ]; then
		VALIDATION_CMD="make test"
		SOURCE="conventional-make"
	fi
fi

# No source found — FR-048: criterion fails unless overridden
if [ -z "$VALIDATION_CMD" ]; then
	echo "validation_command=none"
	echo "source=none"
	echo "exit_code=1"
	echo "output_excerpt=no validation command declared in repository"
	echo "verdict=fail:no-validation-declared"
	exit 0
fi

echo "validation_command=$VALIDATION_CMD"
echo "source=$SOURCE"

# If command references CI config only, report as informational
case "$VALIDATION_CMD" in
	see-ci-config:*)
		echo "exit_code=0"
		echo "output_excerpt=validation runs in CI; no local command extracted"
		echo "verdict=informational"
		exit 0
		;;
	*)
		# Fall through to execution below
		;;
esac

# Execute validation command
OUTPUT="$(eval "$VALIDATION_CMD" 2>&1)" || EXIT_CODE=$?
EXIT_CODE="${EXIT_CODE:-0}"

echo "exit_code=$EXIT_CODE"

# Truncate output to 500 chars for excerpt
EXCERPT="$(echo "$OUTPUT" | head -20 | cut -c1-500)"
echo "output_excerpt=$EXCERPT"

if [ "$EXIT_CODE" -eq 0 ]; then
	echo "verdict=pass"
else
	echo "verdict=fail"
fi
