from __future__ import annotations

import csv
import hashlib
import math
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
    / "QM5_13108_xti-mtsm-s2"
    / "QM5_13108_xti-mtsm-s2.mq5"
)
STANDALONE_SET = STANDALONE.parent / "sets" / (
    "QM5_13108_xti-mtsm-s2_XTIUSD.DWX_D1_backtest.set"
)
BOOK3_SET = JOINT.parent / "sets" / (
    "QM5_20181_ftmo-joint-multisym-timer_USDJPY.DWX_H1_book3_9936_10145_13108.set"
)
SPEC = JOINT.parent / "SPEC.md"
OWNER_LOCK = (
    REPO
    / "docs"
    / "ops"
    / "evidence"
    / "2026-07-29_qm5_20181_slot2_owner_lock.md"
)
REGISTRY = REPO / "framework" / "registry" / "magic_numbers.csv"
RESOLVER = REPO / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"


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


def _compact(value: str) -> str:
    return "".join(value.split())


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


def _resolver_array(source: str, name: str) -> list[int]:
    match = re.search(
        rf"{re.escape(name)}\[QM_MAGIC_REGISTRY_ROWS\]\s*=\s*\{{([^}}]*)\}}",
        source,
    )
    assert match is not None, f"missing resolver array {name}"
    return [int(value.strip()) for value in match.group(1).split(",")]


def _nearest_rank(values: list[float], percentile: float) -> float:
    rank = math.ceil(percentile * len(values) / 100.0) - 1
    return sorted(values)[max(0, min(len(values) - 1, rank))]


def _region_target(
    current_upm: float,
    current_lpm: float,
    up_reference: float,
    low_reference: float,
    momentum_return: float,
) -> int:
    up_tail = current_upm >= up_reference
    low_tail = current_lpm >= low_reference
    if up_tail and low_tail:
        return 0
    if not up_tail and low_tail:
        return 1
    if up_tail and not low_tail:
        return -1
    return 1 if momentum_return > 0.0 else -1


def test_13108_defaults_and_book3_inputs_match_standalone() -> None:
    standalone_source = _source(STANDALONE)
    joint_source = _source(JOINT)
    standalone_set = _set_values(STANDALONE_SET)
    book = _set_values(BOOK3_SET)

    parameter_map = {
        "strategy_momentum_days": "s2_momentum_days",
        "strategy_partial_moment_days": "s2_partial_moment_days",
        "strategy_percentile_history": "s2_percentile_history",
        "strategy_tail_percentile": "s2_tail_percentile",
        "strategy_atr_period": "s2_atr_period",
        "strategy_atr_sl_mult": "s2_atr_sl_mult",
        "strategy_max_hold_days": "s2_max_hold_days",
        "strategy_max_spread_points": "s2_max_spread_points",
    }
    for standalone_name, joint_name in parameter_map.items():
        standalone_default = _input_default(standalone_source, standalone_name)
        assert standalone_default == _input_default(joint_source, joint_name)
        assert book[joint_name] == standalone_set[standalone_name]

    assert book["RISK_PERCENT"] == standalone_set["RISK_PERCENT"] == "0"
    assert book["s2_risk_fixed"] == standalone_set["RISK_FIXED"] == "1000"
    assert book["s2_enabled"] == "1"
    assert book["s2_symbol"] == "XTIUSD.DWX"


def test_13108_parameter_contract_is_not_weakened_in_joint_init() -> None:
    source = _source(JOINT)
    s2_start = source.index("if(s2_enabled)")
    s2_end = source.index("// ---- Equity sampler", s2_start)
    init = _compact(source[s2_start:s2_end])

    assert 's2_symbol!="XTIUSD.DWX"' in init
    assert "s2_momentum_days<2" in init
    assert "s2_momentum_days>250" in init
    assert "s2_partial_moment_days!=5" in init
    assert "s2_percentile_history<100" in init
    assert "s2_percentile_history>1000" in init
    assert "s2_tail_percentile!=80.0" in init
    assert "s2_atr_period<=1" in init
    assert "s2_atr_sl_mult<=0.0" in init
    assert "s2_max_hold_days<=0" in init
    assert "s2_max_hold_days>14" in init
    assert "s2_max_spread_points<0" in init
    assert (
        "MathMax(s2_momentum_days+1,"
        "s2_percentile_history+s2_partial_moment_days+1)"
    ) in init

    assert "GlobalVariableCheck" not in init
    assert "GlobalVariableGet" not in init
    assert "last_closed_bar=0;" in init


