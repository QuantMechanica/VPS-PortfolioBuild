from __future__ import annotations

import csv
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_9909_bandy-lrchannel-breakout-trend"
EA_DIR = ROOT / "framework" / "EAs" / EA_LABEL
SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
SETS = EA_DIR / "sets"
BUILD_IDENTITY = EA_DIR / "build_identity.json"
MAGIC_CSV = ROOT / "framework" / "registry" / "magic_numbers.csv"
MAGIC_RESOLVER = ROOT / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"

APPROVED_SYMBOLS = {
    "AUDUSD.DWX",
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "NDX.DWX",
    "NZDUSD.DWX",
    "SP500.DWX",
    "USDCAD.DWX",
    "USDCHF.DWX",
    "USDJPY.DWX",
    "WS30.DWX",
    "XAUUSD.DWX",
    "XTIUSD.DWX",
}


def _source() -> str:
    return SOURCE.read_text(encoding="utf-8")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def test_d1_contract_and_management_reachability_are_explicit() -> None:
    source = _source()
    on_tick = source.split("void OnTick()", 1)[1]

    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1," in source
    assert "QM_IsNewBar(_Symbol, PERIOD_D1)" in source
    management = on_tick.index("Strategy_ManageOpenPosition();")
    for entry_only_gate in (
        "Strategy_NewsFilterHook(broker_now)",
        "QM_FrameworkHandleFridayClose()",
        "Strategy_NoTradeFilter()",
        "QM_NewsAllowsTrade2(",
        "QM_IsNewBar(_Symbol, PERIOD_D1)",
    ):
        assert management < on_tick.index(entry_only_gate)


def test_card_stop_layers_and_every_strategy_input_are_wired() -> None:
    source = _source()
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_<>]*\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert names
    assert all(len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2 for name in names)
    assert "strategy_spread_max_atr" not in source
    assert "catastrophic_sl" in source
    assert "QM_StopATRFromValue" in source
    assert "Strategy_ArmCatastrophicBackstop(out_ticket, req.sl, g_pending_entry_atr)" in source
    assert "GlobalVariableSet(Strategy_PrimaryTrailKey(ticket), primary_sl)" in source
    assert "QM_TM_MoveSL(ticket, catastrophic_sl, \"LRC_CATASTROPHIC_BACKSTOP\")" in source
    assert "QM_TM_ClosePosition(ticket, QM_EXIT_TRAILING)" in source


def test_bounded_series_reads_are_guarded_and_perf_annotated() -> None:
    source = _source()

    assert "CopyClose(sym, tf, 1, window, closes)" in source
    assert "ArraySize(closes) != window" in source
    for line in source.splitlines():
        if re.search(r"\b(?:CopyClose|Bars|iClose|iTime|iBarShift)\s*\(", line):
            assert "perf-allowed" in line.lower(), line


def test_setfile_cohort_matches_card_and_risk_contract() -> None:
    setfiles = sorted(SETS.glob("*.set"))
    symbols = {path.name.removeprefix(f"{EA_LABEL}_").split("_D1_backtest.set")[0] for path in setfiles}

    assert symbols == APPROVED_SYMBOLS
    for path in setfiles:
        values = _set_values(path)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["PORTFOLIO_WEIGHT"] == "1"
        assert "strategy_spread_max_atr" not in values


def test_xti_registry_gap_is_append_only_and_resolved() -> None:
    with MAGIC_CSV.open(encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "9909"]

    xti = [row for row in rows if row["symbol"] == "XTIUSD.DWX"]
    assert len(xti) == 1
    assert xti[0]["symbol_slot"] == "13"
    assert xti[0]["magic"] == "99090013"
    assert xti[0]["status"] == "active"
    assert "99090013" in MAGIC_RESOLVER.read_text(encoding="utf-8")


def test_spec_and_build_identity_are_review_complete() -> None:
    spec = SPEC.read_text(encoding="utf-8")
    result = json.loads(BUILD_IDENTITY.read_text(encoding="utf-8"))
    required = {
        "task_id",
        "ea_id",
        "ea_dir",
        "mq5_path",
        "ex5_path",
        "magic_base",
        "symbols_registered",
        "setfiles_generated",
        "spec_md_path",
        "build_check_passed",
        "compile_succeeded",
        "smoke_result",
        "smoke_report_path",
        "blocked_reason",
        "open_questions",
    }

    assert "strategy_spread_max_atr" not in spec
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec
    assert required <= result.keys()
    assert result["task_id"] == "d6ea3abe-d44b-4861-b466-475a28899eaa"
    assert result["ea_id"] == "QM5_9909"
    assert result["magic_base"] == 99090000
    assert set(result["symbols_registered"]) >= APPROVED_SYMBOLS
    assert set(result["symbols_built"]) == APPROVED_SYMBOLS
    if result["compile_succeeded"]:
        assert result["build_check_passed"] is True
        assert result["ex5_path"]
    else:
        assert result["compile_status"] == "PENDING_GOVERNED_WORKER"
        assert result["compile_work_item_id"]
        assert result["ex5_path"] is None
        assert result["blocked_reason"]
    assert result["smoke_result"] in {"passed", "deferred_p2_smoke"}
    if result["smoke_result"] == "deferred_p2_smoke":
        assert result["blocked_reason"]
