# Go License Validator Action

Validate Go module licenses using CycloneDX SBOM generation and check against forbidden licenses.

## Description

This action provides comprehensive license validation for Go projects with:
- Automatic SBOM generation using CycloneDX
- Modular validation pipeline with clear separation of concerns
- Configurable forbidden license detection
- Detailed license reporting in GitHub Step Summary
- Flexible failure handling
- Rich outputs for integration with other tools

### Validation Pipeline

The action runs through multiple focused steps:

1. **SBOM Generation**: Creates CycloneDX SBOM using official action
2. **SBOM Validation**: Verifies file existence and JSON structure
3. **License Extraction**: Parses license information from components
4. **Forbidden Check**: Compares found licenses against forbidden list
5. **Report Generation**: Creates detailed GitHub Step Summary
6. **Status Handling**: Outputs results and handles failure conditions

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `forbidden_licenses` | Semicolon-separated list of forbidden license identifiers | Yes | - |
| `working_directory` | Working directory where go.mod is located | No | `.` |
| `output_file` | Output file for the generated SBOM | No | `sbom.json` |
| `cyclonedx_version` | Version of cyclonedx-gomod to use | No | `v1` |
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
- uses: enthus-appdev/oss-actions/go-license-validator@v1
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0"
```

### Custom Working Directory

```yaml
- uses: enthus-appdev/oss-actions/go-license-validator@v1
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;LGPL-3.0"
    working_directory: "./backend"
    output_file: "backend-sbom.json"
```

### Warning Mode (Don't Fail)

```yaml
- uses: enthus-appdev/oss-actions/go-license-validator@v1
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0"
    fail_on_forbidden: false
```

### Using Outputs for Further Processing

```yaml
- name: Validate Licenses
  id: license-check
  uses: enthus-appdev/oss-actions/go-license-validator@v1
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0"

- name: Upload SBOM Artifact
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: ${{ steps.license-check.outputs.sbom_file }}

- name: Post Results to Slack
  if: steps.license-check.outputs.forbidden_found == 'true'
  run: |
    echo "Forbidden licenses found: ${{ steps.license-check.outputs.licenses_found }}"
    # Add Slack notification logic here
```

## Complete Examples

### Pull Request License Check

```yaml
name: License Check
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  license-validation:
    runs-on: ubuntu-latest
    name: Validate Go Licenses
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true
      
      - name: Validate Licenses
        uses: enthus-appdev/oss-actions/go-license-validator@v1
        with:
          forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0;BUSL-1.1"
          fail_on_forbidden: true
```

### Multi-Module Project

```yaml
name: License Validation
on:
  push:
    branches: [main]

jobs:
  validate-licenses:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        module:
          - path: "./backend"
            name: "Backend API"
          - path: "./worker"
            name: "Background Worker"
          - path: "./cli"
            name: "CLI Tool"
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: "1.21"
          cache: true
      
      - name: Validate ${{ matrix.module.name }} Licenses
        uses: enthus-appdev/oss-actions/go-license-validator@v1
        with:
          forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0"
          working_directory: ${{ matrix.module.path }}
          output_file: "${{ matrix.module.name }}-sbom.json"
      
      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: "sbom-${{ matrix.module.name }}"
          path: "${{ matrix.module.name }}-sbom.json"
```

### Enterprise Compliance Workflow

```yaml
name: License Compliance
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  compliance-check:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true
      
      - name: Generate License Report
        id: license-report
        uses: enthus-appdev/oss-actions/go-license-validator@v1
        with:
          forbidden_licenses: "GPL-3.0;AGPL-3.0;SSPL-1.0;BUSL-1.1;Commons-Clause"
          fail_on_forbidden: false  # Generate report but don't fail
          output_file: "compliance-sbom.json"
      
      - name: Archive SBOM for Compliance
        uses: actions/upload-artifact@v4
        with:
          name: "compliance-sbom-${{ github.run_number }}"
          path: "compliance-sbom.json"
          retention-days: 365
      
      - name: Create Issue on Forbidden Licenses
        if: steps.license-report.outputs.forbidden_found == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'License Compliance Issue Detected',
              body: `
              ## 🚨 License Compliance Alert
              
              Forbidden licenses have been detected in the codebase:
              
              **Total Components**: ${{ steps.license-report.outputs.total_components }}
              **Components with Licenses**: ${{ steps.license-report.outputs.components_with_licenses }}
              **Forbidden License Found**: Yes
              
              Please review the [workflow run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}) for detailed information.
              
              /cc @legal-team @security-team
              `,
              labels: ['compliance', 'legal-review', 'high-priority']
            })
```

### Custom Validation with SBOM Processing

```yaml
- name: License Validation with Custom Processing
  id: validate
  uses: enthus-appdev/oss-actions/go-license-validator@v1
  with:
    forbidden_licenses: "GPL-3.0;AGPL-3.0"
    output_file: "project-sbom.json"

