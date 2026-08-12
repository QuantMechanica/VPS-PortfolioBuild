from __future__ import annotations

import csv
import importlib.util
import json
import math
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = ROOT / "tools" / "strategy_farm" / "portfolio" / "dxz_live_blend_reweight.py"
SPEC = importlib.util.spec_from_file_location("dxz_live_blend_reweight", MODULE_PATH)
assert SPEC and SPEC.loader
blend = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = blend
SPEC.loader.exec_module(blend)


def _sleeve(ea_id: int = 100, symbol: str = "EURUSD.DWX", magic: int = 1000000, risk: float = 0.5):
    return blend.Sleeve(ea_id, symbol, magic, risk)


def _deal(
    deal_id: int,
    position_id: int,
    entry: str,
    magic: int,
    *,
    day: int = 1,
    profit: float = 0.0,
    swap: float = 0.0,
    commission: float = 0.0,
    fee: float = 0.0,
    volume: float = 1.0,
    symbol: str = "EURUSD",
):
    return blend.Deal(
        deal_id=deal_id,
        position_id=position_id,
        time_utc=datetime(2026, 7, day, 12, tzinfo=timezone.utc),
        deal_type="BUY",
        entry=entry,
        magic=magic,
        symbol=symbol,
        volume=volume,
        profit=profit,
        swap=swap,
        commission=commission,
        fee=fee,
    )


def _business_dates(count: int, start: date = date(2018, 1, 1)) -> list[date]:
    rows = []
    current = start
    while len(rows) < count:
        if current.weekday() < 5:
            rows.append(current)
        current += timedelta(days=1)
    return rows


def test_variance_blend_alpha_endpoints_and_partial() -> None:
    assert blend.blend_volatility(4.0, 10.0, 0.0) == 4.0
    assert blend.blend_volatility(4.0, 10.0, 1.0) == 10.0
    assert blend.blend_volatility(4.0, 10.0, 0.5) == pytest.approx(math.sqrt(58.0))


def test_capped_inverse_vol_preserves_total_and_cap_exactly() -> None:
    weights = blend.capped_inverse_vol(
        {magic: float(magic) for magic in range(1, 25)},
        total_risk=9.75,
        cap=1.0,
    )

    assert round(sum(weights.values()), 6) == 9.750000
    assert max(weights.values()) <= 1.0
    assert len(weights) == 24


def test_capped_inverse_vol_rejects_infeasible_total() -> None:
    with pytest.raises(blend.InputError, match="infeasible"):
        blend.capped_inverse_vol({1: 1.0, 2: 2.0}, total_risk=2.1, cap=1.0)


def test_attribute_deals_uses_opening_magic_and_entry_risk_for_broker_close() -> None:
    logical_magic = 127780000
    alias_magic = 127780001
    regimes = {
        logical_magic: [
            blend.RiskRegime(logical_magic, date(2026, 7, 1), date(2026, 7, 1), 0.5),
            blend.RiskRegime(logical_magic, date(2026, 7, 2), None, 0.8),
        ]
    }
    deals = [
        _deal(1, 99, "IN", alias_magic, day=1, commission=-2.0, symbol="EURJPY"),
        _deal(
            2, 99, "OUT", 0, day=2, profit=13.0, swap=-1.0,
            commission=-2.0, symbol="EURJPY",
        ),
    ]

    rows, normalised_daily, actual_daily, counts = blend.attribute_deals(
        deals,
        {
            alias_magic: blend.MagicRoute(logical_magic, "EURJPY.DWX"),
            logical_magic: blend.MagicRoute(logical_magic, "AUDUSD.DWX"),
        },
        regimes,
        date(2026, 7, 1),
        date(2026, 7, 2),
    )

    assert [row["logical_magic"] for row in rows] == [logical_magic, logical_magic]
    assert rows[0]["net_actual"] == -2.0
    assert rows[0]["net_per_1pct_risk"] == -4.0
    # Close-day regime is 0.8, but the lifecycle remains normalized by 0.5 at entry.
    assert rows[1]["net_actual"] == 10.0
    assert rows[1]["risk_percent_in_force"] == 0.5
    assert rows[1]["net_per_1pct_risk"] == 20.0
    # Live daily PnL is realised once on the final close: entry and exit costs
    # reconcile into one lifecycle value on the Q08-compatible close-day basis.
    assert rows[1]["lifecycle_net_actual_if_closed"] == 8.0
    assert normalised_daily[logical_magic][date(2026, 7, 2)] == 16.0
    assert actual_daily[logical_magic][date(2026, 7, 2)] == 8.0
    assert counts == {logical_magic: 1}


