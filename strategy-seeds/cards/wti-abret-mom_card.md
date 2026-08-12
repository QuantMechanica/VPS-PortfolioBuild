---
strategy_id: CAPORALE-PLASTUN-2021_OIL_S02
source_id: CAPORALE-PLASTUN-2021
ea_id: QM5_20049
slug: wti-abret-mom
status: APPROVED
created: 2026-07-22
created_by: Research+Development
last_updated: 2026-07-22
g0_status: APPROVED
source_citations:
  - type: academic_paper
    citation: "Caporale, G. M. and Plastun, A. (2021). Gold and oil prices: abnormal returns, momentum and contrarian effects. Financial Markets and Portfolio Management 35, 353-368. DOI 10.1007/s11408-021-00380-w."
    location: "Sections 3-4, especially equations 1-3, Strategy 2, Tables 1-4 and Appendices C-D"
    quality_tier: A
    role: primary
strategy_type_flags: [volatility-breakout, momentum, atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [H1, D1_signal]
target_symbols: [XTIUSD.DWX]
expected_trades_per_year_per_symbol: 10
pipeline_phase: Q02
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes one new card/build; open-access peer-reviewed source gives the oil abnormal-return definition and next-day momentum direction/timing; deterministic no-lookahead rolling translation on registered XTIUSD.DWX; no ML/grid/martingale/external runtime feed."
---

# WTI Abnormal-Return Next-Day Momentum

## Concept

Caporale and Plastun find that an unusually large oil open-to-close move tends
to continue for the first hours of the following trading day. This card tests
that structural delayed-reaction effect on the WTI CFD: after a completed D1
return crosses a two-standard-deviation threshold, enter the same direction on
the first H1 bar of the next broker day and flatten at 10:00 broker time.

## Source claims and translation boundary

The source defines return as `Close/Open - 1`, uses a dynamic trigger, selects
`k=2`, and states that on the following day oil moves in the direction of the
abnormal return. It reports the largest next-day momentum effects at 09:00 for
positive shocks and 10:00 for negative shocks (GMT+3), with oil Strategy 2
results statistically different from random trading.

The paper estimates its threshold from the study sample. A backtest cannot do
that without look-ahead, so this card locks a causal 252-completed-D1 rolling
mean and sample standard deviation, excluding the signal day. That is a
deliberate CFD implementation translation, not a source performance claim.

## Immutable Q02 rules

- Run only on `XTIUSD.DWX`, H1, magic slot 0.
- At the first H1 bar of a new broker day, calculate the immediately completed
  D1 open-to-close return.
- Calculate mean and sample standard deviation from the 252 earlier completed
  D1 open-to-close returns; the signal day is excluded from these estimates.
- BUY when signal return is above `mean + 2 * sd`; SELL when it is below
  `mean - 2 * sd`; otherwise do nothing.
- Require the signal D1 bar to be the immediately preceding broker date; skip
  weekends/data gaps rather than backfilling a stale shock.
- Freeze a `2.5 * ATR(20,D1)` hard stop at entry. No target, trail, add-on,
  reversal, oscillator, or pyramiding.
- Close at the first H1 bar whose broker hour is at least 10, or after 36 hours
  as a stale-position guard. Friday close remains enabled.
- Spread cap 1000 points. Backtest sizing is exactly `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## Non-duplicate decision

Repository search found no card or EA using Caporale-Plastun oil abnormal-return
continuation. Existing WTI sleeves are calendar, holiday, weekday, monthly
trend/reversal, pullback, inventory, or cross-asset rules. QM5_20049 alone uses
a causal D1 open-to-close shock z-score followed by a same-direction next-day
H1 hold; it is unrelated to QM5_12567 cumulative-RSI2 commodity reversion.

## Risk, frequency and kill criteria

Expected cadence is roughly 6-18 packages/year. Q02 must retire on fewer than
five completed packages/year, zero trades, repeat entries per signal day,
look-ahead/bar-date failure, nondeterminism, risk mismatch, or governed net
economics failure. Do not tune direction, lookback, z threshold or exit hour
after observing Q02.

## Framework alignment

- no_trade: exact symbol/H1/slot, valid parameters, spread, fresh-day and
  one-position guards plus framework defaults.
- trade_entry: causal 252-day shock threshold, symmetric same-direction entry,
  and frozen D1 ATR stop.
- trade_management: 10:00 broker-time exit and 36-hour stale guard.
- trade_close: framework strategy close, ATR hard stop, or Friday close.

## Allowability and safety boundary

- [x] Mechanical and low-frequency.
- [x] No ML, banned indicator, external runtime data, grid or martingale.
- [x] Darwinex-native `.DWX` data only.
- [x] Source is peer-reviewed and the implementation translation is disclosed.
- [x] Exact-mechanic repository search is clean.

Card, build, compile and Q02 enqueue only. No T_Live, AutoTrading, live
setfile, deploy manifest, portfolio manifest or portfolio-gate modification.

## Pipeline history

| version | date | phase | verdict |
|---|---|---|---|
| v1 | 2026-07-22 | Q02 | PENDING |
