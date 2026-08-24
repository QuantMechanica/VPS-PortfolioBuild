#!/usr/bin/env python3
"""Generate the 20 Wave-2 Strategy Card drafts for independent G0 review."""
from __future__ import annotations

import argparse
import hashlib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CardSpec:
    slug: str
    title: str
    mechanism: str
    family: str
    symbol: str
    timeframe: str
    source_id: str
    citation: str
    source_url: str
    hypothesis: str
    refutation: str
    entry: tuple[str, ...]
    exits: tuple[str, ...]
    no_trade: tuple[str, ...]
    parameters: tuple[tuple[str, str], ...]
    duplicate_guard: str

    @property
    def pending_id(self) -> str:
        digest = hashlib.sha256(f"orthogonal-wave2:{self.slug}".encode()).hexdigest()[:8].upper()
        return f"PENDING_{digest}"

    @property
    def filename(self) -> str:
        return f"{self.pending_id}_{self.slug}.md"


NAGEL = (
    "Stefan Nagel (2012), Evaporating Liquidity, Review of Financial Studies "
    "25(7), 2005-2039, DOI 10.1093/rfs/hhs066."
)
BREEDON_RANALDO = (
    "Francis Breedon and Angelo Ranaldo (2013), Intraday Patterns in FX Returns "
    "and Order Flow, Journal of Money, Credit and Banking 45(5), 953-965."
)
CARRY = (
    "Markus K. Brunnermeier, Stefan Nagel and Lasse H. Pedersen (2009), Carry "
    "Trades and Currency Crashes, NBER Macroeconomics Annual 23, 313-347, "
    "DOI 10.1086/593088."
)
FIX = (
    "Michael Melvin and John Prins (2015), Equity Hedging and Exchange Rates "
    "at the London 4 p.m. Fix, Journal of Financial Markets 22, 50-72, "
    "DOI 10.1016/j.finmar.2014.11.001."
)
ANNOUNCEMENT = (
    "Pavel Savor and Mungo Wilson (2013), How Much Do Investors Care About "
    "Macroeconomic Risk? Evidence from Scheduled Economic Announcements, "
    "Journal of Financial and Quantitative Analysis 48(2), 343-375."
)


def _index_liquidity_specs() -> list[CardSpec]:
    clocks = {
        "WS30.DWX": "America/New_York cash session",
        "SP500.DWX": "America/New_York cash session",
        "GDAXI.DWX": "Europe/Berlin cash session",
        "UK100.DWX": "Europe/London cash session",
    }
    specs = []
    for symbol, clock in clocks.items():
        stem = symbol.split(".")[0].lower()
        specs.append(CardSpec(
            slug=f"{stem}-highvol-liquidity-reversal",
            title=f"{symbol} High-Volatility Liquidity-Provision Reversal",
            mechanism="index_volatility_liquidity_reversal",
            family="mean_reversion",
            symbol=symbol,
            timeframe="H1",
            source_id="NAGEL-EVAPORATING-LIQUIDITY-2012",
            citation=NAGEL,
            source_url="https://doi.org/10.1093/rfs/hhs066",
            hypothesis=(
                f"During stressed {clock} conditions, constrained intermediaries withdraw liquidity; "
                "the compensation to supplying liquidity rises. A large same-session displacement that "
                "then closes back toward the session open is therefore tested as a bounded reversal, not "
                "as a generic oscillator fade. The economic mechanism is intermediary balance-sheet "
                "scarcity. The source studies liquidity/reversal in equities, not this CFD rule, so the "
                "realized-volatility proxy and index transfer are unproven translations."
            ),
            refutation=(
                "Refute if the fixed high-volatility state does not improve post-cost reversal expectancy "
                "over its declared ungated control, if the return comes from ordinary low-volatility fades, "
                "or if the card is materially correlated with the existing index intraday-MR cluster."
            ),
            entry=(
                "Use exchange-local, DST-aware cash-session bars and the completed D1 series only.",
                "Arm when completed D1 ATR(20) is at or above its 80th percentile over the prior 250 completed D1 bars.",
                "After the first cash-session H1 bar, require distance from session open of at least 1.5 completed H1 ATR(20).",
                "Enter opposite the displacement only after a completed H1 bar closes toward the session open and does not extend the displacement extreme.",
                "Allow one consumed attempt per local session; an order rejection does not re-arm the date.",
            ),
            exits=(
                "Install a hard stop 0.75 H1 ATR beyond the displacement extreme and never widen it.",
                "Take profit when half of the entry-to-session-open distance has retraced.",
                "Flatten at the validated cash-session close; no overnight index exposure is allowed.",
            ),
            no_trade=(
                "No trade on a shortened/ambiguous session, missing exchange calendar, stale/missing news calendar, invalid ATR history, or excessive framework spread.",
                "No entry when the displacement bar overlaps a relevant high-impact news blackout.",
                "No pyramiding, averaging, grid, martingale, break-even move, or parameter adaptation.",
            ),
            parameters=(("vol_lookback_d1", "250"), ("vol_percentile", "80"), ("atr_period", "20"), ("displacement_atr", "1.5"), ("stop_beyond_extreme_atr", "0.75"), ("retrace_fraction", "0.50"), ("max_attempts_per_session", "1")),
            duplicate_guard="G0 must enforce the Wave-1 index-MR cluster cap and reject carrier-only duplication.",
        ))
    return specs


