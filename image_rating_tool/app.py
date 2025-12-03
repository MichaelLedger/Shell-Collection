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


def get_image_names_list() -> List[str]:
    """Get list of all image names from ratings.csv."""
    if not RATINGS_CSV.exists():
        return []
    try:
        df = pd.read_csv(RATINGS_CSV)
        return df['image_name'].tolist()
    except Exception:
        return []


def delete_image_and_rating(image_name: str) -> Tuple[bool, str]:
    """Delete an image from uploads/ and remove its entry from ratings.csv.
    Returns (success, message).
    """
    if not image_name:
        return False, "No image selected."
    
    # Remove from CSV
    if RATINGS_CSV.exists():
        try:
            df = pd.read_csv(RATINGS_CSV)
            if image_name not in df['image_name'].values:
                return False, f"Image '{image_name}' not found in ratings."
            df = df[df['image_name'] != image_name]
            df.to_csv(RATINGS_CSV, index=False)
        except Exception as e:
            return False, f"Failed to update CSV: {str(e)}"
    
    # Delete image file
    img_path = UPLOADS_DIR / image_name
    if img_path.exists():
        try:
            img_path.unlink()
        except Exception as e:
            return False, f"Failed to delete image file: {str(e)}"
    
    return True, f"Successfully deleted '{image_name}'."


def update_image_score(image_name: str, new_score: float) -> Tuple[bool, str]:
    """Update the score for an image in ratings.csv.
    Returns (success, message).
    """
    if not image_name:
        return False, "No image selected."
    
    # Validate score
    ok, val, msg = validate_score(new_score)
    if not ok:
        return False, msg
    
    if not RATINGS_CSV.exists():
        return False, "No ratings file exists."
    
    try:
        df = pd.read_csv(RATINGS_CSV)
        if image_name not in df['image_name'].values:
            return False, f"Image '{image_name}' not found in ratings."
        
        df.loc[df['image_name'] == image_name, 'quality_mos'] = val
        df.to_csv(RATINGS_CSV, index=False)
        return True, f"Successfully updated score for '{image_name}' to {val:.4f}."
    except Exception as e:
        return False, f"Failed to update score: {str(e)}"


