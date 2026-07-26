"""Swap-cost closure for the DXZ book — a REPLACEMENT-cost swap analysis.

WS-D of the ULTRACODE programme. This module answers one question for the OWNER money
gate: how much does overnight swap change the FINAL24b / FINAL23 book KPIs?

Cost basis (the round-1 REJECT correction). The durable Q08 sleeve streams the book is
weighted on ALREADY carry a non-zero ``swap`` field per closed trade, and the book's
``net`` (hence every baseline KPI) already includes it. The round-1 engine added the
native-report swap ON TOP of that, double-counting the swap the graded tester already
applied. This module therefore operates on a strict REPLACEMENT basis: for an attributed
sleeve the book keeps its trade P/L and commission and has its stream-embedded swap
*replaced* by the swap from another source (``net - stream_swap + source_swap``). It is
never added on top. When the replacement source equals the embedded swap, the book is
unchanged — which is the correct answer, not a +/- headline.

Direction source (HARD RULE). Swap sign depends on the *side* (long/short) of a position,
never on the P/L sign. The durable Q08 sleeve streams carry NO direction field (Codex
verified 0 of 47,515 rows). The authoritative side source is therefore the native MT5
Q10 report deal table (``Type`` buy/sell + ``Direction`` in/out, FIFO-paired partial
fills). This module REUSES :func:`ftmo_report_cost_reconcile.extract_round_trips` and
:func:`ftmo_report_cost_reconcile.swap_rollover_units` verbatim — it does not fork their
semantics.

Two replacement sources are produced, and they are labelled distinctly:

1. ``native_report`` — the swap the graded MT5 tester ACTUALLY applied on the recompiled
   binary, read straight out of the native Q10 report ``Swap`` column
   (``RoundTrip.native_swap``). This is real evidence. Replacing the durable stream's
   (07-19-bundle) swap with the 07-24-regrade swap is a *like-for-like* recost of the
   exact same trade population; the net effect on the whole book is only the drift
   between the two builds, not the gross swap.

2. ``scenario`` — a forward-looking CURRENT-RATE swap stress: a single sourced current
   published swap rate applied to every historical rollover, again REPLACING the embedded
   swap. Per ``venue_cost_model.json:150-153`` (swap OPEN for all symbols) this is a
   *deployment-cost stress scenario*, NEVER "historical actuals". Each rate carries
   source + effective-date + units + swap mode; an unsourced rate yields ``UNKNOWN``,
   never a signed estimate.

Rollover / triple-day convention (sourced). Darwinex/DXZ charge swap daily at 17:00
New York time (= broker-server midnight, GMT+2 winter / GMT+3 US-DST), tripled on
Wednesday (help.darwinex.com/execution-costs, darwinexzero docs, retrieved 2026-07-26).
:func:`swap_rollover_units` counts server-midnight crossings on broker-wallclock report
timestamps and triples ``triple_weekday`` (default Wednesday=2), so it is DST-correct by
construction (the report timestamps are already in server local time).

Reconciliation BEFORE recosting (HARD RULE). A sleeve's native round-trips are attributed
to the book stream only if the two populations are the SAME set of positions, matched on
exact ``(entry_time, exit_time, volume)`` tuples (partial-fill safe: FIFO fragments are
aggregated back to their position). The reconciliation authenticates count, gross P/L,
net, commission, swap, and the report source hash as ONE record, with a per-field tie
flag; recompile drift shows up as a swap/net drift under an identical position set (the
attributable case). Non-reconciling sleeves are ``UNKNOWN`` with a reason, never a signed
estimate. The whole-book result is explicitly INCOMPLETE if any sleeve is ``UNKNOWN``.
"""
from __future__ import annotations

import datetime as dt
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .ftmo_report_cost_reconcile import (
        RoundTrip,
        extract_round_trips,
        file_sha256,
        swap_rollover_units,
    )
except ImportError:  # pragma: no cover - direct script execution
    from ftmo_report_cost_reconcile import (  # type: ignore
        RoundTrip,
        extract_round_trips,
        file_sha256,
        swap_rollover_units,
    )


# --------------------------------------------------------------------------- #
# Swap-rate model
# --------------------------------------------------------------------------- #

SWAP_MODE_POINTS = "points"
SWAP_MODE_MONEY_PER_LOT = "money_per_lot_per_night"
SWAP_MODE_PERCENT_ANNUAL = "percent_annual"
_SUPPORTED_MODES = frozenset(
    {SWAP_MODE_POINTS, SWAP_MODE_MONEY_PER_LOT, SWAP_MODE_PERCENT_ANNUAL}
)

# Wednesday is the common MT5 metals / Darwinex triple-swap weekday.
TRIPLE_WEEKDAY_WEDNESDAY = 2
# Day-count basis for the percent-annual swap mode (MT5 SYMBOL_SWAP_MODE interest
# models use a 360-day year for the per-night accrual).
PERCENT_ANNUAL_DAY_COUNT = 360.0


