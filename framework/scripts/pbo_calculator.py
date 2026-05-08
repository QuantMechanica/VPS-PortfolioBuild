#!/usr/bin/env python3
"""Deterministic CSCV-based PBO calculator for pipeline P7 inputs.

Input CSV must contain one row per (config_id, slice_id) pair with a numeric score.
The score should be the objective metric used in the sweep ranking (higher is better).
"""
from __future__ import annotations

import argparse
import csv
import itertools
import json
from collections import defaultdict
from pathlib import Path


def _load_scores(path: Path, config_col: str, slice_col: str, score_col: str) -> dict[str, dict[str, float]]:
    by_config: dict[str, dict[str, float]] = defaultdict(dict)
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            cfg = (row.get(config_col) or "").strip()
            slc = (row.get(slice_col) or "").strip()
            raw = (row.get(score_col) or "").strip()
            if not cfg or not slc or raw == "":
                continue
            by_config[cfg][slc] = float(raw)
    return dict(by_config)


def _rank_percentile_desc(values: dict[str, float], key: str) -> float:
    ordered = sorted(values.items(), key=lambda kv: kv[1], reverse=True)
    n = len(ordered)
    if n <= 1:
        return 1.0
    pos = next((i + 1 for i, (k, _) in enumerate(ordered) if k == key), n)
    # Best OOS rank should map near 1.0, worst near 0.0.
    return float(n - pos + 1) / float(n)


def compute_pbo(scores: dict[str, dict[str, float]]) -> dict[str, float | int]:
    if not scores:
        return {"pbo_pct": 100.0, "splits_evaluated": 0, "overfit_splits": 0}
    common_slices = set.intersection(*(set(v.keys()) for v in scores.values()))
    if len(common_slices) < 2 or (len(common_slices) % 2) != 0:
        return {"pbo_pct": 100.0, "splits_evaluated": 0, "overfit_splits": 0}

    slices = sorted(common_slices)
    half = len(slices) // 2
    split_combos = list(itertools.combinations(slices, half))
    seen = set()
    valid_splits = []
    for combo in split_combos:
        left = tuple(combo)
        right = tuple(sorted(set(slices) - set(combo)))
        key = (left, right) if left <= right else (right, left)
        if key in seen:
            continue
        seen.add(key)
        valid_splits.append(key)

    overfit = 0
    evaluated = 0
    for is_slices, oos_slices in valid_splits:
        is_perf = {}
        oos_perf = {}
        for cfg, cfg_scores in scores.items():
            is_perf[cfg] = sum(cfg_scores[s] for s in is_slices) / float(len(is_slices))
            oos_perf[cfg] = sum(cfg_scores[s] for s in oos_slices) / float(len(oos_slices))
        best_is_cfg = max(is_perf.items(), key=lambda kv: kv[1])[0]
        omega = _rank_percentile_desc(oos_perf, best_is_cfg)
        # CSCV overfit event: out-of-sample rank in lower half (logit(omega) <= 0).
        if omega <= 0.5:
            overfit += 1
        evaluated += 1

    if evaluated == 0:
        return {"pbo_pct": 100.0, "splits_evaluated": 0, "overfit_splits": 0}
    return {
        "pbo_pct": round(100.0 * (overfit / float(evaluated)), 6),
        "splits_evaluated": evaluated,
        "overfit_splits": overfit,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Compute PBO% from CSCV sweep score rows.")
    ap.add_argument("--input", required=True, help="CSV with config_id, slice_id, score")
    ap.add_argument("--out", required=True, help="Output JSON file path")
    ap.add_argument("--config-col", default="config_id")
    ap.add_argument("--slice-col", default="slice_id")
    ap.add_argument("--score-col", default="score")
    args = ap.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.out)
    scores = _load_scores(in_path, args.config_col, args.slice_col, args.score_col)
    result = compute_pbo(scores)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(str(out_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
