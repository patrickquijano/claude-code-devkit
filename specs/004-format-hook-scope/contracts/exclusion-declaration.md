# Contract: where each check declares its excluded paths

**Date**: 2026-09-03 | **Feature**: [spec.md](../spec.md) | **Plan**: [plan.md](../plan.md)

Supersedes FR-013, FR-013a, FR-013b and FR-013c of `specs/001-quality-gate-plugin/spec.md`, and the "reads its scope from `.lintignore` and nothing else" clause of that feature's `contracts/cli.md`. Those established one central list plus five mirrors, kept in agreement by a seventh check. This replaces the arrangement with one declaration per check and deletes both the central list and the check that policed it.

## The rule

**Each check declares its excluded paths in exactly one place, and that place is the configuration file which already drives that check.**

One consequence is worth stating up front because it is the point of the change: a contributor who invokes a tool by hand, outside `scripts/`, gets the same exclusions the runner applies — because it is the same declaration, read by the tool itself. Under the old arrangement that held only as long as six copies stayed in step.

## The declarations

| Check | Declaration | Syntax |
| `format` | `.prettierignore`, whole file | gitignore-style |
| `markdown` | `ignores` array in `.markdownlint-cli2.jsonc` | JSONC array of globs; directories carry `/**` |
| `yaml` | `ignore` block scalar in `.yamllint.yml` | YAML block scalar, two-space body indent |
| `python` | `exclude` array in `ruff.toml` | TOML array of strings |
| `editorconfig` | `Exclude` array in `.editorconfig-checker.json` | JSON array of **regexes** |
| `shell` | marked comment block in `.shellcheckrc` | commented plain paths, repository convention |
| `citations` | **none** | — |

Six declarations, seven checks. `citations` consumes no file list — its scope is the fixed directory `.github` (`scripts/lint-citations.sh:59`) and it enumerates governance-quotation markers inside it — so it has no exclusions to declare and FR-021 is satisfied trivially. A reader who counts seven is looking for one that should not exist.

## Normalised form

Each declaration is read by one extractor. Every extractor emits the same thing:

```text
one repository-relative plain path per line, sorted,
no comments, no blank lines, no tool syntax
```

That is the form `exclude_pathspecs()` consumes to emit `:(exclude)<path>` git pathspecs, and it is already the form the six existing extractors produce — which is why they are **promoted** from `scripts/lint-scope.sh` into `scripts/lib/scope.sh` rather than rewritten. Deleting the file they live in without promoting them first would discard the only part of the old design worth keeping.

Per-syntax normalisation:

| Extractor | Normalisation |
| `extract_plain` | strip comments and trailing whitespace; drop blanks |
| `extract_markdownlint` | unquote; strip the trailing `/**` directories carry |
| `extract_yamllint` | strip the two-space body indent of the block scalar |
| `extract_ruff` | unquote; trailing comma optional |
| `extract_editorconfig` | unquote; strip leading `^`, trailing `$` or `/`; delete every backslash |
| `extract_shellcheck` | strip the leading `#`; drop blanks — **new**, modelled on `extract_plain` |

Two facts that look like defects and are not, both pre-existing and both unchanged here:

- `.editorconfig-checker.json` holds **regexes**, not globs. The backslash deletion is deliberate: JSON writes an escaped dot as two characters, so a single unescaping pass would leave one behind (`scripts/lint-scope.sh:88-93`).
- `ruff.toml`'s `exclude` **replaces** Ruff's default excludes rather than extending them, as its own comment says.

## `shell`, the check with no tool mechanism

ShellCheck has no path-exclusion directive — `.shellcheckrc:38-56` documents that, and it is why the old `lint-scope.sh:146` reported shell as `UNVERIFIABLE` rather than pass or fail. FR-023 requires the exclusions be declared somewhere a reader can find from that check alone.

The declaration is a marked block in `.shellcheckrc`:

