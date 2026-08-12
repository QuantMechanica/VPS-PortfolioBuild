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
import re
import subprocess
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
RUN_FAMILY_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_13210")
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "XAUUSD_MULHAM_NATIVE_001"
ATTEMPT_001_RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
ATTEMPT_002_RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_002"
ALLOWED_RUN_ROOT = ATTEMPT_002_RUN_ROOT
LEGACY_RUN_ROOT = Path(
    r"D:\QM\reports\candidate_analysis\QM5_13210\XAUUSD_DWX"
)
SCHEDULED_TASK_PREFIX = "QM_QM13210_XAU_AUDIT_"
LAUNCHER_REVISION = "QM13210_XAU_SCHEDULED_TASK_INFRA_ALTERNATE_V2"
AUTHORIZATION_SCOPE = (
    "QM5_13210_XAUUSD_ATTEMPT_002_INFRA_ALTERNATE_"
    "4_CELLS_X_2_DUPLICATES_MODEL4_T1"
)

CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "xauusd_outcome_fenced_analysis_contract_20260721.json"
)
BUILD_RECEIPT_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
)
ATTEMPT_001_CLOSURE_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "xauusd_attempt001_invalid_infrastructure_closure_20260721.json"
)
ATTEMPT_001_PRE_RECEIPT_PATH = ATTEMPT_001_RUN_ROOT / "pre_receipt.json"
ATTEMPT_001_AUTHORIZATION_PATH = (
    ATTEMPT_001_RUN_ROOT / "native_outcome_authorization.json"
)
ATTEMPT_001_STATE_PATH = ATTEMPT_001_RUN_ROOT / "launch_state.json"
ATTEMPT_001_JOB_PATH = ATTEMPT_001_RUN_ROOT / "launch_job.json"
ATTEMPT_001_TASK_NAME = "QM_QM13210_XAU_AUDIT_08e91a0b4fef8e702efc569e"

ATTEMPT_002_PRE_RECEIPT_PATH = ATTEMPT_002_RUN_ROOT / "pre_receipt.json"
ATTEMPT_002_AUTHORIZATION_PATH = (
    ATTEMPT_002_RUN_ROOT / "native_outcome_authorization.json"
)
ATTEMPT_002_STATE_PATH = ATTEMPT_002_RUN_ROOT / "launch_state.json"
ATTEMPT_002_JOB_PATH = ATTEMPT_002_RUN_ROOT / "launch_job.json"
ATTEMPT_002_POST_RECEIPT_PATH = ATTEMPT_002_RUN_ROOT / "post_receipt.json"

ATTEMPT_002_RESEARCH_READINESS_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_13210\data\XAUUSD_DWX_201807_202512_T1_receipt.json"
)
ATTEMPT_002_DATA_MANIFEST_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_13210\data\XAUUSD_DWX_201807_202512_T1_manifest.json"
)
ATTEMPT_002_INPUT_BINDINGS: dict[str, dict[str, Any]] = {
    "research_readiness_receipt": {
        "path": str(ATTEMPT_002_RESEARCH_READINESS_PATH),
        "size": 817,
        "sha256": "832abb2b191e85e61c6d6621dfb8971a79b2ad07fa6fdc609e75ebc89d2ee1de",
    },
    "data_manifest": {
        "path": str(ATTEMPT_002_DATA_MANIFEST_PATH),
        "size": 19831,
        "sha256": "f4c35f3acff8d8b6c5a0d337f181d418b1f546b660156942b18069bffae71f17",
    },
}

XAU_CONTRACT_SIZE_OZ = Decimal("100")
XAU_POINT_SIZE_QUOTE = Decimal("0.01")
XAU_POINT_VALUE_USD_PER_LOT_PER_SIDE = Decimal("1")
XAU_COMMISSION_RATE_RT = Decimal("0.00005")
XAU_REGISTRY_INDICATIVE_RT_PER_LOT_USD = Decimal("20.37")
XAU_MERIT_SLIPPAGE_POINTS_PER_SIDE = Decimal("1")
XAU_P95_SLIPPAGE_POINTS_PER_SIDE = Decimal("3")

XAU_SYMBOL_SPEC_CONTRACT: dict[str, Any] = {
    "research_symbol": RESEARCH_SYMBOL,
    "live_symbol_exact_alias": "XAUUSD",
    "trade_calc_mode": "SYMBOL_CALC_MODE_CFD",
    "contract_size_oz_per_lot": "100",
    "point_size_quote": "0.01",
    "profit_currency": "USD",
    "enforcement": "EA_ONINIT_FAIL_CLOSED_AND_ANALYSIS_CONTRACT_BOUND",
}

# This is the complete XAU-only projection used by the audit.  It is embedded
# in the finalized analysis contract; PRE never re-reads or binds the global
# calibration file that the Factory pump may legitimately update.
XAU_CALIBRATION_PROJECTION: dict[str, Any] = {
    "schema_version": 1,
    "symbol": RESEARCH_SYMBOL,
    "classification": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
    "source_lineage": "VPS_SLIPPAGE_LATENCY_CALIBRATION_V2_XAUUSD_DWX_ROW",
    "auto_stub": True,
    "stub_source": "farmctl_pump_p5_calibration_autostub",
    "slippage_points_per_side": {"merit_center": "1", "p95_stress": "3"},
    "spread_reference_points": {"median": "20", "p95": "60"},
    "latency_reference_ms": {"avg": "50", "p95": "120"},
    "live_fill_measurement_claimed": False,
}

FINAL_ARTIFACT_ROLES = frozenset(
    {
        "adapter",
        "attempt001_closure",
        "base_tool",
        "build_receipt",
        "card",
        "ex5",
        "mq5",
        "scheduled_task_helper",
        "set",
        "spec",
    }
)


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

