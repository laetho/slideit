#!/usr/bin/env bash
# Unit tests for scripts/audit-windows-deps.sh using a mocked objdump.
#
# Run from anywhere:  bash scripts/test-packaging-audit.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
audit="$repo_root/scripts/audit-windows-deps.sh"

# Mock objdump: emit a fixed import table. When MOCK_DLLS is set (even empty)
# it is used verbatim; otherwise a representative default list is used.
objdump() {
  if [[ -z "${MOCK_DLLS+x}" ]]; then
    set -- KERNEL32.dll ADVAPI32.dll Qt6Core.dll libstdc++-6.dll
  else
    set -- ${MOCK_DLLS}
  fi
  for d in "$@"; do
    printf '  DLL Name: %s\n' "$d"
  done
}
export -f objdump

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Fake System32 mount so the audit can resolve system-provided DLLs.
mkdir -p "$tmp/system32"
for d in KERNEL32.dll ADVAPI32.dll ucrtbase.dll; do : > "$tmp/system32/$d"; done

pass=0
fail=0

check() { # check <name> <expected-exit> <cmd...>
  local name="$1" expected="$2"
  shift 2
  local got=0
  "$@" >/dev/null 2>&1 || got=$?
  if [[ "$got" -eq "$expected" ]]; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name (expected exit $expected, got $got)"
    fail=$((fail + 1))
  fi
}

# Case 1: every import resolvable (system DLLs via System32, Qt/runtime in
# the staging directory) -> pass.
mkdir -p "$tmp/stage_ok"
for d in Qt6Core.dll libstdc++-6.dll; do : > "$tmp/stage_ok/$d"; done
: > "$tmp/stage_ok/slideit.exe"
MOCK_DLLS="KERNEL32.dll ADVAPI32.dll Qt6Core.dll libstdc++-6.dll" \
  SYSTEM32_DIR="$tmp/system32" \
  check "all-resolvable passes" 0 \
  bash "$audit" "$tmp/stage_ok" "$tmp/stage_ok/slideit.exe"

# Case 2: Windows API-set contracts are resolved by the loader and need not
# exist as physical files in either the staging directory or System32.
MOCK_DLLS="KERNEL32.dll api-ms-win-crt-environment-l1-1-0.dll EXT-MS-WIN-NTUSER-WINDOW-L1-1-0.DLL" \
  SYSTEM32_DIR="$tmp/system32" \
  check "API-set contracts pass" 0 \
  bash "$audit" "$tmp/stage_ok" "$tmp/stage_ok/slideit.exe"

# Case 3: a runtime DLL missing from both the staging directory and System32
# -> fail with a missing-DLL error.
mkdir -p "$tmp/stage_missing"
for d in Qt6Core.dll; do : > "$tmp/stage_missing/$d"; done
: > "$tmp/stage_missing/slideit.exe"
MOCK_DLLS="KERNEL32.dll Qt6Core.dll libstdc++-6.dll" \
  SYSTEM32_DIR="$tmp/system32" \
  check "missing-DLL fails" 1 \
  bash "$audit" "$tmp/stage_missing" "$tmp/stage_missing/slideit.exe"

# Case 4: objdump yields no DLL names (e.g. output format changed) -> the
# zero-imports guard fails instead of silently passing.
mkdir -p "$tmp/stage_empty"
: > "$tmp/stage_empty/slideit.exe"
MOCK_DLLS="" \
  SYSTEM32_DIR="$tmp/system32" \
  check "zero-DLLs guard fails" 1 \
  bash "$audit" "$tmp/stage_empty" "$tmp/stage_empty/slideit.exe"

# Case 5: transitive dependency — a DLL bundled in the staging directory
# imports a DLL that is missing -> fail. This is the ICU/zlib scenario that
# auditing only the executable would miss.
mkdir -p "$tmp/stage_transitive"
for d in Qt6Core.dll; do : > "$tmp/stage_transitive/$d"; done
: > "$tmp/stage_transitive/slideit.exe"
: > "$tmp/stage_transitive/Qt6Core.dll"
MOCK_DLLS="KERNEL32.dll Qt6Core.dll icuuc.dll" \
  SYSTEM32_DIR="$tmp/system32" \
  check "transitive-missing-DLL fails" 1 \
  bash "$audit" "$tmp/stage_transitive" "$tmp/stage_transitive/slideit.exe"

# Case 6: missing staging directory or binary -> fail with a clear error.
check "missing-staging-dir fails" 1 \
  bash "$audit" "$tmp/does-not-exist" "$tmp/stage_ok/slideit.exe"
check "missing-binary fails" 1 \
  bash "$audit" "$tmp/stage_ok" "$tmp/does-not-exist.exe"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "All $pass tests passed."
else
  echo "$fail test(s) failed."
  exit 1
fi
