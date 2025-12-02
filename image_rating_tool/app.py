import csv
import io
import os
from pathlib import Path
from typing import Dict, List, Tuple
import pandas as pd

import gradio as gr
from PIL import Image

from thresholds import (
    compute_thresholds,
    format_ranges,
    label_score,
    save_thresholds_json,
    load_thresholds_json,
)


ROOT_DIR = Path(__file__).resolve().parent
UPLOADS_DIR = ROOT_DIR / "uploads"
RESULTS_DIR = ROOT_DIR / "results"
RATINGS_CSV = RESULTS_DIR / "ratings.csv"
THRESHOLDS_JSON = RESULTS_DIR / "thresholds.json"

# Absolute path to training CSV in the main project
TRAIN_CSV_PATH = ROOT_DIR / "train.csv"


def ensure_dirs() -> None:
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def next_numeric_filename(uploads_dir: Path, original_ext: str) -> str:
    """Return the next numeric filename (string) starting at 10000 with given extension."""
    max_id = 9999
    for p in uploads_dir.iterdir():
        if p.is_file():
            stem = p.stem
            if stem.isdigit():
                try:
                    val = int(stem)
                except ValueError:
                    continue
                if val > max_id:
                    max_id = val
    next_id = max_id + 1 if max_id >= 10000 else 10000
    ext = original_ext.lower() if original_ext else ".jpg"
    return f"{next_id}{ext}"


def save_image_with_numeric_name(image: Image.Image, original_name: str) -> str:
    """Save image to uploads/ with numeric filename preserving extension; return saved filename."""
    _, ext = os.path.splitext(original_name)
    if ext.lower() not in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}:
        ext = ".jpg"
    filename = next_numeric_filename(UPLOADS_DIR, ext)
    save_path = UPLOADS_DIR / filename
    image.save(save_path)
    return filename


