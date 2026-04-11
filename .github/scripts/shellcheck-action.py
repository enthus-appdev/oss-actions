#!/usr/bin/env python3
"""Lint shell code inside GitHub Actions composite action.yml files.

Extracts every `run:` block from each specified action.yml file, writes it to
a temporary script with a bash shebang and `set -euo pipefail`, and runs
shellcheck against it. Exits non-zero if any block has findings at or above
the configured severity.

actionlint does not handle composite action definitions — it treats them as
malformed workflow files — so this helper fills that gap.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
import tempfile

import yaml

# GitHub Actions expression: ${{ ... }}.
_EXPR_RE = re.compile(r"\$\{\{\s*([^}]+?)\s*\}\}")


def _sanitize(shell: str) -> str:
    """Replace ${{ expr }} with a shell-safe placeholder identifier.

    Composite actions should route inputs through `env:` blocks instead of
    interpolating expressions directly, but this is a safety net so the linter
    doesn't blow up on legacy code.
    """
    return _EXPR_RE.sub(
        lambda m: f"$_GH_{re.sub(r'\W', '_', m.group(1))}",
        shell,
    )


def _lint_file(path: pathlib.Path, severity: str) -> int:
    """Shellcheck every run: block in the given action.yml file.

    Returns the number of blocks with findings.
    """
    try:
        data = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        print(f"{path}: YAML parse error: {exc}", file=sys.stderr)
        return 1

    runs = (data or {}).get("runs") or {}
    if runs.get("using") != "composite":
        print(f"{path}: not a composite action, skipping")
        return 0

    steps = runs.get("steps") or []
    checked = 0
    failing = 0
    for index, step in enumerate(steps):
        run = step.get("run")
        if not run:
            continue
        checked += 1
        shell = step.get("shell", "bash")
        name = step.get("name", f"step-{index}")

        with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False) as handle:
            handle.write("#!/usr/bin/env bash\n")
            handle.write("set -euo pipefail\n")
            handle.write(_sanitize(run))
            tmp_path = handle.name

        try:
            result = subprocess.run(
                [
                    "shellcheck",
                    f"--shell={shell}",
                    f"--severity={severity}",
                    "--color=never",
                    tmp_path,
                ],
                capture_output=True,
                text=True,
                check=False,
            )
        finally:
            pathlib.Path(tmp_path).unlink(missing_ok=True)

        if result.returncode != 0:
            failing += 1
            label = f"{path}:{name}"
            print(f"\n=== {label} ===")
            print((result.stdout + result.stderr).replace(tmp_path, label))

    print(f"{path}: {checked} run: block(s) checked, {failing} failing")
    return failing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "files",
        nargs="+",
        type=pathlib.Path,
        help="Composite action.yml files to lint",
    )
    parser.add_argument(
        "--severity",
        default="info",
        choices=["style", "info", "warning", "error"],
        help="Minimum shellcheck severity to report (default: info)",
    )
    args = parser.parse_args()

    total_failing = 0
    for path in args.files:
        if not path.is_file():
            print(f"{path}: not found", file=sys.stderr)
            total_failing += 1
            continue
        total_failing += _lint_file(path, args.severity)

    return 1 if total_failing else 0


if __name__ == "__main__":
    raise SystemExit(main())
