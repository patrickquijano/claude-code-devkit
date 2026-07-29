# GitHub Actions authoring rules

Applies to any workflow file under `.github/workflows/`. Consult before creating a new workflow or editing an existing one.

## Workflow design

Prefer composing jobs and reusable workflows over duplicating logic across files: call a shared workflow with `uses: org/repo/.github/workflows/x.yml@ref` and pass data between jobs via `needs.<job_id>.outputs.<name>` rather than copy-pasting steps. Keep each job focused on one responsibility (build, test, deploy) so failures are easy to attribute and jobs can run in parallel where they don't depend on each other.

## Triggers and untrusted input

Avoid the `pull_request_target` and `workflow_run` triggers unless the workflow genuinely needs their privileged context (repo write access, referenced secrets) — `pull_request` is safer and sufficient for most CI. When either privileged trigger is unavoidable, never check out or execute untrusted fork content (PR head ref, uploaded artifacts) within that workflow; doing so is the classic "pwn request" vector that lets a forked PR exfiltrate secrets or push to the repo.

## Runners

Default to GitHub-hosted runners. Only reach for self-hosted runners when GitHub-hosted can't meet a real requirement (custom hardware, network access), and never on a public repository without isolation — any external contributor who can open a PR can otherwise execute code on that runner. If self-hosted is unavoidable, prefer ephemeral/just-in-time runners over long-lived ones so a compromise doesn't persist across jobs.

## Permissions and secrets

Set the workflow's default `permissions` to read-only on contents, then grant broader `GITHUB_TOKEN` scopes only on the specific job that needs them — least privilege limits the blast radius of a compromised step or action. Never hardcode secret values in a workflow file. Never bundle multiple sensitive values into one structured secret (a JSON/YAML blob) — redaction matches on exact string values, so structured secrets defeat log masking; register each sensitive value as its own secret instead. If a step derives a new sensitive value from an existing secret (e.g. signing a JWT with a private key), register that derived value as a secret too, or it won't be redacted if it leaks into logs.

## Script injection

Never interpolate an untrusted expression (`${{ github.event.issue.title }}`, PR title/body, branch name, etc.) directly into a `run:` shell block — the value can contain shell metacharacters that execute as commands. Pass it through an intermediate `env:` variable and reference the env var in the script instead, or use a dedicated action that takes the value as a structured input.

```yaml
# wrong: value flows straight into the generated shell script
- run: echo "${{ github.event.pull_request.title }}"

# right: value is data, not script
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "$TITLE"
```

## Third-party actions

Pin third-party actions to a full-length commit SHA, verified against the action's real repository (not a fork) — this is the only immutable reference, since tags and branches can be moved or deleted. Only pin to a tag (`@v1`) if the publisher is verified/trusted and the convenience is worth the residual risk of a moved tag. Use Dependabot to keep pinned SHAs current so bug fixes and security patches aren't missed by freezing a version.

## Governance

Add `.github/workflows/` to a `CODEOWNERS` entry so changes to workflow files require review from a designated owner before merging — workflow files can grant repo write access or exfiltrate secrets, so they deserve the same scrutiny as production code.

## Testing

Dry-run a new or changed workflow with `workflow_dispatch` (or a local runner like `act`) before merging, and read the Actions tab run log to confirm the intended jobs, permissions, and outputs actually happened — don't assume a workflow does what its YAML implies without seeing a run.
