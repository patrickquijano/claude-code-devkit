# Quickstart Validation: ccd-readme

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Data Model**: [data-model.md](./data-model.md) | **Date**: 2026-09-13

## Prerequisites

- Claude Code CLI installed and authenticated
- POSIX-compliant shell (`sh`) available on PATH
- Read/write permission in target project directory
- Network access only required if license templates are fetched at runtime (current design commits them; no network needed)

## Validation Scenarios

### VS-001: Generate README for Project Without Existing README

**Purpose**: Verify P1 user story — bootstrapping documentation from verified artifacts.

**Setup**:

```sh
mkdir -p /tmp/test-project-no-readme
cd /tmp/test-project-no-readme
git init
echo '{"name": "test-project", "description": "A test project", "license": "MIT"}' > package.json
mkdir -p src
echo 'console.log("hello");' > src/index.js
```

**Run**: Invoke `/ccd-readme` in the test project directory.

**Expected Outcome**:

- Skill detects no README.md exists
- Skill presents license options via AskUserQuestion (MIT recommended based on package.json)
- After selection, README.md is created with sections traceable to package.json and file structure
- LICENSE.md is created matching selected SPDX identifier
- No hallucinated content (no URLs, authors, or features not present in artifacts)

**Verification**:

```sh
test -f README.md && echo "README created"
test -f LICENSE.md && echo "LICENSE created"
grep -q "test-project" README.md && echo "Project name traced"
grep -q "MIT" LICENSE.md && echo "License matches selection"
```

### VS-002: Improve Existing README Without Destroying Accurate Content

**Purpose**: Verify P2 user story — non-destructive improvement.

**Setup**:

```sh
mkdir -p /tmp/test-project-existing-readme
cd /tmp/test-project-existing-readme
git init
echo '{"name": "existing-project", "version": "2.0.0"}' > package.json
cat > README.md << 'EOF'
# Existing Project

This is a custom description written by the author.

## Custom Section

This section contains valuable project-specific information that must be preserved.
EOF
```

**Run**: Invoke `/ccd-readme` in the test project directory.

**Expected Outcome**:

- Skill detects existing README.md
- "Custom Section" and author-written description are preserved verbatim
- Missing sections (Install, Usage, License) are added based on verified artifacts
- No existing accurate content is removed or overwritten

**Verification**:

```sh
grep -q "Custom Section" README.md && echo "Custom section preserved"
grep -q "valuable project-specific information" README.md && echo "Author content preserved"
grep -q "2.0.0" README.md && echo "Version traced from manifest"
```

### VS-003: License Decision Flow With Missing License

**Purpose**: Verify P3 user story — safety-gated license selection.

**Setup**:

```sh
mkdir -p /tmp/test-project-no-license
cd /tmp/test-project-no-license
git init
echo '{"name": "unlicensed-project"}' > package.json
mkdir -p src
echo 'print("hello")' > src/main.py
```

**Run**: Invoke `/ccd-readme` in the test project directory.

**Expected Outcome**:

- Skill detects no LICENSE file and no license metadata in package.json
- AskUserQuestion presents ≥3 options with recommendation, justification, and non-legal-advice notice
- LICENSE.md created only after explicit selection
- If user declines, README generated without license section and output notes licensing was skipped

**Verification**:

```sh
# After selecting MIT:
test -f LICENSE.md && echo "LICENSE created after selection"
grep -q "MIT" LICENSE.md && echo "Selected license written"

# After declining:
! grep -q "^## License" README.md && echo "License section omitted when declined"
```

### VS-004: Idempotency Check

**Purpose**: Verify SC-007 — byte-identical output on unchanged repository.

**Setup**: Use any of the above test projects after initial `/ccd-readme` run completes.

**Run**:

```sh
cp README.md README.md.first
# Re-invoke /ccd-readme in same directory without changes
diff README.md README.md.first && echo "IDEMPOTENT: output identical"
```

**Expected Outcome**: `diff` produces no output; exit code 0.

### VS-005: Insufficient Information Handling

**Purpose**: Verify FR-011 — focused question instead of speculation.

**Setup**:

```sh
mkdir -p /tmp/test-project-empty
cd /tmp/test-project-empty
git init
# No manifests, no source files, no docs
```

**Run**: Invoke `/ccd-readme` in the empty project directory.

**Expected Outcome**:

- Skill reports insufficient verified information
- AskUserQuestion asks focused question about project purpose
- No speculative README content generated before user provides input

**Verification**: Manual observation — no README.md created until user responds to clarification.

### VS-006: SKILL.md Line Budget Validation

**Purpose**: Verify SC-005 — SKILL.md under 500 lines.

**Run**:

```sh
wc -l < skills/ccd-readme/SKILL.md
```

**Expected Outcome**: Output ≤ 500.

### VS-007: Script Delegation Validation

**Purpose**: Verify SC-006 — zero inline shell logic in SKILL.md.

**Run**:

```sh
grep -cE '^\s*(if|for|while|case|do|done|fi|esac)\b' skills/ccd-readme/SKILL.md
```

**Expected Outcome**: Output = 0 (no shell control flow keywords in SKILL.md).

## Post-Validation Cleanup

```sh
rm -rf /tmp/test-project-no-readme /tmp/test-project-existing-readme \
  /tmp/test-project-no-license /tmp/test-project-empty
```

## Notes

- All scenarios use temporary directories to avoid polluting real projects
- License template content is committed; no network calls during validation
- Idempotency check (VS-004) should be repeated after every implementation change
- SKILL.md structural checks (VS-006, VS-007) run as part of `scripts/validate-readme.sh` during implementation
