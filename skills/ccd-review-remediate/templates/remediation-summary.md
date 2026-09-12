# Remediation Summary

**Change Request**: {{cr_id}}
**Forge**: {{forge}}
**Cycle**: {{cycle}}
**Date**: {{date}}

## Findings Addressed

| Finding ID | Severity  | Resolution       | Files Changed | Checks Run   | Commit SHA |
| ---------- | --------- | ---------------- | ------------- | ------------ | ---------- |
| {{id_1}}   | {{sev_1}} | {{resolution_1}} | {{files_1}}   | {{checks_1}} | {{sha_1}}  |

_Repeat row for each finding addressed in this cycle._

## Validation Results

| Command   | Exit Code  | Output Excerpt |
| --------- | ---------- | -------------- |
| {{cmd_1}} | {{exit_1}} | {{excerpt_1}}  |

## Partial Remediation

{{#if partial}}
**Warning**: Remediation stopped mid-cycle. Working tree left as-is with uncommitted changes.

- Findings addressed: {{partial_completed_ids}}
- Findings remaining: {{partial_remaining_ids}}
- Failure reason: {{partial_failure_reason}}
  {{/if}}

## Notes

{{remediation_notes}}
