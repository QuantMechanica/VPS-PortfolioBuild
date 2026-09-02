---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MVNRATIO-TREND-20260902_S01
variant_id: AI-CODEX-WTI-MVNRATIO-TREND-20260902_S01
source_id: AI-CODEX-WTI-MVNRATIO-TREND-20260902
ea_id: QM5_41310
slug: wti-mvnratio-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41310_wti-mvnratio-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41310_wti_monthly_von_neumann_ratio_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_von_neumann_ratio_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; John von Neumann; R. H. Kent; H. R. Bellinson; B. I. Hart; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "OpenAI Codex (2026), WTI monthly raw von Neumann ratio gated trend; NIST/SEMATECH Mean Successive Differences Test; von Neumann (1941), Annals of Mathematical Statistics 12(4), DOI 10.1214/aoms/1177731677; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: official_statistical_method
    citation: "NIST/SEMATECH Dataplot. Mean Successive Differences Test."
    location: https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/msdt.htm
    quality_tier: A
    role: raw_successive_difference_ratio_formula_null_mean_and_low_ratio_trend_interpretation
  - type: original_statistical_method_provenance
    citation: "von Neumann, J. (1941). Distribution of the Ratio of the Mean Square Successive Difference to the Variance. Annals of Mathematical Statistics 12(4), 367-395."
    location: DOI 10.1214/aoms/1177731677
    quality_tier: A
    role: original_method_provenance_only
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly raw von Neumann ratio gated trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902/source.md
    quality_tier: governed_source
    role: exact_conjunction_threshold_risk_attempt_and_lifecycle
strategy_mechanic: monthly-wti-twenty-completed-log-returns-raw-von-neumann-successive-difference-ratio-strictly-below-two-gated-newest-twelve-month-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/successive-difference-randomness]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/raw-von-neumann-ratio]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, raw-von-neumann-ratio, successive-differences, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 413100000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately six completed WTI positions per full post-warm-up year; one consumed attempt per broker month. A fixed-seed market-free null prior qualified 49.9715%. Q02 must prove at least five trades in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_SYNTHESIS_BOUNDARY
r1_reasoning: "Official complete NIST method page, original peer-reviewed statistical provenance, complete governed peer-reviewed WTI trading-paper read, and explicit disclosure that the exact conjunction is untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, 21 endpoints, 20 log returns, centering, raw successive-difference numerator, variance denominator, strict eta<2 boundary, newest-12m direction, consumed attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only completed prices, timestamps, logarithms, sums, products, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 21 consecutive completed month-end closes; 20 adjacent log returns; centered denominator floor 1e-18; raw von Neumann eta=D/V; strict eta<2.0; newest 12m direction epsilon 1e-12; 1000 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a direct-WTI monthly raw-path trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, exact mean/D/V arithmetic, denominator floor, strict eta=2 boundary, newest-12m side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_one_consecutive_completed_months, no_current_month_price, twenty_adjacent_log_returns, chronological_return_orientation, exact_sample_mean, squared_successive_difference_numerator, centered_sum_square_denominator, denominator_floor, strict_eta_two_boundary, newest_twelve_month_continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41310_wti_monthly_von_neumann_ratio_trend_g0.md: R1-R4 pass within disclosed synthesis and continuous-CFD risks. Corrected-root dedup returned CLEAN across 4,795 registry rows, 1,424 cards, and 45 wiki nodes; manual review separates the raw return-magnitude statistic from Bartels ranks, net/absolute path efficiency, q-horizon variance ratios, entropy, sign, regression, calendar, event, channel, and certified XNG RSI families."
---

# QM5_41310 WTI Monthly Raw von Neumann Ratio Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, geopolitical, and
demand risks absent from the certified XAU, SP500, NDX, and XNG carrier set.
When the latest twenty completed monthly WTI returns have low raw successive
variation relative to their total dispersion, the newest twelve-month return
direction may persist for one more broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, predictability, statistical significance, independence, or
decorrelation. Q02 owns cadence and baseline economics; unchanged Q09 alone
owns portfolio overlap.

## Source Traceability And Claim Boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MVNRATIO-TREND-20260902/source.md`,
SHA-256 `C30EAC1402E532BEB68AC95B408A7559A355710914AD3E46991821B508529797`,
approved at commit `fa3b33f98e` before this card.