def test_two_opening_deals_do_not_qualify_as_completed_positions() -> None:
    logical_magic = 1000000
    regimes = {
        logical_magic: [blend.RiskRegime(logical_magic, date(2026, 7, 1), None, 0.5)]
    }
    deals = [
        _deal(1, 10, "IN", logical_magic, commission=-1.0),
        _deal(2, 11, "IN", logical_magic, commission=-1.0),
    ]

    _rows, _daily, _actual, counts = blend.attribute_deals(
        deals,
        {logical_magic: blend.MagicRoute(logical_magic, "EURUSD.DWX")},
        regimes,
        date(2026, 7, 1),
        date(2026, 7, 2),
    )

    assert counts == {}


def test_partial_close_counts_completed_position_only_when_flat() -> None:
    logical_magic = 1000000
    routes = {logical_magic: blend.MagicRoute(logical_magic, "EURUSD.DWX")}
    regimes = {
        logical_magic: [blend.RiskRegime(logical_magic, date(2026, 7, 1), None, 0.5)]
    }
    partial = [
        _deal(1, 10, "IN", logical_magic, volume=1.0, commission=-1.0),
        _deal(2, 10, "OUT", logical_magic, volume=0.4, profit=4.0),
    ]

    rows, daily, _actual, counts = blend.attribute_deals(
        partial, routes, regimes, date(2026, 7, 1), date(2026, 7, 2)
    )
    assert len(rows) == 2
    assert counts == {}
    assert daily == {}

    rows, daily, actual, counts = blend.attribute_deals(
        [*partial, _deal(3, 10, "OUT", 0, volume=0.6, profit=7.0)],
        routes,
        regimes,
        date(2026, 7, 1),
        date(2026, 7, 2),
    )
    assert len(rows) == 3
    assert counts == {logical_magic: 1}
    assert actual[logical_magic][date(2026, 7, 1)] == 10.0
    assert daily[logical_magic][date(2026, 7, 1)] == 20.0


def test_attribute_deals_rejects_unknown_nonzero_close_and_wrong_symbol() -> None:
    logical_magic = 1000000
    routes = {logical_magic: blend.MagicRoute(logical_magic, "EURUSD.DWX")}
    regimes = {
        logical_magic: [blend.RiskRegime(logical_magic, date(2026, 7, 1), None, 0.5)]
    }
    with pytest.raises(blend.InputError, match="unknown closing magic"):
        blend.attribute_deals(
            [
                _deal(1, 10, "IN", logical_magic),
                _deal(2, 10, "OUT", 999999999),
            ],
            routes,
            regimes,
            date(2026, 7, 1),
            date(2026, 7, 2),
        )
    with pytest.raises(blend.InputError, match="closing symbol"):
        blend.attribute_deals(
            [
                _deal(1, 10, "IN", logical_magic),
                _deal(2, 10, "OUT", 0, symbol="GBPUSD"),
            ],
            routes,
            regimes,
            date(2026, 7, 1),
            date(2026, 7, 2),
        )


