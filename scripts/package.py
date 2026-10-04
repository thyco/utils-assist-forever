#!/usr/bin/env python3
"""Build an installable addon ZIP from the manifest's source files."""

from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "UtilsAssistForever"
MANIFEST = ADDON / "UtilsAssistForever.toc"


def main():
    manifest = MANIFEST.read_text()
    version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", manifest, re.MULTILINE)
    if not version:
        raise SystemExit("Manifest must contain a semantic version")

    files = [MANIFEST]
    for line in manifest.splitlines():
        entry = line.strip()
        if entry and not entry.startswith("#"):
            source = (ADDON / entry).resolve()
            if not source.is_relative_to(ADDON) or not source.is_file():
                raise SystemExit(f"Invalid or missing manifest entry: {entry}")
            files.append(source)

    for asset in sorted((ADDON / "Media").rglob("*")):
        if asset.is_file():
            source = asset.resolve()
            if not source.is_relative_to(ADDON):
                raise SystemExit(f"Asset is outside the addon directory: {asset}")
            files.append(source)

    # Ship the bundled library's attribution and license files as well as Lua.
    for asset in sorted((ADDON / "Libs").rglob("*")):
        if asset.is_file():
            source = asset.resolve()
            if not source.is_relative_to(ADDON):
                raise SystemExit(f"Library asset is outside the addon directory: {asset}")
            if source not in files:
                files.append(source)

    license_file = ROOT / "LICENSE.txt"
    if not license_file.is_file():
        raise SystemExit("Missing GPL-3.0 license")

    destination = ROOT / "dist" / f"UtilsAssistForever-{version[1]}.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for source in files:
            archive.write(source, source.relative_to(ROOT))
        archive.write(license_file, "UtilsAssistForever/LICENSE.txt")

    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None or len(archive.namelist()) != len(files) + 1:
            raise SystemExit("Archive verification failed")

    print(f"Built {destination} ({len(files) + 1} files)")


if __name__ == "__main__":
    main()
