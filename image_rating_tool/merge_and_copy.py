#!/usr/bin/env python3
"""
Script to:
1. Merge ratings.csv with train_v4.csv (UHD-IQA training metadata)
2. Copy images from uploads folder to training folder
"""

import csv
import shutil
import os
from pathlib import Path

# Define paths
RATINGS_CSV = "/Users/macminiai/VSCODE_Projects/image_rating_tool/results/ratings.csv"
TARGET_CSV = "/Users/macminiai/VSCODE_Projects/BestPhotos/UIQA/csvfiles/train_v4.csv"
SOURCE_IMAGES = "/Users/macminiai/VSCODE_Projects/image_rating_tool/uploads"
TARGET_IMAGES = "/Users/macminiai/VSCODE_Projects/BestPhotos/UHD-IQA/challenge/training"
DELETED_IMAGES = "/Users/macminiai/VSCODE_Projects/image_rating_tool/deleted_images"
IMAGE_NAME_MAX = 10000


def read_csv_to_dict(filepath):
    """Read CSV file and return as list of dicts"""
    with open(filepath, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return list(reader)


def write_csv_from_dict(filepath, data, fieldnames):
    """Write CSV file from list of dicts"""
    with open(filepath, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)


def is_image_name_over_limit(image_name, max_value):
    """Return True when image_name's numeric part is over max_value."""
    base_name = os.path.splitext(image_name)[0]
    try:
        return int(base_name) > max_value
    except ValueError:
        return False


def list_image_names(folder_path):
    """List image filenames in folder using supported extensions."""
    p = Path(folder_path)
    if not p.exists():
        return set()
    files = (
        list(p.glob("*.jpg"))
        + list(p.glob("*.jpeg"))
        + list(p.glob("*.png"))
        + list(p.glob("*.webp"))
    )
    return {f.name for f in files}


def merge_csv_files():
    """Merge ratings from ratings.csv into train_v4.csv"""
    print("=" * 60)
    print("Step 1: Merging CSV files")
    print("=" * 60)

    print(f"\nReading ratings from: {RATINGS_CSV}")
    ratings_data = read_csv_to_dict(RATINGS_CSV)
    print(f"  - Found {len(ratings_data)} ratings")

    # Rule 1: deleted_images should be removed from ratings.csv
    deleted_image_names = list_image_names(DELETED_IMAGES)
    if deleted_image_names:
        before = len(ratings_data)
        ratings_data = [row for row in ratings_data if row["image_name"] not in deleted_image_names]
        removed_by_deleted_folder = before - len(ratings_data)
        if removed_by_deleted_folder:
            print(f"  - Removed {removed_by_deleted_folder} ratings found in deleted_images/")
    else:
        removed_by_deleted_folder = 0

    # Rule 2: every uploads image should exist in ratings.csv
    upload_image_names = list_image_names(SOURCE_IMAGES)
    ratings_by_name = {row["image_name"]: row for row in ratings_data}
    missing_upload_rows = []
    for image_name in sorted(upload_image_names):
        if image_name not in ratings_by_name:
            missing_upload_rows.append({"image_name": image_name, "quality_mos": ""})
    if missing_upload_rows:
        ratings_data.extend(missing_upload_rows)
        print(f"  - Added {len(missing_upload_rows)} uploads into ratings.csv (empty quality_mos)")

    # Persist synchronized ratings.csv before merging to target.
    ratings_backup_path = RATINGS_CSV + ".backup"
    print(f"\n  Creating backup: {ratings_backup_path}")
    shutil.copy2(RATINGS_CSV, ratings_backup_path)
    print(f"  Saving synchronized ratings CSV to: {RATINGS_CSV}")
    write_csv_from_dict(RATINGS_CSV, ratings_data, ["image_name", "quality_mos"])

    print(f"\nReading target CSV: {TARGET_CSV}")
    target_data = read_csv_to_dict(TARGET_CSV)
    print(f"  - Found {len(target_data)} existing records")
    filtered_target_data = [
        row for row in target_data if not is_image_name_over_limit(row["image_name"], IMAGE_NAME_MAX)
    ]
    deleted_from_target = len(target_data) - len(filtered_target_data)
    if deleted_from_target:
        print(f"  - Replacing {deleted_from_target} target records with image_name > {IMAGE_NAME_MAX}")
    target_data = filtered_target_data

    # Use only rated rows for target updates (skip empty quality_mos placeholders).
    valid_ratings = [row for row in ratings_data if str(row["quality_mos"]).strip()]

    # <= IMAGE_NAME_MAX: normal update/add merge
    filtered_ratings_data = [
        row for row in valid_ratings if not is_image_name_over_limit(row["image_name"], IMAGE_NAME_MAX)
    ]
    ratings_dict = {row["image_name"]: row["quality_mos"] for row in filtered_ratings_data}

    updated_count = 0
    new_count = 0

    for row in target_data:
        image_name = row["image_name"]
        if image_name in ratings_dict:
            old_value = row["quality_mos"]
            new_value = ratings_dict[image_name]
            row["quality_mos"] = new_value
            updated_count += 1
            print(f"  Updated {image_name}: {old_value} -> {new_value}")
            del ratings_dict[image_name]

    if ratings_dict:
        print(f"\n  Adding {len(ratings_dict)} new records...")
        for img_name, mos in ratings_dict.items():
            target_data.append({"image_name": img_name, "quality_mos": mos})
            print(f"  Added {img_name}: {mos}")
        new_count = len(ratings_dict)

    # Rule 3: for > IMAGE_NAME_MAX, target CSV follows ratings.csv exactly.
    ratings_over_limit = [
        row for row in valid_ratings if is_image_name_over_limit(row["image_name"], IMAGE_NAME_MAX)
    ]
    for row in ratings_over_limit:
        target_data.append({"image_name": row["image_name"], "quality_mos": row["quality_mos"]})
    if ratings_over_limit:
        print(f"  - Synced {len(ratings_over_limit)} records > {IMAGE_NAME_MAX} from ratings.csv into target")

    def sort_key(row):
        name = row["image_name"]
        base_name = os.path.splitext(name)[0]
        try:
            return (0, int(base_name))
        except ValueError:
            return (1, base_name)

    target_data.sort(key=sort_key)

    backup_path = TARGET_CSV + ".backup"
    print(f"\n  Creating backup: {backup_path}")
    shutil.copy2(TARGET_CSV, backup_path)

    print(f"\n  Saving updated CSV to: {TARGET_CSV}")
    write_csv_from_dict(TARGET_CSV, target_data, ["image_name", "quality_mos"])

    print(f"\n✓ CSV merge complete!")
    print(f"  - Removed from ratings.csv via deleted_images: {removed_by_deleted_folder}")
    print(f"  - Added to ratings.csv from uploads: {len(missing_upload_rows)}")
    print(f"  - Deleted from target CSV (> {IMAGE_NAME_MAX}): {deleted_from_target}")
    print(f"  - Synced to target CSV from ratings (> {IMAGE_NAME_MAX}): {len(ratings_over_limit)}")
    print(f"  - Updated records: {updated_count}")
    print(f"  - New records: {new_count}")
    print(f"  - Total records: {len(target_data)}")

    return updated_count, new_count


def copy_images():
    """Copy images from uploads folder to training folder"""
    print("\n" + "=" * 60)
    print("Step 2: Copying images")
    print("=" * 60)

    target_path = Path(TARGET_IMAGES)
    if not target_path.exists():
        print(f"\n  Creating target directory: {TARGET_IMAGES}")
        target_path.mkdir(parents=True, exist_ok=True)

    source_path = Path(SOURCE_IMAGES)

    image_files = (
        list(source_path.glob("*.jpg"))
        + list(source_path.glob("*.jpeg"))
        + list(source_path.glob("*.png"))
        + list(source_path.glob("*.webp"))
    )

    if not image_files:
        print(f"\n  No images found in {SOURCE_IMAGES}")
        return 0

    print(f"\n  Found {len(image_files)} images to copy")

    copied_count = 0
    skipped_count = 0

    for img_file in image_files:
        target_file = target_path / img_file.name

        if target_file.exists():
            print(f"  Skipped {img_file.name} (already exists)")
            skipped_count += 1
        else:
            shutil.copy2(img_file, target_file)
            print(f"  Copied {img_file.name}")
            copied_count += 1

    print(f"\n✓ Image copy complete!")
    print(f"  - Copied: {copied_count}")
    print(f"  - Skipped (already exist): {skipped_count}")
    print(f"  - Total: {len(image_files)}")

    return copied_count


def main():
    """Main execution function"""
    print("\n" + "=" * 60)
    print("Image Rating Tool - Merge and Copy Script")
    print("=" * 60)

    try:
        updated, new = merge_csv_files()
        copied = copy_images()

        print("\n" + "=" * 60)
        print("SUMMARY")
        print("=" * 60)
        print(f"✓ CSV Records Updated: {updated}")
        print(f"✓ CSV Records Added: {new}")
        print(f"✓ Images Copied: {copied}")
        print("\nAll operations completed successfully!")

    except FileNotFoundError as e:
        print(f"\n✗ Error: File not found - {e}")
        print("  Please check that all paths are correct.")
        return 1
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback

        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
