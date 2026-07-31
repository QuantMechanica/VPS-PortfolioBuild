from __future__ import annotations

import datetime as dt
import json
from dataclasses import replace
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import book3_bound_eval as bound


def _utc(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(dt.UTC)


def _repriced(
    row_id: str,
    entry: str,
    close: str,
    *,
    net: float = 0.0,
    low: float = 0.0,
    margin: float = 0.0,
) -> bound.RepricedTrade:
    return bound.RepricedTrade(
        row_id=row_id,
        sleeve_id="9936",
        symbol="USDJPY.DWX",
        side="BUY",
        entry_utc=_utc(entry),
        close_utc=_utc(close),
        target_net=net,
        lifetime_mae_bound=low,
        target_commission=0.0,
        target_entry_commission=0.0,
        target_swap=0.0,
        source_commission_removed=0.0,
        source_swap_removed=0.0,
        equivalent_target_volume=1.0,
        margin_at_entry=margin,
    )


def _day(
    number: int,
    *,
    pnl: float = 0.0,
    low: float = 0.0,
    opens: int = 1,
    flat_start: bool = True,
    flat_end: bool = True,
) -> bound.DayComponent:
    return bound.DayComponent(
        day=dt.date(2024, 1, 1) + dt.timedelta(days=number),
        realized_pnl=pnl,
        pessimistic_low_from_midnight=low,
        opened_positions=opens,
        flat_at_start=flat_start,
        flat_at_end=flat_end,
        peak_margin=0.0,
    )


def _raw_trade() -> bound.RawTrade:
    return bound.RawTrade(
        row_id="9936:1",
        sleeve_id="9936",
        symbol="USDJPY.DWX",
        side="BUY",
        entry_utc=_utc("2024-01-02T10:00:00Z"),
        close_utc=_utc("2024-01-02T12:00:00Z"),
        entry_price=100.0,
        exit_price=101.0,
        mae_acct=-100.0,
        net=88.0,
        profit=100.0,
        swap=-4.0,
        fee=0.0,
        commission=-8.0,
        entry_commission=-4.0,
        exit_commission=-4.0,
        volume=1.0,
        notional=100_000.0,
    )


def _cost_snapshot() -> dict[str, object]:
    definitions = {
        "USDJPY.DWX": {
            "provider": "USD/JPY",
            "source_contract": 100_000,
            "target_contract": 100_000,
            "model": "flat_round_trip_per_target_lot_usd",
            "flat": 5.0,
            "percent": 0.0,
            "long": 0.92,
            "short": -19.78,
            "digits": 3,
            "conversion": 0.0066666667,
            "mode": "forex",
            "leverage": 30,
        },
        "XAUUSD.DWX": {
            "provider": "XAU/USD",
            "source_contract": 100,
            "target_contract": 100,
            "model": "percent_of_notional_per_side",
            "flat": 0.0,
            "percent": 0.0014,
            "long": -66.21,
            "short": -23.55,
            "digits": 2,
            "conversion": 1.0,
            "mode": "cfd_leverage",
            "leverage": 15,
        },
        "XTIUSD.DWX": {
            "provider": "USOIL.cash",
            "source_contract": 1_000,
            "target_contract": 100,
            "model": "commission_free",
            "flat": 0.0,
            "percent": 0.0,
            "long": 4.22,
            "short": -26.8,
            "digits": 3,
            "conversion": 1.0,
            "mode": "cfd_leverage",
            "leverage": 15,
        },
    }
    providers = []
    normalizations = []
    for symbol, row in definitions.items():
        providers.append(
            {
                "code": row["provider"],
                "swapLong": row["long"],
                "swapShort": row["short"],
                "leverageSwing": row["leverage"],
                "marginCalculation": row["mode"],
                "marginCurrency": "USD",
            }
        )
        normalizations.append(
            {
                "dwx_symbol": symbol,
                "provider_symbol": row["provider"],
                "source_contract_size": row["source_contract"],
                "target_contract_size": row["target_contract"],
                "commission_model": row["model"],
                "flat_round_trip_commission_per_lot": row["flat"],
                "commission_percent_per_side": row["percent"],
                "swap_long_points": row["long"],
                "swap_short_points": row["short"],
                "digits": row["digits"],
                "profit_currency_to_account_rate": row["conversion"],
                "triple_weekday": 2,
            }
        )
    return {
        "schema": "qm.ftmo-book3-symbol-cost-snapshot/v1",
        "selected_provider_rows": providers,
        "book3_normalization": normalizations,
    }


def _write_json(path: Path, value: object) -> dict[str, object]:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    return {"path": str(path.resolve()), "sha256": bound.sha256_file(path)}


def _stream_row(symbol: str, entry: str, close: str) -> dict[str, object]:
    return {
        "event": "TRADE_CLOSED",
        "money_basis": bound.MONEY_BASIS,
        "side": "BUY",
        "entry_price": 100.0,
        "exit_price": 101.0,
        "time": int(_utc(close).timestamp()),
        "entry_time": int(_utc(entry).timestamp()),
        "mae_acct": -500.0,
        "net": 97.0,
        "profit": 100.0,
        "swap": -1.0,
        "fee": 0.0,
        "commission": -2.0,
        "entry_commission": -1.0,
        "exit_commission": -1.0,
        "volume": 1.0,
        "notional": 100_000.0,
        "symbol": symbol,
    }


def _write_jsonl(path: Path, rows: list[dict[str, object]]) -> dict[str, object]:
    path.write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    return {"path": str(path.resolve()), "sha256": bound.sha256_file(path)}


def _prepare_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict[str, object], dict[str, object]]:
    cost_binding = _write_json(tmp_path / "cost.json", _cost_snapshot())
    monkeypatch.setattr(bound, "HISTORICAL_COST_SNAPSHOT_SHA256", cost_binding["sha256"])

    manifest = _write_json(tmp_path / "manifest.json", {"fixture": True})
    contracts: dict[str, dict[str, object]] = {}
    full_bindings = []
    is_bindings = []
    identities = (
        ("9936", "USDJPY.DWX"),
        ("10145", "XAUUSD.DWX"),
        ("13108", "XTIUSD.DWX"),
    )
    for sleeve_id, symbol in identities:
        # Deliberately not valid JSONL: prepare-config must hash but never parse
        # the historical/holdout stream while freezing the IS dependence rule.
        full_path = tmp_path / f"full_{sleeve_id}.jsonl"
        full_path.write_text("HOLDOUT_BYTES_MUST_NOT_BE_PARSED\n", encoding="utf-8")
        full_digest = bound.sha256_file(full_path)
        lineage = []
        lineage_contract: dict[str, str] = {}
        for role in ("summary", "report", "receipt"):
            artifact = _write_json(tmp_path / f"{sleeve_id}_{role}.json", {"role": role})
            artifact["role"] = role
            lineage.append(artifact)
            lineage_contract[role] = str(artifact["sha256"])
        manifest_binding = {**manifest, "role": "evaluation_manifest"}
        lineage.append(manifest_binding)
        lineage_contract["evaluation_manifest"] = str(manifest["sha256"])
        contracts[sleeve_id] = {
            "symbol": symbol,
            "expected_rows": 2,
            "sha256": full_digest,
            "lineage": lineage_contract,
        }
        full_bindings.append(
            {
                "path": str(full_path.resolve()),
                "sha256": full_digest,
                "sleeve_id": sleeve_id,
                "symbol": symbol,
                "expected_rows": 2,
                "lineage": lineage,
            }
        )
        is_binding = _write_jsonl(
            tmp_path / f"is_{sleeve_id}.jsonl",
            [_stream_row(symbol, "2022-09-01T10:00:00Z", "2022-09-02T10:00:00Z")],
        )
        is_binding.update(
            {
                "sleeve_id": sleeve_id,
                "symbol": symbol,
                "expected_rows": 1,
                "parent_stream_sha256": full_digest,
                "derivation": "IS_ONLY_ENTRY_AND_CLOSE_WITHIN_WINDOW",
            }
        )
        is_bindings.append(is_binding)
    monkeypatch.setattr(bound, "HISTORICAL_STREAM_CONTRACT", contracts)
    spec = {
        "windows": {
            "is_start_utc": "2022-08-31T22:00:00Z",
            "is_end_utc": "2022-09-15T21:59:59Z",
            "evaluation_start_utc": "2022-09-15T22:00:00Z",
            "evaluation_end_utc": "2025-12-30T12:00:00Z",
        },
        "inputs": {
            "streams": full_bindings,
            "is_streams": is_bindings,
            "cost_snapshot": cost_binding,
        },
        "bootstrap": {"replicates": 100, "max_lag_days": 5},
        "prepared_at_utc": "2026-07-31T12:00:00Z",
    }
    return spec, contracts


