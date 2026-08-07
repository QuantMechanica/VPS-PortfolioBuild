---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MADRV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MADRV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MAD-2026
ea_id: QM5_20263
slug: xauxag-mad-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20263_xauxag-mad-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI https://doi.org/10.1016/j.jbankfin.2017.11.010; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: primary_long_run_relation
  - type: peer_reviewed_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI https://doi.org/10.1016/j.resourpol.2021.102045; governed review strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supplemental_robust_relation
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade; governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: B
    role: primary_relative_value_carrier
strategy_mechanic: synchronized-d1-gold-silver-log-ratio-median-mad-robust-score-fresh-cross-reversion-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MAD-2026]]"
  - "[[sources/SCHWEIKERT-XAUXAG-RATIO-2026]]"
  - "[[sources/CME-GSR-SPREAD-2025]]"
concepts: [precious-metals-relative-value, robust-location-scale, market-neutral-basket, mean-reversion]
indicators: [log-price-ratio, rolling-median, median-absolute-deviation, atr]
strategy_type_flags: [commodity, precious-metals, relative-value, market-neutral-basket, robust-mean-reversion, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20263_XAU_XAG_MADRV_D1
symbol: QM5_20263_XAU_XAG_MADRV_D1
symbol_slot: 0
magic: 202630000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated five to twelve completed XAU/XAG packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
review_focus: "Falsify a robust opposite-leg gold/silver convergence stream whose median/MAD state, excursion clock, and package returns differ from outright XAU, SP500, NDX, and XNG book drivers; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, ratio_orientation, robust_statistic, aggregate_fixed_risk, restart_attempt_state, friday_close_exception, magic_schema, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20263_xauxag_mad_rv_g0.md: R1 two peer-reviewed DOI records plus a CME exchange carrier in complete durable packets; R2 locked synchronized ratios, 63-value median/MAD windows, fixed normal-consistency score, fresh threshold cross, opposite legs, aggregate fixed risk, ATR stops, convergence and stale exits; R3 registered XAUUSD.DWX and XAGUSD.DWX D1; R4 deterministic native sorting/arithmetic only. Pre-allocation review covered 4,320 registry rows and 840 card files with no exact or median/MAD mechanic collision; closest ratio, OLS, quantile, and variance-ratio systems were manually distinguished. No source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20263 XAU/XAG Robust Ratio Reversion

## Hypothesis

Gold and silver share precious-metals exposure but differ in monetary,
safe-haven, industrial, and business-cycle sensitivity. Their relative price
can therefore dislocate and later converge. A median/MAD score tests those
dislocations without allowing one large observation to pull both the rolling
center and scale as strongly as an arithmetic mean and standard deviation.

The opposite-leg package seeks relative-value exposure and suppresses part of
the common metal direction. It is not a claim of dollar, beta, volatility,
factor, market, or portfolio neutrality. Q02 owns density and economics;
unchanged downstream gates and Q09 own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MAD-2026/source.md`. Its two
peer-reviewed lineages support a potentially time-varying gold/silver
long-run relationship. CME supplies the gold/silver ratio definition and
intermarket-spread carrier.

None specifies rolling median/MAD, 63 bars, score scaling, thresholds, a
crossing rule, Darwinex CFDs, fixed-cash sizing, ATR stops, or lifecycle
controls. Those are transparent QM hypotheses. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, CFD equivalence, neutrality, or
portfolio correlation is imported.

## Non-Duplicate Decision

The pre-allocation review covered 4,320 EA-registry rows and all 840 card
files. It found no exact identity or gold/silver median/MAD mechanic. The
closest systems are materially different:

- `QM5_12577_cme-xauxag-ratio` and `QM5_20157_xau-xag-ratio` use an arithmetic
  mean and standard deviation on a fixed log ratio;
- `QM5_20161_xauxag-ols-rv` estimates a rolling OLS hedge ratio and trades
  standardized residuals;
- `QM5_13205_xau-xag-qc` uses quantile-cointegration state;
- `QM5_20254_xauxag-vr-fade` adds a monthly anti-persistence gate to a
  conventional ratio z-score; and
- `QM5_20249_xauxag-vr-spread` trades monthly relative-return memory.

The rolling median, rolling MAD, fixed normal-consistency scaling, separate
current/prior windows, fresh-cross entry, and no re-entry inside the same
excursion are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_FAMILY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: `XAUUSD.DWX` D1, slot 0, intended magic `202630000`.
- Second leg: `XAGUSD.DWX`, slot 1, intended magic `202630001`.
- Logical symbol: `QM5_20263_XAU_XAG_MADRV_D1`.
- Formation: 64 synchronized completed D1 bars, producing independent current
  and prior 63-value robust-score windows.
- Expected cadence: five to twelve completed packages per full post-warm-up
  year; retire below five.
- Runtime data: Darwinex-native D1 time/close, ATR, spread, quote, position,
  deal, and contract metadata only.

## Formula

For each 63-value window of completed ratios `r_i`:

```text
r_i      = ln(XAU_close_i) - ln(XAG_close_i)
median   = middle(sorted(r_0..r_62))
MAD      = middle(sorted(abs(r_i - median), i=0..62))
robust_z = 0.6744897501960817 * (latest_ratio - median) / MAD
```

The current score uses shifts 1-63 and the prior score shifts 2-64. Each
window computes its own median and MAD. Require exact timestamp alignment,
positive finite closes, finite arithmetic, and `MAD > 1e-12`.

## Rules

These are the complete authorized baseline. There is no parameter sweep and
no fallback to mean/standard deviation, OLS, a moving average, oscillator,
calendar direction, external series, or previous pipeline result.

## 4. Entry Rules

1. Require EA ID 20263, exact XAU D1 host, slot 0, registered XAU/XAG legs,
   fixed risk/news/Friday contract, and every baseline input locked.
2. Evaluate only once per new host D1 bar after lifecycle repair and exits.
3. Align exactly 64 completed XAU and XAG D1 timestamps and compute the two
   robust scores exactly as specified.
4. Reject any owned leg, invalid alignment/state, or already consumed D1
   attempt.
5. A current score crossing above `+2.0` from a prior score at or below `+2.0`
   opens SELL XAU / BUY XAG.
6. A current score crossing below `-2.0` from a prior score at or above `-2.0`
   opens BUY XAU / SELL XAG.
7. Consume the D1 attempt before spread, quote, ATR, sizing, or order checks;
   no restart retry is allowed on that crossing bar.
8. Require XAU spread no greater than 1,500 points and XAG spread no greater
   than 3,000 points, executable quotes, completed ATR, and valid volume data.
9. Split one aggregate fixed-cash risk budget equally between legs after each
   leg's own frozen `3.5*ATR(20,D1)` stop distance. Open both legs or close any
   orphan immediately. No take-profit is used.

## 5. Exit Rules

1. On each new D1 bar, close both legs when `abs(current_robust_z) <= 0.5`.
2. Close both legs on an invalid synchronized score, missing/orphan leg,
   duplicate leg, wrong opposite-side composition, or missing hard stop.
3. Close after 45 elapsed calendar days.
4. Per-leg broker hard stops and the framework kill switch remain binding.
5. Friday close is disabled to preserve the multi-day relative convergence
   path. No signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, slot, risk/news/Friday
  contract, or locked strategy inputs.
- Reject stale, missing, unsynchronized, nonpositive, nonfinite, or degenerate
  ratio state; an owned package; a non-crossing extreme; a consumed bar;
  excessive spread; invalid quote/ATR/stop/volume; or failed basket atomicity.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle repair
  and exits run before entry-only filters.
- Runtime may not read a futures chain, volume, inventory, file, API, analyst
  forecast, trained output, or portfolio result.

## 7. Trade Management Rules

- Maintain exactly zero or two owned legs with opposite sides and valid hard
  stops. Any other composition is closed immediately.
- Maintain at most one attempt per completed D1 crossing bar. The threshold
  crossing prevents re-entry during the same excursion after a later stop.
- Recover entry time from live position state after restart.
- No randomness, adaptive PnL fit, external state, partial close, scale-in,
  grid, martingale, or pyramiding.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_ratio_window_d1` | 63 | [63] | odd rolling robust window |
| `strategy_mad_scale` | 0.6744897501960817 | [0.6744897501960817] | normal-consistency scaling |
| `strategy_entry_robust_z` | 2.0 | [2.0] | fresh-cross entry band |
| `strategy_exit_robust_z` | 0.5 | [0.5] | convergence band |
| `strategy_mad_epsilon` | 1e-12 | [1e-12] | degenerate-scale boundary |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard stop |
| `strategy_max_hold_days` | 45 | [45] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |

Changing any window, statistic, constant, band, direction, risk split, stop,
hold, spread cap, retry rule, or carrier requires a new card and full pipeline.

## Author Claims

The sources support testing a state-dependent gold/silver relative-price
relationship and identify the ratio as an intermarket spread. They do not
claim that this robust score works, that the locked parameters are optimal,
that two CFDs reproduce a futures spread, or that the package diversifies the
QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the aggregate package. Risk is high: XAU/XAG basis,
spread and financing asymmetry, legging, gap risk, stop mismatch, persistent
structural ratio breaks, MAD collapse, sparse crossings, and residual common
metal or risk-asset beta can dominate the premise. Opposite legs do not prove
neutrality.

## Kill Criteria

- Retire on zero packages or fewer than five completed packages per full
  post-warm-up year.
- Fail on timestamp mismatch, wrong log-ratio orientation, wrong median/MAD or
  window, entry without a fresh crossing, repeated excursion entry, wrong
  sides, orphan exposure, aggregate fixed-risk breach, missing hard stop,
  hold beyond 45 days, invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the statistic, window, threshold, side,
  stop, hold, spread cap, retry contract, or carrier.

## Strategy Allowability Check

- [x] R1: two peer-reviewed DOI records and one CME exchange carrier packet.
- [x] R2: fixed alignment, formula, crossing, sides, risk, stops, and exits.
- [x] R3: registered XAU/XAG D1 and native V5 execution state only.
- [x] R4: deterministic sorting and arithmetic; no trained model, banned
  signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact or median/MAD identity; closest families manually
  resolved.

## Framework Alignment

- no_trade: exact host/slot, locked inputs, fixed risk/news/Friday contract,
  and cheap parameter guards.
- trade_entry: synchronized ratio load, current/prior median/MAD scores,
  fresh-cross gate, persisted bar attempt, spread/quote/ATR/volume checks, and
  atomic two-leg fixed-risk open.
- trade_management: atomicity/stop repair, robust convergence, invalid-state
  close, and 45-day stale exit.
- trade_close: basket close helper, per-leg broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate edit;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial robust XAU/XAG ratio-reversion card | G0 | APPROVED |
| v1-q01 | 2026-08-07 | deterministic V5 basket build and strict compile; paced Q02 handoff stopped at the binding 9-of-7 factory-terminal ceiling | Q01 | PASS; Q02 NOT_ENQUEUED_CPU_CEILING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20263_xauxag_mad_rv_g0.md` |
| Q01 Build Validation | 2026-08-07 | PASS | compile `D:/QM/reports/compile/20260807_100807/summary.csv`; build check `D:/QM/reports/framework/21/build_check_20260807_100806.json` |
| Q02 Baseline Screening | 2026-08-07 | NOT_ENQUEUED_CPU_CEILING | `docs/ops/evidence/2026-08-07_qm5_20263_xauxag_mad_rv_q01_cpu_stop.md` |