def _session_drift_specs() -> list[CardSpec]:
    rows = (
        ("EURUSD.DWX", "eurusd", "Europe/Berlin local session", "SELL", "EUR depreciation"),
        ("GBPUSD.DWX", "gbpusd", "Europe/London local session", "SELL", "GBP depreciation"),
        ("USDJPY.DWX", "usdjpy", "Asia/Tokyo local session", "BUY", "JPY depreciation"),
        ("AUDUSD.DWX", "audusd", "Australia/Sydney local session", "SELL", "AUD depreciation"),
    )
    specs = []
    for symbol, stem, session, direction, expression in rows:
        specs.append(CardSpec(
            slug=f"{stem}-local-session-inventory-drift",
            title=f"{symbol} Local-Session Inventory Drift",
            mechanism="fx_local_session_inventory_drift",
            family="calendar_seasonality",
            symbol=symbol,
            timeframe="H1",
            source_id="BREEDON-RANALDO-FX-INTRADAY-2013",
            citation=BREEDON_RANALDO,
            source_url="https://www.snb.ch/public/asset/en/www-snb-ch/publications/research/working-papers/2011/working_paper_2011_04/publications0_en/working_paper_2011_04.n.pdf",
            hypothesis=(
                f"The source documents a tendency for currencies to depreciate in their own local trading "
                f"hours and links it to local participants' foreign-currency purchases and dealer inventory. "
                f"This card expresses {expression} during the {session}. The mechanism is segmented local "
                "order flow, not price momentum. Transfer to post-2015 .DWX prices is explicitly unproven."
            ),
            refutation=(
                "Refute if the predeclared local-hours sign is non-positive after spread and commission in "
                "the post-2015 window, reverses across DST regimes, or is explained by a few news dates."
            ),
            entry=(
                f"On the first executable H1 bar of the validated {session}, submit one {direction} order.",
                "The local-session window is a fixed calendar object, not an optimized pair of broker hours.",
                "Consume the local date before order submission so restart or rejection cannot create a second entry.",
            ),
            exits=(
                "Install a hard stop 1.5 completed H1 ATR(14) from fill and never widen it.",
                f"Flatten at the final executable H1 bar of the same {session}; never hold beyond that window.",
            ),
            no_trade=(
                "Fail closed on missing/DST-ambiguous session mapping, holiday, stale/missing news calendar, invalid ATR, invalid symbol metadata, or excessive framework spread.",
                "Skip the session when a relevant high-impact event falls inside the owned interval.",
                "One position per magic; no grid, martingale, averaging, pyramid, reversal, or discretionary trend filter.",
            ),
            parameters=(("atr_period_h1", "14"), ("hard_stop_atr", "1.5")),
            duplicate_guard="G0 must compare the exact symbol/session/direction with all time-of-day cards, especially QM5_10012 and QM5_41011.",
        ))
    return specs


