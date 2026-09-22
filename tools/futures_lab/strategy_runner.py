"""Frozen futures signal kernels and causal, offline reference replay.

No network, provider operations, or trading.  The reference executor is deliberately
labelled as a diagnostic, not a completed Nautilus economic trial.  See
strategy_run_plan.md for the pre-economic timing/ambiguity bindings.
"""
from __future__ import annotations

import argparse
import hashlib
import heapq
import importlib.metadata
import json
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from importlib.resources import files
from functools import lru_cache
from pathlib import Path
from typing import Iterable, Iterator
from zoneinfo import ZoneInfo

from preregister import compile_plan, validate_config

NS = 1_000_000_000
MINUTE = 60 * NS
SCALE = 1_000_000_000
TICK = 250_000_000
FROZEN_SHA256 = "a91938e318e7ce5948a9b87949ae22b27af1ea3491f3d4723880385d123bea02"
FROZEN_OBJECT_SHA256 = "62a7913e17ad1c2d74be08a2513e7318fb5e70bc97423d72353a7999a0f3b942"
HERE = Path(__file__).resolve().parent
DEFAULT_CONFIG = HERE / "preregistrations/task_b86d2fbd-574d-4024-af9a-2e48ff84beb9/preregistration.json"
ARM_IDS = (
    "A1_ORB_MES_SIGNAL_MES_FILL", "A2_ORB_ES_SIGNAL_MES_FILL",
    "A3_QM_FAILED_BREAK_MES_SIGNAL_MES_FILL", "A4_ORB_MNQ_SIGNAL_MNQ_FILL",
    "A5_ORB_NQ_SIGNAL_MNQ_FILL",
)


