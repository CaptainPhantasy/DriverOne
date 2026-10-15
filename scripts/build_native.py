#!/usr/bin/env python3
"""Build the local ZCode helper using Apple's installed compiler; no downloads."""
from __future__ import annotations
import argparse
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument('--universal', action='store_true', help='Build Apple Silicon and Intel slices')
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        parser.error('This native helper must be built on macOS.')
    native = {'arm64': 'arm64', 'x86_64': 'x86_64'}.get(platform.machine())
    if native is None:
        parser.error('This build supports Apple Silicon and Intel Macs.')
    build_dir = ROOT / 'build'
    build_dir.mkdir(exist_ok=True)
    cache = build_dir / 'swift-module-cache'
    destination = ROOT / 'scripts/zcode-macos'
    architectures = ['arm64', 'x86_64'] if args.universal else [native]
    with tempfile.TemporaryDirectory(prefix='zdrive-', dir=build_dir) as raw:
        temporary = Path(raw)
        slices = []
        for architecture in architectures:
            output = temporary / ('zcode-macos-' + architecture)
            subprocess.run([
                '/usr/bin/xcrun', 'swiftc', '-O', '-parse-as-library',
                '-swift-version', '5', '-target', architecture + '-apple-macosx14.0',
                '-module-cache-path', str(cache), str(ROOT / 'scripts/mac_gui.swift'),
                '-o', str(output),
            ], check=True)
            slices.append(output)
        result = temporary / 'zcode-macos'
        if args.universal:
            subprocess.run(['/usr/bin/xcrun', 'lipo', '-create', *map(str, slices), '-output', str(result)], check=True)
        else:
            slices[0].rename(result)
        result.chmod(0o755)
        result.replace(destination)
    print('Built ' + str(destination) + ' for ' + ', '.join(architectures))


if __name__ == '__main__':
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        print('Build failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