ATTEMPT_002_COST_SCHEDULE: dict[str, Any] = {
    "symbol": RESEARCH_SYMBOL,
    "currency": "USD",
    "spread": "EMBEDDED_IN_BOUND_XAUUSD_DWX_REAL_TICKS",
    "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
    "dxz_pct_notional_rt": "0.00005",
    "ftmo_pct_notional_rt": "0.00005",
    "ftmo_rt_per_lot_usd": "0",
    "contract_size_base_per_lot": "100",
    "contract_size_unit": "TROY_OUNCE",
    "registry_indicative_rt_per_lot_usd_at_4074": "20.37",
    "point_size_quote": "0.01",
    "point_value_usd_per_lot_per_side": "1",
    "merit_slippage_points_per_side": "1",
    "p95_slippage_points_per_side": "3",
    "slippage_proxy": {
        "classification": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
        "projection_sha256": (
            "712234f2a5f3d144433bbd443e63b9df2dc7442d3800e2a630a4fed625d9b193"
        ),
        "points_axis_per_side": ["1", "3"],
        "spread_reference_points": {"median": "20", "p95": "60"},
        "latency_reference_ms": {"avg": "50", "p95": "120"},
    },
    "application": (
        "XAU_0.005PCT_NOTIONAL_RT_PLUS_BLOCKING_PER_SIDE_SLIPPAGE_"
        "ROUNDED_TO_CENT_PER_TRADE"
    ),
}


_BASE_EXPECTED_BINDING_PATHS = B._expected_binding_paths
_BASE_PREFLIGHT = B.preflight
_BASE_ASSERT_PRE_RECEIPT = B.assert_pre_receipt
_BASE_RESOLVE_COST_SCHEDULE = B.resolve_cost_schedule
_BASE_RECONSTRUCT_TRADES = B._reconstruct_trades
_BASE_EVALUATE_MERIT = B.evaluate_merit
_BASE_LOAD_BOUND_NEWS_EVENTS = B.load_bound_news_events
_BASE_VALIDATE_TRADE_SEMANTICS = B.validate_trade_semantics
_BASE_LAUNCH_PERSISTENT_TASK = B.launch_persistent_task
_BASE_POSTFLIGHT = B.postflight
_BASE_WORKER_RUN = B._worker_run


def _assert_exact_run_root(path: Path) -> Path:
    resolved = path.resolve()
    expected = ALLOWED_RUN_ROOT.resolve()
    if resolved != expected:
        raise B.InvalidEvidence(
            f"XAU run root must be the single frozen root {expected}: {resolved}"
        )
    return resolved


def _attempt001_control_paths() -> dict[str, Path]:
    return {
        "pre_receipt": ATTEMPT_001_PRE_RECEIPT_PATH,
        "authorization": ATTEMPT_001_AUTHORIZATION_PATH,
        "launch_job": ATTEMPT_001_JOB_PATH,
        "launch_state": ATTEMPT_001_STATE_PATH,
    }


