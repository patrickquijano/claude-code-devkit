# Data Model: Format on modification, and one exclusion declaration per check

**Date**: 2026-09-03 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

This feature has no datastore and no persisted records. What it does have is a small number of values that pass between the hook, the check scripts and the shared library, each with a definite shape and definite validation rules. Getting those shapes wrong is how a path escapes containment or an exclusion silently stops applying, so they are written down here with the same care a schema would get.

## Entities

### Hook invocation

The payload the platform delivers on the hook's standard input, and the only external input this feature accepts.

| Field | Shape | Used? | Notes |
| `hook_event_name` | string | no | Always `PostToolUse` for this hook; the matcher has already selected the event |
| `tool_name` | string | no | One of `Edit`, `Write`, `MultiEdit`, `NotebookEdit`; the matcher has already selected it |
| `tool_input.file_path` | absolute path string | **yes** | The one field read. Extraction and its single blind spot: research.md §4 |
| `cwd` | absolute path string | no, deliberately | Follows the session into a worktree. Not read — the repository root is derived from the script's own location instead, so the hook, the checks and the configuration always agree on which tree they are in. Consequence recorded in research.md §5 |
| everything else | — | no | `session_id`, `transcript_path`, `permission_mode`, `tool_response`, `tool_use_id` and the rest are ignored |

**Validation**: the payload is untrusted. Only `tool_input.file_path` is read, and it is treated as a candidate rather than a path until it has passed every rule under _Candidate path_ below.

### Candidate path

A single filesystem path, offered for formatting, before it has earned the right to be formatted.

**States**, in the order the rules are applied. The first rule that rejects ends the invocation:

| State | Rule | Outcome |
| unextractable | no `file_path` in the payload, or the extracted value is empty | exit 0, no output |
| unresolvable | the directory portion cannot be entered (`cd -- "$(dirname -- "$p")"` fails) | exit 0, no output |
| outside | the resolved absolute path is not prefixed by `$REPO_ROOT/` | exit 0, no output |
| absent | no longer exists, or never existed | exit 0, no output |
| symlink | is a symbolic link, wherever it points — refused rather than followed, so a link inside the repository cannot reach a file outside it | exit 0, no output |
| irregular | exists but is not a regular file — a directory, device node, socket, FIFO | exit 0, no output |
| binary | a NUL byte within the first 8 KiB | exit 0, no output |
| **eligible** | none of the above | proceeds to _Check invocation_ |

**Invariants**:

- Resolution uses `pwd -P`, so the directory portion has its symbolic links resolved **before** the containment test. A symlink inside the repository pointing outward is `outside`, not `eligible`.
- The containment test includes the trailing `/`, so a sibling directory whose name begins with the repository's own name cannot pass.
- Every rejection is exit 0 with no output. Rejection is a normal outcome, not a failure — FR-008 requires it, and `PostToolUse` cannot undo the edit anyway, so a non-zero exit here would report a problem nobody can act on.
- No rejection writes anything, anywhere, including inside the repository.

### Check

One of the repository's seven quality checks after this feature. Not a new entity — this feature only adds two attributes to a thing that already exists.

| Attribute | Where it lives | Changed by this feature? |
| Name | `lint.sh`'s `CHECKS`, and the script filename | Yes — `scope` removed, leaving seven |
| Globs | that check's own `collect ...` call | No |
| Can rewrite | whether the script calls `no_automatic_fix` under `--fix` | No |
| Native tool and pinned image | `scripts/lib/images.sh` | No |
| **Exclusion declaration** | the check's own configuration file | **Yes — this is half one** |

**The seven, and their two feature-relevant attributes**:

| Check | Can rewrite | Exclusion declaration | Invoked by the hook? |
| `citations` | no | none needed — fixed directory, no file list | no |
| `editorconfig` | no | `Exclude` in `.editorconfig-checker.json` | no |
| `format` | **yes** | `.prettierignore` | **yes, 1st** |
| `markdown` | **yes** | `ignores` in `.markdownlint-cli2.jsonc` | **yes, 2nd** |
| `yaml` | no | `ignore` in `.yamllint.yml` | no |
| `shell` | no | marked block in `.shellcheckrc` | no |
| `python` | **yes** | `exclude` in `ruff.toml` | **yes, 3rd** |

**Invariants**:

- Exactly one exclusion declaration per check (FR-021). Six declarations for seven checks, because `citations` consumes no file list — a reader who counts seven is looking for one that should not exist (research.md §15).
- Only the three that can rewrite are invoked by the hook (FR-004). Invoking a report-only check per edit would fail the session on violations the edit did not cause.
- The hook's order is `lint.sh`'s order. It is fixed and declared in one place, because Markdown is governed by two rewriting checks and the result depends on which ran first (FR-005).

### Exclusion declaration

The statement of which paths one check skips. After this feature there is exactly one per check, and it is the file that already drives that check.

| Declaration | Syntax | Normalisation the extractor performs |
| `.prettierignore` | gitignore-style | strip comments and trailing whitespace, drop blanks |
| `ignores` in `.markdownlint-cli2.jsonc` | JSONC array of globs | unquote; strip the trailing `/**` that directories carry |
| `ignore` in `.yamllint.yml` | YAML block scalar | strip the two-space body indent |
| `exclude` in `ruff.toml` | TOML array | unquote; trailing comma optional after hardening (research.md §13) |
| `Exclude` in `.editorconfig-checker.json` | JSON array of **regexes** | unquote; strip leading `^`, trailing `$` or `/`; delete every backslash |
| marked block in `.shellcheckrc` | commented plain paths between `# lint-exclude-begin` and `# lint-exclude-end` | strip the leading `#`; drop blanks |

