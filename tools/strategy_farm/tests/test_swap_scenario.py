"""Synthetic-fixture tests for the WS-D swap-scenario engine (REPLACEMENT-cost).

Covers every correctness case named in the Codex WS-D acceptance list plus the round-2
REJECT corrections: long & short, partial closes (FIFO), same-day/no-roll, one- and
multi-night holds, triple rollover, DST/midnight boundary in broker time, weekends/
holidays, rate-unit conversion (points / money-per-lot / percent-annual), contract size,
profit-currency conversion, direction from native deal Type (never P/L sign), EXACT
(entry,exit,volume) reconciliation with count/gross/net/commission/swap/source-hash
authentication (and the fixed gross-vs-net flag), and the whole-book REPLACEMENT overlay
that never double-counts the swap already embedded in the durable stream.
"""
from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

# Resolve the repo root that contains THIS test file, so the suite imports the sibling
# swap_scenario module in whichever checkout it runs from (isolated worktree or canonical).
_REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(_REPO_ROOT))

from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import RoundTrip
from tools.strategy_farm.portfolio import swap_scenario as ss


UTC = dt.timezone.utc


def _dtime(s: str) -> dt.datetime:
    return dt.datetime.strptime(s, "%Y.%m.%d %H:%M:%S").replace(tzinfo=UTC)


def _epoch(s: str) -> int:
    return int(_dtime(s).timestamp())


def make_trip(
    *,
    side: str,
    entry: str,
    exit: str,
    volume: float = 1.0,
    entry_price: float = 100.0,
    exit_price: float = 101.0,
    profit: float = 0.0,
    native_swap: float = 0.0,
    native_commission: float = 0.0,
    symbol: str = "XAUUSD.DWX",
) -> RoundTrip:
    return RoundTrip(
        entry_time=_dtime(entry),
        exit_time=_dtime(exit),
        symbol=symbol,
        side=side,
        volume=volume,
        entry_price=entry_price,
        exit_price=exit_price,
        profit=profit,
        native_swap=native_swap,
        native_commission=native_commission,
    )


def stream_row(
    *,
    entry: str,
    exit: str,
    volume: float = 1.0,
    profit: float = 0.0,
    swap: float = 0.0,
    commission: float = 0.0,
    net: float | None = None,
    symbol: str = "XAUUSD.DWX",
) -> dict:
    """A durable Q08 TRADE_CLOSED stream row (epoch entry_time/time; net includes swap)."""
    if net is None:
        net = profit + swap + commission
    return {
        "event": "TRADE_CLOSED",
        "entry_time": _epoch(entry),
        "time": _epoch(exit),
        "volume": volume,
        "profit": profit,
        "swap": swap,
        "commission": commission,
        "net": net,
        "symbol": symbol,
    }


def render_report(deals, *, total_trades: int, period: str, symbol: str = "XAUUSD.DWX") -> str:
    """Render a minimal MT5 report.htm the reused parser accepts.

    deals: list of (time, symbol, type, direction, volume, price, commission, swap, profit).
    """
    def row(cells):
        return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"

    header = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order",
              "Commission", "Swap", "Profit", "Balance", "Comment"]
    parts = ["<html><body><table>"]
    parts.append(row(["Symbol", symbol]))
    parts.append(row(["Period", period]))
    parts.append(row(["Total Net Profit", "0.00"]))
    parts.append(row(["Total Trades", str(total_trades)]))
    parts.append(row(["Deals"]))
    parts.append(row(header))
    deal_no = 1
    for (time, sym, typ, direction, vol, price, comm, swap, profit) in deals:
        parts.append(row([time, str(deal_no), sym, typ, direction, vol, price, "0",
                          comm, swap, profit, "0.00", ""]))
        deal_no += 1
    parts.append("</table></body></html>")
    return "".join(parts)


def write_report(text: str) -> Path:
    fh = tempfile.NamedTemporaryFile("w", suffix=".htm", delete=False, encoding="utf-8")
    fh.write(text)
    fh.close()
    return Path(fh.name)


