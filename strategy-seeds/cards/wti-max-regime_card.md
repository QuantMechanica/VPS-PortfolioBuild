---
card_schema_version: 2
type: strategy
strategy_id: HOLLSTEIN-MAX-2021_XTI_TS_S07
variant_id: HOLLSTEIN-MAX-2021_XTI_TS_S07
source_id: HOLLSTEIN-WTI-MAX-REGIME-2026
ea_id: QM5_20300
slug: wti-max-regime
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20300_wti-max-regime_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_authors: "Fabian Hollstein; Marcel Prokopczuk; Bjoern Tharann"
source_citation: "Hollstein, Prokopczuk, and Tharann (2021), Anomalies in Commodity Futures Markets, Quarterly Journal of Finance 11(4), article 2150017, DOI 10.1142/S2010139221500178."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hollstein, F., Prokopczuk, M., and Tharann, B. (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), 2150017."
    location: "DOI https://doi.org/10.1142/S2010139221500178; complete accepted-manuscript evidence strategy-seeds/sources/HOLLSTEIN-MAX-2021/source.md; bounded extraction strategy-seeds/sources/HOLLSTEIN-WTI-MAX-REGIME-2026/source.md"
    quality_tier: A
    role: primary_max_formula_post_financialization_low_minus_high_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-self-relative-two-disjoint-252-simple-return-blocks-top-five-max-low-minus-high-regime
sources:
  - "[[sources/HOLLSTEIN-WTI-MAX-REGIME-2026]]"
concepts:
  - "[[concepts/commodity-max-effect]]"
  - "[[concepts/upside-tail-demand]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/top-five-return-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, max-effect, upside-order-statistic, time-series-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 203000000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the 505-close warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright monthly WTI self-relative MAX regime, unlike paired XTI/XNG and XAU/XAG MAX ranks, WTI kurtosis/VoV, cumulative-return trend, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_completed_closes, two_disjoint_252_simple_return_blocks, exactly_five_largest_mean, source_low_max_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20300_wti_max_regime_g0.md: R1 peer-reviewed QJF source with complete-read evidence, explicit WTI membership, and full-sample/two-portfolio nulls preserved; R2 exact two-block 252-return top-five MAX estimator, self-relative low-minus-high map, and monthly lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; eleven fuzzy source/carrier neighbors were manually separated by statistic, carrier, or lifecycle."
---

# QM5_20300 WTI Self-Relative Low-MAX Regime

## Hypothesis

The source's post-financialization low-MAX commodity relation may have a weak
time-series analogue in WTI: buy when the average of the five largest returns
in the most recent 252-return block is below the same statistic in the
immediately preceding disjoint block, and sell when it is above. This treats a
decline in upside-tail intensity as a low-MAX state and an increase as a high-
MAX state.

The crude-oil carrier and upside order statistic differ from the certified
XAU, SP500, NDX, and XNG book. This is a low-prior falsification, not a
profitability, significance, decorrelation, certification, market-neutrality,
or portfolio-admission claim. Q09 remains decisive for realized overlap.

## Source Traceability And Claim Boundary

The trading source is Hollstein, Prokopczuk, and Tharann (2021), a peer-
reviewed QJF article with DOI and institutional accepted manuscript. The
complete-read parent and bounded WTI packet are identified in the metadata.

The paper specifies the prior-year top-five-return MAX statistic, a monthly
cross-sectional sort, post-financialization low-minus-high direction, and
explicit WTI membership. Its full-sample hedge return and directly relevant
two-portfolio result are null, and its supportive subsample ends in 2015. It
does not test a self-relative time-series comparison. The two disjoint blocks,
continuous-CFD carrier, fixed risk, ATR stop, spread cap, and lifecycle are QM
translations. No source return, alpha, drawdown, WTI-only result, cost, trade
count, CFD equivalence, or correlation statistic transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,365 registry rows and 476 root
cards. It found no exact identity and eleven expected fuzzy source/carrier
neighbors. Manual review separated them:

- `QM5_13130_xti-xng-lowmax` and `QM5_20294_xauxag-max-rk` rank two concurrent
  instruments, use two magics, split package risk, and repair orphan legs.
  This card compares two disjoint WTI history blocks and owns one position.
- `QM5_20295_wti-kurt-prem` uses every return in a centered fourth moment
  around benchmark three. This rule uses only five upside order statistics in
  each of two blocks and has no distribution-wide fourth moment.
- `QM5_20298_wti-vov-regime` measures dispersion-over-mean across nested
  rolling realized-volatility estimates, not extreme positive returns.
- WTI skewness, semivariance, cumulative-return trend, robust-location,
  path-efficiency, calendar, event, breakout, variance-ratio, and ordinary
  reversal EAs use different information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only oscillator
  pullback rather than a monthly symmetric upside-tail regime.