def _probe_attempt001_task_absence() -> dict[str, Any]:
    command = [
        str(B.POWERSHELL_PATH.resolve()),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(B.SCHEDULED_TASK_HELPER_PATH.resolve()),
        "-Operation",
        "Probe",
        "-TaskName",
        ATTEMPT_001_TASK_NAME,
        "-PythonExe",
        str(B.PYTHON_PATH.resolve()),
        "-ToolPath",
        str(TOOL_PATH.resolve()),
        "-JobPath",
        str(ATTEMPT_001_JOB_PATH.resolve()),
        "-RepoRoot",
        str(REPO_ROOT.resolve()),
        "-ExecutionLimitSeconds",
        "241200",
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise B.InvalidEvidence(
            "ATTEMPT_001 scheduled-task absence probe failed closed"
        )
    payload = B._parse_last_json(completed.stdout)
    expected = {
        "operation": "Probe",
        "exists": False,
        "task_name": ATTEMPT_001_TASK_NAME,
        "task_path": "\\",
        "state": "Absent",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": 241200,
        "last_run_utc": None,
        "last_task_result": None,
    }
    drift = {
        key: (wanted, payload.get(key))
        for key, wanted in expected.items()
        if payload.get(key) != wanted
    }
    if drift:
        raise B.InvalidEvidence(
            f"ATTEMPT_001 scheduled task is not proved absent: {sorted(drift)}"
        )
    return payload


def _validate_attempt001_control_state(
    controls: Mapping[str, Mapping[str, Any]],
) -> None:
    state = B.load_json(Path(str(controls["launch_state"]["path"])))
    job = B.load_json(Path(str(controls["launch_job"]["path"])))
    cell_ids = [f"XAUUSD_DWX_{window.cell_id}" for window in B.WINDOWS]
    cells = state.get("cells")
    if (
        state.get("schema_version") != 1
        or state.get("artifact_type") != "QM5_13210_NATIVE_LAUNCH_STATE"
        or state.get("analysis_id") != ANALYSIS_ID
        or state.get("status") != "PENDING_SCHEDULED"
        or state.get("worker_pid") is not None
        or not isinstance(cells, list)
        or len(cells) != len(cell_ids)
    ):
        raise B.InvalidEvidence("ATTEMPT_001 control state is not pre-native")
    for expected_id, row in zip(cell_ids, cells, strict=True):
        if not isinstance(row, Mapping) or {
            "cell_id": row.get("cell_id"),
            "status": row.get("status"),
            "attempts": row.get("attempts"),
        } != {"cell_id": expected_id, "status": "PENDING", "attempts": []}:
            raise B.InvalidEvidence("ATTEMPT_001 cell contains a native start")
    launches = state.get("launches")
    if (
        not isinstance(launches, list)
        or len(launches) != 1
        or not isinstance(launches[0], Mapping)
        or launches[0].get("status") != "PREPARED"
        or launches[0].get("resume") is not False
        or "requested_utc" in launches[0]
    ):
        raise B.InvalidEvidence("ATTEMPT_001 launch advanced beyond PREPARED")
    if (
        state.get("pre_receipt_sha256")
        != "b7e6b6852f72c76cf87733e7f43563b7f5b20c9a222102cdf2a85d739809f8c2"
        or state.get("job") != controls["launch_job"]
        or job.get("pre_receipt_sha256") != state.get("pre_receipt_sha256")
        or Path(str(job.get("state_path", ""))).resolve()
        != ATTEMPT_001_STATE_PATH.resolve()
        or job.get("scheduler", {}).get("task_name") != ATTEMPT_001_TASK_NAME
        or job.get("scheduler", {}).get("helper")
        != {
            "path": str(B.SCHEDULED_TASK_HELPER_PATH.resolve()),
            "size": 9479,
            "sha256": "d81952ddc9d23b3d3d0e45de1a22bd2cf61336d4bb54b49babe03faf5a3b1443",
        }
    ):
        raise B.InvalidEvidence("ATTEMPT_001 launch-job/control binding drift")


def validate_attempt001_invalid_infrastructure_closure(
    path: Path = ATTEMPT_001_CLOSURE_PATH,
    *,
    probe_task_absence: bool = True,
) -> dict[str, Any]:
    payload = B.load_json(path)
    required_fields = {
        "schema_version",
        "artifact_type",
        "status",
        "analysis_id",
        "attempt_id",
        "classification",
        "closed_utc",
        "run_root",
        "control_bindings",
        "failure_evidence",
        "scheduled_task_absence",
        "native_start_proof",
        "outcome_fence",
        "recovery_contract",
    }
    if set(payload) != required_fields:
        raise B.InvalidEvidence("ATTEMPT_001 closure field closure drift")
    expected_semantics = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_ATTEMPT_INVALID_INFRASTRUCTURE_CLOSURE",
        "status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "analysis_id": ANALYSIS_ID,
        "attempt_id": "ATTEMPT_001",
        "classification": "SCHEDULER_HELPER_TASK_NAME_PATTERN_REJECTED_BEFORE_REGISTRATION",
        "run_root": str(ATTEMPT_001_RUN_ROOT.resolve()),
        "failure_evidence": {
            "failed_operation": "Register",
            "rejected_task_name": ATTEMPT_001_TASK_NAME,
            "helper_validate_pattern_at_failure": "^QM_QM13210_AUDIT_[0-9a-f]{24}$",
            "failed_helper_binding": {
                "path": str(B.SCHEDULED_TASK_HELPER_PATH.resolve()),
                "size": 9479,
                "sha256": "d81952ddc9d23b3d3d0e45de1a22bd2cf61336d4bb54b49babe03faf5a3b1443",
            },
            "task_registration_reached": False,
        },
        "scheduled_task_absence": {
            "observed_utc": "2026-07-21T08:55:59.5786415Z",
            "task_name": ATTEMPT_001_TASK_NAME,
            "task_path": "\\",
            "exists": False,
            "match_count": 0,
            "live_reprobe_required_before_attempt002_pre": True,
        },
        "native_start_proof": {
            "native_start_count": 0,
            "worker_pid": None,
            "cell_count": 4,
            "all_cell_statuses": "PENDING",
            "all_cell_attempt_lists_empty": True,
            "launch_status": "PENDING_SCHEDULED",
            "launch_audit_status": "PREPARED",
            "run_root_inventory": [
                "launch_job.json",
                "launch_state.json",
                "native_outcome_authorization.json",
                "pre_receipt.json",
            ],
            "native_directory_present": False,
            "native_reports_present": False,
            "outcome_artifacts_present": False,
        },
        "outcome_fence": {
            "native_reports_opened": False,
            "native_outcomes_opened": False,
            "controller_stdout_opened": False,
            "controller_stderr_opened": False,
            "closure_uses_control_files_and_filesystem_metadata_only": True,
        },
        "recovery_contract": {
            "attempt001_resume_forbidden": True,
            "attempt001_control_files_immutable": True,
            "single_authorized_alternate": "ATTEMPT_002",
            "attempt003_plus_forbidden": True,
            "strategy_or_parameter_change_forbidden": True,
        },
    }
    drift = {
        key: (wanted, payload.get(key))
        for key, wanted in expected_semantics.items()
        if payload.get(key) != wanted
    }
    if drift:
        raise B.InvalidEvidence(
            f"ATTEMPT_001 closure semantic drift: {sorted(drift)}"
        )
    B.parse_utc(str(payload.get("closed_utc", "")), "ATTEMPT_001 closed_utc")
    controls = payload.get("control_bindings")
    expected_paths = _attempt001_control_paths()
    if not isinstance(controls, Mapping) or set(controls) != set(expected_paths):
        raise B.InvalidEvidence("ATTEMPT_001 control-binding closure drift")
    for role, expected_path in expected_paths.items():
        row = controls.get(role)
        if (
            not isinstance(row, Mapping)
            or Path(str(row.get("path", ""))).resolve() != expected_path.resolve()
        ):
            raise B.InvalidEvidence(f"ATTEMPT_001 control path drift: {role}")
        B.assert_binding(row, f"ATTEMPT_001 immutable {role}")
    root = ATTEMPT_001_RUN_ROOT.resolve()
    inventory = sorted(item.name for item in root.iterdir()) if root.is_dir() else []
    if inventory != expected_semantics["native_start_proof"]["run_root_inventory"]:
        raise B.InvalidEvidence("ATTEMPT_001 run-root inventory drift")
    if any(not item.is_file() for item in root.iterdir()):
        raise B.InvalidEvidence("ATTEMPT_001 contains a native/output directory")
    _validate_attempt001_control_state(controls)
    if probe_task_absence:
        _probe_attempt001_task_absence()
    return {
        "binding": B.file_binding(path),
        "status": payload["status"],
        "control_bindings": {role: dict(row) for role, row in controls.items()},
        "native_start_count": 0,
        "task_absent": True,
    }


