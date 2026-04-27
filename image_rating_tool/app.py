import base64
import csv
import io
import json
import mimetypes
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
DELETED_DIR = ROOT_DIR / "deleted_images"
RESULTS_DIR = ROOT_DIR / "results"
RATINGS_CSV = RESULTS_DIR / "ratings.csv"
DELETED_RATINGS_CSV = RESULTS_DIR / "deleted_ratings.csv"
THRESHOLDS_JSON = RESULTS_DIR / "thresholds.json"

# Absolute path to training CSV in the main project
TRAIN_CSV_PATH = ROOT_DIR / "train.csv"


def ensure_dirs() -> None:
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    DELETED_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)


def _archive_deleted_rows(rows_df: "pd.DataFrame") -> None:
    """Append rows that were just removed from RATINGS_CSV into DELETED_RATINGS_CSV."""
    if rows_df is None or rows_df.empty:
        return
    if DELETED_RATINGS_CSV.exists():
        try:
            existing = pd.read_csv(DELETED_RATINGS_CSV)
            existing = existing[~existing["image_name"].isin(rows_df["image_name"].values)]
            combined = pd.concat([existing, rows_df], ignore_index=True)
        except Exception:
            combined = rows_df
    else:
        combined = rows_df
    combined.to_csv(DELETED_RATINGS_CSV, index=False)


def _move_to_deleted(name: str) -> bool:
    """Move uploads/<name> to deleted_images/<name>. Returns True on success."""
    src = UPLOADS_DIR / name
    if not src.exists():
        return False
    DELETED_DIR.mkdir(parents=True, exist_ok=True)
    dst = DELETED_DIR / name
    try:
        if dst.exists():
            dst.unlink()
        src.replace(dst)
        return True
    except Exception:
        return False


def _move_to_uploads(name: str) -> bool:
    """Move deleted_images/<name> back to uploads/<name>. Returns True on success."""
    src = DELETED_DIR / name
    if not src.exists():
        return False
    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    dst = UPLOADS_DIR / name
    try:
        if dst.exists():
            return False
        src.replace(dst)
        return True
    except Exception:
        return False


def next_numeric_filename(uploads_dir: Path, original_ext: str) -> str:
    """Return the next numeric filename (string) starting at 10000 with given extension.

    Scans both uploads_dir and DELETED_DIR so we never reuse an ID belonging to a
    soft-deleted image (which would collide on recovery).
    """
    max_id = 9999
    scan_dirs: List[Path] = [uploads_dir]
    if DELETED_DIR.exists() and DELETED_DIR.resolve() != uploads_dir.resolve():
        scan_dirs.append(DELETED_DIR)
    for d in scan_dirs:
        try:
            for p in d.iterdir():
                if not p.is_file():
                    continue
                stem = p.stem
                if not stem.isdigit():
                    continue
                try:
                    val = int(stem)
                except ValueError:
                    continue
                if val > max_id:
                    max_id = val
        except FileNotFoundError:
            continue
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


def get_rated_image_names_gallery_order() -> List[str]:
    """Image names in the same order as load_all_rated_images() (sorted by name, file must exist)."""
    if not RATINGS_CSV.exists():
        return []
    try:
        df = _sort_df_by_name(pd.read_csv(RATINGS_CSV))
    except Exception:
        return []
    names: List[str] = []
    for _, row in df.iterrows():
        img_name = str(row["image_name"])
        if (UPLOADS_DIR / img_name).exists():
            names.append(img_name)
    return names


def load_all_rated_images() -> List[Tuple[Image.Image, str]]:
    """Load all images from uploads/ that have ratings in ratings.csv.
    Returns list of tuples: (PIL Image, caption with 'filename - Score: X.XXXX')
    """
    if not RATINGS_CSV.exists():
        return []

    try:
        df = _sort_df_by_name(pd.read_csv(RATINGS_CSV))
    except Exception:
        return []

    gallery_items: List[Tuple[Image.Image, str]] = []
    for _, row in df.iterrows():
        img_name = str(row["image_name"])
        score = row["quality_mos"]
        img_path = UPLOADS_DIR / img_name

        if img_path.exists():
            try:
                img = Image.open(img_path).convert("RGB")
                caption = f"{img_name} - Score: {score:.4f}"
                gallery_items.append((img, caption))
            except Exception:
                continue

    return gallery_items


def _sort_df_by_name(df: "pd.DataFrame") -> "pd.DataFrame":
    """Sort a ratings dataframe by image_name. Numeric stems sort numerically; rest lexicographically."""
    if df is None or df.empty or "image_name" not in df.columns:
        return df
    names = df["image_name"].astype(str)
    stems = names.str.split(".").str[0]
    is_num = stems.str.fullmatch(r"\d+").fillna(False)
    num_key = pd.to_numeric(stems.where(is_num, other=-1), errors="coerce").fillna(-1).astype("int64")
    out = df.copy()
    out["_is_num"] = (~is_num).astype(int)  # numeric names first (0), others after (1)
    out["_num_key"] = num_key
    out["_name_lower"] = names.str.lower()
    out = out.sort_values(["_is_num", "_num_key", "_name_lower"], kind="stable")
    return out.drop(columns=["_is_num", "_num_key", "_name_lower"])


