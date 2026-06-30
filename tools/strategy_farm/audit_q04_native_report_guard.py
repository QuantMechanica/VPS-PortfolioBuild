"""Audit historic Q04 PASS-ish rows against native MT5 fold summaries.

The Q04 runner grades from the per-trade stream when possible because that lets
it apply the shared commission model. A partial stream can miss exits, though,
so the runner now falls back to native MT5 report metrics when the stream and
report materially disagree. This script applies that same guard read-only to
historic Q04 aggregate.json files and reports likely false positives.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts.q04_walkforward import (
    aggregate_verdict,
    guard_pf_net_against_report_summary,
    parse_pf_from_report_summary,
)


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_OUT_DIR = Path(r"D:\QM\reports\analysis")
Q04_PASSISH = {"PASS", "PASS_SOFT", "PASS_LOWFREQ"}


def _utc_stamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def _load_json(path: str | Path | None) -> dict[str, Any]:
    if not path:
        return {}
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8-sig", errors="ignore"))
    except (OSError, json.JSONDecodeError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def _to_int(value: Any) -> int:
    try:
        return int(float(value or 0))
    except (TypeError, ValueError):
        return 0


def _to_float(value: Any) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


@dataclass
class FoldAudit:
    fold_id: str
    old_pf: float | None
    old_trades: int
    report_pf: float | None
    report_trades: int
    guarded_pf: float | None
    guarded_trades: int
    guard_reason: str | None
    summary_path: str | None


@dataclass
class RowAudit:
    work_item_id: str
    ea_id: str
    symbol: str
    db_verdict: str
    aggregate_verdict: str
    old_verdict: str
    guarded_verdict: str
    guarded_reason: str
    evidence_path: str
    setfile_path: str
    updated_at: str
    guard_trigger_count: int
    missing_summary_count: int
    folds: list[FoldAudit]

    @property
    def verdict_changed(self) -> bool:
        return self.old_verdict != self.guarded_verdict


def _guard_fold(fold: dict[str, Any]) -> tuple[dict[str, Any], FoldAudit]:
    summary_path = fold.get("summary_path")
    report_pf, report_trades = (
        parse_pf_from_report_summary(Path(summary_path))
        if summary_path and Path(summary_path).exists()
        else (None, 0)
    )
    old_pf = _to_float(fold.get("pf_net"))
    old_trades = _to_int(fold.get("trades"))
    basis = str(fold.get("commission_basis") or "")
    guarded_pf, guarded_trades, guarded_basis, guard_reason = guard_pf_net_against_report_summary(
        pf_net=old_pf,
        trades=old_trades,
        commission_basis=basis,
        report_pf=report_pf,
        report_trades=report_trades,
    )

    guarded = dict(fold)
    guarded["pf_net"] = guarded_pf
    guarded["trades"] = guarded_trades
    guarded["commission_basis"] = guarded_basis
    if guard_reason:
        guarded["report_pf"] = report_pf
        guarded["report_trades"] = report_trades
        guarded["report_guard_reason"] = guard_reason
        guarded["sim_commission_total"] = None
        guarded["gross_total"] = None

    return guarded, FoldAudit(
        fold_id=str(fold.get("id") or ""),
        old_pf=old_pf,
        old_trades=old_trades,
        report_pf=report_pf,
        report_trades=report_trades,
        guarded_pf=guarded_pf,
        guarded_trades=guarded_trades,
        guard_reason=guard_reason,
        summary_path=str(summary_path) if summary_path else None,
    )


def audit_q04_row(row: sqlite3.Row | dict[str, Any]) -> RowAudit | None:
    data = dict(row)
    evidence_path = str(data.get("evidence_path") or "")
    aggregate = _load_json(evidence_path)
    folds = aggregate.get("folds") or []
    if not folds:
        return None

    guarded_folds: list[dict[str, Any]] = []
    fold_audits: list[FoldAudit] = []
    for fold in folds:
        if not isinstance(fold, dict):
            continue
        guarded, fold_audit = _guard_fold(fold)
        guarded_folds.append(guarded)
        fold_audits.append(fold_audit)

    guarded_verdict, guarded_reason = aggregate_verdict(guarded_folds)
    db_verdict = str(data.get("verdict") or "")
    aggregate_verdict_value = str(aggregate.get("verdict") or "")
    old_verdict = db_verdict or aggregate_verdict_value
    return RowAudit(
        work_item_id=str(data.get("id") or ""),
        ea_id=str(data.get("ea_id") or ""),
        symbol=str(aggregate.get("symbol") or data.get("symbol") or ""),
        db_verdict=db_verdict,
        aggregate_verdict=aggregate_verdict_value,
        old_verdict=old_verdict,
        guarded_verdict=guarded_verdict,
        guarded_reason=guarded_reason,
        evidence_path=evidence_path,
        setfile_path=str(data.get("setfile_path") or ""),
        updated_at=str(data.get("updated_at") or ""),
        guard_trigger_count=sum(1 for f in fold_audits if f.guard_reason),
        missing_summary_count=sum(1 for f in fold_audits if f.report_pf is None),
        folds=fold_audits,
    )


def load_q04_passish_rows(db_path: Path, limit: int | None = None) -> list[sqlite3.Row]:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    try:
        sql = """
            SELECT id, ea_id, symbol, verdict, evidence_path, setfile_path, updated_at
            FROM work_items
            WHERE status='done'
              AND phase='Q04'
              AND verdict IN ('PASS','PASS_SOFT','PASS_LOWFREQ')
            ORDER BY updated_at ASC
        """
        if limit:
            sql += " LIMIT ?"
            return conn.execute(sql, (limit,)).fetchall()
        return conn.execute(sql).fetchall()
    finally:
        conn.close()


def build_report(rows: list[RowAudit], db_path: Path) -> dict[str, Any]:
    changed = [r for r in rows if r.verdict_changed]
    guarded = [r for r in rows if r.guard_trigger_count]
    false_positive = [
        r for r in changed
        if r.old_verdict in Q04_PASSISH and r.guarded_verdict not in Q04_PASSISH
    ]
    guard_driven_false_positive = [r for r in false_positive if r.guard_trigger_count]
    evidence_missing_false_positive = [
        r for r in false_positive
        if r.guard_trigger_count == 0 and r.missing_summary_count
    ]
    db_aggregate_mismatch = [r for r in rows if r.db_verdict and r.aggregate_verdict and r.db_verdict != r.aggregate_verdict]
    return {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "db_path": str(db_path),
        "rows_audited": len(rows),
        "guard_triggered_rows": len(guarded),
        "verdict_changed_rows": len(changed),
        "passish_to_nonpassish_rows": len(false_positive),
        "guard_driven_passish_to_nonpassish_rows": len(guard_driven_false_positive),
        "evidence_missing_passish_to_nonpassish_rows": len(evidence_missing_false_positive),
        "db_aggregate_verdict_mismatch_rows": len(db_aggregate_mismatch),
        "rows": [asdict(r) for r in rows],
    }


def write_markdown(report: dict[str, Any], out_path: Path, *, only_changed: bool = False) -> None:
    rows = report["rows"]
    if only_changed:
        rows = [r for r in rows if r["old_verdict"] != r["guarded_verdict"] or r["guard_trigger_count"]]

    lines = [
        "# Q04 Native Report Guard Global Audit",
        "",
        f"- Generated UTC: `{report['generated_at_utc']}`",
        f"- DB: `{report['db_path']}`",
        f"- Q04 PASS-ish rows audited: **{report['rows_audited']}**",
        f"- Rows with native-report guard triggers: **{report['guard_triggered_rows']}**",
        f"- Verdict changes: **{report['verdict_changed_rows']}**",
        f"- PASS-ish -> non-PASS-ish: **{report['passish_to_nonpassish_rows']}**",
        f"- Guard-driven PASS-ish -> non-PASS-ish: **{report['guard_driven_passish_to_nonpassish_rows']}**",
        f"- Evidence-missing PASS-ish -> non-PASS-ish: **{report['evidence_missing_passish_to_nonpassish_rows']}**",
        f"- DB/Aggregate verdict mismatches: **{report['db_aggregate_verdict_mismatch_rows']}**",
        "",
        "## Flagged Rows",
        "",
    ]
    if not rows:
        lines.append("No guarded differences found.")
    else:
        lines.append("| EA | symbol | DB | aggregate | guarded | guard folds | missing summaries | evidence |")
        lines.append("|---|---|---|---|---|---:|---:|---|")
        for row in rows:
            evidence = str(row["evidence_path"]).replace("|", "\\|")
            lines.append(
                f"| `{row['ea_id']}` | `{row['symbol']}` | `{row['db_verdict']}` | "
                f"`{row['aggregate_verdict']}` | `{row['guarded_verdict']}` | "
                f"{row['guard_trigger_count']} | "
                f"{row['missing_summary_count']} | `{evidence}` |"
            )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only Q04 native-report guard audit")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--out-json", type=Path)
    parser.add_argument("--out-md", type=Path)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--only-changed", action="store_true")
    args = parser.parse_args()

    rows = [r for r in (audit_q04_row(row) for row in load_q04_passish_rows(args.db, args.limit)) if r]
    report = build_report(rows, args.db)

    stamp = _utc_stamp()
    out_json = args.out_json or DEFAULT_OUT_DIR / f"q04_native_report_guard_audit_{stamp}.json"
    out_md = args.out_md or Path("docs") / "ops" / f"Q04_NATIVE_REPORT_GUARD_GLOBAL_AUDIT_{stamp}.md"
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(report, out_md, only_changed=args.only_changed)

    print(json.dumps({
        "out_json": str(out_json),
        "out_md": str(out_md),
        "rows_audited": report["rows_audited"],
        "guard_triggered_rows": report["guard_triggered_rows"],
        "verdict_changed_rows": report["verdict_changed_rows"],
        "passish_to_nonpassish_rows": report["passish_to_nonpassish_rows"],
        "guard_driven_passish_to_nonpassish_rows": report["guard_driven_passish_to_nonpassish_rows"],
        "evidence_missing_passish_to_nonpassish_rows": report["evidence_missing_passish_to_nonpassish_rows"],
        "db_aggregate_verdict_mismatch_rows": report["db_aggregate_verdict_mismatch_rows"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
