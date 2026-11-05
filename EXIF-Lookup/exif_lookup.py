#!/usr/bin/env python3
"""Read image metadata with ExifTool; never modify source images."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def thumbnail_dimensions(tool, path):
    """Read dimensions from the JPEG referenced by IFD1, without creating files."""
    extracted = subprocess.run(
        [tool, "-b", "-IFD1:ThumbnailImage", str(path)], capture_output=True,
    )
    if extracted.returncode:
        raise RuntimeError(extracted.stderr.decode("utf-8", errors="replace").strip())
    if not extracted.stdout:
        return {"IFD1Thumbnail:Status": "No embedded IFD1 thumbnail"}
    inspected = subprocess.run(
        [tool, "-j", "-n", "-File:ImageWidth", "-File:ImageHeight", "-"],
        input=extracted.stdout, capture_output=True,
    )
    if inspected.returncode:
        raise RuntimeError(inspected.stderr.decode("utf-8", errors="replace").strip())
    tags = json.loads(inspected.stdout)[0]
    if "ImageWidth" not in tags or "ImageHeight" not in tags:
        raise RuntimeError("Embedded thumbnail dimensions could not be read")
    return {
        "IFD1Thumbnail:PixelWidth": tags["ImageWidth"],
        "IFD1Thumbnail:PixelHeight": tags["ImageHeight"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path, help="Image file(s) to inspect")
    parser.add_argument(
        "--group", choices=("all", "ifd0", "ifd1", "exif", "sony"), default="all",
        help="Metadata group: all (default), main image, thumbnail, EXIF, or Sony",
    )
    parser.add_argument("--numeric", action="store_true", help="Show numeric codes instead of friendly labels")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of text")
    parser.add_argument("--unknown", action="store_true", help="Include unknown tags (may contain opaque maker data)")
    args = parser.parse_args()

    tool = shutil.which("exiftool")
    if not tool:
        for candidate in ("/opt/homebrew/bin/exiftool", "/usr/local/bin/exiftool"):
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                tool = candidate
                break
    if not tool:
        parser.exit(2, "ExifTool not found. Install with: brew install exiftool\n")

    paths = [p.expanduser().resolve() for p in args.images]
    for path in paths:
        if not path.is_file():
            parser.error(f"Image file not found: {path}")

    command = [tool, "-a", "-G1", "-s"]
    if args.numeric:
        command.append("-n")
    if args.json:
        command.append("-j")
    if args.unknown:
        command.append("-u")
    groups = {"ifd0": "-IFD0:all", "ifd1": "-IFD1:all", "exif": "-EXIF:all", "sony": "-Sony:all"}
    if args.group != "all":
        command.append(groups[args.group])
    # Absolute paths avoid treating dash-prefixed filenames as ExifTool options.
    try:
        json_rows = []
        status = 0
        for path in paths:
            result = subprocess.run(command + [str(path)], capture_output=True)
            if result.stderr:
                sys.stderr.write(result.stderr.decode("utf-8", errors="replace"))
            status = max(status, result.returncode)
            extra = {}
            if not result.returncode and args.group in ("all", "ifd1", "exif"):
                try:
                    extra = thumbnail_dimensions(tool, path)
                except (RuntimeError, ValueError, KeyError) as error:
                    extra = {"IFD1Thumbnail:Error": str(error)}
                    status = max(status, 1)
            if args.json:
                rows = json.loads(result.stdout) if result.stdout.strip() else []
                for row in rows:
                    row.update(extra)
                json_rows.extend(rows)
            else:
                if len(paths) > 1:
                    print(f"======== {path}")
                print(result.stdout.decode("utf-8", errors="replace"), end="")
                for key, value in extra.items():
                    group, tag = key.split(":", 1)
                    print(f"[{group}] {tag:<31} : {value}")
        if args.json:
            print(json.dumps(json_rows, ensure_ascii=False, indent=2))
        return status
    except (OSError, ValueError) as error:
        parser.exit(2, f"Could not inspect image metadata: {error}\n")


if __name__ == "__main__":
    sys.exit(main())