def _carry_unwind_specs() -> list[CardSpec]:
    for_symbol = ("AUDJPY.DWX", "NZDJPY.DWX", "GBPJPY.DWX", "EURJPY.DWX")
    specs = []
    for symbol in for_symbol:
        stem = symbol.split(".")[0].lower()
        specs.append(CardSpec(
            slug=f"{stem}-carry-unwind-crisis-momentum",
            title=f"{symbol} Carry-Unwind Crisis Momentum",
            mechanism="carry_unwind_crisis_momentum",
            family="carry_funding",
            symbol=symbol,
            timeframe="D1",
            source_id="BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008",
            citation=CARRY,
            source_url="https://www.nber.org/papers/w14473",
            hypothesis=(
                "Funding constraints force simultaneous reductions of high-yielding currency positions when "
                "risk appetite and funding liquidity fall, producing crash-like appreciation of funding "
                f"currencies. A short {symbol} position after broad JPY strength tests continuation of that "
                "forced unwind. The exact price-only state is a declared proxy because historical rate and "
                "position data are not available to the EA."
            ),
            refutation=(
                "Refute if the broad-JPY and volatility gates do not improve the target's post-cost short "
                "expectancy over an unconditional 20-day-low control, if adverse swap dominates, or if the "
                "payoff adds rather than offsets the book's crisis drawdowns."
            ),
            entry=(
                "On completed D1 bars, compute the equal-weight mean five-day return of AUDJPY, NZDJPY, CADJPY and EURJPY.",
                "Require that breadth return to be at most -1.0%, the target to close below the prior 20 completed-bar low, and target 10-day realized volatility to exceed its trailing 60-day median.",
                f"When all gates pass, enter one SHORT {symbol} position at the next permitted D1 execution point.",
            ),
            exits=(
                "Install a hard stop 2.0 completed D1 ATR(14) above fill and never widen it.",
                "Exit after 10 completed D1 bars or on a completed close above the midpoint of the prior 20-bar high/low channel, whichever comes first.",
            ),
            no_trade=(
                "Fail closed unless all four breadth series share an exact completed timestamp and all history, swap, ATR, quote, and symbol metadata are valid.",
                "Skip new entries during relevant high-impact news blackouts; protective exits remain authoritative.",
                "One position per magic; no long leg, averaging, grid, martingale, scale-in, pyramid, or stop widening.",
            ),
            parameters=(("breadth_return_days", "5"), ("breadth_threshold", "-0.010"), ("breakout_lookback", "20"), ("vol_short_days", "10"), ("vol_baseline_days", "60"), ("atr_period", "14"), ("hard_stop_atr", "2.0"), ("max_hold_bars", "10")),
            duplicate_guard="G0 must compare against QM5_13023 and QM5_20292; approve only a materially distinct carrier or rule boundary.",
        ))
    return specs