```sh
# lint-exclude-begin
# .git
# .specify/scripts
# .specify/templates
# ...
# lint-exclude-end
```

ShellCheck ignores comment lines, so the block is inert to the tool and authoritative for the runner. `.shellcheckrc` is a committed configuration file at a documented path, which is what Principle V requires; a list inside `lint-shell.sh` would not be, and was rejected on that ground (research.md §12).

**One limitation, stated in `.shellcheckrc` itself as well as here**: FR-027 — a hand invocation getting the runner's exclusions — **cannot** be satisfied for this check, because ShellCheck provides no mechanism to satisfy it. `shellcheck scripts/*.sh` run by hand across the tree does not read this block. That was already true before this feature and is unchanged by it.

**The block must not exclude `scripts/`.** The constitution requires every script under the script directory to be subject to the shell check, and this feature adds a script there.

## Error behaviour

This is the part of the contract that the old arrangement did not need, and the main risk the change carries.

| Condition | Old behaviour, as a cross-check | Required new behaviour, as a source |
| Declaration file absent | empty list ⇒ comparison fails ⇒ loud, named difference | **exit non-zero, naming the file** |
| Declaration block not found in the file | as above | **exit non-zero, naming the file and the block** |
| File present, block present, no paths declared | empty list, legal | empty list, legal — and **distinguishable from the two above** |

Promoting a comparison to a source inverts the consequence of every failure mode: what used to be a loud mismatch becomes "exclude nothing", which silently widens a check's scope. Principle II applies directly — a partial result that exits zero is indistinguishable from a pass, and is acted on as one. Hence the hard failure, and hence the requirement that "declares nothing" be a distinct, legal state rather than the same empty list.

`extract_ruff` additionally needs its trailing comma made optional. Its pattern requires one, so an array whose last element lacks it silently loses that element. As a cross-check that was a latent bug; as the source of a file list it is a silent scope hole (research.md §13).

## Equality obligation

For each of the seven checks, the file list the check receives **must be identical before and after this change**. FR-024 states it, FR-025 requires it be demonstrated mechanically, SC-002 quantifies it as zero paths gained and zero lost.

Three details of the comparison are part of this contract, because getting any of them wrong would make a passing comparison meaningless:

- **Per check, not in aggregate.** A path lost by `markdown` and gained by `yaml` sums to zero and is a defect.
- **On the file list, not the exclusion set.** Two exclusion sets can differ while producing identical file lists — an exclusion for a path that does not exist, or one subsumed by another. What a check examines is what the claim is about. The exclusion sets are compared as a diagnostic; file-list equality is the requirement.
- **Sorted, then compared.** `git ls-files` output order is not part of any contract, and requiring identical order would fail on a difference that changes no behaviour — the same reasoning the old extractors already applied to their sets (`scripts/lint-scope.sh:50-51`).

The comparison survives as a self-test fixture rather than being run once during implementation, because SC-008 is a claim about the repository's continuing behaviour, not about one afternoon.

## Adding an excluded path, after this change

One edit, in the declaration of each check that should skip it. No central list, and no check that can now fail because two declarations disagree — there is no second declaration to disagree with.

A path that must be excluded from several checks is repeated in each of their declarations. That is deliberate and is **not** the duplication this feature removes: the old duplication was six copies of one list that had to be identical, enforced by a check; this is each check stating its own scope, and two checks legitimately differing is now expressible rather than a build failure.

## Removed

- **`.lintignore`** — deleted. It was the sixth copy.
- **`scripts/lint-scope.sh`** — deleted. It compared the six and failed on divergence; with one declaration per check there is nothing to compare.
- **`scope` from `scripts/lint.sh`'s `CHECKS`** — eight checks become seven.

The comment in `.gitignore` claiming `.lint-selftest-tmp/` must be "Also in `.lintignore` -- both are required" becomes false and is corrected; the self-test fixtures are excluded through each check's own declaration instead.