def test_multiday_position_is_represented_each_day_and_can_breach_intraday() -> None:
    trades = [
        _repriced(
            "closed-profit",
            "2024-01-01T09:00:00Z",
            "2024-01-01T10:00:00Z",
            net=3_000.0,
        ),
        _repriced(
            "multiday",
            "2024-01-01T11:00:00Z",
            "2024-01-03T11:00:00Z",
            net=500.0,
            low=-6_000.0,
        ),
    ]
    days = bound.build_daily_components(
        trades, _utc("2023-12-31T23:00:00Z"), _utc("2024-01-03T22:59:59Z")
    )

    assert [row.pessimistic_low_from_midnight for row in days[:3]] == [-3_000.0, -6_000.0, -6_000.0]
    outcome = bound.evaluate_phase(
        days,
        0,
        target_fraction=0.10,
        risk_multiplier=1.0,
        rules=bound.DEFAULT_RULES,
    )
    assert outcome["outcome"] == "daily_loss_breach"
    assert outcome["end_index"] == 1


def test_equal_timestamp_uses_half_open_close_before_open_order() -> None:
    trades = [
        _repriced(
            "old", "2024-01-01T00:00:00Z", "2024-01-02T12:00:00Z", net=100.0, low=-50.0
        ),
        _repriced(
            "new", "2024-01-02T12:00:00Z", "2024-01-02T18:00:00Z", low=-200.0
        ),
    ]
    days = bound.build_daily_components(
        trades, _utc("2024-01-01T23:00:00Z"), _utc("2024-01-02T22:59:59Z")
    )
    assert days[0].pessimistic_low_from_midnight == -100.0