- name: Process SBOM for Internal Tools
  run: |
    # Extract specific license information
    LICENSES=$(echo '${{ steps.validate.outputs.licenses_found }}' | jq -r '.[]' | sort | uniq)
    echo "Found licenses: $LICENSES"
    
    # Check component count
    if [ "${{ steps.validate.outputs.total_components }}" -gt 100 ]; then
      echo "Large dependency footprint detected"
    fi
    
    # Custom validation logic
    if echo "$LICENSES" | grep -q "MIT\|Apache-2.0\|BSD"; then
      echo "✅ Preferred licenses found"
    fi
```

## Forbidden License Examples

Common forbidden licenses to watch for:

```yaml
# Copyleft licenses
forbidden_licenses: "GPL-3.0;GPL-2.0;LGPL-3.0;LGPL-2.1;AGPL-3.0"

# Commercial/proprietary licenses
forbidden_licenses: "SSPL-1.0;BUSL-1.1;Commons-Clause;Elastic-2.0"

# Comprehensive enterprise list
forbidden_licenses: "GPL-3.0;GPL-2.0;LGPL-3.0;LGPL-2.1;AGPL-3.0;SSPL-1.0;BUSL-1.1;Commons-Clause;Elastic-2.0;EUPL-1.2"
```

## Generated Reports

The action generates comprehensive reports in the GitHub Step Summary including:

- **Scan Summary**: Component counts and license statistics
- **Forbidden License Alerts**: Details of any violations found
- **Complete License Inventory**: All licenses found with usage counts
- **Component Details**: Which components use which licenses

## Common License Identifiers

Use these SPDX license identifiers in your `forbidden_licenses` input:

| License | SPDX ID |
|---------|---------|
| GNU General Public License v3.0 | `GPL-3.0` |
| GNU General Public License v2.0 | `GPL-2.0` |
| GNU Affero General Public License v3.0 | `AGPL-3.0` |
| GNU Lesser General Public License v3.0 | `LGPL-3.0` |
| Server Side Public License v1 | `SSPL-1.0` |
| Business Source License 1.1 | `BUSL-1.1` |
| Elastic License 2.0 | `Elastic-2.0` |

## Architecture

### Modular Design

The action is designed with a modular pipeline architecture that provides:

- **Clear separation of concerns**: Each step has a single responsibility
- **Better error isolation**: Failures are easier to identify and debug
- **Granular outputs**: Individual steps provide specific outputs for debugging
- **Improved readability**: GitHub Actions UI shows clear progression
- **Extensibility**: Easy to add new validation steps or modify existing ones

### Step Details

| Step | ID | Purpose | Key Outputs |
|------|----|---------| ------------|
| Generate SBOM | `generate` | Creates SBOM using CycloneDX | SBOM file |
| Validate SBOM | `validate-sbom` | Checks file validity | `sbom_valid`, `sbom_file` |
| Extract Licenses | `extract-licenses` | Parses license data | `licenses_found`, `total_components` |
| Check Forbidden | `check-forbidden` | Validates against rules | `forbidden_found`, `forbidden_details` |
| Generate Report | `generate-report` | Creates summary | GitHub Step Summary |
| Final Status | `final-status` | Handles exit codes | Success/failure status |

## Troubleshooting

### SBOM Generation Fails
- **Step**: `Generate SBOM with CycloneDX`
- **Check**: Ensure `go.mod` exists in the working directory
- **Check**: Verify Go version compatibility with CycloneDX tools
- **Check**: Ensure network access to download dependencies

### SBOM Validation Fails
- **Step**: `Validate SBOM generation`
- **Check**: Review SBOM file existence and JSON validity
- **Check**: Verify CycloneDX format compliance
- **Debug**: Check the generated file manually with `jq`

### No Licenses Detected
- **Step**: `Extract license information`
- **Cause**: Some packages may not have license information in go.mod
- **Solution**: Run with `include_dev_dependencies: true` to include test dependencies
- **Note**: Check if licenses are declared in package source code vs go.mod

### False Positives/Negatives
- **Step**: `Check for forbidden licenses`
- **Cause**: SPDX license IDs are case-sensitive
- **Cause**: Some packages use non-standard license identifiers
- **Debug**: Review the `licenses_found` output and generated SBOM file

### Report Generation Issues
- **Step**: `Generate detailed report`
- **Check**: Verify jq is available and working
- **Check**: Ensure GITHUB_STEP_SUMMARY is writable
- **Debug**: Review individual step outputs

### Performance Issues
- **Overall**: Large projects may take time to generate SBOM
- **Solution**: Consider running on schedule rather than every PR
- **Optimization**: Use caching for Go modules and tools
- **Monitoring**: Check individual step duration in GitHub Actions UI

## Dependencies

Requires:
- Go runtime (setup-go action recommended)
- CycloneDX SBOM generation tools (automatically installed)
- jq for JSON processing (available in GitHub runners)

## License

See the repository's [LICENSE](../LICENSE) file.