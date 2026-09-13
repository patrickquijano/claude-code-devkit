# README Best Practices Reference

## Authoritative Sources

- **Standard Readme Specification**: <https://github.com/RichardLitt/standard-readme>
- **GitHub README Guidance**: <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes>
- **Make a README**: <https://www.makeareadme.com/>

## Section-to-Artifact Mapping

| README Section | Verified Artifact Source(s) |
| ---------------- | ---------------------------- |
| Title + Badges | `package.json` `name`, `Cargo.toml` `[package].name`, directory basename |
| Description | Manifest `description`/`summary`, existing README first paragraph |
| Install | Package manifest type (`package.json` → npm, `Cargo.toml` → cargo, etc.) |
| Usage | Source file entry points, existing docs, examples directory |
| Documentation | `docs/` directory, `CONTRIBUTING*`, API doc config files |
| Contributing | `CONTRIBUTING*` file, `.github/` templates |
| License | `LICENSE*` file, manifest `license` field |

## Structural Rules

1. Every section MUST trace to at least one verified artifact (SC-001)
2. Never infer project details absent from repository files (FR-002)
3. Preserve accurate existing content byte-identical (FR-003, SC-003)
4. Generated content language matches existing README when detectable
5. No timestamps or non-deterministic values in output (FR-012)
