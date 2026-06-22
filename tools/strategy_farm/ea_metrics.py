"""ea_metrics — normalized metric-extraction layer for the Strategy Archive.

Problem this solves
-------------------
The factory stores per-work_item backtest evidence as JSON files on disk, with a
DIFFERENT shape per pipeline phase (Q02 `runs[]`, Q04 `folds[]`, Q07
`per_seed_detail[]`, Q08 `sub_gates[]`, Q09_PORTFOLIO `sharpe_with/without`, ...).
The `work_items` table itself holds NO numeric columns — only verdict/status and an
`evidence_path`. The dashboard renderers tried to re-parse these scattered files at
render time and frequently fell back to "no parsed evidence / $0.00 / —", so genuine
survivors (e.g. QM5_10440: +$49,991 net, PF 1.22, all 3 walk-forward folds PASS)
showed as empty.

This module reads every work_item's `evidence_path` ONCE, normalizes the headline
scalars (net_profit, profit_factor, trades, drawdown_money, drawdown_pct, sharpe) into
a single `ea_metrics` table, and stores the phase-specific structure (folds, seeds,
sub-gates, portfolio with/without) in `detail_json`. The Strategy Archive surfaces
(strategies.html + ea_<id>.html) then SELECT from this table instead of parsing files.

The Cockpit (company-progress surface) deliberately does NOT consume per-EA rows from
here — it stays a funnel/throughput/health view. It may later read aggregate COUNTs.

CLI
---
    python tools/strategy_farm/ea_metrics.py build           # incremental (mtime-gated)
    python tools/strategy_farm/ea_metrics.py build --full    # full rebuild
    python tools/strategy_farm/ea_metrics.py build --ea QM5_10440   # one EA (verify)
    python tools/strategy_farm/ea_metrics.py show --ea QM5_10440    # dump rows
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

FARM_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")

# Phases that emit `runs[]`-shaped summary.json (in-sample / multi-symbol backtests).
_SUMMARY_RUN_PHASES = {"P2", "Q02", "Q03"}
# Walk-forward / stress / multi-seed / robustness / portfolio: each its own aggregate.json shape.
_AGG_PHASES = {"Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q09_PORTFOLIO", "Q10", "Q11"}

_DD_PCT_RE = re.compile(r"\(([\d.,]+)\s*%\)")


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _to_float(v: Any) -> float | None:
    if v in (None, ""):
        return None
    try:
        if isinstance(v, str):
            v = v.replace(" ", "").replace(" ", "").replace(",", "")
        return float(v)
    except (TypeError, ValueError):
        return None


def _to_int(v: Any) -> int | None:
    f = _to_float(v)
    return int(round(f)) if f is not None else None


def _dd_pct_from_raw(raw: Any) -> float | None:
    """Extract '14.40' from a drawdown_raw string like '18 157.19 (14.40%)'."""
    if not isinstance(raw, str):
        return None
    m = _DD_PCT_RE.search(raw)
    return _to_float(m.group(1)) if m else None


def _load_json(path: str | None) -> dict | None:
    if not path:
        return None
    p = Path(path)
    if not (p.exists() and p.suffix == ".json"):
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8-sig", errors="ignore"))
    except Exception:
        return None


# --------------------------------------------------------------------------- #
# Per-phase extractors. Each returns (headline_dict, detail_dict, source_tag). #
# headline keys: net_profit, profit_factor, trades, drawdown_money,           #
#                drawdown_pct, sharpe  (any may be None).                      #
# --------------------------------------------------------------------------- #

def _extract_summary_runs(d: dict) -> tuple[dict, dict, str]:
    runs = d.get("runs") or []
    if not runs:
        return {}, {"n_runs": 0}, "summary_runs_empty"
    # Headline = the run that actually made the most money (most informative for an
    # archive). Falls back to runs[0] if nets are absent.
    def _net(r: dict) -> float:
        return _to_float(r.get("net_profit")) or float("-inf")
    primary = max(runs, key=_net)
    if _net(primary) == float("-inf"):
        primary = runs[0]
    head = {
        "net_profit": _to_float(primary.get("net_profit")),
        "profit_factor": _to_float(primary.get("profit_factor")),
        "trades": _to_int(primary.get("total_trades")),
        "drawdown_money": _to_float(primary.get("drawdown")),
        "drawdown_pct": _dd_pct_from_raw(primary.get("drawdown_raw")),
        "sharpe": None,  # not present in summary.json; report-htm parse is on-demand
    }
    detail = {
        "n_runs": len(runs),
        "runs": [
            {
                "net_profit": _to_float(r.get("net_profit")),
                "profit_factor": _to_float(r.get("profit_factor")),
                "trades": _to_int(r.get("total_trades")),
                "drawdown_money": _to_float(r.get("drawdown")),
                "drawdown_pct": _dd_pct_from_raw(r.get("drawdown_raw")),
                "setfile": r.get("setfile_path") or r.get("setfile"),
            }
            for r in runs
        ],
    }
    return head, detail, "summary_runs"


def _extract_q04(d: dict) -> tuple[dict, dict, str]:
    folds = d.get("folds") or []
    fdet = []
    pfs, nets, trs = [], [], []
    for f in folds:
        pf_net = _to_float(f.get("pf_net"))
        gross = _to_float(f.get("gross_total"))
        comm = _to_float(f.get("sim_commission_total"))
        net = (gross - comm) if (gross is not None and comm is not None) else None
        tr = _to_int(f.get("trades"))
        if pf_net is not None:
            pfs.append(pf_net)
        if net is not None:
            nets.append(net)
        if tr is not None:
            trs.append(tr)
        fdet.append({
            "oos_start": f.get("oos_start"), "oos_end": f.get("oos_end"),
            "dev_start": f.get("dev_start"), "dev_end": f.get("dev_end"),
            "pf_net": pf_net, "trades": tr, "net_profit": net,
            "status": f.get("status") or f.get("verdict"),
        })
    head = {
        "net_profit": sum(nets) if nets else None,
        "profit_factor": (sum(pfs) / len(pfs)) if pfs else None,
        "trades": sum(trs) if trs else None,
        "drawdown_money": None, "drawdown_pct": None, "sharpe": None,
    }
    detail = {
        "fold_count": d.get("fold_count") or len(folds),
        "commission_per_lot_round_trip": d.get("commission_per_lot_round_trip"),
        "reason": d.get("reason"),
        "folds": fdet,
    }
    return head, detail, "q04_folds"


def _extract_q05_q06(d: dict) -> tuple[dict, dict, str]:
    head = {
        "net_profit": _to_float(d.get("net_profit")),
        "profit_factor": _to_float(d.get("pf")),
        "trades": _to_int(d.get("trades")),
        "drawdown_money": _to_float(d.get("dd_money")),
        "drawdown_pct": _to_float(d.get("dd_pct")),
        "sharpe": _to_float(d.get("sharpe")),
    }
    detail = {k: d.get(k) for k in ("stress_level", "rejection_probability", "reason") if k in d}
    return head, detail, "q05q06_flat"


def _extract_q07(d: dict) -> tuple[dict, dict, str]:
    m = d.get("metrics") or {}
    seeds = d.get("per_seed_detail") or []
    dd_pcts = [_to_float(s.get("dd_pct")) for s in seeds if _to_float(s.get("dd_pct")) is not None]
    trs = [_to_int(s.get("trades")) for s in seeds if _to_int(s.get("trades")) is not None]
    head = {
        "net_profit": None,
        "profit_factor": _to_float(m.get("mean_pf")),
        "trades": (max(trs) if trs else None),
        "drawdown_money": None,
        "drawdown_pct": (max(dd_pcts) if dd_pcts else None),
        "sharpe": None,
    }
    detail = {
        "metrics": m,
        "per_seed": [
            {"seed": s.get("seed"), "pf": _to_float(s.get("pf")),
             "trades": _to_int(s.get("trades")), "dd_pct": _to_float(s.get("dd_pct")),
             "dd_money": _to_float(s.get("dd_money"))}
            for s in seeds
        ],
        "reason": d.get("reason"),
    }
    return head, detail, "q07_seeds"


def _extract_q08(d: dict) -> tuple[dict, dict, str]:
    gross = _to_float(d.get("gross_total"))
    comm = _to_float(d.get("commission_total"))
    base = d.get("baseline_run") or {}
    head = {
        "net_profit": (gross - comm) if (gross is not None and comm is not None) else gross,
        "profit_factor": _to_float(base.get("baseline_profit_factor")),
        "trades": _to_int(d.get("n_trades")),
        "drawdown_money": None, "drawdown_pct": None,
        "sharpe": None,
    }
    sgs = d.get("sub_gates") or []
    detail = {
        "cost_cushion": _to_float(d.get("cost_cushion")),
        "cost_cushion_tier": d.get("cost_cushion_tier"),
        "baseline_trades": _to_int(base.get("baseline_total_trades")),
        "verdict_classification": d.get("verdict_classification"),
        "sub_gates": [
            {"name": g.get("name"), "status": g.get("status"),
             "passed": g.get("passed"), "value": g.get("value"),
             "threshold": g.get("threshold"), "detail": g.get("detail")}
            for g in sgs
        ],
    }
    return head, detail, "q08_subgates"


def _extract_q09_portfolio(d: dict) -> tuple[dict, dict, str]:
    head = {
        "net_profit": None,
        "profit_factor": _to_float(d.get("standalone_pf")),
        "trades": _to_int(d.get("trade_count")),
        "drawdown_money": None,
        "drawdown_pct": _to_float(d.get("maxdd_with")),
        "sharpe": _to_float(d.get("sharpe_with")),
    }
    ec = d.get("equity_curve") or []
    if ec and isinstance(ec, list):
        last = ec[-1]
        if isinstance(last, dict):
            head["net_profit"] = _to_float(last.get("net_of_cost"))
    detail = {
        "standalone_pf": _to_float(d.get("standalone_pf")),
        "sharpe_with": _to_float(d.get("sharpe_with")),
        "sharpe_without": _to_float(d.get("sharpe_without")),
        "maxdd_with": _to_float(d.get("maxdd_with")),
        "maxdd_without": _to_float(d.get("maxdd_without")),
        "diversifies": d.get("diversifies"),
        "admit": d.get("admit"),
        "max_corr_to_book": _to_float(d.get("max_corr_to_book")),
        "reason": d.get("reason"),
    }
    return head, detail, "q09_portfolio"


def extract_one(phase: str, evidence_path: str | None) -> tuple[dict, dict, str]:
    """Dispatch on phase → (headline, detail, source). Never raises."""
    empty = {"net_profit": None, "profit_factor": None, "trades": None,
             "drawdown_money": None, "drawdown_pct": None, "sharpe": None}
    if not evidence_path:
        return empty, {}, "no_evidence"
    if not Path(evidence_path).exists():
        return empty, {}, "missing"
    d = _load_json(evidence_path)
    if d is None:
        return empty, {}, "parse_error"
    try:
        if phase in _SUMMARY_RUN_PHASES:
            return _extract_summary_runs(d)
        if phase == "Q04":
            return _extract_q04(d)
        if phase in ("Q05", "Q06"):
            return _extract_q05_q06(d)
        if phase == "Q07":
            return _extract_q07(d)
        if phase == "Q08":
            return _extract_q08(d)
        if phase in ("Q09", "Q09_PORTFOLIO"):
            return _extract_q09_portfolio(d)
        if phase in ("Q10", "Q11"):
            # Q10/Q11 reuse the summary.json runs[] shape when present, else flat.
            if d.get("runs"):
                return _extract_summary_runs(d)
            return _extract_q05_q06(d)
        # Unknown phase with a runs[] payload — best effort.
        if d.get("runs"):
            return _extract_summary_runs(d)
        return empty, {}, f"unknown_phase:{phase}"
    except Exception as e:  # never let one bad file abort the build
        return empty, {"error": str(e)}, "extract_error"


# --------------------------------------------------------------------------- #
# Table management + build                                                     #
# --------------------------------------------------------------------------- #

_SCHEMA = """
CREATE TABLE IF NOT EXISTS ea_metrics (
    work_item_id    TEXT PRIMARY KEY,
    ea_id           TEXT,
    phase           TEXT,
    symbol          TEXT,
    verdict         TEXT,
    status          TEXT,
    is_ablation     INTEGER,
    parent_work_item_id TEXT,
    net_profit      REAL,
    profit_factor   REAL,
    trades          INTEGER,
    drawdown_money  REAL,
    drawdown_pct    REAL,
    sharpe          REAL,
    detail_json     TEXT,
    source          TEXT,
    evidence_path   TEXT,
    evidence_mtime  REAL,
    extracted_at    TEXT
);
CREATE INDEX IF NOT EXISTS ix_ea_metrics_ea ON ea_metrics(ea_id);
CREATE INDEX IF NOT EXISTS ix_ea_metrics_ea_phase_sym ON ea_metrics(ea_id, phase, symbol);
CREATE INDEX IF NOT EXISTS ix_ea_metrics_phase ON ea_metrics(phase);
"""


def ensure_schema(con: sqlite3.Connection) -> None:
    con.executescript(_SCHEMA)
    # Forward-migrate columns added after the first deploy.
    have = {r[1] for r in con.execute("PRAGMA table_info(ea_metrics)").fetchall()}
    for col, decl in (("is_ablation", "INTEGER"), ("parent_work_item_id", "TEXT")):
        if col not in have:
            con.execute(f"ALTER TABLE ea_metrics ADD COLUMN {col} {decl}")
    con.commit()


def _mtime(path: str | None) -> float | None:
    if not path:
        return None
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def build(con: sqlite3.Connection, *, full: bool = False, ea: str | None = None) -> dict:
    ensure_schema(con)
    con.row_factory = sqlite3.Row
    where = ["evidence_path IS NOT NULL"]
    params: list[Any] = []
    if ea:
        where.append("ea_id = ?")
        params.append(ea)
    q = ("SELECT id, ea_id, phase, symbol, verdict, status, evidence_path, payload_json "
         f"FROM work_items WHERE {' AND '.join(where)}")
    rows = con.execute(q, params).fetchall()

    existing: dict[str, float | None] = {}
    if not full:
        emap = con.execute(
            "SELECT work_item_id, evidence_mtime FROM ea_metrics"
            + (" WHERE ea_id = ?" if ea else ""),
            ([ea] if ea else []),
        ).fetchall()
        existing = {r["work_item_id"]: r["evidence_mtime"] for r in emap}

    upserts = 0
    skipped = 0
    by_source: dict[str, int] = {}
    now = _utcnow()
    for r in rows:
        wid = r["id"]
        ev = r["evidence_path"]
        mt = _mtime(ev)
        if (not full) and wid in existing and existing[wid] == mt and mt is not None:
            skipped += 1
            continue
        head, detail, source = extract_one(r["phase"], ev)
        by_source[source] = by_source.get(source, 0) + 1
        is_abl, parent = None, None
        try:
            pl = json.loads(r["payload_json"] or "{}")
            is_abl = 1 if pl.get("is_ablation") else 0
            parent = pl.get("parent_work_item_id")
        except Exception:
            pass
        con.execute(
            """INSERT INTO ea_metrics
                 (work_item_id, ea_id, phase, symbol, verdict, status,
                  is_ablation, parent_work_item_id,
                  net_profit, profit_factor, trades, drawdown_money, drawdown_pct,
                  sharpe, detail_json, source, evidence_path, evidence_mtime, extracted_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(work_item_id) DO UPDATE SET
                 ea_id=excluded.ea_id, phase=excluded.phase, symbol=excluded.symbol,
                 verdict=excluded.verdict, status=excluded.status,
                 is_ablation=excluded.is_ablation,
                 parent_work_item_id=excluded.parent_work_item_id,
                 net_profit=excluded.net_profit, profit_factor=excluded.profit_factor,
                 trades=excluded.trades, drawdown_money=excluded.drawdown_money,
                 drawdown_pct=excluded.drawdown_pct, sharpe=excluded.sharpe,
                 detail_json=excluded.detail_json, source=excluded.source,
                 evidence_path=excluded.evidence_path, evidence_mtime=excluded.evidence_mtime,
                 extracted_at=excluded.extracted_at""",
            (wid, r["ea_id"], r["phase"], r["symbol"], r["verdict"], r["status"],
             is_abl, parent,
             head.get("net_profit"), head.get("profit_factor"), head.get("trades"),
             head.get("drawdown_money"), head.get("drawdown_pct"), head.get("sharpe"),
             json.dumps(detail, ensure_ascii=False) if detail else None,
             source, ev, mt, now),
        )
        upserts += 1
    con.commit()
    return {"scanned": len(rows), "upserts": upserts, "skipped": skipped,
            "by_source": by_source}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Build the ea_metrics archive table.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--full", action="store_true", help="full rebuild (ignore mtime gate)")
    b.add_argument("--ea", help="restrict to one ea_id")
    b.add_argument("--db", default=str(FARM_DB))
    s = sub.add_parser("show")
    s.add_argument("--ea", required=True)
    s.add_argument("--db", default=str(FARM_DB))
    args = ap.parse_args(argv)

    con = sqlite3.connect(args.db)
    if args.cmd == "build":
        res = build(con, full=args.full, ea=args.ea)
        print(json.dumps(res, indent=2))
        return 0
    if args.cmd == "show":
        ensure_schema(con)
        con.row_factory = sqlite3.Row
        rows = con.execute(
            "SELECT phase, symbol, verdict, net_profit, profit_factor, trades, "
            "drawdown_pct, sharpe, source FROM ea_metrics WHERE ea_id=? "
            "ORDER BY phase, symbol", (args.ea,)).fetchall()
        for r in rows:
            print(dict(r))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