def get_image_score(image_name: str) -> float:
    """Get the current score for an image from ratings.csv."""
    if not image_name or not RATINGS_CSV.exists():
        return 0.7
    try:
        df = pd.read_csv(RATINGS_CSV)
        match = df[df['image_name'] == image_name]
        if not match.empty:
            return float(match['quality_mos'].iloc[0])
    except Exception:
        pass
    return 0.7


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

    # Custom CSS to align edit section elements
    custom_css = """
    .edit-section-row {
        align-items: stretch !important;
        margin-bottom: 16px !important;
    }
    .edit-left-col {
        display: flex;
        flex-direction: column;
        justify-content: flex-start;
        gap: 8px;
    }
    .edit-right-col {
        display: flex;
        flex-direction: column;
        justify-content: flex-start;
        gap: 8px;
    }
    .selected-preview img {
        transform: none !important;
        transition: none !important;
    }
    .selected-preview img:hover {
        transform: none !important;
    }
    .selected-preview .image-container {
        transform: none !important;
    }
    .selected-preview .image-container:hover {
        transform: none !important;
    }
    """
    
    with gr.Blocks(title="Manual Image Rating Tool", css=custom_css) as demo:
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
        
        # Edit/Delete section (above gallery)
        gr.Markdown("### Edit or Delete Selected Image")
        with gr.Row(elem_classes="edit-section-row", equal_height=True):
            with gr.Column(scale=2, elem_classes="edit-left-col"):
                selected_image_dropdown = gr.Dropdown(
                    label="Select Image to Edit/Delete",
                    choices=[],
                    interactive=True,
                    allow_custom_value=False
                )
                edit_score_input = gr.Number(
                    value=0.7,
                    minimum=0.0,
                    maximum=1.0,
                    step=0.001,
                    label="New Score (0.0-1.0)"
                )
                update_score_btn = gr.Button("Update Score", variant="primary", interactive=False)
            with gr.Column(scale=1, elem_classes="edit-right-col"):
                selected_image_preview = gr.Image(
                    label="Selected Image Preview",
                    height=120,
                    interactive=False,
                    elem_classes="selected-preview"
                )
                delete_btn = gr.Button("🗑️ Delete Image", variant="stop", interactive=False)
        
        edit_status = gr.Markdown(visible=False)
        
        # Gallery below edit section
        refresh_gallery_btn = gr.Button("Refresh Gallery", variant="secondary")
        saved_gallery = gr.Gallery(
            label="All Rated Images (Click an image to select it for edit/delete)",
            show_label=True,
            columns=6,
            rows=5,
            height=600,
            object_fit="contain",
            show_download_button=False,
            interactive=False
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
                    return gr.update(visible=True, value="❌ No files uploaded."), None, [], gr.update()
                
                # Build filename -> score map with validation
                name_to_score: Dict[str, float] = {}
                for idx, f in enumerate(files):
                    fname = os.path.basename(f.name)
                    score_val = scores[idx] if idx < len(scores) else 0.7
                    
                    ok, val, msg = validate_score(score_val)
                    if not ok:
                        return gr.update(visible=True, value=f"❌ '{fname}': {msg}"), None, [], gr.update()
                    
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
                        return gr.update(visible=True, value=f"❌ Failed to save '{base}': {str(e)}"), None, [], gr.update()

                # Append to CSV
                append_ratings(saved_rows)
                
                # Reload all rated images from disk for gallery
                gallery_items = load_all_rated_images()
                
                # Update dropdown with new image names
                names = get_image_names_list()
                
                return gr.update(visible=True, value=f"✅ Successfully saved {len(saved_rows)} ratings."), str(RATINGS_CSV), gallery_items, gr.update(choices=names)
                
            except Exception as e:
                import traceback
                return gr.update(visible=True, value=f"❌ Error: {str(e)}\n{traceback.format_exc()}"), None, [], gr.update()

        # Wire up events
        uploader_outputs = []
        for row, thumb, fname, score in score_inputs_list:
            uploader_outputs.extend([row, thumb, fname, score])
        uploader_outputs.append(files_state)
        
        uploader.upload(update_inputs, inputs=[uploader], outputs=uploader_outputs)
        
        save_inputs = [files_state] + [score for _, _, _, score in score_inputs_list]
        save_btn.click(save, inputs=save_inputs, outputs=[status, download_csv, saved_gallery, selected_image_dropdown])
        
        def download_csv_handler():
            csv_path = build_download_csv()
            return csv_path
        
        def refresh_gallery():
            """Refresh the gallery with all saved images."""
            return load_all_rated_images()
        
        def refresh_dropdown():
            """Refresh the dropdown with current image names."""
            names = get_image_names_list()
            return gr.update(choices=names, value=None)
        
        def refresh_all():
            """Refresh both gallery and dropdown."""
            gallery = load_all_rated_images()
            names = get_image_names_list()
            return gallery, gr.update(choices=names, value=None)
        
        def on_image_select(image_name):
            """When an image is selected from dropdown, show preview and load its score."""
            if not image_name:
                # No image selected - disable buttons
                return None, 0.7, gr.update(interactive=False), gr.update(interactive=False)
            
            # Load image preview
            img_path = UPLOADS_DIR / image_name
            if img_path.exists():
                try:
                    img = Image.open(img_path).convert("RGB")
                    score = get_image_score(image_name)
                    # Image selected - enable buttons
                    return img, score, gr.update(interactive=True), gr.update(interactive=True)
                except Exception:
                    pass
            return None, 0.7, gr.update(interactive=False), gr.update(interactive=False)
        
        def on_gallery_select(evt: gr.SelectData):
            """When an image is clicked in gallery, select it in dropdown."""
            names = get_image_names_list()
            if evt.value and isinstance(evt.value, dict) and 'caption' in evt.value:
                caption = evt.value['caption']
                # Extract image name from caption (format: "filename - Score: X.XXXX")
                if ' - Score:' in caption:
                    image_name = caption.split(' - Score:')[0]
                    img_path = UPLOADS_DIR / image_name
                    if img_path.exists():
                        try:
                            img = Image.open(img_path).convert("RGB")
                            score = get_image_score(image_name)
                            # Image selected - enable buttons
                            return gr.update(choices=names, value=image_name), img, score, gr.update(interactive=True), gr.update(interactive=True)
                        except Exception:
                            pass
            # No image selected - disable buttons
            return gr.update(choices=names, value=None), None, 0.7, gr.update(interactive=False), gr.update(interactive=False)
        
        def handle_delete(image_name, current_gallery):
            """Handle delete button click."""
            if not image_name:
                return (
                    gr.update(visible=True, value="❌ Please select an image first."),
                    gr.update(),  # Don't reload gallery
                    gr.update(),  # Don't reload dropdown
                    gr.update(),
                    gr.update(),
                    gr.update(interactive=False),  # Disable update button
                    gr.update(interactive=False)   # Disable delete button
                )
            
            success, msg = delete_image_and_rating(image_name)
            
            if success:
                # Remove deleted image from current gallery without full reload
                names = get_image_names_list()
                # Filter out the deleted image from current gallery data
                new_gallery = []
                if current_gallery:
                    for item in current_gallery:
                        # Gallery item can be tuple (img, caption) or dict
                        if isinstance(item, tuple) and len(item) >= 2:
                            img, caption = item[0], item[1]
                            # Check if this is the deleted image
                            if not caption.startswith(f"{image_name} - Score:"):
                                new_gallery.append((img, caption))
                        elif isinstance(item, dict):
                            caption = item.get('caption', '')
                            if not caption.startswith(f"{image_name} - Score:"):
                                new_gallery.append(item)
                
                return (
                    gr.update(visible=True, value=f"✅ {msg}"),
                    new_gallery,
                    gr.update(choices=names, value=None),
                    None,
                    0.7,
                    gr.update(interactive=False),  # Disable update button after delete
                    gr.update(interactive=False)   # Disable delete button after delete
                )
            else:
                return (
                    gr.update(visible=True, value=f"❌ {msg}"),
                    gr.update(),  # Don't reload on error
                    gr.update(),
                    gr.update(),
                    gr.update(),
                    gr.update(),  # Keep button state
                    gr.update()   # Keep button state
                )
        
        def handle_update_score(image_name, new_score, current_gallery):
            """Handle update score button click."""
            if not image_name:
                return (
                    gr.update(visible=True, value="❌ Please select an image first."),
                    gr.update(),  # Don't reload gallery
                    gr.update()
                )
            
            success, msg = update_image_score(image_name, new_score)
            
            if success:
                # Update only the changed image's caption in current gallery (no reload)
                updated_gallery = []
                new_caption = f"{image_name} - Score: {new_score:.4f}"
                
                if current_gallery:
                    for item in current_gallery:
                        # Gallery item can be tuple (img, caption) or dict
                        if isinstance(item, tuple) and len(item) >= 2:
                            img, caption = item[0], item[1]
                            # Check if this is the updated image
                            if caption.startswith(f"{image_name} - Score:"):
                                updated_gallery.append((img, new_caption))
                            else:
                                updated_gallery.append((img, caption))
                        elif isinstance(item, dict):
                            caption = item.get('caption', '')
                            img = item.get('image', item)
                            if caption.startswith(f"{image_name} - Score:"):
                                updated_gallery.append({'image': img, 'caption': new_caption})
                            else:
                                updated_gallery.append(item)
                
                return (
                    gr.update(visible=True, value=f"✅ {msg}"),
                    updated_gallery,
                    new_score
                )
            else:
                return (
                    gr.update(visible=True, value=f"❌ {msg}"),
                    gr.update(),  # Don't reload on error
                    gr.update()
                )
        
        def on_startup():
            """Initialize gallery and dropdown on startup."""
            gallery = load_all_rated_images()
            names = get_image_names_list()
            return gallery, gr.update(choices=names, value=None)
        
        dl_btn.click(download_csv_handler, outputs=[download_csv])
        refresh_gallery_btn.click(refresh_all, outputs=[saved_gallery, selected_image_dropdown])
        
        # Dropdown selection handler
        selected_image_dropdown.change(
            on_image_select,
            inputs=[selected_image_dropdown],
            outputs=[selected_image_preview, edit_score_input, update_score_btn, delete_btn]
        )
        
        # Gallery click handler
        saved_gallery.select(
            on_gallery_select,
            outputs=[selected_image_dropdown, selected_image_preview, edit_score_input, update_score_btn, delete_btn]
        )
        
        # Delete button handler with confirmation
        delete_btn.click(
            fn=handle_delete,
            inputs=[selected_image_dropdown, saved_gallery],
            outputs=[edit_status, saved_gallery, selected_image_dropdown, selected_image_preview, edit_score_input, update_score_btn, delete_btn],
            js="(image_name, gallery) => { if (!confirm('Are you sure you want to delete this image? This action cannot be undone.')) { throw new Error('cancelled'); } return [image_name, gallery]; }"
        )
        
        # Update score button handler with confirmation
        update_score_btn.click(
            fn=handle_update_score,
            inputs=[selected_image_dropdown, edit_score_input, saved_gallery],
            outputs=[edit_status, saved_gallery, edit_score_input],
            js="(image_name, score, gallery) => { if (!confirm('Are you sure you want to update the score for this image?')) { throw new Error('cancelled'); } return [image_name, score, gallery]; }"
        )
        
        # Load gallery and dropdown on startup
        demo.load(on_startup, outputs=[saved_gallery, selected_image_dropdown])

    return demo


if __name__ == "__main__":
    app = make_app()
    app.launch(server_port=7009, server_name="0.0.0.0")
