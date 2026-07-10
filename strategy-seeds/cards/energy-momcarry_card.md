---
strategy_id: FMR-MOMTS-2010_XTI_XNG_S01
source_id: FMR-MOMTS-2010
ea_id: QM5_13126
slug: energy-momcarry
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Rallis, Georgios (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete 47-page accepted manuscript; Sections 2-7, Tables 1-10, Appendices A1-A3; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009"
    quality_tier: A
    role: primary
strategy_type_flags: [carry-direction, atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13126_ENERGY_MOMCARRY_D1
period: D1
expected_trade_frequency: "Approximately 4-8 completed monthly packages/year when momentum and carry ranks agree; Q02 retirement floor is five/year."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval 2026-07-10: peer-reviewed JBF paper and complete accepted text; fixed one-completed-month momentum rank, independent broker-swap carry rank, strict agreement, monthly paired hold, equal fixed risk, and hard stops; registered XTI/XNG native data; no ML/banned/external/grid/martingale logic; repository dedup CLEAN before atomic QM5_13126 allocation."
---

# XTI/XNG Momentum-Carry Double Screen

## Hypothesis

Recent commodity winners are more credible continuation candidates when their
carry ranking points in the same direction. This card tests a low-frequency
two-energy package that buys the last completed month's XTI/XNG winner only
when it also has the higher broker-native swap differential, and shorts the
other leg.

Opposite legs reduce common energy direction but do not guarantee beta or
dollar neutrality. Portfolio decorrelation is a design objective, not a claim;
only a surviving return stream can be evaluated downstream.

## Source And Evidence Boundary

The primary source is Fuertes, Miffre, and Rallis (2010), *Journal of Banking &
Finance* 34(10), DOI `10.1016/j.jbankfin.2010.04.009`. The complete accepted
47-page manuscript was read, including tables and appendices.

The paper ranks a broad futures cross-section on front-end roll return and past
performance. This two-CFD port replaces the unavailable futures curve with the
Darwinex symbol's long-versus-short swap differential. `.DWX` tester symbols
expose zero swap, so the locked Q02 baseline uses a predeclared `+1` carry rank
(prefer XTI) while still requiring the independent momentum rank. That proxy,
the two-instrument narrowing, and the lack of historical swap changes are
explicit falsification risks. No paper performance statistic is a QM
expectation.

## Rules

On the first new `XTIUSD.DWX` D1 bar of each broker month:

1. Select synchronized closes immediately before the current month boundary
   and the boundary one month earlier for XTI and XNG.
2. Compute each leg's completed-month log return and rank the two legs.
3. Compute `carry_edge = SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT` for each leg and
   rank the two edges.
4. Stay flat if the return rank ties, nonzero carry ranks tie, or momentum and
   carry ranks disagree. On all-zero `.DWX` tester metadata only, substitute
   the card-locked `+1` carry rank.
5. When ranks agree, buy the higher-return/higher-carry leg and sell the
   lower-return/lower-carry leg.
6. Split the fixed package risk equally and attach a frozen `ATR(20) * 3.5`
   hard stop to each leg.
7. Close the package on the next broker-month transition, after 35 calendar
   days, or immediately when one leg is missing or package composition is
   invalid.

The source states that the double sort "buys the High-Winner portfolio, shorts
the Low-Loser portfolio and holds this position for one month" (Section 5.1,
pp. 17-18).

## Markets And Timeframe

- Logical basket: `QM5_13126_ENERGY_MOMCARRY_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: completed month-end closes; the live month is excluded.
- Runtime data: MT5 D1 OHLC, ATR, spread, calendar, swap properties, and
  position state only.

## Entry Rules

- Exact host guard: `XTIUSD.DWX`, D1, magic slot 0.
- Evaluate only once on the first host D1 bar of a new broker month.
- Reject a completed-month endpoint more than ten calendar days before its
  boundary.
- Require finite positive prices and a nonzero completed-month return
  difference.
- Require finite swap-long and swap-short properties for both legs.
- Require a nonzero carry-edge difference. Nonzero tied swap stays flat; when
  every `.DWX` tester swap field is zero, use only the predeclared
  `strategy_zero_swap_fallback_direction`.
- Require `sign(xti_return - xng_return) == sign(xti_carry - xng_carry)`.
- BUY XTI plus SELL XNG when both ranks prefer XTI.
- SELL XTI plus BUY XNG when both ranks prefer XNG.
- Reject missing history, invalid ATR/lot metadata, excess spread, an existing
  package, or a month already entered.

## Exit Rules

- Close both legs on the next broker-month transition before evaluating a
  replacement package.
- Close both legs when the package age reaches 35 calendar days.
- If either broker stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's one-month hold.

## Filters And Trade Management

- Framework kill switch remains first and authoritative.
- News compliance gates entries only; management and repair remain active.
- One bounded history read per leg on the monthly signal path.
- One package per EA and no same-month re-entry after a successful open.
- No take profit, trailing stop, break-even, partial close, scale-in, grid,
  martingale, pyramiding, external data, adaptive fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_momentum_months` | 1 | [1, 3, 12] | source-declared momentum rank |
| `strategy_history_bars` | 120 | [90, 120, 180] | bounded endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | [7, 10] | stale endpoint guard |
| `strategy_min_carry_rank_gap` | 0.0 | [0.0] | strict non-tie carry rank |
| `strategy_zero_swap_fallback_direction` | 1 | [-1, 0, 1] | locked `.DWX` tester carry rank; 0 disables |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | hard-stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | order deviation |

The Q02 baseline locks the one-month source variant. The 3- and 12-month
source variants are declared future axes, not authorization to tune after a
poor baseline. Carry agreement, monthly renewal, equal half-risk legs, paired
carrier, explicit all-zero tester fallback, and no same-month re-entry are
locked.

## Non-Duplicate Decision

- `QM5_12733_xti-xng-xmom` is raw 12-month relative momentum without carry.
- `QM5_13089_xti-xng-carry` is a weekly carry-only rank with a 12-month adverse
  guard; this card requires an independent completed-month momentum rank and
  renews monthly only when the two ranks agree. Both disclose the `.DWX`
  all-zero tester limitation.
- `QM5_13121_energy-tfmom` combines 12-month momentum with a seven-month price
  trend and inverse-volatility weights, not swap.
- `QM5_13113`, `QM5_13115`, `QM5_13118`, `QM5_13120`, and `QM5_13123` pair
  energy ranks with residual volatility, calendar history, skewness, reversal,
  or value rather than carry.
- `QM5_12567` is a short RSI pullback and has no overlap.

Repository pre-allocation dedup verdict: `CLEAN`.

## Risk

- Backtests use one logical basket setfile with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and equal half-budget leg sizing.
- Expected frequency is a conservative queue prior; retire below five
  completed packages/year. Nonzero tied carry remains a stand-down.
- Fail Q02 on nondeterminism, persistent orphan exposure, risk mismatch, or
  invalid completed-month endpoints.
- Treat CFD/futures basis and the fixed tester carry rank as falsification
  risks, never waiver grounds. Q02 does not claim historical carry variation.
- Do not loosen the agreement gate or change the predeclared fallback after a
  poor baseline.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed JBF paper with DOI and complete accepted text.
- [x] R2 mechanical: fixed momentum/carry ranks, agreement, lifecycle, stops.
- [x] R3 testable: registered XTIUSD.DWX/XNGUSD.DWX and MT5 symbol metadata.
- [x] R4 compliant: no banned indicator, ML, external feed, grid, martingale.
- [x] Four controlled strategy flags are present.
- [x] Repository dedup was clean before EA-ID allocation.

## Framework Alignment

- no_trade: exact host/slot, locked baseline, history/end-point freshness,
  arithmetic, swap-tie, spread, ATR, lot, and package guards.
- trade_entry: independent completed-month momentum and broker-swap ranks,
  strict agreement, paired orders, equal fixed-risk allocation, hard stops.
- trade_management: monthly reset, 35-day stale close, composition validation,
  and orphan cleanup.
- trade_close: framework close helper plus broker-side ATR hard stops.

No `T_Live`, AutoTrading, live setfile, deploy manifest, portfolio gate, or
portfolio admission artifact is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-10 | initial source-backed extraction and mission approval | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-10 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-10 | PASS | `artifacts/qm5_13126_build_result.json` |
| Q02 Baseline Screening | 2026-07-10 | ENQUEUED | `docs/ops/evidence/2026-07-10_qm5_13126_energy_momcarry_q02_enqueue.md` |