def test_attribute_deals_rejects_wrong_alias_symbol_and_overclose() -> None:
    logical_magic = 127780000
    alias_magic = 127780001
    routes = {alias_magic: blend.MagicRoute(logical_magic, "EURJPY.DWX")}
    regimes = {
        logical_magic: [blend.RiskRegime(logical_magic, date(2026, 7, 1), None, 0.5)]
    }
    with pytest.raises(blend.InputError, match="does not match"):
        blend.attribute_deals(
            [_deal(1, 10, "IN", alias_magic, symbol="AUDUSD")],
            routes,
            regimes,
            date(2026, 7, 1),
            date(2026, 7, 2),
        )
    with pytest.raises(blend.InputError, match="exceeds open volume"):
        blend.attribute_deals(
            [
                _deal(1, 10, "IN", alias_magic, symbol="EURJPY", volume=0.5),
                _deal(2, 10, "OUT", 0, symbol="EURJPY", volume=0.6),
            ],
            routes,
            regimes,
            date(2026, 7, 1),
            date(2026, 7, 2),
        )


def test_attribute_deals_fails_closed_when_close_has_no_opening_deal() -> None:
    logical_magic = 1000000
    regimes = {logical_magic: [blend.RiskRegime(logical_magic, date(2026, 7, 1), None, 0.5)]}
    with pytest.raises(blend.InputError, match="no opening deal"):
        blend.attribute_deals(
            [_deal(1, 99, "OUT", logical_magic, profit=10)],
            {logical_magic: blend.MagicRoute(logical_magic, "EURUSD.DWX")},
            regimes,
            date(2026, 7, 1),
            date(2026, 7, 2),
        )


def test_load_deals_rejects_duplicate_and_refuses_unallocated_cashflow(tmp_path: Path) -> None:
    path = tmp_path / "deals.json"
    path.write_text(
        json.dumps(
            [
                {
                    "ticket": 1, "time": 1782921600, "type": 2,
                    "profit": 0, "swap": 0, "commission": 0, "fee": 0,
                },
                {
                    "ticket": 2,
                    "position_id": 3,
                    "time": 1782921600,
                    "type": 0,
                    "entry": 0,
                    "magic": 1000000,
                    "symbol": "EURUSD",
                    "volume": 1,
                    "profit": 0,
                    "swap": 0,
                    "commission": -1,
                    "fee": 0,
                },
            ]
        ),
        encoding="utf-8",
    )
    deals = blend.load_deals(path)
    assert [row.deal_id for row in deals] == [2]

    unallocated = [
        {
            "ticket": 9, "time": 1782921600, "type": 2,
            "profit": 1000, "swap": 0, "commission": 0, "fee": 0,
        }
    ]
    path.write_text(json.dumps(unallocated), encoding="utf-8")
    with pytest.raises(blend.InputError, match="UNALLOCATED_FINANCIAL_CASHFLOW"):
        blend.load_deals(path)

    path.write_text(
        json.dumps(
            [
                {
                    "ticket": 1, "time": 1782921600, "type": 2,
                    "profit": 0, "swap": 0, "commission": 0, "fee": 0,
                },
                {
                    "ticket": 1, "time": 1782921601, "type": 2,
                    "profit": 0, "swap": 0, "commission": 0, "fee": 0,
                },
            ]
        ),
        encoding="utf-8",
    )
    with pytest.raises(blend.InputError, match="duplicate"):
        blend.load_deals(path)