def _assert_no_sibling_or_prior_namespace() -> None:
    validate_attempt001_invalid_infrastructure_closure()
    family = RUN_FAMILY_ROOT.resolve()
    namespace = RUN_NAMESPACE_ROOT.resolve()
    exact = ALLOWED_RUN_ROOT.resolve()
    legacy = LEGACY_RUN_ROOT.resolve()
    if legacy.exists():
        raise B.InvalidEvidence(f"legacy/prior XAU run namespace exists: {legacy}")
    if family.is_dir():
        for child in family.iterdir():
            if "xau" in child.name.casefold() and child.resolve() != namespace:
                raise B.InvalidEvidence(
                    f"sibling/prior XAU run namespace exists: {child.resolve()}"
                )
    if namespace.is_dir():
        for child in namespace.iterdir():
            if child.resolve() not in {ATTEMPT_001_RUN_ROOT.resolve(), exact}:
                raise B.InvalidEvidence(
                    f"ATTEMPT_003+ or unregistered XAU attempt exists: {child.resolve()}"
                )


def _assert_pristine_one_shot_namespace() -> None:
    _assert_no_sibling_or_prior_namespace()
    exact = ALLOWED_RUN_ROOT.resolve()
    if exact.exists() and (not exact.is_dir() or any(exact.iterdir())):
        raise B.InvalidEvidence(f"ATTEMPT_002 alternate root is not pristine: {exact}")


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
    B.REQUIRED_BINDING_ROLES = frozenset(
        set(B.REQUIRED_BINDING_ROLES)
        | {"attempt001_closure", "base_tool", "xau_contract"}
    )
    B._assert_run_root = _assert_exact_run_root


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
    paths["attempt001_closure"] = ATTEMPT_001_CLOSURE_PATH
    paths["xau_contract"] = CONTRACT_PATH
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
        "adapter": TOOL_PATH,
        "attempt001_closure": ATTEMPT_001_CLOSURE_PATH,
        "base_tool": BASE_TOOL_PATH,
        "scheduled_task_helper": B.SCHEDULED_TASK_HELPER_PATH,
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
    return result


def _candidate_contract() -> dict[str, Any]:
    return {
        "ea_id": "QM5_13210",
        "strategy": "mulham-asian-sweep-london",
        "symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
        "parameter_tuning_forbidden": True,
        "separate_from_eurusd_outcome_namespace": True,
    }


def _lane_contract() -> dict[str, Any]:
    return {
        "terminal": "T1",
        "research_store": "T1_CUSTOM_SYMBOL_STORE",
        "namespace": ".DWX_RESEARCH_BACKTEST",
        "live_suffix_policy": "EXACT_ALIAS_XAUUSD_ONLY_NOT_EVALUATED_HERE",
        "live_parity_required": False,
        "deployment_routing_evaluated": False,
        "model4_real_ticks_required": True,
    }


def _window_contract() -> list[dict[str, Any]]:
    return [
        {
            "cell_id": window.cell_id,
            "cohort": window.cohort,
            "from_date": window.from_date.isoformat(),
            "to_date": window.to_date.isoformat(),
        }
        for window in B.WINDOWS
    ]


def _run_namespace_contract() -> dict[str, Any]:
    return {
        "family_root": str(RUN_FAMILY_ROOT.resolve()),
        "namespace_root": str(RUN_NAMESPACE_ROOT.resolve()),
        "primary_attempt001_root": str(ATTEMPT_001_RUN_ROOT.resolve()),
        "primary_attempt001_closure": str(ATTEMPT_001_CLOSURE_PATH.resolve()),
        "single_alternate_run_root": str(ATTEMPT_002_RUN_ROOT.resolve()),
        "legacy_root_forbidden": str(LEGACY_RUN_ROOT.resolve()),
        "attempt_id": "ATTEMPT_002",
        "attempt001_status_required": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "only_attempt_directories_allowed": ["ATTEMPT_001", "ATTEMPT_002"],
        "attempt003_plus_forbidden": True,
        "prior_xau_namespaces_forbidden": True,
        "resume_forbidden": True,
        "exact_control_paths": {
            "pre": str(ATTEMPT_002_PRE_RECEIPT_PATH.resolve()),
            "authorization": str(ATTEMPT_002_AUTHORIZATION_PATH.resolve()),
            "state": str(ATTEMPT_002_STATE_PATH.resolve()),
            "job": str(ATTEMPT_002_JOB_PATH.resolve()),
            "post": str(ATTEMPT_002_POST_RECEIPT_PATH.resolve()),
        },
    }


def _outcome_fence_contract() -> dict[str, bool]:
    return {
        "eurusd_native_outcomes_read_to_select_xau": False,
        "attempt001_native_outcomes_read": False,
        "xau_native_reports_opened": False,
        "xau_deal_rows_parsed": False,
        "mt5_terminal_started": False,
        "metatester_started": False,
    }


