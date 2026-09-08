#!/usr/bin/env python3
"""Ad-hoc sign a macOS application bundle from the inside out."""

import os
from pathlib import Path
import subprocess


APP = Path(os.environ["APP"]).resolve()
BUNDLE_SUFFIXES = {
    ".appex",
    ".app",
    ".bundle",
    ".framework",
    ".plugin",
    ".qlgenerator",
    ".xpc",
}


def is_macho(path: Path) -> bool:
    if not path.is_file() or path.is_symlink():
        return False
    result = subprocess.run(
        ["file", "-b", str(path)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return "Mach-O" in result.stdout


def sign(path: Path) -> None:
    subprocess.run(
        ["codesign", "--force", "--sign", "-", "--timestamp=none", str(path)],
        check=True,
    )


def depth(path: Path) -> int:
    return len(path.parts)


if not APP.is_dir() or APP.suffix != ".app":
    raise SystemExit(f"APP is not an application bundle: {APP}")

main_executable = APP / "Contents" / "MacOS" / "slideit"
if not is_macho(main_executable):
    raise SystemExit(f"Main executable is missing or not Mach-O: {main_executable}")

# Sign all nested code first, including nonstandard and versioned dylib names.
# Exclude the main executable explicitly: it can have the same path depth as a
# Frameworks dylib, making a depth-only sort nondeterministic.
machos = (
    path
    for path in APP.rglob("*")
    if path != main_executable and is_macho(path)
)
for item in sorted(machos, key=lambda path: (depth(path), str(path)), reverse=True):
    sign(item)

# Seal nested code bundles after their contents, then seal the outer app last.
bundles = (
    path
    for path in APP.rglob("*")
    if path.is_dir() and not path.is_symlink() and path.suffix.lower() in BUNDLE_SUFFIXES
)
for item in sorted(bundles, key=lambda path: (depth(path), str(path)), reverse=True):
    sign(item)

# Sign the application executable only after every nested dylib/plugin/framework.
sign(main_executable)

# The outer application seal must always be last.
sign(APP)