def test_deal_export_metadata_binds_account_cutoff_and_sha(tmp_path: Path) -> None:
    deal_path = tmp_path / "deals.json"
    deal_path.write_text("[]\n", encoding="utf-8")
    metadata_path = tmp_path / "metadata.json"
    payload = {
        "schema_version": 1,
        "account_login": "4000090541",
        "server": "Darwinex-Live",
        "source_kind": "MT5_ACCOUNT_HISTORY_EXPORT",
        "complete": True,
        "read_only_export": True,
        "scope": "ALL_ACCOUNT_DEALS_UNFILTERED",
        "history_from_utc": "2026-07-20T00:00:00Z",
        "history_to_utc_exclusive": "2026-08-18T00:00:00Z",
        "exported_at_utc": "2026-08-18T00:05:00Z",
        "deal_history_basename": "deals.json",
        "deal_history_sha256": blend.sha256_file(deal_path),
        "source_row_count": 0,
    }
    metadata_path.write_text(json.dumps(payload), encoding="utf-8")

    result = blend.verify_deal_export_metadata(
        metadata_path,
        deal_path,
        date(2026, 7, 20),
        date(2026, 8, 17),
        datetime(2026, 8, 18, 1, tzinfo=timezone.utc),
    )
    assert result["account_login"] == "4000090541"

    payload["account_login"] = "wrong"
    metadata_path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(blend.InputError, match="T_Live account"):
        blend.verify_deal_export_metadata(
            metadata_path,
            deal_path,
            date(2026, 7, 20),
            date(2026, 8, 17),
            datetime(2026, 8, 18, 1, tzinfo=timezone.utc),
        )

    payload["account_login"] = "4000090541"
    payload["history_to_utc_exclusive"] = "2026-08-17T00:00:00Z"
    metadata_path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(blend.InputError, match="end exactly"):
        blend.verify_deal_export_metadata(
            metadata_path,
            deal_path,
            date(2026, 7, 20),
            date(2026, 8, 17),
            datetime(2026, 8, 18, 1, tzinfo=timezone.utc),
        )

    payload["history_to_utc_exclusive"] = "2026-08-18T00:00:00Z"
    payload["history_from_utc"] = "2026-07-19T00:00:00Z"
    metadata_path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(blend.InputError, match="start exactly"):
        blend.verify_deal_export_metadata(
            metadata_path,
            deal_path,
            date(2026, 7, 20),
            date(2026, 8, 17),
            datetime(2026, 8, 18, 1, tzinfo=timezone.utc),
        )


def test_deal_export_metadata_checks_raw_row_count(tmp_path: Path) -> None:
    deal_path = tmp_path / "deals.json"
    deal_path.write_text("[]\n", encoding="utf-8")
    metadata_path = tmp_path / "metadata.json"
    payload = {
        "schema_version": 1,
        "account_login": "4000090541",
        "server": "Darwinex-Live",
        "source_kind": "MT5_ACCOUNT_HISTORY_EXPORT",
        "scope": "ALL_ACCOUNT_DEALS_UNFILTERED",
        "complete": True,
        "read_only_export": True,
        "history_from_utc": "2026-07-20T00:00:00Z",
        "history_to_utc_exclusive": "2026-07-22T00:00:00Z",
        "exported_at_utc": "2026-07-22T00:01:00Z",
        "deal_history_basename": deal_path.name,
        "deal_history_sha256": blend.sha256_file(deal_path),
        "source_row_count": 1,
    }
    metadata_path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(blend.InputError, match="source_row_count mismatch"):
        blend.verify_deal_export_metadata(
            metadata_path,
            deal_path,
            date(2026, 7, 20),
            date(2026, 7, 21),
            datetime(2026, 7, 22, 1, tzinfo=timezone.utc),
        )


def test_v1_risk_schedule_is_anchored_to_manifest_and_total(tmp_path: Path) -> None:
    sleeves = [
        _sleeve(
            ea_id=1000 + index,
            symbol=f"S{index}.DWX",
            magic=10_000_000 + index,
            risk=0.55 if index == 0 else 0.4,
        )
        for index in range(24)
    ]
    path = tmp_path / "risk.csv"

    def write(first_risk: float) -> None:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=("magic", "effective_from", "effective_to", "risk_percent"),
            )
            writer.writeheader()
            for index, sleeve in enumerate(sleeves):
                writer.writerow(
                    {
                        "magic": sleeve.magic,
                        "effective_from": "2026-07-20",
                        "effective_to": "",
                        "risk_percent": first_risk if index == 0 else sleeve.current_risk_percent,
                    }
                )

    write(0.55)
    regimes = blend.load_risk_schedule(
        path, sleeves, date(2026, 7, 20), date(2026, 8, 20)
    )
    assert len(regimes) == 24

    write(0.56)
    with pytest.raises(blend.InputError, match="pinned manifest"):
        blend.load_risk_schedule(
            path, sleeves, date(2026, 7, 20), date(2026, 8, 20)
        )


