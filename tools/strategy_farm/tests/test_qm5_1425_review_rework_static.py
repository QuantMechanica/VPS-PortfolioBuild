from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
EA = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_1425_classical-triple-bottom-reversal-h4"
    / "QM5_1425_classical-triple-bottom-reversal-h4.mq5"
)


def _source() -> str:
    return EA.read_text(encoding="utf-8")


def _compact(value: str) -> str:
    return "".join(value.split())


def _function(source: str, name: str, next_name: str) -> str:
    start = source.index(name)
    end = source.index(next_name, start)
    return source[start:end]


def test_pivots_are_newest_first_significant_and_consecutive() -> None:
    source = _source()
    compact = _compact(source)

    assert "STRATEGY_TROUGH_CONTEXT_BARS=20" in compact
    assert "surrounding_count==STRATEGY_TROUGH_CONTEXT_BARS" in compact
    assert "strategy_trough_depth_atr*atr" in compact
    assert "for(ints=start_shift+w;s<=start_shift+count-1-w;++s)" in compact
    assert "constinti2=i3+1;" in compact
    assert "constinti1=i3+2;" in compact
    assert "s_t3<s_t2&&s_t2<s_t1" in compact
    assert "s_t1<strategy_lookback_min_bars" in compact


def test_intervening_peak_gate_requires_exactly_one_per_interval() -> None:
    compact = _compact(_source())

    assert "p12_count++;" in compact
    assert "p23_count++;" in compact
    assert "if(p12_count!=1||p23_count!=1)continue;" in compact
    assert "strategy_peak_amplitude_min_atr*atr" in compact
    assert "strategy_peak_equal_atr*atr" in compact


def test_entry_is_a_twelve_bar_buy_stop_and_state_commits_after_acceptance() -> None:
    source = _source()
    entry = _compact(_function(source, "bool Strategy_EntrySignal", "void Strategy_CommitAcceptedSetup"))
    on_tick = _compact(_function(source, "void OnTick", "void OnTimer"))

    assert "req.type=QM_BUY_STOP;" in entry
    assert "req.type=QM_BUY;" not in entry
    assert "req.price=entry_price;" in entry
    assert "req.expiration_seconds=strategy_breakout_recency_bars*tf_seconds;" in entry
    assert "MathMax(trough_sl,capped_sl)" in entry
    assert "strategy_breakout_recency_bars+20" not in source
    assert "rates[1].close<trigger_level" not in entry
    assert "if(QM_TM_OpenPosition(req,out_ticket))Strategy_CommitAcceptedSetup();" in on_tick
    assert on_tick.index("QM_TM_OpenPosition(req,out_ticket)") < on_tick.index(
        "Strategy_CommitAcceptedSetup()"
    )


def test_pending_invalidation_and_restart_state_are_persistent() -> None:
    source = _source()
    compact = _compact(source)

    assert "GlobalVariableSet(Strategy_StateKey(\"state\")" in compact
    assert "GlobalVariableGet(Strategy_StateKey(\"neck\"))" in compact
    assert "GlobalVariableGet(Strategy_StateKey(\"tp1\"))" in compact
    assert "GlobalVariableGet(Strategy_StateKey(\"invalid\"))" in compact
    assert "Strategy_RestoreExecutionState()" in compact
    assert "QM_TM_RemovePendingOrder(ticket,\"QM5_1425_PATTERN_INVALIDATED\")" in compact
    assert "Strategy_PersistSetup(2);" in compact
    assert "Strategy_PersistBlockUntil();" in compact


def test_macro_bias_and_news_window_match_the_card() -> None:
    compact = _compact(_source())

    assert "QM_SMA(_Symbol,PERIOD_D1,strategy_macro_sma_period,1,PRICE_CLOSE)" in compact
    assert "QM_SMA(_Symbol,PERIOD_D1,strategy_macro_sma_period,2,PRICE_CLOSE)" in compact
    assert "return(sma_newer>=sma_older);" in compact
    assert "STRATEGY_NEWS_WINDOW_BARS=2" in compact
    assert "if(window_minutes!=480)returnfalse;" in compact
    assert "QM_NewsInWindow(utc_time,_Symbol,480,480,\"HIGH\")" in compact


def test_framework_corset_and_all_strategy_inputs_are_wired() -> None:
    source = _source()
    compact = _compact(source)

    assert "#include<QM/QM_Common.mqh>" in compact
    assert "QM_FrameworkTrackOpenPositionMae();" in source
    assert "QM_FrameworkDeclareExecutionContract(PERIOD_H4" in compact
    assert "QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE" in source
    assert "QM_FrameworkMagic()" in source
    assert "RISK_PERCENT" in source and "RISK_FIXED" in source
    assert "CopyBuffer(" not in source
    assert not re.search(r"\bi(?:ATR|MA)\s*\(", source)
    assert "CopyRates(_Symbol,strategy_tf,0,fetch_bars,rates);//perf-allowed" in compact
    assert "ArraySize(rates)<fetch_bars" in compact

    strategy_inputs = re.findall(
        r"^input\s+[^\r\n=]+?\s+(strategy_[A-Za-z0-9_]+)\s*=",
        source,
        flags=re.MULTILINE,
    )
    assert strategy_inputs
    for input_name in strategy_inputs:
        assert len(re.findall(rf"\b{re.escape(input_name)}\b", source)) >= 2, input_name