NIST supplies the exact raw statistic and small-ratio trend interpretation;
von Neumann supplies original provenance; Moskowitz-Ooi-Pedersen supply the
WTI carrier and monthly own-return continuation lineage. None tests the exact
twenty-return conjunction, strict mean boundary, Darwinex CFD, fixed risk,
stop, attempt state, lifecycle, or portfolio.

## Non-Duplicate Decision

The deterministic receipt
`artifacts/qm5_wti_mvnratio_tr_preallocation_dedup_20260902.json` returned
`CLEAN`. The nearest existing EA, `QM5_41170_wti-bartels-rank-tr`, replaces
price magnitudes with thirteen ordinal ranks. This card retains twenty
monthly log-return magnitudes, centers them, and compares squared adjacent
changes with total dispersion. It is not invariant to monotone transforms or
outlier amplitude and therefore cannot collapse to the Bartels rule.

Net/absolute path efficiency, q-horizon variance ratios, ordinal entropy,
LZ76, sign-run/count/vote, regression, rank, location, scale,
distribution-shift, calendar, event, and channel systems use different state
objects. Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_20_RAW_RETURN_VON_NEUMANN_ETA_LT2_GATED_12M_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and slot 0: `XTIUSD.DWX`, D1.
- Decision clock: first executable tick after a genuine broker-month change,
  within 180 elapsed minutes of the host D1 boundary.
- Formation: twenty-one consecutive completed month-end closes; current-month
  prices are excluded.
- State: raw von Neumann ratio of twenty adjacent monthly log returns.
- Direction: cumulative log return of the newest twelve completed months.
- Hold: next broker month, with a forty-calendar-day stale repair.
- Expected cadence: approximately six completed positions/year. Q02 retires
  any full scored year below five.

## Exact Formula

For chronological completed-month closes `C[0..20]`:

```text
r[i]   = ln(C[i+1] / C[i]), i=0..19
mean   = sum(r[i], i=0..19) / 20
V      = sum((r[i] - mean)^2, i=0..19)
D      = sum((r[i+1] - r[i])^2, i=0..18)
eta    = D / V
mom12  = sum(r[i], i=8..19)

BUY  iff V > 1e-18 and eta < 2.0 and mom12 > 1e-12
SELL iff V > 1e-18 and eta < 2.0 and mom12 < -1e-12
FLAT otherwise
```

Require every close, return, mean, squared term, sum, ratio, and momentum to
be finite. Require `D>=0` and `eta>=0`. The `eta=2` boundary and inclusive
momentum tie stay flat. Ratio and momentum magnitude never scale risk.

## Rules

These are the complete authorized baseline. No alternate statistic, p-value,
critical table, normalization, rank transform, fallback momentum, parameter
sweep, or result-based repair is authorized.

## 4. Entry Rules

1. Require exact EA ID `41310`, `XTIUSD.DWX` D1, slot 0, magic `413100000`,
   seed 42, and every baseline input locked to its declared value.
2. Process lifecycle repair before entry gates. Evaluate only at a genuine
   broker-month transition within the 180-minute grace window.
3. Persist the normalized month key before history, signal, spread, quote,
   news, ATR, sizing, margin, or order checks. Never retry that month.
4. Reject owned exposure, foreign host-symbol exposure, or an existing
   same-month entry deal for the magic.
5. Reconstruct exactly twenty-one consecutive completed month-end closes from
   bounded D1 history. Require positive finite closes, strictly increasing
   endpoint times, newest endpoint before the decision bar and no more than
   ten days stale, and no current-month price.
6. Form exactly twenty chronological adjacent log returns and calculate the
   exact mean, `V`, nineteen-term `D`, and `eta`. Fail closed at `V<=1e-18`.
7. Consume flat unless `eta<2.0`. At qualification, sum exactly `r[8]..r[19]`;
   buy above `1e-12`, sell below `-1e-12`, and consume ties flat.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid metadata, fixed-risk sizing, and margin.
9. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
   hard stop and no take-profit.

## 5. Exit Rules

1. Close the prior position at the next genuine broker-month transition before
   considering replacement, even if the direction remains unchanged.
2. Close after forty elapsed calendar days as a stale guard.
3. Close duplicate, wrong-symbol, invalid-type, wrong-side, or missing-stop
   owned exposure.
4. Broker hard stop and framework kill switch remain authoritative.
5. Friday close is disabled because the authorized hold spans weekends.
6. No intramonth signal flip, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is allowed.

## 6. Filters (No-Trade Module)

