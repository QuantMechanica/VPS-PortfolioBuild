#!/usr/bin/env python3
"""Round 6 section 1: can the equity measurement still turn the decision, or is it already decided?

The question
-----------
Before a recompile batch is paid for that discards the fleet's verdicts: is there ANY outcome of the
intraday measurement under which this book reaches the 80 % requirement?

The answer has a shape that makes it cheap. The true intraday curve lies between two computable
bounds. The MAE floor assumes perfect simultaneity and is provably too pessimistic; the close-price
curve assumes no intraday excursion beyond the close and is provably too optimistic. So the
**close-price curve is the best case the equity measurement can possibly produce.** If the ceiling
built on it is already below the requirement, the measurement can only say how far below - never
whether.

Four terms, in decreasing order of how well they are known
----------------------------------------------------------
1. CEILING - the best close-basis pass rate anywhere on the sizing grid. Measured.
2. FLIP - verdict instability. rev4 measured -6 pp at 1.00x on 36 windows; recomputed here at every
   multiplier in the chain, because there is no reason the effect is sizing-invariant (OQ-6).
3. POPULATION - the book is 21 sleeves, the pool is 91. Direction was asserted, never measured. It
   is bounded here by subsampling the existing book: if the pass rate rises as the book grows, a
   larger book helps; if it falls, it hurts. Both raw and exposure-normalised, because a smaller book
   carries less total risk and that confound would otherwise drive the whole curve.
4. SELECTION - the gates saw the whole history. Bounded here by the interval around the calendar
   difference measured in rev5 section 2, which is what limits how large a hidden downward bias can
   be without contradicting the observation.

OQ-5, the overlap-constrained MAE floor
----------------------------------------
Also computed here, because it belongs to the same question. The naive floor sums the MAE of every
trade closing on a day and so charges trades that were never open at the same moment. The streams
carry entry and close timestamps to the minute, so overlap is checkable: a sweep over interval
endpoints yields, per day, the deepest simultaneous sum

    min over event times t of [ realised P&L closed earlier that day + sum of MAE of trades open at t ]

which is still a lower bound - it assumes everything open reaches its own worst point together - but
only over trades that genuinely overlapped. Multi-day excursions are charged to every day the trade
is open rather than to the close day, which is the second rev4 caveat, also fixed.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import io
import json
import math
import random
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import audit_intraday_sizing_sweep as sw  # noqa: E402

ACCOUNT = sw.ACCOUNT
DAILY_CAP = sw.DAILY_CAP
TOTAL_CAP = sw.TOTAL_CAP
TARGET = sw.TARGET
MIN_TRADING_DAYS = sw.MIN_TRADING_DAYS
WINDOW_DAYS = sw.WINDOW_DAYS
REQUIREMENT = 0.80
SCHEMA = "qm.audit-upper-bound/v1"

FLIP_DRAWS = 1000
FLIP_REMOVE_SHARE = 0.21          # rev4 R4-5: 4 of 21
BOOK_SIZE_DRAWS = 300
SEED = 20260818


def wilson(k: int, n: int, z: float = 1.96) -> tuple[float, float]:
    return sw.wilson(k, n, z)


def newcombe_difference(k1: int, n1: int, k2: int, n2: int,
                        z: float = 1.96) -> tuple[float, float]:
    """Newcombe method 10 interval for p2 - p1, built from the two Wilson intervals.

    Used rather than a normal approximation because both cells are small (n = 14 and n = 22) and the
    normal interval misbehaves near the boundary - 18/22 is close enough to 1 to matter.
    """
    l1, u1 = wilson(k1, n1, z)
    l2, u2 = wilson(k2, n2, z)
    p1, p2 = k1 / n1, k2 / n2
    lo = (p2 - p1) - math.sqrt((p2 - l2) ** 2 + (u1 - p1) ** 2)
    hi = (p2 - p1) + math.sqrt((u2 - p2) ** 2 + (p1 - l1) ** 2)
    return lo, hi


class SleeveBook:
    """Per-sleeve daily series, so a sub-book can be assembled without re-reading the streams."""

    def __init__(self, cb) -> None:
        self.cb = cb
        self.keys = list(cb.keys)
        self.close: dict[str, dict[dt.date, float]] = {}
        self.mae: dict[str, dict[dt.date, float]] = {}
        for key in self.keys:
            c: dict[dt.date, float] = defaultdict(float)
            m: dict[dt.date, float] = defaultdict(float)
            for _entry, close, net, mae in cb.sleeves[key]:
                c[close] += net
                m[close] += mae
            self.close[key] = dict(c)
            self.mae[key] = dict(m)
        self.all_days = sorted({d for k in self.keys for d in self.close[k]})

    def combine(self, keys: list[str]) -> tuple[dict[dt.date, float], dict[dt.date, float]]:
        c: dict[dt.date, float] = defaultdict(float)
        m: dict[dt.date, float] = defaultdict(float)
        for k in keys:
            for d, v in self.close[k].items():
                c[d] += v
            for d, v in self.mae[k].items():
                m[d] += v
        return dict(c), dict(m)


class Sim:
    """Window simulator over a given daily series pair. Same rules as the rev5 harness."""

    def __init__(self, close: dict[dt.date, float], low: dict[dt.date, float],
                 starts: list[dt.date], complete: list[bool]) -> None:
        self.close = close
        self.low = low
        self.days = sorted(close)
        self.starts = starts
        self.complete = complete

    def run(self, start: dt.date, mult: float, *, use_low: bool) -> bool:
        equity = 0.0
        traded = 0
        end = start + dt.timedelta(days=WINDOW_DAYS)
        for day in self.days:
            if day < start:
                continue
            if day >= end:
                break
            realised = self.close[day] * mult
            floor = (self.low.get(day, 0.0) * mult) if use_low else min(0.0, realised)
            traded += 1
            if floor <= -DAILY_CAP * ACCOUNT or equity + floor <= -TOTAL_CAP * ACCOUNT:
                return False
            equity += realised
            if equity >= TARGET * ACCOUNT and traded >= MIN_TRADING_DAYS:
                return True
        return False

    def rate(self, mult: float, *, use_low: bool = False,
             complete_only: bool = False) -> tuple[int, int]:
        idx = [i for i in range(len(self.starts)) if (self.complete[i] or not complete_only)]
        k = sum(1 for i in idx if self.run(self.starts[i], mult, use_low=use_low))
        return k, len(idx)


# --------------------------------------------------------------------------- #
# Term 1 - the ceiling                                                          #
# --------------------------------------------------------------------------- #

def ceiling(sim: Sim, grid: tuple[float, ...]) -> dict[str, Any]:
    rows = []
    for m in grid:
        k50, n50 = sim.rate(m)
        k36, n36 = sim.rate(m, complete_only=True)
        rows.append({"multiplier": m, "all": k50 / n50, "all_k": k50, "all_n": n50,
                     "complete": k36 / n36, "complete_k": k36, "complete_n": n36})
    best_all = max(rows, key=lambda r: r["all"])
    best_comp = max(rows, key=lambda r: r["complete"])
    lo_a, hi_a = wilson(best_all["all_k"], best_all["all_n"])
    lo_c, hi_c = wilson(best_comp["complete_k"], best_comp["complete_n"])
    return {"grid": rows,
            "best_all": {**best_all, "wilson": [lo_a, hi_a]},
            "best_complete": {**best_comp, "wilson": [lo_c, hi_c]}}


# --------------------------------------------------------------------------- #
# Term 2 - flip instability, at every multiplier in the chain (closes OQ-6)     #
# --------------------------------------------------------------------------- #

def flip(book: SleeveBook, starts, complete, multipliers: tuple[float, ...],
         draws: int = FLIP_DRAWS) -> dict[str, Any]:
    rng = random.Random(SEED)
    n_remove = max(1, round(FLIP_REMOVE_SHARE * len(book.keys)))
    out = {}
    for m in multipliers:
        base_c, base_m = book.combine(book.keys)
        base = Sim(base_c, base_m, starts, complete)
        bk, bn = base.rate(m, complete_only=True)
        rates = []
        for _ in range(draws):
            keep = rng.sample(book.keys, len(book.keys) - n_remove)
            c, mm = book.combine(keep)
            k, n = Sim(c, mm, starts, complete).rate(m, complete_only=True)
            rates.append(k / n)
        rates.sort()
        median = rates[len(rates) // 2]
        out[f"{m:.2f}"] = {
            "base": bk / bn, "removed": n_remove, "draws": draws,
            "median": median, "p5": rates[int(0.05 * draws)], "p95": rates[int(0.95 * draws)],
            "min": rates[0], "max": rates[-1],
            "delta_pp": 100.0 * (median - bk / bn),
            "band_pp": 100.0 * (rates[int(0.95 * draws)] - rates[int(0.05 * draws)]),
        }
    return out


# --------------------------------------------------------------------------- #
# Term 3 - population, bounded by book-size scaling                             #
# --------------------------------------------------------------------------- #

def book_size_curve(book: SleeveBook, starts, complete, mult: float,
                    draws: int = BOOK_SIZE_DRAWS) -> dict[str, Any]:
    """Pass rate against book size, raw and exposure-normalised.

    Raw answers "what does a smaller book do", which conflates size with total risk: six sleeves at
    1.00x carry less than twenty-one at 1.00x. Normalised multiplies by 21/k so total exposure is
    held roughly constant, which is the question the population term actually asks - does spreading
    the same risk across more sleeves help or hurt?
    """
    rng = random.Random(SEED + 1)
    full = len(book.keys)
    rows = []
    for k_size in (6, 9, 12, 15, 18, full):
        raw, norm = [], []
        n_draws = 1 if k_size == full else draws
        for _ in range(n_draws):
            keep = book.keys if k_size == full else rng.sample(book.keys, k_size)
            c, m = book.combine(keep)
            sim = Sim(c, m, starts, complete)
            kk, nn = sim.rate(mult, complete_only=True)
            raw.append(kk / nn)
            kk2, nn2 = sim.rate(mult * full / k_size, complete_only=True)
            norm.append(kk2 / nn2)
        rows.append({"book_size": k_size, "draws": n_draws,
                     "raw_mean": sum(raw) / len(raw),
                     "normalised_mean": sum(norm) / len(norm)})
    first, last = rows[0], rows[-1]
    return {"multiplier": mult, "rows": rows,
            "raw_slope_pp_per_sleeve":
                100.0 * (last["raw_mean"] - first["raw_mean"]) / (last["book_size"] - first["book_size"]),
            "normalised_slope_pp_per_sleeve":
                100.0 * (last["normalised_mean"] - first["normalised_mean"]) / (last["book_size"] - first["book_size"])}


# --------------------------------------------------------------------------- #
# Term 4 - selection, bounded by the calendar difference within complete books  #
# --------------------------------------------------------------------------- #

def selection_bound(sim: Sim, mult: float) -> dict[str, Any]:
    half = len(sim.starts) // 2
    cells = {}
    for name, rng_ in (("first", range(0, half)), ("second", range(half, len(sim.starts)))):
        idx = [i for i in rng_ if sim.complete[i]]
        k = sum(1 for i in idx if sim.run(sim.starts[i], mult, use_low=False))
        cells[name] = {"k": k, "n": len(idx), "rate": k / len(idx) if idx else None,
                       "wilson": list(wilson(k, len(idx)))}
    lo, hi = newcombe_difference(cells["first"]["k"], cells["first"]["n"],
                                 cells["second"]["k"], cells["second"]["n"])
    return {"multiplier": mult, "cells": cells,
            "difference_second_minus_first_pp": 100.0 * (cells["second"]["rate"] - cells["first"]["rate"]),
            "newcombe_pp": [100.0 * lo, 100.0 * hi],
            "largest_hidden_downward_bias_pp": -100.0 * lo}


# --------------------------------------------------------------------------- #
# OQ-5 - the overlap-constrained MAE floor                                      #
# --------------------------------------------------------------------------- #

def overlap_floor(cb) -> dict[dt.date, float]:
    """Per day, the deepest simultaneous adverse sum, using real open intervals.

    Sweep-line over interval endpoints. At every event time inside a day the value considered is
    the P&L already realised that day plus the MAE of every position open at that instant. The
    extremum of a piecewise-constant function lies at an event, so the endpoints suffice.
    """
    events: dict[dt.date, list[tuple[dt.datetime, str, float, float]]] = defaultdict(list)
    open_before: dict[dt.date, float] = defaultdict(float)
    trades = []
    for key in cb.keys:
        for entry, close, net, mae in cb.sleeves[key]:
            trades.append((entry, close, net, mae))
    day_set = sorted({c for _e, c, _n, _m in trades})
    day_index = {d: i for i, d in enumerate(day_set)}
    for entry, close, net, mae in trades:
        e_day = entry if entry in day_index else close
        events[e_day].append((entry, "open", net, mae))
        events[close].append((close, "close", net, mae))
        i0, i1 = day_index.get(e_day, day_index[close]), day_index[close]
        for i in range(i0 + 1, i1):
            open_before[day_set[i]] += mae
    lows: dict[dt.date, float] = {}
    for day in day_set:
        carried = open_before.get(day, 0.0)
        evs = sorted(events.get(day, []), key=lambda x: (x[0], 0 if x[1] == "open" else 1))
        realised = 0.0
        open_mae = carried
        low = min(0.0, carried)
        for _t, kind, net, mae in evs:
            if kind == "open":
                open_mae += mae
            else:
                open_mae -= mae
                realised += net
            low = min(low, realised + open_mae)
        lows[day] = low
    return lows


def main() -> int:
    ap = argparse.ArgumentParser(description="Round 6 section 1 + OQ-5")
    ap.add_argument("--json-out", type=Path)
    args = ap.parse_args()

    with contextlib.redirect_stdout(io.StringIO()):
        cb = sw.engine()
    base = sw.Book(cb)
    book = SleeveBook(cb)
    starts, complete = base.starts, base.complete
    sim = Sim(base.close, base.mae, starts, complete)

    chain_mults = (0.50, 0.60, 0.85, 0.90, 1.00, 1.10)
    ceil = ceiling(sim, sw.GRID)
    fl = flip(book, starts, complete, chain_mults)
    pop = {f"{m:.2f}": book_size_curve(book, starts, complete, m) for m in (0.50, 0.85, 1.00)}
    sel = selection_bound(sim, 1.00)

    lows = overlap_floor(cb)
    naive = base.mae
    oq5_sim = Sim(base.close, lows, starts, complete)
    oq5 = []
    for m in sw.GRID:
        kc, nc = sim.rate(m)
        kn, nn = Sim(base.close, naive, starts, complete).rate(m, use_low=True)
        ko, no = oq5_sim.rate(m, use_low=True)
        oq5.append({"multiplier": m, "close": kc / nc, "naive_floor": kn / nn,
                    "overlap_floor": ko / no,
                    "gap_close_overlap_pp": 100.0 * (kc / nc - ko / no)})
    agree_overlap = None
    for r in oq5:
        if abs(r["gap_close_overlap_pp"]) <= sw.AGREEMENT_PP:
            agree_overlap = r["multiplier"]
        else:
            break

    worst_naive = min(naive.values()) / ACCOUNT * 100
    worst_overlap = min(lows.values()) / ACCOUNT * 100
    out = {
        "schema_version": SCHEMA,
        "baseline_snapshot": "3472a5d2e1b5",
        "requirement": REQUIREMENT,
        "ceiling": ceil,
        "flip": fl,
        "population": pop,
        "selection": sel,
        "oq5": {
            "worst_day_close_pct": round(min(base.close.values()) / ACCOUNT * 100, 2),
            "worst_day_naive_floor_pct": round(worst_naive, 2),
            "worst_day_overlap_floor_pct": round(worst_overlap, 2),
            "days_le_5pct_naive": sum(1 for v in naive.values() if v <= -0.05 * ACCOUNT),
            "days_le_5pct_overlap": sum(1 for v in lows.values() if v <= -0.05 * ACCOUNT),
            "sweep": oq5,
            "largest_agreeing_multiplier_overlap": agree_overlap,
        },
    }
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n",
                                 encoding="utf-8")

    print("== TERM 1 · ceiling (best close-basis rate on the grid) ==")
    ba, bc = ceil["best_all"], ceil["best_complete"]
    print(f"  50 windows: {ba['all']:.0%} at {ba['multiplier']:.2f}x  "
          f"Wilson [{ba['wilson'][0]:.2f}-{ba['wilson'][1]:.2f}]")
    print(f"  36 complete: {bc['complete']:.0%} at {bc['multiplier']:.2f}x  "
          f"Wilson [{bc['wilson'][0]:.2f}-{bc['wilson'][1]:.2f}]")
    print()
    print("== TERM 2 · flip instability (closes OQ-6) ==")
    for m, v in fl.items():
        print(f"  {m}x  base {v['base']:.0%}  median {v['median']:.0%}  "
              f"delta {v['delta_pp']:+.0f} pp  band {v['band_pp']:.0f} pp  "
              f"[p5 {v['p5']:.0%} p95 {v['p95']:.0%}]")
    print()
    print("== TERM 3 · population (book-size scaling) ==")
    for m, v in pop.items():
        print(f"  at {m}x:")
        for r in v["rows"]:
            print(f"    {r['book_size']:>3} sleeves   raw {r['raw_mean']:.0%}   "
                  f"exposure-normalised {r['normalised_mean']:.0%}")
        print(f"    slope: raw {v['raw_slope_pp_per_sleeve']:+.2f} pp/sleeve   "
              f"normalised {v['normalised_slope_pp_per_sleeve']:+.2f} pp/sleeve")
    print()
    print("== TERM 4 · selection bound ==")
    c = sel["cells"]
    print(f"  first half {c['first']['k']}/{c['first']['n']} = {c['first']['rate']:.0%}   "
          f"second half {c['second']['k']}/{c['second']['n']} = {c['second']['rate']:.0%}")
    print(f"  difference {sel['difference_second_minus_first_pp']:+.0f} pp   "
          f"Newcombe [{sel['newcombe_pp'][0]:+.0f}, {sel['newcombe_pp'][1]:+.0f}] pp")
    print(f"  largest hidden downward bias consistent with the data: "
          f"{sel['largest_hidden_downward_bias_pp']:.0f} pp")
    print()
    print("== OQ-5 · overlap-constrained floor ==")
    print(f"  worst day: close {out['oq5']['worst_day_close_pct']:.2f} %  "
          f"naive floor {worst_naive:.2f} %  overlap floor {worst_overlap:.2f} %")
    print(f"  days at or below -5 %: naive {out['oq5']['days_le_5pct_naive']}  "
          f"overlap {out['oq5']['days_le_5pct_overlap']}")
    print(f"{'mult':>6}{'close':>9}{'naive':>9}{'overlap':>9}{'gap pp':>9}")
    for r in oq5:
        print(f"{r['multiplier']:>6.2f}{r['close']:>9.0%}{r['naive_floor']:>9.0%}"
              f"{r['overlap_floor']:>9.0%}{r['gap_close_overlap_pp']:>9.0f}")
    print(f"  largest multiplier where close and overlap agree within "
          f"{sw.AGREEMENT_PP:.0f} pp: {agree_overlap}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
