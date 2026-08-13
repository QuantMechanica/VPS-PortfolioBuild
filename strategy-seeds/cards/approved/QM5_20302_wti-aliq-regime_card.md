---
card_schema_version: 2
type: strategy
strategy_id: YIYI-ALIQ-2025_XTI_TS_S02
variant_id: YIYI-ALIQ-2025_XTI_TS_S02
source_id: YIYI-WTI-ALIQ-REGIME-2026
ea_id: QM5_20302
slug: wti-aliq-regime
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20302_wti-aliq-regime_card.md
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
    location: "DOI https://doi.org/10.1002/fut.22559; complete-paper evidence strategy-seeds/sources/YIYI-ALIQ-2025/source.md; bounded extraction strategy-seeds/sources/YIYI-WTI-ALIQ-REGIME-2026/source.md"
    quality_tier: A
    role: primary_aliq_formula_high_minus_low_direction_and_monthly_cadence
strategy_mechanic: monthly-wti-self-relative-two-disjoint-252-log-return-tick-volume-amihud-illiquidity-high-minus-low-regime
sources:
  - "[[sources/YIYI-WTI-ALIQ-REGIME-2026]]"
concepts:
  - "[[concepts/commodity-illiquidity-premium]]"
  - "[[concepts/activity-price-impact]]"
  - "[[concepts/crude-oil-structural-premium]]"
indicators:
  - "[[indicators/amihud-illiquidity-proxy]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, illiquidity-premium, activity-price-impact, self-relative-regime, monthly-rebalance, atr-hard-stop, time-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 203020000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eleven to twelve monthly WTI positions/year after the 505-bar warm-up because only a numerical tie or invalid state stays flat; Q02 must prove at least five completed positions/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify an outright monthly WTI activity-price-impact regime using two disjoint own-history ALIQ blocks, unlike paired energy ALIQ, WTI ES/MAX/skew/kurtosis/VoV, return trend/reversal, calendar, event, and XNG RSI neighbors; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exactly_505_completed_rates, two_disjoint_252_log_return_blocks, same_bar_tick_volume_alignment, strictly_positive_tick_volume, fixed_one_million_scale, source_high_aliq_direction, monthly_attempt_state, risk_mode_dual, friday_close_disabled, tick_volume_dollar_volume_proxy, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-13_qm5_20302_wti_aliq_regime_g0.md: R1 peer-reviewed Journal of Futures Markets source with complete-read evidence, exact ALIQ transform, proxy caveat, and paired-sibling Q08 failure preserved; R2 exact two-block 252-log-return/activity estimator, one-million scale, self-relative high-ALIQ map, and monthly lifecycle; R3 registered WTI D1 close/tick-volume route; R4 deterministic native arithmetic without trained output or prohibited signal indicator. No exact identity; two fuzzy neighbors were manually separated by carrier or statistic."
---

# QM5_20302 WTI Self-Relative Amihud-Illiquidity Regime

## Hypothesis

The source's cross-sectional high-illiquidity commodity relation may have a
weak time-series analogue in WTI: buy when average absolute price movement per
unit of quote-tick activity in the most recent 252-return block is higher than
in the immediately preceding disjoint block; sell when it is lower. This
treats a rise in the source-aligned ALIQ proxy as a high-ALIQ state.

The crude-oil carrier and activity-price-impact information object differ
from the certified XAU, SP500, NDX, and XNG book. This is a low-prior
falsification, not a profitability, significance, decorrelation,
certification, or portfolio-admission claim. Q09 remains decisive for
realized overlap.

## Source Traceability And Claim Boundary

The trading source is Qin, Cai, Zhu, and Webb (2025), a peer-reviewed
*Journal of Futures Markets* article with DOI, publisher record, and a
complete open-paper review. The complete-read parent and bounded WTI packet
are identified in the metadata.

The paper specifies the prior-twelve-month mean of daily absolute return
divided by dollar volume, a monthly cross-sectional sort, and high-minus-low
direction. It does not test a self-relative time-series comparison. The two
disjoint blocks, MT5 tick-volume proxy, continuous-CFD carrier, fixed risk,
ATR stop, spread cap, and lifecycle are QM translations. No source return,
alpha, drawdown, WTI-specific result, cost, trade count, CFD equivalence, or
correlation statistic transfers.

The closest source-family build, `QM5_13140_energy-aliq-rank`, passed Q02
through Q07 and failed Q08 hard on a runs-test p-value of `0.00226`. Its 2024
Q02 row had 82 trades and PF 1.19. That evidence is retained; it neither
proves this distinct carrier nor authorizes a repair or changed direction.

## Non-Duplicate Decision

The canonical checker scanned 4,367 registry rows and 478 root cards. It
found no exact identity and two expected fuzzy matches. Manual review
separated them:

- `QM5_13140_energy-aliq-rank` ranks concurrent XTI and XNG proxy values over
  the prior twelve completed months, opens two opposite legs, and manages
  package risk. This card compares two fixed WTI blocks and owns one position.
- `QM5_20301_wti-es-regime` shares a monthly WTI/two-block architecture but
  sorts and averages thirteen lower-tail simple returns. This card averages
  all 252 absolute log returns divided by same-bar tick volume.
- WTI trend, calendar, event, variance-ratio, robust-location, reversal,
  skewness, kurtosis, MAX, ES, and VoV EAs use other state objects or clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG pullback,
  not a monthly symmetric WTI activity-price-impact state.

