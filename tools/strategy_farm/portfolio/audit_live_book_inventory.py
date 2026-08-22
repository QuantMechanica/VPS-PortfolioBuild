#!/usr/bin/env python3
"""Round 8 section 5.4: what is actually deployed and trading on T_Live.

Never trust a manifest alone for "what's running" -- the Experts directory holds 64
.ex5 and the profiles hold over a hundred chart files, and neither answers the question
that matters after an incident: WHICH strategies were running, under which magic, and
which of them actually traded. (Historically there was no authenticated manifest at all
to compare against; SP-A1 [2026-08-22] closed that gap with the runtime deploy pointer
at D:\\QM\\reports\\state\\live_deployment_pointer.json -- see `manifest_reconciliation`
below, which is comparison evidence ADDED ON TOP of the log-based read, never a
replacement for it.)

The reliable primary source is the terminal-local per-EA log,
C:\\QM\\mt5\\T_Live\\MT5_Base\\MQL5\\Files\\QM\\QM5_<id>_*.log -- it is append-written by
the EA itself, is not shared with the factory (unlike the FILE_COMMON q08 streams), and
carries the identity (ea_id, slug, symbol, timeframe, magic) on every line plus a daily
EQUITY_SNAPSHOT and the order lifecycle.

Three states are reported separately, because collapsing them is what made the
2026-07-26 reading wrong: ATTACHED (the EA initialised), EMITTING (it still writes), and
TRADING (it actually opened positions).  An EA can be attached and silent, or emitting
and flat.

Strictly read-only.  Touches nothing in T_Live.
"""
from __future__ import annotations

import datetime as dt
import json
import re
from collections import defaultdict
from pathlib import Path

LOGDIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
EXPERTS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts")
OUT = Path(r"C:\QM\repo\artifacts\audit_live_book_inventory_20260819.json")
DEPLOY_POINTER = Path(r"D:\QM\reports\state\live_deployment_pointer.json")


