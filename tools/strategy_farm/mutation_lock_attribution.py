"""Read-only busy-claim attribution over a frozen UTC observation window.

Historical declines are joined to recorded hold intervals, explicitly as an
inference. New claim_lock_busy observations take precedence over the companion
throttled claim_declined lines, so the same attempt is not counted twice.
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import statistics


def timestamp(value):
    try:
        result = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return result.astimezone(dt.UTC) if result.tzinfo else None
    except (ValueError, TypeError):
        return None


def read_rows(path):
    digest = hashlib.sha256()
    rows = []
    malformed = 0
    with path.open("rb") as handle:
        for raw in handle:
            digest.update(raw)
            try:
                row = json.loads(raw)
                if isinstance(row, dict):
                    rows.append(row)
            except (ValueError, UnicodeError):
                malformed += 1
    return rows, {"path": str(path), "sha256_of_bytes_read": digest.hexdigest(),
                  "non_json_lines": malformed}


def summarize(holds, events, *, start, end):
    acquisitions, releases = {}, {}
    for row in holds:
        nonce = row.get("nonce")
        at = timestamp(row.get("timestamp_utc"))
        if not nonce or at is None:
            continue
        if row.get("event") == "ACQUIRED":
            acquisitions[nonce] = (timestamp(row.get("acquired_at_utc")) or at, row)
        elif row.get("event") == "RELEASED":
            releases[nonce] = at
    intervals = sorted(((at, releases.get(nonce), row) for nonce, (at, row) in acquisitions.items()), key=lambda item: item[0])
    starts = [item[0] for item in intervals]
    window_events = [(timestamp(r.get("at_utc")), r) for r in events
                     if r.get("event") == "claim_lock_busy" or
                     (r.get("event") == "claim_declined" and r.get("reason") == "factory_mutation_lock_busy")]
    window_events = [(at, r) for at, r in window_events if at is not None and start <= at < end]
    upgraded = {}
    for at, row in window_events:
        if row["event"] == "claim_lock_busy":
            terminal = row.get("terminal")
            upgraded[terminal] = min(at, upgraded.get(terminal, at))
    groups, details = {}, []
    for at, row in sorted(window_events, key=lambda x: x[0]):
        if row["event"] == "claim_declined" and at >= upgraded.get(row.get("terminal"), end):
            continue
        observed = row.get("lock_owner") or {}
        owner, age = observed.get("owner"), observed.get("age_seconds")
        method = "direct_busy_observation" if owner else "unattributed"
        pid = observed.get("pid")
        # An unknown new observation remains unknown; do not convert a
        # timed-out read into a claimed measurement after the fact.
        if not owner and row["event"] == "claim_declined":
            lock_path = row.get("lock")
            candidates = [(begin, record) for begin, finish, record in intervals[:bisect_right(starts, at)]
                          if finish is not None and at < finish and
                          (not lock_path or os.path.normcase(str(record.get("lock_path"))) == os.path.normcase(str(lock_path)))]
            if len(candidates) == 1:
                begin, record = candidates[0]
                owner, pid = record.get("owner"), record.get("pid")
                age = (at - begin).total_seconds()
                method = "historical_hold_interval_inference"
        owner = str(owner or "UNKNOWN")
        group = groups.setdefault(owner, {"owner": owner, "count": 0, "ages": [], "pids": set(), "methods": set()})
        group["count"] += 1
        if isinstance(age, (int, float)):
            group["ages"].append(age)
        if pid is not None:
            group["pids"].add(pid)
        group["methods"].add(method)
        details.append({"at_utc": at.isoformat(), "terminal": row.get("terminal"),
                        "owner": owner, "pid": pid, "age_seconds": age, "method": method})
    table = [{"owner": g["owner"], "count": g["count"],
              "median_age_seconds": round(statistics.median(g["ages"]), 6) if g["ages"] else None,
              "pids": sorted(g["pids"]), "methods": sorted(g["methods"])} for g in groups.values()]
    return {"schema": "qm.mutation-lock-attribution/v1", "window_start_utc": start.isoformat(),
            "window_end_utc": end.isoformat(), "window_hours": (end-start).total_seconds()/3600,
            "busy_event_count": len(details), "owner_table": sorted(table, key=lambda x: (-x["count"], x["owner"])),
            "observations": details, "post_deployment_window_proven": False,
            "limits": "Legacy claim_declined was throttled at 60s per reason per process. Counts are logged declines, not all attempts. Interval joins are inference. Deployment and log coverage require separate receipts."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--holds", type=Path, default=Path("D:/QM/reports/state/factory_mutation_lock_holds.jsonl"))
    parser.add_argument("--logs-dir", type=Path, default=Path("D:/QM/strategy_farm/logs"))
    parser.add_argument("--hours", type=float, default=2)
    parser.add_argument("--end-utc", default=dt.datetime.now(dt.UTC).isoformat())
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    end = timestamp(args.end_utc)
    if end is None or not 0 < args.hours <= 24:
        parser.error("timezone-aware end and 0 < hours <= 24 required")
    holds, receipt = read_rows(args.holds)
    sources, events = [receipt], []
    for path in sorted(args.logs_dir.glob("terminal_worker_T*.log")):
        rows, receipt = read_rows(path)
        events.extend(rows)
        sources.append(receipt)
    result = summarize(holds, events, start=end-dt.timedelta(hours=args.hours), end=end)
    result["sources"] = sources
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k not in ("observations", "sources")}, indent=2))


if __name__ == "__main__":
    main()
