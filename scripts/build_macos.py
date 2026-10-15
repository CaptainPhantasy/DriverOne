#!/usr/bin/env python3
"""Build the Mac helper from source without replacing an existing executable."""
import argparse
import os
from pathlib import Path
import platform
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=root / "gui-system-builder/scripts/gui-macos")
    args = parser.parse_args()
    output = args.output.expanduser().absolute()
    if platform.system() != "Darwin":
        parser.error("Build this helper on a Mac with Xcode command-line tools.")
    if output.exists() or output.is_symlink():
        parser.error("Output already exists; preserve it and choose a new --output path.")
    if not output.parent.is_dir():
        parser.error("The output directory must already exist.")
    source = root / "gui-system-builder/scripts/mac_gui.swift"
    with tempfile.TemporaryDirectory(prefix=".driverone-build-", dir=output.parent) as temporary:
        work = Path(temporary)
        slices = []
        for architecture in ("arm64", "x86_64"):
            binary = work / architecture
            subprocess.run(["/usr/bin/xcrun", "swiftc", "-O", "-parse-as-library",
                            "-swift-version", "5", "-target", architecture + "-apple-macosx14.0",
                            str(source), "-o", str(binary)], check=True)
            slices.append(binary)
        combined = work / "gui-macos"
        subprocess.run(["/usr/bin/lipo", "-create", *map(str, slices), "-output", str(combined)], check=True)
        observed = subprocess.run(["/usr/bin/lipo", "-archs", str(combined)], check=True,
                                  capture_output=True, text=True).stdout.split()
        if set(observed) != {"arm64", "x86_64"}:
            raise RuntimeError("The combined executable is missing a required architecture.")
        combined.chmod(0o755)
        # Exclusive creation keeps a file created by another process intact.
        os.link(combined, output)
    print("Built " + str(output) + " (Apple Silicon and Intel).")
    print("Compilation is complete. Verify the intended app workflow separately.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