def load_manifest_reconciliation(observed_magics: set[int]) -> dict:
    """Compare the log-observed magic roster against the SP-A1 authenticated
    runtime deploy pointer's manifest -- read-only, evidence only, never a
    substitute for the log-based ATTACHED/EMITTING/TRADING read above. Absent
    or unreadable pointer/manifest is reported explicitly (UNKNOWN), never
    silently treated as "no expectation"."""
    result = {
        "pointer_path": str(DEPLOY_POINTER),
        "pointer_exists": DEPLOY_POINTER.is_file(),
        "pointer_signed": None,
        "manifest_path": None,
        "manifest_sha256": None,
        "expected_magics": [],
        "magics_in_manifest_not_in_logs": [],
        "magics_in_logs_not_in_manifest": [],
        "status": "UNKNOWN",
        "detail": None,
    }
    if not result["pointer_exists"]:
        result["detail"] = "no_runtime_pointer"
        return result
    try:
        pointer = json.loads(DEPLOY_POINTER.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        result["detail"] = f"pointer_unreadable:{exc}"
        return result
    result["pointer_signed"] = pointer.get("signed")
    result["manifest_path"] = pointer.get("manifest_path")
    result["manifest_sha256"] = pointer.get("manifest_sha256")
    roster = ((pointer.get("expected_sleeves") or {}).get("roster")) or []
    expected_magics = sorted({int(r["magic_number"]) for r in roster if r.get("magic_number") is not None})
    result["expected_magics"] = expected_magics
    if not expected_magics:
        result["detail"] = "pointer_has_no_expected_sleeves_roster"
        return result
    expected_set = set(expected_magics)
    result["magics_in_manifest_not_in_logs"] = sorted(expected_set - observed_magics)
    result["magics_in_logs_not_in_manifest"] = sorted(observed_magics - expected_set)
    result["status"] = "OK" if not result["magics_in_manifest_not_in_logs"] and not result["magics_in_logs_not_in_manifest"] else "DRIFT"
    result["detail"] = "expected_and_observed_magics_match" if result["status"] == "OK" else "roster_vs_log_drift"
    return result

TRADE_EVENTS = {"ENTRY_ACCEPTED", "TM_OPEN", "TRADE_CLOSED", "POSITION_CLOSED"}
FRESH_HOURS = 36          # a live EA on a weekday writes at least a daily snapshot


def scan_log(path: Path) -> dict:
    """Last-value-wins identity plus event tallies. Tolerant of interleaved writes."""
    ident = {}
    events = defaultdict(int)
    first_ts = last_ts = None
    last_trade_ts = None
    symbols, magics, tfs = set(), set(), set()
    equity_last = None
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or not line.startswith("{"):
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                # Concurrent chart instances can interleave writes and produce
                # nested/broken JSON. Salvage identity by regex rather than drop.
                m = re.search(r'"magic":(\d+)', line)
                if m:
                    magics.add(int(m.group(1)))
                m = re.search(r'"symbol":"([A-Z0-9._]+)"', line)
                if m:
                    symbols.add(m.group(1))
                events["_unparsable"] += 1
                continue
            ts = r.get("ts_utc")
            if ts:
                if first_ts is None or ts < first_ts:
                    first_ts = ts
                if last_ts is None or ts > last_ts:
                    last_ts = ts
            ev = str(r.get("event") or "")
            events[ev] += 1
            if r.get("symbol"):
                symbols.add(str(r["symbol"]))
            if r.get("magic") is not None:
                magics.add(int(r["magic"]))
            if r.get("tf"):
                tfs.add(str(r["tf"]))
            if r.get("ea_id") is not None:
                ident["ea_id"] = int(r["ea_id"])
            if r.get("slug"):
                ident["slug"] = str(r["slug"])
            if ev in TRADE_EVENTS and ts:
                if last_trade_ts is None or ts > last_trade_ts:
                    last_trade_ts = ts
            if ev == "EQUITY_SNAPSHOT":
                p = r.get("payload") or {}
                if isinstance(p, dict) and p.get("equity") is not None:
                    equity_last = p.get("equity")
    ident.update({
        "file": path.name,
        "symbols": sorted(symbols),
        "magics": sorted(magics),
        "timeframes": sorted(tfs),
        "first_event_utc": first_ts,
        "last_event_utc": last_ts,
        "last_trade_utc": last_trade_ts,
        "equity_snapshots": events.get("EQUITY_SNAPSHOT", 0),
        "entries_accepted": events.get("ENTRY_ACCEPTED", 0),
        "unparsable_lines": events.get("_unparsable", 0),
        "init_events": events.get("SYMBOL_GUARD_INIT", 0),
        "events_total": sum(v for k, v in events.items() if not k.startswith("_")),
    })
    return ident


def main() -> int:
    now = dt.datetime.now(dt.timezone.utc)
    rows = []
    for path in sorted(LOGDIR.glob("QM5_*.log")):
        rec = scan_log(path)
        last = rec.get("last_event_utc")
        age_h = None
        if last:
            try:
                age_h = (now - dt.datetime.fromisoformat(last.replace("Z", "+00:00"))).total_seconds() / 3600
            except ValueError:
                age_h = None
        rec["age_hours"] = round(age_h, 1) if age_h is not None else None
        rec["emitting"] = bool(age_h is not None and age_h <= FRESH_HOURS)
        rec["traded_ever"] = rec["last_trade_utc"] is not None
        rows.append(rec)

    ex5 = sorted(p.name for p in EXPERTS.glob("*.ex5")) if EXPERTS.exists() else []
    qm_ex5 = [n for n in ex5 if n.upper().startswith("QM5")]

    emitting = [r for r in rows if r["emitting"]]
    traded_recent = [r for r in emitting if r["traded_ever"]]
    stale = [r for r in rows if not r["emitting"]]
    unconfigured = [r for r in rows if r.get("ea_id") == 0]
    observed_magics = {m for r in rows for m in r.get("magics", [])}
    manifest_reconciliation = load_manifest_reconciliation(observed_magics)

    payload = {
        "schema": "qm.live-book-inventory/v1",
        "generated_at_utc": now.isoformat(timespec="seconds"),
        "log_dir": str(LOGDIR),
        "per_ea_logs": len(rows),
        "emitting_within_hours": FRESH_HOURS,
        "emitting": len(emitting),
        "stale": len(stale),
        "unconfigured_instances": len(unconfigured),
        "ex5_in_experts_dir": len(ex5),
        "ex5_qm5_named": len(qm_ex5),
        "manifest_reconciliation": manifest_reconciliation,
        "rows": rows,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")

    print(f"per-EA logs               {len(rows)}")
    print(f"emitting (<= {FRESH_HOURS} h)      {len(emitting)}")
    print(f"stale                     {len(stale)}")
    print(f".ex5 in Experts dir       {len(ex5)}  (QM5-named: {len(qm_ex5)})")
    print(f"manifest reconciliation   {manifest_reconciliation['status']} "
          f"({manifest_reconciliation['detail']}, signed={manifest_reconciliation['pointer_signed']})")
    print()
    print(f"{'ea_id':>7} {'symbols':22} {'magic(s)':22} {'age_h':>7} {'snaps':>6} {'entries':>8} {'last trade':20}")
    for r in sorted(rows, key=lambda x: (x["age_hours"] is None, x["age_hours"] or 0)):
        print(f"{str(r.get('ea_id')):>7} {','.join(r['symbols'])[:22]:22} "
              f"{','.join(str(m) for m in r['magics'])[:22]:22} "
              f"{str(r['age_hours']):>7} {r['equity_snapshots']:>6} {r['entries_accepted']:>8} "
              f"{str(r['last_trade_utc'])[:19]:20}")
    print(f"\nartifact: {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
