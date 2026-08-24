from __future__ import annotations

import re
from pathlib import Path

from tools.strategy_farm import build_gate_hardening


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_LABEL = "QM5_37004_volatility-targeted-momentum-kelly"
EA_DIR = REPO_ROOT / "framework" / "EAs" / EA_LABEL
EA_SOURCE = EA_DIR / f"{EA_LABEL}.mq5"
SPEC = EA_DIR / "SPEC.md"
CARD_MIRROR = EA_DIR / "docs" / "strategy_card.md"
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


def _canonical_card_text(path: Path) -> str:
    return "\n".join(
        line.rstrip()
        for line in path.read_text(encoding="utf-8-sig").splitlines()
    ).strip()


def test_approved_card_mirror_is_content_equivalent() -> None:
    mirror = _canonical_card_text(CARD_MIRROR)
    assert mirror == _canonical_card_text(APPROVED_CARD)
    assert "g0_status: APPROVED" in mirror


def test_current_hardening_passes_against_approved_card() -> None:
    result = build_gate_hardening.analyze_file(EA_SOURCE, APPROVED_CARD)
    assert result["failures"] == []
    assert result["warnings"] == []


def test_exponential_momentum_volatility_target_and_half_kelly_are_wired() -> None:
    source = _source()
    refresh = _function_body(source, "AdvanceState_OnNewBar")
    risk = _function_body(source, "Strategy_ResolveScaledRisk")

    assert "CopyClose(_Symbol, PERIOD_D1, 1, close_count, closes)" in refresh
    assert "ArrayResize(closes, close_count)" in refresh
    assert "ArraySize(closes) < close_count" in refresh
    assert "i + 1 < ArraySize(closes)" in refresh
    assert "if(i >= ArraySize(closes))" in refresh
    assert "if(i + 1 >= ArraySize(closes))" in refresh
    assert "momentum_terms != strategy_momentum_days" in refresh
    assert "volatility_terms != STRATEGY_VOL_LOOKBACK_DAYS" in refresh
    assert "deviation_terms != STRATEGY_VOL_LOOKBACK_DAYS" in refresh
    assert "alpha = 2.0 / ((double)strategy_momentum_days + 1.0)" in refresh
    assert "momentum_weight *= decay" in refresh
    assert "MathLog(closes[i] / closes[i + 1])" in refresh
    assert "STRATEGY_VOL_LOOKBACK_DAYS = 20" in source
    assert "MathSqrt(252.0)" in refresh
    assert "strategy_kelly_fraction * full_kelly" in refresh
    assert "strategy_vol_target_pct / 100.0" in refresh
    assert "RISK_FIXED * g_cached_position_weight" in risk
    assert "MathMin(RISK_PERCENT, strategy_base_risk_percent)" in risk
    assert "QM_TM_OpenPosition(req, out_ticket, 0, risk_mode, risk_value)" in source


def test_card_loss_rails_and_slippage_ceiling_are_wired() -> None:
    source = _source()
    no_trade = _function_body(source, "Strategy_NoTradeFilter")
    total_stop = _function_body(source, "Strategy_EnforceTotalDrawdownStop")
    on_init = _function_body(source, "OnInit")

    assert "QM_ChartUITodayPnL(0, closed_trades)" in no_trade
    assert "strategy_daily_loss_halt_pct" in no_trade
    assert "QM_KillSwitchInit(qm_ea_id" in on_init
    assert "strategy_daily_hard_stop_pct" in on_init
    assert "strategy_total_dd_halt_pct" in on_init
    assert "strategy_base_risk_percent" in on_init
    assert "QM_KillSwitchTrip(KS_PORTFOLIO_DD" in total_stop
    assert "strategy_total_dd_halt_pct" in total_stop
    assert "strategy_max_slippage_ticks *" in on_init
    assert "QM_EntryConfigure(qm_ea_id" in on_init


def test_management_and_exit_precede_entry_only_filters() -> None:
    on_tick = _function_body(_source(), "OnTick")

    manage = on_tick.index("Strategy_ManageOpenPosition();")
    exit_signal = on_tick.index("if(Strategy_ExitSignal())")
    news = on_tick.index("if(Strategy_NewsFilterHook(broker_now))")
    no_trade = on_tick.index("if(Strategy_NoTradeFilter())")
    assert manage < exit_signal < news < no_trade


def test_every_declared_input_has_an_executable_use_site() -> None:
    source = _source()
    names = re.findall(
        r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*=",
        source,
        flags=re.MULTILINE,
    )

    assert names
    unused = [
        name
        for name in names
        if len(re.findall(rf"\b{re.escape(name)}\b", source)) < 2
    ]
    assert unused == []


def test_framework_magic_mae_perf_no_ml_and_setfile_contract() -> None:
    source = _source()
    spec = SPEC.read_text(encoding="utf-8")
    refresh = _function_body(source, "AdvanceState_OnNewBar")

    assert "#include <QM/QM_Common.mqh>" in source
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkMagic()" in source
    assert "370040000" not in source
    assert "CopyBuffer(" not in source
    assert "iMA(" not in source
    assert "iATR(" not in source

    raw_series_lines = [
        line
        for line in refresh.splitlines()
        if re.search(r"\b(?:CopyRates|CopyClose|iOpen|iClose|iHigh|iLow)\s*\(", line)
    ]
    assert len(raw_series_lines) == 1
    assert all("perf-allowed:" in line for line in raw_series_lines)

    forbidden_ml_tokens = ("tensorflow", "torch", "sklearn", "keras", "onnx")
    assert all(token not in source.lower() for token in forbidden_ml_tokens)
    assert "EA_RISK_SIZER_UNCONFIGURED" in spec
    assert "EA_INPUT_RISK_MODE_MISMATCH" not in spec

    strategy_inputs = set(
        re.findall(
            r"^input\s+[A-Za-z_][A-Za-z0-9_]*\s+(strategy_[A-Za-z0-9_]*)\s*=",
            source,
            flags=re.MULTILINE,
        )
    )
    setfiles = sorted((EA_DIR / "sets").glob("*_backtest.set"))
    assert len(setfiles) == 4
    for setfile in setfiles:
        values = _set_values(setfile)
        assert values["RISK_FIXED"] == "1000"
        assert values["RISK_PERCENT"] == "0"
        assert strategy_inputs <= values.keys()
