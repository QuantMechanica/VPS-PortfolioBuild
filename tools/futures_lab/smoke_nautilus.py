"""Small, offline Nautilus 1.221.0 data/engine/accounting smoke.

No live node, API client, broker, account or third-party strategy is started.
--fetch downloads only two hash-pinned official fixture URLs (<55 KB total).
The historical fixture is a snapshot, so the roundtrip uses SEPARATE synthetic
quotes. Its spread loss and fees are an accounting assertion, not an edge test.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import platform
import sys
import urllib.request

DEFAULT_DATA = Path("D:/QM/futures_lab/data/fixtures")
DEFAULT_REPORT = Path("D:/QM/reports/research/futures_pivot_20260922/nautilus_smoke")
OFFICIAL_BASE = "https://raw.githubusercontent.com/nautechsystems/nautilus_trader/v1.221.0/tests/test_data/databento/"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_hash(value) -> str:
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), default=str).encode())


def ensure_fixtures(root: Path, fetch: bool) -> list[dict]:
    manifest = json.loads(Path(__file__).with_name("fixtures_manifest.json").read_text())
    if sum(x["bytes"] for x in manifest["fixtures"]) > 2_000_000:
        raise ValueError("Fixture cap exceeded")
    root.mkdir(parents=True, exist_ok=True)
    receipts = []
    for row in manifest["fixtures"]:
        if Path(row["name"]).name != row["name"] or row["url"] != OFFICIAL_BASE + row["name"]:
            raise ValueError("Unexpected fixture path or URL")
        path = root / row["name"]
        origin = "existing_local_hash_verified"
        if not path.exists():
            if not fetch:
                raise FileNotFoundError(f"Missing fixture {path}; use --fetch once")
            with urllib.request.urlopen(row["url"], timeout=30) as response:
                if response.geturl() != row["url"]:
                    raise ValueError("Unexpected redirect")
                payload = response.read(row["bytes"] + 1)
            if len(payload) != row["bytes"] or sha256(payload) != row["sha256"]:
                raise ValueError(f"Downloaded fixture hash/size mismatch: {row['name']}")
            path.write_bytes(payload)
            origin = "downloaded_official_hash_verified"
        payload = path.read_bytes()
        if len(payload) != row["bytes"] or sha256(payload) != row["sha256"]:
            raise ValueError(f"Existing fixture hash/size mismatch: {path}")
        receipts.append({**row, "local_path": str(path), "origin": origin})
    return receipts


def run_smoke(data_dir: Path) -> dict:
    import nautilus_trader
    from nautilus_trader.adapters.databento import DatabentoDataLoader
    from nautilus_trader.backtest.config import BacktestEngineConfig
    from nautilus_trader.backtest.engine import BacktestEngine
    from nautilus_trader.backtest.models import FixedFeeModel
    from nautilus_trader.config import LoggingConfig, StrategyConfig
    from nautilus_trader.model.currencies import USD
    from nautilus_trader.model.data import QuoteTick
    from nautilus_trader.model.enums import AccountType, AssetClass, BookType, OmsType, OrderSide
    from nautilus_trader.model.identifiers import InstrumentId, Symbol, Venue
    from nautilus_trader.model.instruments import FuturesContract
    from nautilus_trader.model.objects import Money, Price, Quantity
    from nautilus_trader.trading.strategy import Strategy

    if nautilus_trader.__version__ != "1.221.0":
        raise RuntimeError("This smoke is pinned to NautilusTrader 1.221.0")
    loader = DatabentoDataLoader()
    definitions = loader.from_dbn_file(data_dir / "definition-glbx-es-fut.dbn.zst")
    assert len(definitions) == 2
    assert all(str(x.id) == "ESM3.GLBX" for x in definitions)
    assert all(x.multiplier.as_decimal() == Decimal(50) for x in definitions)
    assert all(x.price_increment.as_decimal() == Decimal("0.25") for x in definitions)
    assert all(str(x.quote_currency) == "USD" for x in definitions)

    # No override of the DBN instrument ID: verify source symbology first.
    deltas = loader.from_dbn_file(data_dir / "esh4-glbx-mdp3-20231224.mbo.dbn.zst")
    assert len(deltas) == 8725
    assert {str(d.instrument_id) for d in deltas} == {"ESH4.GLBX"}
    timestamps = [int(d.ts_init) for d in deltas]
    assert timestamps == sorted(timestamps)
    assert len(set(timestamps)) == 1, "Reviewed fixture changed: expected one snapshot"
    fixture_event_hash = canonical_hash([str(d) for d in deltas])
    venue = Venue("GLBX")
    instrument_id = InstrumentId.from_str("ESH4.GLBX")
    # Explicit, manually constructed lab metadata, NOT the ESM3 definition.
    # The upstream TestInstrumentProvider.es_future uses multiplier=1, so do
    # not use that helper for dollar accounting. Activation is a lab bound.
    instrument = FuturesContract(
        instrument_id=instrument_id, raw_symbol=Symbol("ESH4"),
        asset_class=AssetClass.INDEX, currency=USD, price_precision=2,
        price_increment=Price.from_str("0.25"), multiplier=Quantity.from_int(50),
        lot_size=Quantity.from_int(1), underlying="ES", exchange="XCME",
        activation_ns=int(datetime(2023, 1, 1, tzinfo=timezone.utc).timestamp()) * 1_000_000_000,
        expiration_ns=int(datetime(2024, 3, 15, 13, 30, tzinfo=timezone.utc).timestamp()) * 1_000_000_000,
        ts_event=0, ts_init=0,
        info={"source": "MANUAL_TECHNICAL_TEST_METADATA", "activation_is_lab_bound": True},
    )

    class SnapshotObserver(Strategy):
        def __init__(self):
            super().__init__(StrategyConfig(strategy_id="SNAPSHOT-001"))
            self.batches = 0
            self.observed_deltas = 0

        def on_start(self):
            self.subscribe_order_book_deltas(instrument_id, book_type=BookType.L3_MBO)

        def on_order_book_deltas(self, batch):
            self.batches += 1
            self.observed_deltas += len(batch.deltas)

    def engine_for(book_type):
        engine = BacktestEngine(BacktestEngineConfig(logging=LoggingConfig(bypass_logging=True)))
        engine.add_venue(
            venue=venue, oms_type=OmsType.NETTING, account_type=AccountType.MARGIN,
            base_currency=USD, starting_balances=[Money(50_000, USD)],
            book_type=book_type, fee_model=FixedFeeModel(Money(1, USD)),
        )
        engine.add_instrument(instrument)
        return engine

    engine = engine_for(BookType.L3_MBO)
    observer = SnapshotObserver()
    try:
        engine.add_strategy(observer)
        engine.add_data(deltas)
        engine.run()
        book = engine.cache.order_book(instrument_id)
        snapshot = {
            "classification": "OFFICIAL_DBN_SNAPSHOT_REPLAY_NO_TRADES",
            "decoded_events": len(deltas), "unique_timestamps": len(set(timestamps)),
            "event_hash": fixture_event_hash, "timestamp_ns": timestamps[0],
            "observed_batches": observer.batches, "observed_deltas": observer.observed_deltas,
            "orders": len(engine.cache.orders()),
            "best_bid": str(book.best_bid_price()) if book else None,
            "best_ask": str(book.best_ask_price()) if book else None,
        }
        assert observer.observed_deltas == len(deltas)
        assert snapshot["orders"] == 0
        assert book is not None and book.best_bid_price() and book.best_ask_price()
    finally:
        engine.dispose()

    class IntentionalRoundTrip(Strategy):
        def __init__(self):
            super().__init__(StrategyConfig(strategy_id="SMOKE-001"))
            self.quotes_seen = 0
            self.fills = []

        def on_start(self):
            self.subscribe_quote_ticks(instrument_id)

        def on_quote_tick(self, tick):
            self.quotes_seen += 1
            if self.quotes_seen == 1:
                self.submit_order(self.order_factory.market(
                    instrument_id=instrument_id, order_side=OrderSide.BUY,
                    quantity=Quantity.from_int(1),
                ))
            elif self.quotes_seen == 2:
                assert self.cache.positions_open(instrument_id=instrument_id)
                self.close_all_positions(instrument_id)

        def on_order_filled(self, event):
            self.fills.append({
                "side": event.order_side.name, "quantity": str(event.last_qty),
                "price": str(event.last_px), "commission": str(event.commission),
                "timestamp_ns": int(event.ts_event),
            })

    # Independent SYNTHETIC scenario. Neither prices nor dates are DBN trades.
    # Flat market: deliberately cross one spread and pay $1 per side.
    base_ns = int(datetime(2023, 12, 26, 14, 30, tzinfo=timezone.utc).timestamp()) * 1_000_000_000
    quotes = [QuoteTick(
        instrument_id=instrument_id, bid_price=Price.from_str("5000.00"),
        ask_price=Price.from_str("5000.25"), bid_size=Quantity.from_int(10),
        ask_size=Quantity.from_int(10), ts_event=base_ns+i*1_000_000_000,
        ts_init=base_ns+i*1_000_000_000,
    ) for i in range(3)]
    engine = engine_for(BookType.L1_MBP)
    strategy = IntentionalRoundTrip()
    try:
        engine.add_data(quotes)
        engine.add_strategy(strategy)
        engine.run()
        balance = engine.cache.account_for_venue(venue).balance_total(USD).as_decimal()
        fills = strategy.fills
        assert strategy.quotes_seen == 3
        assert len(fills) == 2 and [x["side"] for x in fills] == ["BUY", "SELL"]
        assert [Decimal(x["price"]) for x in fills] == [Decimal("5000.25"), Decimal("5000.00")]
        assert not engine.cache.positions_open(instrument_id=instrument_id)
        assert balance == Decimal("49985.50"), balance
        synthetic = {
            "classification": "SYNTHETIC_ACCOUNTING_TEST_NOT_MARKET_PERFORMANCE",
            "quotes": len(quotes), "fills": fills, "fills_hash": canonical_hash(fills),
            "one_roundtrip": True, "end_position_flat": True,
            "starting_balance_usd": "50000.00", "ending_balance_usd": str(balance),
            "gross_spread_loss_usd": "12.50", "fees_usd": "2.00", "net_loss_usd": "14.50",
            "fee_assumption": "Artificial fixed $1 per order, not a broker/prop quote",
            "latency_assumption": "Engine default zero latency; no live-fill claim",
        }
    finally:
        engine.dispose()
    return {
        "engine_version": nautilus_trader.__version__,
        "definition_check": {"instrument": "ESM3.GLBX", "definition_records": 2,
                             "multiplier": "50", "tick_size": "0.25", "currency": "USD"},
        "replay_instrument": {"instrument": "ESH4.GLBX", "metadata": "MANUAL_TECHNICAL_TEST_METADATA",
                              "definition_fixture_is_different_contract": True, "multiplier": "50"},
        "snapshot_replay": snapshot, "synthetic_roundtrip": synthetic,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true", help="Download only missing hash-pinned public fixtures")
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--report-dir", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    args.report_dir.mkdir(parents=True, exist_ok=True)
    base = {
        "purpose": "TECHNICAL_SMOKE_ONLY", "live_trading": False,
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
        "python": sys.version, "platform": platform.platform(),
        "script_sha256": sha256(Path(__file__).read_bytes()),
    }
    try:
        base["fixture_receipts"] = ensure_fixtures(args.data_dir, args.fetch)
        first, second = run_smoke(args.data_dir), run_smoke(args.data_dir)
        assert canonical_hash(first) == canonical_hash(second), "Determinism mismatch"
        base.update(status="PASS", result=first, deterministic_repeat_hash=canonical_hash(first),
                    repeated_runs=2, total_fixture_bytes=sum(x["bytes"] for x in base["fixture_receipts"]))
    except Exception as error:
        base.update(status="FAIL", error_type=type(error).__name__, error=str(error))
        (args.report_dir / "result.json").write_text(json.dumps(base, indent=2, default=str)+"\n")
        raise
    (args.report_dir / "result.json").write_text(json.dumps(base, indent=2, default=str)+"\n")
    print(json.dumps({"status": base["status"], "result": str(args.report_dir / "result.json"),
                      "fixture_bytes": base["total_fixture_bytes"], "repeat_hash": base["deterministic_repeat_hash"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
