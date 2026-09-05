---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905
ea_id: QM5_41351
slug: wti-adf-bds-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41351_wti-adf-bds-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41351_wti_monthly_adf_bds_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_bds_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; William A. Broock; Jose A. Scheinkman; W. Davis Dechert; Blake LeBaron; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Chan (2013), Algorithmic Trading, Wiley; Broock et al. (1996), Econometric Reviews 15(3), DOI 10.1080/07474939608800353; statsmodels pinned implementation 2d1115db; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF-BDS agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: approved_adf_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_constant_no_time_trend_adf_arithmetic_and_boundary_orientation
  - type: peer_reviewed_diagnostic_source
    citation: "Broock, W. A., Scheinkman, J. A., Dechert, W. D., and LeBaron, B. (1996). A Test for Independence Based on the Correlation Dimension. Econometric Reviews 15(3), 197-235."
    location: strategy-seeds/sources/BROOCK-STATSMODELS-MOP-WTI-BDS2-20260902/source.md
    quality_tier: A
    role: embedding_two_bds_arithmetic_and_interpretation
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-one-completed-log-price-levels-newest-sixty-level-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-forty-eight-log-returns-embedding-two-absolute-bds-at-least0p6744897501960817-agreement-gated-twelve-month-return-sign-continuation
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-diagnostic-agreement, augmented-dickey-fuller, bds, nonlinear-dependence, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413510000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately three to six completed positions per full post-warm-up year is an uncalibrated conjunction prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Complete approved ADF and BDS records plus a complete peer-reviewed WTI continuation record provide exact hashes, adverse interpretation limits, and explicit non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty-one endpoints, both locked arithmetic paths, inclusive thresholds, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, bounded pair comparisons and sums, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 61 completed month-end closes; ADF on newest 60 log levels, 58 rows, lag one, intercept, residual dof 55, inclusive t>=-2.594; BDS on newest 48 returns, sample ddof one, epsilon=1.5*sd, strict distance, embedding dimension two, inclusive abs statistic>=0.6744897501960817; 12-month direction; 1800 D1 bars; 180-minute grace; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: SOURCE_BUILT_COMPILE_PENDING
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify direct-WTI monthly ADF/BDS agreement outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, strict BDS pair geometry, inclusive gates, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_one_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, inclusive_adf_boundary, newest_forty_eight_returns, sample_ddof_one, strict_bds_distance, full_and_conditioned_correlation_sums, embedding_two_bds_variance, inclusive_absolute_bds_boundary, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-05 and G0 decision approve R1-R4 within disclosed source-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity; manual review separates BDS delay-vector geometry from every other ADF agreement gate."
---

# QM5_41351 WTI Monthly ADF and BDS Agreement Trend

## Hypothesis

