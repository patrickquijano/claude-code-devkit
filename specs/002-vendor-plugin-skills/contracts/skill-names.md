# Contract: resolvable skill names, and the dispatch between them

**Feature**: [../spec.md](../spec.md) | **Plan**: [../plan.md](../plan.md) | **Research**: [../research.md](../research.md) §4

> **Superseded** by [`specs/003-ccd-skill-rename/contracts/skill-names.md`](../../003-ccd-skill-rename/contracts/skill-names.md), which renamed all five skills to a `ccd-` prefix. The names below are a true record of what shipped under this feature and are no longer current.

The interface this feature exposes is a set of names. A consumer who installs the plugin addresses the five skills by them; three of the five are addressed by a fourth as well. This file states those names and what a caller may rely on.

## The five names

Plugin name is `claude-code-devkit`, from `.claude-plugin/plugin.json`. Each skill's directory basename equals its frontmatter `name`, and the resolvable name is the two joined by a colon.

| Directory                  | Frontmatter `name` | Resolvable name                       | Invoked by                                        |
| -------------------------- | ------------------ | ------------------------------------- | ------------------------------------------------- |
| `skills/speckit-run/`      | `speckit-run`      | `claude-code-devkit:speckit-run`      | a user only                                       |
| `skills/auto-branch-push/` | `auto-branch-push` | `claude-code-devkit:auto-branch-push` | a user                                            |
| `skills/auto-commit-push/` | `auto-commit-push` | `claude-code-devkit:auto-commit-push` | a user, or `speckit-run` at 6a                    |
| `skills/auto-github-pr/`   | `auto-github-pr`   | `claude-code-devkit:auto-github-pr`   | a user, or `speckit-run` at 6b on a GitHub remote |
| `skills/auto-gitlab-mr/`   | `auto-gitlab-mr`   | `claude-code-devkit:auto-gitlab-mr`   | a user, or `speckit-run` at 6b on a GitLab remote |

**Guarantees**

- The namespaced form is the addressable name. The colon separator carries no spaces.
- A personal or project skill of the same base name does not shadow any of these, and none of these shadows it. The namespace makes the two non-colliding by construction, which is what satisfies FR-006 -- resolution is deterministic because the names are distinct, not because a precedence rule was chosen.
- `speckit-run` is reachable by a user and not by automatic invocation. The other four are reachable both ways.

**Not guaranteed**, and stated because a caller might assume it: that the bare name resolves to the distributed copy. The documentation states the namespaced form and does not say whether the unprefixed name is also valid for a plugin skill. Callers use the namespaced form; nothing here depends on the bare form working, and nothing here promises it fails.

## Dispatch contract

`speckit-run` hands work to three of the four at two points in its run.

| Point | Target                                | Chosen by                                      | Carries                                                 |
| ----- | ------------------------------------- | ---------------------------------------------- | ------------------------------------------------------- |
| 6a    | `claude-code-devkit:auto-commit-push` | the user's answer to 6a's question             | an explicit path list, credential-shaped paths excluded |
| 6b    | `claude-code-devkit:auto-github-pr`   | `tooling.forge = "github"`, recorded at Step 0 | the verification status                                 |
| 6b    | `claude-code-devkit:auto-gitlab-mr`   | `tooling.forge = "gitlab"`, recorded at Step 0 | the verification status                                 |

**Guarantees**

- The target at 6b is read from run state, decided once at Step 0 by `forge-detect.sh`. It is never re-derived at dispatch time and never inferred from the task description.
- A dispatch is a `Skill` tool call. Naming a skill in prose invokes nothing.
- Each dispatched skill owns its own questions. The caller hands over facts -- target or base branch, verification status, path list -- and never answers on the callee's behalf.

**Failure behaviour**

- Availability is determined at **Step 0**, not at dispatch. This is the contract's load-bearing clause: a companion found missing six phases later has already cost the caller a full pipeline run.
- Step 0 resolves availability from the session's own available-skills listing, treating it as authoritative, and falls back to a filesystem check that covers a plugin install and a personal install both.
- A companion recorded unavailable degrades that step and records the reason: 6a drops its commit option and offers only "open anyway" or "stop"; 6b is skipped with the reason written to `ship.subskill_calls.6b`. The run still completes.
- A dispatch attempted against an unresolvable name is reported naming the target. Whether the host makes that observable to the caller is not documented ([../research.md](../research.md) §4, Gap 5), which is why Step 0's probe -- not the call site -- is where availability is settled.

## Frontmatter contract

Exactly one of the five carries `disable-model-invocation: true`, and it is `speckit-run`.

| Skill          | `disable-model-invocation` | Consequence if changed                                                              |
| -------------- | -------------------------- | ----------------------------------------------------------------------------------- |
| `speckit-run`  | `true`                     | removed: an eight-phase pipeline can start unbidden                                 |
| the other four | absent                     | added: `speckit-run`'s 6a or 6b dispatch breaks, silently, at the end of a full run |

**Guarantee**: the asymmetry is preserved by distribution. It is not a style inconsistency to be tidied, and each of the four companions carries a written warning against adding the field.

**Validation**: by inspection. No tool checks this, and SC-009 counts it -- exactly 1 of 5.