def _draft_contract_payload() -> dict[str, Any]:
    return {
        "schema_version": 3,
        "artifact_type": "QM5_13210_XAUUSD_OUTCOME_BLIND_ANALYSIS_CONTRACT",
        "status": "DRAFT_PENDING_ATTEMPT_002_FINAL_FREEZE",
        "analysis_id": ANALYSIS_ID,
        "candidate": _candidate_contract(),
        "lane_and_data": _lane_contract(),
        "windows": _window_contract(),
        "run_namespace": _run_namespace_contract(),
        "symbol_spec_contract": XAU_SYMBOL_SPEC_CONTRACT,
        "xau_calibration_projection": XAU_CALIBRATION_PROJECTION,
        "execution_cost_contract": MERIT_GATES["execution_cost_axes"],
        "merit_contract": MERIT_GATES,
        "outcome_fence": _outcome_fence_contract(),
        "infrastructure_alternate": {
            "cause": "ATTEMPT_001_HELPER_TASK_NAME_VALIDATE_PATTERN_BUG",
            "attempt001_pre_receipt_sha256": (
                "b7e6b6852f72c76cf87733e7f43563b7f5b20c9a222102cdf2a85d739809f8c2"
            ),
            "attempt001_native_start_count": 0,
            "attempt002_is_only_authorized_alternate": True,
            "same_build_data_parameters_windows_costs_and_gates": True,
            "parameter_tuning_forbidden": True,
            "attempt001_resume_forbidden": True,
            "attempt003_plus_forbidden": True,
            "frozen_input_bindings": ATTEMPT_002_INPUT_BINDINGS,
        },
        "finalization": {
            "required_command": (
                "audit_mulham_asian_sweep_london_xau.py finalize-contract "
                "--source-commit <40_HEX_BUILD_COMMIT>"
            ),
            "requires_committed_clean_adapter": True,
            "requires_committed_clean_source_artifacts": True,
            "requires_immutable_attempt001_infrastructure_closure": True,
            "requires_pristine_attempt002_namespace": True,
            "final_contract_must_bind_roles": sorted(FINAL_ARTIFACT_ROLES),
            "pre_and_launch_forbidden_until_status": "FINALIZED_OUTCOME_BLIND",
        },
    }


def validate_draft_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    payload = B.load_json(path)
    if payload != _draft_contract_payload():
        raise B.InvalidEvidence("XAU draft contract semantic closure drift")
    return payload


def _validate_bound_build_receipt(
    artifacts: Mapping[str, Mapping[str, Any]], source_commit: str
) -> dict[str, Any]:
    receipt = B.load_json(Path(str(artifacts["build_receipt"]["path"])))
    if (
        receipt.get("artifact_type") != "QM5_13210_BUILD_RECEIPT"
        or receipt.get("schema_version") != 1
        or receipt.get("ea_id") != "QM5_13210"
        or receipt.get("build_check_passed") is not True
        or receipt.get("compile_succeeded") is not True
        or receipt.get("compile_errors") != 0
        or receipt.get("compile_warnings") != 0
        or receipt.get("build_commit") != source_commit
    ):
        raise B.InvalidEvidence("XAU bound build receipt is not the exact clean source build")
    expected = {
        "source_sha256": artifacts["mq5"]["sha256"],
        "ex5_sha256": artifacts["ex5"]["sha256"],
        "spec_sha256": artifacts["spec"]["sha256"],
        "card_sha256": artifacts["card"]["sha256"],
    }
    if any(str(receipt.get(key, "")).lower() != value for key, value in expected.items()):
        raise B.InvalidEvidence("XAU build receipt artifact hashes drift from final contract")
    set_hashes = receipt.get("setfile_sha256")
    if (
        not isinstance(set_hashes, Mapping)
        or str(set_hashes.get(RESEARCH_SYMBOL, "")).lower()
        != artifacts["set"]["sha256"]
    ):
        raise B.InvalidEvidence("XAU build receipt set hash drifts from final contract")
    compile_evidence = receipt.get("compile_evidence")
    if not isinstance(compile_evidence, Mapping) or not compile_evidence:
        raise B.InvalidEvidence("XAU build receipt compile evidence is missing")
    for role, row in compile_evidence.items():
        if not isinstance(row, Mapping):
            raise B.InvalidEvidence(f"XAU compile evidence malformed: {role}")
        B.assert_binding(row, f"XAU finalized compile evidence {role}")
    return receipt


def _activate_finalized_contract(contract: Mapping[str, Any]) -> None:
    artifacts = contract["artifact_bindings"]
    receipt = _validate_bound_build_receipt(
        artifacts, str(contract["source_build_commit"])
    )
    B.EXPECTED_BUILD_HASHES = {
        role: str(artifacts[role]["sha256"])
        for role in ("card", "spec", "mq5", "ex5", "set")
    }
    B.EXPECTED_BUILD_COMMIT = str(contract["source_build_commit"])
    B.EXPECTED_COMPILE_EVIDENCE = {
        role: {
            "path": Path(str(row["path"])).resolve(),
            "size": int(row["size"]),
            "sha256": str(row["sha256"]).lower(),
        }
        for role, row in receipt["compile_evidence"].items()
    }


