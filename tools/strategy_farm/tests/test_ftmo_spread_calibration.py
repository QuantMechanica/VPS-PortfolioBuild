from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_spread_calibration as calibration


def _projection(
    path: Path,
    *,
    symbol: str,
    venue: str,
    spreads: list[int],
    start: dt.datetime | None = None,
) -> None:
    start = start or dt.datetime(2026, 7, 20, 8, 0, tzinfo=dt.UTC)
    rows = [
        {
            "schema": calibration.M1_ROW_SCHEMA,
            "symbol": symbol,
            "venue": venue,
            "time": (start + dt.timedelta(minutes=index)).isoformat().replace("+00:00", "Z"),
            "spread_points": spread,
        }
        for index, spread in enumerate(spreads)
    ]
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")


def _spec(tmp_path: Path, *, mismatch: bool = False) -> dict[str, object]:
    ftmo_m1 = tmp_path / "ftmo.jsonl"
    dxz_m1 = tmp_path / "dxz.jsonl"
    ftmo_hcc = tmp_path / "ftmo_2026.hcc"
    dxz_hcc = tmp_path / "dxz_2026.hcc"
    ftmo_hcc.write_bytes(b"bound FTMO hcc")
    dxz_hcc.write_bytes(b"bound DXZ hcc")
    _projection(ftmo_m1, symbol="XAUUSD", venue="FTMO", spreads=[5] * 120)
    _projection(
        dxz_m1,
        symbol="XAUUSD.DWX",
        venue="DXZ",
        spreads=[2] * (119 if mismatch else 120),
    )
    return {
        "schema": calibration.SPEC_SCHEMA,
        "session_bucket_minutes": 60,
        "conservative_quantile": 0.90,
        "minimum_matched_minutes": 60,
        "minimum_bucket_minutes": 20,
        "pairs": [
            {
                "evaluator_symbol": "XAUUSD",
                "ftmo": {
                    "symbol": "XAUUSD",
                    "venue": "FTMO",
                    "point_size": 0.01,
                    "m1_spread_path": str(ftmo_m1),
                    "source_hcc_paths": [str(ftmo_hcc)],
                    "extraction_method": calibration.EXTRACTION_METHOD,
                },
                "dxz": {
                    "symbol": "XAUUSD.DWX",
                    "venue": "DXZ",
                    "point_size": 0.01,
                    "m1_spread_path": str(dxz_m1),
                    "source_hcc_paths": [str(dxz_hcc)],
                    "extraction_method": calibration.EXTRACTION_METHOD,
                },
            }
        ],
    }


def test_calibrates_exact_matched_minutes_and_upper_tail_charge(tmp_path: Path) -> None:
    artifact = calibration.calibrate_spec(_spec(tmp_path))
    pair = artifact["pairs"][0]

    assert artifact["status"] == "PASS"
    assert artifact["evidence_class"] == "DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1"
    assert artifact["conservative_quantile"] == 0.90
    assert pair["coverage"]["matched_minutes"] == 120
    assert pair["ftmo_spread_price_quantiles"]["p90"] == pytest.approx(0.05)
    assert pair["dxz_spread_price_quantiles"]["p90"] == pytest.approx(0.02)
    assert pair["delta_price_quantiles"]["p90"] == pytest.approx(0.03)
    assert pair["conservative_delta_price_per_side"] == pytest.approx(0.03)
    assert len(pair["session_buckets"]) == 2
    assert all(
        bucket["conservative_delta_price_per_side"] == pytest.approx(0.03)
        for bucket in pair["session_buckets"]
    )
    assert pair["inputs"]["ftmo"]["source_hcc"][0]["sha256"]


def test_refuses_nonidentical_calendar_coverage(tmp_path: Path) -> None:
    with pytest.raises(calibration.SpreadCalibrationError, match="non-identical M1 coverage"):
        calibration.calibrate_spec(_spec(tmp_path, mismatch=True))


def test_refuses_unbound_or_non_hcc_source(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    spec["pairs"][0]["ftmo"]["source_hcc_paths"] = [str(tmp_path / "missing.hcc")]
    with pytest.raises(calibration.SpreadCalibrationError, match="required file is absent"):
        calibration.calibrate_spec(spec)


def test_never_credits_a_negative_ftmo_minus_dxz_delta(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    ftmo_path = Path(spec["pairs"][0]["ftmo"]["m1_spread_path"])
    _projection(ftmo_path, symbol="XAUUSD", venue="FTMO", spreads=[1] * 120)
    artifact = calibration.calibrate_spec(spec)
    assert artifact["pairs"][0]["delta_price_quantiles"]["p90"] == pytest.approx(-0.01)
    assert artifact["pairs"][0]["conservative_delta_price_per_side"] == 0.0