def test_magic_registry_maps_only_explicit_composite_alias(tmp_path: Path) -> None:
    registry = tmp_path / "magic.csv"
    registry.write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "12778,basket,0,AUDUSD.DWX,127780000,2026-01-01,test,active\n"
        "12778,basket,1,EURJPY.DWX,127780001,2026-01-01,test,active\n"
        "11165,multi,0,EURUSD.DWX,111650000,2026-01-01,test,active\n"
        "11165,multi,2,AUDCAD.DWX,111650002,2026-01-01,test,active\n"
        "11165,multi,3,GBPUSD.DWX,111650003,2026-01-01,test,active\n",
        encoding="utf-8",
    )
    sleeves = [
        _sleeve(12778, "AUDUSD.DWX", 127780000),
        _sleeve(11165, "EURUSD.DWX", 111650000),
        _sleeve(11165, "AUDCAD.DWX", 111650002),
    ]

    aliases = blend.load_magic_registry(registry, sleeves)

    assert aliases[127780001] == blend.MagicRoute(127780000, "EURJPY.DWX")
    assert 111650003 not in aliases

    registry.write_text(
        registry.read_text(encoding="utf-8").replace("EURJPY.DWX,127780001", "GBPUSD.DWX,127780001"),
        encoding="utf-8",
    )
    with pytest.raises(blend.InputError, match="not registry-valid"):
        blend.load_magic_registry(registry, sleeves)


def test_live_diagnostics_alpha_is_zero_partial_and_saturated() -> None:
    sleeve = _sleeve()
    backtest_dates = _business_dates(60)
    backtest = {
        sleeve.magic: {day: (10.0 if index % 2 else -10.0) for index, day in enumerate(backtest_dates)}
    }
    live_dates = _business_dates(42, date(2026, 1, 1))
    live = {
        sleeve.magic: {day: (20.0 if index % 2 else -20.0) for index, day in enumerate(live_dates)}
    }

    short_rows, _ = blend.build_live_diagnostics(
        [sleeve], backtest, live, {sleeve.magic: 2}, live_dates[:21],
        blend_window=42, min_live_deals=2, total_risk=0.5, cap=1.0,
    )
    full_rows, _ = blend.build_live_diagnostics(
        [sleeve], backtest, live, {sleeve.magic: 2}, live_dates,
        blend_window=42, min_live_deals=2, total_risk=0.5, cap=1.0,
    )
    no_deal_rows, _ = blend.build_live_diagnostics(
        [sleeve], backtest, live, {sleeve.magic: 1}, live_dates,
        blend_window=42, min_live_deals=2, total_risk=0.5, cap=1.0,
    )

    assert short_rows[0]["alpha"] == 0.5
    assert full_rows[0]["alpha"] == 1.0
    assert no_deal_rows[0]["alpha"] == 0.0
    assert no_deal_rows[0]["hold_reason"] == "INSUFFICIENT_LIVE_DEALS"


