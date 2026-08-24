from __future__ import annotations

import csv
import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_36001_nnfx-classic-mcginley-ssl-wae"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
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


def test_tp1_is_partial_restart_safe_and_leaves_a_runner() -> None:
    source = _source()
    entry = _function_body(source, "Strategy_EntrySignal")
    management = _function_body(source, "Strategy_ManageOpenPosition")
    partial_state = _function_body(source, "Strategy_TP1PartialState")

    assert "req.tp = 0.0" in entry
    assert "initial_risk / strategy_sl_atr_mult" in management
    assert "strategy_tp_atr_mult * atr_at_entry" in management
    assert "volume * strategy_tp1_fraction" in management
    assert "QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL)" in management
    assert "QM_TM_MoveSL(ticket, be_sl, \"NNFX_TP1_BE_PROTECTION\")" in management
    assert "POSITION_IDENTIFIER" in management
    assert "Strategy_TP1PartialState(position_id, position_time)" in management
    assert "DEAL_POSITION_ID" in partial_state
    assert "DEAL_ENTRY_OUT" in partial_state
    assert "NNFX_TP1_BE_RESTORE" in management


def test_ssl_and_demarker_require_completed_bar_crossovers() -> None:
    source = _source()
    ssl_cross = _function_body(source, "Strategy_SSLCross")
    exit_signal = _function_body(source, "Strategy_ExitSignal")

    assert "Strategy_SSLState(shift)" in ssl_cross
    assert "Strategy_SSLState(shift + 1)" in ssl_cross
    assert "state_now == 1 && state_prev != 1" in ssl_cross
    assert "state_now == -1 && state_prev != -1" in ssl_cross
    assert "demarker_1 >= 0.70 && demarker_2 < 0.70" in exit_signal
    assert "demarker_1 <= 0.30 && demarker_2 > 0.30" in exit_signal


def test_wae_is_the_same_unsigned_expansion_gate_for_both_directions() -> None:
    source = _source()
    wae = _function_body(source, "Strategy_WAEPass")
    entry = _function_body(source, "Strategy_EntrySignal")

    assert "wae_val = MathAbs(momentum)" in wae
    assert "return (wae_val > threshold)" in wae
    assert "if(direction" not in wae
    assert entry.count("Strategy_WAEPass(wae_val, explosion_val)") == 2
    assert "Strategy_WAEPass(-1" not in source


def test_card_loss_rails_slippage_and_fixed_risk_default_are_wired() -> None:
    source = _source()
    no_trade = _function_body(source, "Strategy_NoTradeFilter")
    on_init = _function_body(source, "OnInit")

    assert "input double RISK_PERCENT                 = 0.0;" in source
    assert "Strategy_DailyRealizedLossHalt()" in no_trade
    assert "QM_ChartUITodayPnL(0, closed_trades)" in source
    assert "strategy_daily_loss_halt_pct" in source
    assert "QM_KillSwitchInit(qm_ea_id" in on_init
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_per_trade_risk_cap_pct" in on_init
    assert "strategy_max_slippage_ticks * tick_size / point" in on_init
    assert "QM_EntryConfigure(qm_ea_id" in on_init


def test_management_and_closed_bar_exit_precede_entry_only_filters() -> None:
    on_tick = _function_body(_source(), "OnTick")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    new_bar = on_tick.index("QM_IsNewBar(_Symbol, PERIOD_D1)")
    exit_signal = on_tick.index("if(Strategy_ExitSignal())")
    news = on_tick.index("if(Strategy_NewsFilterHook(broker_now))")
    no_trade = on_tick.index("if(Strategy_NoTradeFilter())")
    entry = on_tick.index("if(Strategy_EntrySignal(req))")
    assert manage < new_bar < exit_signal < news < no_trade < entry
    assert "if(!is_new_bar)" in on_tick


def test_every_declared_input_has_a_use_site_and_backtest_value() -> None:
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
    assert len(setfiles) == 5
    for setfile in setfiles:
        values = _set_values(setfile)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert strategy_inputs <= values.keys()


def test_framework_magic_mae_bounded_buffers_and_no_ml_contract() -> None:
    source = _source()
    mcginley = _function_body(source, "Strategy_McGinley")
    vortex = _function_body(source, "Strategy_Vortex")
    spec = SPEC.read_text(encoding="utf-8")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "360010000" not in source
    assert "ArraySize(closes) < bars_needed" in mcginley
    assert "ArraySize(rates) < bars_needed" in vortex
    assert "k + 1 >= ArraySize(rates)" in vortex
    raw_series_lines = [
        line
        for line in source.splitlines()
        if re.search(r"\b(?:CopyRates|CopyClose|iOpen|iClose|iHigh|iLow)\s*\(", line)
    ]
    assert len(raw_series_lines) == 2
    assert all("perf-allowed:" in line for line in raw_series_lines)
    forbidden_ml_tokens = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert all(token not in source.lower() for token in forbidden_ml_tokens)
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec


def test_magic_registry_rows_exist_without_reallocation() -> None:
    registry = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
    with registry.open(encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if row["ea_id"] == "36001"]

    assert len(rows) == 5
    assert {int(row["symbol_slot"]) for row in rows} == set(range(5))
    assert all(row["status"] == "active" for row in rows)
    assert all(
        int(row["magic"]) == 36001 * 10000 + int(row["symbol_slot"])
        for row in rows
    )
