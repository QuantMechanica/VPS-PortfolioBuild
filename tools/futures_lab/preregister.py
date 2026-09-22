"""Validate and compile a bounded, futures-only research preregistration.

This module deliberately does not load market data or calculate economic results.
It turns a frozen preregistration into a deterministic trial-cell manifest for a
later NautilusTrader executor.  The executor must independently bind licensed raw
contract data and may not substitute continuous contracts, CFD aliases, or MT5
pipeline evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import date
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "qm.futures-preregistration/v1"
PLAN_SCHEMA = "qm.futures-trial-plan/v1"
RAW_CONTRACT_RE = re.compile(r"^(MES|ES|MNQ|NQ)[HMUZ][0-9]$")
PAIRINGS = {
    "MES": frozenset({"MES", "ES"}),
    "MNQ": frozenset({"MNQ", "NQ"}),
}
REQUIRED_PERIODS = (
    "development",
    "validation",
    "historical_context_test",
    "untouched_holdout",
)
REQUIRED_SCENARIOS = frozenset({"BASE", "ADVERSE", "SEVERE"})


class PreregistrationError(ValueError):
    """Raised when a preregistration would permit an ambiguous or widened run."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise PreregistrationError(message)


def _as_date(raw: Any, label: str) -> date:
    _require(isinstance(raw, str), f"{label} must be an ISO date string")
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise PreregistrationError(f"{label} is not an ISO date: {raw!r}") from exc


def _unique_ids(rows: list[dict[str, Any]], label: str) -> set[str]:
    ids = [row.get("id") for row in rows]
    _require(all(isinstance(value, str) and value for value in ids), f"{label} ids must be non-empty strings")
    _require(len(ids) == len(set(ids)), f"{label} ids must be unique")
    return set(ids)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    _require(isinstance(value, dict), "top-level preregistration must be an object")
    return value


def _validate_periods(config: dict[str, Any]) -> list[dict[str, Any]]:
    periods = config.get("periods")
    _require(isinstance(periods, list), "periods must be a list")
    ids = _unique_ids(periods, "period")
    _require(ids == set(REQUIRED_PERIODS), f"period ids must be exactly {REQUIRED_PERIODS}")

    ordered = sorted(periods, key=lambda row: _as_date(row.get("start"), f"period {row.get('id')} start"))
    prior_end: date | None = None
    for row in ordered:
        period_id = str(row["id"])
        start = _as_date(row.get("start"), f"period {period_id} start")
        end = _as_date(row.get("end"), f"period {period_id} end")
        _require(start <= end, f"period {period_id} ends before it starts")
        if prior_end is not None:
            _require(start > prior_end, f"period {period_id} overlaps an earlier period")
        prior_end = end

    holdout = next(row for row in periods if row["id"] == "untouched_holdout")
    frozen_on = _as_date(config.get("frozen_on"), "frozen_on")
    holdout_start = _as_date(holdout.get("start"), "untouched_holdout start")
    holdout_end = _as_date(holdout.get("end"), "untouched_holdout end")
    access_not_before = _as_date(holdout.get("economic_access_not_before"), "untouched_holdout access")
    _require(holdout.get("classification") == "PROSPECTIVE_UNTOUCHED", "holdout must be prospectively untouched")
    _require(holdout_start > frozen_on, "prospective holdout must start after the freeze date")
    _require(access_not_before > holdout_end, "holdout economic access must remain embargoed through period end")

    historical = next(row for row in periods if row["id"] == "historical_context_test")
    _require(
        historical.get("classification") == "LOCKED_OOS_NOT_UNTOUCHED_DUE_PRIOR_CFD_VIEWING",
        "historical context period must disclose prior-CFD selection contamination",
    )
    return periods


