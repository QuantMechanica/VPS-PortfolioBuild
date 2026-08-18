#!/usr/bin/env python3
"""Round 5 section 5: freeze the basis the audit stands on, before anything regenerates it.

The failure this prevents
-------------------------
Every number in audit revisions 2 to 5 was computed against a live database and a live report tree.
Part B of Round 5 changes both: the extractor repair rewrites ea_metrics, and the merged batch
rewrites verdicts. Once that happens, nobody can say afterwards which state the 81 % was computed on,
and no later revision is checkable against an earlier one. That is not a hypothetical -- it is the
single way this round can destroy work that is already done.

What a snapshot has to contain to be worth taking
--------------------------------------------------
Not the data. The report tree is hundreds of gigabytes and the database is live. What is frozen here
is the *identity* of the state: a content hash over exactly those quantities the audit rests on, so
that a later run either reproduces the hash or is provably standing on different ground.

Six components, each hashed independently so a change can be localised rather than merely detected:

    verdict_inventory   latest verdict per (ea_id, symbol, phase) over terminal work items
    ea_metrics_coverage row counts by (phase, source) and per-field non-null counts
    sleeve_population   the 21 sleeves, their trade counts, the trading-day span
    window_series       the 50 window starts and which 36 carry a complete book
    pool_population     the 91-pair pool and the 18 of it that have a usable daily series
    artifacts           sha256 of the named files on disk

The snapshot id is the sha256 over the six component hashes in a fixed order. Any number produced
after this point cites that id, per section 5.3.

Off-host copy
-------------
The manifest is written into the repo and copied to the vault on G:, which is a different machine's
storage. A hash kept only on the host it describes proves nothing about that host.

Usage
-----
    python audit_baseline_snapshot.py --write            take and record the snapshot
    python audit_baseline_snapshot.py --verify <path>    recompute and compare, component by component
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import io
import json
import shutil
import sqlite3
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REPO = Path(r"C:\QM\repo")
OFFHOST = Path(r"G:\My Drive\QuantMechanica - Company Reference\_audit_baselines")
SCHEMA = "qm.audit-baseline-snapshot/v1"

TRACKED_ARTIFACTS = (
    "artifacts/book_q08_regeneration_cohorts_20260817.json",
    "artifacts/audit_intraday_sizing_sweep_20260818.json",
    "artifacts/batch_expedite_expectations_20260818.json",
    "docs/ops/audit_rev3.md",
    "docs/ops/audit_rev4.md",
    "docs/ops/AUDIT_RESPONSE_2026-08-18.md",
    "tools/strategy_farm/portfolio/challenge_book_60d.py",
    "tools/strategy_farm/portfolio/audit_intraday_sizing_sweep.py",
    "tools/strategy_farm/ea_metrics.py",
)


def h(obj: Any) -> str:
    return hashlib.sha256(
        json.dumps(obj, sort_keys=True, default=str, ensure_ascii=False).encode("utf-8")
    ).hexdigest()


def file_sha256(p: Path) -> str | None:
    if not p.is_file():
        return None
    d = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            d.update(chunk)
    return d.hexdigest()


def ro(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=60)
    con.row_factory = sqlite3.Row
    return con


def verdict_inventory(con: sqlite3.Connection) -> dict[str, Any]:
    """Latest verdict per (ea_id, symbol, phase) over terminal rows -- the audit's selection basis."""
    latest: dict[str, str] = {}
    for r in con.execute(
            "SELECT ea_id, symbol, phase, verdict FROM work_items "
            "WHERE status IN ('done','failed') ORDER BY updated_at"):
        latest[f"{r['ea_id']}|{str(r['symbol']).upper()}|{r['phase']}"] = str(r["verdict"] or "")
    counts: dict[str, int] = {}
    for v in latest.values():
        counts[v] = counts.get(v, 0) + 1
    return {"triples": len(latest), "by_verdict": dict(sorted(counts.items())),
            "content_hash": h(latest)}


def ea_metrics_coverage(con: sqlite3.Connection) -> dict[str, Any]:
    fields = ("net_profit", "profit_factor", "trades",
              "drawdown_money", "drawdown_pct", "sharpe")
    sel = ", ".join(f"SUM({f} IS NOT NULL)" for f in fields)
    rows = []
    for r in con.execute(
            f"SELECT phase, source, COUNT(*), {sel} FROM ea_metrics GROUP BY phase, source"):
        rows.append({"phase": r[0], "source": r[1], "n": r[2],
                     **{f: r[3 + i] for i, f in enumerate(fields)}})
    rows.sort(key=lambda x: (str(x["phase"]), str(x["source"])))
    total = con.execute("SELECT COUNT(*) FROM ea_metrics").fetchone()[0]
    missing = con.execute("SELECT COUNT(*) FROM ea_metrics WHERE source='missing'").fetchone()[0]
    return {"rows": total, "missing": missing, "missing_share": missing / total if total else None,
            "by_phase_source": rows, "content_hash": h(rows)}