The 252 simple returns per block, five-largest arithmetic mean, disjoint
offsets `0/252`, self-relative low-minus-high direction, outright WTI carrier,
and monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_MAX_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Exact symbol: `XTIUSD.DWX`, D1, slot 0, intended magic `203000000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: exactly 505 completed D1 closes, newest first, with the newest
  endpoint before the decision bar and at most ten calendar days stale.
- Holding clock: next broker-month boundary, with a forty-day stale guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k = 0..251
MAX[b] = arithmetic_mean(five_largest(r[b,0..251]))

recent block b=0:       close-index pairs 0/1 through 251/252
preceding block b=252:  close-index pairs 252/253 through 503/504
```

Buy when `MAX[0] < MAX[252] - 1e-12`; sell when
`MAX[0] > MAX[252] + 1e-12`; remain flat inside the tolerance or on invalid
state. Magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a single maximum, percentile, winsorized statistic,
log returns, kurtosis, skewness, semivariance, volatility-of-volatility,
overlapping blocks, fitted threshold, trend, calendar direction, external
series, or prior result.

## 4. Entry Rules

1. Require exact EA ID 20300, `XTIUSD.DWX` D1, magic slot 0, and every locked
   input.
2. Process lifecycle exits before entry-only gates and evaluate only after a
   genuine broker-month transition.
3. Persist the month as consumed before history, signal, spread, quote, news,
   ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load exactly 505 completed D1 closes. Require strictly older timestamps as
   series index increases, positive finite prices, and a fresh completed
   endpoint before the decision bar.
6. Form exactly 252 simple returns in each block with disjoint return support;
   the blocks may share only close index 252.
7. Sort each complete return vector and average exactly its five largest
   observations. Require finite returns and MAX values.
8. Buy strictly below the preceding value by more than `1e-12`; sell strictly
   above it by more than `1e-12`; the tolerance band consumes the month flat.
9. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, and valid contract metadata.
10. Open at most one market position with a frozen `3.5 * ATR(20,D1)` broker
    hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of every new broker
   month before considering replacement risk, even if direction is unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, or missing-stop exposure owned
   by this EA's magic.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source-aligned hold spans weekends.
6. No intramonth flip, target, trail, break-even, partial close, scale-in,
   grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, fixed-risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  incomplete or stale history, non-decreasing time by series index,
  nonpositive close, wrong count, nonfinite return or MAX, numerical tie,
  excessive spread, invalid quote, unavailable ATR, invalid stop, or invalid
  contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, optimizer result, or
  portfolio state.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly replacement or after
  forty calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future marker so
  historical runs remain deterministic.
- Lifecycle repair closes duplicate, wrong-symbol, invalid-type, or missing-
  stop exposure before any new entry logic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_returns_per_block` | 252 | [252] | exact simple-return count in each block |
| `strategy_top_return_count` | 5 | [5] | exact largest-return observations averaged |
| `strategy_prior_block_offset` | 252 | [252] | preceding block's first return index |
| `strategy_history_bars_d1` | 505 | [505] | exact completed D1 close count |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_max_tolerance` | 1e-12 | [1e-12] | symmetric block-comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return type, block support, statistic, direction, entry clock,
risk, stop, hold, and no-retry policy are locked. Any change requires a new
card and pipeline.

## Author Claims

Hollstein, Prokopczuk, and Tharann define MAX as the prior-year average of the
five largest daily commodity returns, report a negative relation only in the
post-financialization subsample, use monthly sorts, and include WTI. They do
not claim that a two-block MAX change predicts WTI, that a continuous CFD
reproduces collateralized futures, or that this candidate diversifies the QM
book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: null full-sample and two-portfolio source
evidence, subsample dependence, cross-sectional-to-time-series translation,
two-year warm-up, sensitivity of five order statistics to isolated jumps,
persistent outright WTI states, crude gaps and rolls, CFD basis and financing,
stop slippage, and correlation with XNG or risk assets can dominate the
premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong close or return count/orientation, wrong block offset,
  overlapping returns, log instead of simple returns, wrong order-statistic
  count, high-MAX-long direction, repeated attempt, hold beyond forty days,
  missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the formation, blocks, statistic,
  threshold, direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read evidence, adverse robustness, and explicit WTI membership. |
| R2 | PASS | Fixed two-block 252-return estimator, exact top-five means, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; eleven same-source/carrier fuzzy neighbors
  were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, exact completed history, two
  disjoint simple-return blocks, top-five MAX comparison, spread/quote/ATR/
  stop checks, and one fixed-risk order.
- trade_management: malformed-state repair, broker-month exit, and stale exit
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio-gate change;
portfolio admission; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-13 | initial WTI self-relative low-MAX regime | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20300_wti_max_regime_g0.md`; bounded source packet |
| Q01 Build Validation | - | PENDING | build not started |
| Q02 Baseline Screening | - | NOT ENQUEUED | build and Q01 required |
