---
name: ccd-readme
description: Create or improve README.md using only verified repository information, with safety-gated license selection.
triggers:
  - /ccd-readme
  - 'create readme'
  - 'generate readme'
  - 'improve readme'
---

# ccd-readme

Generate or improve a README.md using only verified repository artifacts. Never hallucinate project details. Never silently select a license.

## Workflow

### Step 1: Inspect Project

Run `"${CLAUDE_SKILL_DIR}/scripts/inspect-project.sh"` against the target directory. Parse the JSON output into working memory as `ProjectInspectionResult`. Scripts are executable (`chmod +x`) and invoked directly; the executable bit is guaranteed by the install process and verified by `scripts/lint-shell.sh`.

If the script exits non-zero, report the error and stop.

### Step 2: Scope Check

If `has_nested_projects` is true, invoke `AskUserQuestion`:

```text
Nested project directories detected. Which scope should the README cover?

Options:
- Top-level only: Generate README for the root project only
- Specify subdirectory: Name a specific nested project to document
- Cancel: Stop without generating
```

Wait for response before continuing. If user cancels, stop.

### Step 3: Insufficient Information Guard

If `project_name` equals the directory basename AND `description` is null AND `languages` is empty AND `dependencies` is null AND `existing_docs` is empty, invoke `AskUserQuestion`:

```text
Insufficient verified information found to generate a meaningful README.

What is the purpose of this project? (Answer in 1-2 sentences)
```

Wait for response. Use the answer as the description. If user declines, stop without generating.

### Step 4: License Decision Flow

Evaluate `license_state`:

- **present-consistent**: Skip license flow. Reference existing LICENSE file in output.
- **present-inconsistent**: Invoke `AskUserQuestion` offering reconciliation (see template below).
- **missing** or **ambiguous**: Invoke `AskUserQuestion` with full selection (see template below).

#### AskUserQuestion License Template

Read `${CLAUDE_SKILL_DIR}/references/license-guide.md` for the prompt template and mandatory non-legal-advice notice. Present ≥3 options with exactly one recommended based on manifest signals and project type. Include the non-legal-advice notice verbatim.

If user selects a license, record the `LicenseDecision` and read `${CLAUDE_SKILL_DIR}/templates/license-{SPDX_ID}.md` for the LICENSE.md content. Replace `{{YEAR}}` with current year and `{{COPYRIGHT_HOLDER}}` with project name or author from manifest if available.

If user declines, note in output that licensing was skipped and omit the license section from README.

### Step 5: README Assembly

#### New README (readme_exists is false)

1. Read `${CLAUDE_SKILL_DIR}/templates/readme-base.md`
2. Replace placeholders using `ProjectInspectionResult` fields:
   - `{{PROJECT_NAME}}` → `project_name`
   - `{{DESCRIPTION}}` → `description` or user-provided answer from Step 3
   - `{{INSTALL_INSTRUCTIONS}}` → derive from manifest type (npm install, cargo add, pip install, etc.)
   - `{{USAGE_EXAMPLES}}` → derive from source entry points or existing docs
   - `{{DOCS_LINKS}}` → links to `docs/` directory or API doc files if present
   - `{{CONTRIBUTING_GUIDELINES}}` → content from CONTRIBUTING file or default text
   - `{{LICENSE_SECTION}}` → SPDX identifier and link to LICENSE.md, or "No license specified" if declined
3. Remove HTML comment provenance markers from final output
4. Write README.md to target directory

#### Improve Existing README (readme_exists is true)

1. Parse existing README into sections by heading
2. For each section, classify:
   - **Accurate**: Content matches verified artifacts → preserve byte-identical
   - **Inaccurate**: Content contradicts verified artifacts → flag with evidence, propose correction
   - **Unverifiable**: No corresponding artifact → preserve but note unverifiable
3. Identify missing sections (Install, Usage, License, Contributing) not present in existing README
4. Add missing sections from verified artifacts
5. Preserve detected `readme_language` for all generated content
6. If all sections are accurate and complete, report no changes needed and do not modify file
7. Otherwise, write updated README.md preserving accurate sections byte-identical

### Step 6: LICENSE.md Creation

If user selected a license in Step 4:

1. Write LICENSE.md to target directory with populated template content
2. If LICENSE.md already exists and user chose to reconcile, overwrite with selected license

### Step 7: Validation

Run `${CLAUDE_SKILL_DIR}/scripts/validate-readme.sh README.md ${CLAUDE_SKILL_DIR}/SKILL.md`

If validation fails, report the failure and do not mark the run as successful.

### Step 8: Idempotency & Non-Destructiveness

- Exclude all timestamps from generated content
- Use sorted file ordering for any list derived from filesystem enumeration
- Before overwriting any existing file, create `.bak` backup of original content
- Report what was preserved, added, corrected, and backed up

## Output Format

After completion, report:

```text
README: [created|updated|unchanged] at [path]
LICENSE: [created|updated|skipped] at [path]
Sections: [N] total, [N] preserved, [N] added, [N] corrected
Validation: [PASS|FAIL]
Backup: [.bak file path or "none needed"]
```

## Safeguards

- Never infer project details absent from verified artifacts (FR-002)
- Never create or modify LICENSE.md without explicit user selection (FR-006)
- Never remove accurate existing README content (FR-003)
- Never include timestamps or non-deterministic values (FR-012)
- Always use `${CLAUDE_SKILL_DIR}` for script/template/reference paths
- All deterministic logic delegated to scripts in `scripts/` (FR-008)
- SKILL.md stays under 500 lines (FR-009)
