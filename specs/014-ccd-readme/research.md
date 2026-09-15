# Research: ccd-readme

**Feature**: [spec.md](./spec.md) | **Date**: 2026-09-13

## R-001: Verified Repository Artifact Sources

**Decision**: Authoritative sources are limited to files physically present in the target project directory: package manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json`), CI configuration (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`), existing documentation (`README*`, `CONTRIBUTING*`, `docs/`), license files (`LICENSE*`, `COPYING*`), and build system files (`Makefile`, `Dockerfile`, `docker-compose.yml`). Metadata is extracted by parsing these files directly; no external API calls are made for project metadata.

**Rationale**: Principle VII requires all output derive from verified repository artifacts. External APIs (GitHub API, npm registry) may return stale or divergent data compared to what is actually on disk. The skill operates on the local working tree, which is the single source of truth for what the developer has.

**Alternatives considered**: GitHub API for repo metadata — rejected because it reflects remote state, not local working tree. npm/crates.io registry lookup — rejected because declared dependencies in manifests are authoritative for what the project _is_, not what was last published.

## R-002: README Best Practices Structure

**Decision**: Follow the Standard Readme specification (<https://github.com/RichardLitt/standard-readme>) as the primary structural reference, supplemented by GitHub's "Making READMEs readable" guidance. Sections in order: title + badges, description, install, usage, API/docs links, contributing, license. Each section maps to one or more verified artifact sources.

**Rationale**: Standard Readme is the most widely adopted machine-parseable README specification. GitHub's guidance reflects actual rendering behavior. Both are stable, publicly documented, and do not require runtime dependencies.

**Alternatives considered**: Custom section ordering based on project type — rejected because it introduces heuristic logic that cannot be verified against a standard. Keep a Changelog format — rejected because changelogs are separate artifacts; README should link to them, not embed them.

## R-003: License Template Sources

**Decision**: Embed SPDX-standard license texts for MIT, Apache-2.0, ISC, and GPL-3.0-only as committed templates under `templates/license-*.md`. Templates sourced from <https://spdx.org/licenses/> and verified against OSI-approved texts at <https://opensource.org/licenses>. Lazy-load means the template file is read from disk only when the license decision flow triggers — not fetched from network at runtime.

**Rationale**: FR-007 requires lazy-loading from authoritative sources. Committing the templates satisfies both "authoritative" (SPDX/OSI are the canonical sources) and "lazy-load" (read on demand, not eagerly). Network fetching would violate Tooling Independence (Principle I) and introduce non-determinism (FR-012). Four licenses cover >90% of open-source projects per GitHub Octoverse data.

**Alternatives considered**: Runtime fetch from SPDX API — rejected due to network dependency and non-determinism. Bundling all 500+ SPDX licenses — rejected as excessive scope; four covers the vast majority, and users can request additional licenses via future feature work.

## R-004: SKILL.md Line Budget Enforcement

**Decision**: Hard limit of 500 lines enforced by `validate-readme.sh` post-generation check. SKILL.md content categories: trigger conditions (~20 lines), workflow steps (~80 lines), safeguards (~40 lines), resource routing (~30 lines), output format (~30 lines). Total target: ~200 lines, leaving headroom for edge-case handling.

**Rationale**: FR-009 mandates under 500 lines. Setting the validation threshold at exactly 500 provides a hard gate while targeting ~200 lines ensures progressive disclosure is genuine, not just technically compliant. The validation script enforces this deterministically (FR-008).

**Alternatives considered**: Soft warning at 400 lines — rejected because soft limits drift. No automated check — rejected because manual line counting is error-prone and violates FR-008's script delegation requirement.

## R-005: Idempotency Strategy

**Decision**: All output is deterministic given identical input state. Timestamps are excluded from generated content. File ordering uses sorted glob expansion. External data (license templates) is committed, not fetched. Re-running produces byte-identical output because every variable element is either derived from stable file content or excluded entirely.

**Rationale**: SC-007 requires byte-identical output on unchanged repositories. The only sources of non-determinism in shell scripts are timestamps, unsorted iteration, and network fetches — all three are explicitly excluded.

**Alternatives considered**: Content-hash-based change detection — rejected as over-engineering; if output is deterministic, re-running naturally produces identical results without needing to detect changes.
