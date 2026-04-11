# Contributing

Thanks for your interest in contributing to oss-actions. Contributions are welcome via pull requests.

## Reporting issues

Open a GitHub issue for bugs or feature requests. For security vulnerabilities, see [SECURITY.md](SECURITY.md) — please do not file them publicly.

## Development workflow

1. Fork the repository and branch off `main`.
2. Make a focused change. One action per PR unless the change is cross-cutting.
3. Test it (see below).
4. Open a pull request against `main` and describe the problem and the fix in the body.
5. Update the action's `README.md` if inputs, outputs, or behavior change.

## Testing changes

Composite actions cannot run standalone, so changes should be validated against a real workflow. Reference your fork's branch from a test repo:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: <your-username>/oss-actions/npm-license-validator@<your-branch>
        with:
          forbidden_licenses: 'GPL-3.0;AGPL-3.0'
```

Please verify:

- The action runs end-to-end against a real project in the relevant language.
- Forbidden-license detection still fails the build when it should.
- No new warnings from `actionlint` / `shellcheck`.

## Pull request expectations

- Keep changes minimal and scoped to one concern.
- Update the action's `README.md` when inputs, outputs, or behavior change.
- Call out breaking changes explicitly in the PR description — they require a major version bump.
- Release tagging and the moving `v1` alias are managed by maintainers.

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.
