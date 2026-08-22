from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import concentration_tail as ct


def _policy(tmp_path: Path, *, ratified: bool = True) -> Path:
    value = json.loads(ct.DEFAULT_POLICY_PATH.read_text(encoding="utf-8"))
    value["status"] = "OWNER_RATIFIED" if ratified else "PROPOSED_OWNER_RATIFICATION_REQUIRED"
    path = tmp_path / "policy.json"
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def _evaluate(
    tmp_path: Path,
    keys,
    weights,
    matrix,
    *,
    assets=None,
    families=None,
    sessions=None,
    ratified=True,
):
    dates = [dt.date(2026, 1, 1) + dt.timedelta(days=index) for index in range(len(matrix))]
    return ct.evaluate(
        keys=keys,
        weights=weights,
        dates=dates,
        matrix=matrix,
        streams={},
        starting_capital=100_000.0,
        policy_path=_policy(tmp_path, ratified=ratified),
        asset_by_key=assets or {key: "fx" for key in keys},
        family_by_key=families or {key: f"family-{index}" for index, key in enumerate(keys)},
        session_by_key=sessions or {
            key: ("ASIA", "EU", "US")[index % 3] for index, key in enumerate(keys)
        },
    )


def test_three_sleeves_same_symbol_trigger_d1_reject(tmp_path: Path) -> None:
    keys = [(1, "EURUSD.DWX"), (2, "EURUSD.DWX"), (3, "EURUSD.DWX")]
    matrix = [[10.0, 5.0, 2.0] for _ in range(20)]
    report = _evaluate(tmp_path, keys, {key: 0.4 for key in keys}, matrix)

    symbol = report["dimensions"]["symbol"]["rows"][0]
    assert symbol["stop_risk_pct"] == pytest.approx(1.2)
    assert symbol["cap_stop_risk_pct"] == pytest.approx(1.0)
    assert symbol["status"] == "BREACH"
    assert any(row["dim"] == "symbol" for row in report["concentration_reject"])
    assert report["builder_eligible"] is False


def test_four_family_clones_trigger_d3_reject(tmp_path: Path) -> None:
    keys = [(1, "EURUSD.DWX"), (2, "GBPUSD.DWX"), (3, "USDJPY.DWX"), (4, "AUDUSD.DWX")]
    matrix = [[1.0, 2.0, 3.0, 4.0] for _ in range(20)]
    report = _evaluate(
        tmp_path,
        keys,
        {key: 0.35 for key in keys},
        matrix,
        families={key: "clone" for key in keys},
    )

    family = report["dimensions"]["family"]["rows"][0]
    assert family["stop_risk_pct"] == pytest.approx(1.4)
    assert family["cap_stop_risk_pct"] == pytest.approx(1.25)
    assert family["status"] == "BREACH"


def test_joint_tail_counts_three_constructed_days_exactly(tmp_path: Path) -> None:
    keys = [(index + 1, f"S{index}.DWX") for index in range(6)]
    matrix = [[10.0 for _ in keys] for _ in range(20)]
    # tail_n=1 per sleeve; three disjoint pairs share their single worst day.
    matrix[0][0] = matrix[0][1] = -100.0
    matrix[1][2] = matrix[1][3] = -200.0
    matrix[2][4] = matrix[2][5] = -300.0
    report = _evaluate(
        tmp_path,
        keys,
        {key: 0.15 for key in keys},
        matrix,
        assets={key: ("fx", "indices", "metals")[index % 3] for index, key in enumerate(keys)},
    )

    assert report["tail"]["joint_k"] == 2
    assert report["tail"]["joint_tail_day_count"] == 3
    assert [row["tail_sleeve_count"] for row in report["tail"]["joint_tail_days"]] == [2, 2, 2]
    assert report["tail"]["worst_joint_day_loss_pct"] == pytest.approx(0.084)


def test_missing_oos_series_is_unknown_and_fail_closed(tmp_path: Path) -> None:
    report = ct.unknown_report("sealed OOS series missing", policy_path=_policy(tmp_path))

    assert report["status"] == "UNKNOWN"
    assert report["builder_eligible"] is False
    assert report["concentration_reject"][0]["dim"] == "data"


def test_clean_four_sleeve_book_passes_with_complete_panel(tmp_path: Path) -> None:
    keys = [(1, "EURUSD.DWX"), (2, "NDX.DWX"), (3, "XAUUSD.DWX"), (4, "XTIUSD.DWX")]
    matrix = [
        [10.0 + index, 8.0 - index, 4.0 + index * 0.5, 3.0 - index * 0.25]
        for index in range(20)
    ]
    report = _evaluate(
        tmp_path,
        keys,
        {key: 0.3 for key in keys},
        matrix,
        assets={keys[0]: "fx", keys[1]: "indices", keys[2]: "metals", keys[3]: "energy"},
        sessions={keys[0]: "ASIA", keys[1]: "EU", keys[2]: "US", keys[3]: "US"},
    )

    assert report["status"] == "PASS"
    assert report["builder_eligible"] is True
    assert report["concentration_reject"] == []
    assert set(report["dimensions"]) == {"symbol", "asset_class", "family", "session"}
    assert report["risk_proxies"]["historical_daily_var_95_loss_pct"] is not None
    assert "SP-C3 concentration" in ct.markdown_panel(report)


def test_metals_energy_and_xau_shares_are_explicit(tmp_path: Path) -> None:
    keys = [(1, "XAUUSD.DWX"), (2, "XTIUSD.DWX"), (3, "EURUSD.DWX"), (4, "NDX.DWX")]
    weights = {keys[0]: 0.217, keys[1]: 0.193, keys[2]: 0.30, keys[3]: 0.29}
    report = _evaluate(
        tmp_path,
        keys,
        weights,
        [[5.0, 4.0, 3.0, 2.0] for _ in range(20)],
        assets={keys[0]: "metals", keys[1]: "energy", keys[2]: "fx", keys[3]: "indices"},
    )

    assert report["highlights"]["metals_energy_pct_of_total_book_risk"] == pytest.approx(41.0)
    assert report["highlights"]["xauusd_pct_of_total_book_risk"] == pytest.approx(21.7)


def test_proposed_policy_never_mints_builder_eligibility(tmp_path: Path) -> None:
    keys = [(1, "EURUSD.DWX"), (2, "NDX.DWX"), (3, "XAUUSD.DWX"), (4, "XTIUSD.DWX")]
    report = _evaluate(
        tmp_path,
        keys,
        {key: 0.2 for key in keys},
        [[1.0, 2.0, 3.0, 4.0] for _ in range(20)],
        assets={keys[0]: "fx", keys[1]: "indices", keys[2]: "metals", keys[3]: "energy"},
        ratified=False,
    )

    assert report["passed"] is True
    assert report["status"] == "POLICY_UNRATIFIED"
    assert report["builder_eligible"] is False
