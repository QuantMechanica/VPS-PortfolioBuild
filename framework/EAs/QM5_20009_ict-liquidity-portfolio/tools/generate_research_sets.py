"""Generate the deterministic Freeze-v3 center/OAAT bundle for QM5_20009.

The detached ``manifest.sha256`` is the only object that hashes ``manifest.json``.
The manifest therefore never hashes itself.  Every set embeds a canonical
``freeze_inputs_sha256`` over sources, transitive framework includes, compile
evidence, data identities, news, costs, tester defaults and registries.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable, Mapping


EA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = EA_ROOT.parents[2]
SETS_ROOT = EA_ROOT / "sets"
EA_SOURCE = EA_ROOT / "QM5_20009_ict-liquidity-portfolio.mq5"
RULES_SOURCE = EA_ROOT / "ICT_LiquidityRules.mqh"
CONTRACT = EA_ROOT / "docs" / "strategy_contract.md"
SPEC = EA_ROOT / "SPEC.md"
PROTOCOL = EA_ROOT / "docs" / "research_protocol_v3.json"
GENERATOR = Path(__file__).resolve()
VALIDATOR = EA_ROOT / "tools" / "validate_research_run.py"
AUDITOR = EA_ROOT / "tools" / "audit_mt5_report.py"
RESEARCH_LAUNCHER = EA_ROOT / "tools" / "run_research_phase.ps1"
RESEARCH_LAUNCHER_SUPPORT = EA_ROOT / "tools" / "research_launcher_support.psm1"
FRAMEWORK_INCLUDE_ROOT = REPO_ROOT / "framework" / "include"

MAGIC_RESOLVER_PATH = "framework/include/QM/QM_MagicResolver.mqh"
MAGIC_RESOLVER_RELATIVE = "qm/qm_magicresolver.mqh"
TARGET_MAGIC_ROWS = (
    (20009, 0, "NDX.DWX", 200090000),
    (20009, 1, "GDAXI.DWX", 200090001),
    (20009, 2, "GBPUSD.DWX", 200090002),
    (20009, 3, "USDJPY.DWX", 200090003),
    (20009, 4, "XAUUSD.DWX", 200090004),
    (20009, 5, "EURUSD.DWX", 200090005),
)
EXPECTED_MAGIC_EXCEPTION = {
    "path": MAGIC_RESOLVER_PATH,
    "compiled_git_blob_sha1": "5dd52ece69ffe2c86135a30f5044899b0c080e8e",
    "compiled_sha256": "0c1dade22f9427d881f121f9b8a9dca1e5f38204d661a439b415aeba501157be",
    "policy": "EXACT_COMPILED_PREFIX_PLUS_COLLISION_FREE_FOREIGN_EA_APPEND_ONLY",
    "target_ea_id": 20009,
    "target_rows": [list(row) for row in TARGET_MAGIC_ROWS],
    "dynamic_git_head_dependency": False,
}

MARKETS = (
    ("NDX.DWX", "M1", 0, 0, "index"),
    ("GDAXI.DWX", "M1", 1, 0, "index"),
    ("GBPUSD.DWX", "M5", 2, 1, "fx"),
    ("EURUSD.DWX", "M5", 5, 1, "fx"),
)

A_CENTER = {
    "strategy_a_pivot_wing": "2",
    "strategy_a_reclaim_bars": "3",
    "strategy_a_max_bars_to_mss": "9",
    "strategy_a_min_fvg_atr": "0.05",
    "strategy_a_sl_buffer_atr": "0.10",
    "strategy_a_min_rr": "2.0",
}
B_CENTER = {
    "strategy_b_pivot_wing": "2",
    "strategy_b_reclaim_bars": "3",
    "strategy_b_max_bars_to_mss": "12",
    "strategy_b_min_fvg_atr": "0.05",
    "strategy_b_sl_buffer_atr": "0.10",
    "strategy_b_min_rr": "2.0",
}
STARS = {
    "index": (
        ("pivot_low", "strategy_a_pivot_wing", "1"),
        ("pivot_high", "strategy_a_pivot_wing", "3"),
        ("reclaim_low", "strategy_a_reclaim_bars", "1"),
        ("reclaim_high", "strategy_a_reclaim_bars", "5"),
        ("mss_low", "strategy_a_max_bars_to_mss", "6"),
        ("mss_high", "strategy_a_max_bars_to_mss", "12"),
        ("fvg_low", "strategy_a_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_a_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_a_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_a_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_a_min_rr", "1.5"),
        ("rr_high", "strategy_a_min_rr", "2.5"),
    ),
    "fx": (
        ("pivot_low", "strategy_b_pivot_wing", "1"),
        ("pivot_high", "strategy_b_pivot_wing", "3"),
        ("reclaim_low", "strategy_b_reclaim_bars", "1"),
        ("reclaim_high", "strategy_b_reclaim_bars", "5"),
        ("mss_low", "strategy_b_max_bars_to_mss", "6"),
        ("mss_high", "strategy_b_max_bars_to_mss", "18"),
        ("fvg_low", "strategy_b_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_b_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_b_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_b_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_b_min_rr", "1.5"),
        ("rr_high", "strategy_b_min_rr", "2.5"),
    ),
}

INCLUDE_RE = re.compile(r'^\s*#include\s*[<"]([^>"]+)[>"]', re.MULTILINE)
INPUT_RE = re.compile(r"^\s*input\s+(?!group\b)\S+\s+(\w+)\s*=", re.MULTILINE)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class FreezeError(RuntimeError):
    """The requested bundle is not fully evidenced and must not be generated."""


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def _read_source(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _decode_evidence_text(payload: bytes) -> str:
    if payload.startswith((b"\xff\xfe", b"\xfe\xff")):
        return payload.decode("utf-16")
    return payload.decode("utf-8-sig")


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _resolve_include(owner: Path, raw_include: str) -> Path | None:
    include = raw_include.replace("\\", "/")
    candidates = (owner.parent / include, FRAMEWORK_INCLUDE_ROOT / include)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


@lru_cache(maxsize=1)
def repo_include_closure() -> tuple[tuple[Path, ...], tuple[str, ...]]:
    """Return every resolvable repo include reached by the EA, plus externals.

    Local strategy includes are deliberately part of this closure.  Treating the
    rules file as a separately hashed leaf would miss inputs (or further local
    includes) introduced below it.
    """

    visited: set[Path] = set()
    external: set[str] = set()

    def scan(owner: Path) -> None:
        for raw_include in INCLUDE_RE.findall(_read_source(owner)):
            target = _resolve_include(owner, raw_include)
            if target is None:
                external.add(raw_include.replace("\\", "/"))
                continue
            if not _is_within(target, REPO_ROOT):
                external.add(raw_include.replace("\\", "/"))
                continue
            if target in visited:
                continue
            visited.add(target)
            scan(target)

    scan(EA_SOURCE)
    return (
        tuple(sorted(visited, key=lambda item: item.as_posix().lower())),
        tuple(sorted(external)),
    )


@lru_cache(maxsize=1)
def framework_include_closure() -> tuple[list[dict[str, object]], list[str]]:
    """Return every transitive framework include reached by the EA."""

    visited, external = repo_include_closure()
    rows = [
        {
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        for path in visited
        if _is_within(path, FRAMEWORK_INCLUDE_ROOT)
    ]
    return rows, list(external)


@lru_cache(maxsize=1)
def local_strategy_include_closure() -> list[dict[str, object]]:
    """Return transitive repo includes outside the shared framework tree."""

    visited, _external = repo_include_closure()
    return [
        {
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        for path in visited
        if not _is_within(path, FRAMEWORK_INCLUDE_ROOT)
    ]


@lru_cache(maxsize=1)
def visible_input_names() -> list[str]:
    sources = [EA_SOURCE]
    includes, _external = repo_include_closure()
    sources.extend(includes)
    names: list[str] = []
    for source in sources:
        names.extend(INPUT_RE.findall(_read_source(source)))
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise FreezeError(f"duplicate visible input declarations: {','.join(duplicates)}")
    return names


def load_protocol(path: Path = PROTOCOL) -> dict[str, Any]:
    try:
        protocol = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise FreezeError(f"research protocol unreadable: {path}: {exc}") from exc
    validate_protocol(protocol)
    return protocol


def _parse_iso_date(value: object, label: str) -> date:
    try:
        return date.fromisoformat(str(value))
    except ValueError as exc:
        raise FreezeError(f"invalid {label}: {value!r}") from exc


def validate_protocol(protocol: Mapping[str, Any]) -> None:
    if protocol.get("schema_version") != 2 or protocol.get("ea_id") != 20009:
        raise FreezeError("research protocol schema/EA identity mismatch")
    markets = protocol.get("markets")
    if not isinstance(markets, list):
        raise FreezeError("research protocol markets must be a list")
    observed = tuple(
        (
            item.get("symbol"),
            item.get("timeframe"),
            item.get("slot"),
            item.get("mode"),
            item.get("kind"),
        )
        for item in markets
    )
    if observed != MARKETS:
        raise FreezeError(f"research protocol markets drifted: {observed!r}")
    expected_dev_windows = {
        "NDX.DWX": ("2021-01-01", "2022-12-31"),
        "GDAXI.DWX": ("2021-01-01", "2022-12-31"),
        "GBPUSD.DWX": ("2017-10-01", "2022-12-31"),
        "EURUSD.DWX": ("2017-10-01", "2022-12-31"),
    }
    for market in markets:
        start = _parse_iso_date(market.get("dev_from"), f"{market.get('symbol')} DEV from")
        end = _parse_iso_date(market.get("dev_to"), f"{market.get('symbol')} DEV to")
        if start > end or end >= date(2023, 1, 1):
            raise FreezeError(f"invalid DEV partition for {market.get('symbol')}")
        if (market.get("dev_from"), market.get("dev_to")) != expected_dev_windows[market["symbol"]]:
            raise FreezeError(f"DEV partition drifted for {market.get('symbol')}")
    fx_starts = {item["dev_from"] for item in markets if item["kind"] == "fx"}
    if fx_starts != {"2017-10-01"}:
        raise FreezeError("FX DEV must start at honest Model-4 coverage 2017-10-01")

    phases = protocol.get("phases")
    if not isinstance(phases, list):
        raise FreezeError("research protocol phases must be a list")
    ids = [str(item.get("id")) for item in phases]
    required_ids = {
        "DEV",
        "DEV_SMOKE_2022",
        "OOS_2023_H1",
        "OOS_2023_H2",
        "OOS_2024_H1",
        "OOS_2024_H2",
        "OOS_2025_H1",
        "OOS_2025_H2",
        "RETRO_HOLDOUT_2026_H1",
        "PROSPECTIVE_OPERATIONAL",
    }
    if set(ids) != required_ids or len(ids) != len(set(ids)):
        raise FreezeError("research protocol phase set is incomplete or duplicated")
    expected_later_phases = {
        "OOS_2023_H1": ("OOS", "2023-01-01", "2023-06-30", 2),
        "OOS_2023_H2": ("OOS", "2023-07-01", "2023-12-31", 2),
        "OOS_2024_H1": ("OOS", "2024-01-01", "2024-06-30", 2),
        "OOS_2024_H2": ("OOS", "2024-07-01", "2024-12-31", 2),
        "OOS_2025_H1": ("OOS", "2025-01-01", "2025-06-30", 2),
        "OOS_2025_H2": ("OOS", "2025-07-01", "2025-12-31", 2),
        "RETRO_HOLDOUT_2026_H1": (
            "RETROSPECTIVE_HOLDOUT", "2026-01-01", "2026-06-30", 2
        ),
        "PROSPECTIVE_OPERATIONAL": (
            "PROSPECTIVE_FORWARD_OBSERVATION", "2026-07-20", "2027-07-17", 1
        ),
    }
    for phase in phases:
        if phase.get("id") == "DEV":
            if (
                phase.get("class") != "DEV"
                or phase.get("window") != "PER_MARKET_DEV"
                or phase.get("allowed_variants") != "ALL_13"
                or phase.get("duplicates") != 2
                or phase.get("requires_resolved_cost_axes") is not False
            ):
                raise FreezeError("DEV must allow the complete 13-point OAAT star")
            continue
        if phase.get("id") == "DEV_SMOKE_2022":
            expected_smoke = {
                "class": "DIAGNOSTIC_SMOKE",
                "from": "2022-01-01",
                "to": "2022-12-31",
                "allowed_symbols": ["NDX.DWX", "GBPUSD.DWX"],
                "allowed_variants": "CENTER_ONLY",
                "duplicates": 1,
                "minimum_trades": 0,
                "requires_resolved_cost_axes": False,
                "nonbinding": True,
                "may_satisfy_phase_verdict_gate": False,
            }
            if any(phase.get(key) != value for key, value in expected_smoke.items()):
                raise FreezeError("DEV_SMOKE_2022 diagnostic contract drifted")
            continue
        if phase.get("allowed_variants") != "CENTER_ONLY":
            raise FreezeError(f"later phase is not center-only: {phase.get('id')}")
        if not phase.get("requires_resolved_cost_axes"):
            raise FreezeError(f"later phase omits cost-resolution fence: {phase.get('id')}")
        expected_phase = expected_later_phases[str(phase.get("id"))]
        observed_phase = (
            phase.get("class"), phase.get("from"), phase.get("to"), phase.get("duplicates")
        )
        if observed_phase != expected_phase:
            raise FreezeError(f"later phase partition/class drifted: {phase.get('id')}")
        if phase.get("id") == "RETRO_HOLDOUT_2026_H1" and phase.get("epistemic_status") != (
            "RETROSPECTIVE_NOT_PRISTINE"
        ):
            raise FreezeError("retrospective holdout epistemic status drifted")
        if phase.get("id") == "RETRO_HOLDOUT_2026_H1" and phase.get("data_availability") != (
            "BLOCKED_MISSING_VERIFIED_MODEL4_TICKS_202605_202606"
        ):
            raise FreezeError("retrospective holdout data-availability blocker drifted")
        if phase.get("id") == "PROSPECTIVE_OPERATIONAL" and phase.get("execution_kind") != (
            "FORWARD_ONLY_NOT_RETROSPECTIVE_BACKTEST"
        ):
            raise FreezeError("prospective phase must remain forward-only")
        _parse_iso_date(phase.get("from"), f"{phase.get('id')} from")
        _parse_iso_date(phase.get("to"), f"{phase.get('id')} to")

    tester = protocol.get("tester")
    if not isinstance(tester, Mapping) or tester.get("visible_input_count") != 35:
        raise FreezeError("tester visible_input_count must be 35")
    expected_tester = {
        "model": 4,
        "execution_mode": 0,
        "optimization": 0,
        "initial_deposit": 100000,
        "deposit_currency": "USD",
        "leverage": 100,
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "rng_seed": 42,
        "duplicate_policy": "IDENTICAL_BINARY_INPUTS_DATA_ENVIRONMENT_AND_SEED",
    }
    if any(tester.get(key) != value for key, value in expected_tester.items()):
        raise FreezeError("tester execution defaults drifted")
    if tester.get("framework_inputs") != {
        "InpQMSimCommissionPerLot": 0.0,
        "qm_chartui_enabled": False,
        "qm_chartui_corner": 0,
    }:
        raise FreezeError("tester framework input freeze drifted")
    if tester.get("chartui_override_reason") != (
        "DISABLED_IN_NONVISUAL_TESTER_FOR_PERFORMANCE; "
        "NO_SIGNAL_OR_EXECUTION_SEMANTICS"
    ):
        raise FreezeError("tester chart UI override is not explicitly justified")
    if tester.get("commission_injection") != (
        "RAW_TESTER_COMMISSION_ZERO; RUNNER_COMMISSION_OVERRIDES_ZERO; "
        "EA_SIM_COMMISSION_ZERO; AUTHORITATIVE_EXTERNAL_DEAL_AUDIT"
    ):
        raise FreezeError("tester commission application contract drifted")

    model4 = protocol.get("model4_data")
    expected_model4 = {
        "provisioning_manifest_artifact_id": "provisioning_tick_hash_manifest",
        "destination_root": "D:/QM/mt5/DEV1/Bases",
        "symbol_definition_relative_path": "symbols.custom.dat",
        "history_extension": ".hcc",
        "tick_extension": ".tkc",
        "frozen_through_month": "202604",
        "exclude_months": ["202605", "202606", "202607"],
        "manifest_match_required": True,
        "preflight_rehash_selected_phase_files": True,
        "postflight_rehash_selected_phase_files": True,
    }
    if model4 != expected_model4:
        raise FreezeError("Model-4 provisioning/fence contract drifted")
    if protocol.get("compiled_source_snapshot_exceptions") != [EXPECTED_MAGIC_EXCEPTION]:
        raise FreezeError("compiled source snapshot exception contract drifted")

    expected_launcher = {
        "entrypoint": (
            "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/run_research_phase.ps1"
        ),
        "support_module": (
            "framework/EAs/QM5_20009_ict-liquidity-portfolio/tools/"
            "research_launcher_support.psm1"
        ),
        "accepted_receipt_artifact_type": (
            "QM5_20009_FAIL_CLOSED_RESEARCH_LAUNCHER_RECEIPT"
        ),
        "direct_runner_output_is_verdict_evidence": False,
        "tester_entrypoint": "framework/scripts/run_dev1_smoke.ps1",
        "fixed_model": 4,
        "fixed_deposit": 100000,
        "fixed_currency": "USD",
        "commission_per_lot": 0.0,
        "commission_per_side_native": 0.0,
        "pre_and_post_validator_required": True,
        "external_report_audit_required": True,
        "binding_duplicate_count": 2,
        "diagnostic_smoke_duplicate_count": 1,
    }
    if protocol.get("research_launcher") != expected_launcher:
        raise FreezeError("research launcher evidence contract drifted")

    unlock = protocol.get("phase_unlock")
    if not isinstance(unlock, Mapping):
        raise FreezeError("phase unlock policy is missing")
    expected_priors = {
        "DEV": [],
        "DEV_SMOKE_2022": [],
        "OOS_2023_H1": ["DEV"],
        "OOS_2023_H2": ["DEV", "OOS_2023_H1"],
        "OOS_2024_H1": ["DEV", "OOS_2023_H1", "OOS_2023_H2"],
        "OOS_2024_H2": ["DEV", "OOS_2023_H1", "OOS_2023_H2", "OOS_2024_H1"],
        "OOS_2025_H1": [
            "DEV", "OOS_2023_H1", "OOS_2023_H2", "OOS_2024_H1", "OOS_2024_H2"
        ],
        "OOS_2025_H2": [
            "DEV", "OOS_2023_H1", "OOS_2023_H2", "OOS_2024_H1", "OOS_2024_H2",
            "OOS_2025_H1",
        ],
        "RETRO_HOLDOUT_2026_H1": [
            "DEV", "OOS_2023_H1", "OOS_2023_H2", "OOS_2024_H1", "OOS_2024_H2",
            "OOS_2025_H1", "OOS_2025_H2",
        ],
        "PROSPECTIVE_OPERATIONAL": [
            "DEV", "OOS_2023_H1", "OOS_2023_H2", "OOS_2024_H1", "OOS_2024_H2",
            "OOS_2025_H1", "OOS_2025_H2", "RETRO_HOLDOUT_2026_H1",
        ],
    }
    if (
        unlock.get("enforcement") != "FAIL_CLOSED_DETACHED_VERDICT_RECORDS"
        or unlock.get("verdict_root") != "D:/QM/reports/dev1/QM5_20009/freeze_v3/verdicts"
        or unlock.get("record_name_template") != "{phase_id}.verdict.json"
        or unlock.get("detached_sha256_suffix") != ".sha256"
        or unlock.get("nonbinding_phases") != ["DEV_SMOKE_2022"]
        or unlock.get("required_prior_verdicts") != expected_priors
        or unlock.get("accepted_verdict") != "PASS"
        or unlock.get("record_schema_version") != 1
    ):
        raise FreezeError("phase unlock policy drifted or was weakened")
    required_record_fields = {
        "schema_version", "protocol_id", "phase_id", "binding", "verdict",
        "freeze_inputs_sha256", "manifest_sha256", "evidence_sha256", "completed_utc",
    }
    if set(unlock.get("required_record_fields", [])) != required_record_fields:
        raise FreezeError("phase verdict record schema is incomplete")

    attestation = protocol.get("freeze_attestation")
    if not isinstance(attestation, Mapping) or attestation != {
        "method": "DETACHED_SHA256_OF_MANIFEST_AND_EXPLICIT_PATH_LEVEL_EVIDENCE",
        "manifest_must_not_hash_itself": True,
        "dynamic_git_head_dependency": False,
        "phase_unlock_enforcement": "TECHNICALLY_ENFORCED_BY_VALIDATE_RESEARCH_RUN",
    }:
        raise FreezeError("freeze attestation is missing or overclaims enforcement")

    blockers = protocol.get("qualification_blocking_cost_axes")
    costs = protocol.get("costs")
    if blockers != ["slippage", "overnight_swap_proof"] or not isinstance(costs, Mapping):
        raise FreezeError("qualification cost blocker declaration drifted")
    for axis in blockers:
        row = costs.get(axis)
        if not isinstance(row, Mapping) or row.get("status") not in {"RESOLVED", "UNRESOLVED"}:
            raise FreezeError(f"invalid cost status for {axis}")
    expected_spread = {
        "status": "RESOLVED",
        "model": "MODEL4_EMBEDDED_HISTORICAL_REAL_TICK_BID_ASK",
        "additional_fixed_points": 0.0,
        "double_count_guard": True,
    }
    if costs.get("spread") != expected_spread:
        raise FreezeError("spread cost contract drifted")
    commission = costs.get("commission")
    expected_commission_symbols = {
        "NDX.DWX": {"method": "FIXED_USD_PER_SIDE_PER_LOT", "per_side_usd": 2.75},
        "GDAXI.DWX": {
            "method": "CONSERVATIVE_FIXED_USD_PER_SIDE_PER_LOT",
            "per_side_usd": 3.5,
        },
        "GBPUSD.DWX": {
            "method": "MAX_NATIVE_CONVERTED_AND_USD_FLOOR_PER_SIDE_PER_LOT",
            "native_per_side": 2.5,
            "native_currency": "GBP",
            "usd_floor_per_side": 2.5,
            "conversion": "DEAL_PRICE_BASE_TO_USD",
        },
        "EURUSD.DWX": {
            "method": "MAX_NATIVE_CONVERTED_AND_USD_FLOOR_PER_SIDE_PER_LOT",
            "native_per_side": 2.5,
            "native_currency": "EUR",
            "usd_floor_per_side": 2.5,
            "conversion": "DEAL_PRICE_BASE_TO_USD",
        },
    }
    expected_commission_contract = {
        "status": "RESOLVED",
        "gate_model": "DEALWISE_MAX_DXZ_FTMO_PER_SIDE_VOLUME_USD",
        "execution_model": "RAW_TESTER_ZERO_PLUS_AUTHORITATIVE_EXTERNAL_POSTPROCESSOR",
        "raw_tester_commission_required": 0.0,
        "runner_commission_per_lot_required": 0.0,
        "runner_commission_per_side_native_required": 0.0,
        "ea_sim_commission_required": 0.0,
        "double_count_guard": "REJECT_ANY_NONZERO_NATIVE_REPORT_COMMISSION",
        "rounding": "USD_CENT_HALF_UP_PER_DEAL_SIDE",
        "authoritative_artifact_id": "report_cost_auditor",
        "symbols": expected_commission_symbols,
    }
    if not isinstance(commission, Mapping) or (
        commission != expected_commission_contract
    ):
        raise FreezeError("commission cost contract is incomplete or drifted")
    if costs["slippage"].get("required_resolution") != (
        "PER_SYMBOL_OBSERVED_MAX_ADVERSE_LIVE_FILL_PLUS_GAP_COMPONENT_AND_CONSERVATIVE_MULTIPLIER"
    ):
        raise FreezeError("slippage resolution contract drifted")
    if costs["overnight_swap_proof"].get("required_resolution") != (
        "DEAL_ASSERT_SAME_NY_DATE_AND_SWAP_ZERO; "
        "SYMBOL_SWAP_SNAPSHOT_REQUIRED_ONLY_IF_ANY_OVERNIGHT_EXPOSURE_EXISTS"
    ):
        raise FreezeError("overnight swap proof contract drifted")

    artifacts = protocol.get("evidence_artifacts")
    if not isinstance(artifacts, list):
        raise FreezeError("evidence_artifacts must be a list")
    artifact_ids = [str(item.get("id")) for item in artifacts]
    if len(artifact_ids) != len(set(artifact_ids)):
        raise FreezeError("duplicate evidence artifact id")
    required_artifacts = {
        "ea_binary",
        "ea_binary_repo",
        "compile_evidence",
        "compiler_log",
        "compiler_binary",
        "compile_include_path_audit",
        "provisioning_tick_hash_manifest",
        "news_shared_primary",
        "news_shared_secondary",
        "news_qmdev1_common_primary",
        "news_qmdev1_common_secondary",
        "venue_cost_model",
        "live_commission_model",
        "slippage_calibration",
        "slippage_livefill_ledger",
        "tester_defaults",
        "commission_groups_canonical",
        "commission_groups_dev1",
        "registry_execution_contract",
        "runner_run_smoke",
        "runner_run_dev1_smoke",
        "runner_invoke_dev1_smoke_task",
        "report_cost_auditor",
        "research_launcher",
        "research_launcher_support",
    }
    missing = sorted(required_artifacts - set(artifact_ids))
    if missing:
        raise FreezeError(f"mandatory evidence artifacts missing: {','.join(missing)}")


def _artifact_path(raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else REPO_ROOT / path


def _manifest_path(path: Path, declared_path: str, overridden: bool) -> str:
    if not overridden and not Path(declared_path).is_absolute():
        return declared_path.replace("\\", "/")
    return path.resolve().as_posix()


def _validate_artifact_payload(artifact_id: str, validation: str, path: Path) -> None:
    if path.stat().st_size <= 0:
        raise FreezeError(f"mandatory evidence artifact empty: {artifact_id}: {path}")
    if validation == "METAEDITOR_ZERO_ERRORS_ZERO_WARNINGS":
        text = _decode_evidence_text(path.read_bytes())
        if not re.search(r"Result:\s*0 errors,\s*0 warnings\b", text):
            raise FreezeError(f"compiler log is not clean: {path}")
    elif validation == "INCLUDE_PATH_AUDIT_ALL_ALLOWED":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or any(str(row.get("allowed", "")).lower() != "true" for row in rows):
            raise FreezeError(f"compile include audit contains an outside path: {path}")
    elif validation == "PROVISIONING_HASH_MANIFEST_ALL_MATCH":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or any(
            str(row.get("match", "")).lower() != "true"
            or str(row.get("source_sha256", "")).lower() != str(row.get("dest_sha256", "")).lower()
            or not SHA256_RE.fullmatch(str(row.get("dest_sha256", "")).lower())
            for row in rows
        ):
            raise FreezeError(f"provisioning hash manifest contains drift/invalid hashes: {path}")
    elif validation == "COMPILE_EVIDENCE_PASS":
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError as exc:
            raise FreezeError(f"compile evidence JSON invalid: {path}") from exc
        if payload.get("result") != "PASS" or payload.get("errors") != 0 or payload.get("warnings") != 0:
            raise FreezeError(f"compile evidence is not PASS/0/0: {path}")
    elif validation != "NONEMPTY":
        raise FreezeError(f"unknown evidence validation {validation!r} for {artifact_id}")


def evidence_hashes(
    protocol: Mapping[str, Any],
    overrides: Mapping[str, Path] | None = None,
) -> tuple[list[dict[str, object]], dict[str, Path]]:
    overrides = overrides or {}
    rows: list[dict[str, object]] = []
    paths: dict[str, Path] = {}
    groups: dict[str, list[dict[str, object]]] = {}
    for artifact in sorted(protocol["evidence_artifacts"], key=lambda item: str(item["id"])):
        artifact_id = str(artifact["id"])
        declared = str(artifact["path"])
        overridden = artifact_id in overrides
        path = Path(overrides[artifact_id]) if overridden else _artifact_path(declared)
        if not path.is_file():
            raise FreezeError(f"mandatory evidence artifact missing: {artifact_id}: {path}")
        validation = str(artifact.get("validation", "NONEMPTY"))
        _validate_artifact_payload(artifact_id, validation, path)
        digest = sha256_file(path)
        if "expected_sha256" in artifact:
            expected_digest = str(artifact["expected_sha256"]).lower()
            if not SHA256_RE.fullmatch(expected_digest) or digest != expected_digest:
                raise FreezeError(f"mandatory evidence artifact hash mismatch: {artifact_id}: {path}")
        row: dict[str, object] = {
            "id": artifact_id,
            "path": _manifest_path(path, declared, overridden),
            "size": path.stat().st_size,
            "sha256": digest,
            "validation": validation,
        }
        if "expected_sha256" in artifact:
            row["expected_sha256"] = str(artifact["expected_sha256"]).lower()
        if "version" in artifact:
            row["version"] = artifact["version"]
        if "equality_group" in artifact:
            group = str(artifact["equality_group"])
            row["equality_group"] = group
            groups.setdefault(group, []).append(row)
        rows.append(row)
        paths[artifact_id] = path
    for group, members in groups.items():
        if len(members) < 2 or len({str(row["sha256"]) for row in members}) != 1:
            raise FreezeError(f"equality group drift: {group}")
    _validate_compile_evidence(paths, rows)
    return rows, paths


def _validate_compile_evidence(paths: Mapping[str, Path], rows: Iterable[Mapping[str, object]]) -> None:
    evidence = json.loads(paths["compile_evidence"].read_text(encoding="utf-8-sig"))
    by_id = {str(row["id"]): row for row in rows}
    expected = {
        "source_sha256": sha256_file(EA_SOURCE),
        "local_include_sha256": sha256_file(RULES_SOURCE),
        "ex5_sha256": str(by_id["ea_binary"]["sha256"]),
        "metaeditor_sha256": str(by_id["compiler_binary"]["sha256"]),
        "compile_log_sha256": str(by_id["compiler_log"]["sha256"]),
    }
    for field, wanted in expected.items():
        if str(evidence.get(field, "")).lower() != wanted.lower():
            raise FreezeError(f"compile evidence {field} does not match frozen artifact")
    if evidence.get("outside_include_paths_count") != 0 or int(evidence.get("included_paths_count", 0)) <= 0:
        raise FreezeError("compile evidence include path audit is not clean")


def _month_range(start: str, end_yyyymm: str) -> list[str]:
    cursor = date.fromisoformat(start).replace(day=1)
    end = date(int(end_yyyymm[:4]), int(end_yyyymm[4:]), 1)
    months: list[str] = []
    while cursor <= end:
        months.append(cursor.strftime("%Y%m"))
        cursor = date(cursor.year + (cursor.month == 12), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return months


def model4_data_files(
    protocol: Mapping[str, Any], artifact_paths: Mapping[str, Path]
) -> list[dict[str, object]]:
    config = protocol["model4_data"]
    manifest = artifact_paths[str(config["provisioning_manifest_artifact_id"])]
    with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        source_rows = list(csv.DictReader(handle))
    by_relative = {
        str(row["relative_path"]).replace("\\", "/"): row for row in source_rows
    }
    required: set[str] = {str(config["symbol_definition_relative_path"])}
    frozen_through = str(config["frozen_through_month"])
    for market in protocol["markets"]:
        symbol = str(market["symbol"])
        for month in _month_range(str(market["dev_from"]), frozen_through):
            required.add(f"Custom/ticks/{symbol}/{month}.tkc")
        first_year = date.fromisoformat(str(market["dev_from"])).year
        last_year = int(frozen_through[:4])
        for year in range(first_year, last_year + 1):
            required.add(f"Custom/history/{symbol}/{year}.hcc")
    missing = sorted(required - set(by_relative))
    if missing:
        raise FreezeError(f"provisioning manifest lacks required Model-4 files: {','.join(missing[:8])}")
    destination_root = _artifact_path(str(config["destination_root"]))
    rows: list[dict[str, object]] = []
    for relative in sorted(required):
        source = by_relative[relative]
        digest = str(source["dest_sha256"]).lower()
        size = int(source["dest_length"])
        actual = destination_root / Path(relative)
        if not actual.is_file() or actual.stat().st_size != size:
            raise FreezeError(f"required Model-4 file missing/size drift: {actual}")
        rows.append({"relative_path": relative, "size": size, "sha256": digest})
    return rows


def _git_blob_bytes(object_id: str) -> bytes:
    """Read one fixed Git blob without consulting the moving working-tree HEAD."""

    if not re.fullmatch(r"[0-9a-f]{40}", object_id):
        raise FreezeError("compiled source snapshot Git blob id is invalid")
    try:
        completed = subprocess.run(
            ["git", "cat-file", "blob", object_id],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        raise FreezeError(f"cannot read compiled source snapshot Git blob: {exc}") from exc
    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise FreezeError(f"compiled source snapshot Git blob unavailable: {detail}")
    return completed.stdout


def _magic_resolver_rows_and_skeleton(payload: bytes) -> tuple[
    tuple[tuple[int, int, str, int], ...], str
]:
    """Parse generated registry rows and the invariant resolver implementation.

    The registry generator legitimately appends mappings for unrelated EAs while
    a research binary is frozen.  The compiled prefix and all executable resolver
    code must remain exact; only a collision-free foreign-EA suffix is tolerated.
    """

    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise FreezeError("MagicResolver snapshot is not UTF-8 text") from exc
    lines = text.splitlines()

    def array_payload(name: str) -> str:
        matches = [
            line
            for line in lines
            if line.lstrip().startswith("static const ") and f"{name}[" in line
        ]
        if len(matches) != 1 or "=" not in matches[0]:
            raise FreezeError(f"MagicResolver array is missing or duplicated: {name}")
        raw = matches[0].split("=", 1)[1].strip()
        if not raw.startswith("{") or not raw.endswith("};"):
            raise FreezeError(f"MagicResolver array syntax is invalid: {name}")
        return raw[1:-2]

    def int_array(name: str) -> list[int]:
        try:
            return [int(item.strip()) for item in array_payload(name).split(",")]
        except ValueError as exc:
            raise FreezeError(f"MagicResolver integer array is invalid: {name}") from exc

    def string_array(name: str) -> list[str]:
        try:
            return next(csv.reader([array_payload(name)], skipinitialspace=True))
        except (csv.Error, StopIteration) as exc:
            raise FreezeError(f"MagicResolver string array is invalid: {name}") from exc

    ea_ids = int_array("QM_MAGIC_REG_EA_ID")
    slots = int_array("QM_MAGIC_REG_SLOT")
    symbols = string_array("QM_MAGIC_REG_SYMBOL")
    magics = int_array("QM_MAGIC_REG_MAGIC")
    lengths = {len(ea_ids), len(slots), len(symbols), len(magics)}
    if len(lengths) != 1 or not ea_ids:
        raise FreezeError("MagicResolver generated arrays have inconsistent lengths")
    rows = tuple(zip(ea_ids, slots, symbols, magics, strict=True))
    if len({(row[0], row[1]) for row in rows}) != len(rows):
        raise FreezeError("MagicResolver contains duplicate EA/slot rows")
    if len({row[3] for row in rows}) != len(rows):
        raise FreezeError("MagicResolver contains duplicate magic numbers")

    dynamic_prefixes = (
        "#define QM_MAGIC_REGISTRY_SHA256 ",
        "#define QM_MAGIC_REGISTRY_ROWS ",
        "static const int    QM_MAGIC_REG_EA_ID[",
        "static const int    QM_MAGIC_REG_SLOT[",
        "static const string QM_MAGIC_REG_SYMBOL[",
        "static const int    QM_MAGIC_REG_MAGIC[",
    )
    skeleton = "\n".join(
        "<GENERATED_REGISTRY_PAYLOAD>"
        if line.startswith(dynamic_prefixes)
        else line
        for line in lines
    )
    return rows, skeleton


def _compiled_magic_resolver_row(
    include: Mapping[str, object],
    manifest_row: Mapping[str, str],
    exception: Mapping[str, Any],
) -> dict[str, object]:
    if exception != EXPECTED_MAGIC_EXCEPTION:
        raise FreezeError("compiled MagicResolver snapshot exception drifted")

    compiled = _git_blob_bytes(str(exception["compiled_git_blob_sha1"]))
    compiled_hash = sha256_bytes(compiled)
    source_hash = str(manifest_row.get("source_sha256", "")).lower()
    destination_hash = str(manifest_row.get("destination_sha256", "")).lower()
    if (
        compiled_hash != str(exception["compiled_sha256"])
        or source_hash != compiled_hash
        or destination_hash != compiled_hash
    ):
        raise FreezeError("compiled MagicResolver blob/manifest identity mismatch")

    active_path = REPO_ROOT / MAGIC_RESOLVER_PATH
    active = active_path.read_bytes()
    compiled_rows, compiled_skeleton = _magic_resolver_rows_and_skeleton(compiled)
    active_rows, active_skeleton = _magic_resolver_rows_and_skeleton(active)
    if active_skeleton != compiled_skeleton:
        raise FreezeError("MagicResolver executable/static implementation changed after compile")
    if len(active_rows) < len(compiled_rows) or active_rows[: len(compiled_rows)] != compiled_rows:
        raise FreezeError("MagicResolver active registry is not an append-only compiled-prefix extension")
    if tuple(row for row in compiled_rows if row[0] == 20009) != TARGET_MAGIC_ROWS:
        raise FreezeError("compiled MagicResolver target EA mapping drifted")
    if tuple(row for row in active_rows if row[0] == 20009) != TARGET_MAGIC_ROWS:
        raise FreezeError("active MagicResolver target EA mapping drifted")
    if any(row[0] == 20009 for row in active_rows[len(compiled_rows) :]):
        raise FreezeError("MagicResolver append-only suffix mutates the target EA")

    frozen = dict(include)
    frozen.update(
        {
            "size": len(compiled),
            "sha256": compiled_hash,
            "source_identity": "FIXED_COMPILED_GIT_BLOB",
            "compiled_git_blob_sha1": str(exception["compiled_git_blob_sha1"]),
            "active_drift_policy": str(exception["policy"]),
        }
    )
    return frozen


def validate_compiled_include_closure(
    includes: Iterable[Mapping[str, object]],
    artifact_paths: Mapping[str, Path],
    protocol: Mapping[str, Any],
) -> list[dict[str, object]]:
    manifest_path = artifact_paths["compile_include_sync_manifest"]
    with manifest_path.open("r", encoding="utf-8-sig", newline="") as handle:
        manifest_rows = list(csv.DictReader(handle))
    compiled = {
        str(row.get("relative_path", "")).replace("\\", "/").lower(): row
        for row in manifest_rows
    }
    exceptions = protocol.get("compiled_source_snapshot_exceptions")
    if not isinstance(exceptions, list) or len(exceptions) != 1:
        raise FreezeError("compiled source snapshot exception contract is missing")
    exception = exceptions[0]
    frozen_includes: list[dict[str, object]] = []
    for include in includes:
        repo_path = Path(str(include["path"]))
        try:
            relative = repo_path.relative_to("framework/include").as_posix().lower()
        except ValueError as exc:
            raise FreezeError(f"framework include path outside expected root: {repo_path}") from exc
        row = compiled.get(relative)
        if row is None:
            raise FreezeError(f"compiled include manifest lacks active include: {relative}")
        source_hash = str(row.get("source_sha256", "")).lower()
        destination_hash = str(row.get("destination_sha256", "")).lower()
        if relative == MAGIC_RESOLVER_RELATIVE:
            frozen_includes.append(_compiled_magic_resolver_row(include, row, exception))
            continue
        if source_hash != str(include["sha256"]) or destination_hash != source_hash:
            raise FreezeError(f"compiled include differs from active repo include: {relative}")
        frozen_includes.append(dict(include))
    if not any(str(row["path"]) == MAGIC_RESOLVER_PATH for row in frozen_includes):
        raise FreezeError("compiled include closure does not contain MagicResolver")
    return frozen_includes


def build_freeze_inputs(
    protocol: Mapping[str, Any] | None = None,
    evidence_overrides: Mapping[str, Path] | None = None,
) -> dict[str, object]:
    protocol = dict(protocol or load_protocol())
    validate_protocol(protocol)
    active_includes, external_includes = framework_include_closure()
    local_includes = local_strategy_include_closure()
    evidence, artifact_paths = evidence_hashes(protocol, evidence_overrides)
    includes = validate_compiled_include_closure(active_includes, artifact_paths, protocol)
    data_files = model4_data_files(protocol, artifact_paths)
    source_hashes = {
        "ea_sha256": sha256_file(EA_SOURCE),
        "rules_sha256": sha256_file(RULES_SOURCE),
        "contract_sha256": sha256_file(CONTRACT),
        "spec_sha256": sha256_file(SPEC),
        "protocol_sha256": sha256_file(PROTOCOL),
        "generator_sha256": sha256_file(GENERATOR),
        "validator_sha256": sha256_file(VALIDATOR),
        "auditor_sha256": sha256_file(AUDITOR),
        "research_launcher_sha256": sha256_file(RESEARCH_LAUNCHER),
        "research_launcher_support_sha256": sha256_file(RESEARCH_LAUNCHER_SUPPORT),
    }
    return {
        "schema_version": 2,
        "protocol_id": protocol["protocol_id"],
        "contract_freeze": protocol["contract_freeze"],
        "source_hashes": source_hashes,
        "framework_includes": includes,
        "framework_include_tree_sha256": sha256_bytes(canonical_json_bytes(includes)),
        "local_strategy_includes": local_includes,
        "local_strategy_include_tree_sha256": sha256_bytes(canonical_json_bytes(local_includes)),
        "external_compiler_includes": external_includes,
        "evidence_artifacts": evidence,
        "model4_data_files": data_files,
        "model4_data_tree_sha256": sha256_bytes(canonical_json_bytes(data_files)),
        "cost_axis_status": {
            axis: protocol["costs"][axis]["status"]
            for axis in protocol["qualification_blocking_cost_axes"]
        },
    }


def parameter_map(slot: int, mode: int) -> dict[str, str]:
    values = {
        "qm_ea_id": "20009",
        "qm_magic_slot_offset": str(slot),
        "qm_rng_seed": "42",
        "RISK_PERCENT": "0.0",
        "RISK_FIXED": "1000.0",
        "PORTFOLIO_WEIGHT": "1.0",
        "InpQMSimCommissionPerLot": "0.0",
        "qm_news_temporal": "3",
        "qm_news_compliance": "2",
        "qm_news_stale_max_hours": "336",
        "qm_news_min_impact": "high",
        "qm_news_mode_legacy": "0",
        "qm_friday_close_enabled": "true",
        "qm_friday_close_hour_broker": "23",
        "qm_stress_reject_probability": "0.0",
        "qm_chartui_enabled": "false",
        "qm_chartui_corner": "0",
        "strategy_mode": str(mode),
        "strategy_replay_bars_index": "2500",
        "strategy_replay_bars_fx": "10000",
        **A_CENTER,
        **B_CENTER,
        "strategy_governor_policy_id": "",
        "strategy_challenge_instance_id": "",
        "strategy_governor_heartbeat_max_age_seconds": "5",
    }
    discovered = set(visible_input_names())
    if set(values) != discovered:
        missing = sorted(discovered - set(values))
        extra = sorted(set(values) - discovered)
        raise FreezeError(f"set/input closure mismatch missing={missing} extra={extra}")
    return values


def variants(kind: str) -> list[tuple[str, str | None, str | None]]:
    return [("center", None, None), *STARS[kind]]


def filename(symbol: str, timeframe: str, kind: str, variant: str) -> str:
    return f"QM5_20009_{symbol.replace('.', '_')}_{timeframe}_{kind}_{variant}.set"


def render_set(
    symbol: str,
    timeframe: str,
    slot: int,
    mode: int,
    kind: str,
    variant: str,
    changed_parameter: str | None,
    changed_value: str | None,
    freeze_inputs: Mapping[str, object],
    freeze_inputs_sha256: str,
) -> bytes:
    values = parameter_map(slot, mode)
    if changed_parameter is not None:
        if changed_value is None:
            raise FreezeError(f"variant {variant} has no changed value")
        values[changed_parameter] = changed_value
    hashes = freeze_inputs["source_hashes"]
    evidence = {row["id"]: row for row in freeze_inputs["evidence_artifacts"]}
    lines = [
        ";==========================================================",
        "; QM5_20009 deterministic Freeze-v3 research set",
        f"; protocol_id: {freeze_inputs['protocol_id']}",
        f"; contract_freeze: {freeze_inputs['contract_freeze']}",
        f"; symbol: {symbol}",
        f"; timeframe: {timeframe}",
        f"; sleeve: {kind}",
        f"; variant: {variant}",
        f"; changed_parameter: {changed_parameter or 'none'}",
        f"; freeze_inputs_sha256: {freeze_inputs_sha256}",
        f"; ea_sha256: {hashes['ea_sha256']}",
        f"; rules_sha256: {hashes['rules_sha256']}",
        f"; contract_sha256: {hashes['contract_sha256']}",
        f"; protocol_sha256: {hashes['protocol_sha256']}",
        f"; generator_sha256: {hashes['generator_sha256']}",
        f"; ex5_sha256: {evidence['ea_binary']['sha256']}",
        ";==========================================================",
    ]
    lines.extend(f"{key}={value}" for key, value in values.items())
    return ("\r\n".join(lines) + "\r\n").encode("ascii")


def expected_files(
    protocol: Mapping[str, Any] | None = None,
    evidence_overrides: Mapping[str, Path] | None = None,
) -> tuple[dict[str, bytes], bytes]:
    protocol = dict(protocol or load_protocol())
    freeze_inputs = build_freeze_inputs(protocol, evidence_overrides)
    freeze_root = sha256_bytes(canonical_json_bytes(freeze_inputs))
    files: dict[str, bytes] = {}
    rows: list[dict[str, object]] = []
    for symbol, timeframe, slot, mode, kind in MARKETS:
        for variant, changed_parameter, changed_value in variants(kind):
            name = filename(symbol, timeframe, kind, variant)
            payload = render_set(
                symbol,
                timeframe,
                slot,
                mode,
                kind,
                variant,
                changed_parameter,
                changed_value,
                freeze_inputs,
                freeze_root,
            )
            files[name] = payload
            rows.append(
                {
                    "file": name,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "slot": slot,
                    "mode": mode,
                    "sleeve": kind,
                    "variant": variant,
                    "changed_parameter": changed_parameter,
                    "changed_value": changed_value,
                    "set_sha256": sha256_bytes(payload),
                }
            )
    manifest = {
        "schema_version": 2,
        "ea_id": 20009,
        "protocol_id": protocol["protocol_id"],
        "contract_freeze": protocol["contract_freeze"],
        "generation": "deterministic_no_wall_clock_no_git_head",
        "freeze_inputs_sha256": freeze_root,
        "freeze_inputs": freeze_inputs,
        "set_count": len(rows),
        "sets": rows,
    }
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return files, manifest_bytes


def detached_manifest_sha256(manifest: bytes) -> bytes:
    return f"{sha256_bytes(manifest)}  manifest.json\n".encode("ascii")


def check(evidence_overrides: Mapping[str, Path] | None = None) -> list[str]:
    files, manifest = expected_files(evidence_overrides=evidence_overrides)
    detached = detached_manifest_sha256(manifest)
    expected = {**files, "manifest.json": manifest, "manifest.sha256": detached}
    issues: list[str] = []
    actual_names = {path.name for path in SETS_ROOT.iterdir() if path.is_file()} if SETS_ROOT.is_dir() else set()
    for extra in sorted(actual_names - set(expected)):
        issues.append(f"unexpected:{extra}")
    for name, payload in expected.items():
        path = SETS_ROOT / name
        if not path.exists():
            issues.append(f"missing:{name}")
        elif path.read_bytes() != payload:
            issues.append(f"drift:{name}")
    return issues


def write(evidence_overrides: Mapping[str, Path] | None = None) -> None:
    files, manifest = expected_files(evidence_overrides=evidence_overrides)
    expected = {
        **files,
        "manifest.json": manifest,
        "manifest.sha256": detached_manifest_sha256(manifest),
    }
    SETS_ROOT.mkdir(parents=True, exist_ok=True)
    for stale in SETS_ROOT.iterdir():
        if stale.is_file() and stale.name not in expected:
            stale.unlink()
    for name, payload in expected.items():
        (SETS_ROOT / name).write_bytes(payload)


def parse_evidence_overrides(values: Iterable[str]) -> dict[str, Path]:
    overrides: dict[str, Path] = {}
    for value in values:
        artifact_id, separator, raw_path = value.partition("=")
        if not separator or not artifact_id or not raw_path:
            raise FreezeError(f"invalid --evidence override: {value!r}; expected ID=PATH")
        overrides[artifact_id] = Path(raw_path)
    return overrides


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--evidence",
        action="append",
        default=[],
        metavar="ID=PATH",
        help="override a declared evidence path; the effective path is frozen in the manifest",
    )
    args = parser.parse_args(argv)
    try:
        overrides = parse_evidence_overrides(args.evidence)
        if args.check:
            issues = check(overrides)
            if issues:
                print("\n".join(issues))
                return 1
            print("PASS: 52 frozen research sets, manifest and detached hash match")
            return 0
        write(overrides)
    except FreezeError as exc:
        print(f"FREEZE_BLOCKED: {exc}")
        return 2
    print("WROTE: 52 frozen research sets, manifest and detached hash")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