class DataInvalid(ValueError):
    """A causal or identity requirement failed; never converted into NO_SIGNAL."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_frozen(path: Path = DEFAULT_CONFIG) -> dict:
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != FROZEN_SHA256:
        raise DataInvalid("FROZEN_CONFIG_HASH_MISMATCH")
    config = json.loads(raw)
    validate_config(config)
    plan = compile_plan(config, FROZEN_SHA256)
    if (plan["hypothesis_count"], plan["arm_count"], plan["trial_cell_count"]) != (2, 5, 60):
        raise DataInvalid("FROZEN_PLAN_COUNT_MISMATCH")
    return config


def assert_frozen(config: dict) -> None:
    payload = json.dumps(config,sort_keys=True,separators=(",",":")).encode()
    if hashlib.sha256(payload).hexdigest() != FROZEN_OBJECT_SHA256:
        raise DataInvalid("FROZEN_CONFIG_OBJECT_CHANGED")


@lru_cache(maxsize=2)
def _zone(name: str) -> ZoneInfo:
    # Do not silently use Windows/system tzdata instead of the frozen package.
    if importlib.metadata.version("tzdata") != "2026.4":
        raise DataInvalid("TZDATA_VERSION_MISMATCH")
    with files("tzdata.zoneinfo").joinpath(*name.split("/")).open("rb") as stream:
        return ZoneInfo.from_file(stream, key=name)


def timestamp_ns(value: str) -> int:
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if stamp.tzinfo is None:
        raise DataInvalid("TIMESTAMP_REQUIRES_ZONE")
    delta = stamp.astimezone(timezone.utc) - datetime(1970, 1, 1, tzinfo=timezone.utc)
    return ((delta.days * 86400 + delta.seconds) * NS + delta.microseconds * 1000)


@lru_cache(maxsize=1024)
def cash_ns(day: str, clock: str) -> int:
    stamp = datetime.fromisoformat(f"{day}T{clock}").replace(tzinfo=_zone("America/New_York"))
    return timestamp_ns(stamp.isoformat())


def check_period(config: dict, period_id: str, day: str, as_of: date) -> dict:
    assert_frozen(config)
    period = next((row for row in config["periods"] if row["id"] == period_id), None)
    if period is None or not period["start"] <= day <= period["end"]:
        raise DataInvalid("DATE_OUTSIDE_SELECTED_FROZEN_PERIOD")
    if period_id == "untouched_holdout" and as_of < date.fromisoformat(period["economic_access_not_before"]):
        raise DataInvalid("PROSPECTIVE_HOLDOUT_EMBARGO")
    return period


def candidate_contract(root: str, day: str) -> tuple[str, bool]:
    """Calendar candidate only. Actual point-in-time definitions remain required."""
    current = date.fromisoformat(day)
    if root not in ("MES", "ES", "MNQ", "NQ"):
        raise DataInvalid("UNSUPPORTED_FUTURES_ROOT")
    for year in (current.year, current.year + 1):
        for month, code in ((3, "H"), (6, "M"), (9, "U"), (12, "Z")):
            first = date(year, month, 1)
            friday = first + timedelta(days=(4-first.weekday()) % 7 + 14)
            monday = friday - timedelta(days=4)
            if current < monday:
                return f"{root}{code}{year % 10}", False
            if current == monday:
                next_month = {3: (6,"M"), 6: (9,"U"), 9: (12,"Z"), 12: (3,"H")}[month]
                next_year = year + (month == 12)
                return f"{root}{next_month[1]}{next_year % 10}", True
    raise DataInvalid("ROLL_MAP_UNRESOLVED")


@dataclass(frozen=True, slots=True)
class TradeBar:
    symbol: str
    start_ns: int
    available_ns: int
    open_raw: int
    high_raw: int
    low_raw: int
    close_raw: int
    last_source_ordinal: int = 0

    @property
    def end_ns(self) -> int:
        return self.start_ns + MINUTE

    def validate(self) -> None:
        prices = (self.open_raw, self.high_raw, self.low_raw, self.close_raw)
        if (self.start_ns % MINUTE or self.available_ns < self.end_ns
                or any(type(p) is not int or p <= 0 or p % TICK for p in prices)
                or not self.low_raw <= min(self.open_raw,self.close_raw) <= max(self.open_raw,self.close_raw) <= self.high_raw):
            raise DataInvalid("INVALID_TRADE_BAR")


def trade_bars(events: Iterable, symbol: str, *, end_watermark_ns: int) -> Iterator[TradeBar]:
    """Causal receive-order aggregation of action-T prices, exchange minute buckets.

    Only a trade in a later exchange minute finalizes an older bucket. Receive
    wall-clock time alone is not an exchange-time completeness watermark. That
    finalizing event is already consumed, so its quote is not an entry fill.
    A trade for an already finalized minute invalidates the session. No empty bar
    forward fill; an explicit end watermark is needed for the final minute.
    """
    bucket = None
    prices: list[int] = []
    ordinal = 0
    finalized = -1
    previous_recv = -1
    previous_ordinal = -1
    last_trade_sequence = None
    last_trade_ordinal = -1
    for event in events:
        if event.kind in ("mbp-1","trades"):
            from replay_adapter import data_quality_reasons
            flags_problem = data_quality_reasons(event.flags)
            if flags_problem:
                raise DataInvalid("SIGNAL_EVENT_QUALITY:"+",".join(flags_problem))
        if event.ts_recv_ns < previous_recv or event.replay_ordinal <= previous_ordinal:
            raise DataInvalid("UNRESOLVED_EVENT_ORDER")
        previous_recv, previous_ordinal = event.ts_recv_ns, event.replay_ordinal
        if event.ts_recv_ns > end_watermark_ns:
            raise DataInvalid("EVENT_BEYOND_DECLARED_WATERMARK")
        is_trade = event.kind in ("mbp-1","trades") and event.action == ord("T")
        if is_trade:
            quality = trade_event_quality(event)
            if quality:
                raise DataInvalid("SIGNAL_EVENT_QUALITY:"+",".join(quality))
            stamp = event.ts_exchange_ns // MINUTE * MINUTE
            if stamp <= finalized:
                raise DataInvalid("LATE_TRADE_AFTER_BAR_FINALIZATION")
            if type(event.source_sequence) is not int or event.source_sequence < 0:
                raise DataInvalid("TRADE_EXCHANGE_SEQUENCE_MISSING")
            if (event.source_ordinal <= last_trade_ordinal or
                    (last_trade_sequence is not None and event.source_sequence < last_trade_sequence)):
                raise DataInvalid("UNRESOLVED_DUPLICATE_TRADE_ORDER")
            last_trade_sequence,last_trade_ordinal = event.source_sequence,event.source_ordinal
            price = event.trade_price_raw
            if type(price) is not int or price <= 0 or price % TICK or event.trade_size <= 0:
                raise DataInvalid("INVALID_LAST_TRADE")
            if event.ts_exchange_ns > event.ts_recv_ns:
                raise DataInvalid("TRADE_AVAILABLE_BEFORE_EXCHANGE_TIMESTAMP")
            if bucket is not None and stamp < bucket:
                raise DataInvalid("TRADE_MINUTE_ORDER_REVERSAL")
            if bucket is not None and stamp > bucket:
                result = TradeBar(symbol,bucket,event.ts_recv_ns,prices[0],max(prices),min(prices),prices[-1],ordinal)
                result.validate()
                yield result
                finalized, bucket, prices = bucket, None, []
            if bucket is None:
                bucket = stamp
            prices.append(price)
            ordinal = event.source_ordinal
    if bucket is not None and end_watermark_ns >= bucket + MINUTE:
        result = TradeBar(symbol,bucket,end_watermark_ns,prices[0],max(prices),min(prices),prices[-1],ordinal)
        result.validate()
        yield result


def trade_event_quality(event) -> tuple[str,...]:
    """Do not turn bad clock/book data into an apparently clean signal series."""
    from replay_adapter import bbo_reasons, data_quality_reasons
    reasons = list(data_quality_reasons(event.flags))
    if event.kind == "mbp-1":
        reasons.extend(bbo_reasons(event))
    elif event.kind != "trades":
        reasons.append("UNSUPPORTED_SIGNAL_SCHEMA")
    return tuple(reasons)


@dataclass(frozen=True, slots=True)
class Intent:
    side: str
    decision_ns: int
    signal_close_ns: int
    stop_raw: int
    target_raw: int | None
    reason: str


class FrozenSignal:
    """One causal attempt. Fill range is always the micro's own range."""
    def __init__(self, config: dict, arm_id: str, day: str):
        assert_frozen(config)
        self.arm = next((row for row in config["arms"] if row["id"] == arm_id), None)
        if self.arm is None:
            raise DataInvalid("ARM_NOT_FROZEN")
        self.day = day
        self.signal_symbol, _ = candidate_contract(self.arm["signal_instrument"]["root"], day)
        self.fill_symbol, _ = candidate_contract(self.arm["fill_instrument"]["root"], day)
        self.reversion = arm_id == ARM_IDS[2]
        self.open_ns = cash_ns(day,"09:30:00")
        self.range_end = cash_ns(day,"09:35:00")
        self.entry_end = cash_ns(day,"11:30:00" if self.reversion else "15:00:00")
        self.ranges: dict[str, tuple[int,int]] = {}
        self.opening: dict[str, list[TradeBar]] = {}
        self.previous: dict[str, TradeBar] = {}
        self.consumed = False
        self.reason = "NO_CONFIRMED_SIGNAL"
        self.excursion_side: str | None = None
        self.excursion_extreme: int | None = None
        self.excursion_bars = 0

    def on_bar(self, bar: TradeBar) -> Intent | None:
        bar.validate()
        if bar.symbol not in (self.signal_symbol,self.fill_symbol):
            raise DataInvalid("UNEXPECTED_RAW_SIGNAL_SYMBOL")
        if not self.open_ns <= bar.start_ns < cash_ns(self.day,"16:00:00"):
            return None
        prior = self.previous.get(bar.symbol)
        if prior and (bar.start_ns != prior.end_ns or bar.available_ns < prior.available_ns):
            raise DataInvalid("MISSING_OR_REORDERED_SIGNAL_MINUTE")
        self.previous[bar.symbol] = bar
        if bar.start_ns < self.range_end:
            opening = self.opening.setdefault(bar.symbol,[])
            if bar.start_ns != self.open_ns + len(opening)*MINUTE:
                raise DataInvalid("INCOMPLETE_FIRST_FIVE_MINUTES")
            opening.append(bar)
            if len(opening) == 5:
                self.ranges[bar.symbol] = (min(b.low_raw for b in opening), max(b.high_raw for b in opening))
            return None
        if self.consumed or bar.symbol != self.signal_symbol:
            return None
        if bar.end_ns >= self.entry_end or bar.available_ns >= self.entry_end:
            return None
        if self.signal_symbol not in self.ranges or self.fill_symbol not in self.ranges:
            raise DataInvalid("OPENING_RANGE_NOT_AVAILABLE_AT_SIGNAL")
        low,high = self.ranges[self.signal_symbol]
        fill_low,fill_high = self.ranges[self.fill_symbol]
        if not self.reversion:
            if bar.close_raw > high:
                side,stop = "BUY",fill_low
            elif bar.close_raw < low:
                side,stop = "SELL",fill_high
            else:
                return None
            self.consumed = True
            self.reason = "FIRST_CONFIRMED_ORB_CLOSE"
            return Intent(side,bar.available_ns,bar.end_ns,stop,None,self.reason)
        below,above = bar.low_raw <= low-4*TICK, bar.high_raw >= high+4*TICK
        if (below and above) or (self.excursion_side == "BUY" and above) or (self.excursion_side == "SELL" and below):
            self.consumed,self.reason = True,"AMBIGUOUS_BOTH_SIDES"
            return None
        if self.excursion_side is None:
            if not (below or above):
                return None
            self.excursion_side = "BUY" if below else "SELL"
            self.excursion_extreme = bar.low_raw if below else bar.high_raw
        self.excursion_bars += 1
        if self.excursion_side == "BUY":
            self.excursion_extreme = min(self.excursion_extreme,bar.low_raw)
            inside = low+TICK <= bar.close_raw < high
            stop = self.excursion_extreme-2*TICK
        else:
            self.excursion_extreme = max(self.excursion_extreme,bar.high_raw)
            inside = low < bar.close_raw <= high-TICK
            stop = self.excursion_extreme+2*TICK
        if inside:
            self.consumed,self.reason = True,"FAILED_BREAK_CONFIRMED"
            return Intent(self.excursion_side,bar.available_ns,bar.end_ns,stop,(fill_low+fill_high)//2,self.reason)
        if self.excursion_bars >= 15:
            self.consumed,self.reason = True,"EXCURSION_TIMED_OUT_SOLE_ATTEMPT"
        return None

    def early_exit(self, bar: TradeBar, side: str) -> bool:
        if self.reversion or bar.symbol != self.fill_symbol or self.fill_symbol not in self.ranges:
            return False
        low,high = self.ranges[self.fill_symbol]
        return bar.close_raw < low if side == "BUY" else bar.close_raw > high


@dataclass(frozen=True, slots=True)
class SessionPolicy:
    """Bound upstream facts, not authority to call a trial economically complete."""
    day: str
    calendar_verified: bool = False
    regular_cash_session: bool = False
    news_covered: bool = False
    news_as_of_ns: int | None = None
    high_usd_event_ns: tuple[int,...] = ()
    definitions_verified: bool = False
    raw_contract_data_verified: bool = False
    stage1_technical_pass: bool = False
    input_manifest_sha256: str = ""
    fill_instrument_id: int | None = None
    calendar_basis: str = "OFFICIAL_CME"


def policy_outcome(policy: SessionPolicy, now_ns: int, stage: int) -> tuple[str,str] | None:
    if any(type(getattr(policy,field)) is not bool for field in (
        "calendar_verified","regular_cash_session","news_covered","definitions_verified",
        "raw_contract_data_verified","stage1_technical_pass")):
        raise DataInvalid("POLICY_FLAGS_REQUIRE_BOOLEAN")
    if date.fromisoformat(policy.day).weekday() >= 5:
        return "DATA_INVALID","UNSCHEDULED_WEEKEND"
    if not policy.calendar_verified:
        return "DATA_INVALID","CME_SESSION_CALENDAR_MISSING"
    _,roll = candidate_contract("MES",policy.day)
    if roll:
        return "ROLL_EXCLUDED","CALENDAR_ROLL_CUTOVER"
    if not policy.regular_cash_session:
        return "DATA_INVALID","CME_HOLIDAY_OR_EARLY_CLOSE_EXCLUDED"
    if not policy.news_covered or policy.news_as_of_ns is None:
        return "NEWS_BLACKOUT","NEWS_CALENDAR_MISSING"
    age = now_ns-policy.news_as_of_ns
    if age < 0 or age > 168*3600*NS:
        return "NEWS_BLACKOUT","NEWS_CALENDAR_STALE_OR_FUTURE_DATED"
    start,end = cash_ns(policy.day,"09:30:00"),cash_ns(policy.day,"15:59:30")
    if any(event+30*MINUTE >= start and event-30*MINUTE <= end for event in policy.high_usd_event_ns):
        return "NEWS_BLACKOUT","HIGH_USD_EVENT_WHOLE_SESSION"
    if not policy.definitions_verified:
        return "DATA_INVALID","POINT_IN_TIME_DEFINITIONS_UNVERIFIED"
    if not policy.raw_contract_data_verified:
        return "DATA_INVALID","LICENSED_RAW_DATA_OR_ORDER_PROOF_MISSING"
    if stage == 2 and not policy.stage1_technical_pass:
        return "DATA_INVALID","MNQ_IMPORT_TECHNICAL_STAGE_GATE"
    return None


def fixed_risk_size(stop_distance_raw: int, root: str, scenario: dict) -> int:
    if type(stop_distance_raw) is not int or stop_distance_raw <= 0:
        return 0
    multiplier = Decimal("5") if root == "MES" else Decimal("2") if root == "MNQ" else None
    if multiplier is None:
        raise DataInvalid("FILL_MUST_BE_MICRO")
    loss = Decimal(stop_distance_raw)/SCALE*multiplier
    costs = Decimal(str(scenario["commission_usd_round_turn_per_micro"]))
    costs += Decimal(2*scenario["slippage_ticks_per_side"])*Decimal("0.25")*multiplier
    # Project total quantity costs rather than subtracting just one contract's fees.
    return max(0,min(2,int(Decimal("100")//(loss+costs))))


def _merge_bars(signal_bars: Iterable[TradeBar], fill_bars: Iterable[TradeBar], same_symbol: bool):
    streams = [iter(fill_bars)] if same_symbol else [iter(fill_bars),iter(signal_bars)]
    # Micro range is available first on an equal timestamp, avoiding a mini-price stop.
    yield from heapq.merge(*streams,key=lambda bar: bar.available_ns)


def _validated_session_bars(bars: Iterable[TradeBar], symbol: str, day: str, end_clock: str) -> tuple[TradeBar,...]:
    opening,end = cash_ns(day,"09:30:00"),cash_ns(day,end_clock)
    rows = tuple(bar for bar in bars if opening <= bar.start_ns < end)
    expected = list(range(opening,end,MINUTE))
    if [bar.start_ns for bar in rows] != expected:
        raise DataInvalid("INCOMPLETE_CASH_MINUTE_COVERAGE:"+symbol)
    previous_available = -1
    for bar in rows:
        bar.validate()
        if bar.symbol != symbol or bar.available_ns < previous_available:
            raise DataInvalid("SIGNAL_IDENTITY_OR_AVAILABILITY_ORDER")
        previous_available = bar.available_ns
    return rows


def run_session_reference(config: dict, arm_id: str, scenario_id: str, policy: SessionPolicy,
                          signal_bars: Iterable[TradeBar], fill_bars: Iterable[TradeBar],
                          fill_events: Iterable, *, now_ns: int, mode: str = "SYNTHETIC",
                          starting_balance: Decimal = Decimal("50000"),
                          prior_high_watermark: Decimal = Decimal("50000"),
                          prior_halt: bool = False) -> dict:
    """Offline reference execution, never a frozen economic PASS.

    Iterators are not touched until period/news/roll controls pass. It consumes
    every eligible BBO mark; missing exit quotes invalidate the session. The caller
    must keep arms/scenarios in independent accounts and carry balance/watermark/
    sticky halt forward. No result-based arm or scenario selection is provided.
    """
    if mode not in ("SYNTHETIC","DEVELOPMENT_DIAGNOSTIC"):
        raise DataInvalid("REFERENCE_ENGINE_CANNOT_COMPLETE_FROZEN_ECONOMIC_TRIAL")
    check_period(config,"development",policy.day,datetime.fromtimestamp(now_ns/NS,timezone.utc).date())
    model = FrozenSignal(config,arm_id,policy.day)
    scenario = next((row for row in config["execution"]["scenarios"] if row["id"] == scenario_id),None)
    if scenario is None:
        raise DataInvalid("SCENARIO_NOT_FROZEN")
    row = {"arm_id":arm_id,"chicago_trade_date":policy.day,"signal_raw_symbol":model.signal_symbol,
           "fill_raw_symbol":model.fill_symbol,"period_id":"development","scenario_id":scenario_id,
           "input_manifest_sha256":policy.input_manifest_sha256,"config_sha256":FROZEN_SHA256,
           "classification":"MECHANICAL_SYNTHETIC" if mode == "SYNTHETIC" else "DEVELOPMENT_REFERENCE_DIAGNOSTIC",
           "frozen_trial_result_status":"NOT_RUN","economic_success_certified":False,
           "outcome":"NO_SIGNAL","reason_code":"NO_CONFIRMED_SIGNAL","net_profit_usd":"0",
           "net_R":None,"trade":None,"max_intraday_drawdown_pct":"0","max_daily_loss_pct":"0",
           "ending_balance_usd":str(starting_balance),"high_watermark_usd":str(prior_high_watermark),
           "research_halt":prior_halt,"equity_mark_count":0,"account_path_valid":True}
    row["calendar_basis"] = policy.calendar_basis
    blocked = policy_outcome(policy,now_ns,model.arm["stage"])
    if blocked:
        row.update(outcome=blocked[0],reason_code=blocked[1],net_profit_usd=None if blocked[0] == "DATA_INVALID" else "0")
        if blocked[0] == "DATA_INVALID":
            row.update(account_path_valid=False,ending_balance_usd=None)
        return row
    if len(policy.input_manifest_sha256) != 64 or any(c not in "0123456789abcdef" for c in policy.input_manifest_sha256):
        row.update(outcome="DATA_INVALID",reason_code="INPUT_MANIFEST_HASH_MISSING",net_profit_usd=None,account_path_valid=False,ending_balance_usd=None)
        return row
    if prior_halt:
        row.update(outcome="RISK_SKIP",reason_code="STICKY_RESEARCH_HALT",net_profit_usd="0")
        return row
    if type(policy.fill_instrument_id) is not int or policy.fill_instrument_id <= 0:
        row.update(outcome="DATA_INVALID",reason_code="FILL_INSTRUMENT_ID_UNBOUND",net_profit_usd=None,account_path_valid=False,ending_balance_usd=None)
        return row
    try:
        fill_bars = _validated_session_bars(fill_bars,model.fill_symbol,policy.day,"15:55:00")
        if model.signal_symbol != model.fill_symbol:
            signal_bars = _validated_session_bars(signal_bars,model.signal_symbol,policy.day,"15:00:00")
    except DataInvalid as exc:
        row.update(outcome="DATA_INVALID",reason_code=str(exc),net_profit_usd=None,account_path_valid=False,ending_balance_usd=None)
        return row
    # Adapter is imported lazily: embargo/skip cases require no event parser at all.
    from replay_adapter import QuoteGate, ReplayError
    gate = QuoteGate(max_quote_age_ns=0, instrument_id=policy.fill_instrument_id)
    bars = iter(_merge_bars(signal_bars,fill_bars,model.signal_symbol == model.fill_symbol))
    next_bar = next(bars,None)
    pending: Intent | None = None
    position = None
    exit_order = None
    balance = starting_balance
    high = max(prior_high_watermark,starting_balance)
    worst_dd = Decimal(0)
    worst_daily = Decimal(0)
    last_key = (-1,-1)
    flat_ns,deadline = cash_ns(policy.day,"15:55:00"),cash_ns(policy.day,"15:59:30")
    latency = scenario["latency_ms"]*1_000_000
    slip = scenario["slippage_ticks_per_side"]*TICK
    mult = Decimal("5") if model.arm["fill_instrument"]["root"] == "MES" else Decimal("2")
    commission = Decimal(str(scenario["commission_usd_round_turn_per_micro"]))

    def mark(price_raw: int, timestamp: int) -> Decimal:
        nonlocal high,worst_dd,worst_daily
        sign = 1 if position["side"] == "BUY" else -1
        liquidation_raw = price_raw-sign*slip
        equity = starting_balance + Decimal(sign*(liquidation_raw-position["entry_raw"]))*mult/SCALE*position["quantity"] - commission*position["quantity"]
        high = max(high,equity)
        worst_dd = max(worst_dd,(high-equity)/Decimal("50000")*100)
        worst_daily = max(worst_daily,(starting_balance-equity)/Decimal("50000")*100)
        row["equity_mark_count"] += 1
        if worst_dd >= 5 or worst_daily >= 2:
            row["research_halt"] = True
            row.setdefault("halt_first_ns",timestamp)
        return equity

    try:
        for event in fill_events:
            key = (event.ts_recv_ns,event.replay_ordinal)
            if key <= last_key:
                raise DataInvalid("REPLAY_EVENTS_NOT_STRICTLY_ORDERED")
            last_key = key
            now = event.ts_recv_ns
            # A bar finalized by this raw event may act only on a later event.
            while next_bar is not None and next_bar.available_ns < now:
                intent = model.on_bar(next_bar)
                if intent is not None and position is None and pending is None:
                    pending = intent
                if position is not None and exit_order is None and model.early_exit(next_bar,position["side"]):
                    exit_order = (next_bar.available_ns,"OPPOSITE_RANGE_CLOSE",event.replay_ordinal-1)
                next_bar = next(bars,None)
            gate.consume(event)
            if now > deadline:
                break
            if position is not None:
                exit_side = "SELL" if position["side"] == "BUY" else "BUY"
                quote = gate.execution_quote(now,exit_side,1,after_ordinal=position["entry_ordinal"],eligible_at_ns=position["entry_ns"])
                if quote.eligible:
                    mark(quote.price_raw,now)
                    stop_hit = quote.price_raw <= position["stop_raw"] if position["side"] == "BUY" else quote.price_raw >= position["stop_raw"]
                    target = position["target_raw"]
                    target_hit = target is not None and (quote.price_raw >= target if position["side"] == "BUY" else quote.price_raw <= target)
                    if exit_order is None and (stop_hit or target_hit or row["research_halt"]):
                        exit_order = (now,"STOP" if stop_hit else "TARGET_MARKETABLE" if target_hit else "RESEARCH_HALT",event.replay_ordinal)
                if now >= flat_ns and exit_order is None:
                    exit_order = (flat_ns,"FORCED_FLAT",event.replay_ordinal-1)
                if exit_order is not None:
                    executable = gate.execution_quote(now,exit_side,position["quantity"],after_ordinal=exit_order[2],eligible_at_ns=exit_order[0]+latency)
                    if executable.eligible:
                        exit_raw = executable.price_raw-slip if exit_side == "SELL" else executable.price_raw+slip
                        sign = 1 if position["side"] == "BUY" else -1
                        net = Decimal(sign*(exit_raw-position["entry_raw"]))*mult/SCALE*position["quantity"]-commission*position["quantity"]
                        balance = starting_balance+net
                        trade = {**position,"exit_raw":exit_raw,"exit_ns":now,"exit_reason":exit_order[1],"commission_usd":str(commission*position["quantity"])}
                        row.update(outcome="TRADE",reason_code=exit_order[1],trade=trade,net_profit_usd=str(net),net_R=str(net/Decimal("100")))
                        position = None
                        break
            elif pending is not None:
                if now >= model.entry_end:
                    raise DataInvalid("NO_EXECUTABLE_QUOTE_WITHIN_ENTRY_WINDOW")
                # Quote eligibility includes known continuous session status, clean
                # BBO, fresh receive time and visible size. Never a bar-close fill.
                quote = gate.execution_quote(now,pending.side,1,after_ordinal=-1,eligible_at_ns=pending.decision_ns+latency)
                if quote.eligible:
                    raw = quote.price_raw
                    sign = 1 if pending.side == "BUY" else -1
                    distance = sign*(raw-pending.stop_raw)
                    qty = fixed_risk_size(distance,model.arm["fill_instrument"]["root"],scenario)
                    if qty < 1:
                        row.update(outcome="RISK_SKIP",reason_code="FIXED_RISK_BELOW_ONE_CONTRACT")
                        pending = None
                        break
                    sized = gate.execution_quote(now,pending.side,qty,after_ordinal=-1,eligible_at_ns=pending.decision_ns+latency)
                    if not sized.eligible:
                        continue
                    position = {"side":pending.side,"entry_raw":raw+sign*slip,"entry_ns":now,
                                "entry_ordinal":event.replay_ordinal,"quantity":qty,"stop_raw":pending.stop_raw,
                                "target_raw":pending.target_raw,"signal_close_ns":pending.signal_close_ns,
                                "decision_ns":pending.decision_ns}
                    pending = None
                    opposite = "SELL" if position["side"] == "BUY" else "BUY"
                    initial_mark = gate.execution_quote(now,opposite,1,after_ordinal=-1,eligible_at_ns=now)
                    if initial_mark.eligible:
                        mark(initial_mark.price_raw,now)
        if position is not None:
            raise DataInvalid("NO_CONFIRMED_FLAT_BY_155930")
        if pending is not None:
            raise DataInvalid("CONFIRMED_SIGNAL_WITHOUT_EXECUTABLE_QUOTE")
        # Finish bar validation even in a no-trade session. Missing range remains
        # DATA_INVALID rather than a profitable omission from denominators.
        if row["outcome"] == "NO_SIGNAL":
            if last_key[0] <= deadline:
                raise DataInvalid("FILL_STREAM_HORIZON_UNPROVEN")
            while next_bar is not None:
                if next_bar.available_ns <= deadline:
                    unexecuted = model.on_bar(next_bar)
                    if unexecuted is not None:
                        raise DataInvalid("CONFIRMED_SIGNAL_WITHOUT_OBSERVED_FILL_STREAM")
                next_bar = next(bars,None)
            if model.fill_symbol not in model.ranges or model.signal_symbol not in model.ranges:
                raise DataInvalid("INCOMPLETE_FIRST_FIVE_MINUTES")
            row["reason_code"] = model.reason if row["reason_code"] == "NO_CONFIRMED_SIGNAL" else row["reason_code"]
    except (DataInvalid,ReplayError) as exc:
        row.update(outcome="DATA_INVALID",reason_code=str(exc),net_profit_usd=None,net_R=None,account_path_valid=False)
    row.update(ending_balance_usd=str(balance) if row["account_path_valid"] else None,high_watermark_usd=str(high),
               max_intraday_drawdown_pct=str(worst_dd),max_daily_loss_pct=str(worst_daily))
    return row


def readiness_plan(config: dict, day: str, *, as_of: date) -> dict:
    """Machine-actionable scoped requirements, not blanket future-data blockers."""
    check_period(config,"development",day,as_of)
    plan = compile_plan(config,FROZEN_SHA256)
    requirements = [
        ("LICENSED_RAW_EVENTS","Bind definitions/status/trades/MBP-1 only for the selected development contracts/dates; prove action-T equivalence if trades are sourced from MBP-1."),
        ("POINT_IN_TIME_DEFINITIONS_AND_ROLL","Verify tick .25, MES multiplier5 (MNQ2), raw expiry, availability, same-expiry pairs and June17 roll exclusion."),
        ("CME_SESSION_CALENDAR","Bind dated official CME full-holiday/early-close evidence for selected dates, with SHA256."),
        ("NEWS_CALENDAR_BUNDLE","Bind complete HIGH/USD coverage for selected dates, extraction refreshed <=168h before run; ±30m intersecting NY09:30..15:59:30 excludes entire session."),
        ("EVENT_ORDER_AND_STATUS_SEED","Verify action-T/order/late-event coverage and known continuous status before first executable quote; never discard invalid events silently."),
        ("NAUTILUS_FROZEN_EXECUTOR_PARITY","Wire these tested kernels to pinned Nautilus1.221.0 and reconcile signal/order/fill/fee/mark/flat parity before marking a frozen trial COMPLETE."),
        ("APPEND_ONLY_TRIAL_LEDGER","Persist all selected cells/input/config hashes before result reading; keep reruns linked, all arms/scenarios and zero-trade sessions."),
    ]
    return {"schema":"qm.futures-strategy-readiness/v1","config_sha256":FROZEN_SHA256,
            "hypothesis_count":2,"arm_count":5,"trial_cell_count":60,
            "requested_development_day":day,"development_not_blocked_until_2027":True,
            "candidate_contracts":{root:candidate_contract(root,day)[0] for root in ("MES","ES","MNQ","NQ")},
            "gaps":[{"id":key,"required_action":action} for key,action in requirements],
            "not_required_for_development":["FUTURE_NEWS_COVERAGE","PROSPECTIVE_HOLDOUT_ELAPSED","PROVIDER_CONTRACT_COSTS","NATIVE_LIVE_PLATFORM_PARITY"],
            "cells":plan["cells"],"economic_success_certified":False,
            "reference_engine":"MECHANICAL_OR_DEVELOPMENT_DIAGNOSTIC_ONLY"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config",type=Path,default=DEFAULT_CONFIG)
    parser.add_argument("--development-day",default="2019-06-03")
    parser.add_argument("--as-of",type=date.fromisoformat,default=date.today())
    parser.add_argument("--output",type=Path)
    args = parser.parse_args(argv)
    result = readiness_plan(load_frozen(args.config),args.development_day,as_of=args.as_of)
    text = json.dumps(result,indent=2)+"\n"
    if args.output:
        # Exclusive receipt. Never replace an earlier plan/result silently.
        with args.output.open("x",encoding="utf-8") as stream:
            stream.write(text)
    else:
        print(text,end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