def _validate_hypotheses(config: dict[str, Any]) -> set[str]:
    hypotheses = config.get("hypotheses")
    _require(isinstance(hypotheses, list), "hypotheses must be a list")
    _require(1 <= len(hypotheses) <= 2, "one or two hypotheses are permitted")
    ids = _unique_ids(hypotheses, "hypothesis")
    provenance = {row.get("provenance") for row in hypotheses}
    _require(provenance == {"SOURCE_GROUNDED", "QM_AUTHORED"}, "one source-grounded and one QM-authored hypothesis are required")
    specs = config.get("strategy_specs")
    _require(isinstance(specs, dict), "strategy_specs must be an object")
    for row in hypotheses:
        spec_id = row.get("mechanical_spec_id")
        _require(isinstance(spec_id, str), f"hypothesis {row['id']} lacks mechanical_spec_id")
        spec = specs.get(spec_id)
        _require(isinstance(spec, dict), f"hypothesis {row['id']} references a missing mechanical spec")
        for field in (
            "range_window_new_york",
            "entry_window_new_york",
            "signal_bar_seconds",
            "long_trigger",
            "short_trigger",
            "entry_order",
            "initial_stop",
            "profit_target",
            "attempts_per_session",
            "reentry",
            "size_formula",
            "forced_flat",
        ):
            _require(field in spec, f"mechanical spec {spec_id} lacks {field}")
        _require(spec["attempts_per_session"] == 1 and spec["reentry"] is False, f"mechanical spec {spec_id} widens daily attempts")
        _require(isinstance(row.get("falsification"), list) and row["falsification"], f"hypothesis {row['id']} lacks falsification rules")
        if row["provenance"] == "SOURCE_GROUNDED":
            lineage = row.get("source_lineage")
            _require(isinstance(lineage, list) and lineage, "source-grounded hypothesis needs source_lineage")
        else:
            _require(row.get("external_source_claim") == "NONE_QM_AUTHORED", "QM-authored hypothesis must not imply an external source")
            for field in ("minimum_excursion_ticks", "maximum_reentry_wait_bars", "inside_confirmation_ticks", "ambiguous_both_sides"):
                _require(field in spec, f"QM-authored mechanical spec {spec_id} lacks {field}")
    return ids


def _validate_contracts(config: dict[str, Any]) -> None:
    roll = config.get("contract_mapping")
    _require(isinstance(roll, dict), "contract_mapping must be an object")
    _require(roll.get("price_series") == "INDIVIDUAL_RAW_CONTRACTS_ONLY", "continuous/back-adjusted price series are forbidden")
    _require(roll.get("cutover_rule") == "NY_CASH_OPEN_MONDAY_BEFORE_THIRD_FRIDAY", "roll cutover rule is not frozen")
    _require(roll.get("exclude_cutover_session") is True, "roll cutover session must be excluded")
    _require(roll.get("definition_verification_required") is True, "raw contract definitions must be verified")
    suffixes = roll.get("candidate_contract_suffixes")
    roots = roll.get("roots")
    _require(isinstance(suffixes, list) and suffixes, "candidate contract suffixes are required")
    _require(roots == ["MES", "ES", "MNQ", "NQ"], "contract roots must be explicit and ordered")
    expanded = [f"{root}{suffix}" for root in roots for suffix in suffixes]
    _require(len(expanded) == len(set(expanded)), "raw contract candidates must be unique")
    _require(all(RAW_CONTRACT_RE.fullmatch(symbol) for symbol in expanded), "invalid raw quarterly contract candidate")


def _validate_arms(config: dict[str, Any], hypothesis_ids: set[str]) -> list[dict[str, Any]]:
    arms = config.get("arms")
    _require(isinstance(arms, list), "arms must be a list")
    cap = config.get("arm_cap")
    _require(isinstance(cap, int) and 1 <= cap <= 6, "arm_cap must be between one and six")
    _require(1 <= len(arms) <= cap, "frozen arm count exceeds the cap")
    _require(config.get("unused_capacity_is_not_authorization") is True, "unused arm capacity must not authorize later additions")
    _unique_ids(arms, "arm")

    priorities: list[int] = []
    for arm in arms:
        arm_id = str(arm["id"])
        _require("QM5_" not in arm_id and ".DWX" not in arm_id.upper(), f"arm {arm_id} uses a CFD/EA identity")
        _require(arm.get("hypothesis_id") in hypothesis_ids, f"arm {arm_id} references an unknown hypothesis")
        _require(arm.get("stage") in (1, 2), f"arm {arm_id} stage must be 1 or 2")
        priorities.append(arm.get("priority"))
        signal = arm.get("signal_instrument")
        fill = arm.get("fill_instrument")
        _require(isinstance(signal, dict) and isinstance(fill, dict), f"arm {arm_id} must separate signal and fill instruments")
        signal_root = signal.get("root")
        fill_root = fill.get("root")
        _require(fill_root in PAIRINGS, f"arm {arm_id} fill root must be MES or MNQ")
        _require(signal_root in PAIRINGS[fill_root], f"arm {arm_id} mini/micro pairing is invalid")
        for role, instrument in (("signal", signal), ("fill", fill)):
            _require(instrument.get("venue") == "GLBX", f"arm {arm_id} {role} venue must be GLBX")
            _require(instrument.get("stype_in") == "raw_symbol", f"arm {arm_id} {role} must use raw symbols")
            _require(instrument.get("contract_resolution") == "VERIFIED_ROLL_MAP", f"arm {arm_id} {role} lacks verified roll binding")
            rendered = json.dumps(instrument).lower()
            _require("continuous" not in rendered and ".dwx" not in rendered and "c.0" not in rendered, f"arm {arm_id} {role} permits a continuous/CFD alias")
        if arm["stage"] == 1:
            _require(fill_root == "MES", f"stage-1 arm {arm_id} must prioritize MES")
        else:
            _require(fill_root == "MNQ", f"stage-2 arm {arm_id} must be the later MNQ transfer")
        _require(arm.get("paired_session_ledger") is True, f"arm {arm_id} must retain no-signal sessions")

    _require(all(isinstance(value, int) for value in priorities), "arm priorities must be integers")
    _require(sorted(priorities) == list(range(1, len(arms) + 1)), "arm priorities must be contiguous")
    _require(any(arm["stage"] == 1 for arm in arms) and any(arm["stage"] == 2 for arm in arms), "both MES-first and MNQ-transfer stages are required")
    return arms


