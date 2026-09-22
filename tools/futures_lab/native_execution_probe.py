"""Offline synthetic Nautilus 1.221 mechanics probe, never an economic trial.

Only local definition metadata are read. No network clients, live nodes, broker
connections, credentials, actual market replay, or strategy selection are used.
The native engine owns orders, fills, positions and fees. A deliberately bounded
synthetic FillModel supplies the frozen adverse prices; QuoteGate controls fresh
quote eligibility. Raw native latency/standing-stop comparisons expose where the
native defaults are NOT the reference execution contract.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path

import nautilus_trader
from nautilus_trader.adapters.databento import DatabentoDataLoader
from nautilus_trader.backtest.config import BacktestEngineConfig
from nautilus_trader.backtest.engine import BacktestEngine
from nautilus_trader.backtest.models import FillModel, LatencyModel, PerContractFeeModel
from nautilus_trader.config import LoggingConfig, StrategyConfig
from nautilus_trader.model.book import OrderBook
from nautilus_trader.model.currencies import USD
from nautilus_trader.model.data import BookOrder, QuoteTick
from nautilus_trader.model.enums import AccountType, BookType, OmsType, OrderSide
from nautilus_trader.model.identifiers import Venue
from nautilus_trader.model.objects import Money, Price, Quantity
from nautilus_trader.trading.strategy import Strategy

from replay_adapter import QuoteGate, ReplayEvent
from strategy_runner import fixed_risk_size, load_frozen
from validate_databento_pilot import official_decode

NS = 1_000_000_000
TICK = Decimal("0.25")
BASE_NS = 1559569200000000000  # 2019-06-03 13:40:00 UTC, synthetic clock only
FLAT_NS = 1559591700000000000  # 2019-06-03 19:55:00 UTC = 15:55 New York
DEADLINE_NS = FLAT_NS + 270 * NS
DEF_PATH = Path("D:/QM/futures_lab/development/june2019/MESM9/definition.dbn")
DEF_SHA256 = "2af1fa989ddbfb466c4f5cad6eaabdbe253180b3c176b107c0ede81b6a66040b"
DEFAULT_OUTPUT = Path("D:/QM/reports/research/futures_pivot_20260922/progress_20260922/native_execution_probe.json")
EXPECTED_SCENARIOS = {
    "BASE": (Decimal("1.9"), 1, 100),
    "ADVERSE": (Decimal("2.5"), 2, 250),
    "SEVERE": (Decimal("3.0"), 4, 750),
}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def load_instrument():
    require(nautilus_trader.__version__ == "1.221.0", "NAUTILUS_VERSION_MISMATCH")
    require(hashlib.sha256(DEF_PATH.read_bytes()).hexdigest() == DEF_SHA256, "DEFINITION_HASH_MISMATCH")
    definitions = official_decode(DEF_PATH, "definition", DatabentoDataLoader(), definitions=True)
    require(len(definitions) == 12, "DEFINITION_COUNT_MISMATCH")
    for instrument in definitions:
        require(str(instrument.id) == "MESM9.GLBX" and str(instrument.raw_symbol) == "MESM9", "IDENTITY_MISMATCH")
        require(instrument.multiplier.as_decimal() == 5 and instrument.price_increment.as_decimal() == TICK
                and str(instrument.quote_currency) == "USD", "CONTRACT_METADATA_MISMATCH")
    # Select a definition already available before synthetic session start.
    eligible = [x for x in definitions if x.ts_init <= BASE_NS]
    require(bool(eligible), "NO_POINT_IN_TIME_DEFINITION")
    instrument = max(eligible, key=lambda x: x.ts_init)
    require(instrument.activation_ns <= BASE_NS < DEADLINE_NS < instrument.expiration_ns, "CONTRACT_NOT_ACTIVE")
    return instrument


def scenarios():
    config = load_frozen()
    rows = config["execution"]["scenarios"]
    require(len(rows) == 3, "SCENARIO_COUNT_CHANGED")
    for row in rows:
        require(row["id"] in EXPECTED_SCENARIOS, "UNBOUND_SCENARIO")
        actual = (Decimal(str(row["commission_usd_round_turn_per_micro"])),
                  row["slippage_ticks_per_side"], row["latency_ms"])
        require(actual == EXPECTED_SCENARIOS[row["id"]], "FROZEN_COST_CHANGED")
    return rows


@dataclass(frozen=True)
class Row:
    ts: int
    bid: str
    ask: str


@dataclass(frozen=True)
class Fixture:
    name: str
    rows: tuple[Row, ...]
    side: str = "BUY"
    quantity: int = 1
    mode: str = "fresh_gate"
    exit_decision_ns: int | None = None
    stop: str | None = None
    force_flat: bool = False
    size_at: str = "fixed"
    heartbeat: bool = False
    expect_flat: bool = True


class FrozenSyntheticFillModel(FillModel):
    """Exactly N adverse ticks, with only 10 synthetic contracts per side.

    NOT a real-book liquidity model. All fixtures have size 10, quantities <= 2.
    Returning an empty book would trigger native fallback: reject out-of-scope
    orders by raising, never pretend empty simulated liquidity prevents fills.
    """
    def __init__(self, ticks):
        super().__init__(prob_fill_on_limit=0.0, prob_slippage=0.0, random_seed=7)
        require(type(ticks) is int and ticks in (1, 2, 4), "UNBOUND_SLIPPAGE")
        self.ticks = ticks
        self.calls = []

    def get_orderbook_for_fill_simulation(self, instrument, order, best_bid, best_ask):
        require(order.quantity.as_decimal() <= 2, "SYNTHETIC_QUANTITY_CAP")
        require(best_bid is not None and best_ask is not None
                and best_bid.as_decimal() > 0 and best_ask.as_decimal() > best_bid.as_decimal(), "INVALID_FILL_BBO")
        delta = instrument.price_increment.as_decimal() * self.ticks
        book = OrderBook(instrument_id=instrument.id, book_type=BookType.L2_MBP)
        for side, value, order_id in ((OrderSide.BUY, best_bid.as_decimal()-delta, 1),
                                      (OrderSide.SELL, best_ask.as_decimal()+delta, 2)):
            book.add(BookOrder(side=side, price=Price.from_str(f"{value:.2f}"),
                               size=Quantity.from_int(10), order_id=order_id), 0, 0)
        self.calls.append({"side": order.side.name, "best_bid": str(best_bid), "best_ask": str(best_ask),
                           "quantity": str(order.quantity), "slippage_ticks": self.ticks})
        return book


def fixture_set(scenario):
    lag = scenario["latency_ms"] * 1_000_000
    t = BASE_NS
    end = t + 2 * NS
    common = (Row(t, "5000.00", "5000.25"), Row(t+lag-1, "5000.25", "5000.50"),
              Row(t+lag, "5000.50", "5000.75"), Row(end, "5001.00", "5001.25"),
              Row(end+lag-1, "5001.25", "5001.50"), Row(end+lag, "5001.50", "5001.75"),
              Row(end+2*NS, "5001.50", "5001.75"))
    result = [Fixture(f"{side.lower()}_q{qty}", common, side, qty, exit_decision_ns=end)
              for side in ("BUY", "SELL") for qty in (1, 2)]
    result.append(Fixture("raw_defaults_market", common, mode="raw_defaults", exit_decision_ns=end))
    sparse = (Row(t, "5000.00", "5000.25"), Row(t+NS, "5002.00", "5002.25"),
              Row(end, "5001.00", "5001.25"), Row(end+NS, "5000.00", "5000.25"),
              Row(end+2*NS, "5000.00", "5000.25"))
    result += [Fixture("native_latency_sparse", sparse, mode="native_latency", exit_decision_ns=end, heartbeat=True),
               Fixture("fresh_latency_sparse", sparse, exit_decision_ns=end, heartbeat=True)]
    gap = (Row(t, "5000.00", "5000.25"), Row(t+lag, "5000.00", "5000.25"),
           Row(t+NS, "4995.00", "4995.25"), Row(t+NS+lag, "4994.50", "4994.75"),
           Row(t+3*NS, "4994.50", "4994.75"))
    result += [Fixture("stop_gap_gated", gap, stop="4998.00"),
               Fixture("stop_gap_native_standing", gap, mode="native_standing_stop", stop="4998.00"),
               Fixture("raw_defaults_standing_stop", gap, mode="raw_default_stop", stop="4998.00")]
    forced = (Row(FLAT_NS-2*NS, "5000.00", "5000.25"), Row(FLAT_NS-2*NS+lag, "5000.00", "5000.25"),
              Row(FLAT_NS-1, "5001.00", "5001.25"), Row(FLAT_NS+lag-1, "5002.00", "5002.25"),
              Row(FLAT_NS+lag, "5003.00", "5003.25"), Row(DEADLINE_NS, "5003.00", "5003.25"))
    result += [Fixture("forced_flat", forced, force_flat=True),
               Fixture("forced_flat_missing_quote", forced[:3]+(Row(DEADLINE_NS+1, "5003.00", "5003.25"),),
                       force_flat=True, expect_flat=False)]
    size = (Row(t, "5000.00", "5000.25"), Row(t+lag, "5007.00", "5007.25"),
            Row(end, "5008.00", "5008.25"), Row(end+lag, "5008.00", "5008.25"),
            Row(end+2*NS, "5008.00", "5008.25"))
    result += [Fixture("sizing_at_"+at, size, exit_decision_ns=end, stop="4994.00", size_at=at)
               for at in ("decision", "fill")]
    tied = (Row(t, "5000.00", "5000.25"), Row(t+lag, "5001.00", "5001.25"),
            Row(t+lag, "5100.00", "5100.25"), Row(end, "5002.00", "5002.25"),
            Row(end+lag, "5003.00", "5003.25"), Row(end+NS, "5003.00", "5003.25"))
    result.append(Fixture("equal_time_source_order", tied, exit_decision_ns=end))
    return result


class ProbeStrategy(Strategy):
    def __init__(self, instrument, scenario, fixture):
        super().__init__(StrategyConfig(strategy_id="PROBE-001"))
        self.instrument = instrument
        self.scenario, self.fixture = scenario, fixture
        self.lag = scenario["latency_ms"] * 1_000_000
        self.gate = QuoteGate(max_quote_age_ns=0, instrument_id=7849)
        first = fixture.rows[0].ts
        self.gate.consume(ReplayEvent("status", 0, 0, first-1, first-1, 7849, 1, None, 7,
                                     trading_indicator=ord("Y"), quoting_indicator=ord("Y")))
        self.ordinal = 0
        self.pending = None
        self.entered = self.exit_requested = False
        self.quantity = fixture.quantity
        self.fills, self.lifecycle, self.decisions, self.blocked = [], [], [], []
        self.last_quote_ns = None
        self.last_quote_ordinal = None
        self.entry_quantity_reference = None

    def on_start(self):
        self.subscribe_quote_ticks(self.instrument.id)
        if self.fixture.force_flat:
            self.clock.set_time_alert_ns("forced-flat", FLAT_NS, self.on_flat, allow_past=False)

    def on_flat(self, event):
        if self.entered and not self.exit_requested:
            self.set_pending("EXIT", "SELL" if self.fixture.side == "BUY" else "BUY", FLAT_NS, "FORCED_FLAT")

    def set_pending(self, role, side, now, reason):
        if role == "EXIT":
            self.exit_requested = True
        self.decisions.append({"role": role, "side": side, "decision_ns": now,
                               "eligible_at_ns": now+self.lag, "decision_ordinal": self.ordinal, "reason": reason})
        self.pending = (role, side, now+self.lag, self.ordinal)
        if self.fixture.heartbeat:
            self.clock.set_time_alert_ns("heartbeat-"+role, now+self.lag, self.on_heartbeat, allow_past=False)
        if self.fixture.mode in ("native_latency", "raw_defaults"):
            self.submit_market(role, side)

    def on_heartbeat(self, event):
        # A real native timer proves the engine can process delayed commands
        # with an old quote. The freshness-gated mode submits nothing here.
        self.lifecycle.append({"kind": "Heartbeat", "timestamp_ns": int(event.ts_event)})

    def submit_market(self, role, side):
        self.pending = None
        self.submit_order(self.order_factory.market(instrument_id=self.instrument.id,
                          order_side=OrderSide.BUY if side == "BUY" else OrderSide.SELL,
                          quantity=Quantity.from_int(self.quantity), reduce_only=role == "EXIT",
                          tags=[role]))

    def on_quote_tick(self, tick):
        self.ordinal += 1
        now = int(tick.ts_init)
        self.last_quote_ns, self.last_quote_ordinal = now, self.ordinal
        event = ReplayEvent("mbp-1", self.ordinal, self.ordinal, now, int(tick.ts_event), 7849, 1,
                            self.ordinal, ord("A"), flags=128,
                            bid_px_raw=int(tick.bid_price.as_decimal()*NS), ask_px_raw=int(tick.ask_price.as_decimal()*NS),
                            bid_size=10, ask_size=10)
        self.gate.consume(event)
        if self.ordinal == 1:
            if self.fixture.size_at == "decision":
                price = tick.ask_price if self.fixture.side == "BUY" else tick.bid_price
                self.quantity = self.risk_size(price.as_decimal())
            self.set_pending("ENTRY", self.fixture.side, now, "SYNTHETIC_DECISION")
        if self.entered and not self.exit_requested:
            if self.fixture.exit_decision_ns is not None and now >= self.fixture.exit_decision_ns:
                self.set_pending("EXIT", "SELL" if self.fixture.side == "BUY" else "BUY", now, "SYNTHETIC_EXIT")
            elif (self.fixture.stop and self.fixture.size_at == "fixed" and self.fixture.mode != "native_standing_stop"
                  and self.fixture.mode != "raw_default_stop" and tick.bid_price.as_decimal() <= Decimal(self.fixture.stop)):
                self.set_pending("EXIT", "SELL", now, "STOP_GAP_TRIGGER")
        if self.pending is None:
            return
        role, side, eligible, ordinal = self.pending
        if role == "EXIT" and self.fixture.force_flat and now > DEADLINE_NS:
            self.blocked.append({"timestamp_ns": now, "reason": "FORCED_FLAT_DEADLINE_MISSED"})
            return
        if role == "ENTRY" and self.fixture.size_at != "fixed":
            candidate = self.risk_size(tick.ask_price.as_decimal())
            if now >= eligible:
                self.entry_quantity_reference = candidate
            if self.fixture.size_at == "fill":
                self.quantity = candidate
        if self.quantity < 1:
            self.blocked.append({"timestamp_ns": now, "reason": "RISK_SKIP"})
            return
        decision = self.gate.execution_quote(now, side, self.quantity, after_ordinal=ordinal, eligible_at_ns=eligible)
        if decision.eligible:
            self.submit_market(role, side)
        else:
            self.blocked.append({"timestamp_ns": now, "reasons": list(decision.reasons)})

    def risk_size(self, price):
        return fixed_risk_size(int(abs(price-Decimal(self.fixture.stop))*NS), "MES", self.scenario)

    def on_order_event(self, event):
        self.lifecycle.append({"kind": type(event).__name__, "timestamp_ns": int(event.ts_event),
                               "client_order_id": str(event.client_order_id)})

    def on_order_filled(self, event):
        self.fills.append({"side": event.order_side.name, "quantity": str(event.last_qty),
                           "price": str(event.last_px), "commission_usd": f"{event.commission.as_decimal():.2f}",
                           "timestamp_ns": int(event.ts_event), "client_order_id": str(event.client_order_id),
                           "last_strategy_quote_ns": self.last_quote_ns,
                           "last_strategy_quote_ordinal": self.last_quote_ordinal,
                           "age_of_last_strategy_quote_ns": int(event.ts_event)-self.last_quote_ns})
        if not self.entered:
            self.entered = True
            if self.fixture.mode in ("native_standing_stop", "raw_default_stop"):
                self.exit_requested = True
                self.submit_order(self.order_factory.stop_market(instrument_id=self.instrument.id,
                                  order_side=OrderSide.SELL, quantity=Quantity.from_int(self.quantity),
                                  trigger_price=Price.from_str(self.fixture.stop), reduce_only=True, tags=["EXIT"]))


def expected_fills(fixture, scenario):
    """Independent hand-specified oracle for fixtures which claim parity."""
    slip = scenario["slippage_ticks_per_side"] * TICK
    if fixture.mode in ("raw_defaults", "raw_default_stop"):
        slip = Decimal(0)
    lag = scenario["latency_ms"] * 1_000_000
    if fixture.name.startswith(("buy_", "sell_")):
        entry, exit = fixture.rows[2], fixture.rows[5]
    elif fixture.name in ("fresh_latency_sparse", "sizing_at_decision", "sizing_at_fill"):
        entry, exit = fixture.rows[1], fixture.rows[3]
    elif fixture.name == "stop_gap_gated":
        entry, exit = fixture.rows[1], fixture.rows[3]
    elif fixture.name == "forced_flat":
        entry, exit = fixture.rows[1], fixture.rows[4]
    elif fixture.name == "forced_flat_missing_quote":
        entry, exit = fixture.rows[1], None
    elif fixture.name == "native_latency_sparse":
        entry, exit = fixture.rows[0], fixture.rows[2]
    elif fixture.name == "equal_time_source_order":
        entry, exit = fixture.rows[1], fixture.rows[4]
    elif fixture.name == "stop_gap_native_standing":
        entry, exit = fixture.rows[1], fixture.rows[2]
    elif fixture.name == "raw_defaults_market":
        entry, exit = fixture.rows[0], fixture.rows[3]
    elif fixture.name == "raw_defaults_standing_stop":
        entry = fixture.rows[1]
        # Installed default L1 matching fills this stop at its trigger price.
        # Explicit counterexample, not the admissible frozen stop-gap model.
        exit = Row(fixture.rows[2].ts, fixture.stop, fixture.stop)
    else:
        raise ValueError("FIXTURE_WITHOUT_ORACLE")
    quantity = 2 if fixture.size_at == "decision" else 1 if fixture.size_at == "fill" else fixture.quantity
    fee = Decimal(str(scenario["commission_usd_round_turn_per_micro"]))*quantity/2
    result = []
    for row, side in ((entry, fixture.side), (exit, "SELL" if fixture.side == "BUY" else "BUY")):
        if row is None:
            continue
        price = Decimal(row.ask)+slip if side == "BUY" else Decimal(row.bid)-slip
        stamp = row.ts+lag if fixture.mode == "native_latency" else row.ts
        result.append({"side": side, "quantity": str(quantity), "price": f"{price:.2f}",
                       "commission_usd": f"{fee:.2f}", "timestamp_ns": stamp})
    return result


def run_fixture(instrument, scenario, fixture):
    require(1 <= fixture.quantity <= 2 and fixture.side in ("BUY", "SELL"), "INVALID_FIXTURE")
    require(all(a.ts <= b.ts for a, b in zip(fixture.rows, fixture.rows[1:])), "UNORDERED_FIXTURE")
    raw_default = fixture.mode in ("raw_defaults", "raw_default_stop")
    model = FillModel(random_seed=7) if raw_default else FrozenSyntheticFillModel(scenario["slippage_ticks_per_side"])
    engine = BacktestEngine(BacktestEngineConfig(logging=LoggingConfig(bypass_logging=True)))
    strategy = ProbeStrategy(instrument, scenario, fixture)
    latency = (LatencyModel(base_latency_nanos=0, insert_latency_nanos=scenario["latency_ms"]*1_000_000)
               if fixture.mode == "native_latency" else None)
    engine.add_venue(venue=Venue("GLBX"), oms_type=OmsType.NETTING, account_type=AccountType.MARGIN,
                     base_currency=USD, starting_balances=[Money(50_000, USD)], book_type=BookType.L1_MBP,
                     fee_model=PerContractFeeModel(Money(Decimal(str(scenario["commission_usd_round_turn_per_micro"]))/2, USD)),
                     fill_model=model, latency_model=latency, use_message_queue=True)
    engine.add_instrument(instrument)
    try:
        engine.add_strategy(strategy)
        quotes = [QuoteTick(instrument_id=instrument.id, bid_price=Price.from_str(row.bid), ask_price=Price.from_str(row.ask),
                            bid_size=Quantity.from_int(10), ask_size=Quantity.from_int(10),
                            ts_event=row.ts-50_000, ts_init=row.ts) for row in fixture.rows]
        engine.add_data(quotes)
        engine.run()
        flat = not engine.cache.positions_open(instrument_id=instrument.id)
        actual = [{key: fill[key] for key in ("side", "quantity", "price", "commission_usd", "timestamp_ns")}
                  for fill in strategy.fills]
        expected = expected_fills(fixture, scenario)
        require(flat == fixture.expect_flat, "UNEXPECTED_FLAT_STATE:"+fixture.name)
        if expected is not None:
            require(actual == expected, "FILL_ORACLE_MISMATCH:"+fixture.name+":"+json.dumps(actual))
        balance = engine.cache.account_for_venue(Venue("GLBX")).balance_total(USD).as_decimal()
        fees = sum((Decimal(x["commission_usd"]) for x in strategy.fills), Decimal(0))
        expected_balance = None
        if flat and len(strategy.fills) == 2:
            direction = 1 if fixture.side == "BUY" else -1
            expected_balance = (Decimal(50000)+direction*(Decimal(strategy.fills[1]["price"])-Decimal(strategy.fills[0]["price"]))
                                *Decimal(strategy.fills[0]["quantity"])*5-fees)
            require(balance == expected_balance, "NATIVE_ACCOUNTING_MISMATCH")
        return {"fixture": fixture.name, "scenario": scenario["id"], "mode": fixture.mode,
                "classification": "SYNTHETIC_MECHANICS_ONLY", "quotes": len(quotes),
                "synthetic_quotes": [{"source_ordinal": j+1, "ts_recv_ns": row.ts,
                                      "ts_exchange_ns": row.ts-50_000, "bid": row.bid, "ask": row.ask,
                                      "bid_size": 10, "ask_size": 10} for j, row in enumerate(fixture.rows)],
                "expected_fills": expected, "actual_fills": strategy.fills,
                "oracle": "MATCH",
                "decisions": strategy.decisions, "lifecycle": strategy.lifecycle, "blocked": strategy.blocked,
                "native_model_calls": [] if raw_default else model.calls, "ending_flat": flat,
                "fill_model": "NATIVE_DEFAULT_NO_SLIPPAGE" if raw_default else "FROZEN_SYNTHETIC_N_TICKS",
                "fee_model": "PER_CONTRACT_FROZEN_SCENARIO_RT_DIVIDED_BY_2",
                "expected_flat": fixture.expect_flat, "ending_balance_usd": f"{balance:.2f}",
                "independently_reconciled_balance_usd": f"{expected_balance:.2f}" if expected_balance is not None else None,
                "total_commissions_usd": str(fees), "reference_quantity_at_first_eligible_quote": strategy.entry_quantity_reference,
                "quantity_policy": fixture.size_at, "exchange_timestamp_offset_ns": -50_000,
                "reference_parity_claim": fixture.mode == "fresh_gate" and fixture.size_at != "decision"
                                          and fixture.expect_flat}
    finally:
        engine.dispose()


def run_probe():
    instrument = load_instrument()
    results = [run_fixture(instrument, scenario, fixture) for scenario in scenarios() for fixture in fixture_set(scenario)]
    return {"classification": "BOUNDED_NATIVE_SYNTHETIC_EXECUTION_PROBE", "engine_version": nautilus_trader.__version__,
            "instrument": "MESM9.GLBX", "instrument_definition_sha256": DEF_SHA256,
            "multiplier": "5", "tick_size": "0.25", "currency": "USD", "source_events": "SYNTHETIC_ONLY",
            "costs": scenarios(), "fixtures": results, "fixture_count": len(results),
            "native_engine_roles": ["order lifecycle", "fill application", "position accounting", "per-contract commission"],
            "explicit_adapters": {"slippage": "N adverse ticks via custom FillModel; fixed synthetic depth 10 per side",
                                  "freshness": "QuoteGate max_quote_age_ns=0 before native market submission",
                                  "latency": "Gate waits until first fresh quote at/after decision+latency; native order latency zero thereafter",
                                  "gated_stop": "Client observes stop crossing, then applies same fresh-quote/latency gate",
                                  "clock": "Native timers for forced-flat decision and sparse latency counterexample"},
            "remaining_integration_gaps": [
                "Synthetic fixture parity does not validate real-session signal, status, raw DBN ordering, or native full-strategy replay.",
                "Raw-default fixtures retain frozen per-contract fees but deliberately use native FillModel/no native latency, without frozen slippage; they are counterexamples, not conforming runs.",
                "Native default L1 stop-market pricing can fill at the stop trigger through a gap; the gated custom fill model is required for the frozen quote-price policy.",
                "Native LatencyModel alone can fill on a timer using an older BBO; it is not the frozen fresh-quote policy.",
                "A standing native stop can execute at trigger without the reference post-trigger latency; it is a distinct execution policy.",
                "Standing stops fill during native quote processing before the strategy quote callback: last_strategy_quote age is not book age for those fills.",
                "Quantity submitted at decision remains fixed in native orders; the reference currently chooses quantity at eligible fill quote.",
                "The sizing_at_decision fixture freezes quantity at decision but submits only after QuoteGate eligibility; it does not claim to model cancellation or resizing of an already queued order.",
                "The bounded synthetic FillModel is not a production visible-depth or partial-fill model; QuoteGate must precede submission.",
                "Forced-flat deadline failure stays invalid with open exposure; no fabricated exit or forward-filled quote.",
                "Native full-session marked-equity event parity, risk breaches, cancellation/race behavior, and strategy lifecycle still need integration.",
                "These are frozen research cost assumptions, not verified provider commissions or an economic profitability result."],
            "full_frozen_trial": "NOT_RUN", "live_connection": False, "economic_pass": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    dependency_names = ("native_execution_probe.py", "test_native_execution_probe.py", "strategy_runner.py",
                        "replay_adapter.py", "validate_databento_pilot.py", "preregister.py")
    dependencies = {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in dependency_names}
    first, second = run_probe(), run_probe()
    require(digest(first) == digest(second), "DETERMINISM_MISMATCH")
    require(dependencies == {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in dependency_names},
            "SOURCE_CHANGED_DURING_PROBE")
    result = {"status": "PASS", "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
              "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "dependency_sha256": dependencies,
              "status_scope": "Expected mechanics and expected negative cases matched; no economic or full native strategy pass",
              "repeat_count": 2, "deterministic_result_sha256": digest(first), "result": first}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    args.output.with_suffix(".md").write_text(
        "# Native execution probe — synthetic mechanics only\n\n"
        f"NautilusTrader 1.221.0: {first['fixture_count']} bounded fixtures, two identical runs. "
        "All expected fills, fees, lifecycle ordering and expected failure cases matched. "
        f"Deterministic result SHA256: `{digest(first)}`.\n\n"
        "MESM9.GLBX metadata come from the locally hash-verified definition (multiplier $5/point, tick 0.25, USD). "
        "Every price event is synthetic. The three frozen assumptions are BASE ($1.90 RT, 1 tick/side, 100 ms), "
        "ADVERSE ($2.50, 2 ticks, 250 ms), SEVERE ($3.00, 4 ticks, 750 ms). Fees are charged per contract per side.\n\n"
        "| BASE counterexample | Native temporal/default behavior | Fresh-gated custom-fill behavior |\n"
        "|---|---|---|\n"
        "| Sparse quote latency | Timer fills old ask at 5000.50 after 100 ms | First new ask fills 5002.50 after 1 s |\n"
        "| Stop 4998 through bid gap | Default L1 fills 4998.00; custom-priced standing stop fills 4994.75 immediately | Client stop fills 4994.25 after 100 ms |\n"
        "| Quantity selection | Decision-frozen quantity 2 remains 2 | First eligible quote implies quantity 1 |\n\n"
        "Native default market/stop fixtures keep frozen fees but deliberately omit the frozen slippage/latency adapters. "
        "Native-latency and standing-stop fixtures use the custom N-tick prices but preserve native temporal handling. "
        "Fresh-gated fixtures wait for QuoteGate eligibility and then submit a zero-additional-latency native market order. "
        "The sizing-at-decision fixture freezes quantity early and submits after eligibility; queued-order cancellation/resizing is not tested.\n\n"
        "Both BUY and SELL, quantities 1 and 2, all three cost scenarios, exact latency boundaries, "
        "equal receive timestamps in source order, gap stops, native 15:55 New York timer and a missed 15:59:30 flat deadline are covered. "
        "The missed deadline correctly leaves open exposure and an explicit invalid reason. Same-time later quotes do not overwrite the first eligible quote.\n\n"
        "The custom fill model has only synthetic depth 10 and quantity <=2. This is **not evidence of real liquidity**, "
        "partial fills, actual provider fees, or usable live execution. Fresh native market orders are **not a complete native strategy runner**. "
        "Real-session signal/status integration, DBN-to-native ordering, per-event marked equity/risk parity, cancellation races and full strategy lifecycle remain open. "
        "The frozen economic trial remains **NOT_RUN**; no market replay, account connection, credential access or download occurred.\n",
        encoding="utf-8")
    print(json.dumps({"status": "PASS", "fixtures_per_repeat": first["fixture_count"], "report": str(args.output)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
