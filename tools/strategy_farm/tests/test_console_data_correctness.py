"""ConsoleData-only accounting contract; numeric fixtures execute in native MQL.

The Python checks intentionally do not reimplement the accounting algorithm.
Run QM_ConsoleData_compile_probe.mq5 or call QM_ConsoleDataSelfTest from the
no-trade console runtime probe to execute its deterministic deal fixtures.
"""

from pathlib import Path
import re


REPO = Path(__file__).resolve().parents[3]
DATA = REPO / "framework/include/QM/QM_ConsoleData.mqh"
FIXTURES = REPO / "framework/tests/mql5/QM_ConsoleData_selftests.mqh"
PROBE = REPO / "framework/tests/mql5/QM_ConsoleData_compile_probe.mq5"


def _body(name: str) -> str:
    text = DATA.read_text(encoding="utf-8")
    match = re.search(r"\b(?:bool|void|string|double|int)\s+" + name + r"\s*\([^)]*\)\s*\{", text)
    assert match, name
    depth = 0
    for offset in range(match.end() - 1, len(text)):
        depth += (text[offset] == "{") - (text[offset] == "}")
        if not depth:
            return text[match.end() - 1:offset + 1]
    raise AssertionError(name + " is unbalanced")


def test_aggregation_is_pure_and_ownership_precedes_cashflow():
    body = _body("QM_PanelAggregatePerformance")
    assert not re.search(
        r"\b(?:History\w*|Position\w*|Order\w*|AccountInfo\w*|TimeCurrent|File\w*|Print\w*)\s*\(", body
    )
    assert body.index("QM_PanelFindTrade(trades,deals[i].position_id)") < body.index("const QMPanelDeal deal=deals[i]")
    assert "QM_PanelTradeIndex(trades,deal.position_id)" in body
    assert "if(deal.magic!=magic && (deal.entry==DEAL_ENTRY_IN" in body
    assert "QM_PanelIdentifierInSnapshot(open_ids,trades[i].position_id)" in body
    assert "QM_PanelFloatingForMagic" not in body
    assert "final_curve" not in body


def test_collector_keeps_trade_deal_costs_and_all_exit_magics():
    body = _body("QM_PanelBuildPerformance")
    for name in ("DEAL_POSITION_ID", "DEAL_MAGIC", "DEAL_ENTRY", "DEAL_TIME", "DEAL_PROFIT",
                 "DEAL_COMMISSION", "DEAL_SWAP", "DEAL_FEE"):
        assert name in body
    assert "!= magic" not in body and "!=magic" not in body
    assert "QM_PanelAggregatePerformance(deals,open_ids,magic,now,attached_at,start_equity,stats)" in body


def test_day_week_cashflow_and_closed_count_have_explicit_distinct_scopes():
    body = _body("QM_PanelAggregatePerformance")
    assert "deal.profit+deal.swap+deal.commission+deal.fee" in body
    assert "if(when>=today_start) { stats.today_net+=value; stats.today_gross+=deal.profit; }" in body
    assert "if(when>=week_start) { stats.week_net+=value; stats.week_gross+=deal.profit; }" in body
    assert "closed[i].close_time >= today_start" in body
    assert "day.day_of_week==0 ? 6 : day.day_of_week-1" in body
    text = DATA.read_text(encoding="utf-8")
    assert '" closed | net "' in text
    assert '"History scope","Closed positions | available history"' in text
    assert '"Closed-trade DD | attach equity"' in text


def test_no_sample_is_not_a_statistical_zero():
    factor = _body("QM_PanelProfitFactorText")
    assert 'stats.closed_total==0 || (stats.gross_profit==0.0 && stats.gross_loss==0.0)' in factor
    assert 'return "N/A"' in factor
    assert 'stats.profit_factor_infinite?"INF"' in factor
    assert ':"N/A"' in _body("QM_PanelWinRateText")
    populate = _body("Populate")
    for guard in ("m_stats.closed_total>0?QM_PanelMoney(m_stats.expectancy,true)",
                  "m_stats.wins>0?QM_PanelMoney(m_stats.average_win,true)",
                  "m_stats.losses>0?QM_PanelMoney(m_stats.average_loss)"):
        assert guard in populate
    assert 'snapshot.today=m_stats.error' in populate


def test_position_and_pending_sl_risk_are_not_labeled_equity_room():
    populate = _body("Populate")
    assert '"Position SL risk"' in populate and '"Pending SL risk"' in populate
    assert '"Open exposure"' not in populate
    assert "if(snapshot.pending_orders>0)" in populate
    assert 'OrderGetDouble(ORDER_PRICE_OPEN),sl,projected)' in populate
    assert "OrderSend" not in populate and "OrderSendAsync" not in populate


def test_monotonic_history_floor_is_unchanged():
    text = DATA.read_text(encoding="utf-8")
    condition = text.split("if(!m_scanned", 1)[1].split("{", 1)[0]
    assert "now_ms-m_last_scan_ms>=QM_PANEL_REFRESH_SECONDS*1000" in condition
    assert "m_dirty" not in condition
    assert "#define QM_PANEL_REFRESH_SECONDS 30" in text


def test_native_fixture_suite_is_executable_and_non_trading():
    text = FIXTURES.read_text(encoding="utf-8")
    for fixture in (
        "empty_history_has_no_statistical_sample",
        "entry_ownership_foreign_exit_and_deal_time_costs",
        "partial_exit_cashflow_without_closed_position",
        "final_exit_counts_once_and_keeps_entry_cost",
        "entry_cost_today_with_zero_closed_positions",
        "closed_curve_chronology_drawdown_and_streaks",
        "losses_only_is_real_zero_profit_factor",
        "break_even_is_a_trade_but_no_profit_factor",
        "mixed_entry_magic_cannot_be_attributed",
        "sunday_week_starts_previous_monday",
        "missing_broker_clock_is_unavailable",
    ):
        assert fixture in text
    assert not re.search(r"\b(?:OrderSend\w*|CTrade|PositionClose|HistorySelect|ChartApplyTemplate)\s*\(", text)
    probe = PROBE.read_text(encoding="utf-8")
    assert "void OnStart()" in probe and "QM_ConsoleDataSelfTest(failure)" in probe
    assert "QM_CONSOLE_DATA_SELF_TESTS PASS" in probe
