# Image EXIF Adjuster — Design

Date: 2026-07-29

## Goal

Batch-update EXIF create dates and GPS for all photos in a given directory (e.g. `beach`), in place, using ExifTool.

## Decisions

| Topic | Choice |
|-------|--------|
| Engine | Bash + ExifTool |
| Write mode | In place (`-overwrite_original`); no backups |
| Date time | Input date + sequential times across the day |
| Formats | `.jpg` / `.jpeg` / `.heic` / `.heif` / `.png` (case-insensitive) |
| Recursion | Top-level only (no subfolders) |
| Filesystem | Sync `FileModifyDate` to the same datetime |

## CLI

```bash
./adjust_exif.sh <dir> <date> <lat> <lon> [--dry-run] [--start-time HH:MM] [--step-minutes N]
```

Example:

```bash
./adjust_exif.sh ./beach 2024-06-30 43.4835416 -1.56304953
```

Defaults: `--start-time 09:00`, `--step-minutes 2`.

## Processing

1. Validate args, directory, date (`YYYY-MM-DD`), numeric lat/lon, and `exiftool` on PATH.
2. Collect matching files in the directory (non-recursive), sort by filename.
3. For file index `i` (0-based): datetime = `date` + `start-time` + `i * step-minutes`.
4. Write tags:
   - `DateTimeOriginal`, `CreateDate`, `ModifyDate`
   - `GPSLatitude`, `GPSLongitude`, `GPSLatitudeRef`, `GPSLongitudeRef` (refs from sign)
   - `FileModifyDate`
5. Print per-file result; end with updated / skipped / failed counts.

## Layout

```
image_exif_tool/
├── adjust_exif.sh
├── README.md
└── docs/superpowers/specs/2026-07-29-image-exif-tool-design.md
```

## Out of scope

- Recursive subfolders
- WebP/TIFF
- Backups or alternate output directories
- Removing other EXIF fields
