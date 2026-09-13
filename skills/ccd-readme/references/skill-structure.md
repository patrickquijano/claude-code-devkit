# Skill Structure Reference

## Authoring Rules

All skill structure rules are defined in `.claude/rules/skill-authoring.md` at the repository root. Key constraints for ccd-readme:

- **SKILL.md line budget**: Maximum 500 lines (FR-009, SC-005)
- **Progressive disclosure**: Heavy content in `references/` and `templates/`, not SKILL.md (FR-010)
- **Script delegation**: All deterministic logic in `scripts/`, zero inline shell in SKILL.md (FR-008, SC-006)
- **Naming convention**: `ccd-` prefix, resolves as `claude-code-devkit:ccd-readme` (FR-015)

## Directory Layout

```text
skills/ccd-readme/
├── SKILL.md              # Thin orchestrator (<500 lines)
├── scripts/              # Deterministic computation (POSIX sh)
│   ├── inspect-project.sh
│   └── validate-readme.sh
├── templates/            # Reusable structural content
│   ├── readme-base.md
│   ├── license-MIT.md
│   ├── license-Apache-2.0.md
│   ├── license-ISC.md
│   └── license-GPL-3.0.md
└── references/           # Guidance and citations
    ├── readme-best-practices.md
    ├── license-guide.md
    └── skill-structure.md
```

## Progressive Disclosure Principles

1. **SKILL.md** contains only: triggers, workflow steps, safeguards, resource routing, output format
2. **scripts/** contains: all file inspection, validation, and deterministic computation
3. **templates/** contains: structural skeletons and license texts with placeholder markers
4. **references/** contains: best practices, decision guides, and cross-references to repo rules

## Line Budget Enforcement

Validated by `scripts/validate-readme.sh` (SC-005). Target ~200 lines with hard limit at 500.