class RolloverUnitTests(unittest.TestCase):
    def test_same_day_no_roll(self):
        t = make_trip(side="buy", entry="2019.06.03 08:00:00", exit="2019.06.03 20:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 0)

    def test_one_night(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 1)

    def test_midnight_boundary_broker_time(self):
        t1 = make_trip(side="buy", entry="2019.06.03 23:30:00", exit="2019.06.04 00:30:00")
        self.assertEqual(ss.swap_rollover_units(t1.entry_time, t1.exit_time), 1)
        t2 = make_trip(side="buy", entry="2019.06.04 00:30:00", exit="2019.06.04 23:30:00")
        self.assertEqual(ss.swap_rollover_units(t2.entry_time, t2.exit_time), 0)

    def test_multi_night(self):
        t = make_trip(side="buy", entry="2019.06.03 12:00:00", exit="2019.06.06 12:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 5)

    def test_triple_wednesday(self):
        t = make_trip(side="buy", entry="2019.06.05 12:00:00", exit="2019.06.06 12:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 3)

    def test_weekend_holiday_no_extra_units(self):
        t = make_trip(side="buy", entry="2019.06.07 12:00:00", exit="2019.06.10 12:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 1)

    def test_dst_span_counts_each_server_midnight(self):
        t = make_trip(side="buy", entry="2020.03.06 12:00:00", exit="2020.03.09 12:00:00")
        self.assertEqual(ss.swap_rollover_units(t.entry_time, t.exit_time), 1)


class SwapModeTests(unittest.TestCase):
    def _rate(self, **kw):
        base = dict(symbol="XAUUSD.DWX", swap_mode=ss.SWAP_MODE_POINTS, swap_long=-5.0,
                    swap_short=-3.0, contract_size=100.0, digits=2, known=True)
        base.update(kw)
        return ss.SwapRate(**base)

    def test_points_long_one_night(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        r = ss.trade_swap_drag(t, self._rate())
        self.assertEqual(r.rollover_units, 1)
        self.assertAlmostEqual(r.swap_account_ccy, -5.0, places=6)

    def test_points_short_uses_short_rate(self):
        t = make_trip(side="sell", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        r = ss.trade_swap_drag(t, self._rate())
        self.assertAlmostEqual(r.swap_account_ccy, -3.0, places=6)

    def test_contract_size_scales_points(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        half = ss.trade_swap_drag(t, self._rate(contract_size=50.0))
        self.assertAlmostEqual(half.swap_account_ccy, -2.5, places=6)

    def test_profit_currency_conversion(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        r = ss.trade_swap_drag(t, self._rate(profit_ccy_to_account_rate=0.9))
        self.assertAlmostEqual(r.swap_account_ccy, -4.5, places=6)

    def test_money_per_lot_mode(self):
        t = make_trip(side="sell", volume=2.0, entry="2019.06.03 12:00:00", exit="2019.06.05 12:00:00")
        rate = self._rate(swap_mode=ss.SWAP_MODE_MONEY_PER_LOT, swap_long=-1.0, swap_short=-3.5)
        r = ss.trade_swap_drag(t, rate)
        self.assertEqual(r.rollover_units, 2)
        self.assertAlmostEqual(r.swap_account_ccy, -3.5 * 2.0 * 2, places=6)  # -14.0

    def test_percent_annual_mode(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        rate = self._rate(swap_mode=ss.SWAP_MODE_PERCENT_ANNUAL, swap_long=-2.5, swap_short=-2.5)
        r = ss.trade_swap_drag(t, rate)
        expected = (-2.5 / 100.0) / ss.PERCENT_ANNUAL_DAY_COUNT * 10000.0 * 1
        self.assertAlmostEqual(r.swap_account_ccy, expected, places=6)

    def test_same_day_zero_swap(self):
        t = make_trip(side="buy", entry="2019.06.03 08:00:00", exit="2019.06.03 20:00:00")
        self.assertEqual(ss.trade_swap_drag(t, self._rate()).swap_account_ccy, 0.0)

    def test_unknown_rate_refuses(self):
        t = make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")
        with self.assertRaises(ValueError):
            ss.trade_swap_drag(t, ss.SwapRate.unknown("XAUUSD.DWX"))


class DirectionFromReportTests(unittest.TestCase):
    def test_side_from_type_not_pnl_sign(self):
        deals = [
            ("2019.06.03 20:00:00", "XAUUSD.DWX", "buy", "in", "1.0", "100.0", "0.00", "0.00", "0.00"),
            ("2019.06.04 08:00:00", "XAUUSD.DWX", "sell", "out", "1.0", "99.0", "0.00", "0.00", "-100.00"),
            ("2019.06.05 20:00:00", "XAUUSD.DWX", "sell", "in", "1.0", "100.0", "0.00", "0.00", "0.00"),
            ("2019.06.06 08:00:00", "XAUUSD.DWX", "buy", "out", "1.0", "99.0", "0.00", "0.00", "100.00"),
        ]
        rp = write_report(render_report(deals, total_trades=2, period="Daily (2019.01.01 - 2019.12.31)"))
        trips, stats, sha = ss.extract_sleeve_round_trips(rp, "XAUUSD.DWX")
        self.assertEqual(len(trips), 2)
        self.assertEqual(trips[0].side, "buy")   # losing long
        self.assertLess(trips[0].profit, 0.0)
        self.assertEqual(trips[1].side, "sell")  # winning short
        self.assertGreater(trips[1].profit, 0.0)
        self.assertEqual(len(sha), 64)

    def test_partial_close_fifo(self):
        deals = [
            ("2019.06.03 20:00:00", "XAUUSD.DWX", "buy", "in", "0.6", "100.0", "0.00", "0.00", "0.00"),
            ("2019.06.03 20:05:00", "XAUUSD.DWX", "buy", "in", "0.4", "100.0", "0.00", "0.00", "0.00"),
            ("2019.06.05 08:00:00", "XAUUSD.DWX", "sell", "out", "1.0", "101.0", "0.00", "0.00", "100.00"),
        ]
        rp = write_report(render_report(deals, total_trades=2, period="Daily (2019.01.01 - 2019.12.31)"))
        trips, stats, sha = ss.extract_sleeve_round_trips(rp, "XAUUSD.DWX")
        self.assertEqual(len(trips), 2)
        self.assertAlmostEqual(sum(t.volume for t in trips), 1.0, places=6)
        self.assertAlmostEqual(sum(t.profit for t in trips), 100.0, places=6)

    def test_embedded_swap_from_report(self):
        deals = [
            ("2019.06.03 20:00:00", "USDJPY.DWX", "sell", "in", "1.0", "110.0", "-2.5", "0.00", "0.00"),
            ("2019.06.05 08:00:00", "USDJPY.DWX", "buy", "out", "1.0", "109.0", "-2.5", "6.10", "100.00"),
        ]
        rp = write_report(render_report(deals, total_trades=1,
                                        period="M30 (2019.01.01 - 2019.12.31)", symbol="USDJPY.DWX"))
        trips, stats, sha = ss.extract_sleeve_round_trips(rp, "USDJPY.DWX")
        exp = ss.sleeve_overnight_exposure(trips)
        self.assertAlmostEqual(exp.embedded_swap_total, 6.10, places=2)
        self.assertAlmostEqual(exp.embedded_swap_short, 6.10, places=2)
        self.assertGreater(exp.total_rollover_units, 0)


class ReconcileTests(unittest.TestCase):
    """Exact (entry,exit,volume) reconciliation + one authenticated cost record."""

    def _trips(self):
        return [
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                      volume=1.0, profit=100.0, native_swap=-2.0, native_commission=-1.0),
            make_trip(side="sell", entry="2019.06.05 20:00:00", exit="2019.06.06 08:00:00",
                      volume=0.5, profit=-40.0, native_swap=-1.0, native_commission=-0.5),
        ]

    def _stream(self, **overrides):
        rows = [
            stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                       volume=1.0, profit=100.0, swap=-2.0, commission=-1.0),
            stream_row(entry="2019.06.05 20:00:00", exit="2019.06.06 08:00:00",
                       volume=0.5, profit=-40.0, swap=-1.0, commission=-0.5),
        ]
        return rows

    def test_exact_match_all_fields_tie(self):
        res = ss.reconcile_report_to_stream(self._trips(), self._stream(), report_sha256="a" * 64)
        self.assertEqual(res.status, ss.RECON_MATCH)
        self.assertTrue(res.reconciled)
        self.assertTrue(res.volume_tied)
        self.assertTrue(res.gross_profit_tied)
        self.assertTrue(res.net_tied)
        self.assertTrue(res.commission_tied)
        self.assertTrue(res.swap_tied)
        self.assertTrue(res.fully_authenticated)
        self.assertEqual(res.matched_positions, 2)
        self.assertEqual(res.report_only_positions, 0)
        self.assertEqual(res.stream_only_positions, 0)
        self.assertEqual(res.report_sha256, "a" * 64)

    def test_gross_flag_compares_profit_to_profit_not_net(self):
        # Round-1 bug: gross_profit_tied compared report GROSS profit to stream NET
        # (which already carries swap+commission). Here report gross profit == stream
        # profit but stream NET differs from gross by swap+commission; the fixed flag
        # must key on profit, and net_tied on net, INDEPENDENTLY.
        res = ss.reconcile_report_to_stream(self._trips(), self._stream())
        # stream gross profit = 60.0 ; stream net = 60 - 3 - 1.5 = 55.5
        self.assertAlmostEqual(res.stream_gross_profit, 60.0, places=2)
        self.assertAlmostEqual(res.stream_net, 55.5, places=2)
        self.assertAlmostEqual(res.report_gross_profit, 60.0, places=2)
        self.assertTrue(res.gross_profit_tied)   # profit vs profit
        self.assertTrue(res.net_tied)            # net vs net (same convention here)

    def test_commission_convention_offset_does_not_break_authentication(self):
        # Real book: the durable stream logs commission per-side while the native report
        # sums entry+exit deal commissions, so report_commission == 2 * stream_commission
        # for an identical backtest. That structural offset must NOT read as drift: raw
        # commission_tied is False, the ratio exposes the 2.0 convention, and the
        # convention-free net (profit+swap) ties -> fully_authenticated stays True.
        trips = [
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                      volume=1.0, profit=100.0, native_swap=-2.0, native_commission=-4.0),
        ]
        stream = [stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                             volume=1.0, profit=100.0, swap=-2.0, commission=-2.0)]
        res = ss.reconcile_report_to_stream(trips, stream)
        self.assertEqual(res.status, ss.RECON_MATCH)
        self.assertTrue(res.reconciled)
        self.assertTrue(res.gross_profit_tied)
        self.assertTrue(res.swap_tied)
        self.assertFalse(res.commission_tied)          # raw values differ (per-side vs round-trip)
        self.assertAlmostEqual(res.commission_convention_ratio, 2.0, places=3)
        self.assertTrue(res.net_ex_commission_tied)    # profit+swap ties
        self.assertFalse(res.net_tied)                 # raw net inherits the commission offset
        self.assertTrue(res.fully_authenticated)       # convention-free fields all tie

    def test_recompile_swap_drift_still_reconciles_but_flags_swap(self):
        # Identical population/prices, only the swap config drifted between builds
        # (report swap heavier than the stream's embedded swap). Exact bijection holds,
        # so the sleeve is attributable, but swap_tied/net_tied expose the drift and
        # fully_authenticated is False.
        trips = [
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                      volume=1.0, profit=100.0, native_swap=-9.0, native_commission=-1.0),
        ]
        stream = [stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                             volume=1.0, profit=100.0, swap=-2.0, commission=-1.0)]
        res = ss.reconcile_report_to_stream(trips, stream)
        self.assertEqual(res.status, ss.RECON_MATCH)
        self.assertTrue(res.reconciled)
        self.assertTrue(res.volume_tied)
        self.assertTrue(res.gross_profit_tied)   # profit identical
        self.assertTrue(res.commission_tied)     # commission identical
        self.assertFalse(res.swap_tied)          # swap drifted
        self.assertFalse(res.net_tied)           # net drifted (via swap)
        self.assertFalse(res.fully_authenticated)

    def test_population_drift_is_unknown(self):
        # An extra stream position with no report counterpart breaks the bijection.
        stream = self._stream() + [
            stream_row(entry="2019.06.10 20:00:00", exit="2019.06.11 08:00:00",
                       volume=0.3, profit=10.0, swap=-0.5, commission=-0.2)
        ]
        res = ss.reconcile_report_to_stream(self._trips(), stream)
        self.assertEqual(res.status, ss.RECON_POP_DRIFT)
        self.assertFalse(res.reconciled)
        self.assertEqual(res.stream_only_positions, 1)

    def test_matched_key_volume_drift_is_unknown(self):
        stream = [
            stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                       volume=5.0, profit=100.0, swap=-2.0, commission=-1.0),
            stream_row(entry="2019.06.05 20:00:00", exit="2019.06.06 08:00:00",
                       volume=0.5, profit=-40.0, swap=-1.0, commission=-0.5),
        ]
        res = ss.reconcile_report_to_stream(self._trips(), stream)
        self.assertEqual(res.status, ss.RECON_POP_DRIFT)
        self.assertFalse(res.reconciled)

    def test_partial_fill_fragments_aggregate_to_one_position(self):
        # Report fragments a single position into two FIFO round trips; the stream logs
        # it as one TRADE_CLOSED. Aggregation by (entry,exit) reconciles them exactly.
        trips = [
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.05 08:00:00",
                      volume=0.6, profit=60.0, native_swap=-1.2, native_commission=-0.6),
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.05 08:00:00",
                      volume=0.4, profit=40.0, native_swap=-0.8, native_commission=-0.4),
        ]
        stream = [stream_row(entry="2019.06.03 20:00:00", exit="2019.06.05 08:00:00",
                             volume=1.0, profit=100.0, swap=-2.0, commission=-1.0)]
        res = ss.reconcile_report_to_stream(trips, stream)
        self.assertEqual(res.status, ss.RECON_MATCH)
        self.assertTrue(res.reconciled)
        self.assertEqual(res.report_positions, 1)
        self.assertEqual(res.report_fragments, 2)
        self.assertEqual(res.stream_positions, 1)
        self.assertTrue(res.fully_authenticated)

    def test_no_stream(self):
        res = ss.reconcile_report_to_stream(self._trips(), [])
        self.assertEqual(res.status, ss.RECON_NO_STREAM)
        self.assertFalse(res.reconciled)

    def test_missing_entry_time_cannot_exact_match(self):
        rows = [{"event": "TRADE_CLOSED", "time": _epoch("2019.06.04 08:00:00"),
                 "volume": 1.0, "net": 97.0, "profit": 100.0, "swap": -2.0, "commission": -1.0}]
        res = ss.reconcile_report_to_stream(self._trips(), rows)
        self.assertEqual(res.status, ss.RECON_NO_ENTRY_TIME)
        self.assertFalse(res.reconciled)


