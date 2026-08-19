#!/usr/bin/env python3
"""Recount the candidate pool against the stated activity criterion.

challenge_book_60d.py admits a sleeve only if it has >= MIN_DAYS (250)
distinct close days over its whole history.  OWNER states the contractual
criterion is >= 10 trading days per YEAR.  This script measures both, per
sleeve and per year, and reports what the difference is worth.

Two trading-day bases are reported because they are not the same thing:

  close-day  -- days on which a position closed.  This is what MIN_DAYS
                counts today (challenge_book_60d.py:161).
  entry-day  -- days on which a position was newly opened.  This is what
                the published FTMO rule counts (closing a position alone
                does not create a Trading Day) -- see
                docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md.

Read-only.  Writes a JSON artifact and prints a summary.
"""
from __future__ import annotations

import json
import sqlite3
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OUT = Path(r"C:\QM\repo\artifacts\audit_activity_criterion_20260819.json")

MIN_DAYS = 250            # the incumbent close-day floor
PER_YEAR = 10             # OWNER-stated contractual criterion
EARLY_OK = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}
Q08_OK = {"PASS", "PASS_SOFT", "MULTI_SEED_PASS", "FAIL_SOFT"}
EARLY_GATES = ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07")


def parse_ts(v):
    if isinstance(v, (int, float)):
        try:
            return datetime.fromtimestamp(float(v), tz=timezone.utc)
        except Exception:
            return None
    t = str(v).strip()
    try:
        return datetime.fromisoformat(t.replace("Z", "+00:00"))
    except ValueError:
        pass
    for f in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(t[:19], f)
        except ValueError:
            continue
    return None


def verdict_map():
    con = sqlite3.connect(DB, uri=True, timeout=30)
    con.row_factory = sqlite3.Row
    latest = {}
    for r in con.execute("select ea_id,symbol,phase,verdict from work_items "
                         "where status='done' order by updated_at"):
        latest[(r["ea_id"], str(r["symbol"]).upper(), r["phase"])] = str(r["verdict"] or "")
    con.close()
    return latest


def read_stream(path: Path):
    """Return (events, entry_coverage_fraction, n_trades)."""
    ev, cov, n = [], 0, 0
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
            close = parse_ts(r.get("time"))
            if close is None:
                continue
            try:
                net = float(r.get("net"))
            except (TypeError, ValueError):
                continue
            entry = parse_ts(r.get("entry_time"))
            n += 1
            if entry is not None:
                cov += 1
            ev.append((entry.date() if entry else close.date(), close.date(), net))
    return ev, (cov / n if n else 0.0), n


def per_year_days(ev, index):
    """distinct day count per calendar year, on the chosen date index."""
    days = defaultdict(set)
    for row in ev:
        d = row[index]
        days[d.year].add(d)
    return {y: len(s) for y, s in sorted(days.items())}


def classify(ev, coverage):
    close_days = {c for _, c, _ in ev}
    entry_days = {e for e, _, _ in ev}
    by_year_close = per_year_days(ev, 1)
    by_year_entry = per_year_days(ev, 0)
    first, last = min(close_days), max(close_days)
    span_days = (last - first).days + 1
    years = sorted(by_year_close)
    # Partial first/last calendar years are not held to the full-year criterion.
    partial = {years[0], years[-1]} if years else set()
    full_years = [y for y in years if y not in partial]
    # A year inside the span with no stream rows at all is zero trading days,
    # so the criterion is evaluated over the full calendar range, not only
    # over years that happen to appear in the stream.
    inner_years = list(range(years[0] + 1, years[-1])) if len(years) >= 2 else []
    below = [y for y in inner_years if by_year_close.get(y, 0) < PER_YEAR]
    below_entry = [y for y in inner_years if by_year_entry.get(y, 0) < PER_YEAR]
    meets_close = bool(inner_years) and not below
    meets_entry = bool(inner_years) and not below_entry
    return {
        "trades": len(ev),
        "entry_coverage": round(coverage, 4),
        "close_days": len(close_days),
        "entry_days": len(entry_days),
        "first": first.isoformat(),
        "last": last.isoformat(),
        "span_days": span_days,
        "span_years": round(span_days / 365.25, 2),
        "close_days_per_year": round(len(close_days) / max(span_days / 365.25, 1e-9), 1),
        "by_year_close": by_year_close,
        "by_year_entry": by_year_entry,
        "full_years": full_years,
        "inner_years": inner_years,
        "years_below_criterion": below,
        "years_below_criterion_entry": below_entry,
        "meets_10_per_year_close": meets_close,
        "meets_10_per_year_entry": meets_entry,
        "meets_min_days_250": len(close_days) >= MIN_DAYS,
    }