@dataclass(frozen=True)
class SwapRate:
    """A current-rate swap scenario input for one symbol, with full provenance.

    ``swap_long`` / ``swap_short`` are the per-night rate for a long / short position in
    the units named by ``swap_mode``:

    * ``points`` — MT5 swap points; per-night $ = ``swap * contract_size * 10**-digits``
      (profit currency) then scaled by volume and the profit->account conversion.
    * ``money_per_lot_per_night`` — profit-currency money per 1.0 lot per night.
    * ``percent_annual`` — annual interest percent on notional; per-night accrues on a
      360-day basis over the position notional (``entry_price * contract_size * volume``).

    A rate with ``known=False`` (missing / unsourced) makes any scenario computed from it
    ``UNKNOWN``. Sign convention: a negative value is a cost the trader pays.
    """

    symbol: str
    swap_mode: str
    swap_long: float | None
    swap_short: float | None
    contract_size: float
    digits: int
    profit_currency: str = "USD"
    account_currency: str = "USD"
    profit_ccy_to_account_rate: float = 1.0
    triple_weekday: int = TRIPLE_WEEKDAY_WEDNESDAY
    known: bool = True
    source: str = ""
    source_url: str = ""
    effective_date: str = ""
    retrieval_date: str = ""
    note: str = ""

    def __post_init__(self) -> None:
        if self.swap_mode not in _SUPPORTED_MODES:
            raise ValueError(
                f"unsupported swap_mode {self.swap_mode!r}; expected one of {sorted(_SUPPORTED_MODES)}"
            )
        if self.contract_size <= 0.0:
            raise ValueError("contract_size must be positive")
        if self.profit_ccy_to_account_rate <= 0.0:
            raise ValueError("profit_ccy_to_account_rate must be positive")
        if not (0 <= int(self.triple_weekday) <= 6):
            raise ValueError("triple_weekday must be 0..6")
        if self.known and (self.swap_long is None or self.swap_short is None):
            raise ValueError(
                f"{self.symbol}: a known SwapRate must define both swap_long and swap_short "
                "(use known=False for an unsourced rate)"
            )

    @classmethod
    def unknown(cls, symbol: str, *, reason: str = "no sourced current swap rate") -> "SwapRate":
        """A placeholder for a symbol whose current swap rate could not be sourced."""
        return cls(
            symbol=symbol,
            swap_mode=SWAP_MODE_POINTS,
            swap_long=None,
            swap_short=None,
            contract_size=1.0,
            digits=0,
            known=False,
            note=reason,
        )

    def point_value_per_lot(self) -> float:
        """Profit-currency value of one MT5 point for a 1.0-lot position."""
        return self.contract_size * (10.0 ** -int(self.digits))


@dataclass(frozen=True)
class TradeSwap:
    """Per-round-trip swap outcome under a scenario rate."""

    side: str
    volume: float
    rollover_units: int
    swap_account_ccy: float  # signed; negative = cost


def trade_swap_drag(trade: RoundTrip, rate: SwapRate) -> TradeSwap:
    """Scenario swap for one round trip in account currency (signed; negative = cost).

    Side is taken from ``trade.side`` (from the native deal ``Type``), never from P/L.
    Rollover units (incl. triple day and DST/midnight boundaries in broker time) come
    from :func:`swap_rollover_units`.
    """
    if not rate.known:
        raise ValueError(
            f"{rate.symbol}: cannot compute a scenario swap from an UNKNOWN rate "
            "(known=False); the sleeve must be reported UNKNOWN"
        )
    if trade.side not in {"buy", "sell"}:
        raise ValueError(f"unsupported trade side {trade.side!r}")

    units = swap_rollover_units(trade.entry_time, trade.exit_time, rate.triple_weekday)
    if units == 0:
        return TradeSwap(side=trade.side, volume=trade.volume, rollover_units=0, swap_account_ccy=0.0)

    per_night_long = rate.swap_long
    per_night_short = rate.swap_short
    selected = per_night_long if trade.side == "buy" else per_night_short
    conv = rate.profit_ccy_to_account_rate

    if rate.swap_mode == SWAP_MODE_POINTS:
        per_night = float(selected) * rate.point_value_per_lot() * trade.volume
    elif rate.swap_mode == SWAP_MODE_MONEY_PER_LOT:
        per_night = float(selected) * trade.volume
    elif rate.swap_mode == SWAP_MODE_PERCENT_ANNUAL:
        notional = trade.entry_price * rate.contract_size * trade.volume
        per_night = (float(selected) / 100.0) / PERCENT_ANNUAL_DAY_COUNT * notional
    else:  # pragma: no cover - guarded by __post_init__
        raise ValueError(f"unsupported swap_mode {rate.swap_mode!r}")

    return TradeSwap(
        side=trade.side,
        volume=trade.volume,
        rollover_units=units,
        swap_account_ccy=per_night * units * conv,
    )


