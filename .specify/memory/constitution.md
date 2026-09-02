<!--
Sync Impact Report

Version change: 1.1.0 → 1.2.0 (MINOR — existing guidance materially expanded in two places; no
principle removed, and nothing redefined in a way that invalidates prior compliance)

Modified principles:
  - V. Configuration Is Committed — the tool-defaults prohibition now bars *undeclared* defaults
    rather than all reliance on defaults. Reason: the previous absolute wording required every
    configuration file to restate values nobody had chosen, which makes a real decision
    indistinguishable from a default that happens to be acceptable. The guarantee the principle
    exists to provide — the same verdict on every machine — comes from pinning the tool's version,
    not from re-typing that version's defaults. So a documented default MAY now be relied on
    silently in the configuration file, on two conditions that together preserve the guarantee:
    the tool's version is pinned exactly, and the relied-on default is recorded in the written
    record of chosen settings that Principle V's companion requirement already mandates. Editor
    settings and per-developer configuration remain forbidden with no exception.

Modified sections:
  - Quality Gate Requirements — the uniqueness rule is now per content kind AND per concern.
    Reason: the previous wording allowed each content kind exactly one governing configuration
    file, which made a content kind governed by both a formatter and a linter a violation rather
    than a design — even though the two check disjoint properties and neither can substitute for
    the other. The rule now permits one formatting configuration and one linting configuration per
    content kind, and forbids two of either. The hazard the original clause guarded against, two
    tools rewriting the same file, is exactly what the per-concern limit still forbids.

Added sections: none
Removed sections: none
Deferred items: none

Prior reports
-------------

Sync Impact Report

Version change: 1.0.0 → 1.1.0 (MINOR — existing guidance materially expanded; nothing removed
or redefined in a way that invalidates prior compliance)

Modified principles:
  - III. Pinned, Official Images — added a clause for tools that publish no image of their own.
    Reason: two of the six tools this repository depends on (yamllint, Prettier) publish no
    official or upstream image at all, which made the previous wording impossible to satisfy
    without either an unaudited third-party image in the execution path or dropping the
    container fallback entirely — and dropping it would break the reproducibility the principle
    exists to protect. The new clause keeps both halves of the pinning guarantee, in two places
    instead of one: an official image pinned by tag and digest, plus the tool's own version
    pinned exactly. The prohibition on floating tags is unchanged and now applies to both cases.

Modified sections:
  - Development Workflow — the branch clause previously named the Spec Kit `specify` phase as
    what cuts the feature branch. Reason: branch creation in Spec Kit is an optional extension
    hook, not part of the core phase, so the clause described behaviour this repository does
    not have. Reworded to require that the branch exist before the work is proposed for review,
    without mandating which step creates it. The requirement that feature artifacts live under
    `specs/<NNN-slug>/` is unchanged.

Added sections: none
Removed sections: none
Deferred items: none

Prior report (v1.0.0, initial ratification): concrete principles replaced the template
placeholders; Core Principles I–VI, Quality Gate Requirements, Development Workflow and
Governance were all added at that time.
-->

# claude-code-devkit Constitution

## Core Principles

### I. Tooling Independence (NON-NEGOTIABLE)

Every repository quality check MUST produce its verdict using only POSIX `sh` plus either the
tool installed natively or a container runtime. No check MAY require a language package manager,
a virtual environment, or a global install step as a precondition for running it.

Rationale: contributors and automated environments arrive with different toolchains installed.
A check that only runs after a setup ritual is a check that silently stops running.

### II. Fail Fast

Every script MUST exit non-zero on the first failing check. A script MUST NOT mask a command's
exit status behind a pipeline, a subshell, or an ignored error, and MUST NOT continue executing
subsequent checks after one has failed.

Rationale: a partial result that exits zero is indistinguishable from a pass, and is acted on
as one.

### III. Pinned, Official Images

Every container image referenced by this repository MUST be the tool's official or
upstream-published image, and MUST be pinned by an explicit version tag AND a `sha256` digest.
A floating tag MUST NOT be committed.