def _fix_specs() -> list[CardSpec]:
    rows = (
        ("EURUSD.DWX", "GDAXI.DWX", "eurusd", "month-end", "every last local business day"),
        ("GBPUSD.DWX", "UK100.DWX", "gbpusd", "month-end", "every last local business day"),
        ("EURUSD.DWX", "GDAXI.DWX", "eurusd", "quarter-end", "only March, June, September and December month-ends"),
        ("GBPUSD.DWX", "UK100.DWX", "gbpusd", "quarter-end", "only March, June, September and December month-ends"),
    )
    specs = []
    for symbol, equity, stem, scope, scope_rule in rows:
        specs.append(CardSpec(
            slug=f"{stem}-{scope}-benchmark-fix-hedge-flow",
            title=f"{symbol} {scope.title()} Benchmark-Fix Hedge Flow",
            mechanism="fx_benchmark_fix_rebalancing",
            family="calendar_seasonality",
            symbol=symbol,
            timeframe="M15",
            source_id="MELVIN-PRINS-LONDON-FIX-2015",
            citation=FIX,
            source_url="https://doi.org/10.1016/j.finmar.2014.11.001",
            hypothesis=(
                f"International equity managers adjust currency hedges at the London 16:00 benchmark fix. "
                f"The paper finds that equity appreciation predicts associated currency depreciation before "
                f"the end-of-month fix. This card uses completed {equity} month-to-date return as the "
                f"observable direction proxy for {symbol} on {scope} dates. The economic mechanism is a "
                "mandatory benchmark hedge flow. The single-index proxy is a QM translation, not a paper result."
            ),
            refutation=(
                "Refute if the pre-fix direction is not stable and positive after costs in post-2015 data, "
                "if the local-equity sign is wrong, or if any apparent return is earned outside the fixed window."
            ),
            entry=(
                f"Eligible dates are {scope_rule}, using a Europe/London holiday and DST-aware calendar.",
                f"At 14:00 London, compute completed month-to-date return of {equity} from its prior-month final close to its latest completed M15 close.",
                f"If the return is positive, SELL {symbol}; if negative, BUY {symbol}; exact zero consumes the date flat.",
                "Submit once at the first executable M15 bar at or after 14:00 London and persist the consumed date before submission.",
            ),
            exits=(
                "Install a hard stop 2.0 completed H1 ATR(14) from fill and never widen it.",
                "Flatten on the final M15 bar ending at or before the 16:00 London fix; do not trade the post-fix reversal in this card.",
            ),
            no_trade=(
                "Fail closed on a missing/ambiguous holiday or DST calendar, missing local-index bars, stale news data, invalid ATR, symbol metadata, or excessive framework spread.",
                "Skip when a relevant high-impact event would overlap the owned window.",
                "No re-entry, post-fix fade, overnight hold, grid, martingale, averaging, scale-in, or direction fitting.",
            ),
            parameters=(("entry_lead_minutes", "120"), ("atr_period_h1", "14"), ("hard_stop_atr", "2.0")),
            duplicate_guard="G0 must compare against QM5_10763, QM5_12973, QM5_20034 and QM5_32007; the pre-fix flow must not be confused with a post-fix fade.",
        ))
    return specs


def _announcement_specs() -> list[CardSpec]:
    rows = (
        ("SP500.DWX", "sp500", "scheduled US CPI and PPI release days", "USD CPI m/m or PPI m/m"),
        ("WS30.DWX", "ws30", "scheduled US payroll release days", "USD Nonfarm Payrolls"),
        ("NDX.DWX", "ndx", "scheduled regular FOMC decision days", "USD FOMC Statement or Federal Funds Rate"),
        ("GDAXI.DWX", "gdaxi", "scheduled regular FOMC decision days", "USD FOMC Statement or Federal Funds Rate"),
    )
    specs = []
    for symbol, stem, label, event_match in rows:
        specs.append(CardSpec(
            slug=f"{stem}-scheduled-announcement-risk-day",
            title=f"{symbol} Scheduled-Announcement Risk-Premium Day",
            mechanism="scheduled_announcement_risk_premium",
            family="event_driven",
            symbol=symbol,
            timeframe="H1",
            source_id="SAVOR-WILSON-ANNOUNCEMENT-RISK-2013",
            citation=ANNOUNCEMENT,
            source_url="https://doi.org/10.1017/S002210901300015X",
            hypothesis=(
                f"Scheduled macroeconomic uncertainty requires compensation before it is resolved. This "
                f"card tests a long, day-flat {symbol} exposure on {label}. The economic mechanism is an "
                "announcement-day macro-risk premium, not prediction of the released number. The paper's "
                "close-to-close aggregate result does not establish this event subset, CFD carrier, or "
                "open-to-close translation; each is a named refutation risk."
            ),
            refutation=(
                "Refute if this predeclared event subset has non-positive post-cost open-to-close expectancy "
                "after 2015, if returns arise only from the overnight leg omitted here, or if the card is a "
                "duplicate of an existing announcement sleeve rather than a distinct carrier test."
            ),
            entry=(
                f"Use only calendar rows whose normalized title matches: {event_match}.",
                "On an eligible date, enter one LONG at the first executable H1 cash-session bar; persist the consumed event/date before submission.",
                "Same-day overlapping eligible events collapse to one package; unscheduled events never qualify.",
            ),
            exits=(
                "Install a hard stop 2.75 completed D1 ATR(20) below fill and never widen it.",
                "Flatten at the final executable H1 cash-session bar on the same local trading date; no overnight hold.",
            ),
            no_trade=(
                "Fail closed on absent/stale calendar data, an ambiguous event title, holiday/short session, invalid ATR/history, invalid symbol metadata, or excessive framework spread.",
                "The scheduled event is the signal, so ordinary event avoidance does not cancel it; the position must nevertheless be flat by session close and all unrelated mandatory blackouts remain enforced.",
                "One package per event/date; no short leg, re-entry, grid, martingale, averaging, scale-in, or event-list fitting.",
            ),
            parameters=(("atr_period_d1", "20"), ("hard_stop_atr", "2.75")),
            duplicate_guard="G0 must compare QM5_10260, QM5_1094, QM5_1213, QM5_12971/12972, QM5_13128 and QM5_20023; duplicate rejection is the default.",
        ))
    return specs


