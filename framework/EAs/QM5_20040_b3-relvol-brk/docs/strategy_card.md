---
card_schema_version: 2
ea_id: QM5_20040
slug: b3-relvol-brk
status: DRAFT
g0_status: APPROVED
symbol: WS30.DWX
timeframe: M15
variant_id: B3_RELVOL_BRK_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20040
execution_contract_status: DRAFT
target_symbols: [WS30.DWX, SP500.DWX, NDX.DWX]
expected_trades_per_year_per_symbol: 135
g0_approval_reasoning: "R1 Silva 2026 FORCA_WIN_V16 GitHub NTSL is explicit UNVERIFIED tier-C practitioner code; R2 mechanical 09:45-15:55 ET M15 relative-tick-volume breakout; R3 WS30/SP500/NDX .DWX ticks; R4 deterministic proxy, no ML or tape claim"
last_updated: 2026-07-22
expected_pf: 1.25
expected_dd_pct: 12.0
source_id: SILVA-FORCA-WIN-V16-2026
ml_required: false
r1_track_record: PASS
r1_reasoning: "UNVERIFIED quality-tier-C practitioner NTSL source code by Wesley Silva (2026); its formula is traceable at a commit-pinned GitHub URL, while self-reported performance is not treated as evidence."
r2_mechanical: PASS
r2_reasoning: "Mechanical completed-M15 relative-tick-volume force cross, one-bar breakout and MA alignment, next-bar session entry, frozen ATR stop, 1.5R target, six-bar timeout, and 15:55 ET flat."
r3_data_available: PASS
r3_reasoning: "WS30.DWX, SP500.DWX, and NDX.DWX M15 price/tick-volume histories plus the US cash calendar are registered and available for DEV 2018-2023, OOS 2024, and sealed 2025."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed arithmetic thresholds and RISK_FIXED sizing with one position per magic; no grid, martingale, classified aggression feed, discretionary tape reading, or ML."
source_citations:
  - type: ntsl_source_code
    citation: "Silva, Wesley. (2026). FORCA_WIN_V16. GitHub NTSL source code, commit 38e83c24070054d78d82842c7c1b37043127ef58. https://github.com/wesleyzilva/tradetech/blob/38e83c24070054d78d82842c7c1b37043127ef58/Robots/FORCA_WIN_V16"
    location: "Signed price-range multiplied by relative-volume force formula, threshold/MA context, stop/target, bar timeout, and session-flat lineage; all performance comments remain UNVERIFIED."
    quality_tier: C
    role: primary
---

# B3 force / relative-tick-volume breakout

## Source-defined rules

Wesley Silva's 2026 practitioner NTSL artifact `FORCA_WIN_V16`, available at
the commit-pinned URL
https://github.com/wesleyzilva/tradetech/blob/38e83c24070054d78d82842c7c1b37043127ef58/Robots/FORCA_WIN_V16,
supplies the signed price-range multiplied by relative-volume formula and broad
threshold, moving-average, stop/target, bar-timeout, and session-flat lineage.
It is unaudited practitioner code; its comments and self-reported results are
**UNVERIFIED** and are not a track record.

The native WIN/WDO context does not establish portability to US `.DWX` CFDs.
This card deliberately names the observable proxy **relative-tick-volume**.
`TickVolume` is a broker tick count, not traded volume, buyer/seller delta,
market-order aggression, book imbalance, order flow, or tape access. M15
normalization, next-bar execution, rearming, US session gates, and the target
routes are transparent QM interpretations.

## QM interpretations

Every rule in this section belongs to variant `B3_RELVOL_BRK_BASELINE`.

- **Completed-bar indicator.** On each completed `M15` bar calculate
  `body_fraction=(Close-Open)/max(High-Low,one_tick)`,
  `relative_tick_volume=TickVolume/SMA20(TickVolume)`, and
  `force=clamp(100*body_fraction*relative_tick_volume,-100,+100)`. Use only
  completed bars. If range, tick size, or the volume denominator is invalid,
  set force to zero and prohibit a signal.
- **Entry signal.** LONG requires prior `force < +70`, current `force >= +70`,
  `close > prior_high`, `close > SMA20(close)`, and
  `SMA5(close) > SMA20(close)`. SHORT is symmetric: prior `force > -70`,
  current `force <= -70`, `close < prior_low`, `close < SMA20(close)`, and
  `SMA5(close) < SMA20(close)`. Enter at the next `M15` open only when that
  open is from 09:45 through 15:30 ET on an approved US cash session. No wick,
  current/incomplete-bar, or delayed entry is allowed.
- **Rearm and attempts.** A direction rearms only after a completed bar with
  `abs(force) < 25`. Permit at most two entries per symbol/cash session, only
  one open position, and no reversal while a position is open. An early close
  truncates the entry window so every accepted entry can honor the card exit.
