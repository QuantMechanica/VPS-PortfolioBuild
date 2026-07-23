#!/usr/bin/env python3
"""Monitor scheduler state for a fixed window and evaluate saturation threshold."""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


def _parse(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)


def evaluate_window(samples: list[dict[str, Any]], *, window_start: datetime, window_end: datetime, min_ratio: float) -> dict[str, Any]:
    ratios: list[float] = []
    for sample in samples:
        if not isinstance(sample, dict):
            continue
        ts = str(sample.get("ts_utc", "")).strip()
        ratio = sample.get("active_ratio")
        if not ts or not isinstance(ratio, (int, float)):
            continue
        try:
            at = _parse(ts)
        except Exception:
            continue
        if window_start <= at <= window_end:
            ratios.append(float(ratio))
    avg = (sum(ratios) / len(ratios)) if ratios else 0.0
    verdict = "PASS" if ratios and avg >= min_ratio else "FAIL"
    return {
        "verdict": verdict,
        "window_start_utc": window_start.isoformat().replace("+00:00", "Z"),
        "window_end_utc": window_end.isoformat().replace("+00:00", "Z"),
        "sample_count": len(ratios),
        "avg_active_ratio": avg,
        "avg_active_percent": avg * 100.0,
        "threshold_ratio": min_ratio,
        "threshold_percent": min_ratio * 100.0,
    }


def _load_samples(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        return []
    raw = payload.get("utilization_samples", [])
    return raw if isinstance(raw, list) else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Monitor MT5 saturation over fixed duration")
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--duration-minutes", type=int, default=5)
    parser.add_argument("--min-ratio", type=float, default=0.5)
    parser.add_argument("--poll-seconds", type=int, default=30)
    parser.add_argument("--no-wait", action="store_true")
    parser.add_argument("--out", type=Path, default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=args.duration_minutes)

    if not args.no_wait:
        target_end = end + timedelta(minutes=args.duration_minutes)
        while datetime.now(timezone.utc) < target_end:
            time.sleep(max(args.poll_seconds, 1))
        end = datetime.now(timezone.utc)
        start = end - timedelta(minutes=args.duration_minutes)

    samples = _load_samples(args.state)
    result = evaluate_window(samples, window_start=start, window_end=end, min_ratio=args.min_ratio)
    text = json.dumps(result, sort_keys=True)
    print(text)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + "\n", encoding="utf-8")
    return 0 if result["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
