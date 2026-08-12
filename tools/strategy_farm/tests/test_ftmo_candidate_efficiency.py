import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio.ftmo_candidate_efficiency import (
    analyze_rows,
    load_closed_trades,
)


def _ts(day: int, hour: int = 12) -> float:
    return dt.datetime(2025, 1, day, hour, tzinfo=dt.UTC).timestamp()


def test_analyze_rows_sums_concurrent_mae_and_computes_density():
    rows = [
        {"entry_time": _ts(1), "time": _ts(1, 18), "net": 200.0, "mae_acct": -100.0},
        {"entry_time": _ts(1, 13), "time": _ts(2), "net": -50.0, "mae_acct": -250.0},
    ]

    result = analyze_rows(rows, ea_id=42, symbol="TEST.DWX", internal_daily_limit=700.0)

    assert result["trades"] == 2
    assert result["profit_factor"] == 4.0
    assert result["worst_conservative_daily_mae_base"] == 350.0
    assert result["scale_at_internal_daily_limit"] == 2.0
    assert result["method"] == (
        "lifetime_floating_mae_plus_basis_aware_entry_commission_"
        "summed_on_each_spanned_cest_day"
    )


def test_analyze_rows_rejects_empty_input():
    try:
        analyze_rows([], ea_id=42, symbol="TEST.DWX")
    except ValueError as exc:
        assert "no fresh closed trades" in str(exc)
    else:
        raise AssertionError("expected ValueError")


def test_load_closed_trades_rejects_mixed_money_bases(tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    rows = [
        {
            "event": "TRADE_CLOSED",
            "net": 10.0,
            "commission": -1.0,
            "time": _ts(2),
            "entry_time": _ts(1),
            "mae_acct": -2.0,
        },
        {
            "event": "TRADE_CLOSED",
            "money_basis": "FULL_POSITION_LIFECYCLE_ACTUAL_V1",
            "profit": 12.0,
            "swap": 0.0,
            "fee": 0.0,
            "entry_commission": -1.0,
            "exit_commission": -1.0,
            "commission": -2.0,
            "net": 10.0,
            "time": _ts(3),
            "entry_time": _ts(2),
            "mae_acct": -2.0,
        },
    ]
    stream.write_text(
        "".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8"
    )

    with pytest.raises(ValueError, match="mixed q08 money_basis"):
        load_closed_trades(stream)
