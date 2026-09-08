"""Contract checks for the visual-only QM5_11421 Strategy Console canary."""
from pathlib import Path
import re
import subprocess

REPO = Path(__file__).resolve().parents[3]
SOURCE = REPO / "framework/EAs/QM5_11421_ohlc-daily-squeeze-reversal-d1/QM5_11421_ohlc-daily-squeeze-reversal-d1.mq5"


def function_body(text, name):
    match = re.search(r"\b(?:void|bool|int|double|string)\s+" + re.escape(name) + r"\s*\([^)]*\)\s*\{", text)
    assert match, name
    start = match.end() - 1
    depth = 0
    for i in range(start, len(text)):
        depth += (text[i] == "{") - (text[i] == "}")
        if depth == 0:
            return text[start:i + 1]
    raise AssertionError("unbalanced function " + name)


def test_console_lifecycle_is_timer_only_and_fail_inert():
    text = SOURCE.read_text(encoding="utf-8")
    init = function_body(text, "OnInit")
    assert init.index("QM_FrameworkSetChartUISuppressed(true)") < init.index("QM_FrameworkInit")
    assert "qm_show_chart_panel && qm_apply_chart_scheme" in init
    assert "MQLInfoInteger(MQL_TESTER)==0 && MQLInfoInteger(MQL_OPTIMIZATION)==0" in init
    assert "if(!QM_FrameworkSetChartUISuppressed" not in init
    assert "EventSetTimer(5)" in init
    assert "QM11421_RefreshChartPanel();" in function_body(text, "OnTimer")
    assert "g_qm_signature_panel" not in function_body(text, "OnTick")
    assert "g_qm_signature_panel.InvalidatePerformance();" in function_body(text, "OnTradeTransaction")
    assert "g_qm_signature_panel.OnChartEvent(id,sparam);" in function_body(text, "OnChartEvent")
    assert "Refresh(" not in function_body(text, "OnChartEvent")
    assert "qm_news_stale_max_hours      = 336" in text


def test_strategy_paths_are_byte_identical_to_pre_console_commit():
    current = SOURCE.read_text(encoding="utf-8")
    baseline = subprocess.check_output(
        ["git", "show", "db44a0983a:" + SOURCE.relative_to(REPO).as_posix()],
        cwd=REPO, text=True, encoding="utf-8",
    )
    for name in ("SqueezePipFactor", "Strategy_NoTradeFilter", "Strategy_EntrySignal",
                 "Strategy_ManageOpenPosition", "Strategy_ExitSignal",
                 "Strategy_NewsFilterHook", "QM_PendingTTLSeconds", "OnTick", "OnTester"):
        assert function_body(current, name) == function_body(baseline, name), name


def test_explicit_display_recovery_can_resume_observer_without_click_refresh():
    text = SOURCE.read_text(encoding="utf-8")
    event = function_body(text, "OnChartEvent")
    guard = "if(!g_qm_fw_timer_active && g_qm_signature_panel.Ready())"
    assert event.index("g_qm_signature_panel.OnChartEvent(id,sparam);") < event.index(guard)
    assert event.index(guard) < event.index("EventSetTimer(5)")
    assert "g_qm_fw_timer_active=true;" in event
    assert "else\n         g_qm_signature_panel.Shutdown();" in event
    for forbidden in ("Refresh(", "QM11421_RefreshChartPanel(", "Initialize(",
                      "History", "SymbolInfoTick", "OrderSend", "OnInit(", "OnDeinit("):
        assert forbidden not in event
    observer = function_body(text, "QM11421_RefreshChartPanel")
    assert "if(!g_qm_signature_panel.Ready()) return;" in observer


def test_snapshot_uses_real_gates_and_does_not_call_strategy_for_display():
    text = SOURCE.read_text(encoding="utf-8")
    producer = function_body(text, "QM11421_RefreshChartPanel")
    for token in ("snapshot.Reset()", "g_qm_news_cache_verdict", "g_qm_news_cache_wall_utc",
                  "g_qm_ks_halted", "clock.day_of_week==5", "strategy_spread_cap_pips>0.0",
                  "snapshot.positions==0 && snapshot.pending_orders==0",
                  "QM_RuntimeExecutionGovernorRequired()", "g_qm_risk_per_trade_cap_pct"):
        assert token in producer
    assert "Strategy_NoTradeFilter(" not in producer
    assert "Strategy_EntrySignal(" not in producer
    assert "QM_KillSwitchCheck(" not in producer
    assert "QM_NewsAllowsTrade" not in producer
    assert "QM_RiskSizerRiskMoney(" not in producer
    assert "g_qm_ks_day_start_equity" not in producer
    assert "Daily DD" not in producer
    assert 'snapshot.timeframe=QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period)' in producer
    assert "MQL_PROGRAM_NAME" in function_body(text, "QM11421_ConsoleStrategyName")


def test_display_inputs_are_real_and_do_not_enter_trading_paths():
    text = SOURCE.read_text(encoding="utf-8")
    inputs = ("qm_show_chart_panel", "qm_dashboard_mode", "qm_visual_scale", "qm_number_locale",
              "qm_show_active_range", "qm_show_strategy_levels", "qm_show_trade_levels",
              "qm_show_trade_markers")
    trading = function_body(text, "OnTick") + function_body(text, "Strategy_EntrySignal")
    for name in inputs:
        assert re.search(r"input\s+\w+\s+" + name + r"\s*=", text)
        assert text.count(name) >= 2
        assert name not in trading
    assert "QM_FrameworkSetChartUISuppressed(true)" in text