def test_trade_closing_exactly_at_window_start_is_excluded() -> None:
    trade = _repriced(
        "prior", "2024-01-01T10:00:00Z", "2024-01-02T00:00:00Z", net=999.0, low=-999.0
    )
    days = bound.build_daily_components(
        [trade], _utc("2024-01-02T00:00:00Z"), _utc("2024-01-02T23:59:59Z")
    )
    assert days[0].realized_pnl == 0.0
    assert days[0].pessimistic_low_from_midnight == 0.0
    assert days[0].flat_at_start is True


def test_prague_dst_boundaries_use_23_and_25_hour_calendar_days() -> None:
    spring_a = bound._local_midnight_utc(dt.date(2024, 3, 31))
    spring_b = bound._local_midnight_utc(dt.date(2024, 4, 1))
    fall_a = bound._local_midnight_utc(dt.date(2024, 10, 27))
    fall_b = bound._local_midnight_utc(dt.date(2024, 10, 28))
    assert spring_b - spring_a == dt.timedelta(hours=23)
    assert fall_b - fall_a == dt.timedelta(hours=25)
    assert bound.rollover_session_days(
        _utc("2024-03-30T22:30:00Z"), _utc("2024-03-31T22:30:00Z")
    ) == [dt.date(2024, 3, 30), dt.date(2024, 3, 31)]


def test_repricing_removes_source_costs_and_inserts_target_costs() -> None:
    trade = _raw_trade()
    cost = {
        "source_contract_size": 100_000.0,
        "target_contract_size": 100_000.0,
        "commission_model": "flat_round_trip_per_target_lot_usd",
        "flat_round_trip_commission_per_lot": 5.0,
        "commission_percent_per_side": 0.0,
        "swap_long_points": 0.0,
        "swap_short_points": 0.0,
        "digits": 3,
        "profit_currency_to_account_rate": 1.0,
        "triple_weekday": 2,
        "leverage_swing": 30.0,
        "margin_calculation": "forex",
        "margin_currency": "USD",
        "margin_currency_to_account_rate": 1.0,
    }
    repriced = bound.reprice_trade(trade, cost)
    assert repriced.target_net == pytest.approx(95.0)
    assert repriced.lifetime_mae_bound == pytest.approx(-102.5)
    assert repriced.source_commission_removed == -8.0
    assert repriced.source_swap_removed == -4.0


def test_swap_uses_weekday_rollovers_and_skips_weekend_midnights() -> None:
    trade = replace(
        _raw_trade(),
        entry_utc=_utc("2024-01-05T10:00:00Z"),  # Friday
        close_utc=_utc("2024-01-08T10:00:00Z"),  # Monday
    )
    cost = {
        "swap_long_points": 1.0,
        "swap_short_points": -1.0,
        "source_contract_size": 1.0,
        "target_contract_size": 1.0,
        "digits": 0,
        "profit_currency_to_account_rate": 1.0,
        "triple_weekday": 2,
    }
    assert bound._target_swap(trade, cost) == 1.0


def test_is_derivation_requires_exact_full_stream_subset() -> None:
    row = _raw_trade()
    coverage = {"sleeve_id": "9936"}
    verified = bound.verify_is_derivation(
        [([row], coverage)],
        [([row], coverage)],
        _utc("2024-01-01T00:00:00Z"),
        _utc("2024-01-03T00:00:00Z"),
    )
    assert verified == {"9936": 1}
    with pytest.raises(bound.BoundEvaluationError, match="not the exact"):
        bound.verify_is_derivation(
            [([row], coverage)],
            [([replace(row, net=87.0)], coverage)],
            _utc("2024-01-01T00:00:00Z"),
            _utc("2024-01-03T00:00:00Z"),
        )


