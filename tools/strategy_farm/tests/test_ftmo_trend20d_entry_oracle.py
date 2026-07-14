from __future__ import annotations

import pandas as pd
import pytest

from tools.strategy_farm.portfolio import ftmo_trend20d_entry_oracle as oracle
from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip


def _trade(entry: pd.Timestamp, *, side: str = "buy") -> RoundTrip:
    return RoundTrip(
        entry_time=entry.to_pydatetime(),
        exit_time=(entry + pd.Timedelta(minutes=15)).to_pydatetime(),
        symbol="TEST",
        side=side,
        volume=1.0,
        entry_price=100.0,
        exit_price=101.0,
        profit=1.0,
        native_swap=0.0,
        native_commission=0.0,
    )


def _bars(closes: list[float]) -> pd.DataFrame:
    index = pd.date_range(
        "2023-01-01T00:00:00Z",
        periods=len(closes),
        freq="15min",
        tz="UTC",
    )
    return pd.DataFrame(
        {
            "open": closes,
            "high": [value + 1.0 for value in closes],
            "low": [value - 1.0 for value in closes],
            "close": closes,
        },
        index=index,
    )


def test_oracle_uses_exact_observed_shift1_and_shift1921() -> None:
    closes = [100.0] * 1922
    closes[1920] = 120.0
    closes[1921] = 9999.0
    bars = _bars(closes)
    entry = bars.index[1921] + pd.Timedelta(seconds=7)

    row = oracle.trade_oracle_row(
        _trade(entry),
        bars,
        trade_number=1,
        timestamp_basis="unix_utc",
    )

    assert row["shift1"]["observed_bar_open_utc"] == bars.index[1920].isoformat()
    assert row["shift1"]["close"] == 120.0
    assert row["shift1921"]["observed_bar_open_utc"] == bars.index[0].isoformat()
    assert row["shift1921"]["close"] == 100.0
    assert row["signed_return_20d"] == pytest.approx(0.2)
    assert row["decision"] == "accepted"


def test_strict_zero_return_is_rejected() -> None:
    bars = _bars([100.0] * 1922)

    row = oracle.trade_oracle_row(
        _trade(bars.index[1921]),
        bars,
        trade_number=1,
        timestamp_basis="unix_utc",
    )

    assert row["feature_available"] is True
    assert row["signed_return_20d"] == 0.0
    assert row["accepted"] is False
    assert row["decision"] == "rejected"
    assert row["reason"] == "strict_nonpositive"


def test_insufficient_history_retains_control_trade_as_unavailable() -> None:
    bars = _bars([100.0] * 101)

    row = oracle.trade_oracle_row(
        _trade(bars.index[100]),
        bars,
        trade_number=1,
        timestamp_basis="unix_utc",
    )

    assert row["control_trade_number"] == 1
    assert row["feature_available"] is False
    assert row["accepted"] is False
    assert row["decision"] == "unavailable"
    assert row["reason"] == "insufficient_observed_history"
    assert row["shift1"] is not None
    assert row["shift1921"] is None


def test_annual_counts_separate_accepted_rejected_and_unavailable() -> None:
    rows = [
        {"entry_year_prague": 2020, "decision": "accepted"},
        {"entry_year_prague": 2020, "decision": "rejected"},
        {"entry_year_prague": 2020, "decision": "unavailable"},
        {"entry_year_prague": 2021, "decision": "accepted"},
    ]

    assert oracle.count_decisions(rows) == {
        "control": 4,
        "accepted": 2,
        "rejected": 1,
        "unavailable": 1,
    }
    assert oracle.annual_decision_counts(rows) == {
        "2020": {"control": 3, "accepted": 1, "rejected": 1, "unavailable": 1},
        "2021": {"control": 1, "accepted": 1, "rejected": 0, "unavailable": 0},
    }


def test_sidecar_hashes_exact_rendered_payload(tmp_path) -> None:
    out = tmp_path / "oracle.json"
    sidecar = tmp_path / "oracle.sha256"

    digest = oracle.write_artifact(
        {"schema_version": 1, "value": "frozen"},
        out_path=out,
        sha256_path=sidecar,
    )

    assert digest == oracle._sha256_bytes(out.read_bytes())
    assert sidecar.read_text(encoding="ascii") == f"{digest}  oracle.json\n"
