---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03
variant_id: SCHWEIKERT-CME-XAUXAG-QTAILRV-2026_S03
source_id: SCHWEIKERT-CME-XAUXAG-QTAIL-2026
ea_id: QM5_20268
slug: xauxag-qtail-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20268_xauxag-qtail-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-09
created_by: Research+Development
last_updated: 2026-08-09
g0_status: APPROVED
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_gold_silver_relationship
  - type: peer_reviewed_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI https://doi.org/10.1016/j.resourpol.2021.102045; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supplemental_robust_long_run_relation
  - type: exchange_education
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: intermarket_relative_value_carrier
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-frozen-126-empirical-decile-central-to-two-tail-reversion-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-QTAIL-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/empirical-quantile]]"
  - "[[concepts/structural-mean-reversion]]"
indicators:
  - "[[indicators/empirical-quantile]]"
  - "[[indicators/rolling-median]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, structural-mean-reversion, empirical-quantile, paired-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20268_XAU_XAG_QTAILRV_D1
symbol: QM5_20268_XAU_XAG_QTAILRV_D1
host_symbol: XAUUSD.DWX
symbol_slots:
  XAUUSD.DWX: 0
  XAGUSD.DWX: 1
magics:
  XAUUSD.DWX: 202680000
  XAGUSD.DWX: 202680001
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-12 completed XAU/XAG packages/year after 129 synchronized D1 observations; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_STARTED
q02_status: NOT_ENQUEUED
review_focus: "Falsify a distribution-free two-hit gold/silver relative-value excursion whose paired returns may diversify the directional XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [synchronized_completed_bars, frozen_reference_window, exact_order_statistics, ordered_two_hit_event, one_logical_basket, aggregate_fixed_risk, orphan_repair, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-09_qm5_20268_xauxag_qtail_rv_g0.md: R1 two peer-reviewed DOI records plus a governed CME exchange carrier; R2 locked synchronized ratios, frozen 126-value empirical distribution, exact nearest-rank deciles, separate central-plus-two-tail event, inverse sides, aggregate fixed risk, ATR stops, rolling-median and stale exits; R3 registered XAUUSD.DWX and XAGUSD.DWX D1; R4 deterministic native sorting/arithmetic only. The checker covered 4,325 registry rows and 441 cards with no exact or fuzzy identity, and manual review distinguished z-score, OLS, conditional-quantile regression, MAD, breakout, and failed-break systems. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20268 XAU/XAG Empirical-Quantile Tail Reversion

## Hypothesis

Gold and silver share monetary and precious-metals drivers but have different
industrial sensitivity. A synchronized gold/silver log-ratio excursion that
persists beyond a reference distribution's outer decile for two completed D1
sessions may converge. Using fixed empirical order statistics avoids assuming
a Gaussian ratio, estimating a volatility scale, or fitting a hedge ratio.

The package is designed as relative-value exposure, but opposite legs and
equal stop-risk do not establish market neutrality or low correlation. Q02
owns density and economics; unchanged downstream gates, especially Q09, own
robustness and realized overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-QTAIL-2026/source.md`. Its
parents are complete governed packets for two peer-reviewed gold/silver
relationship papers and CME Group's ratio-spread material.

Those sources support only a potentially state-dependent long-run relation and
an intermarket relative-value carrier. They do not use this empirical-decile
event, specify its parameters, test Darwinex CFDs, or report its performance.
All sample shifts, indexes, sides, sizing, stops, spread caps, attempt state,
and exits below are transparent QM mechanizations. No source efficacy,
density, neutrality, CFD equivalence, or portfolio statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker returned `CLEAN` across 4,325 EA
registry rows and 441 cards for the exact slug, strategy identity, and
declared mechanic. Manual review resolved the expected family neighbors:

- `QM5_12577` and `QM5_20157` use rolling mean/standard-deviation ratio scores.
- `QM5_20161` uses a rolling OLS log-price residual and fitted beta.
- `QM5_13205` solves three conditional-quantile regressions monthly and trades
  a weekly conditional envelope with beta-target notional sizing.
- `QM5_20263` uses separate rolling median/MAD robust scores and a fresh score
  threshold cross.
- `QM5_12724` follows a ratio-channel breakout.
- `QM5_20265` requires one outside channel break followed by a separate return
  strictly inside the frozen range.

This candidate has no mean, standard deviation, MAD scale, OLS beta,
conditional regression, channel maximum, breakout continuation, or re-entry
event. The 126-value frozen empirical distribution, exact nearest-rank
deciles, three bars excluded from estimation, central-to-two-tail sequence,
immediate inverse package, and 21-ratio median exit are jointly load-bearing.
Verdict: `CLEAN_DISTRIBUTION_FREE_TWO_HIT_TAIL_EVENT`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20268_XAU_XAG_QTAILRV_D1`.
- Host: `XAUUSD.DWX`, D1, slot 0, intended magic `202680000`.
- Second leg: `XAGUSD.DWX`, slot 1, intended magic `202680001`.
- Decision clock: once on each new host D1 bar using completed bars only.
- Formation: 126 synchronized pre-event ratios plus three separate event bars.
- Expected cadence: five to twelve completed packages per full post-warm-up
  year; retire below five.
