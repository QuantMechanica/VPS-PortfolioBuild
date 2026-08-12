#!/usr/bin/env python3
"""Outcome-blind structural readiness audit for QM5_13128.

This tool never starts MetaTrader, reads trade metrics, or makes a merit
decision.  It verifies that the frozen BLOCKED receipt still describes the
same Card/source/binary/set/registry state and fails closed on any drift.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
CONTRACT_PATH = (
    EA_ROOT
    / "docs"
    / "candidate-analysis"
    / "pre_fomc_ndx_requalification_blocked_contract_20260720.json"
)
EXPECTED_CONTRACT_SHA256 = "dcdabba12eab90bea7c1b93e5442fe926b1345b8ecbe47802cabad3723a3ff43"

OFFICIAL_DATE_KEYS = (
    20180926,
    20181219,
    20190130,
    20190320,
    20190501,
    20190619,
    20190731,
    20190918,
    20191030,
    20191211,
    20200129,
    20200429,
    20200610,
    20200729,
    20200916,
    20201105,
    20201216,
    20210127,
    20210317,
    20210428,
    20210616,
    20210728,
    20210922,
    20211103,
    20211215,
    20220126,
    20220316,
    20220504,
    20220615,
    20220727,
    20220921,
    20221102,
    20221214,
    20230201,
    20230322,
    20230503,
    20230614,
    20230726,
    20230920,
    20231101,
    20231213,
    20240131,
    20240320,
    20240501,
    20240612,
    20240731,
    20240918,
    20241107,
    20241218,
    20250129,
    20250319,
    20250507,
    20250618,
    20250730,
    20250917,
    20251029,
    20251210,
    20260128,
    20260318,
    20260429,
    20260617,
    20260729,
    20260916,
    20261028,
    20261209,
)


class AuditError(RuntimeError):
    """A frozen identity or fail-closed readiness assertion did not hold."""


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha256(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditError(message)


def resolve_binding(raw_path: str) -> Path:
    candidate = Path(raw_path)
    return candidate if candidate.is_absolute() else REPO_ROOT / candidate


def load_contract(*, verify_release_hash: bool = True) -> dict[str, Any]:
    _require(CONTRACT_PATH.is_file(), f"missing contract: {CONTRACT_PATH}")
    if verify_release_hash:
        observed = sha256_path(CONTRACT_PATH)
        _require(
            observed == EXPECTED_CONTRACT_SHA256,
            "contract hash drift: "
            f"expected {EXPECTED_CONTRACT_SHA256}, observed {observed}",
        )
    payload = json.loads(CONTRACT_PATH.read_text(encoding="utf-8-sig"))
    _require(isinstance(payload, dict), "contract root must be an object")
    return payload


def extract_source_date_keys(source_text: str) -> tuple[int, ...]:
    match = re.search(
        r"const\s+int\s+g_event_dates\s*\[\s*\]\s*=\s*\{(?P<body>.*?)\};",
        source_text,
        flags=re.DOTALL,
    )
    _require(match is not None, "source event calendar array not found")
    return tuple(int(value) for value in re.findall(r"\b\d{8}\b", match.group("body")))


def parse_set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _csv_rows(path: Path, *, symbol: str) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return [row for row in csv.DictReader(handle) if row.get("symbol") == symbol]


def verify_source_bindings(contract: Mapping[str, Any]) -> int:
    bindings = contract.get("source_bindings")
    _require(isinstance(bindings, dict) and bindings, "source_bindings missing")
    for raw_path, expected_hash in bindings.items():
        path = resolve_binding(str(raw_path))
        _require(path.is_file(), f"bound file missing: {path}")
        observed_hash = sha256_path(path)
        _require(
            observed_hash == str(expected_hash),
            f"bound file hash drift: {raw_path}: "
            f"expected {expected_hash}, observed {observed_hash}",
        )
    return len(bindings)


def verify_calendar(contract: Mapping[str, Any]) -> None:
    calendar = contract["calendar_contract"]
    frozen_dates = tuple(calendar["verified_source_date_keys"])
    _require(frozen_dates == OFFICIAL_DATE_KEYS, "frozen official calendar drift")
    _require(len(set(frozen_dates)) == 65, "calendar must contain 65 unique dates")
    _require(tuple(sorted(frozen_dates)) == frozen_dates, "calendar must be ordered")
    _require(
        tuple(calendar["future_2026_dates_at_freeze"])
        == (20260729, 20260916, 20261028, 20261209),
        "future forward fence drift",
    )

    source_path = EA_ROOT / "QM5_13128_pre-fomc-drift-ndx.mq5"
    source_text = source_path.read_text(encoding="utf-8-sig")
    _require(
        extract_source_date_keys(source_text) == frozen_dates,
        "MQ5 calendar differs from frozen official dates",
    )
    valid_through = re.search(
        r"g_event_calendar_valid_through_key\s*=\s*(\d{8})", source_text
    )
    _require(valid_through is not None, "source calendar validity horizon missing")
    _require(int(valid_through.group(1)) == 20261231, "source validity horizon drift")


def verify_card_source_binary_conflict(contract: Mapping[str, Any]) -> None:
    card_path = resolve_binding(
        "D:/QM/strategy_farm/artifacts/cards_approved/"
        "QM5_13128_pre-fomc-drift-ndx.md"
    )
    card_text = card_path.read_text(encoding="utf-8-sig")
    _require("compiled 57-date FOMC table" in card_text, "Card no longer declares 57 dates")
    _require(
        "57 dates, 2018-09" in card_text and "2025-12" in card_text,
        "Card calendar horizon no longer reproduces the frozen conflict",
    )

    lineage = contract["binary_and_build_lineage"]
    canonical_ex5 = EA_ROOT / "QM5_13128_pre-fomc-drift-ndx.ex5"
    snapshot_ex5 = (
        REPO_ROOT
        / "framework"
        / "build"
        / "fidelity_compile_20260715"
        / "src"
        / "QM5_13128_pre-fomc-drift-ndx.ex5"
    )
    _require(
        sha256_path(canonical_ex5)
        == lineage["canonical_repo_and_live_ex5_sha256"],
        "canonical EX5 identity drift",
    )
    _require(
        sha256_path(snapshot_ex5)
        == lineage["current_source_compile_snapshot_ex5_sha256"],
        "current-source compile snapshot identity drift",
    )
    _require(
        sha256_path(canonical_ex5) != sha256_path(snapshot_ex5),
        "binary mismatch blocker no longer exists; issue a new readiness decision",
    )

    compile_log = (
        REPO_ROOT
        / "framework"
        / "build"
        / "fidelity_compile_20260715"
        / "logs"
        / "QM5_13128_pre-fomc-drift-ndx.log"
    ).read_text(encoding="utf-16", errors="replace")
    _require("Result: 0 errors, 0 warnings" in compile_log, "compile result drift")


def verify_set_and_risk_identity() -> None:
    backtest_set = (
        EA_ROOT
        / "sets"
        / "QM5_13128_pre-fomc-drift-ndx_NDX.DWX_H1_backtest.set"
    )
    text = backtest_set.read_text(encoding="utf-8-sig")
    values = parse_set_values(backtest_set)
    expected = {
        "RISK_FIXED": "1000",
        "RISK_PERCENT": "0",
        "PORTFOLIO_WEIGHT": "1",
        "strategy_timeframe": "16385",
        "strategy_entry_hour": "21",
        "strategy_exit_hour": "20",
        "strategy_atr_period": "14",
        "strategy_stop_atr_mult": "2.0",
    }
    _require(values == {**{"qm_ea_id": "13128", "qm_magic_slot_offset": "0"}, **expected}, "backtest set values drift")
    _require("; build_hash:   pending" in text, "pending build-hash blocker missing")
    _require("; card_defaults_source=not_found" in text, "missing Card-default blocker drift")

    live_set = resolve_binding(
        "C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/"
        "14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set"
    )
    live_values = parse_set_values(live_set)
    _require(live_values.get("RISK_FIXED") == "0", "live fixed-risk identity drift")
    _require(live_values.get("RISK_PERCENT") == "1.0000", "live percent-risk identity drift")


def verify_registry_blockers(contract: Mapping[str, Any]) -> None:
    expected = contract["content_bindings"]
    execution_path = REPO_ROOT / "framework" / "registry" / "dxz23_execution_contracts.json"
    execution = json.loads(execution_path.read_text(encoding="utf-8-sig"))
    rows = [row for row in execution["contracts"] if row.get("ea_id") == 13128]
    _require(len(rows) == 1, "expected exactly one execution contract for EA 13128")
    entry = rows[0]
    _require(
        canonical_json_sha256(entry)
        == expected["dxz23_execution_contract_ea_13128_canonical_json_sha256"],
        "EA 13128 execution-contract content drift",
    )
    _require(entry["promotion"]["status"] == "BLOCKED", "promotion is not blocked")
    required_reasons = {
        "unresolved_semantic_conflict_card_calendar_ends_2025_vs_source_calendar_extends_2026",
        "friday_close_override_not_card_qualified",
        "remediated_binary_not_requalified",
    }
    _require(
        set(entry["promotion"]["block_reasons"]) == required_reasons,
        "execution-contract blocker set drift",
    )

    matrix_rows = _csv_rows(
        REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv",
        symbol="NDX.DWX",
    )
    _require(len(matrix_rows) == 1, "expected exactly one NDX.DWX symbol row")
    _require(
        canonical_json_sha256(matrix_rows)
        == expected["dwx_symbol_matrix_ndx_row_canonical_json_sha256"],
        "NDX.DWX symbol-matrix row drift",
    )
    _require(
        "FAIL_tail_mid_bars" in matrix_rows[0].get("evidence_line", ""),
        "NDX setup-data failure marker missing",
    )

    history_rows = _csv_rows(
        REPO_ROOT / "framework" / "registry" / "dwx_symbol_history_ranges.csv",
        symbol="NDX.DWX",
    )
    _require(len(history_rows) == 19, "NDX history-range row count drift")
    _require(
        canonical_json_sha256(history_rows)
        == expected["dwx_symbol_history_ranges_ndx_rows_canonical_json_sha256"],
        "NDX history-range rows drift",
    )
    h1_d1 = [row for row in history_rows if row["period"] in {"H1", "D1"}]
    _require(
        len(h1_d1) == 2 and all(row["first_year"] == "2021" for row in h1_d1),
        "NDX H1/D1 history-range mismatch no longer reproduces",
    )


def verify_fail_closed_state(contract: Mapping[str, Any]) -> None:
    decision = contract["decision"]
    _require(decision["state"] == "BLOCKED_NOT_RELEASED", "contract is not blocked")
    _require(decision["execution_authority"] == "NONE", "execution authority must be NONE")
    _require(decision["tester_authority"] == "NONE", "tester authority must be NONE")
    _require(decision["promotion_authority"] == "NONE", "promotion authority must be NONE")
    _require(
        contract["historical_evidence_disposition"]["tester_ini_inventory"]["ending_in_2026"]
        == 0,
        "contract must not claim 2026 tester evidence",
    )
    _require(
        contract["future_forward_fence"]["standalone_merit_power"]
        == "INSUFFICIENT_FOUR_EVENTS",
        "future fence must not claim statistical qualification",
    )
    wave0 = resolve_binding(contract["data_and_time_readiness"]["expected_wave0_report"])
    _require(
        not wave0.exists(),
        "previously missing Wave-0 report now exists; issue a new readiness decision",
    )


def run_audit() -> dict[str, Any]:
    contract = load_contract()
    verify_fail_closed_state(contract)
    verify_calendar(contract)
    verify_card_source_binary_conflict(contract)
    verify_set_and_risk_identity()
    verify_registry_blockers(contract)
    binding_count = verify_source_bindings(contract)
    return {
        "analysis_id": contract["analysis_id"],
        "status": "PASS_BLOCKED_STATE_REPRODUCED",
        "qualification_state": "BLOCKED_NOT_RELEASED",
        "tester_started": False,
        "source_bindings_verified": binding_count,
        "official_calendar_dates_verified": len(OFFICIAL_DATE_KEYS),
        "future_events_fenced": len(contract["future_forward_fence"]["eligible_not_yet_occurred_events"]),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the frozen blocked state")
    args = parser.parse_args(argv)
    if not args.check:
        parser.error("only --check is supported; this tool has no tester mode")
    try:
        result = run_audit()
    except (AuditError, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(json.dumps({"status": "FAIL_CLOSED", "error": str(exc)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