def append_ratings(rows: List[Tuple[str, float]]) -> None:
    """Append rows to ratings.csv; header created if missing."""
    new_file = not RATINGS_CSV.exists()
    with open(RATINGS_CSV, "a", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        if new_file:
            writer.writerow(["image_name", "quality_mos"])
        for name, score in rows:
            writer.writerow([name, f"{float(score):.4f}"])


def build_download_csv() -> str:
    """Return path to the CSV file for download."""
    if RATINGS_CSV.exists():
        return str(RATINGS_CSV)
    # Create empty CSV if doesn't exist
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    with open(RATINGS_CSV, "w", encoding="utf-8") as f:
        f.write("image_name,quality_mos\n")
    return str(RATINGS_CSV)


def load_all_rated_images() -> List[Tuple[Image.Image, str]]:
    """Load all images from uploads/ that have ratings in ratings.csv.
    Returns list of tuples: (PIL Image, caption with 'filename - Score: X.XXXX')
    """
    if not RATINGS_CSV.exists():
        return []
    
    # Read ratings
    try:
        df = pd.read_csv(RATINGS_CSV)
    except Exception:
        return []
    
    gallery_items = []
    for _, row in df.iterrows():
        img_name = row['image_name']
        score = row['quality_mos']
        img_path = UPLOADS_DIR / img_name
        
        if img_path.exists():
            try:
                img = Image.open(img_path).convert("RGB")
                caption = f"{img_name} - Score: {score:.4f}"
                gallery_items.append((img, caption))
            except Exception:
                continue
    
    return gallery_items


def validate_score(value) -> Tuple[bool, float, str]:
    """Validate a score is a valid float between 0 and 1. Returns (ok, float_value, message)."""
    if value is None or value == "":
        return False, 0.0, "Score is required."
    try:
        x = float(value)
        if x < 0.0 or x > 1.0:
            return False, 0.0, "Score must be between 0.0 and 1.0."
        return True, x, ""
    except (ValueError, TypeError):
        return False, 0.0, f"Invalid score: '{value}'. Must be a float number (e.g., 0.85)."


def make_app():
    ensure_dirs()
    if THRESHOLDS_JSON.exists():
        thresholds = load_thresholds_json(str(THRESHOLDS_JSON))
    else:
        thresholds = compute_thresholds(TRAIN_CSV_PATH)
        save_thresholds_json(thresholds, str(THRESHOLDS_JSON))
    ranges = format_ranges(thresholds)

    with gr.Blocks(title="Manual Image Rating Tool") as demo:
        gr.Markdown("# Manual Image Rating Tool")

        with gr.Row():
            with gr.Column(scale=1):
                gr.Markdown("## Rating Standard (fixed from train.csv)")
                std_lines = [f"- **{level}**: {range_str}" for level, range_str in ranges]
                gr.Markdown("\n".join(std_lines))

        # Upload segment
        uploader = gr.File(file_count="multiple", file_types=["image"], label="Upload images")
        
        gr.Markdown("### Instructions")
        gr.Markdown("- Default score is **0.7** for all images")
        gr.Markdown("- **Score must be a float number between 0.0 and 1.0** (e.g., 0.85, 0.72)")
        gr.Markdown("- Use the number input fields below to enter scores (**only numeric values accepted**)")
        
        # Scores container
        with gr.Column() as scores_container:
            gr.Markdown("### Enter Scores")

        save_btn = gr.Button("Save ratings", variant="primary")
        status = gr.Markdown(visible=False)

        # Gallery section to show all saved images with scores
        gr.Markdown("---")
        gr.Markdown("## All Saved Images with Scores")
        refresh_gallery_btn = gr.Button("Refresh Gallery", variant="secondary")
        saved_gallery = gr.Gallery(
            label="All Rated Images",
            show_label=True,
            columns=4,
            rows=3,
            height="auto",
            object_fit="contain"
        )

        download_csv = gr.File(label="Download Ratings CSV")
        dl_btn = gr.Button("Download CSV")

        files_state = gr.State([])  # store uploaded File objects
        scores_state = gr.State([])  # store score values

        def on_upload(files):
            if not files:
                return [], [], "", []
            
            gal_items = []
            score_fields_html = "<table style='width:100%; border-collapse: collapse;'>"
            score_fields_html += "<tr style='background-color: #f0f0f0;'><th style='padding:10px; text-align:left;'>Image Name</th><th style='padding:10px;'>Score (0.0-1.0)</th></tr>"
            
            filenames = []
            for f in files:
                try:
                    img = Image.open(f.name).convert("RGB")
                    fname = os.path.basename(f.name)
                    gal_items.append((img, fname))
                    filenames.append(fname)
                    score_fields_html += f"<tr style='border-bottom: 1px solid #ddd;'><td style='padding:10px;'>{fname}</td><td style='padding:10px;' id='score_{len(filenames)-1}'></td></tr>"
                except Exception:
                    continue
            
            score_fields_html += "</table>"
            return gal_items, files, score_fields_html, [0.7] * len(filenames)

        # Create dynamic number inputs with thumbnails
        score_inputs_list = []
        max_files = 50  # Set a reasonable limit
        
        with scores_container:
            for i in range(max_files):
                with gr.Row(visible=False) as row:
                    thumbnail = gr.Image(label="", height=120, width=120, interactive=False, scale=1)
                    filename_display = gr.Textbox(label="Image Name", interactive=False, scale=2)
                    score_num = gr.Number(value=0.7, minimum=0.0, maximum=1.0, step=0.001, label="Score", scale=1)
                    score_inputs_list.append((row, thumbnail, filename_display, score_num))

        def update_inputs(files):
            if not files:
                updates = []
                for row, thumb, fname, score in score_inputs_list:
                    updates.extend([gr.update(visible=False), gr.update(value=None), gr.update(value=""), gr.update(value=0.7)])
                return updates + [[]]
            
            updates = []
            filenames = []
            
            for idx, f in enumerate(files[:max_files]):
                try:
                    img = Image.open(f.name).convert("RGB")
                    fname = os.path.basename(f.name)
                    filenames.append(fname)
                    
                    if idx < len(score_inputs_list):
                        updates.extend([
                            gr.update(visible=True),  # row
                            gr.update(value=img),  # thumbnail
                            gr.update(value=fname),  # filename
                            gr.update(value=0.7)  # score
                        ])
                except Exception:
                    continue
            
            # Hide remaining rows
            for idx in range(len(filenames), len(score_inputs_list)):
                updates.extend([gr.update(visible=False), gr.update(value=None), gr.update(value=""), gr.update(value=0.7)])
            
            return updates + [files]

        def save(files, *scores):
            try:
                if not files:
                    return gr.update(visible=True, value="❌ No files uploaded."), None, []
                
                # Build filename -> score map with validation
                name_to_score: Dict[str, float] = {}
                for idx, f in enumerate(files):
                    fname = os.path.basename(f.name)
                    score_val = scores[idx] if idx < len(scores) else 0.7
                    
                    ok, val, msg = validate_score(score_val)
                    if not ok:
                        return gr.update(visible=True, value=f"❌ '{fname}': {msg}"), None, []
                    
                    name_to_score[fname] = val

                # Save images with validated scores
                saved_rows = []
                for f in files:
                    base = os.path.basename(f.name)
                    try:
                        img = Image.open(f.name).convert("RGB")
                        saved_name = save_image_with_numeric_name(img, base)
                        saved_rows.append((saved_name, name_to_score[base]))
                    except Exception as e:
                        return gr.update(visible=True, value=f"❌ Failed to save '{base}': {str(e)}"), None, []

                # Append to CSV
                append_ratings(saved_rows)
                
                # Load all rated images for gallery
                gallery_items = load_all_rated_images()
                
                return gr.update(visible=True, value=f"✅ Successfully saved {len(saved_rows)} ratings."), str(RATINGS_CSV), gallery_items
                
            except Exception as e:
                import traceback
                return gr.update(visible=True, value=f"❌ Error: {str(e)}\n{traceback.format_exc()}"), None, []

        # Wire up events
        uploader_outputs = []
        for row, thumb, fname, score in score_inputs_list:
            uploader_outputs.extend([row, thumb, fname, score])
        uploader_outputs.append(files_state)
        
        uploader.upload(update_inputs, inputs=[uploader], outputs=uploader_outputs)
        
        save_inputs = [files_state] + [score for _, _, _, score in score_inputs_list]
        save_btn.click(save, inputs=save_inputs, outputs=[status, download_csv, saved_gallery])
        
        def download_csv_handler():
            csv_path = build_download_csv()
            return csv_path
        
        def refresh_gallery():
            """Refresh the gallery with all saved images."""
            return load_all_rated_images()
        
        dl_btn.click(download_csv_handler, outputs=[download_csv])
        refresh_gallery_btn.click(refresh_gallery, outputs=[saved_gallery])
        
        # Load gallery on startup
        demo.load(refresh_gallery, outputs=[saved_gallery])

    return demo


if __name__ == "__main__":
    app = make_app()
    app.launch(server_port=7009, server_name="0.0.0.0")
