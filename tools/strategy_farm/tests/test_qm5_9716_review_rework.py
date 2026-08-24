from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
LABEL = "QM5_9716_bandy-trend-stretch-ratio-mr-index"
EA_DIR = REPO / "framework" / "EAs" / LABEL
SOURCE = EA_DIR / f"{LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
CARD = EA_DIR / "docs" / "strategy_card.md"
SETS = EA_DIR / "sets"
MAGIC_REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"

AUTHORIZED_SYMBOL_SLOTS = {
    "NDX.DWX": "1",
    "SP500.DWX": "2",
    "WS30.DWX": "4",
}


def _function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def _executable_source() -> str:
    source = SOURCE.read_text(encoding="utf-8")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", source)


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line and not line.startswith(";") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def test_approved_card_and_durable_spec_bind_d1_three_symbol_contract() -> None:
    card = CARD.read_text(encoding="utf-8")
    spec = SPEC.read_text(encoding="utf-8")

    assert "g0_status: APPROVED" in card
    assert "SP500.DWX (backtest), NDX.DWX, WS30.DWX. Daily (D1) bars only." in card
    assert "| Chart and signal timeframe | `D1` only |" in spec
    assert set(re.findall(r"`([A-Z0-9]+\.DWX)`", spec)) == set(AUTHORIZED_SYMBOL_SLOTS)
    for input_name in (
        "strategy_sma_ref_period",
        "strategy_atr_period",
        "strategy_tsr_entry_thresh",
        "strategy_tsr_exit_thresh",
        "strategy_sma_regime_period",
        "strategy_time_stop_days",
        "strategy_sl_atr_mult",
        "strategy_spread_max_atr",
        "strategy_warmup_bars",
    ):
        assert f"`{input_name}`" in spec


def test_card_mechanism_and_every_strategy_input_are_executable() -> None:
    source = _executable_source()
    names = re.findall(r"(?m)^\s*input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=", source)

    assert len(names) == 9
    assert len(names) == len(set(names))
    for name in names:
        assert len(re.findall(rf"\b{re.escape(name)}\b", source)) >= 2, name

    assert "out_tsr = (out_close1 - ref) / atr;" in source
    assert "close1 <= sma200 || tsr > strategy_tsr_entry_thresh" in source
    assert "tsr >= strategy_tsr_exit_thresh" in source
    assert "bars_held >= strategy_time_stop_days" in source
    assert "QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult)" in source
    assert "req.type = QM_SELL" not in source


def test_management_and_strategy_exits_precede_all_entry_admission_guards() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    on_tick = _function_body(source, "void OnTick()")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    exit_signal = on_tick.index("Strategy_ExitSignal()")
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < manage
    assert manage < exit_signal
    for entry_guard in (
        "QM_KillSwitchCheck()",
        "Strategy_NewsFilterHook(broker_now)",
        "QM_NewsAllowsTrade",
        "Strategy_NoTradeFilter()",
        "Strategy_EntrySignal(req)",
    ):
        assert exit_signal < on_tick.index(entry_guard), entry_guard


def test_framework_execution_risk_magic_and_performance_contracts() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    on_init = _function_body(source, "int OnInit()")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_D1," in on_init
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in on_init
    assert '"V5_WEEKEND_RISK_POLICY"' in on_init
    assert "QM_FrameworkMagic()" in source
    assert "qm_ea_id * 10000" not in source
    assert "CopyBuffer(" not in source
    assert not re.search(r"\bi(?:MA|ATR)\s*\(", source)
    assert not re.search(r"\b(?:tensorflow|torch|sklearn|keras|onnx)\b", source, re.I)
    for line in source.splitlines():
        if re.search(r"\bi(?:Close|Open|High|Low|Time|BarShift|Bars)\s*\(", line):
            assert "// perf-allowed" in line


def test_only_card_authorized_setfiles_are_delivered_at_fixed_backtest_risk() -> None:
    setfiles = sorted(SETS.glob("*_backtest.set"))
    symbols = {path.name.split(f"{LABEL}_", 1)[1].split("_D1_backtest.set", 1)[0] for path in setfiles}
    assert symbols == set(AUTHORIZED_SYMBOL_SLOTS)

    for path in setfiles:
        symbol = path.name.split(f"{LABEL}_", 1)[1].split("_D1_backtest.set", 1)[0]
        values = _set_values(path)
        assert values["qm_ea_id"] == "9716"
        assert values["qm_magic_slot_offset"] == AUTHORIZED_SYMBOL_SLOTS[symbol]
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        for strategy_input in (
            "strategy_sma_ref_period",
            "strategy_atr_period",
            "strategy_tsr_entry_thresh",
            "strategy_tsr_exit_thresh",
            "strategy_sma_regime_period",
            "strategy_time_stop_days",
            "strategy_sl_atr_mult",
            "strategy_spread_max_atr",
            "strategy_warmup_bars",
        ):
            assert strategy_input in values

    with MAGIC_REGISTRY.open(newline="", encoding="utf-8-sig") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "9716"]
    active = {(row["symbol"], row["symbol_slot"], row["magic"]) for row in rows if row["status"] == "active"}
    for symbol, slot in AUTHORIZED_SYMBOL_SLOTS.items():
        assert (symbol, slot, str(97160000 + int(slot))) in active


def test_schema_complete_build_result_and_identity_bind_exact_files() -> None:
    build_result_path = EA_DIR / "build_result.json"
    build_identity_path = EA_DIR / "build_identity.json"
    assert build_result_path.is_file()
    assert build_identity_path.is_file()

    result = json.loads(build_result_path.read_text(encoding="utf-8"))
    identity = json.loads(build_identity_path.read_text(encoding="utf-8"))
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
    }
    assert required <= result.keys()
    assert result["task_id"] == "d573fb90-49fa-4f73-87a5-4f01d0254002"
    assert result["rework_task_id"] == "a06e3ace-6c6a-437e-9a6e-da3e37700a59"
    assert result["magic_base"] == 97160000
    assert result["symbols_delivered"] == sorted(AUTHORIZED_SYMBOL_SLOTS)
    assert result["build_check_passed"] is False
    assert result["compile_succeeded"] is True
    assert result["smoke_result"] == "deferred_p2_smoke"
    assert identity["build_check_failure_class"] == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["mq5_sha256"] == result["mq5_sha256"]
    assert identity["ex5_sha256"] == result["ex5_sha256"]
    assert identity["setfiles_generated"] == result["setfiles_generated"]
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == result["mq5_sha256"]
    assert hashlib.sha256(Path(result["ex5_path"]).read_bytes()).hexdigest() == result["ex5_sha256"]
