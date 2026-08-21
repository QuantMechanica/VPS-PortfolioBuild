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
import math
import sqlite3
from collections import defaultdict
from datetime import date, datetime, timezone
from pathlib import Path

STREAMS = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OUT = Path(r"C:\QM\repo\artifacts\audit_activity_criterion_20260819.json")

MIN_DAYS = 250            # the incumbent close-day floor
PER_YEAR = 10             # OWNER-stated contractual criterion (full scored year)
# Ratified partial-year rule (OWNER 2026-08-21, CEO-MP-#4): a boundary/partial
# year is SCORED when it covers >= 3 months, with a scaled distinct-day
# requirement ceil(10 * covered_months / 12); a boundary year covering fewer
# months is skipped entirely (neither scored nor failed).
PARTIAL_MIN_COVERED_MONTHS = 3
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


def _summary_first_tradable_marker(path_value):
    """Return a validated run_smoke first-tradable marker, or None.

    The marker is generation-bound inside the run summary. Old summaries and
    non-pattern runs intentionally return None; callers must expose their
    fallback rather than silently pretending a marker existed.
    """
    path = Path(str(path_value or ""))
    if not path.is_file() or path.suffix.lower() != ".json":
        return None
    try:
        summary = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    floor = summary.get("frequency_floor")
    if not isinstance(floor, dict):
        return None
    marker = floor.get("first_tradable_bar")
    if not isinstance(marker, dict):
        return None
    if floor.get("coverage_start_source") != "pattern_first_tradable_bar":
        return None
    try:
        marker_date = datetime.strptime(
            str(marker["tradable_bar_date"]), "%Y.%m.%d"
        ).date()
        required_bars = int(marker.get("required_bars") or 0)
    except (KeyError, TypeError, ValueError):
        return None
    return {
        "status": "present",
        "date": marker_date,
        "tradable_bar_date": marker_date.isoformat(),
        "required_bars": required_bars,
        "profile_key": str(marker.get("profile_key") or ""),
        "source_evidence_path": str(path.resolve()),
        "source_schema": str(floor.get("schema") or ""),
    }


def runtime_maps():
    con = sqlite3.connect(DB, uri=True, timeout=30)
    con.row_factory = sqlite3.Row
    latest = {}
    markers = {}
    for r in con.execute("select id,ea_id,symbol,phase,verdict,evidence_path from work_items "
                         "where status='done' order by updated_at"):
        pair = (r["ea_id"], str(r["symbol"]).upper())
        latest[(*pair, r["phase"])] = str(r["verdict"] or "")
        # Q02 is the consumer named in Bug #4 and its run_smoke/v2 summary is
        # the authoritative place where the generation-bound marker lives.
        # A newer Q02 without a marker replaces an older one with an explicit
        # absence, so stale-generation markers cannot leak forward.
        if str(r["phase"]).upper() in {"Q02", "P2"}:
            marker = _summary_first_tradable_marker(r["evidence_path"])
            markers[pair] = marker or {
                "status": "absent",
                "date": None,
                "source_work_item_id": str(r["id"]),
                "source_evidence_path": str(r["evidence_path"] or ""),
            }
            if marker:
                markers[pair]["source_work_item_id"] = str(r["id"])
    con.close()
    return latest, markers


def verdict_map():
    """Backward-compatible verdict-only view used by older callers/tests."""
    return runtime_maps()[0]


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


def covered_months(first_date, last_date, year):
    """Number of covered months of a boundary (partial) `year`.

    Coverage runs from the first tradable date to the last observed date,
    clipped to `year`.  For the first boundary year that is `first_date.month`
    through December; for the last boundary year it is January through
    `last_date.month`; for a single-year span it is `first`..`last`.

    Bug #4 contract: `first_date` is the generation-bound marker emitted when
    the pattern gate first has sufficient closed-bar history. If an old run has
    no marker, classify() visibly falls back to the earliest trade date -- the
    historical substitute -- and labels that fallback in every output row.
    """
    start_month = first_date.month if year == first_date.year else 1
    end_month = last_date.month if year == last_date.year else 12
    return max(0, end_month - start_month + 1)


def partial_threshold(months):
    """Scaled distinct-day requirement for a partial year: ceil(10 * m / 12)."""
    return math.ceil(PER_YEAR * months / 12)


