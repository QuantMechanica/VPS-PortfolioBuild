---
card_schema_version: 2
type: strategy
strategy_id: YIYI-ES-2025_XTI_TS_S04
variant_id: YIYI-ES-2025_XTI_TS_S04
source_id: YIYI-WTI-ES-REGIME-2026
ea_id: QM5_20301
slug: wti-es-regime
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20301_wti-es-regime_card.md
execution_contract_status: DRAFT
created: 2026-08-13
created_by: Research+Development
last_updated: 2026-08-13
g0_status: APPROVED
source_author: "Yiyi Qin; Jun Cai; Jie Zhu; Robert Webb"
source_authors: "Yiyi Qin; Jun Cai; Jie Zhu; Robert Webb"
source_citation: "Qin, Cai, Zhu, and Webb (2025), Commodity Futures Characteristics and Asset Pricing Models, Journal of Futures Markets 45(3), 176-207, DOI 10.1002/fut.22559."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Qin, Y., Cai, J., Zhu, J., and Webb, R. (2025). Commodity Futures Characteristics and Asset Pricing Models. Journal of Futures Markets 45(3), 176-207."
    location: "DOI https://doi.org/10.1002/fut.22559; complete-paper evidence strategy-seeds/sources/YIYI-ES-2025/source.md; bounded extraction strategy-seeds/sources/YIYI-WTI-ES-REGIME-2026/source.md"
    quality_tier: A
    role: primary_expected_shortfall_formula_high_minus_low_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-self-relative-two-disjoint-252-simple-return-blocks-worst-five-percent-expected-shortfall-high-minus-low-regime
sources:
  - "[[sources/YIYI-WTI-ES-REGIME-2026]]"
concepts:
  - "[[concepts/commodity-expected-shortfall-premium]]"
  - "[[concepts/downside-tail-risk]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/expected-shortfall]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, expected-shortfall, downside-tail-risk, self-relative-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 203010000
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
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify an outright monthly WTI downside-tail regime using two disjoint own-history ES blocks, unlike paired energy/metal ES ranks, WTI MAX/skew/kurtosis/VoV, return trend/reversal, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_completed_closes, two_disjoint_252_simple_return_blocks, mathematical_ceiling_tail_count, exactly_thirteen_lowest_return_mean, source_high_es_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20301_wti_es_regime_g0.md: R1 peer-reviewed Journal of Futures Markets source with complete-read evidence, exact ES transform, weak source significance, and failed paired-sibling Q04 evidence preserved; R2 exact two-block 252-return worst-five-percent estimator, ceiling count thirteen, self-relative high-ES map, and monthly lifecycle; R3 registered WTI D1 route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; five fuzzy source/name neighbors were manually separated by statistic, carrier, or lifecycle."
---

# QM5_20301 WTI Self-Relative Expected-Shortfall Regime

## Hypothesis

The source's cross-sectional high-expected-shortfall commodity relation may
have a weak time-series analogue in WTI: buy when the mean of the worst five
percent of returns in the most recent 252-return block is higher, hence less
negative, than in the immediately preceding disjoint block; sell when it is
lower, hence more negative. This treats improving downside-tail severity as a
high-ES state and deteriorating severity as a low-ES state.

The crude-oil carrier and downside-tail information object differ from the
certified XAU, SP500, NDX, and XNG book. This is a low-prior falsification,
not a profitability, significance, decorrelation, certification, or
portfolio-admission claim. Q09 remains decisive for realized overlap.

## Source Traceability And Claim Boundary

The trading source is Qin, Cai, Zhu, and Webb (2025), a peer-reviewed
*Journal of Futures Markets* article with DOI, publisher record, and a
complete open-paper review. The complete-read parent and bounded WTI packet
are identified in the metadata.

The paper specifies the prior-twelve-month mean of the worst five percent of
daily returns, a monthly cross-sectional sort, and high-minus-low direction.
Its one-way hedge has only a 1.36 full-sample t-statistic. It does not test a
self-relative time-series comparison. The two disjoint blocks, continuous-CFD
carrier, fixed risk, ATR stop, spread cap, and lifecycle are QM translations.
No source return, alpha, drawdown, WTI-specific result, cost, trade count, CFD
equivalence, or correlation statistic transfers.

The closest source-family build, `QM5_13143_energy-es-rank`, passed Q02 but
failed all three Q04 OOS folds. That failure is retained as adverse evidence;
it neither proves this distinct carrier nor authorizes a repair or changed
direction.

## Non-Duplicate Decision

The canonical checker scanned 4,366 registry rows and 477 root cards. It
found no exact identity and five expected fuzzy matches. Manual review
separated them:

- `QM5_13143_energy-es-rank` and `QM5_20235_xauxag-es-rank` rank two
  concurrent instruments, use two magics, split package risk, and repair
  orphan legs. This card compares two disjoint WTI history blocks and owns one
  position.
- `QM5_20300_wti-max-regime` uses the five largest returns in each block and
  the low-MAX direction. This card uses the thirteen smallest returns and the
  high-ES direction.
