# Severity Model

Six severities and three confidence levels. Every finding MUST carry exactly one of each.

## Severities

| Severity   | Blocks pass | Definition                                                                                   |
| ---------- | ----------- | -------------------------------------------------------------------------------------------- |
| Critical   | Yes         | Data loss, security breach, or production outage with no workaround.                         |
| High       | Yes         | Correctness defect affecting primary user flows with difficult workaround.                   |
| Medium     | Yes         | Defect affecting secondary flows or degraded experience with available workaround.           |
| Low        | Yes         | Minor defect with trivial workaround or limited user impact.                                 |
| Suggestion | No          | Improvement that does not fix a defect. Never blocks pass.                                   |
| Question   | No          | Clarification request where evidence is insufficient to determine defect. Never blocks pass. |

## Confidence levels

| Confidence | Definition                                                                         |
| ---------- | ---------------------------------------------------------------------------------- |
| high       | Evidence directly demonstrates the defect; no reasonable alternative reading.      |
| medium     | Evidence strongly suggests the defect but an alternative reading exists.           |
| low        | Inference from indirect evidence or pattern matching; requires human confirmation. |

Severity and confidence are independent axes. A Critical finding may have low confidence when the evidence is suggestive but not conclusive. A Suggestion always has high confidence when the improvement is clearly applicable.

## Blocking rules

Per CHK003: a discussion blocks when the hosting platform marks it unresolved AND at least one comment in the thread carries a severity of Critical, High, Medium, or Low from a reviewer who is not the author. Suggestion and Question severities never block. Platform-native resolve state is authoritative; this skill does not invent blocking status.

## Assignment guidance

- When uncertain between two adjacent severities, choose the higher one and note the uncertainty in the evidence field.
- Never assign Critical or High without quoted evidence from the diff, config, test, or requirement.
- Suggestion and Question findings still require evidence; they differ in outcome required, not in evidentiary standard.
- A finding's severity may be revised during re-review if new evidence changes the assessment; record the revision reason in the audit trail.
