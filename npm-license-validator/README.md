# npm License Validator Action

Validate npm package licenses using CycloneDX SBOM generation and check against forbidden licenses.

## Description

This action provides comprehensive license validation for npm projects with:
- Automatic SBOM generation using CycloneDX
- Modular validation pipeline with clear separation of concerns
- Configurable forbidden license detection
- Detailed license reporting in GitHub Step Summary
- Flexible failure handling
- Rich outputs for integration with other tools

### Validation Pipeline

The action runs through multiple focused steps:

1. **SBOM Generation**: Creates CycloneDX SBOM using `@cyclonedx/cyclonedx-npm`
2. **SBOM Validation**: Verifies file existence and JSON structure
3. **License Extraction**: Parses license information from components
4. **Forbidden Check**: Compares found licenses against forbidden list
5. **Report Generation**: Creates detailed GitHub Step Summary
6. **Status Handling**: Outputs results and handles failure conditions

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `forbidden_licenses` | Semicolon-separated list of forbidden license identifiers | Yes | - |
| `working_directory` | Working directory where package.json is located | No | `.` |
| `output_file` | Output file for the generated SBOM | No | `sbom-npm.json` |
| `cyclonedx_npm_version` | Version of @cyclonedx/cyclonedx-npm to use (e.g. `"^1"`, `"1.19.3"`) | No | `latest` |
| `fail_on_forbidden` | Whether to fail the action when forbidden licenses are found | No | `true` |
| `include_dev_dependencies` | Include development dependencies in the scan | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `forbidden_found` | Whether forbidden licenses were found (true/false) |
| `licenses_found` | JSON array of all unique licenses found |
| `sbom_file` | Path to the generated SBOM file |
| `total_components` | Total number of components scanned |
| `components_with_licenses` | Number of components with license information |

## Usage

### Basic License Validation

```yaml
- uses: enthus-appdev/oss-actions/npm-license-validator@main
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0"
```

### Custom Working Directory (monorepo)

```yaml
- uses: enthus-appdev/oss-actions/npm-license-validator@main
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;LGPL-3.0"
    working_directory: "./frontend"
    output_file: "frontend-sbom.json"
```

### Warning Mode (Don't Fail)

```yaml
- uses: enthus-appdev/oss-actions/npm-license-validator@main
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0"
    fail_on_forbidden: false
```

### Including Dev Dependencies

```yaml
- uses: enthus-appdev/oss-actions/npm-license-validator@main
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0"
    include_dev_dependencies: true
```

## Complete Example: PR License Check

```yaml
name: License Node
on:
  push:
    branches:
      - main
      - master
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

jobs:
  license-check:
    runs-on: ubuntu-latest
    name: License Check
    if: github.event_name != 'pull_request' || (!github.event.pull_request.draft && !contains(github.event.pull_request.title, 'WIP'))
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Cache license check
        id: license-cache
        uses: actions/cache@v5
        with:
          path: .license-check-passed
          key: license-${{ hashFiles('package-lock.json') }}

      - name: Run license check
        if: steps.license-cache.outputs.cache-hit != 'true'
        uses: enthus-appdev/oss-actions/npm-license-validator@main
        with:
          forbidden_licenses: ${{ vars.FORBIDDEN_LICENSES }}

      - name: Mark license check as passed
        if: steps.license-cache.outputs.cache-hit != 'true'
        run: echo "passed" > .license-check-passed
```

## Forbidden License Examples

```yaml
# Copyleft licenses
forbidden_licenses: "GPL-3.0;GPL-2.0;LGPL-3.0;LGPL-2.1;AGPL-3.0"

# Commercial/proprietary licenses
forbidden_licenses: "SSPL-1.0;BUSL-1.1;Commons-Clause;Elastic-2.0"

# Comprehensive enterprise list
forbidden_licenses: "GPL-3.0;GPL-2.0;LGPL-3.0;LGPL-2.1;AGPL-3.0;SSPL-1.0;BUSL-1.1;Commons-Clause;Elastic-2.0;EUPL-1.2"
```

## Dependencies

Requires:
- Node.js runtime (pre-installed on GitHub-hosted runners)
- `jq` for JSON processing (pre-installed on GitHub-hosted runners)
`@cyclonedx/cyclonedx-npm` is installed automatically via `npx`. No `npm install` or `node_modules` is required — the action reads license data directly from `package-lock.json` via `--package-lock-only`.

## License

See the repository's [LICENSE](../LICENSE) file.