- Q02 window: `2018.07.02` through `2024.12.31`, bounded to synchronized XAG
  history.

## Formula

Let `r[k] = ln(XAU_close[k]) - ln(XAG_close[k])` for exactly aligned completed
D1 shifts, with `k=1` newest. Sort only `r[4]..r[129]` ascending into `s[0]..
s[125]` and define:

```text
q10 = s[12]                       # ceil(0.10 * 126), nearest rank
q50 = (s[62] + s[63]) / 2        # even-sample median
q90 = s[113]                      # ceil(0.90 * 126), nearest rank
```

Require `q10 < q50 < q90`. The event is:

```text
upper = q10 <= r[3] <= q90 and r[2] > q90 and r[1] > q90
lower = q10 <= r[3] <= q90 and r[2] < q10 and r[1] < q10
```

The two tails are mutually exclusive. Equality at `r[2]` or `r[1]` is flat.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to a standardized score, residual model, channel, oscillator,
calendar rule, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20268`, host `XAUUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Run lifecycle repair and exits before entry-only gates. Evaluate entry only
   once per new completed host D1 bar.
3. Reject an owned position or any same-decision-bar entry deal. Consume the
   decision bar before spread, quote, ATR, sizing, news, or order checks; no
   retry is allowed for that event.
4. Load exactly 129 completed D1 bars from both legs. Require identical
   timestamps at every shift, positive finite closes, and finite log ratios.
5. Sort only shifts 4..129, calculate exact `q10`, `q50`, and `q90`, and require
   strict ordered boundaries.
6. Require shift 3 within the inclusive decile band and shifts 2 and 1 both
   strictly beyond the same boundary.
7. For an upper event, SELL XAU and BUY XAG. For a lower event, BUY XAU and
   SELL XAG. Maintain exactly zero or two opposite legs.
8. Require each leg's spread cap, executable quote, completed `ATR(20,D1)`,
   valid point/digit/volume metadata, and valid fixed-risk sizing.
9. Split one aggregate fixed-cash stop-risk budget equally between legs after
   independent `3.5*ATR(20,D1)` stop normalization. No take-profit.

## 5. Exit Rules

1. On each new host D1 bar, align the newest twenty-one completed ratios and
   calculate their exact median at sorted index 10.
2. Close an upper-event package (short XAU/long XAG) when the newest completed
   ratio is at or below that median.
3. Close a lower-event package (long XAU/short XAG) when the newest completed
   ratio is at or above that median.
4. Close both legs immediately on orphan, duplicate, same-side, wrong-side,
   stopless, or invalid synchronized-state composition.
5. Close after thirty-five elapsed calendar days. Broker hard stops and the
   framework kill switch remain authoritative.
