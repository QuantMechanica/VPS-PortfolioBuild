from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_cost_adjusted_export as exporter
from tools.strategy_farm.portfolio import ftmo_spread_calibration as calibration


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def _fixture(tmp_path: Path, *, legacy: bool = False) -> dict[str, Path | str]:
    cost = tmp_path / "cost.json"
    _json(
        cost,
        [
            {
                "code": "XAU/USD",
                "displayCode": "XAU/USD",
                "active": True,
                "commission": 0.1,
                "commissionType": "percent",
                "swapLong": -1.0,
                "swapShort": -2.0,
                "swapType": "points",
                "contractSize": 100,
                "digits": 2,
                "profitCurrency": "USD",
            }
        ],
    )
    spread = tmp_path / "spread.json"
    _json(
        spread,
        {
            "schema": calibration.ARTIFACT_SCHEMA,
            "status": "PASS",
            "evidence_class": exporter.EVIDENCE_CLASS,
            "session_bucket_minutes": 60,
            "pairs": [
                {
                    "evaluator_symbol": "XAUUSD",
                    "ftmo_symbol": "XAUUSD",
                    "dxz_symbol": "XAUUSD.DWX",
                    "session_buckets": [
                        {
                            "bucket_utc": "08:00-08:59Z",
                            "conservative_delta_price_per_side": 0.02,
                        }
                    ],
                }
            ],
        },
    )
    q08 = tmp_path / "q08.jsonl"
    row = {
        "event": "TRADE_CLOSED",
        "money_basis": exporter.MONEY_BASIS,
        "magic": 101280034,
        "side": "BUY",
        "entry_price": 100.0,
        "exit_price": 110.0,
        "time": "2026-07-21T08:00:00Z",
        "entry_time": "2026-07-20T08:00:00Z",
        "mae_acct": -50.0,
        "net": 988.0,
        "profit": 1000.0,
        "swap": -2.0,
        "fee": 0.0,
        "commission": -10.0,
        "entry_commission": -5.0,
        "exit_commission": -5.0,
        "volume": 1.0,
        "notional": 10000.0,
        "symbol": "XAUUSD.DWX",
    }
    if legacy:
        for field in ("money_basis", "side", "entry_price", "exit_price", "fee", "entry_commission", "exit_commission"):
            row.pop(field)
    q08.write_text(json.dumps(row) + "\n", encoding="utf-8")
    return {
        "cost": cost,
        "cost_sha": _sha(cost),
        "spread": spread,
        "spread_sha": _sha(spread),
        "q08": q08,
        "out": tmp_path / "adjusted.jsonl",
        "receipt": tmp_path / "receipt.json",
    }


def _export(case: dict[str, Path | str]) -> dict[str, object]:
    return exporter.export_cost_adjusted_stream(
        sleeve_id="10128:XAUUSD",
        evaluator_symbol="XAUUSD",
        source_symbol="XAUUSD.DWX",
        native_symbol="XAUUSD",
        ftmo_code="XAU/USD",
        q08_path=case["q08"],
        cost_snapshot_path=case["cost"],
        calibration_path=case["spread"],
        expected_calibration_sha256=case["spread_sha"],
        first_day=dt.date(2026, 7, 20),
        last_day=dt.date(2026, 7, 21),
        initial_equity=100_000.0,
        output_path=case["out"],
        receipt_path=case["receipt"],
        expected_cost_sha256=case["cost_sha"],
    )


def test_exact_cost_substitution_and_per_side_spread_charge(tmp_path: Path) -> None:
    case = _fixture(tmp_path)
    receipt = _export(case)
    rows = [json.loads(line) for line in Path(case["out"]).read_text().splitlines()]

    assert receipt["evidence_class"] == exporter.EVIDENCE_CLASS
    assert receipt["native_ftmo_execution_claim"] is False
    assert receipt["totals"] == pytest.approx(
        {
            "source_commission_removed_cash": 10.0,
            "source_swap_removed_cash": 2.0,
            "ftmo_commission_inserted_cash": -21.0,
            "ftmo_swap_inserted_cash": -1.0,
            "calibrated_spread_delta_cash": -4.0,
        }
    )
    assert len(rows) == 2
    assert all(row["schema"] == exporter.EVIDENCE_CLASS for row in rows)
    assert all(row["evidence_class"] == exporter.EVIDENCE_CLASS for row in rows)
    assert all(row["calibration_sha256"] == case["spread_sha"] for row in rows)
    assert rows[0]["cost_decomposition"]["ftmo_entry_commission_cash"] == pytest.approx(-10.0)
    assert rows[0]["calibrated_spread_charge_cash"] == pytest.approx(2.0)
    assert rows[1]["cost_decomposition"]["ftmo_exit_commission_cash"] == pytest.approx(-11.0)
    assert rows[1]["cost_decomposition"]["ftmo_swap_cash"] == pytest.approx(-1.0)
    assert sum(row["cost_decomposition"]["adjusted_net_cash"] for row in rows) == pytest.approx(974.0)


def test_refuses_legacy_q08_rows_before_writing_output(tmp_path: Path) -> None:
    case = _fixture(tmp_path, legacy=True)
    with pytest.raises(exporter.CostAdjustedExportError, match="exact full-lifecycle fields required"):
        _export(case)
    assert not Path(case["out"]).exists()
    assert not Path(case["receipt"]).exists()


def test_refuses_calibration_digest_drift(tmp_path: Path) -> None:
    case = _fixture(tmp_path)
    case["spread_sha"] = "0" * 64
    with pytest.raises(exporter.CostAdjustedExportError, match="calibration SHA-256 mismatch"):
        _export(case)


def test_refuses_cross_symbol_calibration_extrapolation(tmp_path: Path) -> None:
    case = _fixture(tmp_path)
    artifact = json.loads(Path(case["spread"]).read_text())
    artifact["pairs"][0]["dxz_symbol"] = "GDAXI.DWX"
    _json(Path(case["spread"]), artifact)
    case["spread_sha"] = _sha(Path(case["spread"]))
    with pytest.raises(exporter.CostAdjustedExportError, match="extrapolate across symbols"):
        _export(case)