def _safe_score(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.7


def build_batch_picker_html(queued_names: List[str] | None) -> str:
    """Custom HTML thumbnail grid for the batch picker.
    - Multi-image highlighting: every queued thumbnail keeps an orange frame.
    - No Gradio re-render on click: a JS click handler toggles the `.queued` class
      and writes the new queue (JSON) into a hidden textbox to sync server state.
    """
    if not RATINGS_CSV.exists():
        return "<div class='batch-picker-empty'>No rated images yet.</div>"
    try:
        df = _sort_df_by_name(pd.read_csv(RATINGS_CSV))
    except Exception:
        return "<div class='batch-picker-empty'>No rated images yet.</div>"

    qset = set(queued_names or [])
    cells: List[str] = []
    for _, row in df.iterrows():
        img_name = str(row["image_name"])
        p = UPLOADS_DIR / img_name
        if not p.is_file():
            continue
        sc = _safe_score(row["quality_mos"])
        is_q = "queued" if img_name in qset else ""
        # Embed as data URI — avoids Gradio file-route quirks across versions.
        try:
            mime, _ = mimetypes.guess_type(str(p))
            if not mime:
                mime = "image/jpeg"
            with open(p, "rb") as fh:
                b64 = base64.b64encode(fh.read()).decode("ascii")
            src = f"data:{mime};base64,{b64}"
        except Exception:
            continue
        cells.append(
            f'<div class="bp-cell {is_q}" data-name="{img_name}">'
            f'<img loading="lazy" src="{src}" alt="{img_name}" />'
            f'<div class="bp-caption">{img_name} — {sc:.4f}</div>'
            f"</div>"
        )

    if not cells:
        return "<div class='batch-picker-empty'>No rated images yet.</div>"

    return (
        '<div id="batch-picker-grid" class="bp-grid">' + "".join(cells) + "</div>"
    )


def build_recover_picker_html(queued_names: List[str] | None) -> str:
    """Custom HTML thumbnail grid for the recovery picker (deleted images)."""
    if not DELETED_RATINGS_CSV.exists():
        return "<div class='batch-picker-empty'>No deleted images yet.</div>"
    try:
        df = _sort_df_by_name(pd.read_csv(DELETED_RATINGS_CSV))
    except Exception:
        return "<div class='batch-picker-empty'>No deleted images yet.</div>"

    qset = set(queued_names or [])
    cells: List[str] = []
    for _, row in df.iterrows():
        img_name = str(row["image_name"])
        p = DELETED_DIR / img_name
        if not p.is_file():
            continue
        sc = _safe_score(row["quality_mos"])
        is_q = "queued" if img_name in qset else ""
        try:
            mime, _ = mimetypes.guess_type(str(p))
            if not mime:
                mime = "image/jpeg"
            with open(p, "rb") as fh:
                b64 = base64.b64encode(fh.read()).decode("ascii")
            src = f"data:{mime};base64,{b64}"
        except Exception:
            continue
        cells.append(
            f'<div class="bp-cell {is_q}" data-name="{img_name}">'
            f'<img loading="lazy" src="{src}" alt="{img_name}" />'
            f'<div class="bp-caption">{img_name} — {sc:.4f}</div>'
            f"</div>"
        )

    if not cells:
        return "<div class='batch-picker-empty'>No deleted images yet.</div>"

    return (
        '<div id="recover-picker-grid" class="bp-grid">' + "".join(cells) + "</div>"
    )


# Kept for backwards compat / unused after switch — safe no-op replacement.
def build_batch_picker_gallery(queued_names: List[str] | None) -> List[Tuple[str, str]]:
    if not RATINGS_CSV.exists():
        return []
    try:
        df = pd.read_csv(RATINGS_CSV)
    except Exception:
        return []
    qset = set(queued_names or [])
    out: List[Tuple[str, str]] = []
    for _, row in df.iterrows():
        img_name = str(row["image_name"])
        score = row["quality_mos"]
        p = UPLOADS_DIR / img_name
        if not p.is_file():
            continue
        try:
            sc = float(score)
        except (TypeError, ValueError):
            sc = 0.7
        cap = f"{img_name} - Score: {sc:.4f}"
        if img_name in qset:
            cap = f"{cap} · queued"
        out.append((str(p.resolve()), cap))
    return out


def get_image_names_list() -> List[str]:
    """Get list of all image names from ratings.csv, sorted by image name."""
    if not RATINGS_CSV.exists():
        return []
    try:
        df = _sort_df_by_name(pd.read_csv(RATINGS_CSV))
        return df['image_name'].tolist()
    except Exception:
        return []


def delete_image_and_rating(image_name: str) -> Tuple[bool, str]:
    """Delete an image from uploads/ and remove its entry from ratings.csv.
    Returns (success, message).
    """
    if not image_name:
        return False, "No image selected."

    if not RATINGS_CSV.exists():
        return False, "No ratings file exists."

    try:
        df = pd.read_csv(RATINGS_CSV)
        if image_name not in df["image_name"].values:
            return False, f"Image '{image_name}' not found in ratings."
        archived = df[df["image_name"] == image_name].copy()
        df = df[df["image_name"] != image_name]
        df.to_csv(RATINGS_CSV, index=False)
        _archive_deleted_rows(archived)
    except Exception as e:
        return False, f"Failed to update CSV: {str(e)}"

    _move_to_deleted(image_name)
    return True, f"Moved '{image_name}' to deleted_images (recoverable)."


def delete_images_and_ratings_batch(image_names: List[str]) -> Tuple[int, str]:
    """Move multiple images to deleted_images/ and archive their ratings. Returns (count, message)."""
    if not image_names:
        return 0, "No images selected."
    seen = set()
    unique: List[str] = []
    for n in image_names:
        if not n or n in seen:
            continue
        seen.add(n)
        unique.append(n)
    if not unique:
        return 0, "No images selected."

    if not RATINGS_CSV.exists():
        return 0, "No ratings file exists."

    try:
        df = pd.read_csv(RATINGS_CSV)
    except Exception as e:
        return 0, f"Failed to read ratings: {e}"

    archived = df[df["image_name"].isin(unique)].copy()
    if archived.empty:
        return 0, "None of the selected images were found in ratings."

    df = df[~df["image_name"].isin(unique)]
    try:
        df.to_csv(RATINGS_CSV, index=False)
    except Exception as e:
        return 0, f"Failed to update CSV: {e}"

    _archive_deleted_rows(archived)

    moved = 0
    for name in unique:
        if _move_to_deleted(name):
            moved += 1

    return len(archived), (
        f"Moved {moved} file(s) to deleted_images/, archived {len(archived)} rating(s) "
        "(recoverable)."
    )


def get_deleted_image_names() -> List[str]:
    """Get list of all deleted image names from deleted_ratings.csv, sorted by image name."""
    if not DELETED_RATINGS_CSV.exists():
        return []
    try:
        df = _sort_df_by_name(pd.read_csv(DELETED_RATINGS_CSV))
        return df["image_name"].tolist()
    except Exception:
        return []


def recover_deleted_images_batch(image_names: List[str]) -> Tuple[int, str]:
    """Move images back from deleted_images/ to uploads/ and restore their ratings rows."""
    if not image_names:
        return 0, "No images selected."
    seen = set()
    unique: List[str] = []
    for n in image_names:
        if not n or n in seen:
            continue
        seen.add(n)
        unique.append(n)
    if not unique:
        return 0, "No images selected."

    if not DELETED_RATINGS_CSV.exists():
        return 0, "No deleted_ratings.csv yet."
    try:
        ddf = pd.read_csv(DELETED_RATINGS_CSV)
    except Exception as e:
        return 0, f"Failed to read deleted_ratings: {e}"

    to_restore = ddf[ddf["image_name"].isin(unique)].copy()
    if to_restore.empty:
        return 0, "None of the selected images were found in deleted_ratings.csv."

    if RATINGS_CSV.exists():
        try:
            cur = pd.read_csv(RATINGS_CSV)
            cur = cur[~cur["image_name"].isin(to_restore["image_name"].values)]
            new_df = pd.concat([cur, to_restore], ignore_index=True)
        except Exception as e:
            return 0, f"Failed to read ratings.csv: {e}"
    else:
        new_df = to_restore

    try:
        new_df.to_csv(RATINGS_CSV, index=False)
    except Exception as e:
        return 0, f"Failed to write ratings.csv: {e}"

    moved = 0
    for name in to_restore["image_name"].astype(str).tolist():
        if _move_to_uploads(name):
            moved += 1

    remaining = ddf[~ddf["image_name"].isin(to_restore["image_name"].values)]
    try:
        remaining.to_csv(DELETED_RATINGS_CSV, index=False)
    except Exception:
        pass

    return len(to_restore), (
        f"Recovered {moved} file(s); restored {len(to_restore)} rating(s)."
    )


def purge_deleted_images_batch(image_names: List[str]) -> Tuple[int, str]:
    """Permanently delete files from deleted_images/ and rows from deleted_ratings.csv."""
    if not image_names:
        return 0, "No images selected."
    unique = list({n for n in image_names if n})
    if not unique:
        return 0, "No images selected."

    removed_files = 0
    for name in unique:
        p = DELETED_DIR / name
        if p.exists():
            try:
                p.unlink()
                removed_files += 1
            except Exception:
                pass

    removed_rows = 0
    if DELETED_RATINGS_CSV.exists():
        try:
            ddf = pd.read_csv(DELETED_RATINGS_CSV)
            before = len(ddf)
            ddf = ddf[~ddf["image_name"].isin(unique)]
            removed_rows = before - len(ddf)
            ddf.to_csv(DELETED_RATINGS_CSV, index=False)
        except Exception as e:
            return 0, f"Failed to update deleted_ratings.csv: {e}"

    return removed_files + removed_rows, (
        f"Permanently removed {removed_files} file(s) and {removed_rows} archived rating(s)."
    )


def prune_recover_queue(names: List[str] | None) -> List[str]:
    if not names:
        return []
    allowed = set(get_deleted_image_names())
    return [n for n in names if n in allowed]


def batch_update_image_scores_per_image(
    pairs: List[Tuple[str, float]],
) -> Tuple[bool, str, int]:
    """Set quality_mos per image from (image_name, score) pairs. Each score validated."""
    if not pairs:
        return False, "No images in batch.", 0
    if not RATINGS_CSV.exists():
        return False, "No ratings file exists.", 0
    validated: List[Tuple[str, float]] = []
    for name, raw in pairs:
        if not name:
            continue
        ok, val, msg = validate_score(raw)
        if not ok:
            return False, f"'{name}': {msg}", 0
        validated.append((str(name), val))
    if not validated:
        return False, "No images in batch.", 0
    try:
        df = pd.read_csv(RATINGS_CSV)
        updated = 0
        for name, val in validated:
            if name not in df["image_name"].values:
                continue
            df.loc[df["image_name"] == name, "quality_mos"] = val
            updated += 1
        if updated == 0:
            return False, "None of the batch images were found in ratings.", 0
        df.to_csv(RATINGS_CSV, index=False)
        return (
            True,
            f"Updated scores for {updated} image(s).",
            updated,
        )
    except Exception as e:
        return False, f"Failed to update scores: {e}", 0


def prune_batch_queue(names: List[str] | None) -> List[str]:
    """Keep only names that still exist in ratings.csv."""
    if not names:
        return []
    allowed = set(get_image_names_list())
    return [n for n in names if n in allowed]


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


def _gallery_select_index(evt: gr.SelectData) -> int | None:
    idx = evt.index
    if isinstance(idx, (list, tuple)):
        idx = idx[0] if idx else None
    return idx if isinstance(idx, int) else None


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
    /* Custom batch picker grid (multi-select with persistent orange frame) */
    .bp-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
        gap: 8px;
        max-height: 320px;
        overflow-y: auto;
        padding: 4px;
        border: 1px solid var(--border-color-primary, #e5e7eb);
        border-radius: 8px;
        background: var(--background-fill-secondary, #fafafa);
    }
    .bp-cell {
        position: relative;
        cursor: pointer;
        border: 3px solid transparent;
        border-radius: 6px;
        overflow: hidden;
        background: #fff;
        transition: border-color 0.1s ease;
        user-select: none;
    }
    .bp-cell img {
        width: 100%;
        height: 96px;
        object-fit: contain;
        display: block;
        background: #f3f4f6;
        pointer-events: none;
    }
    .bp-cell .bp-caption {
        font-size: 11px;
        line-height: 1.2;
        padding: 4px 6px;
        color: #374151;
        text-align: center;
        word-break: break-all;
        background: #fff;
    }
    .bp-cell:hover { border-color: #fbbf24; }
    .bp-cell.queued {
        border-color: #f97316;
        box-shadow: 0 0 0 2px rgba(249, 115, 22, 0.35) inset;
    }
    .bp-hidden {
        position: absolute !important;
        left: -9999px !important;
        width: 1px !important;
        height: 1px !important;
        overflow: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
    }
    .batch-picker-empty {
        padding: 12px;
        color: #6b7280;
        font-style: italic;
    }
    """
    
    batch_picker_head_js = """
<script>
(function(){
  if (window.__bpInit) return;
  window.__bpInit = true;
  function getProxy(){
    return document.querySelector('#bp_state_proxy textarea, #bp_state_proxy input');
  }
  function readQueue(){
    var grid = document.getElementById('batch-picker-grid');
    if (!grid) return [];
    return Array.from(grid.querySelectorAll('.bp-cell.queued')).map(function(c){return c.dataset.name;});
  }
  function syncProxy(){
    var ta = getProxy();
    if (!ta) return;
    var q = readQueue();
    var nv = JSON.stringify(q);
    if (ta.value === nv) return;
    var proto = (ta.tagName === 'TEXTAREA') ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value');
    if (setter && setter.set) setter.set.call(ta, nv); else ta.value = nv;
    ta.dispatchEvent(new Event('input', {bubbles:true}));
    ta.dispatchEvent(new Event('change', {bubbles:true}));
  }
  document.addEventListener('click', function(ev){
    var cell = ev.target.closest && ev.target.closest('.bp-cell');
    if (!cell) return;
    var grid = document.getElementById('batch-picker-grid');
    var rgrid = document.getElementById('recover-picker-grid');
    if (grid && grid.contains(cell)) {
      cell.classList.toggle('queued');
      syncProxy();
      return;
    }
    if (rgrid && rgrid.contains(cell)) {
      cell.classList.toggle('queued');
      syncRecoverProxy();
      return;
    }
  }, true);
  function getRecoverProxy(){
    return document.querySelector('#bp_recover_state_proxy textarea, #bp_recover_state_proxy input');
  }
  function readRecoverQueue(){
    var grid = document.getElementById('recover-picker-grid');
    if (!grid) return [];
    return Array.from(grid.querySelectorAll('.bp-cell.queued')).map(function(c){return c.dataset.name;});
  }
  function syncRecoverProxy(){
    var ta = getRecoverProxy();
    if (!ta) return;
    var q = readRecoverQueue();
    var nv = JSON.stringify(q);
    if (ta.value === nv) return;
    var proto = (ta.tagName === 'TEXTAREA') ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    var setter = Object.getOwnPropertyDescriptor(proto, 'value');
    if (setter && setter.set) setter.set.call(ta, nv); else ta.value = nv;
    ta.dispatchEvent(new Event('input', {bubbles:true}));
    ta.dispatchEvent(new Event('change', {bubbles:true}));
  }
  function getScoresProxy(){
    return document.querySelector('#bp_scores_proxy textarea, #bp_scores_proxy input');
  }
  function syncScoresProxy(){
    var ta = getScoresProxy();
    if (!ta) return;
    var vals = [];
    for (var i = 0; i < 15; i++) {
      var el = document.querySelector('#bp_row_score_' + i + ' input');
      if (!el) { vals.push(null); continue; }
      var v = el.value;
      if (v === '' || v === null || v === undefined) { vals.push(null); }
      else { var f = parseFloat(v); vals.push(isNaN(f) ? null : f); }
    }
    var nv = JSON.stringify(vals);
    if (ta.value === nv) return;
    var proto2 = (ta.tagName === 'TEXTAREA') ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    var setter2 = Object.getOwnPropertyDescriptor(proto2, 'value');
    if (setter2 && setter2.set) setter2.set.call(ta, nv); else ta.value = nv;
    ta.dispatchEvent(new Event('input', {bubbles:true}));
    ta.dispatchEvent(new Event('change', {bubbles:true}));
  }
  document.addEventListener('input', function(ev){
    if (ev.target && ev.target.closest && ev.target.closest('[id^="bp_row_score_"]')) {
      syncScoresProxy();
    }
  }, true);
  document.addEventListener('change', function(ev){
    if (ev.target && ev.target.closest && ev.target.closest('[id^="bp_row_score_"]')) {
      syncScoresProxy();
    }
  }, true);
  function reapplyClasses(grid, ta){
    if (!grid || !ta) return;
    var q;
    try { q = JSON.parse(ta.value || "[]"); } catch(e) { q = []; }
    var qset = new Set(q);
    grid.querySelectorAll('.bp-cell').forEach(function(c){
      if (qset.has(c.dataset.name)) c.classList.add('queued');
      else c.classList.remove('queued');
    });
  }
  // Only re-apply queued classes when the grid CONTAINER's children list changes
  // (i.e. server pushed a fresh HTML render). Ignore class-only mutations (our own clicks)
  // and unrelated DOM changes elsewhere on the page.
  var mo = new MutationObserver(function(muts){
    for (var i = 0; i < muts.length; i++) {
      var m = muts[i];
      if (m.type !== 'childList') continue;
      var t = m.target;
      if (!t || !t.querySelector) continue;
      // Find grids that may have been (re)rendered as part of this mutation.
      var grid = (t.id === 'batch-picker-grid') ? t : t.querySelector && t.querySelector('#batch-picker-grid');
      if (grid) reapplyClasses(grid, getProxy());
      var rgrid = (t.id === 'recover-picker-grid') ? t : t.querySelector && t.querySelector('#recover-picker-grid');
      if (rgrid) reapplyClasses(rgrid, getRecoverProxy());
    }
  });
  function start(){ mo.observe(document.body, {childList:true, subtree:true}); }
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
})();
</script>
"""
    with gr.Blocks(title="Manual Image Rating Tool", css=custom_css, head=batch_picker_head_js) as demo:
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
        
        gr.Markdown("### Batch operations (thumbnail picker)")
        gr.Markdown(
            "Click thumbnails in the **batch picker** below to add or remove images from the queue "
            "(click again to remove). **Queued** images show **· queued** under the thumbnail. "
            "Set a **different score per row** for each queued image, then apply or delete."
        )
        batch_selected_state = gr.State([])
        batch_picker_html = gr.HTML(value=build_batch_picker_html([]))
        batch_state_proxy = gr.Textbox(
            value="[]",
            elem_id="bp_state_proxy",
            elem_classes="bp-hidden",
            show_label=False,
            interactive=True,
        )
        batch_scores_proxy = gr.Textbox(
            value="[]",
            elem_id="bp_scores_proxy",
            elem_classes="bp-hidden",
            show_label=False,
            interactive=True,
        )
        batch_clear_btn = gr.Button("Clear batch queue", variant="secondary")
        gr.Markdown("#### Queued images — score per row (max 15)")
        batch_rows_list: List[Tuple] = []
        with gr.Column():
            for _bi in range(15):
                with gr.Row(visible=False) as batch_row:
                    batch_thumb = gr.Image(
                        label="",
                        height=72,
                        width=72,
                        interactive=False,
                        scale=0,
                    )
                    batch_fname = gr.Textbox(
                        label="Image",
                        interactive=False,
                        scale=2,
                    )
                    batch_score_num = gr.Number(
                        value=0.7,
                        minimum=0.0,
                        maximum=1.0,
                        step=0.001,
                        label="Score",
                        scale=1,
                        interactive=True,
                        elem_classes=f"bp-row-score bp-row-score-{_bi}",
                        elem_id=f"bp_row_score_{_bi}",
                    )
                    batch_rows_list.append((batch_row, batch_thumb, batch_fname, batch_score_num))

        batch_queue_outputs_flat: List = []
        for _br, _bt, _bf, _bs in batch_rows_list:
            batch_queue_outputs_flat.extend([_br, _bt, _bf, _bs])

        def render_batch_queue_updates(names: List[str]) -> List:
            names = names or []
            updates: List = []
            nmax = len(batch_rows_list)
            for idx in range(nmax):
                row, thumb, fname, score_el = batch_rows_list[idx]
                if idx < len(names):
                    nm = names[idx]
                    img_path = UPLOADS_DIR / nm
                    try:
                        img = Image.open(img_path).convert("RGB")
                    except Exception:
                        img = None
                    sc = get_image_score(nm)
                    updates.extend(
                        [
                            gr.update(visible=True),
                            gr.update(value=img),
                            gr.update(value=nm),
                            gr.update(value=sc),
                        ]
                    )
                else:
                    updates.extend(
                        [
                            gr.update(visible=False),
                            gr.update(value=None),
                            gr.update(value=""),
                            gr.update(value=0.7),
                        ]
                    )
            return updates

        def on_proxy_state_change(proxy_value: str):
            """Hidden textbox driven by JS toggling. Sync state + queue rows.
            Does NOT push HTML for the picker — DOM already has correct classes.
            """
            try:
                names_in = json.loads(proxy_value or "[]")
            except Exception:
                names_in = []
            if not isinstance(names_in, list):
                names_in = []
            allowed = set(get_image_names_list())
            nmax = len(batch_rows_list)
            new_names: List[str] = []
            for n in names_in:
                if isinstance(n, str) and n in allowed and n not in new_names:
                    new_names.append(n)
                if len(new_names) >= nmax:
                    break
            return (new_names, *render_batch_queue_updates(new_names))

        def clear_batch_queue_fn():
            return (
                [],
                build_batch_picker_html([]),
                "[]",
                *render_batch_queue_updates([]),
            )

        with gr.Row():
            batch_delete_btn = gr.Button("🗑️ Batch delete queued", variant="stop")
            batch_update_scores_btn = gr.Button("Apply batch scores", variant="primary")
        
        batch_status = gr.Markdown(visible=False)
        
        refresh_gallery_btn = gr.Button("Refresh Gallery", variant="secondary")
        saved_gallery = gr.Gallery(
            label="All Rated Images",
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

        gr.Markdown("---")
        gr.Markdown("## Deleted Images Recovery")
        gr.Markdown(
            "Deleted images are moved to `deleted_images/` and their ratings to "
            "`results/deleted_ratings.csv`. Click thumbnails to queue images, then "
            "**Recover** them back to `uploads/` and `ratings.csv`, or **Permanently delete** to purge forever."
        )
        recover_selected_state = gr.State([])
        recover_picker_html = gr.HTML(value=build_recover_picker_html([]))
        recover_state_proxy = gr.Textbox(
            value="[]",
            elem_id="bp_recover_state_proxy",
            elem_classes="bp-hidden",
            show_label=False,
            interactive=True,
        )
        with gr.Row():
            recover_clear_btn = gr.Button("Clear recovery queue", variant="secondary")
            recover_refresh_btn = gr.Button("Refresh deleted list", variant="secondary")
        with gr.Row():
            recover_btn = gr.Button("♻️ Recover queued", variant="primary")
            purge_btn = gr.Button("🗑️ Permanently delete queued", variant="stop")
        recover_status = gr.Markdown(visible=False)

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

        def save(files, batch_state, *scores):
            try:
                pruned = prune_batch_queue(batch_state)

                def _tail(p):
                    return (
                        build_batch_picker_html(p),
                        json.dumps(p),
                        p,
                        *render_batch_queue_updates(p),
                    )

                if not files:
                    return (
                        gr.update(visible=True, value="❌ No files uploaded."),
                        None,
                        [],
                        *_tail(pruned),
                    )

                # Build filename -> score map with validation
                name_to_score: Dict[str, float] = {}
                for idx, f in enumerate(files):
                    fname = os.path.basename(f.name)
                    score_val = scores[idx] if idx < len(scores) else 0.7

                    ok, val, msg = validate_score(score_val)
                    if not ok:
                        return (
                            gr.update(visible=True, value=f"❌ '{fname}': {msg}"),
                            None,
                            [],
                            *_tail(pruned),
                        )

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
                        return (
                            gr.update(visible=True, value=f"❌ Failed to save '{base}': {str(e)}"),
                            None,
                            [],
                            *_tail(pruned),
                        )

                # Append to CSV
                append_ratings(saved_rows)

                gallery_items = load_all_rated_images()
                pruned2 = prune_batch_queue(batch_state)

                return (
                    gr.update(visible=True, value=f"✅ Successfully saved {len(saved_rows)} ratings."),
                    str(RATINGS_CSV),
                    gallery_items,
                    *_tail(pruned2),
                )

            except Exception as e:
                import traceback

                pruned_e = prune_batch_queue(batch_state)
                return (
                    gr.update(visible=True, value=f"❌ Error: {str(e)}\n{traceback.format_exc()}"),
                    None,
                    [],
                    *_tail(pruned_e),
                )

        # Wire up events
        uploader_outputs = []
        for row, thumb, fname, score in score_inputs_list:
            uploader_outputs.extend([row, thumb, fname, score])
        uploader_outputs.append(files_state)
        
        uploader.upload(update_inputs, inputs=[uploader], outputs=uploader_outputs)
        
        save_inputs = [files_state, batch_selected_state] + [
            score for _, _, _, score in score_inputs_list
        ]
        save_btn.click(
            save,
            inputs=save_inputs,
            outputs=[
                status,
                download_csv,
                saved_gallery,
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
            ],
        )
        
        def download_csv_handler():
            csv_path = build_download_csv()
            return csv_path
        
        def refresh_gallery():
            """Refresh the gallery with all saved images."""
            return load_all_rated_images()
        
        def refresh_all(batch_state: List[str] | None):
            """Refresh main gallery, batch picker HTML, and pruned batch queue UI."""
            gallery = load_all_rated_images()
            pruned = prune_batch_queue(batch_state)
            return (
                gallery,
                build_batch_picker_html(pruned),
                json.dumps(pruned),
                pruned,
                *render_batch_queue_updates(pruned),
            )

        def on_startup():
            """Initialize gallery, batch picker HTML, recovery picker, queues."""
            gallery = load_all_rated_images()
            return (
                gallery,
                build_batch_picker_html([]),
                "[]",
                [],
                *render_batch_queue_updates([]),
                build_recover_picker_html([]),
                "[]",
                [],
            )

        def on_recover_proxy_change(proxy_value: str):
            try:
                names_in = json.loads(proxy_value or "[]")
            except Exception:
                names_in = []
            if not isinstance(names_in, list):
                names_in = []
            allowed = set(get_deleted_image_names())
            new_names: List[str] = []
            for n in names_in:
                if isinstance(n, str) and n in allowed and n not in new_names:
                    new_names.append(n)
            return new_names

        def clear_recover_queue_fn():
            return ([], build_recover_picker_html([]), "[]")

        def refresh_recover_picker(state: List[str] | None):
            pr = prune_recover_queue(state)
            return (build_recover_picker_html(pr), json.dumps(pr), pr)

        def refresh_batch_picker(state: List[str] | None):
            pr = prune_batch_queue(state)
            return (
                build_batch_picker_html(pr),
                json.dumps(pr),
                pr,
                *render_batch_queue_updates(pr),
            )

        def handle_recover(state: List[str] | None):
            sel = list(state or [])
            if not sel:
                return (
                    gr.update(visible=True, value="❌ Add deleted images to the recovery queue first."),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                )
            count, detail = recover_deleted_images_batch(sel)
            if count <= 0:
                return (
                    gr.update(visible=True, value=f"❌ {detail}"),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                )
            gallery_items = load_all_rated_images()
            return (
                gr.update(visible=True, value=f"✅ {detail}"),
                gr.update(value=gallery_items, selected_index=None),
                build_recover_picker_html([]),
                "[]",
                [],
            )

        def handle_purge(state: List[str] | None):
            sel = list(state or [])
            if not sel:
                return (
                    gr.update(visible=True, value="❌ Add deleted images to the recovery queue first."),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                )
            count, detail = purge_deleted_images_batch(sel)
            if count <= 0:
                return (
                    gr.update(visible=True, value=f"❌ {detail}"),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                )
            return (
                gr.update(visible=True, value=f"✅ {detail}"),
                build_recover_picker_html([]),
                "[]",
                [],
            )

        def handle_batch_delete(batch_state: List[str] | None):
            selected = list(batch_state or [])
            if not selected:
                return (
                    gr.update(visible=True, value="❌ Add images to the batch queue first."),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    *([gr.skip()] * len(batch_queue_outputs_flat)),
                )
            count, detail = delete_images_and_ratings_batch(selected)
            if count <= 0:
                return (
                    gr.update(visible=True, value=f"❌ {detail}"),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    *([gr.skip()] * len(batch_queue_outputs_flat)),
                )
            gallery_items = load_all_rated_images()
            return (
                gr.update(visible=True, value=f"✅ {detail}"),
                gr.update(value=gallery_items, selected_index=None),
                build_batch_picker_html([]),
                "[]",
                [],
                *render_batch_queue_updates([]),
            )

        def handle_batch_apply_scores(batch_state: List[str] | None, scores_json: str):
            names = list(batch_state or [])
            nmax = len(batch_rows_list)
            try:
                parsed = json.loads(scores_json or "[]")
                if not isinstance(parsed, list):
                    parsed = []
            except Exception:
                parsed = []
            batch_scores = list(parsed)
            if not names:
                return (
                    gr.update(visible=True, value="❌ Add images to the batch queue first."),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    [],
                    *render_batch_queue_updates([]),
                )
            pairs: List[Tuple[str, float]] = []
            for i, nm in enumerate(names[:nmax]):
                raw = batch_scores[i] if i < len(batch_scores) else None
                if raw is None or raw == "":
                    raw = get_image_score(nm)
                pairs.append((nm, raw))
            ok, msg, _cnt = batch_update_image_scores_per_image(pairs)
            if not ok:
                pr = prune_batch_queue(names)
                return (
                    gr.update(visible=True, value=f"❌ {msg}"),
                    gr.skip(),
                    gr.skip(),
                    gr.skip(),
                    pr,
                    *render_batch_queue_updates(pr),
                )
            gallery_items = load_all_rated_images()
            pr = prune_batch_queue(names)
            return (
                gr.update(visible=True, value=f"✅ {msg}"),
                gr.update(value=gallery_items, selected_index=None),
                build_batch_picker_html(pr),
                json.dumps(pr),
                pr,
                *render_batch_queue_updates(pr),
            )
        
        dl_btn.click(download_csv_handler, outputs=[download_csv])
        refresh_gallery_btn.click(
            refresh_all,
            inputs=[batch_selected_state],
            outputs=[
                saved_gallery,
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
            ],
        )

        batch_state_proxy.change(
            on_proxy_state_change,
            inputs=[batch_state_proxy],
            outputs=[batch_selected_state, *batch_queue_outputs_flat],
        )
        batch_clear_btn.click(
            clear_batch_queue_fn,
            outputs=[
                batch_selected_state,
                batch_picker_html,
                batch_state_proxy,
                *batch_queue_outputs_flat,
            ],
        )

        batch_delete_btn.click(
            fn=handle_batch_delete,
            inputs=[batch_selected_state],
            outputs=[
                batch_status,
                saved_gallery,
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
            ],
            js="() => { if (!confirm('Delete all images in the batch queue? This cannot be undone.')) { throw new Error('cancelled'); } }",
        ).then(
            refresh_recover_picker,
            inputs=[recover_selected_state],
            outputs=[recover_picker_html, recover_state_proxy, recover_selected_state],
        )

        batch_apply_score_inputs = [batch_selected_state, batch_scores_proxy]
        batch_update_scores_btn.click(
            fn=handle_batch_apply_scores,
            inputs=batch_apply_score_inputs,
            outputs=[
                batch_status,
                saved_gallery,
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
            ],
            js="(_proxy) => { if (!confirm('Apply the score from each row to its queued image?')) { throw new Error('cancelled'); } var vals=[]; for (var i=0;i<15;i++){ var el=document.querySelector('#bp_row_score_'+i+' input'); if(!el){vals.push(null);continue;} var v=el.value; if(v===''||v==null){vals.push(null);} else { var f=parseFloat(v); vals.push(isNaN(f)?null:f); } } return [JSON.stringify(vals)]; }",
        )

        demo.load(
            on_startup,
            outputs=[
                saved_gallery,
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
                recover_picker_html,
                recover_state_proxy,
                recover_selected_state,
            ],
        )

        recover_state_proxy.change(
            on_recover_proxy_change,
            inputs=[recover_state_proxy],
            outputs=[recover_selected_state],
        )
        recover_clear_btn.click(
            clear_recover_queue_fn,
            outputs=[recover_selected_state, recover_picker_html, recover_state_proxy],
        )
        recover_refresh_btn.click(
            refresh_recover_picker,
            inputs=[recover_selected_state],
            outputs=[recover_picker_html, recover_state_proxy, recover_selected_state],
        )
        recover_btn.click(
            fn=handle_recover,
            inputs=[recover_selected_state],
            outputs=[
                recover_status,
                saved_gallery,
                recover_picker_html,
                recover_state_proxy,
                recover_selected_state,
            ],
            js="() => { if (!confirm('Recover the queued images back into uploads/ and ratings.csv?')) { throw new Error('cancelled'); } }",
        ).then(
            refresh_batch_picker,
            inputs=[batch_selected_state],
            outputs=[
                batch_picker_html,
                batch_state_proxy,
                batch_selected_state,
                *batch_queue_outputs_flat,
            ],
        )
        purge_btn.click(
            fn=handle_purge,
            inputs=[recover_selected_state],
            outputs=[
                recover_status,
                recover_picker_html,
                recover_state_proxy,
                recover_selected_state,
            ],
            js="() => { if (!confirm('Permanently delete the queued images? This CANNOT be undone.')) { throw new Error('cancelled'); } }",
        )

    return demo


if __name__ == "__main__":
    app = make_app()
    app.launch(
        server_port=7009,
        server_name="0.0.0.0",
        allowed_paths=[str(UPLOADS_DIR)],
    )
