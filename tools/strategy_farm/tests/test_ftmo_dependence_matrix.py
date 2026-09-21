from __future__ import annotations

import datetime as dt

from tools.strategy_farm.ftmo import dependence_matrix as dm


def _ts(day: int, hour: int) -> int:
    return int(dt.datetime(2024, 1, day, hour, tzinfo=dt.timezone.utc).timestamp())


def _trade(day: int, start: int, end: int, net: float, mae: float, side: str = "BUY") -> dict:
    return {
        "entry_time": _ts(day, start), "close_time": _ts(day, end),
        "net_scaled": net, "mae_scaled": mae, "side": side,
    }


def test_known_three_sleeve_overlap_matrix() -> None:
    sleeves = [
        {"id": "A", "ea_id": 1, "symbol": "XAUUSD.DWX", "timeframe": "H1",
         "family": "breakout", "session": "NY", "news_profile": "PRE30_POST30",
         "trades": [_trade(2, 10, 14, -100, -150), _trade(3, 10, 14, -80, -120),
                    _trade(4, 10, 14, 50, -20)]},
        {"id": "B", "ea_id": 2, "symbol": "XAUUSD.DWX", "timeframe": "H1",
         "family": "breakout", "session": "NY", "news_profile": "PRE30_POST30",
         "trades": [_trade(2, 11, 13, -50, -90), _trade(3, 11, 13, -40, -70),
                    _trade(4, 11, 13, 30, -10)]},
        {"id": "C", "ea_id": 3, "symbol": "EURUSD.DWX", "timeframe": "H1",
         "family": "mean_reversion", "session": "ASIA", "news_profile": "PRE30_POST30",
         "trades": [_trade(2, 1, 2, 10, -5), _trade(3, 1, 2, 15, -5),
                    _trade(4, 1, 2, -10, -15, "SELL")]},
    ]

    matrix = dm.compute_dependence_matrix(sleeves, generated_at_utc="2026-09-21T12:00:00Z")
    rows = {row["pair"]: row for row in matrix["pairs"]}
    ab = rows["A/B"]
    ac = rows["A/C"]

    assert ab["common_symbol"] is True
    assert ab["common_family"] is True
    assert ab["position_overlap_hours"] == 6.0
    assert ab["position_overlap_share_of_smaller_exposure"] == 1.0
    assert ab["same_direction_share_when_overlapping"] == 1.0
    assert ab["same_symbol_entry_within_30m_share"] == 0.0
    assert ac["position_overlap_hours"] == 0.0
    assert ac["same_direction_share_when_overlapping"] is None
    assert ["A", "B"] in matrix["summary"]["fail_together_clusters"]


def test_matrix_and_markdown_are_deterministic() -> None:
    sleeves = [
        {"id": "A", "ea_id": 1, "symbol": "EURUSD.DWX", "trades": [_trade(2, 10, 11, -1, -2)]},
        {"id": "B", "ea_id": 2, "symbol": "USDJPY.DWX", "trades": [_trade(2, 12, 13, 1, -1)]},
    ]
    first = dm.compute_dependence_matrix(sleeves, generated_at_utc="fixed")
    second = dm.compute_dependence_matrix(sleeves, generated_at_utc="fixed")

    assert first == second
    assert dm.render_markdown(first) == dm.render_markdown(second)
    assert "FTMO_BOOK_DEPENDENCE_MATRIX" in dm.render_markdown(first)