def _validate_risk_and_execution(config: dict[str, Any]) -> list[dict[str, Any]]:
    risk = config.get("risk")
    _require(isinstance(risk, dict), "risk must be an object")
    _require(isinstance(risk.get("risk_fixed_usd"), (int, float)) and risk["risk_fixed_usd"] > 0, "risk_fixed_usd must be positive")
    _require(risk.get("risk_percent") == 0, "risk_percent must remain zero for research")
    _require(isinstance(risk.get("max_micro_contracts"), int) and risk["max_micro_contracts"] > 0, "max_micro_contracts must be positive")
    _require(risk.get("one_position_per_arm") is True, "one_position_per_arm must be enforced")
    _require(risk.get("pyramiding") is False and risk.get("averaging_down") is False, "pyramiding/averaging down are forbidden")
    _require(float(risk.get("daily_loss_halt_pct", 100)) <= 5.0, "daily loss halt exceeds 5%")
    _require(float(risk.get("total_loss_halt_pct", 100)) <= 10.0, "total loss halt exceeds 10%")

    execution = config.get("execution")
    _require(isinstance(execution, dict), "execution must be an object")
    _require(execution.get("fill_source") == "MICRO_MBP1_SIDE_CORRECT", "fills must use side-correct micro quotes")
    _require(execution.get("passive_touch_fill") is False, "passive touch fills are forbidden")
    scenarios = execution.get("scenarios")
    _require(isinstance(scenarios, list), "execution scenarios must be a list")
    scenario_ids = _unique_ids(scenarios, "execution scenario")
    _require(scenario_ids == REQUIRED_SCENARIOS, f"execution scenarios must be exactly {sorted(REQUIRED_SCENARIOS)}")
    for scenario in scenarios:
        scenario_id = scenario["id"]
        _require(float(scenario.get("commission_usd_round_turn_per_micro", -1)) >= 0, f"scenario {scenario_id} commission is invalid")
        _require(int(scenario.get("slippage_ticks_per_side", -1)) >= 0, f"scenario {scenario_id} slippage is invalid")
        _require(int(scenario.get("latency_ms", -1)) >= 0, f"scenario {scenario_id} latency is invalid")
    return scenarios