WTI supplies direct physical-energy exposure outside the certified carrier
set. The hypothesis is that the newest twelve-month WTI direction is suitable
for one broker month only when lag-one ADF does not show strong error
correction and BDS detects sufficient departure from i.i.d. structure in the
newest forty-eight monthly returns. Agreement does not prove persistence,
profit, nonlinear causation, or decorrelation.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905/source.md`.
Its complete reputable parents define ADF, BDS, and WTI continuation
separately. The corrected-root scan found no exact identity across 4,831
registry rows, 1,444 cards, and 45 Wiki nodes. Existing siblings use KPSS,
spectral entropy, von Neumann, LZ76, sample entropy, or Ljung-Box. BDS strict
delay-vector pair geometry is load-bearing. Parent-only EAs omit one required
gate. Shared WTI direction remains a correlation risk for Q09.

## Source-Defined Rules

- Chan supplies the lag-one intercept-only ADF arithmetic and the orientation
  that a sufficiently negative statistic indicates stronger error correction.
- Broock et al. and the pinned statsmodels implementation supply the
  dimension-two BDS correlation-integral geometry for detecting departures
  from i.i.d. structure.
- Moskowitz, Ooi, and Pedersen supply the instrument-own completed
  twelve-month return direction and explicitly include crude-oil futures.
- No parent source defines this conjunction, its numeric acceptance gates, a
  continuous CFD carrier, ATR stop, spread ceiling, or QM risk lifecycle.

## QM Interpretations

- `XTIUSD.DWX` is a registered continuous-CFD test carrier, not a matched WTI
  futures contract; roll, basis, and financing differences are unresolved
  empirical risks.
- Requiring both diagnostics is a pre-result sparsity hypothesis. ADF or BDS
  alone is deliberately insufficient and disagreement must stay flat.
- The locked inclusive cutoffs, 61-endpoint alignment, one-month package,
  `ATR(20)*3.5` stop, 1,500-point spread cap, and consumed-month state are QM
  implementation choices rather than claims from the parent sources.

## Exact Formula

For chronological log month-end closes `x[0..60]`, fit the locked lag-one
intercept ADF on `x[1..60]` and require `adf_t>=-2.594`. On newest returns
`r[i]=x[13+i]-x[12+i]`, `i=0..47`, compute the dimension-two BDS statistic
using sample `ddof=1`, `epsilon=1.5*sd`, strict pair distances, full and
conditioned correlation sums, and `variance2=4*(k-C1^2)^2`.

```text
mom12=x[60]-x[48]
BUY  iff adf_t>=-2.594 and abs(BDS2)>=0.6744897501960817 and mom12>+1e-12
SELL iff adf_t>=-2.594 and abs(BDS2)>=0.6744897501960817 and mom12<-1e-12
FLAT otherwise
```

## Rules

Use only sixty-one consecutive completed broker-month endpoints and exclude
the current month. Both diagnostic gates must qualify; only twelve-month
return sign chooses side. Consume the month before every fallible gate.
Permit zero or one owned WTI position, attach one frozen hard stop, and never
retry, resize, scale in, pyramid, grid, or martingale.

## 4. Entry Rules

Require exact identity, WTI D1 host, slot/magic, locked inputs, and fixed risk.
Repair malformed exposure first. On a genuine new month within 180 minutes,
persist the attempt, reconstruct endpoints, apply both formulas, then require
spread `[0,1500]`, quotes, completed ATR(20), sizing, and margin. Open at most
one position with a frozen `3.5*ATR` stop and no target.

## 5. Exit Rules

Framework kill switch and broker stop remain authoritative. Close on the first
later-month tick or after 40 days. There is no intramonth diagnostic exit,
target, trail, break-even, partial close, retry, or Friday flatten.

## 6. Filters (No-Trade Module)

Require the exact WTI carrier, D1 host, slot/magic, locked inputs, fixed-risk
contract, first-tradable-day timing, complete fresh endpoints, both inclusive
diagnostic gates, nonzero twelve-month direction, valid quotes and ATR, and
spread in `[0,1500]`. Persist the monthly attempt before fallible filters.

## 7. Trade Management Rules

Permit only zero or one owned WTI position. Immediately close duplicates,
wrong-symbol, wrong-side, or stopless owned positions. A valid position keeps
its frozen initial stop until the next-month or 40-day close; signal magnitude
never resizes it.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, small-sample diagnostic
size, overlapping windows, shared trend direction, and stop slippage are
material. Signal magnitude never changes size. No live risk is authorized.

## Data Requirements And Framework Alignment

Native `XTIUSD.DWX` D1 prices/times and ATR, broker state, quotes, metadata,
margin, positions/deals, and terminal globals only. No external runtime data.
No-trade helpers own identity, attempts, samples, formulas, and repair; entry
owns conjunction, spread, stop, size, and order; management owns restart and
monthly/stale exits; close maps framework reasons.

## Framework Execution Overrides

- News temporal mode OFF, compliance NONE, and legacy news mode OFF.
- Friday close disabled; the approved position may span Fridays within its
  entry broker month.
- Framework kill switch and the frozen server-side hard stop are authoritative.
- No forced session flatten, external signal, or discretionary override.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. Immediate malformed-exposure repair for duplicates, foreign carrier,
   wrong side, or missing stop.
3. First tick whose normalized broker month differs from the entry month.
4. Forty-calendar-day stale close.
5. No target, trail, break-even, partial, diagnostic, or Friday exit.

## Runtime Data Dependencies

- Exact host and signal route: registered `XTIUSD.DWX`, D1.
- Completed D1 closes and timestamps for 61 broker-month endpoints; completed
  D1 ATR; executable quote, spread, symbol metadata, margin, positions, deals,
  broker calendar, and terminal-persistent attempt state.
- No futures curve, inventory, volume, open interest, news calendar, API, CSV,
  cross-symbol history, wall-clock event feed, or trained output.

## Validation And Kill Criteria

Reference-test both formula paths, inclusive boundaries, disagreement cases,
month rollover, card mirror, registry, and fixed-risk set. Run schema lint,
strict Q01, and enqueue exactly one paced Q02 only under CPU admission. Retire
on zero trades, below five per full scored post-warm-up year, nonpositive
economics, formula/fixture mismatch, leakage, invalid risk, missing stop,
nondeterminism, lifecycle deviation, or any downstream hard failure. No
post-result tuning is authorized.

## Falsification And Requalification

Any change to the carrier, timeframe, endpoint alignment, ADF regression,
BDS pair geometry, either threshold, twelve-month direction, month boundary,
attempt persistence, stop, stale limit, spread cap, or risk mode requires a
new binary and full pipeline requalification. Incomplete or ambiguous history
and state fail closed. Q02 must retire the baseline on zero trades or fewer
than five completed positions in any full scored post-warm-up year; later
gates must reject it if economics or portfolio diversification fail.

## Safety Boundary

Authorized: branch-only non-live build, reference tests, strict Q01, one
fixed-risk backtest set, and one paced Q02 enqueue. Forbidden: manual
backtests, optimization, live/demo/shadow/stress sets, portfolio-gate edits,
correlation waivers, portfolio admission, deploy/live manifests, `T_Live`,
AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_wti_monthly_adf_bds_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41351_wti_monthly_adf_bds_agreement_trend_g0.md` |
| Q01 Build & Spec | 2026-09-05 | SOURCE_BUILT; COMPILE_PENDING | governed compile required |
| Q02 Baseline | 2026-09-05 | NOT_ENQUEUED_Q01_PENDING | strict compile/EX5 prerequisite |
