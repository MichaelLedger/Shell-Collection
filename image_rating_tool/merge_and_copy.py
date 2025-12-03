#!/usr/bin/env python3
"""
Script to:
1. Merge ratings.csv with uhd-iqa-training-metadata-v2.csv
2. Copy images from uploads folder to training folder
"""

import csv
import shutil
import os
from pathlib import Path

# Define paths
RATINGS_CSV = "/Users/macminiai/VSCODE_Projects/image_rating_tool/results/ratings.csv"
TARGET_CSV = "/Users/macminiai/VSCODE_Projects/BestPhotos/UIQA/csvfiles/uhd-iqa-training-metadata-v2.csv"
SOURCE_IMAGES = "/Users/macminiai/VSCODE_Projects/image_rating_tool/uploads"
TARGET_IMAGES = "/Users/macminiai/VSCODE_Projects/BestPhotos/UHD-IQA/challenge/training"

def read_csv_to_dict(filepath):
    """Read CSV file and return as list of dicts"""
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        return list(reader)

def write_csv_from_dict(filepath, data, fieldnames):
    """Write CSV file from list of dicts"""
    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)

def merge_csv_files():
    """Merge ratings from ratings.csv into uhd-iqa-training-metadata-v2.csv"""
    print("=" * 60)
    print("Step 1: Merging CSV files")
    print("=" * 60)
    
    # Read both CSV files
    print(f"\nReading ratings from: {RATINGS_CSV}")
    ratings_data = read_csv_to_dict(RATINGS_CSV)
    print(f"  - Found {len(ratings_data)} ratings")
    
    print(f"\nReading target CSV: {TARGET_CSV}")
    target_data = read_csv_to_dict(TARGET_CSV)
    print(f"  - Found {len(target_data)} existing records")
    
    # Create a dictionary from ratings for quick lookup
    ratings_dict = {row['image_name']: row['quality_mos'] for row in ratings_data}
    
    # Track statistics
    updated_count = 0
    new_count = 0
    
    # Update existing records
    for row in target_data:
        image_name = row['image_name']
        if image_name in ratings_dict:
            old_value = row['quality_mos']
            new_value = ratings_dict[image_name]
            row['quality_mos'] = new_value
            updated_count += 1
            print(f"  Updated {image_name}: {old_value} -> {new_value}")
            # Remove from dict so we know what's been processed
            del ratings_dict[image_name]
    
    # Add new records that weren't in the target CSV
    if ratings_dict:
        print(f"\n  Adding {len(ratings_dict)} new records...")
        for img_name, mos in ratings_dict.items():
            target_data.append({'image_name': img_name, 'quality_mos': mos})
            print(f"  Added {img_name}: {mos}")
        new_count = len(ratings_dict)
    
    # Sort by image_name for consistency (extract numeric part if present)
    def sort_key(row):
        name = row['image_name']
        # Try to extract numeric part for proper sorting
        try:
            return int(name.replace('.jpg', '').replace('.png', ''))
        except:
            return name
    
    target_data.sort(key=sort_key)
    
    # Create backup of original file
    backup_path = TARGET_CSV + ".backup"
    print(f"\n  Creating backup: {backup_path}")
    shutil.copy2(TARGET_CSV, backup_path)
    
    # Save updated CSV
    print(f"\n  Saving updated CSV to: {TARGET_CSV}")
    write_csv_from_dict(TARGET_CSV, target_data, ['image_name', 'quality_mos'])
    
    print(f"\n✓ CSV merge complete!")
    print(f"  - Updated records: {updated_count}")
    print(f"  - New records: {new_count}")
    print(f"  - Total records: {len(target_data)}")
    
    return updated_count, new_count

def copy_images():
    """Copy images from uploads folder to training folder"""
    print("\n" + "=" * 60)
    print("Step 2: Copying images")
    print("=" * 60)
    
    # Create target directory if it doesn't exist
    target_path = Path(TARGET_IMAGES)
    if not target_path.exists():
        print(f"\n  Creating target directory: {TARGET_IMAGES}")
        target_path.mkdir(parents=True, exist_ok=True)
    
    source_path = Path(SOURCE_IMAGES)
    
    # Get list of images to copy
    image_files = list(source_path.glob("*.jpg")) + list(source_path.glob("*.png"))
    
    if not image_files:
        print(f"\n  No images found in {SOURCE_IMAGES}")
        return 0
    
    print(f"\n  Found {len(image_files)} images to copy")
    
    copied_count = 0
    skipped_count = 0
    
    for img_file in image_files:
        target_file = target_path / img_file.name
        
        # Check if file already exists
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
        # Step 1: Merge CSV files
        updated, new = merge_csv_files()
        
        # Step 2: Copy images
        copied = copy_images()
        
        # Summary
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