def validate_config(config: dict[str, Any]) -> None:
    _require(config.get("schema") == SCHEMA, f"schema must be {SCHEMA}")
    _require(config.get("status") == "FROZEN_PRE_ECONOMIC_RESULTS", "status must be frozen before results")
    _require(config.get("lane") == "FUTURES_ONLY_SEPARATE_FROM_CFD_FACTORY", "lane must remain futures-only")
    _require(config.get("economic_results_viewed") is False, "futures economic results were already marked viewed")
    _require(config.get("creates_mt5_ea_ids") is False, "preregistration may not allocate MT5 EA ids")
    _require(config.get("uses_cfd_gate_runner") is False, "preregistration may not use the CFD gate runner")
    _validate_periods(config)
    hypotheses = _validate_hypotheses(config)
    _validate_contracts(config)
    _validate_arms(config, hypotheses)
    _validate_risk_and_execution(config)

    stage_policy = config.get("stage_policy")
    _require(isinstance(stage_policy, dict), "stage_policy must be an object")
    _require(stage_policy.get("economic_selection_between_stages") is False, "MES economics may not control MNQ release")
    _require(stage_policy.get("parameters_change_between_stages") is False, "parameters may not change between stages")

    prior = config.get("prior_cfd_evidence")
    _require(isinstance(prior, list) and prior, "prior CFD selection evidence must be retained")
    prior_rows = [row for group in prior for row in group.get("rows", [])]
    _require(any(row.get("verdict") == "FAIL" for row in prior_rows), "prior negative CFD rows are missing")
    _require(any(group.get("relationship") == "EXACT_SOURCE_CARD_HISTORY_NOT_FUTURES_EVIDENCE" for group in prior), "exact source-card history is missing")

    calendar = config.get("calendar")
    _require(isinstance(calendar, dict), "calendar must be an object")
    _require(calendar.get("event_timestamp_zone") == "UTC", "raw event timestamps must remain UTC")
    _require(calendar.get("cash_session_zone") == "America/New_York", "cash session must use America/New_York")
    _require(calendar.get("trade_date_zone") == "America/Chicago", "trade date must use America/Chicago")
    _require(calendar.get("tzdata_version") == "2026.4", "tzdata version is not pinned")
    _require(calendar.get("exclude_early_close_sessions") is True, "early-close sessions must fail closed")

    news = config.get("news_blackout")
    _require(isinstance(news, dict) and news.get("mandatory") is True, "news blackout must be mandatory")
    _require(float(news.get("max_calendar_age_hours", 337)) <= 336, "news calendar staleness exceeds 336 hours")
    _require(news.get("missing_calendar_action") == "SKIP_SESSION", "missing news data must fail closed")

    no_signal = config.get("no_signal_control")
    _require(isinstance(no_signal, dict) and no_signal.get("mode") == "PAIRED_SESSION_LEDGER", "paired no-signal control is required")
    _require(no_signal.get("drop_zero_trade_sessions") is False, "zero-trade sessions may not be dropped")
    required_outcomes = {"TRADE", "NO_SIGNAL", "NEWS_BLACKOUT", "DATA_INVALID", "ROLL_EXCLUDED", "RISK_SKIP"}
    _require(set(no_signal.get("session_outcomes", [])) == required_outcomes, "session outcome taxonomy is incomplete")

    gaps = config.get("data_gaps")
    _require(isinstance(gaps, list) and gaps, "data gaps must be explicit")
    _require(all(row.get("status") in {"BLOCKED", "UNKNOWN"} for row in gaps), "data gaps may not be silently marked resolved")


def expanded_raw_contracts(config: dict[str, Any]) -> list[str]:
    mapping = config["contract_mapping"]
    return [f"{root}{suffix}" for root in mapping["roots"] for suffix in mapping["candidate_contract_suffixes"]]


def compile_plan(config: dict[str, Any], config_sha256: str) -> dict[str, Any]:
    validate_config(config)
    cells: list[dict[str, Any]] = []
    for arm in sorted(config["arms"], key=lambda row: row["priority"]):
        for period in config["periods"]:
            for scenario in sorted(config["execution"]["scenarios"], key=lambda row: row["id"]):
                cells.append(
                    {
                        "cell_id": f"{arm['id']}__{period['id']}__{scenario['id']}",
                        "arm_id": arm["id"],
                        "hypothesis_id": arm["hypothesis_id"],
                        "stage": arm["stage"],
                        "period_id": period["id"],
                        "start": period["start"],
                        "end": period["end"],
                        "economic_access_not_before": period.get("economic_access_not_before"),
                        "scenario_id": scenario["id"],
                        "result_status": "NOT_RUN",
                    }
                )
    return {
        "schema": PLAN_SCHEMA,
        "task_id": config["task_id"],
        "source_config_sha256": config_sha256,
        "economic_results_included": False,
        "hypothesis_count": len(config["hypotheses"]),
        "arm_count": len(config["arms"]),
        "trial_cell_count": len(cells),
        "raw_contract_candidates": expanded_raw_contracts(config),
        "cells": cells,
    }


def write_plan(path: Path, plan: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(plan, indent=2, sort_keys=True) + "\n").encode("utf-8")
    path.write_bytes(payload)


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and compile a frozen futures preregistration")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--emit-plan", type=Path)
    args = parser.parse_args(list(argv) if argv is not None else None)

    config = load_config(args.config)
    validate_config(config)
    config_hash = file_sha256(args.config)
    plan = compile_plan(config, config_hash)
    if args.emit_plan is not None:
        write_plan(args.emit_plan, plan)
    print(
        json.dumps(
            {
                "status": "VALID_FROZEN_PREREGISTRATION",
                "config": str(args.config),
                "config_sha256": config_hash,
                "hypothesis_count": plan["hypothesis_count"],
                "arm_count": plan["arm_count"],
                "trial_cell_count": plan["trial_cell_count"],
                "raw_contract_candidate_count": len(plan["raw_contract_candidates"]),
                "plan": str(args.emit_plan) if args.emit_plan is not None else None,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