The return type, same-bar tick-volume divisor, one-million scale, two offsets,
252-term means, disjoint support, source high-ALIQ direction, outright WTI
carrier, and monthly consumed attempt are jointly load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_ALIQ_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Formula

- Exact symbol: `XTIUSD.DWX`, D1, slot 0, intended magic `203020000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: exactly 505 completed D1 rates, newest first, with the newest
  endpoint before the decision bar and at most ten calendar days stale.
- Holding clock: next broker-month boundary, with a forty-day stale guard.
- Expected cadence: eleven to twelve positions per full post-warm-up year;
  retire below five observed positions/year.

```text
r[b,k]       = ln(close[b+k] / close[b+k+1]), k = 0..251
aliq[b,k]    = abs(r[b,k]) / tick_volume[b+k] * 1,000,000
ALIQ[b]      = arithmetic_mean(aliq[b,0..251])

recent block b=0:       close pairs 0/1..251/252; volumes 0..251
preceding block b=252:  close pairs 252/253..503/504; volumes 252..503
```

Buy when `ALIQ[0] > ALIQ[252] + 1e-12`; sell when
`ALIQ[0] < ALIQ[252] - 1e-12`; remain flat inside the tolerance or on invalid
state. Magnitude never scales risk.

## Rules

These are the complete authorized baseline. There is no signal-parameter
sweep and no fallback to simple returns, real or dollar volume, range,
spread, turnover, rank percentile, normalization, trend, calendar direction,
external series, or prior pipeline result.

## 4. Entry Rules

1. Require exact EA ID 20302, `XTIUSD.DWX` D1, magic slot 0, and every locked
   input.
2. Process lifecycle exits before entry-only gates and evaluate only after a
   genuine broker-month transition.
3. Persist the month as consumed before history, signal, spread, quote, news,
   ATR, sizing, or order checks. No outcome may retry that month.
4. Reject owned exposure or any same-month entry deal for the magic.
5. Load exactly 505 completed D1 rates. Require strictly older timestamps as
   series index increases, positive finite closes, positive tick volumes, and
   a fresh completed endpoint before the decision bar.
6. Form exactly 252 log returns in each block with disjoint return and volume
   support; the blocks may share only close index 252.
7. Divide each absolute log return by its ending bar's tick volume, multiply
   by exactly 1,000,000, and average exactly 252 finite terms per block.
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
  nonpositive close or tick volume, wrong count, nonfinite ALIQ term, numerical
  tie, excessive spread, invalid quote, unavailable ATR, invalid stop, or
  invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read real volume, dollar volume, a futures chain, inventory
  release, file, API, analyst forecast, trained output, optimizer result, or
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
| `strategy_returns_per_block` | 252 | [252] | exact log-return/volume terms per block |
| `strategy_prior_block_offset` | 252 | [252] | preceding block's first return index |
| `strategy_history_bars_d1` | 505 | [505] | exact completed D1 rate count |
| `strategy_aliq_scale` | 1000000.0 | [1000000.0] | exact source scale factor |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-history freshness guard |
| `strategy_aliq_tolerance` | 1e-12 | [1e-12] | symmetric block-comparison tolerance |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

All values, return type, volume alignment, scale, block support, direction,
entry clock, risk, stop, hold, and no-retry policy are locked. Any change
requires a new card and pipeline.

## Author Claims

Qin, Cai, Zhu, and Webb define ALIQ as prior-year average absolute daily
return divided by dollar volume, form monthly high-minus-low commodity
portfolios, and report a positive broad-universe one-way relation. They do not
claim that a two-block ALIQ change predicts WTI, that quote-tick counts equal
dollar volume, that a continuous CFD reproduces collateralized futures, or
that this candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: cross-sectional-to-time-series
translation, tick volume instead of dollar volume, two-year warm-up, broker
activity-regime drift, sensitivity to isolated returns or quiet bars,
persistent outright WTI states, roll and financing effects, sibling Q08
failure, stop slippage, and correlation with XNG or risk assets can dominate
the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full post-
  warm-up year.
- Fail on wrong rate count/orientation, wrong block offset, overlapping return
  or volume support, simple instead of log returns, wrong volume alignment or
  scale, nonpositive volume acceptance, low-ALIQ-long direction, repeated
  attempt, hold beyond forty days, missing hard stop, invalid risk mode, or
  nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing formation, blocks, transform, scale,
  threshold, direction, stop, hold, spread, retry, or carrier.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | Tier-A peer-reviewed source with DOI, complete-read evidence, proxy caveat, and sibling Q08 failure disclosed. |
| R2 | PASS | Fixed two-block 252-term estimator, exact log-return/tick-volume alignment and scale, direction, attempt, stop, rollover, and stale exit. |
| R3 | PASS | Registered `XTIUSD.DWX` D1 closes and native tick volume; dollar-volume equivalence is not assumed. |
| R4 | PASS | Deterministic arithmetic only; no trained output, prohibited signal indicator, external feed, grid, or martingale. |

- [x] Dedup: no exact identity; two fuzzy neighbors were manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, exact completed rates, two disjoint
  log-return/tick-volume blocks, ALIQ comparison, spread/quote/ATR/stop checks,
  and one fixed-risk order.
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
| v1 | 2026-08-13 | initial WTI self-relative Amihud-illiquidity regime | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | APPROVED; R1-R4 PASS | `decisions/2026-08-13_qm5_20302_wti_aliq_regime_g0.md`; bounded source packet |
