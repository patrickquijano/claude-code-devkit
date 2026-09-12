# Review Findings

**Change Request**: {{cr_id}}
**Forge**: {{forge}}
**Head SHA**: {{head_sha}}
**Reviewer**: {{reviewer}}
**Date**: {{date}}

## Summary

{{findings_count}} finding(s) identified across {{categories_count}} dimension(s).

| Severity   | Count                |
| ---------- | -------------------- |
| Critical   | {{critical_count}}   |
| High       | {{high_count}}       |
| Medium     | {{medium_count}}     |
| Low        | {{low_count}}        |
| Suggestion | {{suggestion_count}} |
| Question   | {{question_count}}   |

## Findings

### {{finding_id}}: {{title}}

- **Severity**: {{severity}}
- **Confidence**: {{confidence}}
- **Category**: {{category}}
- **File**: {{file}}
- **Line**: {{line}}

**Evidence**:

> {{evidence_quote}}

**Impact**: {{impact}}

**Required Outcome**: {{required_outcome}}

**Suggested Fix**: {{suggested_fix}}

**Validation Method**: {{validation_method}}

---

_Repeat the finding block above for each finding._

## Verdict

**Result**: {{verdict}}

| Criterion                | Status       | Evidence       |
| ------------------------ | ------------ | -------------- |
| no-blocking-findings     | {{status_1}} | {{evidence_1}} |
| ci-pass                  | {{status_2}} | {{evidence_2}} |
| discussions-resolved     | {{status_3}} | {{evidence_3}} |
| head-sha-unchanged       | {{status_4}} | {{evidence_4}} |
| approval-rules-satisfied | {{status_5}} | {{evidence_5}} |
| validation-pass          | {{status_6}} | {{evidence_6}} |

{{#if override_reason}}
**Override**: {{override_reason}}
{{/if}}