6. Friday close is disabled. No intraday signal flip, profit target, trail,
   break-even, partial close, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject owned exposure, consumed attempt, timestamp mismatch, insufficient
  history, nonpositive/nonfinite price, invalid ratio, unordered quantiles,
  malformed event, excessive spread, invalid quote, unavailable ATR, invalid
  stop, or invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  and exits run before entry-only gates.
- Runtime may not read futures curves, inventory, volume, open interest, files,
  APIs, analyst forecasts, trained outputs, or portfolio results.

## 7. Trade Management Rules

- Maintain at most one logical package and exactly one position per registered
  leg magic.
- Preserve original hard stops; close on median convergence, invalid package,
  invalid synchronized state, or thirty-five-day timeout.
- Restart recovery combines a terminal-persistent attempted-bar marker with
  owned positions and deal history. A marker from a future tester time is
  cleared so historical replay remains deterministic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| param | default | authorized values | role |
|---|---:|---|---|
| `strategy_reference_bars_d1` | 126 | [126] | frozen pre-event ratios |
| `strategy_lower_index` | 12 | [12] | zero-based nearest-rank tenth percentile |
| `strategy_upper_index` | 113 | [113] | zero-based nearest-rank ninetieth percentile |
| `strategy_exit_median_bars_d1` | 21 | [21] | rolling convergence center |
| `strategy_quantile_epsilon` | 0.000000000001 | [0.000000000001] | strict boundary-width floor |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | paired-order deviation |

Every value, shift, comparison, side, attempt, risk allocation, and lifecycle
rule is locked. Any change requires a new card and full pipeline run.

## Author Claims

The cited authors support investigating a state-dependent gold/silver
relationship; CME documents a tradable ratio-spread carrier. They do not
claim that this two-hit empirical-tail rule works, that its parameters are
optimal, that spot CFDs reproduce futures, or that the package diversifies the
QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Each leg receives half the
cash stop-risk after its independent ATR normalization. Risk is high: XAG
gaps, unequal metal beta, CFD roll/basis and financing, legging, synchronized-
history gaps, persistent structural breaks, minimum-lot rounding, and hard-
stop slippage can dominate the premise. Opposite legs are not proof of market
neutrality.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full
  post-warm-up year.
- Fail on reference/event overlap, timestamp mismatch, wrong quantile indexes,
  one-tail-hit entry, wrong-side entry, repeated event attempt, unpaired or
  stopless exposure, aggregate-risk breach, hold beyond thirty-five days,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the lookback, index, event length,
  direction, median window, stop, hold, spread cap, retry rule, or carrier.

## Strategy Allowability Check

- [x] R1: PASS. Two named-author peer-reviewed DOI records and a governed CME
  exchange packet support the bounded carrier.
- [x] R2: PASS. Exact shifts, indexes, event, direction, attempt, aggregate
  risk, hard stops, median exit, and stale exit are deterministic.
- [x] R3: PASS with disclosed basis risk. Registered XAU/XAG D1 histories and
  native V5 execution state supply every runtime input.
- [x] R4: PASS. Deterministic logarithm, sorting, comparison, arithmetic, ATR,
  and calendar operations only; no trained model, external feed, grid,
  martingale, scale-in, or pyramiding.
- [x] Dedup: no exact empirical-decile central-to-two-tail XAU/XAG identity;
  all close family neighbors manually resolved.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: consumed-bar persistence, synchronized ratio loading, frozen
  order statistics, ordered tail event, spread/quote/ATR/stop checks, and one
  aggregate-risk opposite-leg package.
- trade_management: composition repair, synchronized rolling-median
  convergence, invalid-state exit, and thirty-five-day stale exit.
- trade_close: framework package-close helper, per-leg broker hard stops, and
  kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a
manual backtest; live, demo, shadow, optimization, or stress setfile;
AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio admission;
portfolio-gate edit; correlation waiver; or neutrality claim.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-09 | initial source-bounded empirical-tail ratio card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-09 | APPROVED | `decisions/2026-08-09_qm5_20268_xauxag_qtail_rv_g0.md` |
| Q01 Build Validation | — | NOT_STARTED | — |
| Q02 Baseline Screening | — | NOT_ENQUEUED | — |