def test_config_sha_mismatch_refuses_before_evaluation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    config_path = tmp_path / "config.json"
    config_path.write_text("{}\n", encoding="utf-8")
    called = False

    def forbidden(*_args: object, **_kwargs: object) -> dict[str, object]:
        nonlocal called
        called = True
        return {}

    monkeypatch.setattr(bound, "evaluate_bound", forbidden)
    with pytest.raises(bound.BoundEvaluationError, match="config SHA-256 mismatch"):
        bound.evaluate_config_file(config_path, "0" * 64)
    assert called is False


def test_missing_swap_field_refuses_cost_snapshot(tmp_path: Path) -> None:
    snapshot = _cost_snapshot()
    del snapshot["book3_normalization"][2]["swap_short_points"]  # type: ignore[index]
    binding = _write_json(tmp_path / "cost.json", snapshot)
    with pytest.raises(bound.BoundEvaluationError, match="missing cost fields"):
        bound.load_cost_snapshot(binding)


def test_right_censoring_is_counted_as_non_pass() -> None:
    days = [_day(index) for index in range(6)]
    outcome = bound.evaluate_two_phase(
        days, 0, bound.DEFAULT_SCENARIOS[0], bound.DEFAULT_RULES
    )
    assert outcome["outcome"] == "phase1_right_censored"
    assert bound._rate([outcome]) == 0.0
    summary = bound.summarize_scenario(
        days,
        bound.DEFAULT_SCENARIOS[0],
        bound.DEFAULT_RULES,
        {
            "target_days": 1,
            "sensitivity_days": [2],
            "replicates": 100,
            "seed": 7,
            "alpha": 0.05,
            "hac_bandwidth": 1,
            "reference_lower_bound": 0.80,
            "reference_status": bound.DEFAULT_BOOTSTRAP["reference_status"],
        },
    )
    assert summary["raw_overlapping"]["passes"] == 0
    assert summary["raw_overlapping"]["right_censored_counted_as_non_pass"] is True


def test_flat_boundary_blocks_never_cut_open_position() -> None:
    days = [
        _day(0),
        _day(1, flat_end=False),
        _day(2, flat_start=False, flat_end=False),
        _day(3, flat_start=False, flat_end=True),
        _day(4),
    ]
    blocks = bound._flat_boundary_blocks(days, 2)
    assert blocks
    assert all(block[0].flat_at_start and block[-1].flat_at_end for block in blocks)
    assert any(len(block) == 3 for block in blocks)


def test_prepare_config_uses_separate_is_streams_and_preserves_honest_labels(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec, _contracts = _prepare_fixture(tmp_path, monkeypatch)
    config = bound.prepare_config(spec)
    bound.validate_config(config)
    assert config["claim"]["label"] == bound.CLAIM_LABEL
    assert config["claim"]["n_trials"] == "UNKNOWN_LOWER_BOUND_165"
    assert config["claim"]["strict_qualification"] == "UNVERIFIED"
    assert config["claim"]["paid_challenge"] == "NO_GO"
    assert config["bootstrap"]["is_freeze"]["holdout_metrics_read"] is False
    assert len(config["inputs"]["is_streams"]) == 3


def test_prepare_config_refuses_is_row_past_freeze_window(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec, _contracts = _prepare_fixture(tmp_path, monkeypatch)
    binding = spec["inputs"]["is_streams"][0]  # type: ignore[index]
    path = Path(binding["path"])
    replacement = _write_jsonl(
        path,
        [_stream_row("USDJPY.DWX", "2022-09-14T10:00:00Z", "2022-09-16T10:00:00Z")],
    )
    binding["sha256"] = replacement["sha256"]
    with pytest.raises(bound.BoundEvaluationError, match="out-of-window row"):
        bound.prepare_config(spec)


def test_historical_contract_refuses_missing_lineage_role(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec, _contracts = _prepare_fixture(tmp_path, monkeypatch)
    del spec["inputs"]["streams"][0]["lineage"][0]  # type: ignore[index]
    with pytest.raises(bound.BoundEvaluationError, match="missing lineage role"):
        bound.prepare_config(spec)


def test_mutable_database_reference_is_refused(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec, _contracts = _prepare_fixture(tmp_path, monkeypatch)
    spec["inputs"]["advisory"] = {"path": "D:/QM/state/farm_state.sqlite"}  # type: ignore[index]
    with pytest.raises(bound.BoundEvaluationError, match="inputs"):
        bound.prepare_config(spec)


def test_strict_json_refuses_duplicate_keys_and_nonfinite_constants() -> None:
    with pytest.raises(bound.BoundEvaluationError, match="duplicate JSON key"):
        bound.loads_strict(b'{"a":1,"a":2}', "fixture")
    with pytest.raises(bound.BoundEvaluationError, match="non-finite JSON constant"):
        bound.loads_strict(b'{"a":NaN}', "fixture")
