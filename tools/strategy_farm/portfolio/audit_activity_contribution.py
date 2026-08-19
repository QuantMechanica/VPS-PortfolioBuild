#!/usr/bin/env python3
"""Round 8 section 1.3: what the pairs recovered by the real activity criterion contribute.

Lowering the incumbent 250-close-day floor to the stated criterion (>= 10 trading days
per year) returns a handful of pairs to the pool.  The question is not whether they are
eligible -- audit_activity_criterion.py answers that -- but whether they make the book
better.  Low-frequency sleeves add little return; they may still add diversification.
So this is MEASURED, not extrapolated from the +2.27 pp per sleeve slope, which was
fitted on the incumbent 21 and does not transfer to sleeves of a different character.

Method
------
Two pools are built from the same streams with the same gate and coverage filters:

  incumbent  -- close days >= 250 (challenge_book_60d.py:161)
  extended   -- incumbent PLUS every pair that clears >= 10 trading days in every
                full calendar year of its span

Both are run through the same Book and the same phase engine as the EV work, at 0.50x,
on both measurement bases (close-price series and overlap-constrained intraday floor).
Anything that differs between the two runs is the contribution of the added pairs.

Read-only.  Writes a JSON artifact and prints a summary.
"""
from __future__ import annotations

import contextlib
import datetime as dt
import io
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import audit_intraday_sizing_sweep as sw  # noqa: E402
from audit_upper_bound import overlap_floor  # noqa: E402
from audit_ev_funded_account import funding_probability  # noqa: E402

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
RECOUNT = Path(r"C:\QM\repo\artifacts\audit_activity_criterion_20260819.json")
OUT = Path(r"C:\QM\repo\artifacts\audit_activity_contribution_20260819.json")
MULT = 0.50
SCHEMA = "qm.activity-criterion-contribution/v1"


class Pool:
    """Minimal stand-in for the challenge_book_60d module surface Book/overlap_floor use."""

    def __init__(self, sleeves: dict[str, list]) -> None:
        self.sleeves = sleeves
        self.keys = sorted(sleeves)
        self.all_days = sorted({c for ev in sleeves.values() for _e, c, _n, _m in ev})
        day_index = {d: i for i, d in enumerate(self.all_days)}
        self.active = {k: set() for k in self.keys}
        for k in self.keys:
            for entry, close, _net, _mae in sleeves[k]:
                self.active[k].add(close)
                self.active[k].add(entry)
                i0 = day_index.get(entry, day_index[close])
                for i in range(i0, day_index[close] + 1):
                    self.active[k].add(self.all_days[i])


def load_stream(path: Path) -> list[tuple]:
    """Same parse as challenge_book_60d, including the MAE sign convention."""
    cb = engine()
    ev = []
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if str(r.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                continue
            close = cb.parse_ts(r.get("time"))
            if close is None:
                continue
            try:
                net = float(r.get("net"))
            except (TypeError, ValueError):
                continue
            try:
                mae = min(float(r.get("mae_acct") or 0.0), 0.0)
            except (TypeError, ValueError):
                mae = 0.0
            entry = cb.parse_ts(r.get("entry_time"))
            ev.append((entry.date() if entry else close.date(), close.date(), net, mae))
    ev.sort(key=lambda x: (x[1], x[0]))
    return ev


_ENGINE = None


def engine():
    global _ENGINE
    if _ENGINE is None:
        with contextlib.redirect_stdout(io.StringIO()):
            import challenge_book_60d as cb
        _ENGINE = cb
    return _ENGINE


def measure(pool: Pool) -> dict[str, Any]:
    book = sw.Book(pool)
    lows = overlap_floor(pool)
    out: dict[str, Any] = {"sleeves": len(pool.keys), "starts": len(book.starts)}
    for basis, low_map in (("close", None), ("overlap_floor", lows)):
        res = funding_probability(book, MULT, low_map)
        lo, hi = sw.wilson(res["p1_pass"], res["n_starts"])
        flo, fhi = sw.wilson(res["funded"], res["n_starts"])
        out[basis] = {
            "p1_pass": res["p1_pass"], "p1_rate": round(res["p1_rate"], 4),
            "p1_ci": [round(lo, 4), round(hi, 4)],
            "funded": res["funded"], "funded_rate": round(res["funded_rate"], 4),
            "funded_ci": [round(flo, 4), round(fhi, 4)],
            "expected_attempts": (round(res["expected_attempts"], 2)
                                  if res["expected_attempts"] else None),
        }
    return out


def main() -> int:
    recount = json.loads(RECOUNT.read_text(encoding="utf-8"))
    incumbent_keys = list(recount["admitted_keys"])
    recovered_keys = list(recount["recovered_keys"])

    sleeves: dict[str, list] = {}
    for key in incumbent_keys + recovered_keys:
        bare, _, sym = key.partition(":")
        path = STREAMS / f"{bare}_{sym}_DWX.jsonl"
        if not path.exists():
            print(f"  missing stream for {key}: {path}")
            continue
        sleeves[key] = load_stream(path)

    incumbent = Pool({k: v for k, v in sleeves.items() if k in incumbent_keys})
    extended = Pool(sleeves)

    a = measure(incumbent)
    b = measure(extended)

    payload = {
        "schema": SCHEMA,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "sizing": MULT,
        "incumbent_keys": incumbent_keys,
        "recovered_keys": recovered_keys,
        "incumbent": a,
        "extended": b,
        "delta": {
            basis: {
                "p1_rate": round(b[basis]["p1_rate"] - a[basis]["p1_rate"], 4),
                "funded_rate": round(b[basis]["funded_rate"] - a[basis]["funded_rate"], 4),
            }
            for basis in ("close", "overlap_floor")
        },
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    print(f"sizing {MULT:.2f}x   incumbent {a['sleeves']} sleeves -> extended {b['sleeves']} sleeves")
    print(f"window starts: incumbent {a['starts']}, extended {b['starts']}")
    for basis in ("close", "overlap_floor"):
        pa, pb = a[basis], b[basis]
        print(f"\n{basis}:")
        print(f"  P1      {pa['p1_rate']:.3f} [{pa['p1_ci'][0]:.3f},{pa['p1_ci'][1]:.3f}]"
              f"  ->  {pb['p1_rate']:.3f} [{pb['p1_ci'][0]:.3f},{pb['p1_ci'][1]:.3f}]"
              f"   delta {pb['p1_rate']-pa['p1_rate']:+.3f}")
        print(f"  funded  {pa['funded_rate']:.3f} [{pa['funded_ci'][0]:.3f},{pa['funded_ci'][1]:.3f}]"
              f"  ->  {pb['funded_rate']:.3f} [{pb['funded_ci'][0]:.3f},{pb['funded_ci'][1]:.3f}]"
              f"   delta {pb['funded_rate']-pa['funded_rate']:+.3f}")
    print(f"\nartifact: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
