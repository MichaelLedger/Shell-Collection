Manual Image Rating Tool

## Run Locally
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

## Notes
- Thresholds are computed from dataset/train.csv at startup.
- Thresholds are cached to results/thresholds.json. Delete this file to force recompute on next start.
- Upload images, enter a float score per image, click Save ratings.
- Images are saved under uploads as numeric files starting at 10000.
- CSV is saved to results/ratings.csv (image_name,quality_mos).

## Merge and Copy Script

The `merge_and_copy.py` script automates two tasks:

### Task 1: Merge CSV Files
Merges ratings from `results/ratings.csv` into the main training metadata file:
- **Source**: `results/ratings.csv`
- **Target**: `/Users/macminiai/VSCODE_Projects/BestPhotos/UIQA/csvfiles/uhd-iqa-training-metadata-v2.csv`
- Updates existing records if image_name matches
- Adds new records for new images
- Creates backup file before modifying (`.backup` extension)

### Task 2: Copy Images
Copies all rated images to the training dataset folder:
- **Source**: `uploads/`
- **Target**: `/Users/macminiai/VSCODE_Projects/BestPhotos/UHD-IQA/challenge/training/`
- Copies all .jpg and .png files
- Skips files that already exist in target

### Usage
```bash
python3 merge_and_copy.py
```

### Features
- Uses only Python standard library (no external dependencies)
- Detailed progress output with statistics
- Creates automatic backup of CSV before modification
- Smart sorting of records by image number
- Safe file copying (won't overwrite existing files)