# --------------------------------------------------------------------------- #
# Overnight exposure surface (rate-free, sourced entirely from native reports)
# --------------------------------------------------------------------------- #


@dataclass(frozen=True)
class OvernightExposure:
    """Rate-free overnight exposure of a sleeve, derived purely from native round trips.

    ``lot_nights`` (Σ volume * rollover_units) is the exact multiplier on a per-lot-per-
    night swap rate, split by side because long and short rates differ. This is the
    decision-useful surface even when a current rate is UNKNOWN. ``embedded_swap_*`` is
    the native-report swap on those same trips (real evidence, not a rate).
    """

    trades: int
    overnight_trades: int
    total_rollover_units: int
    triple_rollover_units: int
    long_lot_nights: float
    short_lot_nights: float
    embedded_swap_total: float
    embedded_swap_long: float
    embedded_swap_short: float
    per_year_rollover_units: dict[int, int] = field(default_factory=dict)

    @property
    def total_lot_nights(self) -> float:
        return self.long_lot_nights + self.short_lot_nights


def sleeve_overnight_exposure(
    round_trips: Sequence[RoundTrip], *, triple_weekday: int = TRIPLE_WEEKDAY_WEDNESDAY
) -> OvernightExposure:
    overnight = 0
    total_units = 0
    triple_units = 0
    long_lot_nights = 0.0
    short_lot_nights = 0.0
    emb_total = 0.0
    emb_long = 0.0
    emb_short = 0.0
    per_year: dict[int, int] = {}
    for t in round_trips:
        units = swap_rollover_units(t.entry_time, t.exit_time, triple_weekday)
        emb_total += t.native_swap
        if t.side == "buy":
            long_lot_nights += t.volume * units
            emb_long += t.native_swap
        else:
            short_lot_nights += t.volume * units
            emb_short += t.native_swap
        if units > 0:
            overnight += 1
            total_units += units
            # triple-day units contributed (each triple weekday night counts as 3)
            triple_units += _triple_units(t.entry_time, t.exit_time, triple_weekday)
            per_year[t.exit_time.year] = per_year.get(t.exit_time.year, 0) + units
    return OvernightExposure(
        trades=len(round_trips),
        overnight_trades=overnight,
        total_rollover_units=total_units,
        triple_rollover_units=triple_units,
        long_lot_nights=round(long_lot_nights, 6),
        short_lot_nights=round(short_lot_nights, 6),
        embedded_swap_total=round(emb_total, 2),
        embedded_swap_long=round(emb_long, 2),
        embedded_swap_short=round(emb_short, 2),
        per_year_rollover_units=dict(sorted(per_year.items())),
    )


def _triple_units(entry: dt.datetime, exit_: dt.datetime, triple_weekday: int) -> int:
    """Extra units contributed by triple-swap weekdays inside [entry, exit] (3 per hit)."""
    if exit_ <= entry:
        return 0
    cursor = dt.datetime.combine(
        entry.date() + dt.timedelta(days=1), dt.time.min, tzinfo=entry.tzinfo
    )
    triples = 0
    while cursor <= exit_:
        session_day = cursor.date() - dt.timedelta(days=1)
        if session_day.weekday() == triple_weekday:
            triples += 3
        cursor += dt.timedelta(days=1)
    return triples


# --------------------------------------------------------------------------- #
# Reconciliation: native report round-trips vs durable Q08 stream
# --------------------------------------------------------------------------- #

RECON_MATCH = "MATCH"            # exact (entry,exit,volume) bijection: same position set
RECON_POP_DRIFT = "POP_DRIFT"    # positions differ (recompiled binary population changed)
RECON_NO_STREAM = "NO_STREAM"
RECON_NO_REPORT = "NO_REPORT"
RECON_NO_ENTRY_TIME = "NO_ENTRY_TIME"  # stream lacks entry_time -> exact match impossible

_TRADE_CLOSED = "TRADE_CLOSED"


@dataclass(frozen=True)
class _PosAgg:
    """A position aggregate keyed by (entry_epoch, exit_epoch)."""

    volume: float
    profit: float
    swap: float
    commission: float
    net: float
    fragments: int