- `QM5_20289_wti-rsj-rev` uses one complete month and normalized signed
  semivariance, not sorted lower-tail means over two annual blocks.
- WTI skewness, kurtosis, VoV, trend, robust-location, calendar, event,
  breakout, variance-ratio, and ordinary reversal EAs use different
  information objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only oscillator
  pullback rather than a monthly symmetric downside-tail regime.

The 252 simple returns per block, ceiling-derived thirteen-return lower tail,
disjoint offsets `0/252`, self-relative high-ES direction, outright WTI
carrier, and monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_ES_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Exact symbol: `XTIUSD.DWX`, D1, slot 0, intended magic `203010000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: exactly 505 completed D1 closes, newest first, with the newest
  endpoint before the decision bar and at most ten calendar days stale.
- Holding clock: next broker-month boundary, with a forty-day stale guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.

```text
r[b,k] = close[b+k] / close[b+k+1] - 1, k = 0..251
K      = ceil(252 * 0.05) = 13
ES[b]  = arithmetic_mean(13 smallest r[b,0..251])

recent block b=0:       close-index pairs 0/1 through 251/252
preceding block b=252:  close-index pairs 252/253 through 503/504
```

Buy when `ES[0] > ES[252] + 1e-12`; sell when
`ES[0] < ES[252] - 1e-12`; remain flat inside the tolerance or on invalid
state. Magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to a quantile without tail averaging, another tail
probability, MAX, semivariance, skewness, kurtosis, winsorized return, trend,
calendar direction, external series, or prior pipeline result.

## 4. Entry Rules

1. Require exact EA ID 20301, `XTIUSD.DWX` D1, magic slot 0, and every locked
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
7. Sort each complete return vector ascending, calculate
   `ceil(252*0.05)=13`, and average exactly its thirteen lowest observations.
   Require finite returns and ES values.
8. Buy strictly above the preceding value by more than `1e-12`; sell strictly
   below it by more than `1e-12`; the tolerance band consumes the month flat.
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
  nonpositive close, wrong count, nonfinite return or ES, numerical tie,
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
| `strategy_tail_probability` | 0.05 | [0.05] | exact source lower-tail fraction |
| `strategy_prior_block_offset` | 252 | [252] | preceding block's first return index |
| `strategy_history_bars_d1` | 505 | [505] | exact completed D1 close count |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_es_tolerance` | 1e-12 | [1e-12] | symmetric block-comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return type, block support, tail-count convention, direction,
entry clock, risk, stop, hold, and no-retry policy are locked. Any change
requires a new card and pipeline.

## Author Claims

Qin, Cai, Zhu, and Webb define expected shortfall as the average of the worst
five percent of daily returns over the prior twelve months, form monthly
high-minus-low commodity portfolios, and associate ES with latent-factor
loadings. They do not claim that a two-block ES change predicts WTI, that a
continuous CFD reproduces collateralized futures, or that this candidate
diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: weak full-sample source evidence, failed
paired-sibling OOS evidence, cross-sectional-to-time-series translation, two-
year warm-up, sensitivity to isolated crashes and rolls, persistent outright
WTI states, CFD basis and financing, stop slippage, and correlation with XNG
or risk assets can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong close or return count/orientation, wrong block offset,
  overlapping returns, log instead of simple returns, tail count other than
  thirteen, wrong tail, low-ES-long direction, repeated attempt, hold beyond
  forty days, missing hard stop, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing formation, blocks, probability, statistic,
  threshold, direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read evidence, weak source statistics, and adverse sibling evidence disclosed. |
| R2 | PASS | Fixed two-block 252-return estimator, exact five-percent ceiling tail, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 plus native V5 execution state only. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; five source/name fuzzy neighbors were manually
  resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, exact completed history, two
  disjoint simple-return blocks, thirteen-observation ES comparison,
  spread/quote/ATR/stop checks, and one fixed-risk order.
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
| v1 | 2026-08-13 | initial WTI self-relative expected-shortfall regime | G0 | APPROVED; build pending |
| v1-q01 | 2026-08-13 | deterministic V5 build, strict compile, target guardrails, independent ES vectors, and P1 artifact validation | Q01 | PASS |
| v1-q02 | 2026-08-13 | target-only paced queue handoff after duplicate and factory-capacity checks | Q02 | ENQUEUED; pending at immediate readback |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20301_wti_es_regime_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-13 | PASS; strict compile 0 errors/0 warnings, build check 0 failures/0 warnings, 6 reference tests PASS, P1 PASS | `D:/QM/reports/compile/20260813_073825/summary.csv`; `D:/QM/reports/framework/21/build_check_20260813_073824.json`; `D:/QM/reports/pipeline/QM5_20301/P1/P1_QM5_20301_result.json` |
| Q02 Baseline Screening | 2026-08-13 | ENQUEUED; pending at immediate readback, attempt 0 | work item `391694f4-f6d3-400a-9f3b-9f8f5d700ae0`; `docs/ops/evidence/2026-08-13_qm5_20301_wti_es_regime_q01_q02_enqueue.md` |
