"""Build a compatible summary from deterministic MT5 reports after wrapper loss."""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
from pathlib import Path
from typing import Any, Sequence

try:
    from .ftmo_report_cost_reconcile import extract_round_trips, file_sha256
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_report_cost_reconcile import extract_round_trips, file_sha256  # type: ignore


DETERMINISTIC_FIELDS = (
    "expert",
    "symbol",
    "period",
    "net",
    "gross_profit",
    "gross_loss",
    "pf",
    "total_trades",
    "equity_drawdown",
    "equity_drawdown_pct",
)


def trade_digest(trades: Sequence[Any]) -> str:
    payload = json.dumps(
        [dataclasses.asdict(trade) for trade in trades],
        sort_keys=True,
        default=str,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def recover_summary(
    *,
    ea_id: int,
    ea_label: str,
    expert: str,
    symbol: str,
    period: str,
    reports: Sequence[Path],
    recovery_reason: str,
) -> dict[str, Any]:
    if len(reports) < 2:
        raise ValueError("at least two reports are required")
    parsed = []
    for report in reports:
        if not report.exists():
            raise FileNotFoundError(report)
        trades, metrics = extract_round_trips(report, symbol)
        parsed.append((report, trades, metrics))
    reference_trades = parsed[0][1]
    reference_metrics = parsed[0][2]
    if not reference_trades:
        raise ValueError("reports contain no round trips")
    for report, trades, metrics in parsed[1:]:
        if trades != reference_trades:
            raise ValueError(f"round-trip mismatch: {report}")
        if any(metrics.get(field) != reference_metrics.get(field) for field in DETERMINISTIC_FIELDS):
            raise ValueError(f"report metric mismatch: {report}")

    runs = []
    for index, (report, trades, metrics) in enumerate(parsed, start=1):
        runs.append(
            {
                "run": f"recovered_run_{index:02d}",
                "status": "OK",
                "exit_code": None,
                "report_source_path": str(report),
                "report_canonical_path": str(report),
                "report_size_bytes": report.stat().st_size,
                "report_sha256": file_sha256(report),
                "total_trades": int(metrics["total_trades"]),
                "total_trades_raw": str(metrics["total_trades"]),
                "profit_factor": float(metrics["pf"]),
                "profit_factor_raw": str(metrics["pf"]),
                "drawdown": float(metrics["equity_drawdown"]),
                "drawdown_raw": str(metrics["equity_drawdown"]),
                "net_profit": float(metrics["net"]),
                "net_profit_raw": str(metrics["net"]),
                "round_trip_digest": trade_digest(trades),
            }
        )
    return {
        "schema_version": 1,
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "result": "PASS",
        "reason_classes": ["RECOVERED_WRAPPER_LOSS_DETERMINISTIC_REPORTS"],
        "ea_id": int(ea_id),
        "ea_label": ea_label,
        "expert": expert,
        "symbol": symbol.upper(),
        "period": period,
        "requested_runs": len(reports),
        "attempted_runs": len(reports),
        "deterministic": True,
        "recovery": {
            "reason": recovery_reason,
            "contract": "identical_report_metrics_and_exact_round_trip_sequence",
            "report_hashes_may_differ_due_to_html_metadata": True,
        },
        "runs": runs,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ea-id", type=int, required=True)
    parser.add_argument("--ea-label", required=True)
    parser.add_argument("--expert", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--period", required=True)
    parser.add_argument("--report", type=Path, action="append", required=True)
    parser.add_argument("--recovery-reason", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = recover_summary(
        ea_id=args.ea_id,
        ea_label=args.ea_label,
        expert=args.expert,
        symbol=args.symbol,
        period=args.period,
        reports=args.report,
        recovery_reason=args.recovery_reason,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"wrote {args.out} trades={artifact['runs'][0]['total_trades']} "
        f"pf={artifact['runs'][0]['profit_factor']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