def _report_positions(round_trips: Sequence[RoundTrip]) -> dict[tuple[int, int], _PosAgg]:
    """Aggregate FIFO round-trip fragments back to positions by (entry, exit) epoch.

    Native reports fragment a partially-filled position into multiple round trips; the
    position identity is the (entry_time, exit_time) pair, so fragments are summed back.
    Report native net = profit + native_swap + native_commission (like-for-like with the
    stream ``net`` field).
    """
    acc: dict[tuple[int, int], list[float]] = {}
    for t in round_trips:
        key = (int(t.entry_time.timestamp()), int(t.exit_time.timestamp()))
        cell = acc.setdefault(key, [0.0, 0.0, 0.0, 0.0, 0.0])
        cell[0] += t.volume
        cell[1] += t.profit
        cell[2] += t.native_swap
        cell[3] += t.native_commission
        cell[4] += 1.0
    return {
        k: _PosAgg(
            volume=v[0], profit=v[1], swap=v[2], commission=v[3],
            net=v[1] + v[2] + v[3], fragments=int(v[4]),
        )
        for k, v in acc.items()
    }


def _stream_positions(
    stream_rows: Sequence[Mapping[str, Any]]
) -> tuple[dict[tuple[int, int], _PosAgg], bool]:
    """Aggregate durable-stream TRADE_CLOSED rows to positions by (entry, exit) epoch.

    Returns ``(positions, has_entry_time)``. If any closed row lacks ``entry_time`` the
    exact-tuple match is impossible and the caller falls back to NO_ENTRY_TIME.
    """
    acc: dict[tuple[int, int], list[float]] = {}
    has_entry_time = True
    for r in stream_rows:
        if r.get("event") != _TRADE_CLOSED:
            continue
        entry = r.get("entry_time")
        exit_ = r.get("time")
        if entry is None or exit_ is None:
            has_entry_time = False
            continue
        key = (int(entry), int(exit_))
        cell = acc.setdefault(key, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
        cell[0] += float(r["volume"])
        cell[1] += float(r.get("profit", 0.0))
        cell[2] += float(r.get("swap", 0.0))
        cell[3] += float(r.get("commission", 0.0))
        cell[4] += float(r["net"])
        cell[5] += 1.0
    positions = {
        k: _PosAgg(
            volume=v[0], profit=v[1], swap=v[2], commission=v[3], net=v[4], fragments=int(v[5])
        )
        for k, v in acc.items()
    }
    return positions, has_entry_time


def _tie(a: float, b: float, *, rel: float, floor: float) -> bool:
    return abs(a - b) <= max(floor, abs(b) * rel)


@dataclass(frozen=True)
class ReconcileResult:
    """One authenticated reconciliation record for a sleeve.

    ``reconciled`` (status ``MATCH``) means the report and stream describe the SAME set of
    positions — exact ``(entry_time, exit_time, volume)`` bijection. That is the only
    condition under which the report swap may replace the stream swap in the book. The
    ``*_tied`` flags authenticate — as one record — that count, gross P/L, net (both raw
    and commission-neutral), commission, and swap agree, and bind the report source hash.

    Commission is convention-entangled. The durable stream ``commission`` field is logged
    per-side, while the native report sums the entry and exit deal commissions, so the raw
    values differ by a structural ratio (~2.0 on this book) even for an identical backtest.
    ``commission_convention_ratio`` exposes that offset; ``commission_tied`` is the RAW
    comparison and is expected to be False under the per-side convention, which is why raw
    commission (and the raw ``net`` that inherits it) is NOT part of the attribution
    authentication. The convention-free authentications are volume, gross profit, swap, and
    ``net_ex_commission`` (profit + swap). A recompiled binary can produce
    ``swap_tied=False`` / ``net_ex_commission_tied=False`` while the population and volume
    still tie exactly: that is the attributable recost case (the swap is then replaced).
    """

    status: str
    reconciled: bool
    reason: str
    # population
    report_positions: int
    stream_positions: int
    report_fragments: int
    stream_fragments: int
    matched_positions: int
    report_only_positions: int
    stream_only_positions: int
    # authenticated aggregates (report vs stream, like-for-like)
    report_volume: float
    stream_volume: float
    volume_tied: bool
    report_gross_profit: float
    stream_gross_profit: float
    gross_profit_tied: bool
    report_net: float
    stream_net: float
    net_tied: bool
    report_net_ex_commission: float
    stream_net_ex_commission: float
    net_ex_commission_tied: bool
    report_commission: float
    stream_commission: float
    commission_tied: bool
    commission_convention_ratio: float | None
    report_swap: float
    stream_swap: float
    swap_tied: bool
    # provenance
    report_sha256: str | None = None

    @property
    def fully_authenticated(self) -> bool:
        """True when the convention-free cost fields tie AND the population matches.

        Uses the commission-neutral authentications (volume, gross profit, swap,
        net-ex-commission); the raw commission convention offset is excluded because it is
        structural, not drift.
        """
        return (
            self.reconciled
            and self.volume_tied
            and self.gross_profit_tied
            and self.swap_tied
            and self.net_ex_commission_tied
        )


def reconcile_report_to_stream(
    round_trips: Sequence[RoundTrip],
    stream_rows: Sequence[Mapping[str, Any]],
    *,
    report_sha256: str | None = None,
    volume_tolerance_frac: float = 1e-4,
    money_tolerance_frac: float = 0.005,
    money_tolerance_floor: float = 1.0,
) -> ReconcileResult:
    """Reconcile native round trips against the durable Q08 stream on EXACT position tuples.

    The primary invariant is an exact ``(entry_time, exit_time, volume)`` bijection between
    the report positions (FIFO fragments aggregated back) and the stream's TRADE_CLOSED
    rows. This binds population identity far more strongly than an aggregate-volume band:
    a sleeve reconciles only if *every* position is present on both sides with a matching
    volume, and neither side has an unmatched position.

    On top of that, the result authenticates count, gross P/L, net, commission, swap, and
    the report source hash as ONE record — each with a like-for-like tie flag. This fixes
    the round-1 gross-vs-net bug (it compared report gross profit against the stream NET,
    which already contains swap+commission); gross now compares report profit to stream
    profit, and net compares report native net to stream net separately.
    """
    report_pos = _report_positions(round_trips)
    stream_pos, has_entry_time = _stream_positions(stream_rows)

    report_volume = sum(p.volume for p in report_pos.values())
    stream_volume = sum(p.volume for p in stream_pos.values())
    report_gross = sum(p.profit for p in report_pos.values())
    stream_gross = sum(p.profit for p in stream_pos.values())
    report_net = sum(p.net for p in report_pos.values())
    stream_net = sum(p.net for p in stream_pos.values())
    report_comm = sum(p.commission for p in report_pos.values())
    stream_comm = sum(p.commission for p in stream_pos.values())
    report_swap = sum(p.swap for p in report_pos.values())
    stream_swap = sum(p.swap for p in stream_pos.values())
    report_frag = sum(p.fragments for p in report_pos.values())
    stream_frag = sum(p.fragments for p in stream_pos.values())
    # commission-neutral net (profit + swap) authenticates price/population + the replaced
    # quantity without the per-side-vs-round-trip commission convention offset.
    report_net_ex = report_gross + report_swap
    stream_net_ex = stream_gross + stream_swap
    comm_ratio = round(report_comm / stream_comm, 4) if abs(stream_comm) > 1e-9 else None

    def _authenticated(status: str, reconciled: bool, reason: str,
                       matched: int, r_only: int, s_only: int) -> ReconcileResult:
        return ReconcileResult(
            status=status, reconciled=reconciled, reason=reason,
            report_positions=len(report_pos), stream_positions=len(stream_pos),
            report_fragments=report_frag, stream_fragments=stream_frag,
            matched_positions=matched, report_only_positions=r_only,
            stream_only_positions=s_only,
            report_volume=round(report_volume, 6), stream_volume=round(stream_volume, 6),
            volume_tied=_tie(report_volume, stream_volume, rel=volume_tolerance_frac, floor=1e-6),
            report_gross_profit=round(report_gross, 2), stream_gross_profit=round(stream_gross, 2),
            gross_profit_tied=_tie(report_gross, stream_gross, rel=money_tolerance_frac, floor=money_tolerance_floor),
            report_net=round(report_net, 2), stream_net=round(stream_net, 2),
            net_tied=_tie(report_net, stream_net, rel=money_tolerance_frac, floor=money_tolerance_floor),
            report_net_ex_commission=round(report_net_ex, 2), stream_net_ex_commission=round(stream_net_ex, 2),
            net_ex_commission_tied=_tie(report_net_ex, stream_net_ex, rel=money_tolerance_frac, floor=money_tolerance_floor),
            report_commission=round(report_comm, 2), stream_commission=round(stream_comm, 2),
            commission_tied=_tie(report_comm, stream_comm, rel=money_tolerance_frac, floor=money_tolerance_floor),
            commission_convention_ratio=comm_ratio,
            report_swap=round(report_swap, 2), stream_swap=round(stream_swap, 2),
            swap_tied=_tie(report_swap, stream_swap, rel=money_tolerance_frac, floor=money_tolerance_floor),
            report_sha256=report_sha256,
        )

    if not stream_pos:
        reason = ("no entry_time on stream rows" if not has_entry_time else "no TRADE_CLOSED rows in stream")
        status = RECON_NO_ENTRY_TIME if not has_entry_time else RECON_NO_STREAM
        return _authenticated(status, False, reason, 0, len(report_pos), 0)
    if not has_entry_time:
        return _authenticated(RECON_NO_ENTRY_TIME, False,
                              "stream has TRADE_CLOSED rows without entry_time; exact match impossible",
                              0, len(report_pos), len(stream_pos))
    if not report_pos:
        return _authenticated(RECON_NO_REPORT, False, "no round trips parsed from report",
                              0, 0, len(stream_pos))

    rkeys = set(report_pos)
    skeys = set(stream_pos)
    matched = rkeys & skeys
    report_only = rkeys - skeys
    stream_only = skeys - rkeys
    per_key_volume_tie = all(
        _tie(report_pos[k].volume, stream_pos[k].volume, rel=volume_tolerance_frac, floor=1e-6)
        for k in matched
    )
    bijective = not report_only and not stream_only
    reconciled = bijective and per_key_volume_tie
    if reconciled:
        status = RECON_MATCH
        swap_ties = _tie(report_swap, stream_swap, rel=money_tolerance_frac, floor=money_tolerance_floor)
        reason = (
            "exact (entry,exit,volume) position bijection; gross P/L ties; "
            + ("swap ties (identical backtest; commission differs only by the per-side stream convention)"
               if swap_ties
               else "swap drift under identical population (recompiled binary; recost attributable)")
        )
    else:
        status = RECON_POP_DRIFT
        reason = (
            f"position set differs: matched {len(matched)}, report-only {len(report_only)}, "
            f"stream-only {len(stream_only)}"
            + ("" if per_key_volume_tie else "; matched-key volume drift")
            + " (recompiled binary population changed)"
        )
    return _authenticated(status, reconciled, reason, len(matched), len(report_only), len(stream_only))


# --------------------------------------------------------------------------- #
# Per-sleeve swap REPLACEMENT series (report/scenario swap replaces embedded stream swap)
# --------------------------------------------------------------------------- #

SWAP_BASIS_EMBEDDED = "embedded"      # native-report swap (real, graded)
SWAP_BASIS_SCENARIO = "scenario"      # current-rate hypothetical


@dataclass(frozen=True)
class SwapReplacement:
    """The swap-replacement series for one attributed sleeve.

    ``daily_stream_swap`` is the embedded swap already present in the book ``net`` for
    each exit date; ``daily_source_swap`` is the swap to put in its place (native-report
    or scenario). The book overlay applies ``net - stream + source`` per day, so a source
    that equals the embedded swap leaves the book unchanged. ``daily_delta`` is the net
    per-day effect (source - stream) and is provided for transparency only.
    """

    basis: str
    daily_stream_swap: dict[dt.date, float]
    daily_source_swap: dict[dt.date, float]

    @property
    def daily_delta(self) -> dict[dt.date, float]:
        days = set(self.daily_stream_swap) | set(self.daily_source_swap)
        return {
            d: round(self.daily_source_swap.get(d, 0.0) - self.daily_stream_swap.get(d, 0.0), 6)
            for d in sorted(days)
        }

    @property
    def total_stream_swap(self) -> float:
        return round(sum(self.daily_stream_swap.values()), 6)

    @property
    def total_source_swap(self) -> float:
        return round(sum(self.daily_source_swap.values()), 6)

    @property
    def total_delta(self) -> float:
        return round(self.total_source_swap - self.total_stream_swap, 6)


def _stream_daily_swap(stream_rows: Sequence[Mapping[str, Any]]) -> dict[dt.date, float]:
    """Embedded swap already inside the book net, bucketed by exit date (UTC-of-epoch).

    Uses the SAME day convention as ``portfolio_common.to_daily_pnl`` (exit epoch ->
    UTC date) so that subtracting this series removes exactly the swap the baseline book
    already booked on that day.
    """
    daily: dict[dt.date, float] = {}
    for r in stream_rows:
        if r.get("event") != _TRADE_CLOSED:
            continue
        exit_ = r.get("time")
        if exit_ is None:
            continue
        day = dt.datetime.fromtimestamp(int(exit_), tz=dt.timezone.utc).date()
        daily[day] = daily.get(day, 0.0) + float(r.get("swap", 0.0))
    return dict(sorted(daily.items()))


def sleeve_daily_swap(
    round_trips: Sequence[RoundTrip],
    *,
    basis: str,
    rate: SwapRate | None = None,
) -> dict[dt.date, float]:
    """Per-exit-date source swap $ for a sleeve (signed; negative = cost).

    ``embedded`` uses the native report swap; ``scenario`` applies ``rate``. The date key
    is the round-trip exit date (broker/server date, UTC-of-epoch), consistent with how
    the book stream buckets trade net at close time.
    """
    daily: dict[dt.date, float] = {}
    if basis == SWAP_BASIS_EMBEDDED:
        for t in round_trips:
            day = dt.datetime.fromtimestamp(int(t.exit_time.timestamp()), tz=dt.timezone.utc).date()
            daily[day] = daily.get(day, 0.0) + t.native_swap
    elif basis == SWAP_BASIS_SCENARIO:
        if rate is None or not rate.known:
            raise ValueError("scenario basis requires a known SwapRate")
        for t in round_trips:
            day = dt.datetime.fromtimestamp(int(t.exit_time.timestamp()), tz=dt.timezone.utc).date()
            daily[day] = daily.get(day, 0.0) + trade_swap_drag(t, rate).swap_account_ccy
    else:
        raise ValueError(f"unknown swap basis {basis!r}")
    return dict(sorted(daily.items()))


def sleeve_swap_replacement(
    round_trips: Sequence[RoundTrip],
    stream_rows: Sequence[Mapping[str, Any]],
    *,
    basis: str,
    rate: SwapRate | None = None,
) -> SwapReplacement:
    """Build the like-for-like swap-replacement series for an attributed sleeve.

    ``daily_stream_swap`` comes from the durable stream ``swap`` field (what the baseline
    book already contains); ``daily_source_swap`` comes from the native report
    (``embedded``) or a scenario ``rate`` (``scenario``). Both are bucketed by exit date
    on the same UTC-of-epoch convention as the book, so the overlay's per-day
    ``net - stream + source`` cleanly replaces the embedded swap.
    """
    stream_daily = _stream_daily_swap(stream_rows)
    source_daily = sleeve_daily_swap(round_trips, basis=basis, rate=rate)
    return SwapReplacement(
        basis=basis,
        daily_stream_swap=stream_daily,
        daily_source_swap=source_daily,
    )


# --------------------------------------------------------------------------- #
# Whole-book KPI overlay (faithful reproduction of the manifest arithmetic)
# --------------------------------------------------------------------------- #


def _population_stddev(values: Sequence[float]) -> float:
    n = len(values)
    if n == 0:
        return 0.0
    mean = sum(values) / n
    return math.sqrt(sum((v - mean) ** 2 for v in values) / n)


def book_kpis(
    daily_net_by_sleeve: Mapping[tuple[int, str], Mapping[dt.date, float]],
    weights: Mapping[tuple[int, str], float],
    *,
    starting_capital: float = 100_000.0,
) -> dict[str, Any]:
    """Faithful book KPIs: book daily PnL = Σ_k sleeve_daily_net_k * weight_k.

    Reproduces ``dxz_composite_faithful_recompute.metrics`` (Sharpe = mean/std * sqrt(252)
    on daily returns; MaxDD = faithful-constSC, peak of cumulative PnL from 0 over
    starting_capital). Validated to reproduce the manifest FINAL24b/FINAL23 KPIs exactly.
    """
    keys = sorted(k for k in weights if k in daily_net_by_sleeve and daily_net_by_sleeve[k])
    dates = sorted({d for k in keys for d in daily_net_by_sleeve[k]})
    daily_pnl: list[float] = []
    for day in dates:
        daily_pnl.append(
            sum(float(daily_net_by_sleeve[k].get(day, 0.0)) * float(weights[k]) for k in keys)
        )
    eq: list[float] = []
    cum = 0.0
    for v in daily_pnl:
        cum += v
        eq.append(cum)
    rets = [v / starting_capital for v in daily_pnl]
    if len(rets) >= 2:
        mean = sum(rets) / len(rets)
        sd = _population_stddev(rets)
        sharpe = (mean / sd) * math.sqrt(252.0) if sd > 0 else None
    else:
        sharpe = None
    peak = mdd = 0.0
    for e in eq:
        peak = max(peak, e)
        mdd = max(mdd, peak - e)
    return {
        "sharpe": None if sharpe is None else round(sharpe, 4),
        "max_drawdown_pct": round(mdd / starting_capital * 100.0, 4),
        "total_net_of_cost_profit": round(eq[-1], 2) if eq else 0.0,
        "n_days": len(dates),
        "n_sleeves": len(keys),
    }


@dataclass
class BookSwapResult:
    baseline: dict[str, Any]
    swap_adjusted: dict[str, Any]
    delta: dict[str, Any]
    basis: str
    applied_sleeves: list[str]
    unknown_sleeves: list[str]
    complete: bool
    total_stream_swap_weighted: float
    total_source_swap_weighted: float
    total_book_swap_replacement: float  # weighted (source - stream); the net book effect


def apply_swap_replacement_to_book(
    daily_net_by_sleeve: Mapping[tuple[int, str], Mapping[dt.date, float]],
    replacements_by_sleeve: Mapping[tuple[int, str], SwapReplacement | None],
    weights: Mapping[tuple[int, str], float],
    *,
    basis: str,
    starting_capital: float = 100_000.0,
) -> BookSwapResult:
    """REPLACE each attributed sleeve's embedded stream swap with a source swap.

    The baseline book ``net`` already contains the stream's embedded swap. For an
    attributed sleeve this overlay computes, per exit date,
    ``adjusted = net - stream_swap + source_swap`` — it NEVER adds the source swap on top.
    A sleeve whose ``SwapReplacement`` is ``None`` (UNKNOWN — unreconciled or unsourced
    rate) is left exactly as the baseline (keeps its embedded swap) and marks the whole
    book ``complete=False``. Weights are held at the deployed manifest RISK_PERCENT so the
    overlay isolates the pure swap-basis effect on the already-weighted book.
    """
    adjusted: dict[tuple[int, str], dict[dt.date, float]] = {}
    applied: list[str] = []
    unknown: list[str] = []
    w_stream = 0.0
    w_source = 0.0
    for k, net in daily_net_by_sleeve.items():
        repl = replacements_by_sleeve.get(k)
        if repl is None:
            unknown.append(f"{k[0]}:{k[1]}")
            adjusted[k] = dict(net)
            continue
        applied.append(f"{k[0]}:{k[1]}")
        merged = dict(net)
        weight = float(weights.get(k, 0.0))
        days = set(repl.daily_stream_swap) | set(repl.daily_source_swap)
        for day in days:
            stream_s = repl.daily_stream_swap.get(day, 0.0)
            source_s = repl.daily_source_swap.get(day, 0.0)
            merged[day] = merged.get(day, 0.0) - stream_s + source_s
        w_stream += repl.total_stream_swap * weight
        w_source += repl.total_source_swap * weight
        adjusted[k] = merged
    baseline = book_kpis(daily_net_by_sleeve, weights, starting_capital=starting_capital)
    swap_adj = book_kpis(adjusted, weights, starting_capital=starting_capital)
    delta = {
        "sharpe": _delta(swap_adj["sharpe"], baseline["sharpe"]),
        "max_drawdown_pct": _delta(swap_adj["max_drawdown_pct"], baseline["max_drawdown_pct"]),
        "total_net_of_cost_profit": _delta(
            swap_adj["total_net_of_cost_profit"], baseline["total_net_of_cost_profit"]
        ),
    }
    return BookSwapResult(
        baseline=baseline,
        swap_adjusted=swap_adj,
        delta=delta,
        basis=basis,
        applied_sleeves=sorted(applied),
        unknown_sleeves=sorted(unknown),
        complete=len(unknown) == 0,
        total_stream_swap_weighted=round(w_stream, 4),
        total_source_swap_weighted=round(w_source, 4),
        total_book_swap_replacement=round(w_source - w_stream, 4),
    )


def _delta(a: Any, b: Any) -> Any:
    if a is None or b is None:
        return None
    return round(float(a) - float(b), 4)


# --------------------------------------------------------------------------- #
# Rate loading
# --------------------------------------------------------------------------- #


def load_swap_rates(path: Path) -> dict[str, SwapRate]:
    """Load a swap-rate scenario JSON into ``{symbol: SwapRate}``.

    Schema: ``{"rates": [{"symbol": ..., "known": bool, "swap_mode": ..., ...}]}``.
    A rate object with ``"known": false`` (or missing swap_long/short) becomes a
    :meth:`SwapRate.unknown` placeholder carrying its documented reason.
    """
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    out: dict[str, SwapRate] = {}
    for row in payload.get("rates", []):
        symbol = str(row["symbol"])
        if not row.get("known", False) or row.get("swap_long") is None or row.get("swap_short") is None:
            out[symbol] = SwapRate.unknown(symbol, reason=str(row.get("note") or "unsourced"))
            continue
        out[symbol] = SwapRate(
            symbol=symbol,
            swap_mode=str(row.get("swap_mode", SWAP_MODE_POINTS)),
            swap_long=float(row["swap_long"]),
            swap_short=float(row["swap_short"]),
            contract_size=float(row["contract_size"]),
            digits=int(row["digits"]),
            profit_currency=str(row.get("profit_currency", "USD")),
            account_currency=str(row.get("account_currency", "USD")),
            profit_ccy_to_account_rate=float(row.get("profit_ccy_to_account_rate", 1.0)),
            triple_weekday=int(row.get("triple_weekday", TRIPLE_WEEKDAY_WEDNESDAY)),
            known=True,
            source=str(row.get("source", "")),
            source_url=str(row.get("source_url", "")),
            effective_date=str(row.get("effective_date", "")),
            retrieval_date=str(row.get("retrieval_date", "")),
            note=str(row.get("note", "")),
        )
    return out


def extract_sleeve_round_trips(
    report_path: Path, symbol: str | None
) -> tuple[list[RoundTrip], dict[str, Any], str]:
    """Reuse extract_round_trips; return (round_trips, report_stats, report_sha256).

    ``symbol=None`` parses ALL symbols in the report (basket sleeves with two legs).
    """
    trips, stats = extract_round_trips(report_path, symbol)
    return trips, stats, file_sha256(report_path)
