# License Decision Guide

> **NOTICE**: This guide is for informational purposes only and does not constitute legal advice. Consult a qualified attorney for legal decisions regarding software licensing.

## Supported Licenses

| SPDX ID      | Type       | Best For                                       | Key Characteristics                                         |
| ------------ | ---------- | ---------------------------------------------- | ----------------------------------------------------------- |
| MIT          | Permissive | Libraries, utilities, small projects           | Minimal restrictions, broad compatibility                   |
| Apache-2.0   | Permissive | Corporate projects, APIs, large codebases      | Patent grant, trademark protection, NOTICE file             |
| ISC          | Permissive | Minimalist projects, embedded systems          | Simplest permissive license, functionally equivalent to MIT |
| GPL-3.0-only | Copyleft   | Applications requiring derivative work sharing | Strong copyleft, ensures downstream freedom                 |

## Recommendation Criteria

When recommending a license, evaluate in this order:

1. **Existing signals**: If manifest declares a license, recommend matching it
2. **Project type**: Libraries → MIT/Apache-2.0; Applications → consider GPL-3.0
3. **Dependency compatibility**: Recommend license compatible with existing dependencies
4. **Default**: MIT (most permissive, widest compatibility)

## AskUserQuestion Template

Present exactly this structure when prompting:

```text
Which license would you like for this project?

⚠️ This is not legal advice. Consult an attorney for legal guidance.

Recommended: [SPDX_ID] — [concise justification]

Options:
- MIT: Permissive, minimal restrictions, widest compatibility
- Apache-2.0: Permissive with patent grant and trademark protection
- ISC: Simplest permissive license, functionally equivalent to MIT
- GPL-3.0-only: Copyleft, requires derivative works to share source
- Skip: Proceed without adding a license file
```

## Non-Legal-Advice Notice (Mandatory)

Every license prompt MUST include this exact notice:

> ⚠️ This is not legal advice. The information provided here is for informational purposes only and should not be construed as legal counsel. Consult a qualified attorney for legal decisions regarding software licensing.
