# Security Policy

`oss-actions` runs inside other projects' CI pipelines, often with access to repository secrets and write-scoped tokens. We take all security reports seriously and ship fixes as quickly as possible.

## Supported versions

Each action is released with semantic versioning and a moving major-version tag (e.g. `v1`). Only the latest major receives security updates — consumers pinned to `v1` pick them up automatically on the next workflow run.

| Version       | Supported          |
| ------------- | ------------------ |
| `v1` (latest) | :white_check_mark: |
| `< v1`        | :x:                |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security reports.** Public disclosure before a fix ships puts every consumer of these actions at risk.

Use GitHub's [Private Vulnerability Reporting](https://github.com/enthus-appdev/oss-actions/security/advisories/new) to open a draft security advisory. This routes the report to the maintainers privately and lets us collaborate on the fix in the same place.

Please include:

- The affected action (`npm-license-validator`, `go-license-validator`, or both).
- A description of the vulnerability and its impact.
- Reproduction steps or a minimal proof of concept, if you have one.
- A suggested mitigation, if applicable.
- Your preferred credit for the resulting advisory, or a request to stay anonymous.

## What to expect

- **Acknowledgement** within 3 business days of receiving the report.
- **Initial assessment** within 14 days — accepted, declined with reasoning, or a request for more information.
- **Fix and coordinated release** for accepted reports as quickly as possible. Timing depends on severity and complexity; we will keep you updated throughout.
- **Credit** in the published GitHub Security Advisory unless you opt out.

## Scope

**In scope:**

- Command injection, argument injection, or unsafe input handling in the composite action shell code.
- Leakage of secrets, tokens, or environment variables via logs, outputs, or generated SBOM artifacts.
- Any path through these actions that fetches or executes attacker-controlled code by default.

**Out of scope:**

- Consumer workflows that use these actions unsafely (e.g. `pull_request_target` with untrusted input).
- Vulnerabilities in upstream tools (`@cyclonedx/cyclonedx-npm`, `cyclonedx-gomod`, `jq`, `npx`) — please report those to their respective maintainers.
- Issues requiring the attacker to already have write access to the repository using the action.
