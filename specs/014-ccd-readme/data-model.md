# Data Model: ccd-readme

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-13

## Entities

### ProjectInspectionResult

Structured output of `scripts/inspect-project.sh`. All fields derived exclusively from verified repository artifacts.

| Field | Type | Source Artifact(s) | Nullable | Notes |
| ------- | ------ | -------------------- | ---------- | ------- |
| project_name | string | package.json `name`, Cargo.toml `[package].name`, pyproject.toml `[project].name`, go.mod `module`, directory basename fallback | No | Fallback chain: first manifest found → directory name |
| description | string | Manifest `description`/`summary` fields, first paragraph of existing README | Yes | Null if no description found in any artifact |
| languages | string[] | File extension census (top-level only), manifest type inference | No | Empty array if no source files detected |
| dependencies | object{} | package.json `dependencies`, Cargo.toml `[dependencies]`, pyproject.toml `[project.dependencies]`, go.mod `require` | Yes | Keyed by ecosystem; null if no manifest found |
| ci_systems | string[] | `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml` | No | Empty array if no CI config detected |
| existing_docs | string[] | Glob of `README*`, `CONTRIBUTING*`, `CHANGELOG*`, `docs/**` | No | Paths relative to project root |
| license_state | LicenseState | `LICENSE*`, `COPYING*`, manifest `license` field | No | Enum: `present-consistent`, `present-inconsistent`, `missing`, `ambiguous` |
| readme_exists | boolean | `README.md` or case-insensitive variant present | No | — |
| readme_language | string | Heuristic detection from existing README content | Yes | ISO 639-1 code or null if no README / undetectable |
| has_nested_projects | boolean | Nested manifests or `.git` directories in subdirectories | No | Triggers scope clarification prompt |

### LicenseState

Enum representing the licensing posture of the target project.

| Value | Meaning | Trigger |
| ------- | --------- | --------- |
| `present-consistent` | LICENSE file exists and matches manifest metadata | No license flow needed |
| `present-inconsistent` | LICENSE file exists but conflicts with manifest metadata, or manifest declares license but no file exists | License decision flow (offer to reconcile) |
| `missing` | No LICENSE file and no license metadata in any manifest | License decision flow (new selection) |
| `ambiguous` | Multiple conflicting license signals (e.g., dual LICENSE files, different licenses in different manifests) | License decision flow with conflict explanation |

### LicenseDecision

Record created only after explicit user selection via `AskUserQuestion`.

| Field | Type | Required | Notes |
| ------- | ------ | ---------- | ------- |
| spdx_id | string | Yes | SPDX identifier chosen by user (e.g., `MIT`, `Apache-2.0`) |
| recommended | string | Yes | SPDX identifier that was recommended |
| justification | string | Yes | Concise reason shown for recommendation |
| notice_displayed | boolean | Yes | Always `true`; non-legal-advice notice is mandatory |
| timestamp | string | No | Excluded from output for idempotency; stored only in session memory |

### ReadmeSection

Discrete unit of generated README content with provenance tracking.

| Field | Type | Notes |
| ------- | ------ | ------- |
| heading | string | Section title (e.g., "Installation", "Usage") |
| content | string | Markdown body |
| sources | string[] | Verified artifact paths this section derives from |
| preserved_from_existing | boolean | True if content carried over from existing README unchanged |
| language | string | Matches `ProjectInspectionResult.readme_language` or `"en"` fallback |

## Relationships

```
ProjectInspectionResult 1──→ 0..1 LicenseDecision
ProjectInspectionResult 1──→ 1..* ReadmeSection
LicenseDecision         1──→ 1    ReadmeSection (license section)
```

## Validation Rules

- **VR-001**: Every `ReadmeSection.sources` array MUST contain at least one path that exists on disk at generation time (SC-001).
- **VR-002**: When `license_state` is `missing` or `present-inconsistent`, a `LicenseDecision` MUST exist before the license `ReadmeSection` is generated (FR-006).
- **VR-003**: When `readme_exists` is true and `preserved_from_existing` sections exist, those sections' content MUST be byte-identical to the corresponding sections in the original README (FR-003, SC-003).
- **VR-004**: `has_nested_projects` being true MUST trigger a scope clarification before any `ReadmeSection` is generated (Edge Cases).
- **VR-005**: All string fields MUST be free of timestamps, UUIDs, or other non-deterministic values (FR-012, SC-007).

## State Transitions

```
[Inspect] → ProjectInspectionResult
    ↓
[License Check] → LicenseState
    ├─ present-consistent → [Generate Sections]
    ├─ missing/inconsistent/ambiguous → [AskUserQuestion] → LicenseDecision → [Generate Sections]
    └─ (user declines) → [Generate Sections without license]
    ↓
[Assemble] → ReadmeSection[] → README.md
    ↓
[Validate] → validate-readme.sh exit 0 | non-zero
```
