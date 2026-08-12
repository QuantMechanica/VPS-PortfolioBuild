from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
JOINT = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_20181_ftmo-joint-multisym-timer"
    / "QM5_20181_ftmo-joint-multisym-timer.mq5"
)
STANDALONE = (
    REPO
    / "framework"
    / "EAs"
    / "QM5_10145_tsm-meanret"
    / "QM5_10145_tsm-meanret.mq5"
)
STANDALONE_SET = STANDALONE.parent / "sets" / (
    "QM5_10145_tsm-meanret_XAUUSD.DWX_D1_backtest.set"
)
BOOK2_SET = JOINT.parent / "sets" / (
    "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book2_9936_10145.set"
)
BOOK3_SET = JOINT.parent / "sets" / (
    "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set"
)


def _source(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _function_body(source: str, name: str) -> str:
    signature = source.index(f"{name}(")
    opening = source.index("{", signature)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def _set_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in _source(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _input_default(source: str, name: str) -> str:
    match = re.search(
        rf"^\s*input\s+[^;=]+\s+{re.escape(name)}\s*=\s*([^;]+);",
        source,
        re.MULTILINE,
    )
    assert match is not None, f"missing input {name}"
    return match.group(1).strip()


def test_10145_book_parameters_and_effective_news_axes_match_standalone() -> None:
    standalone_source = _source(STANDALONE)
    joint_source = _source(JOINT)
    standalone_set = _set_values(STANDALONE_SET)

    parameter_map = {
        "strategy_lookback_n": "s1_lookback_n",
        "strategy_shorts_enabled": "s1_shorts_enabled",
        "strategy_atr_period": "s1_atr_period",
        "strategy_atr_stop_mult": "s1_atr_stop_mult",
        "strategy_min_abs_mean_return": "s1_min_abs_mean_return",
    }
    for standalone_name, joint_name in parameter_map.items():
        assert _input_default(standalone_source, standalone_name) == _input_default(
            joint_source, joint_name
        )

    for book_path in (BOOK2_SET, BOOK3_SET):
        book = _set_values(book_path)
        assert book["RISK_PERCENT"] == standalone_set["RISK_PERCENT"] == "0"
        assert book["s1_risk_fixed"] == standalone_set["RISK_FIXED"] == "1000"
        assert book["s1_enabled"] == "1"
        assert book["s1_symbol"] == "XAUUSD.DWX"

        # The standalone set pins FW1 mode 3 / compliance 1.  Joint book sets
        # intentionally inherit the equivalent named enum defaults.
        assert standalone_set["qm_news_temporal"] == "3"
        assert standalone_set["qm_news_compliance"] == "1"
        assert _input_default(joint_source, "qm_news_temporal") == (
            "QM_NEWS_TEMPORAL_PRE30_POST30"
        )
        assert _input_default(joint_source, "qm_news_compliance") == (
            "QM_NEWS_COMPLIANCE_DXZ"
        )


def test_10145_stop_is_bound_to_closed_xauusd_d1_atr() -> None:
    run = _function_body(_source(JOINT), "QM20181_Run10145")
    compact = "".join(run.split())

    assert "QM_ATR(sat.symbol,PERIOD_D1,s1_atr_period,1)" in compact
    assert "QM_StopATRFromValue(sat.symbol,side,entry,atr," in compact
    assert "QM_StopATR(sat.symbol" not in compact
    assert "if(atr<=0.0||sl<=0.0||point<=0.0)" in compact
    assert "if(side==QM_BUY&&sl>=entry)" in compact
    assert "if(side==QM_SELL&&sl<=entry)" in compact
    assert "QM_LotsForRiskAtEntry(sat.symbol," in compact
    assert "margin_order_type,entry,QM_RISK_MODE_FIXED,sat.risk_fixed)" in compact
    assert "QM_LotsForRisk(sat.symbol" not in compact


def test_10145_fw1_news_is_symbol_specific_and_d1_cached() -> None:
    source = _source(JOINT)
    news = _function_body(source, "QM20181_10145NewsAllows")
    run = _function_body(source, "QM20181_Run10145")
    compact_news = "".join(news.split())
    compact_run = "".join(run.split())

    assert "qm_news_temporal!=QM_NEWS_TEMPORAL_OFF" in compact_news
    assert "qm_news_compliance!=QM_NEWS_COMPLIANCE_NONE" in compact_news
    assert "QM_NewsAllowsTrade2(sat.symbol,broker_now," in compact_news
    assert "qm_news_temporal,qm_news_compliance)" in compact_news
    assert "QM_NewsAllowsTrade(sat.symbol,broker_now," in compact_news
    assert "sat.news_bar_time!=current_bar" in compact_news
    assert "sat.news_evaluated" in compact_news
    assert "qm_news_mode_legacy==QM_NEWS_NEWS_ONLY" in compact_news
    news_only = compact_news.index("qm_news_mode_legacy==QM_NEWS_NEWS_ONLY")
    d1_snapshot = compact_news.index("if(sat.news_bar_time!=current_bar)")
    assert news_only < d1_snapshot

    # Standalone order is news -> Friday close -> exit -> one D1 new-bar consume.
    news_gate = compact_run.index("QM20181_10145NewsAllows(")
    friday = compact_run.index("QM_FrameworkFridayCloseNow(broker_now)")
    exit_check = compact_run.index("constboolshould_close=")
    new_bar = compact_run.index("QM_IsNewBar(sat.symbol,PERIOD_D1)")
    assert news_gate < friday < exit_check < new_bar
    assert "QM_FrameworkHandleFridayClose()" in compact_run


def test_10145_waits_for_a_fresh_symbol_tick_before_consuming_new_bar() -> None:
    source = _source(JOINT)
    fresh = _function_body(source, "QM20181_10145FreshD1Tick")
    run = _function_body(source, "QM20181_Run10145")
    compact_fresh = "".join(fresh.split())
    compact_run = "".join(run.split())

    assert "SymbolInfoTick(sat.symbol,tick)" in compact_fresh
    assert "tick.time_msc" in compact_fresh
    assert "tick_msc<=sat.last_observed_tick_msc" in compact_fresh
    assert "iTime(sat.symbol,PERIOD_D1,0)" in compact_fresh
    assert "tick.time<current_bar" in compact_fresh

    fresh_call = compact_run.index("QM20181_10145FreshD1Tick(")
    new_bar = compact_run.index("QM_IsNewBar(sat.symbol,PERIOD_D1)")
    assert fresh_call < new_bar
    assert compact_run.count("QM_IsNewBar(sat.symbol,PERIOD_D1)") == 1
    assert "closed_bar==sat.last_closed_bar" not in compact_run
    assert "GlobalVariable" not in run


def test_10145_preserves_same_bar_close_then_reverse_semantics() -> None:
    run = "".join(_function_body(_source(JOINT), "QM20181_Run10145").split())

    first_position = run.index("if(mean_valid&&QM20181_HasPosition(sat,ticket))")
    close = run.index("QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY)")
    new_bar = run.index("QM_IsNewBar(sat.symbol,PERIOD_D1)")
    second_position = run.index("if(QM20181_HasPosition(sat,ticket))", first_position + 1)
    side_selection = run.index("constdoublethreshold=MathMax(")
    open_position = run.index("QM_BasketOpenPosition(")
    assert first_position < close < new_bar < second_position < side_selection < open_position


def test_20181_remains_backtest_only_and_safety_gated() -> None:
    source = _source(JOINT)
    init = "".join(_function_body(source, "OnInit").split())
    timer = "".join(_function_body(source, "OnTimer").split())
    run = "".join(_function_body(source, "QM20181_Run10145").split())

    assert "if(!MQLInfoInteger(MQL_TESTER))" in init
    assert "if(RISK_PERCENT>0.0)" in init
    assert "if(prop_phase!=QM_PROP_PHASE_OFF)" in init
    assert "if(qm_stress_reject_probability!=0.0)" in init
    assert "if(!EventSetTimer(1))" in init
    assert "refusingsilentsatellitedisablement" in init.lower()
    assert "sleeve-1D1historywarmupfailed" in init
    assert "if(!QM_KillSwitchCheck())" in timer
    assert "QM_BasketOpenPosition(qm_ea_id,qm_news_mode_legacy,20,req,ticket)" in run


def test_10145_replay_state_is_not_terminal_global_state() -> None:
    source = _source(JOINT)
    s1_init_start = source.index("if(s1_enabled)")
    s2_init_start = source.index("if(s2_enabled)", s1_init_start)
    s1_init = source[s1_init_start:s2_init_start]

    assert "GlobalVariableCheck" not in s1_init
    assert "GlobalVariableGet" not in s1_init
    assert "last_closed_bar = 0;" in s1_init
    assert "last_observed_tick_msc = 0;" in s1_init
