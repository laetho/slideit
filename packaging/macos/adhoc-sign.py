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

# Sign all code by content, including nonstandard and versioned dylib names.
machos = (path for path in APP.rglob("*") if is_macho(path))
for item in sorted(machos, key=depth, reverse=True):
    sign(item)

# Seal nested code bundles after their contents, then seal the outer app last.
bundles = (
    path
    for path in APP.rglob("*")
    if path.is_dir() and not path.is_symlink() and path.suffix.lower() in BUNDLE_SUFFIXES
)
for item in sorted(bundles, key=depth, reverse=True):
    sign(item)

sign(APP)
