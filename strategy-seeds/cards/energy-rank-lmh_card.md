---
strategy_id: FERNHOLZ-KOCH-RANK-2016_XTI_XNG_S01
source_id: FERNHOLZ-KOCH-RANK-2016
ea_id: QM5_13148
slug: energy-rank-lmh
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: institutional_working_paper
    citation: "Fernholz, Ricardo T., and Christoffer Koch (2016). The Rank Effect for Commodities. Federal Reserve Bank of Dallas Working Paper 1607, revised March 22, 2026."
    location: "Complete institutional paper, especially Sections 1-4 and Appendix; https://www.dallasfed.org/-/media/documents/research/papers/2016/wp1607.pdf; complete arXiv manuscript and revision record https://arxiv.org/abs/1607.07510"
    quality_tier: A
    role: primary
strategy_type_flags: [signal-reversal-exit, atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13148_XTI_XNG_RANK_LMH_D1
period: D1
expected_trade_frequency: "One XTI/XNG normalized-price rank package per broker calendar month after the fixed 2017-01-03 anchor and 20 completed D1 bars; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether the source's low-minus-high normalized-price rank survives as a fixed-origin, monthly XTI/XNG package. It is not rolling value, return-spread z-score reversion, momentum/carry, or the incumbent XNG RSI pullback. Source performance and realized book orthogonality remain unclaimed."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, fixed_anchor, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: R1 complete Federal Reserve working paper and arXiv manuscript from named authors, with non-peer-reviewed status disclosed; R2 locked 2017-01-03 origin, seven-day anchor bound, 20-bar warm-up, direct normalized-price low-minus-high comparison, monthly basket, hard stops, and lifecycle guards; R3 registered native XTI/XNG D1 data; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding. Canonical fuzzy matches on the energy-rank slug family were manually resolved by signal/input/window/direction as distinct. The two-name narrowing, daily-to-monthly translation, fixed-origin dependence, continuous-CFD basis, and legging are binding Q02 kill risks."
---

# XTI/XNG Monthly Fixed-Origin Rank Low-Minus-High

## Hypothesis

If the cross-sectional distribution of relative commodity prices is stable,
lower-ranked normalized prices must grow faster on average than higher-ranked
prices. This card tests the primitive rank direction in energy: buy the XTI or
XNG leg whose completed D1 close has grown less from a single predeclared
common origin, and short the leg whose normalized price has grown more.

Opposite directions and equal fixed-risk halves reduce outright energy
direction. They do not guarantee dollar, beta, volatility, factor, rank, or
realized market neutrality. Later portfolio gates alone may establish
correlation to the certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

Fernholz and Koch, *The Rank Effect for Commodities*, Federal Reserve Bank of
Dallas Working Paper 1607, studies 30 commodity futures including crude oil
and natural gas. It normalizes prices to a common initial value, waits 20
trading days, ranks commodities by normalized price, and forms an equal-dollar
long-low/short-high portfolio with daily renewal.

The source uses a broad collateralized futures cross-section. Darwinex runtime
offers this build two continuous CFDs. The card also slows daily renewal to one
broker-month package to meet the mission's low-frequency constraint. This is a
disclosed falsification, not a replication. No source return, alpha,
significance, drawdown, transaction-cost, turnover, or correlation value is
imported into the QM prior.

## Concept And Formula

Use one immutable common broker-date origin:

```text
anchor_date = 2017-01-03 00:00

anchor_close_i = first completed D1 close on or after anchor_date
normalized_i,t = latest completed D1 close before decision_t / anchor_close_i
```

- Each effective anchor must occur no more than seven calendar days after the
  configured origin, and both legs must resolve to the identical bar time.
- Require at least 20 completed D1 bars after the anchor close before the first
  signal.
- `normalized_XTI < normalized_XNG`: BUY XTI and SELL XNG.
- `normalized_XTI > normalized_XNG`: SELL XTI and BUY XNG.
- Exact numerical tie, invalid price, stale/misaligned endpoint, missing fixed
  anchor, or insufficient warm-up: remain flat.

The anchor is not rolling. No mean, variance, z-score, regression, momentum,
carry, or entry threshold is estimated.

## Markets And Timeframe

- Logical basket: `QM5_13148_XTI_XNG_RANK_LMH_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal data: completed native D1 closes only; current bars are excluded.
- Rebalance: first tradable D1 host bar of each broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across both traded legs.
- Runtime data: native MT5 D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect the first tradable host D1 bar of each broker month using completed
  host bar dates; do not depend on MN1 bars.
- Parse the locked `2017.01.03` anchor. For each leg, load bounded completed
  D1 history, find the first close on/after that origin, require it within
  seven calendar days, and require identical anchor timestamps across legs.
- Require at least 20 completed bars strictly after the anchor close.
- Use the latest completed close before the decision bar; require identical
  endpoint timestamps across legs and at most ten calendar days of staleness.
- Divide each latest close by its own fixed anchor close and compare the two
  finite positive normalized levels directly.
- Buy the lower normalized-price leg and short the higher normalized-price
  leg; reject an exact numerical tie.
- Reject invalid history, prices, arithmetic, ATR/lot metadata, excess spread,
  an existing package, or a broker month already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create a
  second package in the same month.
- Split fixed package risk equally and attach a frozen `ATR(20) * 3.5` hard
  stop to each leg. If the second order fails, flatten the first immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 host bar of the next broker month
  before evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the declared monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked anchor, anchor gap, warm-up, exact host, bounded completed-bar
  history, endpoint freshness/alignment, finite arithmetic, spread, ATR, lot,
  month-attempt, magic, and package checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs use equal fixed-risk shares.
- One paired package per broker month; a stopped or missing leg does not
  authorize same-month re-entry.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, futures chain, banned indicator, adaptive PnL fit,
  or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_anchor_date` | `2017.01.03` | locked | immutable normalization origin |
| `strategy_max_anchor_gap_days` | 7 | locked | prevents a drifting substitute origin |
| `strategy_min_anchor_age_bars` | 20 | locked | source-specified rank warm-up |
| `strategy_history_bars` | 3000 | [2600, 3000, 3600] | bounded retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed-endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | locked | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The origin, anchor bound, 20-bar warm-up, direct normalized-level comparison,
low-minus-high direction, monthly renewal, equal half-risk package, and no
same-month re-entry are locked. Changing any requires a new card and full
pipeline run.

## Author Claim

The paper states that "lower-ranked, lower-priced assets must necessarily have
their prices grow more quickly" (Section 2). This short source claim motivates
queue admission; it does not validate the two-CFD monthly carrier.

## Risk And Kill Criteria

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, fixed-origin dependence,
  two-name concentration, continuous-CFD basis, and monthly holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, nondeterminism,
  persistent orphan exposure, missing/moving anchor, stale history, or risk
  mismatch.
- Do not move the anchor, shorten the warm-up, add a z-score/threshold, reverse
  direction, substitute rolling value or momentum, or relax alignment/package
  guards to rescue weak economics.
- The daily-to-monthly translation, broad-to-two-name narrowing, arbitrary but
  locked origin, source endpoint, futures/CFD basis, financing, gaps, legging,
  and costs are kill risks, never waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural normalized-price rank thesis.
- [x] Complete Federal Reserve working paper and arXiv manuscript from named
      authors; non-peer-reviewed status disclosed.
- [x] No banned indicator, ML, external runtime feed, futures-chain data,
      grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-translation aligned and documented.
- [x] Canonical fuzzy matches on the energy-rank slug family were manually
      resolved by signal/input/window/direction as distinct.

## Non-Duplicate Decision

- `QM5_13123_energy-val-rank`: moving 54-66 month average/current-price value
  characteristic, not an immutable common-origin normalized level.
- `QM5_12840_xti-xng-rspread`: rolling 20-day return-spread z-score fade, not
  a direct fixed-origin rank.
- `QM5_1129_gatev-pairs-trading-distance`: rolling 252-bar normalized
  formation and standardized spread excursion, not a non-rolling rank.
- Energy trend, momentum, reversal, carry, calendar, beta, tail, salience,
  liquidity, and idiosyncratic-factor builds use different characteristics.
- `QM5_12567_cum-rsi2-commodity`: two-day long-only RSI pullback, not a paired
  monthly normalized-price rank.

Pre-allocation canonical verdict was `FUZZY MATCH` for five shared
`energy-*-rank` slugs. Manual review resolved each as a different
characteristic and found no fixed-origin XTI/XNG low-minus-high rank basket.

## Framework Alignment

- no_trade: exact host/slot, locked origin and warm-up, bounded completed-bar
  history, anchor/endpoint alignment, freshness, finite arithmetic, spread,
  ATR, lot, magic, package, and prior-attempt guards.
- trade_entry: monthly fixed-origin low-normalized-price versus high-normalized-
  price rank, paired orders, equal fixed-risk allocation, and frozen stops.
- trade_management: next-month close, 40-day time stop, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial fixed-origin XTI/XNG normalized-price rank | Q02 | Q01 build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | - | pending | - |
| Q02 Baseline Screening | - | pending enqueue | - |

## Lessons Captured

- 2026-07-11: The rank edge remains distinct only while the normalization
  origin is immutable and the signal directly compares normalized levels;
  rolling the anchor would collapse it into relative value or reversal.