**Normalised form**: one repository-relative plain path per line, sorted, no comments, no blanks, no syntax. This is the form `exclude_pathspecs()` consumes to emit `:(exclude)<path>` git pathspecs, and it is the form the six existing extractors already produce — which is why they are promoted rather than rewritten.

**Invariants**:

- A declaration that cannot be read — file absent, or the block not found — is an **error**, not an empty list. Before this feature an empty result made a comparison fail loudly; as the source of the file list it would silently mean "exclude nothing" and widen every check's scope. Principle II applied to the inversion (research.md §13).
- "Present but declaring nothing" is a distinct, legal state and must be distinguishable from the error above.
- `.editorconfig-checker.json` holds regexes, not globs. `ruff.toml`'s `exclude` replaces Ruff's defaults rather than extending them. Both are pre-existing facts, both look like bugs, neither is changed here.

### File list

What a check actually examines: the output of `file_list()`, NUL-separated repository-relative paths.

**Derivation**, after this feature:

```text
git ls-files --cached --others --exclude-standard
  ∩  the check's own globs
  ∖  the check's own exclusion declaration
  ∩  the caller's `-- <path>...` list, when one was given
```

**Invariants**:

- The caller's path list **narrows** and never widens. It is applied by filtering `file_list()`'s output, not by validating the caller's paths and passing them through — the second form would let a caller reach an excluded or out-of-glob file, which would break FR-006 and FR-007 (research.md §10).
- Empty is a success. `collect()` says `no files in scope` and exits 0, which is already the correct answer for an excluded path, an unsupported kind, and a path outside a check's globs — three of the spec's safety cases handled by code that already exists.
- Both tracked and untracked-but-not-gitignored files count. Unchanged from today: a file not yet committed is still one a contributor is about to commit.
- Order is not part of any contract. The equality proof sorts before comparing, for the same reason `lint-scope.sh:50-51` already sorted its sets — requiring identical order would fail on a difference that changes no behaviour.
- **The claim this feature must prove**: for each of the seven checks, this list is identical before and after half one. Per check, not in aggregate; on the file list, not on the exclusion set (research.md §14, FR-024, FR-025, SC-002).

### Check invocation

One call from `format-file.sh` to one check script.

| Element | Value |
| Command | `sh "$SCRIPT_DIR/lint-<check>.sh" --fix -- "<resolved path>"` |
| Order | `format`, then `markdown`, then `python` |
| Continue on | exit 0 (the check ran, or nothing was in scope), exit 3 (no tooling) |
| Stop on | exit 1 (violations left unfixed), exit 2 (usage), exit 4 (not a git tree) |

**Outcome mapping** — how each invocation's status becomes the hook's own result:

| Status | Meaning | Hook's response | Requirement |
| 0, files were in scope | the check ran | `systemMessage` naming file and check; continue | FR-012 |
| 0, `no files in scope` | this check does not govern the file | no message; continue | FR-007 |
| 1 | violations the check could not fix | **exit 2**; file, check and the check's own unmodified output on stderr | FR-011 |
| 2 | usage error — the hook built a bad command line | **exit 2**, same channel. A defect in this feature, surfaced not swallowed | FR-011 |
| 3 | neither native tool nor container available | `systemMessage` naming the missing tool and the image; **continue** | FR-018 |
| 4 | not a git working tree | **exit 2**, same channel. The hook only runs inside this repository, so this means something is genuinely wrong | FR-011 |

**Invariants**:

- Stop at the first stopping status; do not run the remaining checks (Principle II).
- Exit 3 never stops the run and never fails the edit — making a container runtime a precondition for editing a governed file is what Principle I forbids.
- The check's output is passed through **unmodified**. It already names the file and the location, which is what the Quality Gate section requires; re-formatting it would risk losing that.
- Exit 2 from the hook is a reporting channel, not a veto. `PostToolUse` cannot block, so the edit stands and the session is told what to fix.

### Recursion guard

One environment variable, exported before any check is invoked and tested on entry.

| Property | Value |
| Lifetime | one process tree; nothing on disk |
| On entry, if set | exit 0 immediately, no output |
| Before invoking anything | export it |

**Why it exists even though the event cannot loop**: `PostToolUse` fires on tool calls, and the formatters write to disk directly without one, so the loop FR-010 names cannot form through the designed path. FR-010 is a hard requirement and does not rest on a single argument. The guard covers what the reasoning does not: a formatter that itself invoked Claude Code, a future edit that introduces a tool-calling step, and any path nobody has thought of. Two lines, no cleanup, no stale-state failure mode — which is why it is a variable and not a lock file (research.md §9).

## Relationships

```text
Hook invocation ──reads one field──▶ Candidate path
                                          │
                              (8 rules, first rejection wins)
                                          │
                                     eligible
                                          │
                       ┌──────────────────┼──────────────────┐
                       ▼                  ▼                  ▼
              Check invocation    Check invocation    Check invocation
                  (format)           (markdown)          (python)
                       │                  │                  │
                       └──────────────────┴──────────────────┘
                                          │
                             each consults its own
                                          ▼
                                     File list
                                          │
                              derived in part from
                                          ▼
                            Exclusion declaration (one per check)

Recursion guard ── set for the whole subtree, tested at every entry ──▶ (all of the above)
```

The shape worth noticing: the hook knows nothing about file kinds. It hands the same path to all three rewriting checks and each consults its own globs and its own exclusion declaration to decide whether the path is its business. That is what keeps the extension-to-check mapping in one place — the place that already owned it.