- **Stop, target, and time exits.** At the signal close, freeze Wilder
  `ATR(14)` from completed `M15` bars through that signal bar. For the actual
  next-open fill, LONG stop is `fill-1.0*ATR14` and SHORT stop is
  `fill+1.0*ATR14`; reject non-positive or broker-invalid risk. Freeze target at
  `fill+1.5R` for LONG and `fill-1.5R` for SHORT. Exit after six completed
  `M15` holding bars if neither boundary executes, and in all cases force-flat
  at the first tradable quote at or after 15:55 ET. No breakeven move, trail,
  scaling, partial close, grid, averaging, or reversal is allowed. Resolve
  same-bar stop/target/timeout collisions from executable bid/ask tick
  chronology.
- **Sizing and cost.** Size once from the setfile's locked `RISK_FIXED` amount
  and actual fill-to-stop monetary distance; `RISK_PERCENT` is not authorized.
  Resolve current per-symbol commission, spread, tick value, conversion,
  volume step, and stop constraints from governed runtime data. Require
  `(commission + spread) / initial_monetary_risk <= 0.10R`; missing data or an
  unrepresentable lot blocks entry.
- **Density and risk family.** Approximately 135 trades/year/symbol is an
  untested prior after all gates, not a source or backtest result. WS30, SP500,
  and NDX are one correlated US-index participation family under a shared
  exposure cap, not three independent risk credits.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before any card-managed exit.
- The default framework news pause and governed spread guard remain active;
  neither may delay-enter a blocked signal.
- The framework Friday safety close remains enabled after the same-session
  15:55 ET card exit. An approved early-close calendar may flatten earlier.
- No classified aggression field, order-book or tape feed, alternate volume
  multiplier selected after results, trailing stop, portfolio rescue, grid,
  martingale, pyramid, or loss-dependent sizing override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed frozen 1.0-ATR broker hard stop.
3. Executed frozen `1.5R` target, with stop/target order determined by
   executable bid/ask tick chronology.
4. Six-completed-`M15`-bar timeout.
5. Card session exit at 15:55 ET or an earlier approved early-close safety
   time; after restart or rejected close, retry immediately before entries.
6. Framework Friday safety close if a position somehow remains open. Indicator
   or calendar invalidity blocks new entries only and never removes an open
   trade's stop or deterministic exit.

## Runtime data dependencies

- Primary chart, signal, and order route: `WS30.DWX`, `M15`.
- Sibling symbols — **per-symbol setfiles to generate at build**:
  `SP500.DWX`, `NDX.DWX`. Generate one setfile for each of the three targets.
  Each route owns its indicator history, rearm/attempt state, position, stop,
  target, and cost calculation; the portfolio owns the shared index cap.
- Completed-bar tick count is required for `relative_tick_volume`. The exact
  broker feed identity must be logged and frozen; no centralized volume,
  buyer/seller classification, book, tape, or order-flow dependency exists.
- Tester account currency is USD. Runtime needs executable bid/ask ticks,
  current tick value, account-currency conversion, volume step, stop level,
  commission schedule, and spread per target.
- Pin an IANA timezone database covering `America/New_York` and an official US
  cash holiday/early-close calendar with `valid_through=2025-12-31`.
  Ambiguous conversions or missing session metadata fail closed.
- Price and tick-volume histories must cover DEV 2018-2023, OOS 2024, and
  untouched sealed 2025 for every admitted target, with
  `valid_through=2025-12-31`. No ML service or aggression dataset is allowed.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, LONG/SHORT, signal number within session, and calendar year
  separately. Reject concentration in one symbol, side, or year.
- Run preregistered portability ablations with identical timing and exits: the
  full body/range multiplied by relative-tick-volume rule; a price-only rule
  with the volume multiplier fixed to one; and the full rule on another
  legitimate available tick-count feed. Run the volume increment before any
  limited single-parameter sensitivity; no joint optimization is authorized.
- Reject if the relative-tick-volume term has no stable OOS increment, signal
  direction/count changes materially across legitimate feeds, or post-cost
  density falls below 75 trades/year/symbol. Never relabel a passing proxy as
  aggression.
- Apply governed nonzero commission and historical spread, then shift entry and
  exit one tick adversely. Reject if OOS or sealed expectancy is not positive
  or any admitted trade requires `cost_R > 0.10R`.
- Dedup boundary: this is a completed-`M15` body/range multiplied by broker
  relative-tick-volume impulse, with a threshold cross, one-bar breakout, MA
  alignment, fixed ATR stop/target, and short US-session life. It is neither a
  generic MA breakout nor a buyer/seller aggression, order-book, tape, or B3
  microstructure strategy; requiring classified fields creates a different
  card.
- Any change to tick-feed identity, formula, SMA/ATR convention, thresholds,
  MA gates, rearm, entry window, attempt cap, stop, target, timeout, session
  close, cost model, risk mode, symbol route, or variant identity requires a
  new binary, full-versus-price-only ablation, feed reconciliation, and full
  portfolio requalification. An unresolved item is `BLOCKED`; Development may
  not fill it in.

