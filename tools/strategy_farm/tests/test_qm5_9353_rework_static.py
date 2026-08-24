from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_9353_chande-stochrsi-base-cross-h4"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
APPROVED_CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_9353_chande-stochrsi-base-cross-h4.md"
)
APPROVED_SYMBOLS = {
    "AUDUSD.DWX",
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "GDAXI.DWX",
    "NDX.DWX",
    "NZDUSD.DWX",
    "SP500.DWX",
    "UK100.DWX",
    "USDCAD.DWX",
    "USDCHF.DWX",
    "USDJPY.DWX",
    "WS30.DWX",
    "XAUUSD.DWX",
}


def _source() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    match = re.search(rf"\b{re.escape(name)}\s*\([^)]*\)\s*\{{", source)
    assert match, f"missing function {name}"
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    raise AssertionError(f"unterminated function {name}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_qm5_9353_passes_current_build_hardening() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, APPROVED_CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_stochrsi_max_supported_period_has_no_fixed_buffer() -> None:
    source = _source()
    validation = _function_body(source, "Strategy_InputsValid")
    stochrsi = _function_body(source, "ComputeStochRSIRaw")

    assert "strategy_stoch_period >= 7 && strategy_stoch_period <= 30" in validation
    assert "for(int i = 1; i < strategy_stoch_period; ++i)" in stochrsi
    assert re.search(r"\bdouble\s+[A-Za-z_][A-Za-z0-9_]*\s*\[", stochrsi) is None
    assert "rsi_vals" not in source


def test_h4_contract_and_60_minute_news_window_are_consistent() -> None:
    source = _source()
    on_init = _function_body(source, "OnInit")
    on_tick = _function_body(source, "OnTick")
    spec = SPEC.read_text(encoding="utf-8")

    assert "qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60" in source
    assert "60, 60, qm_news_stale_max_hours" in on_init
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H4" in on_init
    assert on_init.index("QM_FrameworkDeclareExecutionContract") < on_init.index(
        "Strategy_InputsValid"
    )
    assert "QM_IsNewBar(_Symbol, PERIOD_H4)" in on_tick
    assert "QM_IsNewBar()" not in on_tick
    assert "QM_NEWS_TEMPORAL_PRE60_POST60" in spec
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec


def test_management_and_exits_precede_entry_only_filters() -> None:
    on_tick = _function_body(_source(), "OnTick")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    exit_signal = on_tick.index("if(Strategy_ExitSignal())")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol, PERIOD_H4)")
    news = on_tick.index("if(Strategy_NewsFilterHook(broker_now))")
    no_trade = on_tick.index("if(Strategy_NoTradeFilter())")
    entry = on_tick.index("if(Strategy_EntrySignal(req))")
    assert manage < exit_signal < new_bar < news < no_trade < entry


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = _source()
    input_names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ] == []


def test_framework_magic_mae_series_and_no_ml_contract() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "93530000" not in source
    raw_series_lines = [
        line
        for line in source.splitlines()
        if re.search(r"\b(?:CopyRates|CopyBuffer|iOpen|iClose|iHigh|iLow|iBars|iBarShift)\s*\(", line)
    ]
    assert raw_series_lines
    assert all("perf-allowed:" in line for line in raw_series_lines)
    assert all(
        token not in source.lower()
        for token in ("tensorflow", "torch", "sklearn", "keras", "onnx")
    )


def test_setfiles_are_lf_only_fixed_risk_and_seal_news_contract() -> None:
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    symbols = {
        path.name.removeprefix(f"{EA_LABEL}_").removesuffix("_H4_backtest.set")
        for path in setfiles
    }
    assert symbols == APPROVED_SYMBOLS
    for path in setfiles:
        raw = path.read_bytes()
        values = _set_values(path)
        assert b"\r\r\n" not in raw
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert values["qm_news_temporal"] == "4"
        assert values["qm_news_compliance"] == "1"
        assert values["strategy_stoch_period"] == "14"


def test_magic_rows_exist_without_registry_reallocation() -> None:
    registry = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    with registry.open(encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "9353"]

    assert len(rows) == 13
    assert {int(row["symbol_slot"]) for row in rows} == set(range(13))
    assert all(row["status"] == "active" for row in rows)
    assert all(
        int(row["magic"]) == 9353 * 10000 + int(row["symbol_slot"])
        for row in rows
    )


def test_build_identity_is_fail_closed_while_compile_is_held() -> None:
    identity = json.loads((EA_DIR / "build_identity.json").read_text(encoding="utf-8"))
    source_sha256 = hashlib.sha256(EA_SOURCE.read_bytes()).hexdigest()

    assert identity["mq5_sha256"] == source_sha256
    assert identity["build_check_passed"] is False
    assert identity["compile_status"] == "HELD_LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert identity["ex5_binding_status"] == "STALE_PRE_REWORK_BINARY_DO_NOT_USE"
