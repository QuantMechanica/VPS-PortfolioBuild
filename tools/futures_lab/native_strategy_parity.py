"""Offline native lifecycle parity for the frozen June-2019 MES/ES slice.

This module is additive: it never rewrites the frozen reference plan, result,
raw DBN inputs, or their source files.  Raw records drive the causal signal and
execution contract.  NautilusTrader owns only the simulated order, fee, and
position lifecycle after the client-side contract has admitted a submission.

The output is a development parity diagnostic.  It is not a formal frozen
trial, provider-platform test, payout result, funded evaluation, or live-use
authorization.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import struct
from typing import Iterable

import nautilus_trader
from nautilus_trader.adapters.databento import DatabentoDataLoader
from nautilus_trader.backtest.config import BacktestEngineConfig
from nautilus_trader.backtest.engine import BacktestEngine
from nautilus_trader.backtest.models import FillModel, PerContractFeeModel
from nautilus_trader.config import LoggingConfig, StrategyConfig
from nautilus_trader.model.book import OrderBook
from nautilus_trader.model.currencies import USD
from nautilus_trader.model.data import BookOrder, QuoteTick
from nautilus_trader.model.enums import AccountType, BookType, OmsType, OrderSide
from nautilus_trader.model.identifiers import Venue
from nautilus_trader.model.objects import Money, Price, Quantity
from nautilus_trader.trading.strategy import Strategy

from replay_adapter import QuoteGate, ReplayError
from run_june2019_reference import (
    MBP,
    SCENARIOS,
    cached_records,
    extract_cash,
    mini_events,
    session_statuses,
)
from strategy_runner import (
    ARM_IDS,
    FROZEN_SHA256,
    NS,
    SCALE,
    TICK,
    DataInvalid,
    FrozenSignal,
    Intent,
    SessionPolicy,
    _merge_bars,
    _validated_session_bars,
    candidate_contract,
    cash_ns,
    fixed_risk_size,
    load_frozen,
    policy_outcome,
    sha256_file,
    trade_bars,
)
from validate_databento_pilot import official_decode


TASK_ID = "c6077f9d-31d6-417a-bb14-209af09b1b78"
HERE = Path(__file__).resolve().parent
CONTRACT_PATH = HERE / f"preregistrations/task_{TASK_ID}/execution_contract.json"
CONTRACT_SHA256 = "6fbdd2d76edb0a18f39e1d2006c2e74e17f15bd8cd1d3023403dc0689602168f"
REFERENCE_ROOT = Path("D:/QM/reports/research/futures_pivot_20260922/progress_20260922")
DEFAULT_SOURCE_PLAN = REFERENCE_ROOT / "june2019_reference_owner_month_v2/plan.json"
DEFAULT_REFERENCE_RESULT = REFERENCE_ROOT / "june2019_reference_owner_month_v2/result.json"
DEFAULT_OUTPUT = Path(
    "D:/QM/reports/research/futures_pivot_20260922/factory_outputs/"
    f"fut-native-strategy-parity/task_{TASK_ID}"
)
SOURCE_PLAN_SHA256 = "37c72f406ab6f706b992973801acea31a8607083f148388555e31eec452172b7"
REFERENCE_RESULT_SHA256 = "f94db22d244facf4638494b1076a383a8e7c35c280c5f258cb941df999448828"
IMPLEMENTATION_BASE = "4d84761d35774ff5c6bc1745edf4078091eb5672"
SOURCE_SCHEMA = "qm.futures-native-parity-plan/v1"
RESULT_SCHEMA = "qm.futures-native-parity-result/v1"
MISMATCH_SCHEMA = "qm.futures-native-parity-mismatch/v1"
MAX_REJECTION_EXAMPLES = 20


def need(condition: bool, reason: str) -> None:
    if not condition:
        raise DataInvalid(reason)


def canonical_digest(value) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    return hashlib.sha256(raw).hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_bytes())


def write_exclusive(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def file_binding(path: Path) -> dict:
    return {"path": str(path.resolve()), "sha256": sha256_file(path), "bytes": path.stat().st_size}


def verify_binding(row: dict, *, label: str = "BOUND_INPUT") -> None:
    path = Path(row["path"])
    need(path.is_file(), f"{label}_MISSING:{path}")
    need(path.stat().st_size == row["bytes"], f"{label}_SIZE_CHANGED:{path}")
    need(sha256_file(path) == row["sha256"], f"{label}_HASH_CHANGED:{path}")


def load_contract(path: Path = CONTRACT_PATH) -> dict:
    need(path == CONTRACT_PATH, "UNBOUND_EXECUTION_CONTRACT_PATH")
    need(sha256_file(path) == CONTRACT_SHA256, "EXECUTION_CONTRACT_HASH_MISMATCH")
    contract = read_json(path)
    need(contract["schema"] == "qm.futures-native-execution-contract/v1", "EXECUTION_CONTRACT_SCHEMA")
    need(contract["task_id"] == TASK_ID, "EXECUTION_CONTRACT_TASK")
    need(contract["implementation_base_commit"] == IMPLEMENTATION_BASE, "IMPLEMENTATION_BASE_CHANGED")
    need(contract["frozen_strategy_config_sha256"] == FROZEN_SHA256, "FROZEN_CONFIG_BINDING_CHANGED")
    need(contract["source_plan_sha256"] == SOURCE_PLAN_SHA256, "SOURCE_PLAN_BINDING_CHANGED")
    need(contract["source_reference_result_sha256"] == REFERENCE_RESULT_SHA256,
         "REFERENCE_RESULT_BINDING_CHANGED")
    need(contract["engine"]["version"] == "1.221.0", "ENGINE_VERSION_NOT_PINNED")
    need(contract["entry"]["quantity_policy"] == "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE",
         "QUANTITY_POLICY_CHANGED")
    need(contract["fill_and_fee"]["actual_visible_depth_required"] is True,
         "ACTUAL_DEPTH_NOT_REQUIRED")
    need(contract["scope"]["planned_session_rows"] == 180, "CONTRACT_ROW_COUNT")
    need(contract["scope"]["formal_frozen_trial_status"] == "NOT_RUN", "FORMAL_TRIAL_STATUS_CHANGED")
    return contract


def raw_quote_binding(event) -> dict:
    need(event.kind == "mbp-1", "ORDER_BINDING_REQUIRES_RAW_MBP1")
    return {
        "replay_ordinal": event.replay_ordinal,
        "source_ordinal": event.source_ordinal,
        "ts_recv_ns": event.ts_recv_ns,
        "ts_exchange_ns": event.ts_exchange_ns,
        "instrument_id": event.instrument_id,
        "publisher_id": event.publisher_id,
        "source_sequence": event.source_sequence,
        "action": event.action,
        "side": event.side,
        "flags": event.flags,
        "bid_px_raw": event.bid_px_raw,
        "ask_px_raw": event.ask_px_raw,
        "bid_size": event.bid_size,
        "ask_size": event.ask_size,
        "raw_record_sha256": hashlib.sha256(event.raw_record).hexdigest(),
        "raw_record_bytes": len(event.raw_record),
    }


def raw_to_price(value: int) -> str:
    need(type(value) is int and value > 0 and value % TICK == 0, "INVALID_RAW_PRICE")
    return f"{Decimal(value) / SCALE:.2f}"


@dataclass
class AccountCarry:
    balance: Decimal = Decimal("50000")
    high_watermark: Decimal = Decimal("50000")
    sticky_halt: bool = False
    valid: bool = True
    invalid_since: str | None = None


@dataclass
class PendingEntry:
    intent: Intent
    armed_after_ordinal: int
    frozen_quantity: int | None = None
    sizing_quote: dict | None = None


@dataclass
class PendingExit:
    side: str
    decision_ns: int
    eligible_at_ns: int
    after_ordinal: int
    reason: str


class MarkAudit:
    """Bounded-memory digest and extrema over every retained execution mark."""

    def __init__(self):
        self.digest = hashlib.sha256()
        self.count = 0
        self.first = None
        self.last = None
        self.minimum_equity = None
        self.minimum_binding = None

    def add(self, event, *, price_raw: int, equity: Decimal, phase: int = 0) -> None:
        payload = {
            "replay_ordinal": event.replay_ordinal,
            "source_ordinal": event.source_ordinal,
            "ts_recv_ns": event.ts_recv_ns,
            "ts_exchange_ns": event.ts_exchange_ns,
            "phase": phase,
            "price_raw": price_raw,
            "equity_usd": str(equity),
        }
        encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        self.digest.update(struct.pack("<I", len(encoded)))
        self.digest.update(encoded)
        if self.first is None:
            self.first = payload
        self.last = payload
        if self.minimum_equity is None or equity < self.minimum_equity:
            self.minimum_equity = equity
            self.minimum_binding = payload
        self.count += 1

    def report(self) -> dict:
        return {
            "count": self.count,
            "sha256": self.digest.hexdigest(),
            "first": self.first,
            "last": self.last,
            "minimum_equity_usd": str(self.minimum_equity) if self.minimum_equity is not None else None,
            "minimum_binding": self.minimum_binding,
        }


class ActualVisibleDepthFillModel(FillModel):
    """Fixed adverse ticks using the admitted raw quote's actual displayed size.

    This remains a backtest fill model, not proof of queue position, real
    liquidity, partial-fill behavior, or provider-platform execution.
    """

    def __init__(self, slippage_ticks: int):
        super().__init__(prob_fill_on_limit=0.0, prob_slippage=0.0, random_seed=19)
        need(type(slippage_ticks) is int and slippage_ticks in (1, 2, 4), "UNBOUND_SLIPPAGE")
        self.slippage_ticks = slippage_ticks
        self._binding = None
        self.calls = []

    def bind(self, quote: dict) -> None:
        need(self._binding is None, "UNCONSUMED_FILL_BINDING")
        need(quote["bid_size"] > 0 and quote["ask_size"] > 0, "INVALID_ACTUAL_DEPTH")
        self._binding = quote

    def get_orderbook_for_fill_simulation(self, instrument, order, best_bid, best_ask):
        need(self._binding is not None, "NATIVE_FILL_WITHOUT_RAW_BINDING")
        quote = self._binding
        self._binding = None
        need(best_bid is not None and best_ask is not None, "NATIVE_FILL_WITHOUT_BBO")
        need(int(best_bid.as_decimal() * SCALE) == quote["bid_px_raw"], "NATIVE_BID_BINDING_MISMATCH")
        need(int(best_ask.as_decimal() * SCALE) == quote["ask_px_raw"], "NATIVE_ASK_BINDING_MISMATCH")
        quantity = int(order.quantity.as_decimal())
        displayed = quote["ask_size"] if order.side == OrderSide.BUY else quote["bid_size"]
        need(1 <= quantity <= displayed, "NATIVE_ORDER_EXCEEDS_ACTUAL_VISIBLE_DEPTH")
        delta = instrument.price_increment.as_decimal() * self.slippage_ticks
        bid_fill = best_bid.as_decimal() - delta
        ask_fill = best_ask.as_decimal() + delta
        book = OrderBook(instrument_id=instrument.id, book_type=BookType.L2_MBP)
        book.add(BookOrder(OrderSide.BUY, Price.from_str(f"{bid_fill:.2f}"),
                           Quantity.from_int(quote["bid_size"]), 1), 0, 0)
        book.add(BookOrder(OrderSide.SELL, Price.from_str(f"{ask_fill:.2f}"),
                           Quantity.from_int(quote["ask_size"]), 2), 0, 0)
        self.calls.append({
            "side": order.side.name,
            "quantity": quantity,
            "displayed_size": displayed,
            "raw_record_sha256": quote["raw_record_sha256"],
            "source_ordinal": quote["source_ordinal"],
            "replay_ordinal": quote["replay_ordinal"],
            "ts_recv_ns": quote["ts_recv_ns"],
            "best_bid": str(best_bid),
            "best_ask": str(best_ask),
            "slippage_ticks": self.slippage_ticks,
        })
        return book


class NativeTranscriptStrategy(Strategy):
    """Submit an already admitted transcript; never invent or resize an order."""

    def __init__(self, orders: list[dict], instruments: dict[str, object], fill_model):
        super().__init__(StrategyConfig(strategy_id="NATIVE-PARITY-001"))
        self.orders = orders
        self.instruments = instruments
        self.fill_model = fill_model
        self.cursor = 0
        self.fills = []
        self.lifecycle = []
        self.rejections = []

    def on_start(self):
        for instrument in self.instruments.values():
            self.subscribe_quote_ticks(instrument.id)

    def on_quote_tick(self, tick):
        need(self.cursor < len(self.orders), "UNPLANNED_NATIVE_QUOTE")
        order = self.orders[self.cursor]
        instrument = self.instruments[order["raw_symbol"]]
        quote = order["quote"]
        need(tick.instrument_id == instrument.id, "NATIVE_TRANSCRIPT_INSTRUMENT_ORDER")
        need(int(tick.ts_init) == quote["ts_recv_ns"], "NATIVE_TRANSCRIPT_RECEIVE_TIME")
        need(int(tick.ts_event) == quote["ts_exchange_ns"], "NATIVE_TRANSCRIPT_EXCHANGE_TIME")
        need(str(order["quantity_policy"]) == "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE",
             "NATIVE_TRANSCRIPT_QUANTITY_POLICY")
        self.fill_model.bind(quote)
        side = OrderSide.BUY if order["side"] == "BUY" else OrderSide.SELL
        native_order = self.order_factory.market(
            instrument_id=instrument.id,
            order_side=side,
            quantity=Quantity.from_int(order["quantity"]),
            reduce_only=order["role"] == "EXIT",
            tags=[order["role"], order["reason"]],
        )
        self.cursor += 1
        self.submit_order(native_order)

    def on_order_event(self, event):
        kind = type(event).__name__
        row = {
            "sequence": len(self.lifecycle),
            "kind": kind,
            "timestamp_ns": int(event.ts_event),
            "client_order_id": str(event.client_order_id),
        }
        self.lifecycle.append(row)
        if kind == "OrderRejected":
            self.rejections.append(row)

    def on_order_filled(self, event):
        self.fills.append({
            "side": event.order_side.name,
            "quantity": int(event.last_qty.as_decimal()),
            "price_raw": int(event.last_px.as_decimal() * SCALE),
            "price": str(event.last_px),
            "commission_usd": f"{event.commission.as_decimal():.2f}",
            "timestamp_ns": int(event.ts_event),
            "client_order_id": str(event.client_order_id),
        })


def load_native_instrument(plan: dict, raw_symbol: str, session_ns: int):
    need(nautilus_trader.__version__ == "1.221.0", "NAUTILUS_VERSION_MISMATCH")
    definition = next((row for row in plan["inputs"]
                       if row["symbol"] == raw_symbol and row["schema"] == "definition"), None)
    need(definition is not None, "NATIVE_DEFINITION_NOT_BOUND:" + raw_symbol)
    path = Path(definition["path"])
    need(sha256_file(path) == definition["file_sha256"], "NATIVE_DEFINITION_HASH_MISMATCH")
    rows = official_decode(path, "definition", DatabentoDataLoader(), definitions=True)
    eligible = [row for row in rows if row.ts_init <= session_ns
                and row.activation_ns <= session_ns < row.expiration_ns]
    need(bool(eligible), "NO_POINT_IN_TIME_NATIVE_DEFINITION:" + raw_symbol)
    instrument = max(eligible, key=lambda row: row.ts_init)
    multiplier = Decimal("5") if raw_symbol.startswith("MES") else Decimal("50")
    need(str(instrument.raw_symbol) == raw_symbol, "NATIVE_RAW_SYMBOL_MISMATCH")
    need(instrument.multiplier.as_decimal() == multiplier, "NATIVE_MULTIPLIER_MISMATCH")
    need(instrument.price_increment.as_decimal() == Decimal("0.25"), "NATIVE_TICK_MISMATCH")
    need(str(instrument.quote_currency) == "USD", "NATIVE_CURRENCY_MISMATCH")
    return instrument


def native_replay_orders(*, plan: dict, orders: list[dict], scenario: dict,
                         starting_balance: Decimal, expected_ending_balance: Decimal | None) -> dict:
    """Replay only admitted actual-quote submissions through native lifecycle.

    Raw bars, quote eligibility, marks, and risk stay in the independent client
    contract.  This function proves native order/fee/position accounting for the
    admitted transcript, not full provider or market-liquidity parity.
    """
    need(bool(orders), "NATIVE_REPLAY_REQUIRES_ORDER")
    need(len(orders) in (1, 2), "NATIVE_TRANSCRIPT_ORDER_COUNT")
    instruments = {}
    for order in orders:
        symbol = order["raw_symbol"]
        if symbol not in instruments:
            instruments[symbol] = load_native_instrument(plan, symbol, order["quote"]["ts_recv_ns"])
    fill_model = ActualVisibleDepthFillModel(scenario["slippage_ticks_per_side"])
    engine = BacktestEngine(BacktestEngineConfig(logging=LoggingConfig(bypass_logging=True)))
    strategy = NativeTranscriptStrategy(orders, instruments, fill_model)
    half_fee = Decimal(str(scenario["commission_usd_round_turn_per_micro"])) / 2
    engine.add_venue(
        venue=Venue("GLBX"),
        oms_type=OmsType.NETTING,
        account_type=AccountType.MARGIN,
        base_currency=USD,
        starting_balances=[Money(starting_balance, USD)],
        book_type=BookType.L1_MBP,
        fee_model=PerContractFeeModel(Money(half_fee, USD)),
        fill_model=fill_model,
        use_message_queue=True,
    )
    for instrument in instruments.values():
        engine.add_instrument(instrument)
    try:
        engine.add_strategy(strategy)
        ticks = []
        for order in orders:
            quote = order["quote"]
            instrument = instruments[order["raw_symbol"]]
            ticks.append(QuoteTick(
                instrument_id=instrument.id,
                bid_price=Price.from_str(raw_to_price(quote["bid_px_raw"])),
                ask_price=Price.from_str(raw_to_price(quote["ask_px_raw"])),
                bid_size=Quantity.from_int(quote["bid_size"]),
                ask_size=Quantity.from_int(quote["ask_size"]),
                ts_event=quote["ts_exchange_ns"],
                ts_init=quote["ts_recv_ns"],
            ))
        engine.add_data(ticks)
        engine.run()
        account = engine.cache.account_for_venue(Venue("GLBX"))
        ending = account.balance_total(USD).as_decimal()
        open_positions = engine.cache.positions_open()
        expected_flat = len(orders) == 2
        need(strategy.cursor == len(orders), "NATIVE_TRANSCRIPT_NOT_CONSUMED")
        need(len(strategy.fills) == len(orders), "NATIVE_FILL_COUNT_MISMATCH")
        need(not strategy.rejections, "NATIVE_ORDER_REJECTED")
        need((not open_positions) == expected_flat, "NATIVE_FLAT_STATE_MISMATCH")
        if expected_ending_balance is not None:
            need(ending == expected_ending_balance, "NATIVE_ENDING_BALANCE_MISMATCH")
        expected_fills = [order["expected_fill"] for order in orders]
        comparable = [{key: fill[key] for key in ("side", "quantity", "price_raw", "commission_usd", "timestamp_ns")}
                      for fill in strategy.fills]
        need(comparable == expected_fills, "NATIVE_FILL_TRANSCRIPT_MISMATCH")
        return {
            "status": "PASS",
            "engine": "NautilusTrader",
            "engine_version": nautilus_trader.__version__,
            "order_count": len(orders),
            "fill_count": len(strategy.fills),
            "order_rejections": strategy.rejections,
            "fills": strategy.fills,
            "lifecycle": strategy.lifecycle,
            "fill_model_calls": fill_model.calls,
            "ending_balance_usd": str(ending),
            "ending_flat": not open_positions,
            "actual_visible_depth_bound": True,
            "native_default_fill_model_used": False,
        }
    finally:
        engine.dispose()


def frozen_scenario(config: dict, contract: dict, scenario_id: str) -> dict:
    scenario = next((row for row in config["execution"]["scenarios"] if row["id"] == scenario_id), None)
    bound = next((row for row in contract["scope"]["scenarios"] if row["id"] == scenario_id), None)
    need(scenario is not None and bound is not None, "SCENARIO_NOT_FROZEN")
    need(Decimal(str(scenario["commission_usd_round_turn_per_micro"]))
         == Decimal(bound["commission_usd_round_turn_per_micro"]), "SCENARIO_FEE_CHANGED")
    need(scenario["slippage_ticks_per_side"] == bound["slippage_ticks_per_side"],
         "SCENARIO_SLIPPAGE_CHANGED")
    need(scenario["latency_ms"] == bound["latency_ms"], "SCENARIO_LATENCY_CHANGED")
    return scenario


def order_record(*, role: str, side: str, reason: str, raw_symbol: str,
                 quantity: int, quote, scenario: dict, decision_ns: int,
                 eligible_at_ns: int, sizing_quote: dict | None) -> dict:
    binding = raw_quote_binding(quote)
    slip_raw = scenario["slippage_ticks_per_side"] * TICK
    bbo_raw = quote.ask_px_raw if side == "BUY" else quote.bid_px_raw
    fill_raw = bbo_raw + slip_raw if side == "BUY" else bbo_raw - slip_raw
    half_fee = (Decimal(str(scenario["commission_usd_round_turn_per_micro"]))
                * quantity / Decimal(2))
    return {
        "role": role,
        "side": side,
        "reason": reason,
        "raw_symbol": raw_symbol,
        "quantity": quantity,
        "quantity_policy": "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE",
        "decision_ns": decision_ns,
        "eligible_at_ns": eligible_at_ns,
        "quote": binding,
        "sizing_quote": sizing_quote,
        "expected_fill": {
            "side": side,
            "quantity": quantity,
            "price_raw": fill_raw,
            "commission_usd": f"{half_fee:.2f}",
            "timestamp_ns": quote.ts_recv_ns,
        },
    }


def base_session_row(*, arm_id: str, scenario_id: str, policy: SessionPolicy,
                     model: FrozenSignal, starting_balance: Decimal,
                     prior_high: Decimal, prior_halt: bool,
                     plan_sha256: str, contract_sha256: str) -> dict:
    return {
        "arm_id": arm_id,
        "scenario_id": scenario_id,
        "chicago_trade_date": policy.day,
        "period_id": "development",
        "signal_raw_symbol": model.signal_symbol,
        "fill_raw_symbol": model.fill_symbol,
        "classification": "DEVELOPMENT_NATIVE_PARITY_DIAGNOSTIC",
        "frozen_trial_result_status": "NOT_RUN",
        "economic_success_certified": False,
        "provider_platform_parity": "NOT_TESTED",
        "actual_paid_cash_usd": "0",
        "input_manifest_sha256": plan_sha256,
        "execution_contract_sha256": contract_sha256,
        "config_sha256": FROZEN_SHA256,
        "calendar_basis": policy.calendar_basis,
        "outcome": "NO_SIGNAL",
        "reason_code": "NO_CONFIRMED_SIGNAL",
        "net_profit_usd": "0",
        "net_R": None,
        "trade": None,
        "signal": None,
        "orders": [],
        "native": {"status": "NOT_RUN"},
        "mark_audit": None,
        "max_intraday_drawdown_pct": "0",
        "max_daily_loss_pct": "0",
        "ending_balance_usd": str(starting_balance),
        "high_watermark_usd": str(prior_high),
        "research_halt": prior_halt,
        "equity_mark_count": 0,
        "account_path_valid": True,
        "eligibility_rejections": {},
        "eligibility_rejection_examples": [],
        "raw_event_counts": {},
    }


def run_contract_session(config: dict, contract: dict, arm_id: str, scenario_id: str,
                         policy: SessionPolicy, signal_bars: Iterable, fill_bars: Iterable,
                         fill_events: Iterable, *, plan_sha256: str, now_ns: int,
                         starting_balance: Decimal, prior_high_watermark: Decimal,
                         prior_halt: bool) -> dict:
    """Apply the frozen client contract to one independent account/session."""
    model = FrozenSignal(config, arm_id, policy.day)
    scenario = frozen_scenario(config, contract, scenario_id)
    row = base_session_row(
        arm_id=arm_id,
        scenario_id=scenario_id,
        policy=policy,
        model=model,
        starting_balance=starting_balance,
        prior_high=prior_high_watermark,
        prior_halt=prior_halt,
        plan_sha256=plan_sha256,
        contract_sha256=CONTRACT_SHA256,
    )
    blocked = policy_outcome(policy, now_ns, model.arm["stage"])
    if blocked:
        row.update(outcome=blocked[0], reason_code=blocked[1],
                   net_profit_usd=None if blocked[0] == "DATA_INVALID" else "0")
        if blocked[0] == "DATA_INVALID":
            row.update(account_path_valid=False, ending_balance_usd=None)
        row["native"] = {"status": "NO_ORDER_EXPECTED", "reason": blocked[0]}
        return row
    if policy.input_manifest_sha256 != plan_sha256:
        row.update(outcome="DATA_INVALID", reason_code="INPUT_MANIFEST_HASH_MISMATCH",
                   net_profit_usd=None, account_path_valid=False, ending_balance_usd=None)
        return row
    if prior_halt:
        row.update(outcome="RISK_SKIP", reason_code="STICKY_RESEARCH_HALT", net_profit_usd="0")
        row["native"] = {"status": "NO_ORDER_EXPECTED", "reason": "STICKY_RESEARCH_HALT"}
        return row
    if type(policy.fill_instrument_id) is not int or policy.fill_instrument_id <= 0:
        row.update(outcome="DATA_INVALID", reason_code="FILL_INSTRUMENT_ID_UNBOUND",
                   net_profit_usd=None, account_path_valid=False, ending_balance_usd=None)
        return row
    try:
        fill_bars = _validated_session_bars(fill_bars, model.fill_symbol, policy.day, "15:55:00")
        if model.signal_symbol != model.fill_symbol:
            signal_bars = _validated_session_bars(signal_bars, model.signal_symbol, policy.day, "15:00:00")
    except DataInvalid as exc:
        row.update(outcome="DATA_INVALID", reason_code=str(exc), net_profit_usd=None,
                   account_path_valid=False, ending_balance_usd=None)
        return row

    gate = QuoteGate(max_quote_age_ns=0, instrument_id=policy.fill_instrument_id)
    bars = iter(_merge_bars(signal_bars, fill_bars, model.signal_symbol == model.fill_symbol))
    next_bar = next(bars, None)
    pending_entry: PendingEntry | None = None
    position = None
    pending_exit: PendingExit | None = None
    balance = starting_balance
    high = max(prior_high_watermark, starting_balance)
    worst_dd = Decimal(0)
    worst_daily = Decimal(0)
    last_key = (-1, -1)
    flat_ns = cash_ns(policy.day, "15:55:00")
    deadline = cash_ns(policy.day, "15:59:30")
    latency = scenario["latency_ms"] * 1_000_000
    slip = scenario["slippage_ticks_per_side"] * TICK
    multiplier = Decimal("5") if model.arm["fill_instrument"]["root"] == "MES" else Decimal("2")
    round_turn_fee = Decimal(str(scenario["commission_usd_round_turn_per_micro"]))
    marks = MarkAudit()
    rejection_counts = Counter()
    rejection_examples = []
    event_counts = Counter()

    def reject(event, decision, role: str) -> None:
        if decision.eligible:
            return
        rejection_counts.update(decision.reasons)
        if len(rejection_examples) < MAX_REJECTION_EXAMPLES:
            rejection_examples.append({
                "role": role,
                "replay_ordinal": event.replay_ordinal,
                "source_ordinal": event.source_ordinal,
                "ts_recv_ns": event.ts_recv_ns,
                "reasons": list(decision.reasons),
            })

    def mark(event, price_raw: int) -> Decimal:
        nonlocal high, worst_dd, worst_daily, pending_exit
        sign = 1 if position["side"] == "BUY" else -1
        liquidation_raw = price_raw - sign * slip
        equity = (starting_balance
                  + Decimal(sign * (liquidation_raw - position["entry_raw"]))
                  * multiplier / SCALE * position["quantity"]
                  - round_turn_fee * position["quantity"])
        high = max(high, equity)
        worst_dd = max(worst_dd, (high - equity) / Decimal("50000") * 100)
        worst_daily = max(worst_daily, (starting_balance - equity) / Decimal("50000") * 100)
        marks.add(event, price_raw=liquidation_raw, equity=equity)
        if worst_dd >= 5 or worst_daily >= 2:
            row["research_halt"] = True
            row.setdefault("halt_first_ns", event.ts_recv_ns)
            if pending_exit is None:
                exit_side = "SELL" if position["side"] == "BUY" else "BUY"
                pending_exit = PendingExit(exit_side, event.ts_recv_ns,
                                           event.ts_recv_ns + latency,
                                           event.replay_ordinal, "RESEARCH_HALT")
        return equity

    try:
        for event in fill_events:
            key = (event.ts_recv_ns, event.replay_ordinal)
            if key <= last_key:
                raise DataInvalid("REPLAY_EVENTS_NOT_STRICTLY_ORDERED")
            last_key = key
            event_counts[event.kind] += 1
            now = event.ts_recv_ns
            # A raw record which finalized a bar was already consumed.  Only a
            # strictly later replay record may arm or execute its intent.
            while next_bar is not None and next_bar.available_ns < now:
                intent = model.on_bar(next_bar)
                if intent is not None and position is None and pending_entry is None:
                    pending_entry = PendingEntry(intent, event.replay_ordinal - 1)
                    row["signal"] = {
                        **asdict(intent),
                        "armed_after_replay_ordinal": event.replay_ordinal - 1,
                        "first_later_event_replay_ordinal": event.replay_ordinal,
                    }
                if (position is not None and pending_exit is None
                        and model.early_exit(next_bar, position["side"])):
                    exit_side = "SELL" if position["side"] == "BUY" else "BUY"
                    pending_exit = PendingExit(exit_side, next_bar.available_ns,
                                               next_bar.available_ns + latency,
                                               event.replay_ordinal - 1,
                                               "OPPOSITE_RANGE_CLOSE")
                next_bar = next(bars, None)

            consumed = gate.consume(event)
            if not consumed.eligible and event.kind == "mbp-1":
                rejection_counts.update(consumed.reasons)
            if now > deadline:
                break

            if position is not None:
                exit_side = "SELL" if position["side"] == "BUY" else "BUY"
                observed = gate.execution_quote(
                    now, exit_side, 1,
                    after_ordinal=position["entry_ordinal"],
                    eligible_at_ns=position["entry_ns"],
                )
                if observed.eligible:
                    mark(event, observed.price_raw)
                    stop_hit = (observed.price_raw <= position["stop_raw"]
                                if position["side"] == "BUY"
                                else observed.price_raw >= position["stop_raw"])
                    target_raw = position["target_raw"]
                    target_hit = (target_raw is not None and
                                  (observed.price_raw >= target_raw
                                   if position["side"] == "BUY"
                                   else observed.price_raw <= target_raw))
                    if pending_exit is None and (stop_hit or target_hit):
                        reason = "STOP" if stop_hit else "TARGET_MARKETABLE"
                        pending_exit = PendingExit(exit_side, now, now + latency,
                                                   event.replay_ordinal, reason)
                if now >= flat_ns and pending_exit is None:
                    pending_exit = PendingExit(exit_side, flat_ns, flat_ns + latency,
                                               event.replay_ordinal - 1, "FORCED_FLAT")
                if pending_exit is not None:
                    executable = gate.execution_quote(
                        now, pending_exit.side, position["quantity"],
                        after_ordinal=pending_exit.after_ordinal,
                        eligible_at_ns=pending_exit.eligible_at_ns,
                    )
                    if executable.eligible:
                        order = order_record(
                            role="EXIT", side=pending_exit.side,
                            reason=pending_exit.reason, raw_symbol=model.fill_symbol,
                            quantity=position["quantity"], quote=event, scenario=scenario,
                            decision_ns=pending_exit.decision_ns,
                            eligible_at_ns=pending_exit.eligible_at_ns,
                            sizing_quote=None,
                        )
                        row["orders"].append(order)
                        exit_raw = order["expected_fill"]["price_raw"]
                        sign = 1 if position["side"] == "BUY" else -1
                        net = (Decimal(sign * (exit_raw - position["entry_raw"]))
                               * multiplier / SCALE * position["quantity"]
                               - round_turn_fee * position["quantity"])
                        balance = starting_balance + net
                        trade = {
                            **position,
                            "exit_raw": exit_raw,
                            "exit_ns": now,
                            "exit_ordinal": event.replay_ordinal,
                            "exit_reason": pending_exit.reason,
                            "commission_usd": str(round_turn_fee * position["quantity"]),
                        }
                        row.update(outcome="TRADE", reason_code=pending_exit.reason,
                                   trade=trade, net_profit_usd=str(net),
                                   net_R=str(net / Decimal("100")))
                        position = None
                        pending_exit = None
                        break
                    reject(event, executable, "EXIT")

            elif pending_entry is not None:
                if now >= model.entry_end:
                    raise DataInvalid("NO_EXECUTABLE_QUOTE_WITHIN_ENTRY_WINDOW")
                candidate = gate.execution_quote(
                    now, pending_entry.intent.side, 1,
                    after_ordinal=pending_entry.armed_after_ordinal,
                    eligible_at_ns=pending_entry.intent.decision_ns + latency,
                )
                if candidate.eligible and pending_entry.frozen_quantity is None:
                    sign = 1 if pending_entry.intent.side == "BUY" else -1
                    distance = sign * (candidate.price_raw - pending_entry.intent.stop_raw)
                    pending_entry.frozen_quantity = fixed_risk_size(
                        distance, model.arm["fill_instrument"]["root"], scenario)
                    pending_entry.sizing_quote = raw_quote_binding(event)
                    if pending_entry.frozen_quantity < 1:
                        row.update(outcome="RISK_SKIP", reason_code="FIXED_RISK_BELOW_ONE_CONTRACT")
                        pending_entry = None
                        break
                elif not candidate.eligible:
                    reject(event, candidate, "ENTRY_SIZE")
                if pending_entry is None or pending_entry.frozen_quantity is None:
                    continue
                executable = gate.execution_quote(
                    now, pending_entry.intent.side, pending_entry.frozen_quantity,
                    after_ordinal=pending_entry.armed_after_ordinal,
                    eligible_at_ns=pending_entry.intent.decision_ns + latency,
                )
                if executable.eligible:
                    order = order_record(
                        role="ENTRY", side=pending_entry.intent.side,
                        reason=pending_entry.intent.reason, raw_symbol=model.fill_symbol,
                        quantity=pending_entry.frozen_quantity, quote=event,
                        scenario=scenario, decision_ns=pending_entry.intent.decision_ns,
                        eligible_at_ns=pending_entry.intent.decision_ns + latency,
                        sizing_quote=pending_entry.sizing_quote,
                    )
                    row["orders"].append(order)
                    entry_raw = order["expected_fill"]["price_raw"]
                    position = {
                        "side": pending_entry.intent.side,
                        "entry_raw": entry_raw,
                        "entry_ns": now,
                        "entry_ordinal": event.replay_ordinal,
                        "quantity": pending_entry.frozen_quantity,
                        "stop_raw": pending_entry.intent.stop_raw,
                        "target_raw": pending_entry.intent.target_raw,
                        "signal_close_ns": pending_entry.intent.signal_close_ns,
                        "decision_ns": pending_entry.intent.decision_ns,
                        "quantity_frozen_ns": pending_entry.sizing_quote["ts_recv_ns"],
                        "quantity_frozen_replay_ordinal": pending_entry.sizing_quote["replay_ordinal"],
                    }
                    pending_entry = None
                    opposite = "SELL" if position["side"] == "BUY" else "BUY"
                    initial = gate.execution_quote(now, opposite, 1,
                                                   after_ordinal=-1, eligible_at_ns=now)
                    if initial.eligible:
                        mark(event, initial.price_raw)
                else:
                    reject(event, executable, "ENTRY_DEPTH")

        if position is not None:
            raise DataInvalid("NO_CONFIRMED_FLAT_BY_155930")
        if pending_entry is not None:
            raise DataInvalid("CONFIRMED_SIGNAL_WITHOUT_EXECUTABLE_QUOTE")
        if row["outcome"] == "NO_SIGNAL":
            if last_key[0] <= deadline:
                raise DataInvalid("FILL_STREAM_HORIZON_UNPROVEN")
            while next_bar is not None:
                if next_bar.available_ns <= deadline:
                    unexecuted = model.on_bar(next_bar)
                    if unexecuted is not None:
                        raise DataInvalid("CONFIRMED_SIGNAL_WITHOUT_OBSERVED_FILL_STREAM")
                next_bar = next(bars, None)
            if model.fill_symbol not in model.ranges or model.signal_symbol not in model.ranges:
                raise DataInvalid("INCOMPLETE_FIRST_FIVE_MINUTES")
            row["reason_code"] = model.reason
    except (DataInvalid, ReplayError) as exc:
        row.update(outcome="DATA_INVALID", reason_code=str(exc), net_profit_usd=None,
                   net_R=None, account_path_valid=False, ending_balance_usd=None)

    row.update(
        ending_balance_usd=str(balance) if row["account_path_valid"] else None,
        high_watermark_usd=str(high),
        max_intraday_drawdown_pct=str(worst_dd),
        max_daily_loss_pct=str(worst_daily),
        equity_mark_count=marks.count,
        mark_audit=marks.report(),
        eligibility_rejections=dict(sorted(rejection_counts.items())),
        eligibility_rejection_examples=rejection_examples,
        raw_event_counts=dict(sorted(event_counts.items())),
    )
    if not row["orders"]:
        row["native"] = {"status": "NO_ORDER_EXPECTED", "reason": row["outcome"]}
    return row


TASK_INPUTS = {
    "native_execution_probe_json": REFERENCE_ROOT / "native_execution_probe.json",
    "native_execution_probe_md": REFERENCE_ROOT / "native_execution_probe.md",
    "bound_sources_v2": REFERENCE_ROOT / "june2019_bound_sources_v2.json",
    "mbp1_trade_coverage_review": REFERENCE_ROOT / "mbp1_trade_coverage_review.json",
    "root_adapter_delivery": REFERENCE_ROOT / "root_adapter_delivery/delivery.json",
}


def validate_source_plan(path: Path = DEFAULT_SOURCE_PLAN) -> dict:
    need(sha256_file(path) == SOURCE_PLAN_SHA256, "SOURCE_PLAN_HASH_MISMATCH")
    plan = read_json(path)
    need(plan["schema"] == "qm.june2019-reference-plan/v1", "SOURCE_PLAN_SCHEMA")
    need(plan["session_row_count"] == 180 and len(plan["rows"]) == 180, "SOURCE_PLAN_ROW_COUNT")
    need(plan["frozen_trial_status"] == "NOT_RUN", "SOURCE_FORMAL_TRIAL_STATUS_CHANGED")
    need(plan["config_sha256"] == FROZEN_SHA256, "SOURCE_PLAN_CONFIG_CHANGED")
    for name, binding in plan["bindings"].items():
        verify_binding(binding, label="SOURCE_PLAN_BINDING_" + name.upper())
    for name, binding in plan["source_code"].items():
        verify_binding(binding, label="SOURCE_PLAN_CODE_" + name.upper())
    return plan


def prepare_artifact(output: Path, *, source_plan_path: Path = DEFAULT_SOURCE_PLAN,
                     reference_result_path: Path = DEFAULT_REFERENCE_RESULT) -> Path:
    need(not output.exists(), "OUTPUT_DIRECTORY_ALREADY_EXISTS")
    contract = load_contract()
    source_plan = validate_source_plan(source_plan_path)
    need(sha256_file(reference_result_path) == REFERENCE_RESULT_SHA256,
         "REFERENCE_RESULT_HASH_MISMATCH")
    task_inputs = {name: file_binding(path) for name, path in TASK_INPUTS.items()}
    source_files = {
        name: file_binding(HERE / name)
        for name in ("native_strategy_parity.py", "test_native_strategy_parity.py")
    }
    output.mkdir(parents=True, exist_ok=False)
    prepared = {
        "schema": SOURCE_SCHEMA,
        "task_id": TASK_ID,
        "classification": "PREBOUND_OFFLINE_NATIVE_PARITY_NOT_ECONOMIC_TRIAL",
        "prepared_at_utc": datetime.now(timezone.utc).isoformat(),
        "implementation_base_commit": IMPLEMENTATION_BASE,
        "execution_contract": file_binding(CONTRACT_PATH),
        "source_plan": file_binding(source_plan_path),
        "reference_result": file_binding(reference_result_path),
        "task_inputs": task_inputs,
        "source_files": source_files,
        "source_plan_source_code": source_plan["source_code"],
        "source_plan_bindings": source_plan["bindings"],
        "row_identities": source_plan["rows"],
        "session_row_count": 180,
        "arms": contract["scope"]["arms"],
        "dates": contract["scope"]["dates"],
        "scenarios": [row["id"] for row in contract["scope"]["scenarios"]],
        "quantity_policy": contract["entry"]["quantity_policy"],
        "frozen_trial_status": "NOT_RUN",
        "economic_success_certified": False,
        "network_authorized": False,
        "orders_external_authorized": False,
    }
    target = output / "parity_plan.json"
    write_exclusive(target, prepared)
    print(json.dumps({
        "status": "PREPARED",
        "plan": str(target),
        "plan_sha256": sha256_file(target),
        "rows": len(prepared["row_identities"]),
    }), flush=True)
    return target


def verify_parity_plan(path: Path) -> tuple[dict, dict, dict]:
    parity = read_json(path)
    need(parity["schema"] == SOURCE_SCHEMA and parity["task_id"] == TASK_ID,
         "PARITY_PLAN_IDENTITY")
    need(parity["session_row_count"] == 180 and len(parity["row_identities"]) == 180,
         "PARITY_PLAN_ROW_COUNT")
    need(parity["frozen_trial_status"] == "NOT_RUN", "PARITY_PLAN_FORMAL_STATUS")
    for key in ("execution_contract", "source_plan", "reference_result"):
        verify_binding(parity[key], label="PARITY_" + key.upper())
    for group in ("task_inputs", "source_files", "source_plan_source_code", "source_plan_bindings"):
        for name, binding in parity[group].items():
            verify_binding(binding, label="PARITY_" + group.upper() + "_" + name.upper())
    need(parity["execution_contract"]["sha256"] == CONTRACT_SHA256, "PARITY_CONTRACT_CHANGED")
    need(parity["source_plan"]["sha256"] == SOURCE_PLAN_SHA256, "PARITY_SOURCE_PLAN_CHANGED")
    need(parity["reference_result"]["sha256"] == REFERENCE_RESULT_SHA256,
         "PARITY_REFERENCE_RESULT_CHANGED")
    return parity, read_json(Path(parity["source_plan"]["path"])), load_contract()


def policies_from_source_plan(source_plan: dict) -> dict[str, SessionPolicy]:
    policies = {}
    for row in source_plan["sessions"]:
        policy = dict(row["policy"])
        policy["high_usd_event_ns"] = tuple(policy["high_usd_event_ns"])
        policy["input_manifest_sha256"] = SOURCE_PLAN_SHA256
        policies[row["day"]] = SessionPolicy(**policy)
    return policies


def prior_invalid_row(*, config: dict, contract: dict, policy: SessionPolicy,
                      arm_id: str, scenario_id: str, carry: AccountCarry) -> dict:
    model = FrozenSignal(config, arm_id, policy.day)
    row = base_session_row(
        arm_id=arm_id,
        scenario_id=scenario_id,
        policy=policy,
        model=model,
        starting_balance=Decimal("0"),
        prior_high=carry.high_watermark,
        prior_halt=carry.sticky_halt,
        plan_sha256=SOURCE_PLAN_SHA256,
        contract_sha256=CONTRACT_SHA256,
    )
    row.update(
        outcome="DATA_INVALID",
        reason_code="PRIOR_ACCOUNT_PATH_INVALID",
        account_path_valid=False,
        ending_balance_usd=None,
        net_profit_usd=None,
        invalid_since=carry.invalid_since,
        native={"status": "NOT_RUN_PRIOR_ACCOUNT_PATH_INVALID"},
    )
    return row


def carry_forward(carry: AccountCarry, row: dict) -> None:
    if not row["account_path_valid"] or row["ending_balance_usd"] is None:
        carry.valid = False
        carry.invalid_since = carry.invalid_since or row["chicago_trade_date"]
        return
    need(carry.valid, "CANNOT_RESUME_POISONED_ACCOUNT")
    carry.balance = Decimal(row["ending_balance_usd"])
    carry.high_watermark = Decimal(row["high_watermark_usd"])
    carry.sticky_halt = carry.sticky_halt or row["research_halt"]


def materialize_raw_inputs(source_plan: dict, eligible_days: list[str]):
    row_for = {(row["symbol"], row["schema"]): row for row in source_plan["inputs"]}
    caches = {}
    for root, schema in (("MES", "mbp-1"), ("ES", "trades")):
        symbols = sorted({candidate_contract(root, day)[0] for day in eligible_days})
        for symbol in symbols:
            selected = [day for day in eligible_days if candidate_contract(root, day)[0] == symbol]
            caches[symbol] = extract_cash(row_for[symbol, schema], selected)
    return row_for, caches


def materialize_day(day: str, *, row_for: dict, caches: dict) -> dict:
    fill_symbol, _ = candidate_contract("MES", day)
    signal_symbol, _ = candidate_contract("ES", day)
    statuses = session_statuses(row_for[fill_symbol, "status"], day)

    def micro_events():
        from replay_adapter import merge_events
        return merge_events(cached_records(caches[fill_symbol][day], MBP), iter(statuses))

    values = {"events": micro_events, "errors": {}, fill_symbol: None, signal_symbol: None}
    for symbol, events in ((fill_symbol, micro_events()),
                           (signal_symbol, mini_events(caches[signal_symbol][day]))):
        try:
            values[symbol] = tuple(trade_bars(events, symbol,
                                              end_watermark_ns=cash_ns(day, "16:00:00")))
        except DataInvalid as exc:
            values["errors"][symbol] = str(exc)
    values["diagnostic"] = {
        "fill_symbol": fill_symbol,
        "signal_symbol": signal_symbol,
        "bar_counts": {
            fill_symbol: len(values[fill_symbol]) if values[fill_symbol] is not None else None,
            signal_symbol: len(values[signal_symbol]) if values[signal_symbol] is not None else None,
        },
        "bar_errors": values["errors"],
        "status_seed_original_ns": statuses[0][2][5],
    }
    return values


def decimal_equal(left, right) -> bool:
    if left is None or right is None:
        return left is right
    return Decimal(str(left)) == Decimal(str(right))


def compare_results(native_path: Path, reference_path: Path, output: Path) -> dict:
    """Independent post-run comparison; never used to choose execution inputs."""
    native = read_json(native_path)
    reference = read_json(reference_path)
    need(native["schema"] == RESULT_SCHEMA, "NATIVE_RESULT_SCHEMA")
    need(reference["schema"] == "qm.june2019-reference-result/v1", "REFERENCE_RESULT_SCHEMA")
    need(len(native["rows"]) == len(reference["rows"]) == 180, "COMPARISON_ROW_COUNT")
    key = lambda row: (row["chicago_trade_date"], row["arm_id"], row["scenario_id"])
    native_rows = {key(row): row for row in native["rows"]}
    reference_rows = {key(row): row for row in reference["rows"]}
    need(native_rows.keys() == reference_rows.keys(), "COMPARISON_IDENTITY_SET")
    comparisons = []
    account_summaries = {}
    for identity in sorted(native_rows):
        actual = native_rows[identity]
        prior = reference_rows[identity]
        differences = []

        def exact(field: str, left, right):
            if left != right:
                differences.append({"field": field, "reference": left, "native_contract": right})

        def numeric(field: str, left, right):
            if not decimal_equal(left, right):
                differences.append({"field": field, "reference": left, "native_contract": right})

        exact("outcome", prior["outcome"], actual["outcome"])
        exact("reason_code", prior["reason_code"], actual["reason_code"])
        exact("account_path_valid", prior["account_path_valid"], actual["account_path_valid"])
        exact("research_halt", prior["research_halt"], actual["research_halt"])
        numeric("ending_balance_usd", prior["ending_balance_usd"], actual["ending_balance_usd"])
        numeric("high_watermark_usd", prior["high_watermark_usd"], actual["high_watermark_usd"])
        numeric("net_profit_usd", prior["net_profit_usd"], actual["net_profit_usd"])
        numeric("max_intraday_drawdown_pct", prior["max_intraday_drawdown_pct"],
                actual["max_intraday_drawdown_pct"])
        numeric("max_daily_loss_pct", prior["max_daily_loss_pct"], actual["max_daily_loss_pct"])
        exact("equity_mark_count", prior.get("equity_mark_count", 0), actual["equity_mark_count"])
        if prior["trade"] is not None:
            if actual["trade"] is None:
                differences.append({"field": "trade", "reference": "PRESENT", "native_contract": "ABSENT"})
            else:
                exact("signal.decision_ns", prior["trade"]["decision_ns"],
                      actual["signal"]["decision_ns"] if actual["signal"] else None)
                for field in ("side", "quantity", "entry_raw", "entry_ns", "exit_raw", "exit_ns",
                              "exit_reason", "stop_raw", "target_raw", "signal_close_ns"):
                    exact("trade." + field, prior["trade"].get(field), actual["trade"].get(field))
                numeric("trade.commission_usd", prior["trade"]["commission_usd"],
                        actual["trade"]["commission_usd"])
        elif actual["trade"] is not None:
            differences.append({"field": "trade", "reference": "ABSENT", "native_contract": "PRESENT"})
        if actual["orders"]:
            exact("native.status", "PASS", actual["native"].get("status"))
            exact("native.order_rejections", [], actual["native"].get("order_rejections"))
            exact("native.fill_count", len(actual["orders"]), actual["native"].get("fill_count"))
        account_key = actual["arm_id"] + "|" + actual["scenario_id"]
        summary = account_summaries.setdefault(account_key, {
            "arm_id": actual["arm_id"],
            "scenario_id": actual["scenario_id"],
            "rows": 0,
            "rows_exact_reference_match": 0,
            "rows_with_differences": 0,
            "difference_fields": Counter(),
        })
        summary["rows"] += 1
        if differences:
            summary["rows_with_differences"] += 1
            summary["difference_fields"].update(item["field"] for item in differences)
        else:
            summary["rows_exact_reference_match"] += 1
        comparisons.append({
            "chicago_trade_date": actual["chicago_trade_date"],
            "arm_id": actual["arm_id"],
            "scenario_id": actual["scenario_id"],
            "status": "MATCH" if not differences else "DIFFERENT",
            "differences": differences,
            "quantity_policy_reference": "EXECUTABLE_FILL_QUOTE_RECOMPUTED",
            "quantity_policy_native_contract": "FIRST_ELIGIBLE_SUBMISSION_QUOTE_FIXED_NO_RESIZE",
        })
    summaries = []
    for value in account_summaries.values():
        value["difference_fields"] = dict(sorted(value["difference_fields"].items()))
        summaries.append(value)
    result = {
        "schema": MISMATCH_SCHEMA,
        "task_id": TASK_ID,
        "classification": "INDEPENDENT_POST_RUN_TECHNICAL_COMPARISON",
        "native_result": file_binding(native_path),
        "reference_result": file_binding(reference_path),
        "execution_contract_sha256": CONTRACT_SHA256,
        "row_count": len(comparisons),
        "all_rows_retained": len(comparisons) == 180,
        "account_comparisons": summaries,
        "rows": comparisons,
        "predeclared_semantic_differences": [
            "Reference quantity may be recomputed at an executable fill quote; native quantity is frozen before submit_order and never resized.",
            "The native layer owns admitted order, fee and position lifecycle; the client contract owns raw causality, gating, marks and sticky risk.",
            "Neither layer is NinjaTrader/provider-platform parity or actual paid-cash evidence."
        ],
        "frozen_trial_status": "NOT_RUN",
        "economic_success_certified": False,
    }
    write_exclusive(output, result)
    return result


def render_readme(result: dict, mismatch: dict, result_path: Path, mismatch_path: Path) -> str:
    account_lines = []
    for row in mismatch["account_comparisons"]:
        account_lines.append(
            f"| `{row['arm_id']}` | `{row['scenario_id']}` | {row['rows_exact_reference_match']} | "
            f"{row['rows_with_differences']} | `{json.dumps(row['difference_fields'], sort_keys=True)}` |"
        )
    native_pass = sum(1 for row in result["rows"] if row["native"].get("status") == "PASS")
    invalid = sum(1 for row in result["rows"] if not row["account_path_valid"])
    return (
        "# Native frozen-futures execution parity\n\n"
        f"Task: `{TASK_ID}`  \n"
        f"Implementation base: `{IMPLEMENTATION_BASE}`  \n"
        f"Execution contract: `{CONTRACT_SHA256}`\n\n"
        "## Outcome\n\n"
        f"All {len(result['rows'])} planned June-2019 session/account rows were retained. "
        f"NautilusTrader 1.221.0 lifecycle replay passed for {native_pass} rows with admitted orders; "
        f"{invalid} rows have unresolved account paths. Formal frozen trial cells remain **NOT_RUN**. "
        "This is technical parity evidence only, not an economic PASS.\n\n"
        "## Evidence layers\n\n"
        "- **Reference:** the original hash-bound development diagnostic is unchanged.\n"
        "- **Native simulation:** raw-record client gating plus Nautilus order, fee, fill and position lifecycle. "
        "The custom fill model uses the admitted raw quote's actual displayed depth and fixed adverse ticks.\n"
        "- **Provider platform:** not tested. Native Nautilus behavior is not NinjaTrader or provider-platform parity.\n"
        "- **Actual paid cash:** zero; no account, purchase, API call, credential, provider contact or order was used.\n\n"
        "## Frozen execution amendment\n\n"
        "The first quote satisfying causal availability, continuous status, DBN quality, BBO freshness and client latency "
        "freezes quantity before native submission. Quantity is never resized afterward; insufficient displayed depth delays "
        "submission without changing it. Stops are client-triggered and pass through a new latency/fresh-quote gate, so a gap "
        "cannot fill optimistically at the trigger. Forced-flat begins at 15:55 New York and failure to confirm flat by 15:59:30 "
        "poisons that account path. Equal timestamps retain replay order and accounting phases; no jitter or price repair occurs.\n\n"
        "The older reference recomputes quantity at an executable fill quote. That semantic difference was frozen before this "
        "native run and is reported even when the selected records happen to produce the same numeric quantity. The amendment "
        "is a correctness contract, not a result-driven parameter change.\n\n"
        "## Independent comparison by counterfactual account\n\n"
        "No PnL is aggregated across arms or cost scenarios.\n\n"
        "| Arm | Scenario | Exact rows | Different rows | Difference fields |\n"
        "|---|---:|---:|---:|---|\n" + "\n".join(account_lines) + "\n\n"
        "## Durable files\n\n"
        f"- `{result_path.name}` — all raw-contract/native rows and per-account summaries.\n"
        f"- `{mismatch_path.name}` — independent field-level comparison to the retained reference.\n"
        "- `parity_plan.json` — pre-run bindings and all 180 planned identities.\n"
        "- `verification.json` — focused test and binding receipt.\n"
    )


def execute_artifact(parity_plan_path: Path) -> tuple[Path, Path]:
    parity, source_plan, contract = verify_parity_plan(parity_plan_path)
    output = parity_plan_path.parent
    attempt = output / "attempt.json"
    result_path = output / "native_parity_result.json"
    mismatch_path = output / "mismatch_report.json"
    need(not any(path.exists() for path in (attempt, result_path, mismatch_path, output / "README.md")),
         "PARITY_EXECUTION_ALREADY_ATTEMPTED")
    parity_plan_sha = sha256_file(parity_plan_path)
    write_exclusive(attempt, {
        "status": "EXECUTION_STARTED",
        "parity_plan_sha256": parity_plan_sha,
        "execution_contract_sha256": CONTRACT_SHA256,
        "frozen_trial_status": "NOT_RUN",
    })
    config = load_frozen()
    policies = policies_from_source_plan(source_plan)
    session_meta = {row["day"]: row for row in source_plan["sessions"]}
    eligible_days = [row["day"] for row in source_plan["sessions"]
                     if row["pre_result_exclusion"] is None]
    row_for, caches = materialize_raw_inputs(source_plan, eligible_days)
    states = {(arm, scenario): AccountCarry()
              for arm in contract["scope"]["arms"]
              for scenario in SCENARIOS}
    results = []
    diagnostics = {}
    planned_by_day = {}
    for planned in source_plan["rows"]:
        planned_by_day.setdefault(planned["day"], []).append(planned)

    for day in contract["scope"]["dates"]:
        materialized = (materialize_day(day, row_for=row_for, caches=caches)
                        if day in eligible_days else None)
        if materialized:
            diagnostics[day] = materialized["diagnostic"]
        for planned in planned_by_day[day]:
            arm = planned["arm_id"]
            scenario_id = planned["scenario_id"]
            carry = states[arm, scenario_id]
            policy = policies[day]
            if not carry.valid:
                row = prior_invalid_row(config=config, contract=contract, policy=policy,
                                        arm_id=arm, scenario_id=scenario_id, carry=carry)
            else:
                if materialized:
                    fill_symbol, _ = candidate_contract("MES", day)
                    signal_symbol = candidate_contract("ES", day)[0] if arm == ARM_IDS[1] else fill_symbol
                    fill_bars = materialized[fill_symbol] or ()
                    signal_bars = materialized[signal_symbol] or ()
                    events = materialized["events"]()
                else:
                    fill_bars, signal_bars, events = (), (), ()
                starting_balance = carry.balance
                row = run_contract_session(
                    config, contract, arm, scenario_id, policy,
                    signal_bars, fill_bars, events,
                    plan_sha256=SOURCE_PLAN_SHA256,
                    now_ns=source_plan["prepared_at_ns"],
                    starting_balance=starting_balance,
                    prior_high_watermark=carry.high_watermark,
                    prior_halt=carry.sticky_halt,
                )
                if materialized and materialized["errors"]:
                    row["source_bar_errors"] = materialized["errors"]
                if row["orders"]:
                    scenario = frozen_scenario(config, contract, scenario_id)
                    before_native = {
                        key: row[key] for key in (
                            "outcome", "reason_code", "account_path_valid", "ending_balance_usd",
                            "net_profit_usd", "net_R", "trade"
                        )
                    }
                    try:
                        expected_ending = (Decimal(row["ending_balance_usd"])
                                           if row["account_path_valid"] and row["ending_balance_usd"] is not None
                                           else None)
                        row["native"] = native_replay_orders(
                            plan=source_plan,
                            orders=row["orders"],
                            scenario=scenario,
                            starting_balance=starting_balance,
                            expected_ending_balance=expected_ending,
                        )
                    except Exception as exc:
                        row["contract_outcome_before_native_failure"] = before_native
                        row.update(
                            outcome="DATA_INVALID",
                            reason_code="NATIVE_PARITY_FAILURE:" + str(exc),
                            account_path_valid=False,
                            ending_balance_usd=None,
                            net_profit_usd=None,
                            net_R=None,
                            native={"status": "FAIL", "reason": str(exc)},
                        )
                carry_forward(carry, row)
            results.append(row)
        print(json.dumps({"status": "DAY_RETAINED", "day": day, "rows": len(results)}), flush=True)

    need(len(results) == 180, "NATIVE_RESULT_ROW_LOSS")
    account_summaries = []
    for arm in contract["scope"]["arms"]:
        for scenario_id in SCENARIOS:
            rows = [row for row in results
                    if row["arm_id"] == arm and row["scenario_id"] == scenario_id]
            account_summaries.append({
                "arm_id": arm,
                "scenario_id": scenario_id,
                "session_rows": len(rows),
                "outcomes": dict(Counter(row["outcome"] for row in rows)),
                "account_path_valid": all(row["account_path_valid"] for row in rows),
                "ending_balance_usd": rows[-1]["ending_balance_usd"],
                "research_halt": rows[-1]["research_halt"],
                "native_pass_rows": sum(row["native"].get("status") == "PASS" for row in rows),
            })
    result = {
        "schema": RESULT_SCHEMA,
        "task_id": TASK_ID,
        "classification": "DEVELOPMENT_NATIVE_PARITY_DIAGNOSTIC",
        "parity_plan_sha256": parity_plan_sha,
        "source_plan_sha256": SOURCE_PLAN_SHA256,
        "reference_result_sha256": REFERENCE_RESULT_SHA256,
        "execution_contract_sha256": CONTRACT_SHA256,
        "engine_version": nautilus_trader.__version__,
        "session_row_count": len(results),
        "selected_dates": contract["scope"]["dates"],
        "eligible_raw_replay_dates": eligible_days,
        "input_diagnostics": diagnostics,
        "account_summaries": account_summaries,
        "rows": results,
        "frozen_trial_status": "NOT_RUN",
        "economic_success_certified": False,
        "provider_platform_parity": "NOT_TESTED",
        "actual_paid_cash_usd": "0",
        "network_requests": 0,
        "credentials_read": 0,
        "external_orders_submitted": 0,
    }
    need(sha256_file(parity_plan_path) == parity_plan_sha, "PARITY_PLAN_CHANGED_DURING_EXECUTION")
    need(sha256_file(Path(parity["reference_result"]["path"])) == REFERENCE_RESULT_SHA256,
         "REFERENCE_RESULT_CHANGED_DURING_EXECUTION")
    write_exclusive(result_path, result)
    mismatch = compare_results(result_path, Path(parity["reference_result"]["path"]), mismatch_path)
    (output / "README.md").write_text(
        render_readme(result, mismatch, result_path, mismatch_path), encoding="utf-8", newline="\n")
    write_exclusive(output / "completion.json", {
        "status": "NATIVE_PARITY_COMPLETE",
        "parity_plan_sha256": parity_plan_sha,
        "result": file_binding(result_path),
        "mismatch_report": file_binding(mismatch_path),
        "readme": file_binding(output / "README.md"),
        "session_rows": 180,
        "frozen_trial_status": "NOT_RUN",
        "economic_success_certified": False,
    })
    print(json.dumps({
        "status": "NATIVE_PARITY_COMPLETE",
        "result": str(result_path),
        "mismatch_report": str(mismatch_path),
        "rows": 180,
    }), flush=True)
    return result_path, mismatch_path


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--prepare", type=Path, metavar="OUTPUT_DIRECTORY")
    group.add_argument("--execute-plan", type=Path, metavar="PARITY_PLAN_JSON")
    args = parser.parse_args(argv)
    if args.prepare:
        prepare_artifact(args.prepare)
    else:
        execute_artifact(args.execute_plan)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
