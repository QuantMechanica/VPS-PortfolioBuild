from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_39002_forexfactory-sonic-r-system"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
APPROVED_CARD = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved"
    r"\QM5_39002_forexfactory-sonic-r-system.md"
)


def _source() -> str:
    return EA_SOURCE.read_text(encoding="utf-8")


def _function_body(source: str, name: str, next_name: str) -> str:
    return source.split(name, 1)[1].split(next_name, 1)[0]


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def test_current_hardening_passes_against_owner_approved_card() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, APPROVED_CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_management_is_reachable_before_entry_only_filters() -> None:
    source = _source()
    on_tick = _function_body(source, "void OnTick()", "void OnTimer()")
    no_trade = _function_body(
        source, "bool Strategy_NoTradeFilter()", "bool Strategy_EntrySignal("
    )
    entry = _function_body(
        source, "bool Strategy_EntrySignal(", "void Strategy_ManageOpenPosition()"
    )

    assert on_tick.index("Strategy_ManageOpenPosition();") < on_tick.index(
        "if(Strategy_NoTradeFilter())"
    )
    assert "QM_TM_OpenPositionCount" not in no_trade
    assert "QM_TM_OpenPositionCount(magic) > 0" in entry
    assert "QM_TM_MoveSL(" in source
    assert '"BE_AT_ORIGINAL_1R"' in source


def test_card_loss_rails_and_exact_dragon_stop_are_wired() -> None:
    source = _source()
    entry = _function_body(
        source, "bool Strategy_EntrySignal(", "void Strategy_ManageOpenPosition()"
    )

    assert "QM_ChartUITodayPnL(0, closed_trades)" in source
    assert "strategy_daily_loss_halt_pct" in source
    assert "QM_KillSwitchInit(qm_ea_id," in source
    assert "strategy_daily_hard_stop_pct," in source
    assert "strategy_total_dd_halt_pct," in source
    assert "strategy_per_trade_risk_cap_pct))" in source
    assert "g_dragon_low - buffer" in entry
    assert "g_dragon_high + buffer" in entry
    assert "strategy_tp_rr_mult" in entry
    assert "0.5 * g_last_atr" not in entry
    assert "3.5 * g_last_atr" not in entry


def test_raw_series_reads_are_bounded_cached_and_approved() -> None:
    source = _source()
    refresh = _function_body(
        source, "void AdvanceState_OnNewBar()", "bool StrategyDailyRealizedLossHalt()"
    )
    raw_series_lines = [
        line
        for line in refresh.splitlines()
        if re.search(r"\bi(?:Close|Low|High)\s*\(", line)
    ]

    assert len(raw_series_lines) == 3
    assert all("perf-allowed:" in line for line in raw_series_lines)
    assert "CopyBuffer(" not in source
    assert "iMA(" not in source
    assert "iATR(" not in source
    assert "QM_EMA(" in refresh
    assert "QM_ATR(" in refresh


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = _source()
    input_names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert input_names
    missing = [
        name
        for name in input_names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ]
    assert missing == []


def test_v5_framework_risk_magic_mae_and_setfile_contract() -> None:
    source = _source()

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "390020000" not in source
    assert "RISK_PERCENT" in source
    assert "RISK_FIXED" in source
    assert "QM_TM_OpenPosition(req, out_ticket);" in source

    forbidden_ml_tokens = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert all(token not in source.lower() for token in forbidden_ml_tokens)

    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 3
    for setfile in setfiles:
        values = _set_values(setfile)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
