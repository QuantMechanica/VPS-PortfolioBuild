import json
import sqlite3
from pathlib import Path

from tools.strategy_farm.audit_q04_native_report_guard import audit_q04_row


def _write_summary(path: Path, pf: float, trades: int) -> None:
    path.write_text(
        json.dumps({"runs": [{"profit_factor": pf, "total_trades": trades}]}),
        encoding="utf-8",
    )


def test_guard_audit_downgrades_stream_false_positive(tmp_path: Path) -> None:
    summaries = []
    folds = []
    for idx, (stream_pf, stream_trades, report_pf, report_trades) in enumerate(
        [
            (6.2, 399, 0.69, 434),
            (7.0, 429, 0.73, 468),
            (46.8, 441, 1.38, 468),
        ],
        start=1,
    ):
        summary = tmp_path / f"summary_{idx}.json"
        _write_summary(summary, report_pf, report_trades)
        summaries.append(summary)
        folds.append(
            {
                "id": f"F{idx}",
                "pf_net": stream_pf,
                "trades": stream_trades,
                "commission_basis": "worst_case_dxz_ftmo_notional",
                "summary_path": str(summary),
            }
        )

    aggregate = tmp_path / "aggregate.json"
    aggregate.write_text(json.dumps({"verdict": "PASS", "symbol": "GBPUSD.DWX", "folds": folds}), encoding="utf-8")

    row = {
        "id": "wi-1",
        "ea_id": "QM5_10041",
        "symbol": "GBPUSD.DWX",
        "verdict": "PASS",
        "evidence_path": str(aggregate),
        "setfile_path": "demo.set",
        "updated_at": "2026-06-28T00:00:00+00:00",
    }
    result = audit_q04_row(row)

    assert result is not None
    assert result.old_verdict == "PASS"
    assert result.guarded_verdict == "FAIL"
    assert result.guard_trigger_count == 3
    assert result.folds[0].guard_reason is not None


def test_guard_audit_keeps_matching_pass(tmp_path: Path) -> None:
    folds = []
    for idx, pf in enumerate((1.2, 1.3, 1.4), start=1):
        summary = tmp_path / f"summary_{idx}.json"
        _write_summary(summary, pf, 100)
        folds.append(
            {
                "id": f"F{idx}",
                "pf_net": pf,
                "trades": 100,
                "commission_basis": "worst_case_dxz_ftmo_notional",
                "summary_path": str(summary),
            }
        )
    aggregate = tmp_path / "aggregate.json"
    aggregate.write_text(json.dumps({"verdict": "PASS", "symbol": "USDJPY.DWX", "folds": folds}), encoding="utf-8")

    result = audit_q04_row(
        {
            "id": "wi-2",
            "ea_id": "QM5_11476",
            "symbol": "USDJPY.DWX",
            "verdict": "PASS",
            "evidence_path": str(aggregate),
            "setfile_path": "demo.set",
            "updated_at": "2026-06-28T00:00:00+00:00",
        }
    )

    assert result is not None
    assert result.guarded_verdict == "PASS"
    assert result.guard_trigger_count == 0
