#!/usr/bin/env python3
"""Measure MT5 saturation from multi-EA scheduler utilization samples."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_STATE = Path(r"D:\QM\Reports\pipeline\multi_ea_scheduler_state.json")


def _parse_ts(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)


def evaluate_saturation(samples: list[dict[str, Any]], *, min_ratio: float, min_minutes: int, now: datetime) -> dict[str, Any]:
    cutoff = now.timestamp() - (min_minutes * 60)
    ratios: list[float] = []
    for sample in samples:
        if not isinstance(sample, dict):
            continue
        ts = str(sample.get("ts_utc", "")).strip()
        ratio = sample.get("active_ratio")
        if not ts or not isinstance(ratio, (int, float)):
            continue
        try:
            epoch = _parse_ts(ts).timestamp()
        except Exception:
            continue
        if epoch >= cutoff:
            ratios.append(float(ratio))

    avg_ratio = sum(ratios) / len(ratios) if ratios else 0.0
    verdict = "PASS" if ratios and avg_ratio >= min_ratio else "FAIL"
    return {
        "verdict": verdict,
        "window_minutes": min_minutes,
        "sample_count": len(ratios),
        "avg_active_ratio": avg_ratio,
        "avg_active_percent": avg_ratio * 100.0,
        "threshold_ratio": min_ratio,
        "threshold_percent": min_ratio * 100.0,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate MT5 terminal saturation from scheduler state")
    parser.add_argument("--state", type=Path, default=DEFAULT_STATE)
    parser.add_argument("--min-ratio", type=float, default=0.5)
    parser.add_argument("--min-minutes", type=int, default=5)
    parser.add_argument("--out", type=Path, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = json.loads(args.state.read_text(encoding="utf-8"))
    samples = payload.get("utilization_samples", []) if isinstance(payload, dict) else []
    result = evaluate_saturation(samples, min_ratio=args.min_ratio, min_minutes=args.min_minutes, now=datetime.now(timezone.utc))

    text = json.dumps(result, sort_keys=True)
    print(text)
    if args.out is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
