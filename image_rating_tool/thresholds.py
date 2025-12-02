import json
import os
from typing import Dict, List, Tuple

import pandas as pd


def compute_thresholds(train_csv_path: str) -> Dict[str, float]:
    """Compute fixed quintile thresholds from the training CSV (quality_mos).

    Returns a dict with keys: q20, q40, q60, q80.
    """
    df = pd.read_csv(train_csv_path)
    if "quality_mos" not in df.columns:
        raise ValueError("train.csv must contain a 'quality_mos' column")

    s = pd.to_numeric(df["quality_mos"], errors="coerce").dropna()
    if s.empty:
        raise ValueError("No valid numeric values found in 'quality_mos'")

    q20 = float(s.quantile(0.20))
    q40 = float(s.quantile(0.40))
    q60 = float(s.quantile(0.60))
    q80 = float(s.quantile(0.80))

    thresholds = {"q20": q20, "q40": q40, "q60": q60, "q80": q80}
    return thresholds


def label_score(score: float, thresholds: Dict[str, float]) -> str:
    """Map a score in [0,1] to a discrete level using thresholds."""
    q20 = thresholds["q20"]
    q40 = thresholds["q40"]
    q60 = thresholds["q60"]
    q80 = thresholds["q80"]

    if score < q20:
        return "Bad"
    if score < q40:
        return "Poor"
    if score < q60:
        return "Fair"
    if score < q80:
        return "Good"
    return "Excellent"


def format_ranges(thresholds: Dict[str, float]) -> List[Tuple[str, str]]:
    """Return human-readable ranges for each level as (level, range_str)."""
    q20 = thresholds["q20"]
    q40 = thresholds["q40"]
    q60 = thresholds["q60"]
    q80 = thresholds["q80"]

    def r(v: float) -> str:
        return f"{v:.3f}"

    ranges = [
        ("Bad", f"< {r(q20)}"),
        ("Poor", f"{r(q20)} – < {r(q40)}"),
        ("Fair", f"{r(q40)} – < {r(q60)}"),
        ("Good", f"{r(q60)} – < {r(q80)}"),
        ("Excellent", f"≥ {r(q80)}"),
    ]
    return ranges


def save_thresholds_json(thresholds: Dict[str, float], out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(thresholds, f, indent=2)


def load_thresholds_json(in_path: str) -> Dict[str, float]:
    with open(in_path, "r", encoding="utf-8") as f:
        return json.load(f)


