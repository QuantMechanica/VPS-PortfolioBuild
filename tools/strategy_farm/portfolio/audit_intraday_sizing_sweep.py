#!/usr/bin/env python3
"""Round 5 Part A: the sweep gap (S1) and the holdout confound (S2), on one reproducible harness.

Why this file exists at all
---------------------------
Revisions 2 to 4 of the audit were computed inline. Every number in them is therefore unreproducible
by anyone but the session that produced it, which is precisely the property Round 5 section 5 forbids
for anything the analysis rests on. This script is the reconstruction, and it is checked: it
recomputes the rev4 anchors and refuses to report unless they match.

Anchors reproduced exactly (see --selftest):
    21 sleeves, 2128 trading days, span 3004 calendar days
    worst joint day on close basis   -6.95 %
    worst joint day on MAE floor     -9.32 %
    days at or below -5 %            20 close basis / 237 MAE floor
    pass rate at 1.00x               39/50 = 78 %   and 29/36 = 81 % on the complete book
    calendar halves at 1.00x         18/25 = 72 %   and 21/25 = 84 %

One anchor does NOT reproduce and is reported rather than hidden: rev4 quotes 26 % for the MAE floor
at 1.00x, this harness computes 28 % (14 of 50 rather than 13). Every close-basis figure matches to
the window, so the difference sits inside the floor variant alone and is one window out of fifty. It
changes no conclusion -- both readings say the floor at 1.00x is far below target -- but rev5 carries
28 % because 28 % is the number that can be recomputed.

S1 -- the sweep gap
-------------------
rev4 measured the intraday effect at two support points only: 0 points at 0.44x, up to 52 points at
1.00x. The 0.90x recommendation sits between them, in a region where the function is demonstrably
steep, and the claim that 0.90x neutralises the intraday uncertainty was an interpolation.

This computes both curves on the same fine grid and reports the quantity that actually supports a
sizing decision: the largest multiplier at which the two measurement methods still agree. Below it,
the pass rate does not depend on which method is right. Above it, the recommendation is a bet on the
method.

S2 -- the holdout confound
--------------------------
rev4 read 67 % against 94 % as "first half of the complete book against second half". That split is
by position in the complete-window list, not by calendar time, and the complete list's first half
reaches into calendar windows 30 and 31. The honest construction is a two-by-two of calendar half by
book completeness, which is computed here.

Measurement conventions, all inherited unchanged from the engine
----------------------------------------------------------------
Sleeve set, gate filtering and the active-day notion come from challenge_book_60d. Accounts: 100k,
-5 % daily, -10 % static total, +10 % target, minimum 4 trading days, 60 calendar days, first touch
(the window ends the moment the target is touched). Windows are non-overlapping 60-calendar-day
blocks from the first trading day, which yields 50.

The MAE floor sums, per calendar day, the maximum adverse excursion of every trade closing that day.
It assumes perfect simultaneity of all excursions and attributes multi-day excursions to the close
day. Both assumptions are wrong in a known direction -- it is a lower bound, not an estimate, and
rev4's caveat on it stands unchanged.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import io
import json
import math
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

ACCOUNT = 100_000.0
DAILY_CAP = 0.05
TOTAL_CAP = 0.10
TARGET = 0.10
MIN_TRADING_DAYS = 4
WINDOW_DAYS = 60
AGREEMENT_PP = 5.0
SCHEMA = "qm.audit-intraday-sizing-sweep/v1"

GRID = (0.44, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85,
        0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.30)


def engine():
    with contextlib.redirect_stdout(io.StringIO()):
        import challenge_book_60d as cb
    return cb


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return (float("nan"), float("nan"))
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return ((c - h) / d, (c + h) / d)


class Book:
    """Daily joint series plus the window grid. Nothing here depends on the multiplier."""

    def __init__(self, cb) -> None:
        close_pnl: dict[dt.date, float] = defaultdict(float)
        mae_pnl: dict[dt.date, float] = defaultdict(float)
        for key in cb.keys:
            for _entry, close, net, mae in cb.sleeves[key]:
                close_pnl[close] += net
                mae_pnl[close] += mae
        self.sleeves = list(cb.keys)
        self.close = dict(close_pnl)
        self.mae = dict(mae_pnl)
        self.days = sorted(close_pnl)
        first, last = cb.all_days[0], cb.all_days[-1]
        self.span_days = (last - first).days
        starts = []
        cur = first
        while cur + dt.timedelta(days=WINDOW_DAYS) <= last + dt.timedelta(days=1):
            starts.append(cur)
            cur = cur + dt.timedelta(days=WINDOW_DAYS)
        self.starts = starts
        # "complete book" = every sleeve trades at least once inside the window. This is the
        # definition that reproduces rev4's 36; the span-based alternatives give 38.
        self.complete = [
            all(any(s <= d < s + dt.timedelta(days=WINDOW_DAYS) for d in cb.active[k])
                for k in cb.keys)
            for s in starts
        ]

    def run(self, start: dt.date, mult: float, *, floor: bool) -> str:
        equity = 0.0
        traded = 0
        end = start + dt.timedelta(days=WINDOW_DAYS)
        for day in self.days:
            if day < start:
                continue
            if day >= end:
                break
            realised = self.close[day] * mult
            low = (self.mae[day] * mult) if floor else min(0.0, realised)
            traded += 1
            if low <= -DAILY_CAP * ACCOUNT or equity + low <= -TOTAL_CAP * ACCOUNT:
                return "breach"
            equity += realised
            if equity >= TARGET * ACCOUNT and traded >= MIN_TRADING_DAYS:
                return "pass"
        return "expired"

    def rates(self, mult: float, *, floor: bool) -> dict[str, Any]:
        outcomes = [self.run(s, mult, floor=floor) for s in self.starts]
        passes = [o == "pass" for o in outcomes]
        comp = [p for p, c in zip(passes, self.complete) if c]
        return {
            "all_n": len(passes), "all_k": sum(passes),
            "complete_n": len(comp), "complete_k": sum(comp),
            "breach_all": sum(1 for o in outcomes if o == "breach"),
            "outcomes": outcomes,
        }


def sweep(book: Book) -> list[dict[str, Any]]:
    rows = []
    for m in GRID:
        c = book.rates(m, floor=False)
        f = book.rates(m, floor=True)
        c_rate = c["all_k"] / c["all_n"]
        f_rate = f["all_k"] / f["all_n"]
        c_comp = c["complete_k"] / c["complete_n"]
        f_comp = f["complete_k"] / f["complete_n"]
        rows.append({
            "multiplier": m,
            "close_all": c_rate, "mae_all": f_rate,
            "gap_all_pp": 100.0 * (c_rate - f_rate),
            "close_complete": c_comp, "mae_complete": f_comp,
            "gap_complete_pp": 100.0 * (c_comp - f_comp),
            "close_k": c["all_k"], "mae_k": f["all_k"], "n": c["all_n"],
            "breach_close": c["breach_all"], "breach_mae": f["breach_all"],
        })
    return rows


def agreement_multiplier(rows: list[dict[str, Any]], pp: float = AGREEMENT_PP) -> dict[str, Any]:
    """Largest multiplier at which both methods still agree, and the first one where they do not.

    Reported as a run from the bottom of the grid rather than a maximum over the whole grid: a grid
    point above a divergence that happens to agree again is not evidence that the region is safe.
    """
    last_ok = None
    first_bad = None
    for r in rows:
        if abs(r["gap_all_pp"]) <= pp and first_bad is None:
            last_ok = r["multiplier"]
        elif first_bad is None:
            first_bad = r["multiplier"]
    return {"threshold_pp": pp, "largest_agreeing_multiplier": last_ok,
            "first_diverging_multiplier": first_bad}


def crosstab(book: Book, mult: float = 1.00) -> dict[str, Any]:
    """Calendar half by book completeness, at one multiplier, close basis."""
    res = book.rates(mult, floor=False)
    passes = [o == "pass" for o in res["outcomes"]]
    half = len(book.starts) // 2
    cells: dict[str, dict[str, Any]] = {}
    for hname, idx in (("calendar_first_half", range(0, half)),
                       ("calendar_second_half", range(half, len(book.starts)))):
        for cname, want in (("complete", True), ("incomplete", False)):
            sel = [i for i in idx if book.complete[i] is want]
            k = sum(1 for i in sel if passes[i])
            lo, hi = wilson(k, len(sel))
            cells[f"{hname}|{cname}"] = {"n": len(sel), "k": k,
                                         "rate": (k / len(sel)) if sel else None,
                                         "wilson": [lo, hi],
                                         "window_index": sel}
    comp_idx = [i for i, c in enumerate(book.complete) if c]
    m = len(comp_idx) // 2
    rev4_first = comp_idx[:m]
    overlap = {
        "complete_windows": len(comp_idx),
        "complete_in_calendar_second_half": sum(1 for i in comp_idx if i >= half),
        "share_of_complete_in_second_half": sum(1 for i in comp_idx if i >= half) / len(comp_idx),
        "rev4_complete_first_half_indices": rev4_first,
        "rev4_complete_first_half_max_index": max(rev4_first),
        "rev4_first_half_windows_actually_in_calendar_second_half":
            sum(1 for i in rev4_first if i >= half),
        "incomplete_windows_in_calendar_first_half": sum(
            1 for i in range(0, half) if not book.complete[i]),
        "incomplete_windows_in_calendar_second_half": sum(
            1 for i in range(half, len(book.starts)) if not book.complete[i]),
    }
    return {"multiplier": mult, "cells": cells, "overlap": overlap}


ANCHORS = {
    "sleeves": 21, "trading_days": 2128, "span_calendar_days": 3004,
    "worst_close_pct": -6.95, "worst_mae_pct": -9.32,
    "close_days_le_5pct": 20, "mae_days_le_5pct": 237,
    "pass_all_1x": 39, "pass_complete_1x": 29,
    "pass_first_half_1x": 18, "pass_second_half_1x": 21,
}


def selftest(book: Book) -> dict[str, Any]:
    got = {
        "sleeves": len(book.sleeves),
        "trading_days": len(book.days),
        "span_calendar_days": book.span_days,
        "worst_close_pct": round(min(book.close.values()) / ACCOUNT * 100, 2),
        "worst_mae_pct": round(min(book.mae.values()) / ACCOUNT * 100, 2),
        "close_days_le_5pct": sum(1 for v in book.close.values() if v <= -0.05 * ACCOUNT),
        "mae_days_le_5pct": sum(1 for v in book.mae.values() if v <= -0.05 * ACCOUNT),
    }
    res = book.rates(1.00, floor=False)
    passes = [o == "pass" for o in res["outcomes"]]
    half = len(book.starts) // 2
    got["pass_all_1x"] = res["all_k"]
    got["pass_complete_1x"] = res["complete_k"]
    got["pass_first_half_1x"] = sum(passes[:half])
    got["pass_second_half_1x"] = sum(passes[half:])
    mismatch = {k: {"expected": v, "got": got[k]} for k, v in ANCHORS.items() if got[k] != v}
    return {"anchors_expected": ANCHORS, "anchors_got": got, "mismatch": mismatch,
            "reproduced": not mismatch}


def stream_fingerprint(cb) -> str:
    """Hash of the sleeve set and their trade counts -- the identity of the data this ran on."""
    h = hashlib.sha256()
    for k in sorted(cb.keys):
        h.update(f"{k}:{len(cb.sleeves[k])}:".encode())
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description="Round 5 Part A: sweep gap and holdout confound")
    ap.add_argument("--json-out", type=Path)
    ap.add_argument("--selftest", action="store_true", help="only verify the rev4 anchors")
    ap.add_argument("--allow-anchor-mismatch", action="store_true")
    args = ap.parse_args()

    cb = engine()
    book = Book(cb)
    st = selftest(book)
    if args.selftest:
        print(json.dumps(st, indent=1))
        return 0 if st["reproduced"] else 1
    if not st["reproduced"] and not args.allow_anchor_mismatch:
        print(json.dumps({"error": "rev4 anchors do not reproduce; refusing to report",
                          "selftest": st}, indent=1))
        return 1

    rows = sweep(book)
    agree = agreement_multiplier(rows)
    ct = crosstab(book)
    out = {
        "schema_version": SCHEMA,
        "stream_fingerprint": stream_fingerprint(cb),
        "sleeves": book.sleeves,
        "window_days": WINDOW_DAYS,
        "windows": len(book.starts),
        "complete_windows": sum(book.complete),
        "selftest": st,
        "sweep": rows,
        "agreement": agree,
        "crosstab": ct,
    }
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n",
                                 encoding="utf-8")

    print(f"anchors reproduced: {st['reproduced']}")
    print(f"{'mult':>6}{'close 50':>11}{'MAE 50':>10}{'gap pp':>9}"
          f"{'close 36':>11}{'MAE 36':>10}{'gap pp':>9}")
    print("-" * 66)
    for r in rows:
        print(f"{r['multiplier']:>6.2f}{r['close_all']:>11.0%}{r['mae_all']:>10.0%}"
              f"{r['gap_all_pp']:>9.0f}{r['close_complete']:>11.0%}"
              f"{r['mae_complete']:>10.0%}{r['gap_complete_pp']:>9.0f}")
    print()
    print(f"largest multiplier where both methods agree within {AGREEMENT_PP:.0f} pp: "
          f"{agree['largest_agreeing_multiplier']}   "
          f"first divergence at {agree['first_diverging_multiplier']}")
    print()
    print("calendar half x book completeness, close basis, 1.00x:")
    for name, cell in ct["cells"].items():
        rate = "n/a" if cell["rate"] is None else f"{cell['rate']:.0%}"
        print(f"  {name:34} n={cell['n']:>3}  pass={cell['k']:>3}  {rate:>5}"
              f"  Wilson [{cell['wilson'][0]:.2f}-{cell['wilson'][1]:.2f}]")
    ov = ct["overlap"]
    print(f"  overlap: {ov['complete_in_calendar_second_half']} of {ov['complete_windows']} "
          f"complete windows lie in the calendar second half "
          f"({ov['share_of_complete_in_second_half']:.0%})")
    print(f"  rev4 'complete first half' contained "
          f"{ov['rev4_first_half_windows_actually_in_calendar_second_half']} windows that are "
          f"calendar second half")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