def test_13108_state_math_matches_standalone_contract() -> None:
    source = _source(JOINT)
    load = _compact(_function_body(source, "QM20181_13108LoadClosedCloses"))
    partial = _compact(_function_body(source, "QM20181_13108PartialMoments"))
    momentum = _compact(_function_body(source, "QM20181_13108MomentumReturn"))
    percentile = _compact(_function_body(source, "QM20181_13108Percentile"))
    target = _compact(_function_body(source, "QM20181_13108Target"))

    assert "CopyClose(symbol,PERIOD_D1,1,required,closes)" in load
    assert "closes[i]<=0.0||!MathIsValidNumber(closes[i])" in load
    assert "base_shift<1||s2_partial_moment_days<=0" in partial
    assert "current_close<=0.0||prior_close<=0.0" in partial
    assert "constdoublesquared=daily_return*daily_return" in partial
    assert "MathIsValidNumber(upm)&&MathIsValidNumber(lpm)" in partial
    assert "momentum_return+=daily_return" in momentum
    assert "returnMathIsValidNumber(momentum_return)" in momentum
    assert "MathCeil(percentile*count/100.0)-1" in percentile
    assert "QM20181_13108PartialMoments(closes,i+2,obs_upm,obs_lpm)" in target
    assert "historical_upm[i]=obs_upm" in target
    assert "historical_lpm[i]=obs_lpm" in target
    assert "!MathIsValidNumber(up_reference)" in target
    assert "!MathIsValidNumber(low_reference)" in target

    # Nearest-rank and all four S2 regions are pinned independently of MQL text.
    assert _nearest_rank([1.0, 5.0, 2.0, 4.0, 3.0], 80.0) == 4.0
    assert _region_target(2.0, 2.0, 1.0, 1.0, 10.0) == 0
    assert _region_target(0.0, 2.0, 1.0, 1.0, -10.0) == 1
    assert _region_target(2.0, 0.0, 1.0, 1.0, 10.0) == -1
    assert _region_target(0.0, 0.0, 1.0, 1.0, 10.0) == 1
    assert _region_target(0.0, 0.0, 1.0, 1.0, 0.0) == -1


def test_13108_uses_fresh_xti_tick_and_standalone_gate_order() -> None:
    source = _source(JOINT)
    fresh = _compact(_function_body(source, "QM20181_13108FreshD1Tick"))
    run = _compact(_function_body(source, "QM20181_Run13108"))

    assert "SymbolInfoTick(sat.symbol,tick)" in fresh
    assert "tick.time_msc" in fresh
    assert "tick_msc<=sat.last_observed_tick_msc" in fresh
    assert "iTime(sat.symbol,PERIOD_D1,0)" in fresh
    assert "tick.time<current_bar" in fresh

    fresh_tick = run.index("QM20181_13108FreshD1Tick(")
    friday = run.index("QM_FrameworkFridayCloseNow(broker_now)")
    no_trade = run.index("QM20181_13108NoTrade(sat)")
    new_bar = run.index("QM_IsNewBar(sat.symbol,PERIOD_D1)")
    target = run.index("QM20181_13108Target(")
    manage = run.index("QM20181_13108ManagePositions(")
    optional_exit = run.index("QM20181_13108ExitSignal()")
    news = run.index("QM20181_13108NewsAllows(")
    position_recheck = run.index("QM20181_HasPosition(")
    entry = run.index("QM_BasketOpenPosition(")
    assert (
        fresh_tick
        < friday
        < no_trade
        < new_bar
        < target
        < manage
        < optional_exit
        < news
        < position_recheck
        < entry
    )
    assert run.count("QM_IsNewBar(sat.symbol,PERIOD_D1)") == 1
    assert "GlobalVariable" not in run


def test_13108_management_covers_all_positions_and_allows_same_bar_reopen() -> None:
    source = _source(JOINT)
    manage = _compact(_function_body(source, "QM20181_13108ManagePositions"))
    run = _compact(_function_body(source, "QM20181_Run13108"))

    assert "for(inti=PositionsTotal()-1;i>=0;--i)" in manage
    assert "PositionGetString(POSITION_SYMBOL)!=sat.symbol" in manage
    assert "(int)PositionGetInteger(POSITION_MAGIC)!=sat.magic" in manage
    assert "broker_now-opened_at>=max_hold_seconds" in manage
    assert "!sat.state_valid||sat.target_state==0" in manage
    assert "position_state!=sat.target_state" in manage
    assert "QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY)" in manage

    manage_call = run.index("QM20181_13108ManagePositions(")
    recheck = run.index("QM20181_HasPosition(")
    open_call = run.index("QM_BasketOpenPosition(")
    assert manage_call < recheck < open_call