def scored_years(by_year, first_date, last_date):
    """Apply the ratified activity criterion to one date basis.

    Full inner years (strictly inside the span, INCLUDING gap years that carry
    no rows at all, which therefore count as zero distinct days) require
    PER_YEAR (10) distinct days.  The two boundary/partial years are scored
    pro-rata when they cover >= PARTIAL_MIN_COVERED_MONTHS months, with
    threshold partial_threshold(covered_months); a boundary year covering fewer
    months is SKIPPED -- neither scored nor failed -- and reported so the skip
    stays visible rather than silently dropped.  A pair meets the criterion iff
    at least one year is scored and no scored year falls below its threshold.
    """
    if not by_year:
        return {"scored": {}, "skipped": {}, "below": [], "meets": False}
    first_y, last_y = first_date.year, last_date.year
    inner_years = list(range(first_y + 1, last_y))
    boundary_years = {first_y, last_y}
    scored, skipped, below = {}, {}, []
    for y in inner_years:
        scored[y] = PER_YEAR
        if by_year.get(y, 0) < PER_YEAR:
            below.append(y)
    for y in sorted(boundary_years):
        months = covered_months(first_date, last_date, y)
        if months < PARTIAL_MIN_COVERED_MONTHS:
            skipped[y] = months
            continue
        thr = partial_threshold(months)
        scored[y] = thr
        if by_year.get(y, 0) < thr:
            below.append(y)
    return {"scored": scored, "skipped": skipped,
            "below": sorted(below), "meets": bool(scored) and not below}


def _coverage_start(marker, trade_first):
    """Resolve the measured start or a visible earliest-trade fallback."""
    marker_date = marker.get("date") if isinstance(marker, dict) else None
    if isinstance(marker_date, datetime):
        marker_date = marker_date.date()
    if isinstance(marker_date, date) and marker_date <= trade_first:
        return marker_date, "pattern_first_tradable_bar", "present"
    if isinstance(marker_date, date):
        return trade_first, "earliest_trade_fallback_invalid_marker_after_trade", "invalid"
    status = str((marker or {}).get("status") or "absent") if isinstance(marker, dict) else "absent"
    return trade_first, "earliest_trade_fallback_marker_absent", status


def classify(ev, coverage, first_tradable_marker=None):
    close_days = {c for _, c, _ in ev}
    entry_days = {e for e, _, _ in ev}
    by_year_close = per_year_days(ev, 1)
    by_year_entry = per_year_days(ev, 0)
    first_trade_close, last = min(close_days), max(close_days)
    first, close_source, close_marker_status = _coverage_start(
        first_tradable_marker, first_trade_close
    )
    span_days = (last - first).days + 1
    years = sorted(by_year_close)
    # Partial (boundary) years are now scored pro-rata rather than skipped -- see
    # scored_years() and docs/ops/ACTIVITY_CRITERION.md §R (OWNER 2026-08-21,
    # CEO-MP-#4).  Each date basis is scored against its own span endpoints.
    close_score = scored_years(by_year_close, first, last)
    first_trade_entry, entry_last = min(entry_days), max(entry_days)
    entry_first, entry_source, entry_marker_status = _coverage_start(
        first_tradable_marker, first_trade_entry
    )
    entry_score = scored_years(by_year_entry, entry_first, entry_last)
    # full_years / inner_years keep their historical close-basis meaning for the
    # summary print (worst-inner-year); a gap year inside the span with no rows
    # still counts as zero trading days -- a hard fail of the full-year floor.
    partial = {years[0], years[-1]} if years else set()
    full_years = [y for y in years if y not in partial]
    inner_years = list(range(years[0] + 1, years[-1])) if len(years) >= 2 else []
    return {
        "trades": len(ev),
        "entry_coverage": round(coverage, 4),
        "close_days": len(close_days),
        "entry_days": len(entry_days),
        "first": first.isoformat(),
        "first_trade_close": first_trade_close.isoformat(),
        "first_trade_entry": first_trade_entry.isoformat(),
        "last": last.isoformat(),
        "coverage_start_close": first.isoformat(),
        "coverage_start_entry": entry_first.isoformat(),
        "coverage_start_source_close": close_source,
        "coverage_start_source_entry": entry_source,
        "first_tradable_marker_status_close": close_marker_status,
        "first_tradable_marker_status_entry": entry_marker_status,
        "first_tradable_marker": {
            key: (value.isoformat() if isinstance(value, date) else value)
            for key, value in (first_tradable_marker or {}).items()
        },
        "span_days": span_days,
        "span_years": round(span_days / 365.25, 2),
        "close_days_per_year": round(len(close_days) / max(span_days / 365.25, 1e-9), 1),
        "by_year_close": by_year_close,
        "by_year_entry": by_year_entry,
        "full_years": full_years,
        "inner_years": inner_years,
        "scored_years_close": close_score["scored"],
        "scored_years_entry": entry_score["scored"],
        "skipped_partial_years_close": close_score["skipped"],
        "skipped_partial_years_entry": entry_score["skipped"],
        "years_below_criterion": close_score["below"],
        "years_below_criterion_entry": entry_score["below"],
        "meets_10_per_year_close": close_score["meets"],
        "meets_10_per_year_entry": entry_score["meets"],
        "meets_min_days_250": len(close_days) >= MIN_DAYS,
    }


def main():
    latest, first_tradable_markers = runtime_maps()
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
        marker = first_tradable_markers.get((ea, sym), {"status": "absent_no_q02_evidence", "date": None})
        rec = classify(ev, coverage, marker)
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
        "coverage_start_contract": "pattern_first_tradable_bar_else_visible_earliest_trade_fallback",
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
