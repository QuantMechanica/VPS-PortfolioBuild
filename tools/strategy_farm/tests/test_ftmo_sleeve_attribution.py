from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from tools.strategy_farm.ftmo.sleeve_attribution import (
    build_attribution,
    normalize_deal,
    summarize_telemetry,
)


def _utc(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def _deal(
    deal_id: int,
    when: str,
    magic: int,
    entry: str,
    *,
    position_id: int,
    profit: float = 0.0,
    commission: float = 0.0,
    swap: float = 0.0,
    fee: float = 0.0,
    symbol: str = "EURUSD",
) -> dict:
    return normalize_deal(
        {
            "deal_id": deal_id,
            "position_id": position_id,
            "time_utc": when,
            "entry": entry,
            "magic": magic,
            "symbol": symbol,
            "type": "BUY",
            "volume": 1.0 if position_id else 0.0,
            "profit": profit,
            "commission": commission,
            "swap": swap,
            "fee": fee,
        }
    )


def _sample(when: str, balance: float, equity: float, positions: list[dict]) -> dict:
    stamp = _utc(when)
    return {
        "schema": "qm.ftmo-trial-telemetry.raw/v1",
        "event": "SAMPLE",
        "ts_utc": when,
        "ts_epoch": stamp.timestamp(),
        "balance": balance,
        "equity": equity,
        "positions": positions,
    }


def test_reconciliation_two_magics_unattributed_midnight_and_commission_only(tmp_path: Path) -> None:
    magic_a, magic_b = 100010000, 100020000
    roster = {
        "book_id": "SYNTHETIC_BOOK",
        "path": str(tmp_path / "roster.json"),
        "sha256": "a" * 64,
        "sleeves": [
            {
                "ea_id": 10001,
                "ea_label": "QM5_10001_a",
                "symbol": "EURUSD",
                "timeframe": "H1",
                "magic": magic_a,
                "slot": 0,
                "role": "alpha",
                "risk_percent": 0.5,
            },
            {
                "ea_id": 10002,
                "ea_label": "QM5_10002_b",
                "symbol": "USDJPY",
                "timeframe": "H1",
                "magic": magic_b,
                "slot": 0,
                "role": "beta",
                "risk_percent": 0.5,
            },
        ],
    }
    deals = [
        _deal(1, "2026-06-10T21:55:00Z", magic_a, "IN", position_id=11, commission=-1.0),
        _deal(2, "2026-06-10T21:56:00Z", 999, "OUT", position_id=99, profit=3.0),
        # Broker commission-only deal: zero P&L/volume/position but non-zero cash cost.
        _deal(3, "2026-06-10T22:05:00Z", magic_b, "IN", position_id=0, commission=-0.5),
        _deal(
            4,
            "2026-06-10T22:30:00Z",
            magic_a,
            "OUT",
            position_id=11,
            profit=10.0,
            commission=-1.0,
            swap=-1.0,
        ),
    ]
    telemetry_path = tmp_path / "raw.jsonl"
    samples = [
        _sample(
            "2026-06-10T21:59:50Z",
            100002.0,
            100000.0,
            [{"magic": magic_a, "profit": -2.0, "swap": 0.0}],
        ),
        _sample(
            "2026-06-10T22:00:05Z",
            100002.0,
            99999.5,
            [{"magic": magic_a, "profit": -2.5, "swap": 0.0}],
        ),
        _sample(
            "2026-06-10T22:20:00Z",
            100001.5,
            99997.5,
            [{"magic": magic_a, "profit": -4.0, "swap": 0.0}],
        ),
        _sample("2026-06-10T22:40:00Z", 100009.5, 100009.5, []),
    ]
    telemetry_path.write_text("".join(json.dumps(row) + "\n" for row in samples), encoding="utf-8")
    start, end = _utc("2026-06-10T21:50:00Z"), _utc("2026-06-11T01:00:00Z")
    telemetry, telemetry_source = summarize_telemetry(
        telemetry_path, {magic_a, magic_b}, start, end, midnight_tolerance_seconds=30
    )
    result = build_attribution(
        roster=roster,
        deals=deals,
        deal_source={"mode": "SYNTHETIC"},
        telemetry_days=telemetry,
        telemetry_source=telemetry_source,
        start=start,
        end=end,
        generated_at=end,
    )

    assert result["reconciliation_ok"] is True
    assert result["reconciliation"] == {
        "account_realised_usd": 9.5,
        "roster_realised_usd": 6.5,
        "unattributed_realised_usd": 3.0,
        "difference_usd": 0.0,
        "identity": "roster_realised + unattributed_realised == account_history_realised",
        "cent_rounding": "ROUND_HALF_UP_PER_DEAL_COMPONENT",
    }
    assert len(result["unattributed"]) == 1
    assert result["unattributed"][0]["magic"] == 999

    by_day = {row["prague_day"]: row for row in result["days"]}
    june_11 = by_day["2026-06-11"]
    by_magic = {row["magic"]: row for row in june_11["sleeves"]}
    assert by_magic[magic_a]["floating_at_prague_midnight_usd"] == -2.5
    assert by_magic[magic_a]["worst_intraday_mae_proxy_usd"] == -4.0
    assert by_magic[magic_a]["trade_count"] == 1
    assert by_magic[magic_b]["realised_usd"] == -0.5
    assert by_magic[magic_b]["entries"] == 1
    assert june_11["account"]["reconciliation_ok"] is True


def test_every_zero_magic_balance_or_manual_deal_is_itemized(tmp_path: Path) -> None:
    magic = 100010000
    roster = {
        "book_id": "B",
        "path": "roster.json",
        "sha256": "b" * 64,
        "sleeves": [
            {
                "ea_id": 10001,
                "ea_label": "QM5_10001_a",
                "symbol": "EURUSD",
                "timeframe": "H1",
                "magic": magic,
                "slot": 0,
                "role": "alpha",
                "risk_percent": 1.0,
            }
        ],
    }
    deals = [
        _deal(1, "2026-06-10T12:00:00Z", 0, "IN", position_id=0, profit=5.0, symbol=""),
        _deal(2, "2026-06-10T12:01:00Z", magic, "IN", position_id=1, commission=-0.25),
    ]
    result = build_attribution(
        roster=roster,
        deals=deals,
        deal_source={"mode": "SYNTHETIC"},
        telemetry_days={},
        telemetry_source={},
        start=_utc("2026-06-10T00:00:00Z"),
        end=_utc("2026-06-11T00:00:00Z"),
        generated_at=_utc("2026-06-11T00:00:00Z"),
    )
    assert result["reconciliation_ok"] is True
    assert result["unattributed"][0]["reason"] == "ZERO_OR_MANUAL_MAGIC"
    assert result["unattributed"][0]["operation_kind"] == "BALANCE_OPERATION"
    assert result["reconciliation"]["difference_usd"] == 0.0
