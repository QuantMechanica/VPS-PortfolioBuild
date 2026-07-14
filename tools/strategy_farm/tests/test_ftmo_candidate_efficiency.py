import datetime as dt

from tools.strategy_farm.portfolio.ftmo_candidate_efficiency import analyze_rows


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


def test_analyze_rows_rejects_empty_input():
    try:
        analyze_rows([], ea_id=42, symbol="TEST.DWX")
    except ValueError as exc:
        assert "no fresh closed trades" in str(exc)
    else:
        raise AssertionError("expected ValueError")
