# Image EXIF Tool

Batch-set create dates and a shared GPS location for photos in a folder (in place).

## Requirements

```bash
brew install exiftool
```

## Usage

```bash
./adjust_exif.sh <dir> <date> <lat> <lon> [options]
```

| Argument | Example | Meaning |
|----------|---------|---------|
| `dir` | `./beach` | Folder of photos (top-level only) |
| `date` | `2024-06-30` | Create date (`YYYY-MM-DD`) |
| `lat` | `43.4835416` | GPS latitude |
| `lon` | `-1.56304953` | GPS longitude |

**Options**

| Option | Default | Meaning |
|--------|---------|---------|
| `--dry-run` | off | Print planned changes only |
| `--start-time HH:MM` | `09:00` | Time of first photo |
| `--step-minutes N` | `2` | Minutes between successive photos |

Times are assigned after sorting filenames A→Z, so photos get distinct timestamps across the day (e.g. `09:00`, `09:02`, `09:04`…).

## Examples

```bash
# Preview
./adjust_exif.sh ./beach 2024-06-30 43.4835416 -1.56304953 --dry-run

# Apply in place
./adjust_exif.sh ./beach 2024-06-30 43.4835416 -1.56304953

# Custom spacing
./adjust_exif.sh ./beach 2024-06-30 43.4835416 -1.56304953 --start-time 10:30 --step-minutes 3
```

## What it writes

For each `.jpg` / `.jpeg` / `.heic` / `.heif` / `.png` in the directory (not subfolders):

- `DateTimeOriginal`, `CreateDate`, `ModifyDate`
- `GPSLatitude` / `GPSLongitude` (+ N/S/E/W refs)
- `FileModifyDate` (filesystem mtime)

Originals are overwritten (`-overwrite_original`). No backups.

## Verify

```bash
exiftool -DateTimeOriginal -CreateDate -GPSLatitude -GPSLongitude -n -FileModifyDate beach/*
```

## Issues
```
fix it: ✘ Bottle exiftool (13.55)
Error: A `brew install exiftool` process has already locked /Users/gavinxiang/Library/Caches/Homebrew/downloads/f2432d15ce30c9f8374236471b73e3db902d0039313a5086ccbd31b0d6600b34--exiftool--13.55.arm64_tahoe.bottle.tar.gz.incomplete.
Please wait for it to finish or terminate it to continue.
```
Resolution:
```
# Kill stuck brew install tree
kill 90407 89213 89202 2>/dev/null || true
sleep 1
# Also kill any remaining brew install exiftool / related curl
pkill -f 'brew.rb install exiftool' 2>/dev/null || true
pkill -f 'exiftool--13.55.arm64_tahoe.bottle.tar.gz.incomplete' 2>/dev/null || true
sleep 1
ps aux | grep -E '[b]rew.rb install exiftool|[e]xiftool--13.55' || echo "no stuck processes"
# Clear incomplete download lock
rm -f /Users/gavinxiang/Library/Caches/Homebrew/downloads/f2432d15ce30c9f8374236471b73e3db902d0039313a5086ccbd31b0d6600b34--exiftool--13.55.arm64_tahoe.bottle.tar.gz.incomplete
rm -f /var/folders/wk/frkkcch539lc6s2dk6dw9dy80000gn/T/cursor-sandbox-cache/980f64ade943afe679b6ea2966e836cc/homebrew/downloads/f2432d15ce30c9f8374236471b73e3db902d0039313a5086ccbd31b0d6600b34--exiftool--13.55.arm64_tahoe.bottle.tar.gz.incomplete
echo "locks cleared"
brew install exiftool
exiftool -ver
which exiftool
```