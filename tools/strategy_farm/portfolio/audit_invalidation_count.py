#!/usr/bin/env python3
"""Round 5 section 6: how much of a change actually has to be re-run, and how much only re-read.

The distinction this exists to enforce
--------------------------------------
An extractor repair changes no run. It changes what is read out of evidence files that already
exist. Wherever those files are still on disk, the fix costs a file read; only where they are gone
does a metric require a fresh backtest. Treating the two as one is the difference between a free
re-evaluation and days of factory time, and section 6 asks for both counted before anything is
scheduled.

Readability, not row existence
------------------------------
A row in ea_metrics is counted readable only if its source is not one of the failure markers AND
the file it points at still exists right now. Both checks are needed: source is a record of what
happened at extraction time, and the file may have been removed since.

Output
------
Per pool pair and per phase: readable / evidence gone / no row. Reported at pair level, because that
is the unit the batch schedules.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import sqlite3
from pathlib import Path
from typing import Any

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
COHORTS = Path(r"C:\QM\repo\artifacts\book_q08_regeneration_cohorts_20260817.json")
PHASES = ("Q02", "Q04", "Q05", "Q06", "Q07", "Q08")
UNREADABLE_SOURCES = {"missing", "no_evidence", "parse_error"}
SCHEMA = "qm.audit-invalidation-count/v1"


def pool_pairs() -> list[dict[str, str]]:
    doc = json.loads(COHORTS.read_text(encoding="utf-8"))
    out = []
    for cohort, rows in doc["cohorts"].items():
        for r in rows:
            out.append({"ea_id": r["ea_id"], "symbol": str(r["symbol"]).upper(),
                        "cohort": cohort, "pair": r.get("pair")})
    return out


def classify(con: sqlite3.Connection, ea: str, symbol: str) -> dict[str, str]:
    """Per phase: readable / evidence_gone / no_row."""
    state = {}
    for ph in PHASES:
        rows = con.execute(
            "SELECT source, evidence_path FROM ea_metrics "
            "WHERE ea_id=? AND phase=? AND (UPPER(symbol)=? OR UPPER(symbol)=?)",
            (ea, ph, symbol, symbol + ".DWX")).fetchall()
        if not rows:
            state[ph] = "no_row"
            continue
        readable = any(
            r["source"] not in UNREADABLE_SOURCES and r["evidence_path"]
            and os.path.exists(r["evidence_path"]) for r in rows)
        state[ph] = "readable" if readable else "evidence_gone"
    return state


def main() -> int:
    ap = argparse.ArgumentParser(description="Round 5 section 6 counting")
    ap.add_argument("--json-out", type=Path)
    args = ap.parse_args()

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=60)
    con.row_factory = sqlite3.Row
    try:
        pairs = pool_pairs()
        per_pair = []
        for p in pairs:
            st = classify(con, p["ea_id"], p["symbol"])
            readable = [k for k, v in st.items() if v == "readable"]
            gone = [k for k, v in st.items() if v == "evidence_gone"]
            if readable and not gone:
                bucket = "all_phases_re_evaluate"
            elif readable:
                bucket = "partial_re_evaluate"
            elif gone:
                bucket = "re_run_required"
            else:
                bucket = "no_rows_at_all"
            per_pair.append({**p, "phases": st, "readable": readable, "gone": gone,
                             "bucket": bucket})
        buckets = collections.Counter(x["bucket"] for x in per_pair)
        by_phase = {ph: collections.Counter(x["phases"][ph] for x in per_pair) for ph in PHASES}
        by_cohort = collections.Counter((x["cohort"], x["bucket"]) for x in per_pair)
        out = {
            "schema_version": SCHEMA,
            "at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
            "baseline_snapshot": "3472a5d2e1b5",
            "pool_pairs": len(pairs),
            "buckets": dict(buckets),
            "by_phase": {ph: dict(c) for ph, c in by_phase.items()},
            "by_cohort_bucket": {f"{c}|{b}": n for (c, b), n in sorted(by_cohort.items())},
            "pairs": per_pair,
        }
        if args.json_out:
            args.json_out.parent.mkdir(parents=True, exist_ok=True)
            args.json_out.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n",
                                     encoding="utf-8")
        print(f"pool pairs: {len(pairs)}")
        for k, v in buckets.most_common():
            print(f"  {k:26} {v:>3}")
        print()
        print(f"{'phase':8}{'readable':>10}{'gone':>8}{'no row':>8}")
        for ph in PHASES:
            c = by_phase[ph]
            print(f"{ph:8}{c['readable']:>10}{c['evidence_gone']:>8}{c['no_row']:>8}")
        print()
        for k, n in sorted(by_cohort.items()):
            print(f"  {k[0]:24} {k[1]:26} {n:>3}")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
