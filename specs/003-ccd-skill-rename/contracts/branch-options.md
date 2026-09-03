# Contract: `branch-options.sh`

**Feature**: [003-ccd-skill-rename](../spec.md) | **Date**: 2026-09-03

**Supersedes** [`specs/002-vendor-plugin-skills/contracts/branch-options.md`](../../002-vendor-plugin-skills/contracts/branch-options.md). That contract fixed the helper at `skills/auto-branch-push/scripts/branch-options.sh` and remains a true record of what shipped under feature 002; this one replaces it from feature 003 onward. **The script itself is unchanged — only its path moves.**

## Location

```text
skills/ccd-branch-push/scripts/branch-options.sh
```

Exactly one copy exists in the repository. It is owned by `ccd-branch-push` and consumed by four skills.

## Invocation

| Consumer          | Invocation                                                                  |
| ----------------- | --------------------------------------------------------------------------- |
| `ccd-branch-push` | `sh ${CLAUDE_PLUGIN_ROOT}/skills/ccd-branch-push/scripts/branch-options.sh` |
| `ccd-github-pr`   | same path                                                                   |
| `ccd-gitlab-mr`   | same path                                                                   |
| `ccd-speckit-run` | same path                                                                   |

All four invoke the owner's copy through `${CLAUDE_PLUGIN_ROOT}`, which expands to the plugin's installation directory — so no install location is written down anywhere, and the path holds wherever the plugin is installed.

`sh` is explicit in every invocation. The executable bit does not survive every install path.

## Output

Unchanged by this feature. Four tab-separated columns, one line per branch candidate: branch name; `local` / `remote` / `both`; last commit date; and the tag column. Consumers parse it positionally, so the column count and order are the contract.

Exit 1 means not a git work tree.

## Guaranteed

- Exactly one implementation exists in the tree.
- It lives under the owner named above and nowhere else.
- All four consumers reach that one copy, so they see identical candidates by construction rather than by comparison.
- The script's contents are byte-for-byte what feature 002 established. This feature moves the file and rewrites the skill name in its header comment; it changes no logic and no output.

## Not guaranteed

- That a consumer's own `scripts/` directory contains it. Three of the four have no copy and must not gain one.

## The regression to catch

A second copy reappearing anywhere under `skills/`. There is nothing to keep in step while there is one implementation; adding a copy replaces a structural guarantee with a comparison that has already failed once. The rejected fork's three defects are recorded in the script's own header comment, and that comment moves with the file.

Comparing copies is not the check. **Counting** them is — a count cannot miss a copy the way a comparison can.

## Verifying this contract

```sh
# exactly one copy, in the right place
find skills -name branch-options.sh # expect skills/ccd-branch-push/scripts/branch-options.sh

# all four consumers reference the new path
grep -rl 'ccd-branch-push/scripts/branch-options\.sh' skills/*/SKILL.md | wc -l # expect 4

# no consumer references the old path
grep -rn 'auto-branch-push/scripts/branch-options\.sh' skills/ # expect no output
```