Where a tool publishes no official or upstream image of its own, a Docker Official Image for
that tool's language MAY be used instead, provided both of the following hold: the image is
pinned by an explicit version tag AND a `sha256` digest, exactly as any other image; and the
tool's own version is pinned exactly in the invocation. The prohibition on floating tags applies
unchanged to both cases.

Rationale: an unpinned image makes the same command produce different verdicts on different
days, which destroys the reproducibility Principle I exists to provide. The second clause exists
because some tools ship no image at all, and the alternatives — an unaudited third party in the
execution path, or no container fallback — are each worse for reproducibility than an official
language image carrying an exactly pinned tool version.

### IV. POSIX Shell Only

Shell scripts committed to this repository MUST be POSIX `sh`-compatible and MUST pass shell
static analysis in POSIX mode with zero findings. Bashisms MUST NOT be used.

Rationale: the fallback path in Principle I assumes the smallest common shell. A script that
needs `bash` is a script that does not run where it is most needed.

### V. Configuration Is Committed

Every linter and formatter MUST be driven by a configuration file committed to this repository
at a documented path. Behaviour MUST NOT depend on an undeclared default, on editor settings, or
on per-developer configuration.

A tool's documented default MAY be relied on without being restated in the configuration file,
provided both of the following hold: the tool's version is pinned exactly, and the relied-on
default is recorded in the repository's written record of chosen settings. Editor settings and
per-developer configuration are forbidden with no exception.

Rationale: an uncommitted setting is a setting that differs per machine, and a standard that
differs per machine is not a standard. But restating a default in the configuration file buys
none of that guarantee — it comes from the version pin — and it costs the reader the ability to
tell a decision from a value nobody chose. Recording the relied-on default in the written record
keeps it declared, which is the property that matters, without pretending it was chosen here.

### VI. Spec-Driven Change

Feature work MUST pass through the Spec Kit phases and MUST NOT reach implementation without a
spec, a plan, and a task list on disk.

Rationale: this repository is a toolkit for building agent workflows. It holds itself to the
workflow it ships.

## Quality Gate Requirements

Each combination of content kind and concern MUST have exactly one governing configuration file,
where the concerns are formatting and linting. A content kind MAY therefore be governed by one
formatting configuration and one linting configuration; it MUST NOT be governed by two of either.
Each check MUST be runnable from the repository root without arguments.

Rationale: a formatter and a linter check disjoint properties of the same content, and neither
substitutes for the other, so requiring a single configuration per content kind forbade an
arrangement that is correct. What the clause exists to prevent is two tools rewriting the same
file, where the verdict depends on the order they ran in — and the per-concern limit forbids that
as absolutely as the original wording did.

A check MUST name the file and location of every violation it reports. A check that reports a
failure without a location does not satisfy this section.

Every script committed under the repository's script directory MUST itself be subject to the
shell static analysis check described in Principle IV. The tooling is not exempt from the
standards it enforces.

## Development Workflow

Feature work MUST be on a branch cut from the repository's default branch before it is
proposed for review. Which step creates that branch is not mandated: Spec Kit's branch creation
is an optional extension, so the branch may be cut by that extension, by hand, or as part of
shipping. Artifacts for a feature live under `specs/<NNN-slug>/`.

Before a change is proposed for review, the aggregate quality check MUST have been run and MUST
have passed. A change that has not been checked is not ready for review.

Machine-local and agent-local state MUST be excluded from version control rather than committed
and later cleaned up.

## Governance

This constitution supersedes all other practices in this repository. Where another document
conflicts with it, this document governs and the other document is amended.

Amendments require: a semantic version bump under the policy below, an updated
`Last Amended` date, and a written rationale recorded in the Sync Impact Report at the top of
this file.

Versioning policy:

- **MAJOR** — a principle is removed, or redefined in a way that invalidates work that
  previously complied.
- **MINOR** — a principle or section is added, or existing guidance is materially expanded.
- **PATCH** — clarifications, wording, and non-semantic refinements.

All reviews MUST verify compliance with these principles. Added complexity MUST be justified
against them; where it cannot be, the simpler alternative is taken.

**Version**: 1.2.0 | **Ratified**: 2026-09-02 | **Last Amended**: 2026-09-02