def test_walk_forward_validation_is_leakage_free_and_deterministic() -> None:
    dates = _business_dates(620)
    daily = {1: {}, 2: {}, 3: {}}
    for index, day in enumerate(dates):
        # Persistent volatility regimes make the recent pseudo-live window useful
        # for predicting the next window; signs alternate to remove return forecasts.
        regime = (index // 84) % 2
        amp1, amp2 = ((2.0, 12.0) if regime == 0 else (12.0, 2.0))
        sign = -1.0 if index % 2 else 1.0
        daily[1][day] = sign * amp1
        daily[2][day] = -sign * amp2
        daily[3][day] = sign * 5.0

    first, first_folds = blend.walk_forward_validate(
        daily,
        total_risk=2.0,
        cap=1.0,
        blend_window=42,
        min_live_deals=2,
        train_days=252,
        horizon_days=21,
        step_days=42,
    )
    second, second_folds = blend.walk_forward_validate(
        daily,
        total_risk=2.0,
        cap=1.0,
        blend_window=42,
        min_live_deals=2,
        train_days=252,
        horizon_days=21,
        step_days=42,
    )

    assert first == second
    assert first_folds == second_folds
    assert first["fold_count"] >= 6
    assert first["pairs_scored"] > 0


def test_output_guard_and_source_have_no_terminal_control_hooks(tmp_path: Path) -> None:
    source = MODULE_PATH.read_text(encoding="utf-8")
    assert "import MetaTrader5" not in source
    assert "terminal64" not in source.lower()
    assert "subprocess" not in source
    assert "os.system" not in source
    assert blend._path_is_under(Path(r"C:\QM\mt5\T_Live\evidence"), blend.LIVE_ROOT)
    assert not blend._path_is_under(tmp_path, blend.LIVE_ROOT)
    for path in (
        Path(r"C:\QM\mt5\T_Live"),
        Path(r"C:\QM\mt5\T_Live\evidence"),
        Path(r"D:\QM\mt5\T_Live"),
        Path(r"D:\QM\mt5\T_Live\evidence"),
    ):
        with pytest.raises(blend.InputError, match="live terminal root"):
            blend.validate_output_dir(path)
    blend.validate_output_dir(Path(r"C:\QM\mt5\T_Live_backup\evidence"))


def test_evidence_package_disables_git_eol_conversion() -> None:
    assert blend.EVIDENCE_GITATTRIBUTES.splitlines() == ["* -text", "**/* -text"]


def test_proposal_gate_allows_backtest_fallback_for_sparse_live_sleeves() -> None:
    eligible, reasons = blend.proposal_gate(
        deal_evidence_present=True,
        observed_sessions=21,
        eligible_sleeves=23,
        total_sleeves=24,
        oos_verdict="PASS",
    )
    assert eligible is True
    assert reasons == []

    eligible, reasons = blend.proposal_gate(
        deal_evidence_present=True,
        observed_sessions=21,
        eligible_sleeves=0,
        total_sleeves=24,
        oos_verdict="PASS",
    )
    assert eligible is False
    assert reasons == ["NO_SLEEVE_HAS_MINIMUM_LIVE_EVIDENCE"]


def test_hold_diagnostics_withhold_candidate_weights() -> None:
    source = [
        {
            "logical_magic": 123,
            "shadow_weight_percent_not_for_use": 0.625,
            "shadow_delta_vs_current": 0.125,
        }
    ]

    held = blend.diagnostics_for_artifact(source, proposal_eligible=False)
    assert held[0]["shadow_weight_percent_not_for_use"] == ""
    assert held[0]["shadow_delta_vs_current"] == ""
    assert source[0]["shadow_weight_percent_not_for_use"] == 0.625

    reviewable = blend.diagnostics_for_artifact(source, proposal_eligible=True)
    assert reviewable[0]["shadow_weight_percent_not_for_use"] == 0.625
    assert reviewable[0]["shadow_delta_vs_current"] == 0.125


def test_canonical_json_is_byte_deterministic(tmp_path: Path) -> None:
    first = tmp_path / "first.json"
    second = tmp_path / "second.json"
    payload = {"z": [3, 2, 1], "a": {"b": True}}
    blend._canonical_json(first, payload)
    blend._canonical_json(second, payload)
    assert first.read_bytes() == second.read_bytes()


def test_book_evidence_metrics_reports_realised_risk_without_forecasts() -> None:
    metrics = blend._book_evidence_metrics([100.0, -250.0, 50.0, 0.0], 100_000.0)
    assert metrics["sessions"] == 4
    assert metrics["total_net"] == -100.0
    assert metrics["positive_sessions"] == 2
    assert metrics["negative_sessions"] == 1
    assert metrics["flat_sessions"] == 1
    assert metrics["worst_day_pct"] == -0.25
