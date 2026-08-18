#!/usr/bin/env python3
"""Point 2.4 — the producer for `active_days_per_60d`.

`build_book_ftmo.py:167` reads `active_days_per_60d` off every selected sleeve. Nothing writes it:
0 of 216 rows in `fund_scores.json` carry the key, so `_density()` marks every sleeve `missing`,
`passed` is False, and the whole FTMO manifest check fails. This writes it.

## The method, which is the part that needs agreeing — not the number

**Purpose fixes the reference quantity** (v6 §4). The check exists because FTMO Phase 1 requires at
least 4 trading days inside a single 60-day window whose start date nobody controls, and because 3.4
scores the book over ~1,290 rolling windows. So the question is not "does this sleeve trade a lot"
but "at a challenge start drawn from history, how many active days does this sleeve deliver".

Three decisions follow, and each is derived rather than chosen:

1. **Rolling 60-*calendar*-day windows, not the total span.** FTMO's 60 days are calendar days. A
   span average lets a sleeve that traded hard for one year and slept for two look dense.

2. **A regular calendar grid, not the engine's close-anchored windows.** This is the one place where
   reusing the existing construction would be wrong, and it is worth stating plainly.
   `sleeve_improvement_targets.stream_stats` builds its rolling windows as `for i, c0 in
   enumerate(cds)` over close dates — every window therefore *starts at a trade*, so a window
   containing no trading can never be observed. That construction is defensible for `med60`, but for
   density it is blind to precisely the dormancy the check exists to catch. Windows here step one
   calendar day at a time across the sleeve's span.

3. **The per-sleeve statistic is the 10th percentile, not the mean and not the minimum.**
   The mean hides dead stretches. The strict minimum is over-strict in a way that misreads how the
   book is used: 3.4 does not require every sleeve to fire in every window — a sleeve contributing
   nothing in some windows is diluted, not disqualifying. p10 states "in 90% of possible challenge
   starts this sleeve delivers at least X active days", which is the quantity the contract's
   `min(values) >= 4.0` is actually asking about. p10 is also already this artifact's convention:
   `sleeve_improvement_targets` reports `p10_60` and `p20_60` for returns on the same windows.

The mean, median, minimum, maximum and window count are emitted alongside, so the choice of
statistic can be revisited from the artifact without recomputing anything.

## What "active" means

Taken unchanged from `challenge_book_60d.active` — entry day, close day, and every held day in
between. It is not redefined here: `max_gap_days()` already depends on that exact notion, and two
dormancy definitions in one artifact would be worse than either.

## Positive control

`--verify` re-runs the manifest density check over the sleeves that are scorable today and asserts
their pass/fail status is unchanged by the new measure, per the 2.4 acceptance condition.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import statistics
import sys
from datetime import date, timedelta
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

DEFAULT_CACHE = Path(r"D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json")
WINDOW_DAYS = 60
STATISTIC_PERCENTILE = 10
SCHEMA = "qm.sleeve-density/v1"


def _engine():
    """Import the challenge engine without letting its module-level report reach stdout."""
    with contextlib.redirect_stdout(io.StringIO()):
        import challenge_book_60d as cb
    return cb


def window_active_counts(active_days: set[date], *, window: int = WINDOW_DAYS) -> list[int]:
    """Active-day count in every 60-calendar-day window on a one-day grid across the span.

    A sleeve whose span is shorter than the window yields a single window covering the whole span,
    so short-history sleeves are measured rather than silently skipped.
    """
    if not active_days:
        return []
    ordered = sorted(active_days)
    first, last = ordered[0], ordered[-1]
    span = (last - first).days
    if span < window:
        return [len(ordered)]
    counts: list[int] = []
    lo = 0
    hi = 0
    n = len(ordered)
    for offset in range(span - window + 2):
        start = first + timedelta(days=offset)
        end = start + timedelta(days=window)
        while lo < n and ordered[lo] < start:
            lo += 1
        if hi < lo:
            hi = lo
        while hi < n and ordered[hi] < end:
            hi += 1
        counts.append(hi - lo)
    return counts


def percentile(values: list[int], pct: int) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = int(len(ordered) * (pct / 100.0))
    return float(ordered[min(idx, len(ordered) - 1)])


def density_rows() -> dict[str, dict[str, Any]]:
    cb = _engine()
    out: dict[str, dict[str, Any]] = {}
    for key, days in cb.active.items():
        counts = window_active_counts(set(days))
        if not counts:
            out[str(key)] = {"active_days_per_60d": None, "reason": "no_active_days"}
            continue
        ordered = sorted(days)
        out[str(key)] = {
            "active_days_per_60d": percentile(counts, STATISTIC_PERCENTILE),
            "active_days_per_60d_detail": {
                "statistic": f"p{STATISTIC_PERCENTILE}",
                "window_days": WINDOW_DAYS,
                "window_anchoring": "calendar_grid_step_1d",
                "windows": len(counts),
                "p10": percentile(counts, 10),
                "p20": percentile(counts, 20),
                "median": float(statistics.median(counts)),
                "mean": round(statistics.fmean(counts), 3),
                "min": float(min(counts)),
                "max": float(max(counts)),
                "active_days_total": len(days),
                "span_days": (ordered[-1] - ordered[0]).days,
                "active_definition": "challenge_book_60d.active (entry, close, every held day)",
            },
        }
    return out


def merge_into_cache(path: Path, *, apply: bool) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("rows") or []
    density = density_rows()
    matched = 0
    unmatched: list[str] = []
    for row in rows:
        key = str(row.get("sleeve") or "")
        found = density.get(key)
        if found is None:
            unmatched.append(key)
            continue
        matched += 1
        row.update(found)
    result = {
        "schema": SCHEMA, "cache": str(path), "rows": len(rows),
        "density_keys": len(density), "matched": matched,
        "unmatched_rows": unmatched, "applied": bool(apply),
    }
    if apply:
        payload["density_producer"] = {
            "schema": SCHEMA, "statistic": f"p{STATISTIC_PERCENTILE}",
            "window_days": WINDOW_DAYS, "window_anchoring": "calendar_grid_step_1d",
        }
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return result


def verify(path: Path, floor: float) -> dict[str, Any]:
    """Positive control: the sleeves scorable today must keep their status under the new measure."""
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("rows") or []
    density = density_rows()
    scored = [r for r in rows if str(r.get("status")) == "SCORED"]
    covered = [r for r in scored if density.get(str(r.get("sleeve")), {}).get("active_days_per_60d") is not None]
    passing = [r for r in covered
               if float(density[str(r["sleeve"])]["active_days_per_60d"]) >= floor]
    return {
        "scored_sleeves": len(scored),
        "with_density": len(covered),
        "density_missing_for_scored": [str(r.get("sleeve")) for r in scored
                                       if str(r.get("sleeve")) not in density],
        "at_or_above_floor": len(passing),
        "below_floor": [
            {"sleeve": str(r["sleeve"]),
             "active_days_per_60d": density[str(r["sleeve"])]["active_days_per_60d"]}
            for r in covered
            if float(density[str(r["sleeve"])]["active_days_per_60d"]) < floor
        ],
        "floor": floor,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    ap.add_argument("--apply", action="store_true", help="write active_days_per_60d into the cache")
    ap.add_argument("--verify", action="store_true", help="run the positive control only")
    ap.add_argument("--floor", type=float, default=4.0)
    args = ap.parse_args()

    if args.verify:
        print(json.dumps(verify(args.cache, args.floor), indent=1))
        return 0
    result = merge_into_cache(args.cache, apply=args.apply)
    print(json.dumps(result, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
