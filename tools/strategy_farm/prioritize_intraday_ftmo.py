"""Bias the Q02 backtest dispatch toward INTRADAY high-frequency edges (FTMO focus).

The terminal_worker dispatch orders pending work_items by `_priority_track_rank`
first (payload `"priority_track": true` => rank 0, ahead of everything else;
see terminal_worker.py::_priority_pending_query). This tool flips that flag on
the genuine intraday Q02-pending reservoir so the higher-frequency edges (the
only viable FTMO-sprint vehicle per docs/ops/DXZ_FTMO_BOOK_SIZING_REAL_0p75_2026-06-30.md)
drain ahead of the swing (D1/H4) backlog.

Scope: Q02 pending only. Intraday = timeframe in {M1,M5,M15,M30} OR slug in
{scalper,rapidfire,orb} (from setfile_path). Reversible via --revert.

  python prioritize_intraday_ftmo.py            # dry-run (default)
  python prioritize_intraday_ftmo.py --apply
  python prioritize_intraday_ftmo.py --revert
"""
from __future__ import annotations
import argparse, datetime as dt, json, re, sqlite3
from collections import Counter
from pathlib import Path

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
INTRADAY_TF = re.compile(r"_(M1|M5|M15|M30)_", re.I)
INTRADAY_SLUG = re.compile(r"(scalper|rapidfire|orb)", re.I)


def is_intraday(setfile_path: str) -> bool:
    p = setfile_path or ""
    return bool(INTRADAY_TF.search(p) or INTRADAY_SLUG.search(p))


def normalize_epoch_timestamp(value) -> str | None:
    text = str(value or "").strip()
    if not re.fullmatch(r"\d{10}(?:\.\d+)?", text):
        return None
    return dt.datetime.fromtimestamp(float(text), tz=dt.UTC).replace(microsecond=0).isoformat()


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--apply", action="store_true", help="set priority_track=true on intraday Q02 pending")
    g.add_argument("--revert", action="store_true", help="remove priority_track from intraday Q02 pending")
    args = ap.parse_args(argv)

    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    rows = c.execute(
        "SELECT id, setfile_path, payload_json, updated_at FROM work_items "
        "WHERE status='pending' AND phase='Q02'"
    ).fetchall()

    targets = [r for r in rows if is_intraday(r["setfile_path"])]
    tf = Counter()
    for r in targets:
        m = INTRADAY_TF.search(r["setfile_path"] or "")
        tf[m.group(1).upper() if m else "slug-only"] += 1

    already = sum(1 for r in targets if '"priority_track": true' in (r["payload_json"] or ""))
    print(f"Q02 pending total      : {len(rows)}")
    print(f"intraday targets       : {len(targets)}  (by tf: {dict(tf)})")
    print(f"already priority_track : {already}")

    if not (args.apply or args.revert):
        print("\n(dry-run) pass --apply to prioritize, --revert to undo")
        c.close()
        return 0

    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    changed = 0
    timestamps_normalized = 0
    for r in targets:
        try:
            payload = json.loads(r["payload_json"]) if r["payload_json"] else {}
        except Exception:
            payload = {}
        payload_changed = False
        if args.apply:
            if payload.get("priority_track") is True:
                pass
            else:
                payload["priority_track"] = True
                payload_changed = True
        else:  # revert
            if "priority_track" in payload:
                payload.pop("priority_track", None)
                payload_changed = True
        normalized_timestamp = normalize_epoch_timestamp(r["updated_at"])
        if not payload_changed and normalized_timestamp is None:
            continue
        updated_at = now if payload_changed else normalized_timestamp
        c.execute(
            "UPDATE work_items SET payload_json=?, updated_at=? WHERE id=? AND status='pending' AND phase='Q02'",
            (json.dumps(payload), updated_at, r["id"]),
        )
        if payload_changed:
            changed += 1
        if normalized_timestamp is not None:
            timestamps_normalized += 1
    c.commit()
    verb = "prioritized" if args.apply else "reverted"
    print(f"\n{verb} {changed} intraday Q02 work_items")
    print(f"normalized {timestamps_normalized} epoch updated_at values to UTC ISO")
    # confirm
    n = c.execute(
        "SELECT COUNT(*) FROM work_items WHERE status='pending' AND phase='Q02' "
        "AND payload_json LIKE '%\"priority_track\": true%'"
    ).fetchone()[0]
    print(f"priority_track Q02 pending now: {n}")
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