- Fail closed outside exact identity, symbol, timeframe, slot, magic, seed,
  fixed-risk, news/Friday, stress, or locked strategy inputs.
- Fail closed on malformed month labels, late restart, nonconsecutive or stale
  endpoints, current-month leakage, invalid closes or returns, nonfinite mean
  or sums, small denominator, invalid ratio, boundary failure, neutral
  momentum, prior attempt/deal, owned or foreign exposure, excessive spread,
  invalid quote, unavailable ATR, invalid stop, or invalid metadata.
- Both news axes and legacy news are locked OFF. Lifecycle repair and monthly
  close execute before entry-only gates.
- Runtime may not read a futures curve, inventory, volume, open interest,
  file, API, forecast, optimizer, prior PnL, portfolio state, or trained
  artifact.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before renewal or after forty days.
- Restart recovery combines a persistent month marker with owned position and
  deal history; tester initialization removes only a future marker from
  another run so historical tests remain deterministic.
- Recompute the expected current-month direction from the identical completed
  endpoints and formula when validating a recovered position. Close mismatch.
- No randomness, adaptation, external state, partial close, scale-in, grid,
  martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_month_returns` | 20 | [20] | raw monthly return sample |
| `strategy_eta_boundary` | 2.0 | [2.0] | strict raw ratio gate |
| `strategy_variance_floor` | 1e-18 | [1e-18] | centered denominator floor |
| `strategy_momentum_months` | 12 | [12] | newest continuation slice |
| `strategy_direction_epsilon` | 1e-12 | [1e-12] | neutral momentum band |
| `strategy_history_bars_d1` | 1000 | [1000] | bounded endpoint scan |
| `strategy_entry_grace_minutes` | 180 | [180] | month-entry window |
| `strategy_endpoint_stale_days` | 10 | [10] | endpoint freshness |
| `strategy_atr_period_d1` | 20 | [20] | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale repair ceiling |
| `strategy_max_spread_points` | 1500 | [1500] | entry cost ceiling |

All values, arithmetic, orientation, strict boundaries, direction, entry
clock, risk, stop, hold, and no-retry policy are locked.

## Author Claims

NIST defines the raw statistic and identifies small values with trend;
von Neumann supplies provenance; Moskowitz-Ooi-Pedersen document monthly
own-return continuation and include WTI. None claims this conjunction predicts
WTI, transfers to a continuous CFD, clears costs, trades often enough, or
diversifies this book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, continuous-CFD roll/basis and
financing, single-carrier concentration, raw-magnitude outlier sensitivity,
short-sample noise, stop slippage, month-label errors, and correlation with
XNG or risk assets can dominate the premise. A low ratio does not establish
stationarity, prediction, independence, or profitability.

## Kill Criteria

- Retire at zero positions or fewer than five completed positions in any full
  scored post-warm-up year.
- Fail on wrong endpoint count/order, nonconsecutive months, current-month
  leakage, reversed returns, wrong mean/D/V arithmetic, denominator-floor or
  strict-boundary error, wrong momentum slice/side, repeated attempt, missing
  hard stop, hold beyond forty days, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later correlation rejection.
- Do not rescue failure by changing the sample, statistic, boundary,
  direction, carrier, stop, hold, spread, or retry policy.

## Strategy Allowability Check

- [x] R1: official exact method, original provenance, complete governed WTI
  trading-paper read, and explicit synthesis boundary.
- [x] R2: fixed endpoints, raw returns, mean, numerator, denominator,
  threshold, direction, attempt, hard stop, renewal, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: deterministic closed-form arithmetic and framework state; no
  trained output or external runtime feed.
- [x] Dedup: deterministic CLEAN plus semantic separation from rank, path,
  variance-ratio, entropy, sign, regression, calendar, event, and channel
  neighbors.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot/magic/seed, locked inputs, fixed risk,
  news/Friday/stress contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, raw return
  and exact eta arithmetic, strict gate, momentum side, spread/quote/ATR/stop
  checks, and one fixed-risk order.
- trade_management: malformed-state repair, recovered-direction validation,
  prior-month exit, and forty-day stale exit before entry gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, reference fixtures, and one non-live paced Q02 handoff. It does
not authorize manual backtests; live/demo/shadow/stress/optimization setfiles;
terminal control; AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio
admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-02 | initial raw von Neumann WTI trend card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41310_wti_monthly_von_neumann_ratio_trend_g0.md` |
| Q01 Build Validation | - | NOT_BUILT | - |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | - |
