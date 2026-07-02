---
ea_id: QM5_12895
slug: xng-6m-reversal
type: strategy
source_id: BIANCHI-COMM-52W-2016
source_citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016. DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; SSRN https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2571725"
sources:
  - "[[sources/BIANCHI-COMM-52W-2016]]"
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/commodity-momentum]]"
  - "[[concepts/medium-horizon-reversal]]"
  - "[[concepts/overextension-fade]]"
indicators:
  - "[[indicators/rolling-return-120]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [medium-horizon-reversal, return-threshold-fade, atr-hard-stop, time-stop, monthly-rebalance, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly D1 XNGUSD 6-month overextension fade; estimate 4-10 entries/year after threshold and SMA filters."
expected_trades_per_year_per_symbol: 7
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 24.0
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-02: R1 PASS peer-reviewed Bianchi-Drew-Fan commodity momentum/reversal source plus Yang commodity reversal supplement; R2 PASS deterministic 120-D1 return threshold, SMA/ATR stretch confirmation, ATR stop, zero-cross exit, and max-hold exit; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus QM5_12567 because this is monthly 6-month overextension fade, not 2-day RSI pullback."
---

# XNGUSD 6-Month Overextension Fade (Medium-Horizon Reversal)

## Source

- Source: [[sources/BIANCHI-COMM-52W-2016]]
- Primary citation: Bianchi, R. J., Drew, M. E. and Fan, J. H. "Commodities
  momentum: A behavioural perspective." Journal of Banking and Finance, 2016.
  DOI https://doi.org/10.1016/j.jbankfin.2016.06.010.
- Supplement: Yang, Goncu, and Pantelous. "Momentum and Reversal in Commodity
  Futures." SSRN working paper. URL
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## Concept

Bianchi et al. (2016) document horizon-dependent momentum/reversal in commodity
futures. Using behavioural finance frameworks, they show that commodities
exhibit continuation at long horizons (~12 months, captured by QM5_12807) and
reversal at short horizons (~4 weeks, captured by QM5_12620). The intermediate
6-month (~120 D1 bar) window is unoccupied in the current XNG library.

The mechanism: Natural gas is driven by injection/withdrawal cycles of roughly
4–6 months each. A rally that has continued for 6 months typically reflects
a complete storage build (or draw) that is near exhaustion. When the price
has extended >20% above or below its starting level 120 bars ago, the
fundamental driver (seasonal storage fill) has likely been priced in and
reversion begins.

Yang et al. (2017) corroborate: their Table 4 documents reversal in natural gas
at 4–8 week and 4–6 month horizons, with momentum only dominant at 9–12 months.

Low-corr vs book: QM5_12567 is a 2-day RSI reversion. This is a 6-month
return-threshold fade — the same STYLE (mean-reversion) but at a 60× longer
horizon, meaning it fires on completely different events. The style similarity
to 12567 in name (both MR) is outweighed by the horizon difference; in a
portfolio they diversify because 12567 fires dozens of times per year on
tiny pullbacks while this fires 4–10 times per year on multi-month
overextensions.

## Market universe

- `XNGUSD.DWX` only.
- D1 timeframe. 120 D1 bars required as lookback minimum.

## Entry rules

Monthly rebalance check (first D1 bar of each calendar month):

1. Compute `half_yr_return = Close[0] / Close[120] - 1` (6-month return).
2. **Short signal (fade rally):** `half_yr_return > fade_threshold_up` (suggest
   0.20; sweep {0.15, 0.20, 0.30}).
   Confirmation: `Close[0]` is more than `1.5 × ATR(20)` above `SMA(Close, 20)`
   (price stretched above short-term mean).
3. **Long signal (fade decline):** `half_yr_return < -fade_threshold_dn` (suggest
   0.20; sweep {0.15, 0.20, 0.30}).
   Confirmation: `Close[0]` is more than `1.5 × ATR(20)` below `SMA(Close, 20)`.
4. If an existing position is in the same direction, skip.
5. Direction switch: close existing, open new.

## Exit rules

- Close when `half_yr_return` crosses back through zero (momentum exhausted).
- ATR hard stop: `2.5 × ATR(20)` from entry in the fade direction.
- Max hold: 40 D1 bars (two monthly rebalances) as stale-position guard.
- No take-profit target.

## Risk

- `RISK_FIXED > 0`, `RISK_PERCENT = 0` for backtests.
- One open position per symbol magic at all times.
- No grid, martingale, partial close, or external data.

## Filters

- **Spread filter:** Skip entry if broker spread > 2500 points on `XNGUSD.DWX`.
- **News filter:** Standard V5 news blackout applies; EIA Thursday releases are
  expected to be held through (6-month position is not unwound for weekly data).
- **Minimum lookback:** Require at least 120 completed D1 bars before signals.

## Falsification

- Fail if the 6-month overextension fade produces fewer than 4 round-trip trades
  in a 7-year backtest (signal fires too rarely to draw valid conclusions).
- Fail if mean reversion does not materialise within the 40-bar max hold guard
  in at least 55% of trades (would indicate the overextension persists rather
  than reverts at this horizon).
- Fail if the strategy is profitable only in one direction — both long and short
  fades must show positive expectancy to invalidate a directional bias hypothesis.
- Kill if the signal fires on the same bars as QM5_12807 in >70% of cases
  (would indicate the two cards effectively fire on the same market event).

## Q08/Q11 risks

- **Q08:** The 6-month fade can catch the centre of a directional crisis
  (e.g., going long mid-way through a 2022-style energy price collapse). Stress
  slices must show the drawdown is bounded by the ATR stop in crisis periods.
- **Q11:** Monthly rebalance means the position changes at most 12 times per
  year. News blackout at entry only; holding through EIA storage reports is
  intentional for a medium-horizon contrarian position. Robustness argument:
  the edge is structural overextension, not a reaction to weekly news.

## Dedupe notes

- Distinct from QM5_12620 (comm-reversal-4wk): 12620 fades 20-bar (4-week)
  returns; this fades 120-bar (6-month) returns. Non-overlapping horizons —
  they will rarely fire simultaneously.
- Distinct from QM5_12807 (xng-52w-anchor): 12807 is a momentum continuation;
  this is a reversal fade at 6-month horizon. Opposite signals in a shared
  trending year (if 12807 says long, 6-month threshold may not yet be breached).
- Distinct from QM5_12893 (xng-12m-carry): 12893 is broker-swap carry at
  12 months; this is contra-directional fade at 6 months.

## P3 sweep

Narrow: `fade_threshold ∈ {0.15, 0.20, 0.30}`, `atr_mult_stop ∈ {2.0, 2.5, 3.0}`,
`stretch_atr_confirm ∈ {1.0, 1.5}`. Max hold guard {30, 40, 60}.

## Implementation notes

- `Close[120]` must use completed bars (no look-ahead).
- Apply broker holiday calendar for monthly rebalance detection.
- Required diagnostics: `half_yr_return`, `fade_threshold`, `atr_stretch`,
  `sma_value`, `signal_direction`, `entry_bar_date`.