class SwapReplacementTests(unittest.TestCase):
    def test_replacement_series_delta_is_source_minus_stream(self):
        trips = [
            make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                      volume=1.0, native_swap=-9.0),
        ]
        stream = [stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00",
                             volume=1.0, swap=-2.0)]
        repl = ss.sleeve_swap_replacement(trips, stream, basis=ss.SWAP_BASIS_EMBEDDED)
        day = dt.date(2019, 6, 4)
        self.assertAlmostEqual(repl.total_stream_swap, -2.0, places=6)
        self.assertAlmostEqual(repl.total_source_swap, -9.0, places=6)
        self.assertAlmostEqual(repl.total_delta, -7.0, places=6)  # -9 - (-2)
        self.assertAlmostEqual(repl.daily_delta[day], -7.0, places=6)

    def test_scenario_replacement_requires_known_rate(self):
        trips = [make_trip(side="buy", entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")]
        stream = [stream_row(entry="2019.06.03 20:00:00", exit="2019.06.04 08:00:00")]
        with self.assertRaises(ValueError):
            ss.sleeve_swap_replacement(trips, stream, basis=ss.SWAP_BASIS_SCENARIO,
                                       rate=ss.SwapRate.unknown("XAUUSD.DWX"))


class BookReplacementOverlayTests(unittest.TestCase):
    """The core anti-double-count contract: net - stream_swap + source_swap."""

    def _net(self):
        d1 = dt.date(2019, 6, 4)
        d2 = dt.date(2019, 6, 6)
        # Book net ALREADY contains the embedded stream swap.
        return {
            (100, "XAUUSD.DWX"): {d1: 1000.0, d2: -200.0},
            (200, "USDJPY.DWX"): {d1: 500.0, d2: 300.0},
        }

    def test_source_equal_to_stream_leaves_book_unchanged(self):
        # Embedded swap non-zero, and the replacement source EQUALS it: because we
        # replace (not add), the book must not move at all. This is the round-1 REJECT.
        d1 = dt.date(2019, 6, 4)
        d2 = dt.date(2019, 6, 6)
        repl = {
            (100, "XAUUSD.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: -50.0, d2: -10.0},
                daily_source_swap={d1: -50.0, d2: -10.0}),
            (200, "USDJPY.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: 6.0, d2: 6.0},
                daily_source_swap={d1: 6.0, d2: 6.0}),
        }
        weights = {(100, "XAUUSD.DWX"): 1.0, (200, "USDJPY.DWX"): 1.0}
        res = ss.apply_swap_replacement_to_book(self._net(), repl, weights, basis=ss.SWAP_BASIS_EMBEDDED)
        self.assertTrue(res.complete)
        self.assertEqual(res.delta["total_net_of_cost_profit"], 0.0)
        self.assertEqual(res.total_book_swap_replacement, 0.0)

    def test_only_the_drift_flows_through(self):
        # Source swap heavier than embedded by a known amount: only the DIFFERENCE hits
        # the book net, never the gross source swap.
        d1 = dt.date(2019, 6, 4)
        d2 = dt.date(2019, 6, 6)
        repl = {
            (100, "XAUUSD.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: -50.0, d2: -10.0},
                daily_source_swap={d1: -60.0, d2: -14.0}),  # 14 heavier in total
            (200, "USDJPY.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: 6.0, d2: 6.0},
                daily_source_swap={d1: 6.0, d2: 6.0}),
        }
        weights = {(100, "XAUUSD.DWX"): 1.0, (200, "USDJPY.DWX"): 1.0}
        res = ss.apply_swap_replacement_to_book(self._net(), repl, weights, basis=ss.SWAP_BASIS_EMBEDDED)
        # replacement delta = (-60-14) - (-50-10) = -14 at weight 1.0
        self.assertAlmostEqual(res.delta["total_net_of_cost_profit"], -14.0, places=4)
        self.assertAlmostEqual(res.total_book_swap_replacement, -14.0, places=4)

    def test_weight_scales_replacement(self):
        d1 = dt.date(2019, 6, 4)
        d2 = dt.date(2019, 6, 6)
        repl = {
            (100, "XAUUSD.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: 0.0, d2: 0.0},
                daily_source_swap={d1: -100.0, d2: 0.0}),
            (200, "USDJPY.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: 0.0, d2: 0.0},
                daily_source_swap={d1: 0.0, d2: 0.0}),
        }
        weights = {(100, "XAUUSD.DWX"): 0.25, (200, "USDJPY.DWX"): 1.0}
        res = ss.apply_swap_replacement_to_book(self._net(), repl, weights, basis=ss.SWAP_BASIS_EMBEDDED)
        self.assertAlmostEqual(res.total_book_swap_replacement, -25.0, places=4)  # -100 * 0.25

    def test_unknown_sleeve_marks_incomplete_and_is_untouched(self):
        d1 = dt.date(2019, 6, 4)
        d2 = dt.date(2019, 6, 6)
        repl = {
            (100, "XAUUSD.DWX"): ss.SwapReplacement(
                basis=ss.SWAP_BASIS_EMBEDDED,
                daily_stream_swap={d1: -50.0, d2: -10.0},
                daily_source_swap={d1: -60.0, d2: -10.0}),
            (200, "USDJPY.DWX"): None,  # UNKNOWN
        }
        weights = {(100, "XAUUSD.DWX"): 1.0, (200, "USDJPY.DWX"): 1.0}
        res = ss.apply_swap_replacement_to_book(self._net(), repl, weights, basis=ss.SWAP_BASIS_EMBEDDED)
        self.assertFalse(res.complete)
        self.assertIn("200:USDJPY.DWX", res.unknown_sleeves)
        self.assertIn("100:XAUUSD.DWX", res.applied_sleeves)
        # only the known sleeve's drift (-10) flows through
        self.assertAlmostEqual(res.delta["total_net_of_cost_profit"], -10.0, places=4)

    def test_book_kpis_reproduce_metrics(self):
        net = {(1, "X"): {dt.date(2019, 1, 1): 100.0, dt.date(2019, 1, 2): -50.0,
                          dt.date(2019, 1, 3): 200.0}}
        k = ss.book_kpis(net, {(1, "X"): 1.0}, starting_capital=100000.0)
        self.assertEqual(k["total_net_of_cost_profit"], 250.0)
        self.assertEqual(k["n_days"], 3)
        self.assertEqual(k["n_sleeves"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
