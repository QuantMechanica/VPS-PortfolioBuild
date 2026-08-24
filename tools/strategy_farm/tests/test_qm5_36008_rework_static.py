from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36008_nnfx-gold-kama-vortex-supertrend"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
APPROVED_CARD = (
    REPO_ROOT
    / "strategy-seeds"
    / "cards"
    / "approved"
    / f"{EA_LABEL}.md"
)


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


def test_current_hardening_passes_against_approved_card() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, APPROVED_CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_tp1_partial_close_and_protected_runner_are_wired() -> None:
    source = _source()
    manage = _function_body(source, "Strategy_ManageOpenPosition")

    assert "initial_risk / strategy_sl_atr_mult" in manage
    assert "atr_at_entry * strategy_tp1_atr_mult" in manage
    assert "volume * strategy_tp1_fraction" in manage
    assert "QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL)" in manage
    assert "QM_StopRulesPipsToPriceDistance" in manage
    assert "QM_TM_MoveSL(ticket," in manage
    assert '"NNFX_TP1_BE_PROTECTION"' in manage


def test_wae_is_a_symmetric_expansion_filter_and_runner_exit_is_kama_only() -> None:
    source = _source()
    wae = _function_body(source, "Strategy_WAEPass")
    entry = _function_body(source, "Strategy_EntrySignal")
    exit_signal = _function_body(source, "Strategy_ExitSignal")

    assert "MathAbs(momentum) > threshold" in wae
    assert "&& wae_pass" in entry
    assert "wae == 1" not in source
    assert "wae == -1" not in source
    assert "g_strategy_close_1 < g_strategy_kama_1" in exit_signal
    assert "g_strategy_close_1 > g_strategy_kama_1" in exit_signal
    assert "Strategy_Vortex" not in exit_signal
    assert "vi_plus" not in exit_signal


def test_kama_vector_is_refreshed_once_per_closed_bar_and_before_exit() -> None:
    source = _source()
    refresh = _function_body(source, "AdvanceState_OnNewBar")
    exit_signal = _function_body(source, "Strategy_ExitSignal")
    on_tick = _function_body(source, "OnTick")

    assert "Strategy_CalculateKAMA" in refresh
    assert "Strategy_CalculateKAMA" not in exit_signal
    assert "const bool is_new_bar = QM_IsNewBar(_Symbol, PERIOD_D1);" in on_tick
    assert "is_new_bar && AdvanceState_OnNewBar() && Strategy_ExitSignal()" in on_tick
    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(is_new_bar && AdvanceState_OnNewBar() && Strategy_ExitSignal())"
    )
    assert on_tick.index("Strategy_ExitSignal()") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )


def test_card_loss_rails_and_slippage_ceiling_are_wired() -> None:
    source = _source()
    no_trade = _function_body(source, "Strategy_NoTradeFilter")
    on_init = _function_body(source, "OnInit")

    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "QM_ChartUITodayPnL(0, closed_trades)" in source
    assert "QM_KillSwitchInit(qm_ea_id," in on_init
    assert "strategy_daily_hard_stop_pct," in on_init
    assert "strategy_total_dd_halt_pct," in on_init
    assert "strategy_per_trade_risk_cap_pct))" in on_init
    assert "strategy_max_slippage_ticks * tick_size / point" in on_init
    assert "QM_EntryConfigure(qm_ea_id," in on_init


def test_every_declared_input_has_an_executable_use_site_and_setfile_value() -> None:
    source = _source()
    input_names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )
    strategy_inputs = {name for name in input_names if name.startswith("strategy_")}

    assert input_names
    assert [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ] == []

    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 2
    for setfile in setfiles:
        values = _set_values(setfile)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert strategy_inputs <= values.keys()


def test_framework_magic_mae_buffers_and_no_ml_contract() -> None:
    source = _source()
    kama = _function_body(source, "Strategy_CalculateKAMA")
    tsi = _function_body(source, "Strategy_TSI")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "360080000" not in source
    assert "ArraySize(closes)" in kama
    assert "ArraySize(closes)" in tsi
    assert all(
        "perf-allowed:" in line
        for line in source.splitlines()
        if re.search(r"\b(?:CopyClose|iClose|iHigh|iLow)\s*\(", line)
    )
    forbidden_ml_tokens = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert all(token not in source.lower() for token in forbidden_ml_tokens)