def test_13108_news_atr_spread_stop_and_risk_paths_match_standalone() -> None:
    source = _source(JOINT)
    news = _compact(_function_body(source, "QM20181_13108NewsAllows"))
    run = _compact(_function_body(source, "QM20181_Run13108"))

    assert "QM_NewsAllowsTrade2(sat.symbol,broker_now," in news
    assert "QM_NewsAllowsTrade2Fresh" not in news
    assert "qm_news_temporal,qm_news_compliance)" in news
    assert "QM_NewsAllowsTrade(sat.symbol,broker_now," in news
    assert "sat.news_bar_time!=current_bar" in news
    assert "sat.news_evaluated" in news

    assert "s2_max_spread_points>0" in run
    assert "SYMBOL_SPREAD)>s2_max_spread_points" in run
    assert "QM_ATR(sat.symbol,PERIOD_D1,s2_atr_period,1)" in run
    assert "atr<=0.0||!MathIsValidNumber(atr)" in run
    assert "QM_StopATRFromValue(sat.symbol,side,entry,atr,s2_atr_sl_mult)" in run
    assert "side==QM_BUY&&sl>=entry" in run
    assert "side==QM_SELL&&sl<=entry" in run
    assert "constENUM_ORDER_TYPEmargin_order_type=QM_OrderTypeToMT5(side)" in run
    assert "QM_LotsForRiskAtEntry(sat.symbol,sl_points,margin_order_type,entry," in run
    assert "QM_RISK_MODE_FIXED,sat.risk_fixed)" in run
    assert "QM_LotsForRisk(sat.symbol" not in run
    assert '"XTI_MTSM_S2_LONG"' in run
    assert '"XTI_MTSM_S2_SHORT"' in run


def test_slot2_owner_lock_registry_and_generated_resolver_are_exact() -> None:
    owner_lock = _source(OWNER_LOCK)
    assert "QM5_13108 / XTIUSD.DWX" in owner_lock
    assert "slot 2 / magic\n`201810002`" in owner_lock
    assert "QM5_13301 is explicitly not" in owner_lock

    with REGISTRY.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    matches = [
        row
        for row in rows
        if row["ea_id"] == "20181" and row["symbol_slot"] == "2"
    ]
    assert matches == [
        {
            "ea_id": "20181",
            "ea_slug": "ftmo-joint-multisym-timer",
            "symbol_slot": "2",
            "symbol": "XTIUSD.DWX",
            "magic": "201810002",
            "reserved_at": "2026-07-29T00:00:00Z",
            "reserved_by": "OWNER-delegated Codex",
            "status": "active",
        }
    ]

    resolver = _source(RESOLVER)
    ea_ids = _resolver_array(resolver, "QM_MAGIC_REG_EA_ID")
    slots = _resolver_array(resolver, "QM_MAGIC_REG_SLOT")
    magics = _resolver_array(resolver, "QM_MAGIC_REG_MAGIC")
    assert len(ea_ids) == len(slots) == len(magics)
    assert list(zip(ea_ids, slots, magics)).count((20181, 2, 201810002)) == 1

    row_count = re.search(r"#define QM_MAGIC_REGISTRY_ROWS\s+(\d+)", resolver)
    registry_hash = re.search(
        r'#define QM_MAGIC_REGISTRY_SHA256\s+"([0-9A-F]{64})"', resolver
    )
    assert row_count is not None and int(row_count.group(1)) == len(ea_ids)
    assert registry_hash is not None
    assert registry_hash.group(1) == hashlib.sha256(REGISTRY.read_bytes()).hexdigest().upper()


def test_13108_replay_state_and_joint_ea_remain_fail_closed() -> None:
    source = _source(JOINT)
    init = _compact(_function_body(source, "OnInit"))
    timer = _compact(_function_body(source, "OnTimer"))
    spec = _source(SPEC)

    assert "if(!MQLInfoInteger(MQL_TESTER))" in init
    assert "if(RISK_PERCENT>0.0)" in init
    assert "if(prop_phase!=QM_PROP_PHASE_OFF)" in init
    assert "if(qm_stress_reject_probability!=0.0)" in init
    kill = timer.index("if(!QM_KillSwitchCheck())")
    dispatch = timer.index("for(inti=0;i<g_sat_count;++i)")
    assert kill < dispatch
    assert "process-local D1 latch" in spec
    assert "restart-persisted closed-bar timestamp" not in spec
