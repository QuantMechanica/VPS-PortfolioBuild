#!/usr/bin/env python3
"""Outcome-blind XAUUSD.DWX profile for the frozen QM5_13210 auditor.

The existing EURUSD auditor is loaded into a private module namespace.  This
profile changes only symbol-specific research, set, authorization and cost
contracts.  It keeps the same T1 custom-symbol lane, Model-4 runner, four
DEV/OOS time cohorts, two duplicate runs and native evidence fences.

XAU execution costs are preregistered before any XAU native outcome is opened:
real-tick bid/ask spread, 0.005% round-turn notional commission, one point per
side at the blocking merit center, and three points per side at the blocking
p95 survival axis.  The slippage numbers are explicitly identified as the
Factory auto-stub proxy rather than measured XAU live-fill evidence.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
BASE_TOOL_PATH = TOOL_PATH.with_name("audit_mulham_asian_sweep_london.py")
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]

_BASE_SPEC = importlib.util.spec_from_file_location(
    "qm13210_xau_private_base_audit", BASE_TOOL_PATH
)
if _BASE_SPEC is None or _BASE_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load base auditor: {BASE_TOOL_PATH}")
B = importlib.util.module_from_spec(_BASE_SPEC)
sys.modules[_BASE_SPEC.name] = B
_BASE_SPEC.loader.exec_module(B)


ANALYSIS_ID = "QM5_13210_MULHAM_ASIAN_SWEEP_LONDON_XAUUSD_NATIVE_001"
RESEARCH_SYMBOL = "XAUUSD.DWX"
MERIT_CONTRACT_VERSION = "QM5_13210_XAUUSD_MERIT_V1_20260721"
SYMBOL_POLICY = "XAUUSD.DWX_RESEARCH_BACKTEST_ONLY_NO_LIVE_PARITY_GATE"
ALLOWED_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_13210\XAUUSD_DWX"
)
SCHEDULED_TASK_PREFIX = "QM_QM13210_XAU_AUDIT_"
LAUNCHER_REVISION = "QM13210_XAU_SCHEDULED_TASK_V1"
AUTHORIZATION_SCOPE = (
    "QM5_13210_XAUUSD_4_CELLS_X_2_DUPLICATES_MODEL4_T1"
)

CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "xauusd_outcome_fenced_analysis_contract_20260721.json"
)
# Filled only after the outcome-blind contract bytes exist.  This value is an
# immutable preregistration boundary, not a runtime-generated receipt.
EXPECTED_CONTRACT_SHA256 = (
    "20963939b86c3150d236d5936d250495e7f7b8d9e3ebc69d20882f7aa3d7eb7c"
)
BUILD_RECEIPT_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
)
SLIPPAGE_CALIBRATION_PATH = (
    REPO_ROOT / "framework" / "calibrations" / "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"
)

EXPECTED_BASE_TOOL_SHA256 = (
    "dc56390ba11417db7349b369b07ae8c52aac4df48d17c94c18941dd90928c7a2"
)
EXPECTED_BUILD_RECEIPT_SHA256 = (
    "a9fce2d992a04ec072a1957626d12c32640f415e32f96d236772c98e2fb7304c"
)
EXPECTED_XAU_SET_SHA256 = (
    "23970e75ad7c41e682455ddb255473c9e527c2f3a404dbfd74fa8ac9fd363ac6"
)

XAU_CONTRACT_SIZE_OZ = Decimal("100")
XAU_POINT_SIZE_QUOTE = Decimal("0.01")
XAU_POINT_VALUE_USD_PER_LOT_PER_SIDE = Decimal("1")
XAU_COMMISSION_RATE_RT = Decimal("0.00005")
XAU_REGISTRY_INDICATIVE_RT_PER_LOT_USD = Decimal("20.37")
XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE = Decimal("1")
XAU_P95_SLIPPAGE_POINTS_PER_SIDE = Decimal("3")


MERIT_GATES: dict[str, Any] = {
    "version": MERIT_CONTRACT_VERSION,
    "dev": {
        "minimum_trades": 80,
        "minimum_cost_profit_factor": "1.20",
        "net_must_be_strictly_positive": True,
        "maximum_close_drawdown_percent": "10.0",
    },
    "each_oos_year": {
        "minimum_trades": 12,
        "minimum_cost_profit_factor_strict": "1.00",
        "net_must_be_strictly_positive": True,
    },
    "oos_pooled": {
        "minimum_trades": 45,
        "minimum_cost_profit_factor": "1.20",
        "net_must_be_strictly_positive": True,
        "maximum_close_drawdown_percent": "10.0",
    },
    "leave_best_oos_year_out": {
        "minimum_cost_profit_factor": "1.05",
        "net_must_be_strictly_positive": True,
        "best_year_basis": "highest_cost_adjusted_net",
    },
    "maximum_single_year_share_of_positive_oos_gross_profit": "0.60",
    "maximum_new_york_day_loss_percent_of_100k": "3.0",
    "top_five_percent_winners_removed": {
        "minimum_cost_profit_factor": "1.00",
        "removal_count": "ceil(0.05 * positive_winner_count)",
    },
    "execution_cost_axes": {
        "spread": "EMBEDDED_IN_BOUND_XAUUSD_DWX_REAL_TICKS",
        "commission": {
            "model": "MAX_DXZ_FTMO_0.005PCT_NOTIONAL_ROUND_TURN",
            "rate_round_turn": "0.00005",
            "contract_size_oz_per_lot": "100",
            "per_trade_basis": "entry_price_x_100oz_x_volume_x_0.00005",
        },
        "slippage": {
            "point_size_quote": "0.01",
            "point_value_usd_per_lot_per_side": "1",
            "merit_center_points_per_side": "1",
            "p95_stress_points_per_side": "3",
            "source": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
            "merit_center_application": "BLOCKING_ALL_BASE_GATES",
            "p95_application": "BLOCKING_BREAKEVEN_SURVIVAL_GATES",
        },
        "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
    },
    "p95_slippage_stress": {
        "dev_profit_factor_strict": "1.00",
        "dev_net_must_be_strictly_positive": True,
        "each_oos_year_profit_factor_strict": "1.00",
        "each_oos_year_net_must_be_strictly_positive": True,
        "oos_pooled_profit_factor_strict": "1.00",
        "oos_pooled_net_must_be_strictly_positive": True,
    },
}


_BASE_EXPECTED_BINDING_PATHS = B._expected_binding_paths
_BASE_PREFLIGHT = B.preflight
_BASE_ASSERT_PRE_RECEIPT = B.assert_pre_receipt
_BASE_RESOLVE_COST_SCHEDULE = B.resolve_cost_schedule
_BASE_RECONSTRUCT_TRADES = B._reconstruct_trades
_BASE_EVALUATE_MERIT = B.evaluate_merit
_BASE_LOAD_BOUND_NEWS_EVENTS = B.load_bound_news_events


def _configure_private_profile() -> None:
    B.__doc__ = __doc__
    B.TOOL_PATH = TOOL_PATH
    B.ANALYSIS_ID = ANALYSIS_ID
    B.MERIT_CONTRACT_VERSION = MERIT_CONTRACT_VERSION
    B.MERIT_GATES = MERIT_GATES
    B.SYMBOL_POLICY = SYMBOL_POLICY
    B.ALLOWED_RUN_ROOT = ALLOWED_RUN_ROOT
    B.SCHEDULED_TASK_PREFIX = SCHEDULED_TASK_PREFIX
    B.LAUNCHER_REVISION = LAUNCHER_REVISION
    B.EXPECTED_BUILD_HASHES = dict(B.EXPECTED_BUILD_HASHES)
    B.EXPECTED_BUILD_HASHES["set"] = EXPECTED_XAU_SET_SHA256
    B.REQUIRED_BINDING_ROLES = frozenset(
        set(B.REQUIRED_BINDING_ROLES)
        | {"base_tool", "xau_contract", "slippage_calibration"}
    )


_configure_private_profile()


def enforce_symbol_policy(symbol: str) -> None:
    if symbol != RESEARCH_SYMBOL:
        raise B.InvalidEvidence(
            f"symbol outside the frozen XAU single-symbol policy: {symbol!r}; "
            f"only {RESEARCH_SYMBOL} is authorized"
        )


def _validate_set_contract(
    symbol: str, metadata: Mapping[str, str], inputs: Mapping[str, str]
) -> None:
    expected = {
        "qm_ea_id": "13210",
        "qm_magic_slot_offset": "1",
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "PORTFOLIO_WEIGHT": "1",
        "qm_news_temporal": "3",
        "qm_news_compliance": "1",
        "qm_news_stale_max_hours": "336",
        "qm_news_min_impact": "high",
        "qm_news_mode_legacy": "0",
        "strategy_asia_start_hour": "3",
        "strategy_asia_start_minute": "0",
        "strategy_asia_end_hour": "7",
        "strategy_asia_end_minute": "0",
        "strategy_sweep_start_hour": "8",
        "strategy_sweep_start_minute": "30",
        "strategy_sweep_end_hour": "10",
        "strategy_sweep_end_minute": "0",
        "strategy_entry_cancel_hour": "12",
        "strategy_entry_cancel_minute": "0",
        "strategy_flatten_hour": "20",
        "strategy_flatten_minute": "0",
        "strategy_atr_period": "14",
        "strategy_asia_trend_max_frac": "0.50",
        "strategy_asia_range_min_atr": "0.30",
        "strategy_sl_buffer_atr": "0.10",
        "strategy_spread_max_atr_frac": "0.10",
        "strategy_tp_mode": "QM13210_TP_OPPOSITE_BODY",
        "strategy_fixed_rr": "3.0",
    }
    drift = {
        key: (wanted, inputs.get(key))
        for key, wanted in expected.items()
        if inputs.get(key) != wanted
    }
    if (
        symbol != RESEARCH_SYMBOL
        or metadata.get("symbol") != symbol
        or metadata.get("timeframe") != B.TIMEFRAME
    ):
        raise B.InvalidEvidence(
            "set metadata violates the XAUUSD.DWX/M5 single-symbol contract"
        )
    if drift:
        raise B.InvalidEvidence(f"XAU set input contract drift: {drift}")


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths["base_tool"] = BASE_TOOL_PATH
    paths["xau_contract"] = CONTRACT_PATH
    paths["slippage_calibration"] = SLIPPAGE_CALIBRATION_PATH
    return paths


def _artifact_contract_paths() -> dict[str, Path]:
    return {
        "card": B.CARD_PATH,
        "spec": B.SPEC_PATH,
        "mq5": B.MQ5_PATH,
        "ex5": B.EX5_PATH,
        "set": EA_ROOT
        / "sets"
        / f"{B.EXPERT_NAME}_{RESEARCH_SYMBOL}_M5_backtest.set",
        "build_receipt": BUILD_RECEIPT_PATH,
        "base_tool": BASE_TOOL_PATH,
    }


def _validate_contract_artifact_bindings(
    bindings: Any,
) -> dict[str, dict[str, Any]]:
    paths = _artifact_contract_paths()
    if not isinstance(bindings, Mapping) or set(bindings) != set(paths):
        raise B.InvalidEvidence("XAU contract artifact-role closure drift")
    result: dict[str, dict[str, Any]] = {}
    for role, path in paths.items():
        row = bindings.get(role)
        if not isinstance(row, Mapping) or set(row) != {"path", "size", "sha256"}:
            raise B.InvalidEvidence(f"XAU contract malformed artifact binding: {role}")
        expected_path = path.resolve()
        observed_path = Path(str(row.get("path", ""))).resolve()
        if observed_path != expected_path:
            raise B.InvalidEvidence(f"XAU contract artifact path drift: {role}")
        B.assert_binding(row, f"XAU preregistered {role}")
        result[role] = {
            "path": str(observed_path),
            "size": int(row["size"]),
            "sha256": str(row["sha256"]).lower(),
        }
    expected_hashes = {
        "card": B.EXPECTED_BUILD_HASHES["card"],
        "spec": B.EXPECTED_BUILD_HASHES["spec"],
        "mq5": B.EXPECTED_BUILD_HASHES["mq5"],
        "ex5": B.EXPECTED_BUILD_HASHES["ex5"],
        "set": EXPECTED_XAU_SET_SHA256,
        "build_receipt": EXPECTED_BUILD_RECEIPT_SHA256,
        "base_tool": EXPECTED_BASE_TOOL_SHA256,
    }
    drift = {
        role: (wanted, result[role]["sha256"])
        for role, wanted in expected_hashes.items()
        if result[role]["sha256"] != wanted
    }
    if drift:
        raise B.InvalidEvidence(f"XAU preregistered artifact hash drift: {drift}")
    return result


def validate_analysis_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    binding = B.file_binding(path, EXPECTED_CONTRACT_SHA256)
    payload = B.load_json(path)
    expected_fields = {
        "schema_version",
        "artifact_type",
        "status",
        "created_utc",
        "analysis_id",
        "candidate",
        "lane_and_data",
        "windows",
        "artifact_bindings",
        "execution_cost_contract",
        "merit_contract",
        "outcome_fence",
    }
    if set(payload) != expected_fields:
        raise B.InvalidEvidence("XAU analysis-contract field closure drift")
    if (
        payload.get("schema_version") != 1
        or payload.get("artifact_type")
        != "QM5_13210_XAUUSD_OUTCOME_BLIND_ANALYSIS_CONTRACT"
        or payload.get("status") != "PREREGISTERED_OUTCOME_BLIND"
        or payload.get("analysis_id") != ANALYSIS_ID
    ):
        raise B.InvalidEvidence("XAU analysis-contract identity/status drift")
    created = B.parse_utc(str(payload.get("created_utc", "")), "XAU contract created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("XAU contract creation time is implausibly in the future")
    if payload.get("candidate") != {
        "ea_id": "QM5_13210",
        "strategy": "mulham-asian-sweep-london",
        "symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
        "parameter_tuning_forbidden": True,
        "separate_from_eurusd_outcome_namespace": True,
    }:
        raise B.InvalidEvidence("XAU candidate identity drift")
    if payload.get("lane_and_data") != {
        "terminal": "T1",
        "research_store": "T1_CUSTOM_SYMBOL_STORE",
        "namespace": ".DWX_RESEARCH_BACKTEST",
        "live_suffix_policy": "NOT_EVALUATED_IN_CANDIDATE_ANALYSIS",
        "live_parity_required": False,
        "deployment_routing_evaluated": False,
        "model4_real_ticks_required": True,
    }:
        raise B.InvalidEvidence("XAU T1/data contract drift")
    expected_windows = [
        {
            "cell_id": window.cell_id,
            "cohort": window.cohort,
            "from_date": window.from_date.isoformat(),
            "to_date": window.to_date.isoformat(),
        }
        for window in B.WINDOWS
    ]
    if payload.get("windows") != expected_windows:
        raise B.InvalidEvidence("XAU DEV/OOS window drift")
    artifacts = _validate_contract_artifact_bindings(payload.get("artifact_bindings"))
    if payload.get("execution_cost_contract") != MERIT_GATES["execution_cost_axes"]:
        raise B.InvalidEvidence("XAU execution-cost contract drift")
    if payload.get("merit_contract") != MERIT_GATES:
        raise B.InvalidEvidence("XAU merit contract drift")
    if payload.get("outcome_fence") != {
        "eurusd_native_outcomes_read_to_select_xau": False,
        "xau_native_reports_opened": False,
        "xau_deal_rows_parsed": False,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }:
        raise B.InvalidEvidence("XAU preregistration outcome fence drift")
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "artifact_bindings": artifacts,
        "execution_cost_contract": payload["execution_cost_contract"],
        "merit_contract": payload["merit_contract"],
    }


def _load_slippage_proxy(path: Path) -> dict[str, Any]:
    payload = B.load_json(path)
    symbols = payload.get("symbols")
    row = symbols.get(RESEARCH_SYMBOL) if isinstance(symbols, Mapping) else None
    slippage = row.get("slippage_points") if isinstance(row, Mapping) else None
    spread = row.get("spread_points") if isinstance(row, Mapping) else None
    latency = row.get("latency_ms") if isinstance(row, Mapping) else None
    if (
        payload.get("measurement_status") != "MEASURED"
        or not isinstance(row, Mapping)
        or row.get("auto_stub") is not True
        or row.get("stub_source") != "farmctl_pump_p5_calibration_autostub"
        or not isinstance(slippage, Mapping)
        or not isinstance(spread, Mapping)
        or not isinstance(latency, Mapping)
        or B._strict_decimal(slippage.get("avg"), "XAU slippage avg")
        != XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE
        or B._strict_decimal(slippage.get("p95"), "XAU slippage p95")
        != XAU_P95_SLIPPAGE_POINTS_PER_SIDE
        or B._strict_decimal(spread.get("median"), "XAU spread median")
        != Decimal("20")
        or B._strict_decimal(spread.get("p95"), "XAU spread p95")
        != Decimal("60")
        or B._strict_decimal(latency.get("avg"), "XAU latency avg")
        != Decimal("50")
        or B._strict_decimal(latency.get("p95"), "XAU latency p95")
        != Decimal("120")
    ):
        raise B.InvalidEvidence("XAU Factory slippage-proxy contract drift")
    return {
        "binding": B.file_binding(path),
        "classification": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
        "points_axis_per_side": ["1", "3"],
        "spread_reference_points": {"median": "20", "p95": "60"},
        "latency_reference_ms": {"avg": "50", "p95": "120"},
    }


def resolve_cost_schedule(
    path: Path,
    symbol: str,
    live_commission_path: Path = B.LIVE_COMMISSION_PATH,
    slippage_calibration_path: Path | None = None,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    payload = B.load_json(path)
    symbols = payload.get("symbols")
    row = symbols.get("XAUUSD") if isinstance(symbols, Mapping) else None
    dxz = row.get("dxz") if isinstance(row, Mapping) else None
    ftmo = row.get("ftmo") if isinstance(row, Mapping) else None
    if (
        not isinstance(row, Mapping)
        or row.get("dwx_symbol") != RESEARCH_SYMBOL
        or row.get("asset_class") != "commodity"
        or B._strict_decimal(row.get("contract_size_oz"), "XAU contract size")
        != XAU_CONTRACT_SIZE_OZ
        or not isinstance(dxz, Mapping)
        or not isinstance(ftmo, Mapping)
        or dxz.get("commission_model") != "pct_notional_0.005pct_rt"
        or B._strict_decimal(dxz.get("per_side_pct"), "XAU DXZ per-side pct")
        != Decimal("0.0025")
        or B._strict_decimal(
            dxz.get("commission_rt_per_lot_usd_indicative"),
            "XAU DXZ indicative RT",
        )
        != XAU_REGISTRY_INDICATIVE_RT_PER_LOT_USD
        or ftmo.get("commission_model") != "pct_notional_metals"
        or B._strict_decimal(
            ftmo.get("commission_rt_per_lot_usd_indicative"),
            "XAU FTMO indicative RT",
        )
        != XAU_REGISTRY_INDICATIVE_RT_PER_LOT_USD
        or B._strict_decimal(
            row.get("worst_case_rt_per_lot_usd"), "XAU registry worst RT"
        )
        != XAU_REGISTRY_INDICATIVE_RT_PER_LOT_USD
    ):
        raise B.InvalidEvidence("XAU venue-cost registry contract drift")
    live = B.load_json(live_commission_path)
    classes = live.get("classes")
    symbol_class = live.get("symbol_class")
    commodity = classes.get("commodity") if isinstance(classes, Mapping) else None
    if (
        live.get("model")
        != "max(pct_rate_rt*notional_acct, flat_per_lot_rt*volume)"
        or not isinstance(symbol_class, Mapping)
        or symbol_class.get(RESEARCH_SYMBOL) != "commodity"
        or not isinstance(commodity, Mapping)
        or B._strict_decimal(commodity.get("pct_rate_rt"), "commodity pct RT")
        != XAU_COMMISSION_RATE_RT
        or B._strict_decimal(commodity.get("flat_per_lot_rt"), "commodity flat RT")
        != Decimal("0")
    ):
        raise B.InvalidEvidence("XAU live-commission commodity closure drift")
    proxy = _load_slippage_proxy(
        (slippage_calibration_path or SLIPPAGE_CALIBRATION_PATH).resolve()
    )
    return {
        "symbol": RESEARCH_SYMBOL,
        "currency": "USD",
        "application": (
            "XAU_0.005PCT_NOTIONAL_RT_PLUS_BLOCKING_PER_SIDE_SLIPPAGE_"
            "ROUNDED_TO_CENT_PER_TRADE"
        ),
        "dxz_pct_notional_rt": "0.00005",
        "ftmo_pct_notional_rt": "0.00005",
        "ftmo_rt_per_lot_usd": "0",
        "contract_size_base_per_lot": "100",
        "contract_size_unit": "TROY_OUNCE",
        "registry_indicative_rt_per_lot_usd_at_4074": "20.37",
        "spread": "EMBEDDED_IN_BOUND_XAUUSD_DWX_REAL_TICKS",
        "point_size_quote": "0.01",
        "point_value_usd_per_lot_per_side": "1",
        "merit_slippage_points_per_side": "1",
        "p95_slippage_points_per_side": "3",
        "slippage_proxy": proxy,
        "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
    }


def _trade_with_incremental_slippage(
    trade: Any, incremental_points_per_side: Decimal
) -> Any:
    if incremental_points_per_side < Decimal("0"):
        raise B.InvalidEvidence("XAU incremental slippage cannot be negative")
    extra = B._money(
        Decimal("2")
        * incremental_points_per_side
        * trade.volume
        * XAU_POINT_VALUE_USD_PER_LOT_PER_SIDE
    )
    return B.TradeRecord(
        sequence=trade.sequence,
        symbol=trade.symbol,
        side=trade.side,
        entry_deal=trade.entry_deal,
        exit_deals=trade.exit_deals,
        entry_time_broker=trade.entry_time_broker,
        exit_time_broker=trade.exit_time_broker,
        entry_time_ny=trade.entry_time_ny,
        exit_time_ny=trade.exit_time_ny,
        broker_day=trade.broker_day,
        new_york_day=trade.new_york_day,
        volume=trade.volume,
        entry_price=trade.entry_price,
        entry_comment=trade.entry_comment,
        native_net_usd=trade.native_net_usd,
        venue_cost_usd=B._money(trade.venue_cost_usd + extra),
        adjusted_net_usd=B._money(trade.adjusted_net_usd - extra),
    )


def _reconstruct_trades(
    deals: Sequence[Any], symbol: str, cost_schedule: Mapping[str, Any]
) -> list[Any]:
    enforce_symbol_policy(symbol)
    if (
        cost_schedule.get("symbol") != RESEARCH_SYMBOL
        or B._strict_decimal(
            cost_schedule.get("merit_slippage_points_per_side"),
            "XAU merit slippage",
        )
        != XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE
        or B._strict_decimal(
            cost_schedule.get("point_value_usd_per_lot_per_side"),
            "XAU point value",
        )
        != XAU_POINT_VALUE_USD_PER_LOT_PER_SIDE
    ):
        raise B.InvalidEvidence("XAU cost schedule is not the frozen merit center")
    commission_adjusted = _BASE_RECONSTRUCT_TRADES(deals, symbol, cost_schedule)
    return [
        _trade_with_incremental_slippage(
            trade, XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE
        )
        for trade in commission_adjusted
    ]


def _p95_stress_trades(trades: Sequence[Any]) -> list[Any]:
    incremental = (
        XAU_P95_SLIPPAGE_POINTS_PER_SIDE
        - XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE
    )
    return [_trade_with_incremental_slippage(trade, incremental) for trade in trades]


def _stress_gate(
    gate_id: str, metrics: Mapping[str, Any]
) -> list[dict[str, Any]]:
    return [
        B._gate(
            f"{gate_id}_PF",
            B._pf_at_least(metrics, Decimal("1.00"), strict=True),
            metrics["cost_adjusted_profit_factor"],
            ">1.00 at 3 XAU points/side",
        ),
        B._gate(
            f"{gate_id}_NET",
            Decimal(str(metrics["cost_adjusted_net_usd"])) > B.ZERO,
            metrics["cost_adjusted_net_usd"],
            ">0 at 3 XAU points/side",
        ),
    ]


def evaluate_merit(cells: Mapping[str, Sequence[Any]]) -> dict[str, Any]:
    merit = _BASE_EVALUATE_MERIT(cells)
    stressed = {key: _p95_stress_trades(rows) for key, rows in cells.items()}
    dev = B.performance(stressed["DEV"])
    yearly = {
        str(year): B.performance(stressed[f"OOS_{year}"])
        for year in (2023, 2024, 2025)
    }
    pooled = B.performance(
        [
            trade
            for year in (2023, 2024, 2025)
            for trade in stressed[f"OOS_{year}"]
        ]
    )
    stress_gates = _stress_gate("XAU_P95_DEV", dev)
    for year in (2023, 2024, 2025):
        stress_gates.extend(_stress_gate(f"XAU_P95_OOS_{year}", yearly[str(year)]))
    stress_gates.extend(_stress_gate("XAU_P95_OOS_POOLED", pooled))
    merit["gates"].extend(stress_gates)
    merit["xau_p95_slippage_stress"] = {
        "points_per_side": "3",
        "classification": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
        "dev": dev,
        "oos_by_year": yearly,
        "oos_pooled": pooled,
        "gates": stress_gates,
    }
    merit["status"] = (
        "PASS"
        if all(row["status"] == "PASS" for row in merit["gates"])
        else "FAIL"
    )
    return merit


def load_bound_news_events(pre: Mapping[str, Any]) -> tuple[Any, ...]:
    # XAU is quoted in USD and the approved card's source-specific veto is US
    # high-impact news.  The base loader still validates both bound calendars;
    # only its currency projection changes for this XAU-only profile.
    events = tuple(
        event for event in _BASE_LOAD_BOUND_NEWS_EVENTS(pre) if event.currency == "USD"
    )
    if not events:
        raise B.InvalidEvidence("bound calendars contain no USD high-impact events")
    return events


def _contract_receipt() -> dict[str, Any]:
    return validate_analysis_contract(CONTRACT_PATH)


def preflight(
    symbol: str,
    research_readiness_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    if build_receipt_path.resolve() != BUILD_RECEIPT_PATH.resolve():
        raise B.InvalidEvidence("XAU PRE requires the exact bound build receipt path")
    contract = _contract_receipt()
    pre = _BASE_PREFLIGHT(
        symbol,
        research_readiness_receipt_path,
        data_manifest_path,
        build_receipt_path,
        run_root,
    )
    pre["xau_preregistration"] = contract
    return pre


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    expected = _contract_receipt()
    if pre.get("xau_preregistration") != expected:
        raise B.InvalidEvidence("PRE XAU preregistration binding drift")
    return pre


def validate_authorization(
    path: Path,
    pre_sha256: str,
    *,
    require_current: bool = True,
    now: datetime | None = None,
) -> dict[str, Any]:
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": RESEARCH_SYMBOL,
        "authorized_cells": [window.cell_id for window in B.WINDOWS],
        "duplicates_per_cell": B.DUPLICATES,
        "model": 4,
        "authorize_native_outcomes": True,
    }
    drift = {
        key: (wanted, payload.get(key))
        for key, wanted in expected.items()
        if payload.get(key) != wanted
    }
    if drift:
        raise B.AuthorizationError(f"XAU native authorization drift: {drift}")
    created = B.parse_utc(
        str(payload.get("created_utc", "")), "XAU authorization created_utc"
    )
    expires = B.parse_utc(
        str(payload.get("expires_utc", "")), "XAU authorization expires_utc"
    )
    if expires <= created or expires - created > timedelta(hours=24):
        raise B.AuthorizationError("XAU authorization lifetime must be >0 and <=24 hours")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if require_current and not (created - timedelta(minutes=5) <= current <= expires):
        raise B.AuthorizationError("XAU native authorization is not currently valid")
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "payload": payload,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser(
        "prepare-data",
        help="Hash the exact XAUUSD.DWX T1 research store; never starts MT5",
    )
    prepare.add_argument("--symbol", required=True)
    prepare.add_argument("--data-manifest", type=Path, required=True)
    prepare.add_argument("--research-data-receipt", type=Path, required=True)
    pre = sub.add_parser("pre", help="Outcome-blind XAU PRE and immutable receipt")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--research-data-receipt", type=Path, required=True)
    pre.add_argument("--data-manifest", type=Path, required=True)
    pre.add_argument("--build-receipt", type=Path, required=True)
    pre.add_argument("--run-root", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    launch = sub.add_parser("launch", help="Start the persistent XAU native worker")
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.add_argument("--resume", action="store_true")
    post = sub.add_parser("post", help="Audit COMPLETE XAU evidence and frozen gates")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    status = sub.add_parser("status", help="Read XAU launch state without starting anything")
    status.add_argument("--state", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser


# Install hooks only in the private base namespace.  Importing this adapter
# cannot change the committed EURUSD module or a separately imported instance.
B.enforce_symbol_policy = enforce_symbol_policy
B._validate_set_contract = _validate_set_contract
B._expected_binding_paths = _expected_binding_paths
B.resolve_cost_schedule = resolve_cost_schedule
B._reconstruct_trades = _reconstruct_trades
B.evaluate_merit = evaluate_merit
B.load_bound_news_events = load_bound_news_events
B.preflight = preflight
B.assert_pre_receipt = assert_pre_receipt
B.validate_authorization = validate_authorization
B.build_parser = build_parser

AuditError = B.AuditError
InvalidEvidence = B.InvalidEvidence
AuthorizationError = B.AuthorizationError
TradeRecord = B.TradeRecord
NativeRunAudit = B.NativeRunAudit
NewsEvent = B.NewsEvent
Window = B.Window
WINDOWS = B.WINDOWS
DUPLICATES = B.DUPLICATES
TIMEFRAME = B.TIMEFRAME
REQUIRED_BINDING_ROLES = B.REQUIRED_BINDING_ROLES


def build_plan(symbol: str, set_binding: Mapping[str, Any], run_root: Path) -> dict[str, Any]:
    return B.build_plan(symbol, set_binding, run_root)


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    return B.runner_command(pre, cell)


def main(argv: Sequence[str] | None = None) -> int:
    return B.main(argv)


def __getattr__(name: str) -> Any:
    return getattr(B, name)


if __name__ == "__main__":
    raise SystemExit(main())