def book_populations() -> dict[str, Any]:
    with contextlib.redirect_stdout(io.StringIO()):
        import challenge_book_60d as cb
    import audit_intraday_sizing_sweep as sw
    book = sw.Book(cb)
    sleeves = {k: len(cb.sleeves[k]) for k in sorted(cb.keys)}
    windows = [{"start": str(s), "complete": bool(c)}
               for s, c in zip(book.starts, book.complete)]
    return {
        "sleeve_population": {"n": len(sleeves), "sleeves": sleeves,
                              "trading_days": len(book.days),
                              "span_calendar_days": book.span_days,
                              "content_hash": h(sleeves)},
        "window_series": {"n": len(windows), "complete": sum(book.complete),
                          "windows": windows, "content_hash": h(windows)},
    }


def pool_population(con: sqlite3.Connection) -> dict[str, Any]:
    """The 91-pair regeneration pool, from the frozen cohort file rather than re-derived."""
    p = REPO / "artifacts" / "book_q08_regeneration_cohorts_20260817.json"
    if not p.is_file():
        return {"available": False, "content_hash": h(None)}
    doc = json.loads(p.read_text(encoding="utf-8"))
    pairs = []
    for key in ("cohorts", "pool", "rows"):
        node = doc.get(key)
        if isinstance(node, dict):
            for cname, entries in node.items():
                for e in entries or []:
                    if isinstance(e, dict):
                        pairs.append(f"{e.get('ea_id')}|{str(e.get('symbol','')).upper()}|{cname}")
        elif isinstance(node, list):
            for e in node:
                if isinstance(e, dict):
                    pairs.append(f"{e.get('ea_id')}|{str(e.get('symbol','')).upper()}")
    pairs.sort()
    return {"available": True, "n_pairs": len(pairs), "content_hash": h(pairs)}


def artifacts() -> dict[str, Any]:
    out = {rel: file_sha256(REPO / rel) for rel in TRACKED_ARTIFACTS}
    return {"files": out, "content_hash": h(out)}


def take() -> dict[str, Any]:
    con = ro(DB)
    try:
        comps = {
            "verdict_inventory": verdict_inventory(con),
            "ea_metrics_coverage": ea_metrics_coverage(con),
            "pool_population": pool_population(con),
        }
    finally:
        con.close()
    comps.update(book_populations())
    comps["artifacts"] = artifacts()
    order = ("verdict_inventory", "ea_metrics_coverage", "sleeve_population",
             "window_series", "pool_population", "artifacts")
    snapshot_id = hashlib.sha256(
        "".join(comps[k]["content_hash"] for k in order).encode("utf-8")).hexdigest()
    return {
        "schema_version": SCHEMA,
        "snapshot_id": snapshot_id,
        "short_id": snapshot_id[:12],
        "taken_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "db": str(DB),
        "component_order": list(order),
        "components": comps,
    }


def verify(path: Path) -> dict[str, Any]:
    old = json.loads(path.read_text(encoding="utf-8"))
    new = take()
    diffs = {}
    for k in old["component_order"]:
        a = old["components"][k]["content_hash"]
        b = new["components"][k]["content_hash"]
        if a != b:
            diffs[k] = {"snapshot": a, "now": b}
    return {"snapshot_id": old["snapshot_id"], "recomputed_id": new["snapshot_id"],
            "identical": old["snapshot_id"] == new["snapshot_id"],
            "changed_components": diffs}


def main() -> int:
    ap = argparse.ArgumentParser(description="Round 5 section 5: baseline freeze")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--out", type=Path,
                    default=REPO / "artifacts" / "audit_baseline_snapshot_20260818.json")
    ap.add_argument("--verify", type=Path)
    ap.add_argument("--no-offhost", action="store_true")
    args = ap.parse_args()

    if args.verify:
        print(json.dumps(verify(args.verify), indent=1))
        return 0

    snap = take()
    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(snap, indent=1, sort_keys=True, default=str) + "\n",
                            encoding="utf-8")
        if not args.no_offhost:
            try:
                OFFHOST.mkdir(parents=True, exist_ok=True)
                shutil.copy2(args.out, OFFHOST / args.out.name)
                snap["offhost_copy"] = str(OFFHOST / args.out.name)
            except Exception as exc:
                snap["offhost_copy_error"] = str(exc)
    print(json.dumps({k: v for k, v in snap.items() if k != "components"}, indent=1))
    print()
    for k in snap["component_order"]:
        c = snap["components"][k]
        extra = {kk: vv for kk, vv in c.items()
                 if kk not in ("content_hash", "by_phase_source", "windows", "sleeves", "files",
                               "by_verdict")}
        print(f"{k:22} {c['content_hash'][:12]}  {extra}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