def card_specs() -> list[CardSpec]:
    return _index_liquidity_specs() + _session_drift_specs() + _carry_unwind_specs() + _fix_specs() + _announcement_specs()


def render_card(spec: CardSpec) -> str:
    params = "\n".join(f"- `{name}` = `{value}`" for name, value in spec.parameters)
    entries = "\n".join(f"{idx}. {rule}" for idx, rule in enumerate(spec.entry, 1))
    exits = "\n".join(f"{idx}. {rule}" for idx, rule in enumerate(spec.exits, 1))
    filters = "\n".join(f"- {rule}" for rule in spec.no_trade)
    return f"""---
card_schema_version: 2
ea_id: {spec.pending_id}
slug: {spec.slug}
type: strategy
status: DRAFT
g0_status: PENDING_REVIEW
created: 2026-08-24
created_by: Codex
family: {spec.family}
mechanism: {spec.mechanism}
source_id: {spec.source_id}
source_citation: "{spec.citation}"
source_url: {spec.source_url}
target_symbols: [{spec.symbol}]
primary_target_symbols: [{spec.symbol}]
timeframe: {spec.timeframe}
period: {spec.timeframe}
single_symbol_only: true
declared_parameter_count: {len(spec.parameters)}
expected_trade_frequency: UNKNOWN_Q02_MEASURES
ml_required: false
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
---

# {spec.title}

## Hypothesis

{spec.hypothesis}

Refutation criterion: {spec.refutation}

## Source

- {spec.citation}
- Primary source: {spec.source_url}
- OWNER-authorized bounded synthesis: `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md` and ticket `rb-orthogonal-strategies`.
- No paper statistic, profitability estimate, or portfolio property is transferred to this card. Q02 and later gates measure the implementation.

## Market and timeframe

- Target symbol: `{spec.symbol}` (registered DWX carrier).
- Literal execution timeframe: `{spec.timeframe}`.
- Closed bars only; all cross-series reads require exact completed timestamps.
- Backtest risk mode is `RISK_FIXED > 0` with `RISK_PERCENT = 0`.

## Rules

### Entry

{entries}

### Exit

{exits}

### No-trade rules

{filters}

## Risk

- Size from actual fill to the initial hard stop using fixed baseline risk; reject invalid stop/tick-value/volume geometry.
- One position per symbol and magic. Daily and total account loss controls remain framework-authoritative.
- Kill-switch: when the framework kill switch, account-risk freeze, symbol-trading disable, or ownership-integrity fault is active, block entries and flatten owned exposure at the first safe executable point; broker protective stops remain active.
- No live use, `T_Live`, AutoTrading, deploy manifest, build, registry allocation, backtest enqueue, or portfolio admission is authorized by this draft.

## Declared parameters ({len(spec.parameters)})

{params}

These are frozen drafting defaults. There is no undeclared optimizer surface; changing the rule clock, direction, carrier, event set, or lifecycle creates a new card.

## Duplicate and orthogonality guard

{spec.duplicate_guard}

This card is one carrier hypothesis inside a mechanism-class batch, not evidence that the four batch cards are four independent return sources. G0 must reject duplicates, and later portfolio gates alone may establish orthogonality.
"""


def write_cards(output_dir: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for spec in card_specs():
        path = output_dir / spec.filename
        if path.exists():
            raise FileExistsError(f"refusing to overwrite existing card: {path}")
        path.write_text(render_card(spec), encoding="utf-8", newline="\n")
        paths.append(path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--list", action="store_true", help="print names without writing")
    args = parser.parse_args()
    if args.list:
        for spec in card_specs():
            print(spec.filename)
        return 0
    for path in write_cards(args.output_dir):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
