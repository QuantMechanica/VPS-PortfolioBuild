"""ULTRACODE WS-C — one-shot live-sleeve Q10 decay audit (READ-ONLY).

For every sleeve in a portfolio manifest:
  1. Evidence inventory: locate the latest Q10 native report + aggregate via the
     LIVE factory DB (mode=ro, PRAGMA query_only=ON) and the filesystem. Bind
     report / set / EA-binary / window / manifest into ONE identity block with
     SHA-256 where recoverable (unresolvable hash => explicit UNKNOWN).
  2. Decay: parse the native report trade list (NOT the aggregate alone) and
     compute trailing-12m, trailing-24m and Q08-style half-vs-half decay via the
     shared `q10_recency` module. Cross-check the parse against the canonical
     `ftmo_report_cost_reconcile.extract_round_trips` (parity assertion) and the
     native "Total Net Profit".
  3. Classify CURRENT / WATCH / DECAYED / UNKNOWN with documented thresholds.
     Missing DB rows (12567/XNGUSD) propagate UNKNOWN — never imputed. An orphan
     filesystem aggregate is reported separately and clearly flagged.

Writes: evidence_inventory.json, q10_recency_audit.json (machine), and prints a
resolved-DB-path banner. STRICTLY read-only: never writes the DB or any T_Live /
set / manifest / registry file.

Usage:
  python framework/scripts/q10_recency_audit.py \
      --manifest D:/QM/reports/portfolio/portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json \
      --out-dir  D:/QM/reports/ultracode_20260726/wsc2 \
      --endpoint 202512
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve()
sys.path.insert(0, str(_HERE.parents[2]))                                   # repo root
sys.path.insert(0, str(_HERE.parents[2] / "tools" / "strategy_farm" / "portfolio"))

from framework.scripts import q10_recency as R  # noqa: E402

LIVE_DB = r"D:\QM\strategy_farm\state\farm_state.sqlite"
TODAY = dt.date(2026, 7, 26)


# ---------------------------------------------------------------------------
def sha256(path: Path | str | None) -> str | None:
    return R.sha256_file(path)


def open_ro(db_path: str) -> sqlite3.Connection:
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=ON;")
    return con


def q10_rows_for(con: sqlite3.Connection, ea_id: int, symbol: str) -> list[dict[str, Any]]:
    cur = con.cursor()
    cur.execute(
        "SELECT id, ea_id, symbol, status, verdict, evidence_path, setfile_path, updated_at "
        "FROM work_items WHERE phase='Q10' AND ea_id=? AND symbol=? ORDER BY updated_at",
        (f"QM5_{ea_id}", symbol),
    )
    cols = ["id", "ea_id", "symbol", "status", "verdict", "evidence_path", "setfile_path", "updated_at"]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def endpoint_age_days(endpoint_yyyymm: int) -> tuple[str, int, float]:
    y, m = divmod(endpoint_yyyymm, 100)
    # last day of the endpoint month
    end = (dt.date(y + (m == 12), (m % 12) + 1, 1) - dt.timedelta(days=1))
    age = (TODAY - end).days
    return end.isoformat(), age, round(age / 30.44, 1)


def load_aggregate(evidence_path: str) -> dict[str, Any] | None:
    p = Path(evidence_path)
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None


def canonical_parity(report_path: Path) -> dict[str, Any]:
    """Cross-check q10_recency's parser against the canonical Codex-endorsed
    ftmo_report_cost_reconcile parser (trade count + net). Best-effort."""
    try:
        from ftmo_report_cost_reconcile import extract_round_trips  # type: ignore
        trips, stats = extract_round_trips(report_path, None)
        return {
            "available": True,
            "canonical_trades": len(trips),
            "canonical_net": round(sum(t.profit + t.native_swap + t.native_commission for t in trips), 2),
            "canonical_total_trades_stat": stats.get("total_trades"),
        }
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "error": f"{type(exc).__name__}:{exc}"}


def audit_report(report_path: Path, endpoint: int, has_db_row: bool) -> dict[str, Any]:
    """Parse one native report and compute recency + parity + reconciliation."""
    out: dict[str, Any] = {
        "report_htm": str(report_path),
        "report_htm_exists": report_path.exists(),
        "report_sha256": sha256(report_path) if report_path.exists() else None,
    }
    if not report_path.exists():
        out["parse_status"] = "MISSING"
        out["recency"] = R.compute_recency([], None, endpoint, has_db_row=has_db_row)
        return out
    try:
        trades, stats = R.extract_closed_trades(report_path)
    except Exception as exc:  # noqa: BLE001
        out["parse_status"] = f"PARSE_FAIL:{type(exc).__name__}:{exc}"
        out["recency"] = {"classification": {"verdict": "UNKNOWN",
                          "reason": f"parse_or_reconcile_failure:{type(exc).__name__}"}}
        return out
    out["parse_status"] = "OK"
    out["native_stats"] = {k: stats.get(k) for k in ("symbol", "period", "net", "pf", "total_trades")}
    out["recency"] = R.compute_recency(trades, stats, endpoint_yyyymm=endpoint, has_db_row=has_db_row)
    out["parity"] = canonical_parity(report_path)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="WS-C Q10 recency decay audit (read-only)")
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--db", default=LIVE_DB)
    ap.add_argument("--endpoint", type=int, default=202512,
                    help="Fixed window endpoint yyyymm for comparability (default 202512)")
    args = ap.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    end_iso, age_days, age_months = endpoint_age_days(args.endpoint)
    manifest_sha = sha256(args.manifest)
    print("=" * 78)
    print(f"WS-C Q10 RECENCY DECAY AUDIT  (READ-ONLY)")
    print(f"RESOLVED_LIVE_DB_PATH : {args.db}")
    print(f"MANIFEST              : {args.manifest}")
    print(f"MANIFEST_SHA256       : {manifest_sha or R.UNKNOWN}")
    print(f"WINDOW_ENDPOINT       : {args.endpoint}  ({end_iso})")
    print(f"ENDPOINT_AGE_VS_TODAY : {age_days} days (~{age_months} months) as of {TODAY.isoformat()}")
    print(f"THRESHOLDS            : WATCH>={R.RECENCY_WATCH_PCT}%  DECAYED>={R.RECENCY_DECAY_PCT}%  "
          f"Q08>={R.Q08_MAX_DECLINE_PCT}%  min_full={R.Q08_SWING_FLOOR}  min_t24={R.MIN_TRAILING_TRADES}")
    print("=" * 78)

    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    sleeves = manifest["sleeves"]
    con = open_ro(args.db)

    inventory: list[dict[str, Any]] = []
    for s in sleeves:
        ea_id = int(s["ea_id"])
        symbol = s["symbol"]
        rows = q10_rows_for(con, ea_id, symbol)
        rec: dict[str, Any] = {
            "ea_id": ea_id,
            "symbol": symbol,
            "ea_label": s.get("ea_label"),
            "magic_number": s.get("magic_number"),
            "weight": s.get("weight"),
            "risk_percent": s.get("risk_percent"),
            "new_candidate": s.get("new_candidate"),
            "manifest_trades": s.get("trades"),
            "manifest_ex5_path": s.get("ex5_path"),
            "manifest_ex5_sha256_recorded": s.get("ex5_sha256"),
            "manifest_backtest_set": s.get("backtest_set"),
            "db_q10_rows": rows,
            "db_q10_row_count": len(rows),
        }
        # binary identity (read-only hash of the manifest-declared ex5, if present)
        if s.get("ex5_path"):
            exp = Path(s["ex5_path"])
            rec["ex5_sha256_ondisk"] = sha256(exp) if exp.exists() else None
            rec["ex5_exists_ondisk"] = exp.exists()
        # set identity
        if s.get("backtest_set"):
            bs = Path(s["backtest_set"])
            rec["backtest_set_sha256"] = sha256(bs) if bs.exists() else None
            rec["backtest_set_exists"] = bs.exists()

        # window endpoint + report used for the identity block are filled below
        # once the authoritative (or orphan) aggregate is resolved.
        report_for_identity: str | None = None
        setfile_for_identity: str | None = s.get("backtest_set")
        window_endpoint_for_identity: Any = None

        if not rows:
            # No DB-authoritative Q10 row -> UNKNOWN (propagated honestly).
            rec["evidence_status"] = "NO_DB_Q10_ROW"
            rec["classification"] = {"verdict": "UNKNOWN", "reason": "no_db_q10_row"}
            # Surface any orphan filesystem aggregate as clearly-flagged secondary evidence.
            orphan_agg = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q10/{symbol.replace('.', '_')}/aggregate.json")
            if orphan_agg.exists():
                agg = load_aggregate(str(orphan_agg))
                rec["orphan_filesystem_aggregate"] = {
                    "path": str(orphan_agg),
                    "provenance": "FILESYSTEM_ORPHAN_NO_DB_ROW (NOT DB-authoritative; do not treat as verified)",
                    "aggregate_verdict": (agg or {}).get("verdict"),
                    "aggregate_pf": (agg or {}).get("pf"),
                    "aggregate_trades": (agg or {}).get("trades"),
                    "report_htm": (agg or {}).get("report_htm"),
                    "history_to": (agg or {}).get("history_to"),
                }
                rhtm = (agg or {}).get("report_htm")
                window_endpoint_for_identity = (agg or {}).get("history_to")
                if rhtm:
                    report_for_identity = rhtm
                    orphan_audit = audit_report(Path(rhtm), args.endpoint, has_db_row=False)
                    # recompute recency WITHOUT the has_db_row gate so the number is visible,
                    # but keep the authoritative classification UNKNOWN.
                    try:
                        trades, stats = R.extract_closed_trades(Path(rhtm))
                        orphan_num = R.compute_recency(trades, stats, endpoint_yyyymm=args.endpoint, has_db_row=True)
                        orphan_audit["orphan_recency_if_it_had_a_row"] = orphan_num
                        orphan_audit["orphan_recency_if_it_had_a_row"]["classification"]["provenance"] = \
                            "ORPHAN - informational only; authoritative verdict remains UNKNOWN"
                    except Exception:  # noqa: BLE001
                        pass
                    rec["orphan_filesystem_aggregate"]["audit"] = orphan_audit
            # Identity block binds whatever IS resolvable (set/ex5/manifest) even
            # with no DB report; report_sha256 becomes UNKNOWN when no report.
            rec["identity"] = R.evidence_identity(
                report_htm=report_for_identity,
                setfile_path=setfile_for_identity,
                ex5_path=s.get("ex5_path"),
                window_endpoint=window_endpoint_for_identity,
                manifest_ref=str(args.manifest),
            )
            inventory.append(rec)
            continue

        # Authoritative: choose the latest Q10 row by updated_at.
        primary = rows[-1]
        rec["evidence_status"] = "DB_Q10_ROW"
        rec["primary_row_id"] = primary["id"]
        rec["primary_verdict"] = primary["verdict"]
        rec["primary_updated_at"] = primary["updated_at"]
        rec["primary_setfile_path"] = primary["setfile_path"]
        rec["multiple_db_rows"] = len(rows) > 1
        if primary["setfile_path"]:
            sp = Path(primary["setfile_path"])
            rec["primary_setfile_sha256"] = sha256(sp) if sp.exists() else None
            setfile_for_identity = primary["setfile_path"]

        agg = load_aggregate(primary["evidence_path"]) or {}
        rec["aggregate_path"] = primary["evidence_path"]
        rec["aggregate_pf"] = agg.get("pf")
        rec["aggregate_dd_pct"] = agg.get("dd_pct")
        rec["aggregate_trades"] = agg.get("trades")
        rec["aggregate_history_from"] = agg.get("history_from")
        rec["aggregate_history_to"] = agg.get("history_to")
        report_htm = agg.get("report_htm")
        report_for_identity = report_htm
        window_endpoint_for_identity = agg.get("history_to")
        if not report_htm:
            rec["classification"] = {"verdict": "UNKNOWN", "reason": "aggregate_missing_report_htm"}
            rec["identity"] = R.evidence_identity(
                report_htm=None, setfile_path=setfile_for_identity,
                ex5_path=s.get("ex5_path"), window_endpoint=window_endpoint_for_identity,
                manifest_ref=str(args.manifest),
            )
            inventory.append(rec)
            continue

        au = audit_report(Path(report_htm), args.endpoint, has_db_row=True)
        rec["audit"] = au
        recency = au.get("recency", {})
        rec["classification"] = recency.get("classification", {"verdict": "UNKNOWN", "reason": "no_recency"})
        # reconciliation flags
        parsed_full = (recency.get("full") or {}).get("trades")
        rec["reconcile"] = {
            "parsed_trades": parsed_full,
            "aggregate_trades": agg.get("trades"),
            "manifest_trades": s.get("trades"),
            "native_total_trades": (au.get("native_stats") or {}).get("total_trades"),
            "parity": au.get("parity"),
            "net_reconciles_to_native": (
                au.get("native_stats") and recency.get("full")
                and abs((recency["full"]["net"] or 0) - (au["native_stats"]["net"] or 0)) < 1.0
            ),
        }
        # One identity block binding report / set / EX5 SHA-256 + window + manifest.
        rec["identity"] = R.evidence_identity(
            report_htm=report_for_identity,
            setfile_path=setfile_for_identity,
            ex5_path=s.get("ex5_path"),
            window_endpoint=window_endpoint_for_identity,
            manifest_ref=str(args.manifest),
        )
        inventory.append(rec)

    con.close()

    summary = {
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "resolved_live_db_path": args.db,
        "manifest": str(args.manifest),
        "manifest_sha256": manifest_sha or R.UNKNOWN,
        "manifest_book": manifest.get("book"),
        "manifest_status": manifest.get("status"),
        "manifest_total_risk_pct": manifest.get("total_risk_pct"),
        "window_endpoint_yyyymm": args.endpoint,
        "window_endpoint_date": end_iso,
        "endpoint_age_days_vs_today": age_days,
        "endpoint_age_months_vs_today": age_months,
        "today": TODAY.isoformat(),
        "recency_axis_enforced": R.RECENCY_AXIS_ENFORCED,
        "identity_schema": R.RECENCY_IDENTITY_VERSION,
        "thresholds": {
            "recency_watch_pct": R.RECENCY_WATCH_PCT,
            "recency_decay_pct": R.RECENCY_DECAY_PCT,
            "q08_max_decline_pct": R.Q08_MAX_DECLINE_PCT,
            "min_full_trades": R.Q08_SWING_FLOOR,
            "min_trailing24m_trades": R.MIN_TRAILING_TRADES,
        },
        "n_sleeves": len(sleeves),
    }
    counts: dict[str, int] = {"CURRENT": 0, "WATCH": 0, "DECAYED": 0, "UNKNOWN": 0}
    for rec in inventory:
        counts[rec["classification"]["verdict"]] = counts.get(rec["classification"]["verdict"], 0) + 1
    summary["verdict_counts"] = counts
    non_current = [
        {"ea_id": r["ea_id"], "symbol": r["symbol"], "weight": r.get("weight"),
         "verdict": r["classification"]["verdict"],
         "at_cap": r.get("weight") == 1.0}
        for r in inventory if r["classification"]["verdict"] != "CURRENT"
    ]
    summary["non_current_sleeves"] = non_current
    summary["non_current_count"] = len(non_current)
    capped_nc = [f"{r['ea_id']}/{r['symbol']}" for r in non_current if r["at_cap"]]
    uncapped_nc = [f"{r['ea_id']}/{r['symbol']}" for r in non_current if not r["at_cap"]]
    summary["headline"] = (
        f"{len(non_current)} non-CURRENT sleeves: {len(capped_nc)} capped "
        f"[{', '.join(f'{r}' for r in capped_nc)}] PLUS {len(uncapped_nc)} uncapped "
        f"[{', '.join(f'{r}' for r in uncapped_nc)}]. "
        "This is NOT 'exactly the three capped sleeves' - an uncapped sleeve is "
        "non-CURRENT too."
    )
    summary["final22_status"] = (
        "OWNER decision decisions/2026-07-26_book_final22_owner_decisions.md: "
        "12567/XNGUSD DROPPED and 10939/GBPUSD REMOVED+re-qualification from the "
        "evening deploy book (FINAL22); 10919/XTIUSD (UNKNOWN) and 13128/NDX (WATCH) "
        "retained, OWNER-acknowledged. This audit ran on FINAL24b (the 24-sleeve book "
        "Codex reproduced) and is the evidence that drove FINAL22."
    )

    (args.out_dir / "q10_recency_audit.json").write_text(
        json.dumps({"summary": summary, "sleeves": inventory}, indent=2), encoding="utf-8")
    (args.out_dir / "evidence_inventory.json").write_text(
        json.dumps({"summary": summary,
                    "inventory": [{k: v for k, v in r.items() if k != "audit"} for r in inventory]},
                   indent=2), encoding="utf-8")

    print(f"\nVERDICT COUNTS: {counts}")
    print(f"NON-CURRENT ({len(non_current)}): " +
          ", ".join(f"{r['ea_id']}/{r['symbol']}={r['verdict']}"
                    f"{'(cap)' if r['at_cap'] else ''}" for r in non_current))
    print(f"WROTE: {args.out_dir / 'q10_recency_audit.json'}")
    print(f"WROTE: {args.out_dir / 'evidence_inventory.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
