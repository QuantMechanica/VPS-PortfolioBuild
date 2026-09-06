#!/usr/bin/env python3
"""Read-only replay of Q04 INFRA_FAIL rows with valid native reports.

This tool never writes the farm database. It shows which recent rows would
receive an existing Q04 economic verdict after the native-report fallback in
``q04_walkforward``.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from framework.scripts import q04_walkforward as q04  # noqa: E402


def replay_row(row: sqlite3.Row) -> dict | None:
    evidence_path = Path(str(row["evidence_path"] or ""))
    try:
        aggregate = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None
    folds = aggregate.get("folds") or []
    if not isinstance(folds, list) or not folds:
        return None

    replayed: list[dict] = []
    fallback_folds: list[str] = []
    for source_fold in folds:
        if not isinstance(source_fold, dict):
            return None
        fold = dict(source_fold)
        if fold.get("invalid_reason") == "stream_and_selfreport_missing":
            summary_path = Path(str(fold.get("source_summary_path") or ""))
            pf, trades, economic_reason = q04.completed_report_economic_fallback(
                summary_path
            )
            if economic_reason:
                fold.update({
                    "pf_net": pf,
                    "trades": trades,
                    "invalid_reason": None,
                    "status": "FAIL" if economic_reason == "STRATEGY_MIN_TRADES_NOT_MET" else "OK",
                    "verdict_reason": economic_reason,
                    "commission_basis": "native_report_economic_fallback",
                    "report_guard_reason": economic_reason,
                })
                fallback_folds.append(str(fold.get("id") or ""))
        replayed.append(fold)

    if not fallback_folds:
        return None
    verdict, reason = q04.aggregate_verdict(replayed)
    lowfreq_verdict = lowfreq_reason = None
    if verdict == "FAIL" and q04.is_lowfreq_eligible(replayed):
        lowfreq_verdict, lowfreq_reason = q04.aggregate_verdict_lowfreq(replayed)
        if lowfreq_verdict == "PASS_LOWFREQ":
            verdict, reason = lowfreq_verdict, lowfreq_reason
        else:
            reason = f"{reason} || lowfreq:{lowfreq_verdict}:{lowfreq_reason}"
    if verdict == "INVALID":
        return None
    return {
        "work_item_id": row["id"],
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "updated_at": row["updated_at"],
        "stored_verdict": row["verdict"],
        "replay_verdict": verdict,
        "replay_reason": reason,
        "fallback_folds": fallback_folds,
        "lowfreq_verdict": lowfreq_verdict,
        "lowfreq_reason": lowfreq_reason,
        "evidence_path": str(evidence_path),
        "would_leave_stranded_infra_lane": verdict != "INFRA_FAIL",
    }


def build_replay(db_path: Path, *, days: int, now: datetime) -> dict:
    cutoff = now - timedelta(days=days)
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            """
            SELECT id, ea_id, symbol, verdict, evidence_path, updated_at
            FROM work_items
            WHERE phase='Q04' AND status IN ('done','failed')
              AND verdict='INFRA_FAIL' AND updated_at>=?
            ORDER BY updated_at, id
            """,
            (cutoff.isoformat(timespec="seconds"),),
        ).fetchall()
    finally:
        conn.close()
    reclassified = [result for row in rows if (result := replay_row(row)) is not None]
    return {
        "schema": "qm.q04-economic-replay/v1",
        "mode": "dry_run_read_only",
        "database": str(db_path),
        "generated_at_utc": now.isoformat(timespec="seconds"),
        "window_days": days,
        "cutoff_utc": cutoff.isoformat(timespec="seconds"),
        "q04_infra_rows_scanned": len(rows),
        "rows_that_would_reclassify": len(reclassified),
        "stored_verdict_changes_applied": 0,
        "rows": reclassified,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(r"D:\QM\strategy_farm\state\farm_state.sqlite"),
    )
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if args.days <= 0:
        parser.error("--days must be positive")
    report = build_replay(args.db, days=args.days, now=datetime.now(timezone.utc))
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
