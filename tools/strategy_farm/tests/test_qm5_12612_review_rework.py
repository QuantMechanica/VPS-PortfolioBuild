from __future__ import annotations

import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_DIR = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_12612_tsmom-12m-vol-scaled-ndx"
)
EA_PATH = EA_DIR / "QM5_12612_tsmom-12m-vol-scaled-ndx.mq5"
SET_PATH = (
    EA_DIR
    / "sets"
    / "QM5_12612_tsmom-12m-vol-scaled-ndx_NDX.DWX_D1_backtest.set"
)


def source() -> str:
    return EA_PATH.read_text(encoding="utf-8-sig")


def function_body(code: str, name: str) -> str:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", code)
    assert match is not None, f"missing function {name}"
    start = match.end() - 1
    depth = 0
    for offset in range(start, len(code)):
        if code[offset] == "{":
            depth += 1
        elif code[offset] == "}":
            depth -= 1
            if depth == 0:
                return code[start + 1 : offset]
    raise AssertionError(f"unterminated function {name}")


def assignments(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


def test_card_mechanics_use_framework_calendar_and_one_bounded_rate_batch() -> None:
    code = source()
    load_rates = function_body(code, "Strategy_LoadClosedD1Rates")
    direction = function_body(code, "Strategy_TsmomDirection")
    realized_vol = function_body(code, "Strategy_RealizedAnnualizedVol")

    assert "QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0)" in code
    assert "QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1)" in code
    assert all(token not in code for token in ("iTime(", "iClose(", "iSpread(", "Bars("))
    assert code.count("CopyRates(") == 1
    assert "// perf-allowed:" in next(
        line for line in load_rates.splitlines() if "CopyRates(" in line
    )
    assert "required > STRATEGY_MAX_D1_BUFFER_BARS" in load_rates
    assert load_rates.count("ArraySize(rates) < required") == 2
    assert "rate_count <= strategy_lookback_d1_bars" in direction
    assert "rates[strategy_lookback_d1_bars].close" in direction
    assert "rate_count <= n" in realized_vol
    assert "if(i + 1 >= rate_count)" in realized_vol
    assert "MathSqrt(252.0)" in realized_vol


def test_rebalance_risk_and_framework_wiring_are_card_faithful() -> None:
    code = source()
    entry = function_body(code, "Strategy_EntrySignal")
    on_tick = function_body(code, "OnTick")

    assert "strategy_vol_resize_threshold" in entry
    assert "QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult)" in entry
    assert "QM_RISK_MODE_FIXED" in entry and "QM_RISK_MODE_PERCENT" in entry
    assert "QM_TM_OpenPosition(req, out_ticket, QM_FrameworkMagic(), rmode, scaled_val)" in entry
    assert entry.index("if(!QM_TM_OpenPosition") < entry.rindex(
        "g_last_entry_rebalance_key = rebalance_key;"
    )
    assert on_tick.index("QM_FrameworkTrackOpenPositionMae();") < on_tick.index(
        "QM_KillSwitchCheck()"
    )
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "QM_NewsAllowsTrade2"
    )
    assert "QM_EntryRequest req = {};" in on_tick
    assert "#include <QM/QM_Common.mqh>" in code
    assert not re.search(r"tensorflow|torch|sklearn|keras|onnx", code, re.IGNORECASE)


def test_every_declared_input_is_wired_and_setfile_is_identity_complete() -> None:
    code = source()
    input_names = re.findall(
        r"(?m)^input\s+[^\r\n=]+?\s+([A-Za-z_][A-Za-z0-9_]*)\s*=", code
    )
    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", code)) < 2
    ] == []

    values = assignments(SET_PATH)
    assert values["qm_ea_id"] == "12612"
    assert values["qm_magic_slot_offset"] == "1"
    assert values["RISK_FIXED"] == "1000"
    assert values["RISK_PERCENT"] == "0"
    assert set(input_names) <= set(values)
    assert not any(name.startswith("qm_filter_") for name in values)