def main():
    latest = verdict_map()
    rows = {}
    for path in sorted(STREAMS.glob("*.jsonl")):
        bare, _, stem = path.stem.partition("_")
        ea, sym = f"QM5_{bare}", stem.replace("_DWX", ".DWX").upper()
        bad = [g for g in EARLY_GATES
               if (ea, sym, g) in latest and latest[(ea, sym, g)] not in EARLY_OK]
        q08 = latest.get((ea, sym, "Q08"))
        if q08 is not None and q08 not in Q08_OK:
            bad.append("Q08")
        ev, coverage, n = read_stream(path)
        if not n:
            continue
        rec = classify(ev, coverage)
        rec.update({"ea": ea, "symbol": sym, "gates_failed": bad,
                    "gates_ok": not bad,
                    "coverage_ok": coverage >= 0.99})
        rows[f"{bare}:{sym.replace('.DWX','')}"] = rec

    admitted = [k for k, r in rows.items()
                if r["gates_ok"] and r["coverage_ok"] and r["meets_min_days_250"]]
    blocked = [k for k, r in rows.items()
               if r["gates_ok"] and r["coverage_ok"] and not r["meets_min_days_250"]]
    recovered = [k for k in blocked if rows[k]["meets_10_per_year_close"]]
    recovered_entry = [k for k in blocked if rows[k]["meets_10_per_year_entry"]]
    still_out = [k for k in blocked if k not in recovered]
    # Split the ones that remain out: data problem vs construction problem.
    short_history = [k for k in still_out if rows[k]["span_years"] < 3.0]
    low_frequency = [k for k in still_out if rows[k]["span_years"] >= 3.0]

    payload = {
        "schema": "qm.activity-criterion-recount/v1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "min_days_incumbent": MIN_DAYS,
        "criterion_per_year": PER_YEAR,
        "streams_scanned": len(rows),
        "admitted_today": len(admitted),
        "blocked_by_min_days_only": len(blocked),
        "recovered_close_basis": len(recovered),
        "recovered_entry_basis": len(recovered_entry),
        "still_excluded": len(still_out),
        "still_excluded_short_history": len(short_history),
        "still_excluded_low_frequency": len(low_frequency),
        "admitted_keys": sorted(admitted),
        "recovered_keys": sorted(recovered),
        "still_excluded_keys": sorted(still_out),
        "rows": rows,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    print(f"streams scanned                       {len(rows)}")
    print(f"admitted today (gates+cov+250)        {len(admitted)}")
    print(f"blocked by MIN_DAYS only              {len(blocked)}")
    print(f"  meet >=10/yr (close-day basis)      {len(recovered)}")
    print(f"  meet >=10/yr (entry-day basis)      {len(recovered_entry)}")
    print(f"  still excluded                      {len(still_out)}")
    print(f"    of which span < 3y (data)         {len(short_history)}")
    print(f"    of which span >= 3y (frequency)   {len(low_frequency)}")
    print(f"\nartifact: {OUT}")
    if recovered:
        print("\nrecovered pairs (close-day basis):")
        for k in sorted(recovered):
            r = rows[k]
            worst = min((r["by_year_close"].get(y, 0) for y in r["inner_years"]), default=0)
            print(f"  {k:26} trades={r['trades']:5} close_days={r['close_days']:4} "
                  f"span={r['span_years']:.1f}y worst_year={worst}")


if __name__ == "__main__":
    main()