def validate_analysis_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected_fields = {
        "schema_version",
        "artifact_type",
        "status",
        "finalized_utc",
        "analysis_id",
        "source_build_commit",
        "candidate",
        "lane_and_data",
        "windows",
        "run_namespace",
        "symbol_spec_contract",
        "xau_calibration_projection",
        "artifact_bindings",
        "execution_cost_contract",
        "merit_contract",
        "outcome_fence",
        "infrastructure_alternate",
    }
    if set(payload) != expected_fields:
        raise B.InvalidEvidence("XAU analysis-contract field closure drift; finalize required")
    if (
        payload.get("schema_version") != 3
        or payload.get("artifact_type")
        != "QM5_13210_XAUUSD_OUTCOME_BLIND_ANALYSIS_CONTRACT"
        or payload.get("status") != "FINALIZED_OUTCOME_BLIND"
        or payload.get("analysis_id") != ANALYSIS_ID
    ):
        raise B.InvalidEvidence("XAU analysis contract is not finalized; PRE is forbidden")
    finalized = B.parse_utc(
        str(payload.get("finalized_utc", "")), "XAU contract finalized_utc"
    )
    if finalized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("XAU contract finalization time is implausibly in the future")
    source_commit = str(payload.get("source_build_commit", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise B.InvalidEvidence("XAU source-build commit must be lowercase full SHA-1")
    semantic_expected = {
        "candidate": _candidate_contract(),
        "lane_and_data": _lane_contract(),
        "windows": _window_contract(),
        "run_namespace": _run_namespace_contract(),
        "symbol_spec_contract": XAU_SYMBOL_SPEC_CONTRACT,
        "xau_calibration_projection": XAU_CALIBRATION_PROJECTION,
        "execution_cost_contract": MERIT_GATES["execution_cost_axes"],
        "merit_contract": MERIT_GATES,
        "outcome_fence": _outcome_fence_contract(),
        "infrastructure_alternate": _draft_contract_payload()[
            "infrastructure_alternate"
        ],
    }
    drift = {
        key: (wanted, payload.get(key))
        for key, wanted in semantic_expected.items()
        if payload.get(key) != wanted
    }
    if drift:
        raise B.InvalidEvidence(f"XAU finalized contract semantic drift: {sorted(drift)}")
    artifacts = _validate_contract_artifact_bindings(payload.get("artifact_bindings"))
    validate_attempt001_invalid_infrastructure_closure()
    _validate_bound_build_receipt(artifacts, source_commit)
    _activate_finalized_contract({**payload, "artifact_bindings": artifacts})
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "source_build_commit": source_commit,
        "artifact_bindings": artifacts,
        "symbol_spec_contract": payload["symbol_spec_contract"],
        "xau_calibration_projection": payload["xau_calibration_projection"],
        "execution_cost_contract": payload["execution_cost_contract"],
        "merit_contract": payload["merit_contract"],
        "infrastructure_alternate": payload["infrastructure_alternate"],
    }


def _git_run(arguments: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
    )


def _repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError as exc:
        raise B.InvalidEvidence(f"finalized artifact is outside repository: {path}") from exc


def _assert_source_freeze_ready(source_commit: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise B.InvalidEvidence("finalize requires a lowercase full 40-hex source commit")
    resolved = _git_run(["rev-parse", "--verify", f"{source_commit}^{{commit}}"])
    if resolved.returncode != 0 or resolved.stdout.strip().lower() != source_commit:
        raise B.InvalidEvidence("finalize source commit does not resolve exactly")
    ancestor = _git_run(["merge-base", "--is-ancestor", source_commit, "HEAD"])
    if ancestor.returncode != 0:
        raise B.InvalidEvidence("finalize source commit is not an ancestor of HEAD")

    paths = _artifact_contract_paths()
    repo_paths = [
        _repo_relative(path)
        for path in [*paths.values(), CONTRACT_PATH]
        if path.resolve().is_relative_to(REPO_ROOT.resolve())
    ]
    status = _git_run(
        ["status", "--porcelain=v1", "--untracked-files=all", "--", *repo_paths]
    )
    if status.returncode != 0 or status.stdout.strip():
        raise B.InvalidEvidence(
            "finalize requires committed clean source, receipt, adapter, base tool and draft"
        )
    for role in ("mq5", "ex5", "spec", "set"):
        relative = _repo_relative(paths[role])
        diff = _git_run(["diff", "--quiet", source_commit, "--", relative])
        if diff.returncode != 0:
            raise B.InvalidEvidence(
                f"finalize artifact does not match source build commit: {role}"
            )


def _assert_finalized_contract_committed() -> None:
    relative = _repo_relative(CONTRACT_PATH)
    tracked = _git_run(["ls-files", "--error-unmatch", "--", relative])
    status = _git_run(
        ["status", "--porcelain=v1", "--untracked-files=all", "--", relative]
    )
    if tracked.returncode != 0 or status.returncode != 0 or status.stdout.strip():
        raise B.InvalidEvidence(
            "PRE requires the finalized XAU contract to be committed and clean"
        )


def _finalized_contract_payload(
    source_commit: str,
    finalized_utc: str,
    artifact_bindings: Mapping[str, Mapping[str, Any]],
) -> dict[str, Any]:
    return {
        "schema_version": 3,
        "artifact_type": "QM5_13210_XAUUSD_OUTCOME_BLIND_ANALYSIS_CONTRACT",
        "status": "FINALIZED_OUTCOME_BLIND",
        "finalized_utc": finalized_utc,
        "analysis_id": ANALYSIS_ID,
        "source_build_commit": source_commit,
        "candidate": _candidate_contract(),
        "lane_and_data": _lane_contract(),
        "windows": _window_contract(),
        "run_namespace": _run_namespace_contract(),
        "symbol_spec_contract": XAU_SYMBOL_SPEC_CONTRACT,
        "xau_calibration_projection": XAU_CALIBRATION_PROJECTION,
        "artifact_bindings": {
            role: dict(artifact_bindings[role]) for role in sorted(FINAL_ARTIFACT_ROLES)
        },
        "execution_cost_contract": MERIT_GATES["execution_cost_axes"],
        "merit_contract": MERIT_GATES,
        "outcome_fence": _outcome_fence_contract(),
        "infrastructure_alternate": _draft_contract_payload()[
            "infrastructure_alternate"
        ],
    }


def finalize_analysis_contract(source_commit: str) -> dict[str, Any]:
    validate_draft_contract(CONTRACT_PATH)
    _assert_pristine_one_shot_namespace()
    _assert_source_freeze_ready(source_commit)
    artifacts = {
        role: B.file_binding(path)
        for role, path in _artifact_contract_paths().items()
    }
    _validate_bound_build_receipt(artifacts, source_commit)
    payload = _finalized_contract_payload(source_commit, B.utc_now(), artifacts)
    digest = B.atomic_json(CONTRACT_PATH, payload, replace=True)
    validated = validate_analysis_contract(CONTRACT_PATH)
    if validated["binding"]["sha256"] != digest:
        raise B.InvalidEvidence("finalized XAU contract write/binding drift")
    return validated


def _load_slippage_proxy(projection: Mapping[str, Any] | None = None) -> dict[str, Any]:
    payload = (
        dict(projection)
        if projection is not None
        else dict(validate_analysis_contract()["xau_calibration_projection"])
    )
    if payload != XAU_CALIBRATION_PROJECTION:
        raise B.InvalidEvidence("XAU-only calibration projection contract drift")
    return {
        "classification": "FACTORY_AUTO_STUB_PROXY_NOT_XAU_LIVE_FILL_MEASUREMENT",
        "projection_sha256": B.canonical_sha256(payload),
        "points_axis_per_side": ["1", "3"],
        "spread_reference_points": {"median": "20", "p95": "60"},
        "latency_reference_ms": {"avg": "50", "p95": "120"},
    }


def resolve_cost_schedule(
    path: Path,
    symbol: str,
    live_commission_path: Path = B.LIVE_COMMISSION_PATH,
    calibration_projection: Mapping[str, Any] | None = None,
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
    proxy = _load_slippage_proxy(calibration_projection)
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


def validate_trade_semantics(
    trades: Sequence[Any], news_events: Sequence[Any]
) -> dict[str, Any]:
    if any(event.currency != "USD" or event.impact != "HIGH" for event in news_events):
        raise B.InvalidEvidence("XAU semantic audit accepts only bound USD high-impact events")
    receipt = _BASE_VALIDATE_TRADE_SEMANTICS(trades, news_events)
    if receipt.pop("no_fill_inside_bound_eur_usd_high_impact_blackout", None) is not True:
        raise B.InvalidEvidence("base news-semantic receipt drift")
    receipt["no_fill_inside_bound_usd_high_impact_blackout"] = True
    return receipt


def _contract_receipt() -> dict[str, Any]:
    return validate_analysis_contract(CONTRACT_PATH)


def _assert_exact_control_path(path: Path, expected: Path, label: str) -> Path:
    resolved = path.resolve()
    if resolved != expected.resolve():
        raise B.InvalidEvidence(
            f"ATTEMPT_002 {label} must be {expected.resolve()}: {resolved}"
        )
    return resolved


def preflight(
    symbol: str,
    research_readiness_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    closure = validate_attempt001_invalid_infrastructure_closure()
    _assert_pristine_one_shot_namespace()
    _assert_exact_run_root(run_root)
    exact_inputs = {
        "research_readiness_receipt": research_readiness_receipt_path,
        "data_manifest": data_manifest_path,
    }
    for role, observed_path in exact_inputs.items():
        expected = ATTEMPT_002_INPUT_BINDINGS[role]
        if observed_path.resolve() != Path(str(expected["path"])).resolve():
            raise B.InvalidEvidence(f"ATTEMPT_002 {role} path drift")
        B.file_binding(observed_path, str(expected["sha256"]))
        if observed_path.stat().st_size != int(expected["size"]):
            raise B.InvalidEvidence(f"ATTEMPT_002 {role} size drift")
    if build_receipt_path.resolve() != BUILD_RECEIPT_PATH.resolve():
        raise B.InvalidEvidence("XAU PRE requires the exact bound build receipt path")
    contract = _contract_receipt()
    _assert_finalized_contract_committed()
    pre = _BASE_PREFLIGHT(
        symbol,
        research_readiness_receipt_path,
        data_manifest_path,
        build_receipt_path,
        run_root,
    )
    final_role_map = {
        "tool": "adapter",
        "scheduled_task_helper": "scheduled_task_helper",
        "attempt001_closure": "attempt001_closure",
    }
    for pre_role, contract_role in final_role_map.items():
        if pre["bindings"].get(pre_role) != contract["artifact_bindings"].get(
            contract_role
        ):
            raise B.InvalidEvidence(
                f"PRE {pre_role} binding differs from finalized XAU contract"
            )
    if pre.get("cost_schedule") != ATTEMPT_002_COST_SCHEDULE:
        raise B.InvalidEvidence("ATTEMPT_002 cost schedule differs from ATTEMPT_001")
    pre["attempt001_invalid_infrastructure_closure"] = closure
    pre["attempt_id"] = "ATTEMPT_002"
    pre["infrastructure_alternate"] = contract["infrastructure_alternate"]
    pre["xau_preregistration"] = contract
    return pre


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_exact_control_path(path, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt")
    expected = _contract_receipt()
    _assert_finalized_contract_committed()
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    final_role_map = {
        "tool": "adapter",
        "scheduled_task_helper": "scheduled_task_helper",
        "attempt001_closure": "attempt001_closure",
    }
    for pre_role, contract_role in final_role_map.items():
        if pre["bindings"].get(pre_role) != expected["artifact_bindings"].get(
            contract_role
        ):
            raise B.InvalidEvidence(
                f"PRE no longer binds finalized {contract_role} bytes"
            )
    if pre.get("xau_preregistration") != expected:
        raise B.InvalidEvidence("PRE XAU preregistration binding drift")
    closure = validate_attempt001_invalid_infrastructure_closure()
    if pre.get("attempt001_invalid_infrastructure_closure") != closure:
        raise B.InvalidEvidence("PRE ATTEMPT_001 closure binding drift")
    if (
        pre.get("attempt_id") != "ATTEMPT_002"
        or pre.get("infrastructure_alternate")
        != expected["infrastructure_alternate"]
        or pre.get("cost_schedule") != ATTEMPT_002_COST_SCHEDULE
    ):
        raise B.InvalidEvidence("PRE ATTEMPT_002 invariant drift")
    _assert_no_sibling_or_prior_namespace()
    return pre


def validate_authorization(
    path: Path,
    pre_sha256: str,
    *,
    require_current: bool = True,
    now: datetime | None = None,
) -> dict[str, Any]:
    _assert_exact_control_path(
        path, ATTEMPT_002_AUTHORIZATION_PATH, "native authorization"
    )
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


def launch_persistent_task(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    if resume:
        raise B.AuthorizationError("ATTEMPT_002 is one-shot; resume is forbidden")
    _assert_exact_control_path(pre_path, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(
        authorization_path,
        ATTEMPT_002_AUTHORIZATION_PATH,
        "native authorization",
    )
    _assert_exact_control_path(state_path, ATTEMPT_002_STATE_PATH, "launch state")
    validate_attempt001_invalid_infrastructure_closure()
    return _BASE_LAUNCH_PERSISTENT_TASK(
        pre_path,
        pre_sha256,
        authorization_path,
        state_path,
        resume=False,
    )


def postflight(
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
) -> dict[str, Any]:
    _assert_exact_control_path(pre_path, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(state_path, ATTEMPT_002_STATE_PATH, "launch state")
    validate_attempt001_invalid_infrastructure_closure()
    return _BASE_POSTFLIGHT(pre_path, pre_sha256, state_path)


def _worker_run(job_path: Path) -> int:
    _assert_exact_control_path(job_path, ATTEMPT_002_JOB_PATH, "launch job")
    validate_attempt001_invalid_infrastructure_closure()
    return _BASE_WORKER_RUN(job_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    finalize = sub.add_parser(
        "finalize-contract",
        help="Freeze committed source/adapter bytes before any PRE or native launch",
    )
    finalize.add_argument("--source-commit", required=True)
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
    launch.set_defaults(resume=False)
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
B.validate_trade_semantics = validate_trade_semantics
B.preflight = preflight
B.assert_pre_receipt = assert_pre_receipt
B.validate_authorization = validate_authorization
B.launch_persistent_task = launch_persistent_task
B.postflight = postflight
B._worker_run = _worker_run
B.build_parser = build_parser
B._assert_run_root = _assert_exact_run_root

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
    enforce_symbol_policy(symbol)
    _assert_exact_run_root(run_root)
    return B.build_plan(symbol, set_binding, run_root)


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    return B.runner_command(pre, cell)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(argv) if argv is not None else sys.argv[1:]
    args = build_parser().parse_args(arguments)
    if arguments and arguments[0] == "finalize-contract":
        try:
            receipt = finalize_analysis_contract(args.source_commit)
            print(
                json.dumps(
                    {
                        "status": "FINALIZED_OUTCOME_BLIND",
                        "contract": str(CONTRACT_PATH.resolve()),
                        "sha256": receipt["binding"]["sha256"],
                        "source_build_commit": receipt["source_build_commit"],
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        except (B.AuditError, OSError, ValueError, KeyError, TypeError) as exc:
            print(
                json.dumps(B.invalid_receipt("FINALIZE_CONTRACT", exc), sort_keys=True),
                file=sys.stderr,
            )
            return 2
    try:
        if args.command == "pre":
            _assert_exact_control_path(
                args.receipt, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt"
            )
        elif args.command == "launch":
            _assert_exact_control_path(
                args.pre_receipt, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt"
            )
            _assert_exact_control_path(
                args.authorization,
                ATTEMPT_002_AUTHORIZATION_PATH,
                "native authorization",
            )
            _assert_exact_control_path(
                args.state, ATTEMPT_002_STATE_PATH, "launch state"
            )
        elif args.command == "post":
            _assert_exact_control_path(
                args.pre_receipt, ATTEMPT_002_PRE_RECEIPT_PATH, "PRE receipt"
            )
            _assert_exact_control_path(
                args.state, ATTEMPT_002_STATE_PATH, "launch state"
            )
            _assert_exact_control_path(
                args.receipt, ATTEMPT_002_POST_RECEIPT_PATH, "POST receipt"
            )
        elif args.command == "status":
            _assert_exact_control_path(
                args.state, ATTEMPT_002_STATE_PATH, "launch state"
            )
        elif args.command == "_run-plan":
            _assert_exact_control_path(
                args.job, ATTEMPT_002_JOB_PATH, "launch job"
            )
    except B.AuditError as exc:
        print(
            json.dumps(B.invalid_receipt(args.command.upper(), exc), sort_keys=True),
            file=sys.stderr,
        )
        return 2
    return B.main(arguments)


def __getattr__(name: str) -> Any:
    return getattr(B, name)


if __name__ == "__main__":
    raise SystemExit(main())
