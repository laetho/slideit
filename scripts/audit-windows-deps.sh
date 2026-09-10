#!/usr/bin/env bash
# Verify that every DLL imported by the Windows executable and by every bundled
# DLL is either present in the staging directory or provided by Windows itself.
#
# This catches missing-DLL regressions in the portable Windows release,
# including transitive Qt dependencies (e.g. ICU, zlib) that windeployqt is
# expected to bundle but that the executable does not import directly.
#
# Intended to run inside the MSYS2 UCRT64 shell used by the Windows CI job,
# where /c/Windows/System32 is the mount of C:\Windows\System32 and objdump is
# provided by mingw-w64-ucrt-x86_64-binutils.
#
# Usage: audit-windows-deps.sh <staging-dir> <binary-path>
set -euo pipefail

stage="${1:?usage: audit-windows-deps.sh <staging-dir> <binary-path>}"
binary="${2:?usage: audit-windows-deps.sh <staging-dir> <binary-path>}"

# Overridable for tests; defaults to the MSYS2 mount of C:\Windows\System32.
system32="${SYSTEM32_DIR:-/c/Windows/System32}"

[[ -d "$stage" ]] || { echo "::error::staging directory not found: $stage" >&2; exit 1; }
[[ -f "$binary" ]] || { echo "::error::binary not found: $binary" >&2; exit 1; }

found=0

# Audit the executable itself plus every bundled DLL. The executable is passed
# explicitly; the find covers the Qt DLLs windeployqt placed in the staging
# root (plugins in subdirectories are loaded dynamically, not imported).
while IFS= read -r -d '' f; do
  while IFS= read -r dll; do
    found=$((found + 1))
    if [[ -f "$stage/$dll" || -f "$system32/$dll" ]]; then
      continue
    fi
    echo "::error::missing runtime DLL: $dll (imported by $(basename "$f"))" >&2
    exit 1
  done < <(objdump -p "$f" | awk '/DLL Name/ {print $3}' | sort -u)
done < <(printf '%s\0' "$binary"; find "$stage" -type f -name '*.dll' -print0)

# Guard against a silent no-op if objdump's import-table output format changes.
if [[ "$found" -eq 0 ]]; then
  echo "::error::dependency audit found no DLL imports; objdump output format may have changed" >&2
  exit 1
fi
