#!/usr/bin/env bash
# Exercises the forbidden-license matching in both validators.
#
# The block under test is extracted from the shipped action.yml rather than
# restated here: a copy would keep passing after the action it claims to cover
# had changed. Extraction means this test fails loudly if the block is renamed
# or reshaped, which is the correct outcome — it can no longer prove anything.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0
fail=0

# extract_block pulls the matching loop out of an action.yml and de-indents it
# to column 0 so it can be sourced as a standalone script.
extract_block() {
  local action="$1" out="$2"
  python3 - "$action" "$out" <<'PY'
import sys

action, out = sys.argv[1], sys.argv[2]
s = open(action).read()
start = s.index('        if [[ "$LICENSES_FOUND" != "[]"')
end = s.index('        echo "forbidden_found=', start)
block = s[start:end]
block = "\n".join(l[8:] if l.startswith("        ") else l for l in block.split("\n"))
open(out, "w").write(block)
PY
}

# run_case evaluates the extracted block for one (found, forbidden) pair and
# echoes the two outputs the action derives from it.
#
# The variables below look unused here because the block that reads and writes
# them is sourced at runtime, so shellcheck cannot see the use.
# shellcheck disable=SC2034
run_case() {
  local block="$1"
  LICENSES_FOUND="$2"
  FORBIDDEN_LICENSES="$3"
  local FORBIDDEN_ARRAY FORBIDDEN_FOUND FORBIDDEN_DETAILS FORBIDDEN_LIST
  IFS=';' read -ra FORBIDDEN_ARRAY <<< "$FORBIDDEN_LICENSES"
  FORBIDDEN_FOUND=false
  FORBIDDEN_DETAILS=""
  FORBIDDEN_LIST=""
  # shellcheck source=/dev/null
  source "$block"
  echo "$FORBIDDEN_FOUND|$FORBIDDEN_DETAILS"
}

check() { # block desc found forbidden want_found want_details
  local block="$1" desc="$2" got
  got="$(run_case "$block" "$3" "$4")"
  if [[ "$got" == "$5|$6" ]]; then
    pass=$((pass + 1))
    echo "  PASS  $desc"
  else
    fail=$((fail + 1))
    echo "  FAIL  $desc -> got '$got', want '$5|$6'"
  fi
}

for action in go-license-validator npm-license-validator; do
  echo "== $action"
  block="$work/$action.sh"
  mkdir -p "$(dirname "$block")"
  extract_block "$repo_root/$action/action.yml" "$block"

  # SPDX identifiers carry a version suffix, so a family entry has to match the
  # whole family. This is the case the exact-match implementation missed: with
  # FORBIDDEN_LICENSES="GPL;AGPL" it blocked only a license literally named
  # "GPL", which no real dependency is.
  check "$block" "GPL-3.0-only is caught by GPL" '["GPL-3.0-only"]' 'GPL;AGPL' true 'GPL'
  check "$block" "AGPL-3.0 is caught by AGPL" '["AGPL-3.0"]' 'GPL;AGPL' true 'AGPL'

  # Different licenses that merely contain the same letters must not be caught
  # by a family entry — a project blocking GPL has not thereby blocked LGPL.
  check "$block" "AGPL-3.0 is not caught by GPL" '["AGPL-3.0"]' 'GPL' false ''
  check "$block" "LGPL is not caught by GPL" '["LGPL-3.0-or-later"]' 'GPL;AGPL' false ''
  check "$block" "LGPL is caught when listed" '["LGPL-3.0-or-later"]' 'LGPL' true 'LGPL'

  # A found value is an SPDX expression; a forbidden identifier inside a
  # composite is still present in the dependency tree.
  check "$block" "composite AND is split" '["Apache-2.0 AND GPL-2.0"]' 'GPL' true 'GPL'
  check "$block" "composite OR is split" '["BSD-3-Clause OR GPL-2.0-or-later"]' 'GPL' true 'GPL'
  check "$block" "WITH exception matches the base" '["GPL-2.0-or-later WITH GCC-exception-3.1"]' 'GPL' true 'GPL'

  # The identifiers the README documents must keep working, including against
  # the modern -only / -or-later spellings they predate.
  check "$block" "exact documented id works" '["GPL-3.0"]' 'GPL-3.0' true 'GPL-3.0'
  check "$block" "documented id matches -only form" '["GPL-3.0-only"]' 'GPL-3.0' true 'GPL-3.0'

  check "$block" "permissive set passes" '["MIT","Apache-2.0","BSD-3-Clause"]' 'GPL;AGPL' false ''
  check "$block" "empty found list passes" '[]' 'GPL;AGPL' false ''
  check "$block" "matching is case-insensitive" '["gpl-3.0-only"]' 'GPL' true 'GPL'
  check "$block" "every matched family is reported" '["GPL-2.0","AGPL-3.0"]' 'GPL;AGPL' true 'GPL, AGPL'
done

echo
echo "passed=$pass failed=$fail"
[[ "$fail" -eq 0 ]]
