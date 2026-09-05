---
strategy_id: AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905
ea_id: QM5_41353
slug: wti-adf-pp-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41353_wti-adf-pp-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41353_wti_monthly_adf_phillips_perron_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_phillips_perron_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Peter C. B. Phillips; Pierre Perron; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Chan (2013), Algorithmic Trading, Wiley; Phillips and Perron (1988), Biometrika 75(2), DOI 10.1093/biomet/75.2.335; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF and Phillips-Perron agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_threshold_risk_and_lifecycle
  - type: approved_book_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_intercept_adf_arithmetic_and_boundary
  - type: peer_reviewed_econometrics_paper
    citation: "Phillips, P. C. B. and Perron, P. (1988). Testing for a Unit Root in Time Series Regression. Biometrika 75(2), 335-346."
    location: strategy-seeds/sources/AI-CODEX-WTI-MPP-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: pp_ztau_bartlett_hac_arithmetic_and_adverse_boundary
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-lag-zero-eleven-hac-lag-phillips-perron-z-tau-at-least-minus2p594-agreement-gated-twelve-month-return-sign-continuation
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-unit-root-agreement, augmented-dickey-fuller, phillips-perron, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413530000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to ten completed positions per full post-warm-up year is an uncalibrated conjunction prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_REPUTABLE_EVIDENCE
r1_reasoning: "Complete approved ADF, peer-reviewed PP, and peer-reviewed WTI continuation records provide exact hashes, adverse evidence, and non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, both locked regressions, inclusive thresholds, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS/HAC arithmetic, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 completed month-end closes; ADF 58 rows, lag one, intercept, residual dof 55, inclusive t>=-2.594; PP 59 rows, intercept AR(1), residual dof 57, eleven Bartlett HAC lags, inclusive Z-tau>=-2.594; 12-month direction; 1800 D1 bars; 180-minute grace; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: COMPILE_OK
q02_status: NOT_ENQUEUED_CPU_CEILING
force_build: true
review_focus: "Falsify direct-WTI monthly ADF/PP agreement outside the XAU/SP500/NDX/XNG book. Verify distinct regressions, HAC correction, inclusive boundaries, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, pp_lag_zero_constant_no_time_trend, pp_residual_dof_57, eleven_bartlett_hac_lags, both_inclusive_minus2p594_boundaries, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER 2026-09-05 commodity/energy sleeve mission: R1 complete hash-bound Wiley and peer-reviewed ADF/PP/WTI parents; R2 locked dual-unit-root agreement and fixed lifecycle; R3 registered XTIUSD.DWX D1 with disclosed CFD basis risk; R4 deterministic native arithmetic only."
---

# QM5_41353 WTI Monthly ADF and Phillips-Perron Agreement Trend

## Hypothesis

WTI supplies direct physical-energy exposure outside the certified carrier
set. The hypothesis is that completed twelve-month WTI direction is suitable
for one broker-month continuation attempt only when two differently specified
unit-root diagnostics both fail to identify strong error correction. Agreement
does not prove persistence, profit, or decorrelation.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905/source.md`.
It binds complete reputable ADF, PP, and WTI continuation parents. The
corrected-root scan found no exact identity across 4,833 registry rows, 1,446
cards, and 45 Wiki nodes. The PP-only parent omits ADF, the ADF-only parent
omits PP, and each ADF sibling uses a different second diagnostic. ADF uses a
lagged-difference regressor; PP uses a lag-zero level AR(1) plus eleven HAC
corrections, so their conjunction can abstain when either standalone trades.

## Source-Defined Rules

- Chan supplies lag-one intercept-only ADF arithmetic and negative-tail
  orientation.
- Phillips and Perron supply level AR(1) Z-tau correction using a consistent
  residual long-run variance and its finite-sample adverse warning.
- Moskowitz, Ooi, and Pedersen supply completed monthly own-return continuation
  and explicit WTI membership.
- No parent defines this conjunction, CFD thresholds, ATR stop, spread cap, or
  QM lifecycle.

## QM Interpretations

`XTIUSD.DWX` is a continuous-CFD test carrier, not a matched WTI future. Both
rounded `-2.594` lines are state gates, not valid 60-observation CFD p-values.
Requiring agreement is a pre-result sparsity hypothesis. Only return sign
chooses side; diagnostics and signal magnitude never change risk.

## Exact Formula

For chronological log month-end closes `x[0..59]`, fit ADF over `t=2..59`:

```text
dx[t] = alpha + gamma*x[t-1] + phi*dx[t-1] + u[t]
adf_t = gamma / se(gamma), residual dof = 55
```

Separately fit `x[i+1]=a+rho*x[i]+e[i]`, `i=0..58`, residual dof 57. Using
`gamma0=sum(e^2)/59`, eleven Bartlett residual autocovariances, regression
sigma `s`, and `se_rho`:

```text
lambda2 = gamma0 + 2*sum((1-j/12)*gamma[j], j=1..11)
raw_tau = (rho-1)/se_rho
pp_z_tau = sqrt(gamma0/lambda2)*raw_tau
           - 0.5*((lambda2-gamma0)/sqrt(lambda2))*(59*se_rho/s)
mom12 = x[59]-x[47]

BUY  iff adf_t>=-2.594 and pp_z_tau>=-2.594 and mom12>+1e-12
SELL iff adf_t>=-2.594 and pp_z_tau>=-2.594 and mom12<-1e-12
FLAT otherwise
```

## Rules

Use only sixty consecutive completed broker-month endpoints; exclude all
current-month prices. Both diagnostics must qualify. Consume the month before
every fallible gate. Permit zero or one owned WTI position and never retry,
resize, scale in, pyramid, grid, or martingale.

## 4. Entry Rules

Require exact WTI D1 identity, slot/magic, locked inputs, and fixed risk. On a
genuine new month within 180 minutes, persist the attempt, reconstruct
endpoints, apply both diagnostics, then require spread `[0,1500]`, quotes,
completed ATR(20), sizing, and margin. Open at most one position with a frozen
`3.5*ATR` hard stop and no target.

## 5. Exit Rules

Framework kill switch and broker stop remain authoritative. Close on the first
later-month tick or after 40 days. No intramonth diagnostic exit, target,
trail, break-even, partial close, retry, or Friday flatten.

## 6. Filters (No-Trade Module)

Require exact carrier, D1 host, slot/magic, locked risk and framework inputs,
first-tradable-month timing, complete fresh endpoints, both gates, nonzero
direction, valid quotes/ATR, and spread in `[0,1500]`. Persist the attempt
before fallible filters.

## 7. Trade Management Rules

Permit only zero or one owned WTI position. Immediately close duplicates,
wrong-symbol, wrong-side, or stopless owned positions. A valid position keeps
its frozen stop until next-month or 40-day close.

## 8. Parameters To Test

One locked baseline: 60 levels; ADF 58 rows/dof 55; PP 59 rows/dof 57 and 11
Bartlett lags; both thresholds inclusive `-2.594`; 12-month direction; 1,800
D1 bars; 180-minute grace; 10-day endpoint freshness; ATR(20)*3.5 stop; 40-day
stale exit; 1,500-point spread cap. No sweep is authorized before baseline.

## 9. Author Claims

No parent performance transfers. The conjunction, CFD transport, density,
economics, and portfolio correlation are untested.

## 10. Initial Risk Profile

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, small-sample unit-root
size, overlapping windows, shared trend direction, and stop slippage are
material. No live risk is authorized.

## Risk

The only preset uses fixed risk 1,000, zero percent risk, weight one, a frozen
`3.5*ATR(20,D1)` stop, and no target. Signal magnitude never changes risk.

## 11. Strategy Allowability Check

- [x] R1 reputable complete parent records with hashes and adverse boundaries.
- [x] R2 mechanical formulas, gates, side, lifecycle, and risk.
- [x] R3 registered native `XTIUSD.DWX` D1 supplies runtime data.
- [x] R4 no ML, external runtime feed, grid, martingale, scale-in, or pyramid.
- [x] Friday close is disabled to preserve the monthly hold.
- [x] Corrected-root dedup has no exact identity; fuzzy neighbors are resolved.

## 12. Framework Alignment

- no_trade: identity, host, inputs, month attempt, endpoints, formulas, spread,
  ATR, position, and malformed-exposure guards.
- trade_entry: conjunctive state, twelve-month side, fixed-risk size, frozen
  ATR stop.
- trade_management: defensive repair and restart-safe next-month/stale exits.
- trade_close: framework reason mapping and broker-side hard stop.

## 13. Implementation Notes

Use V5 hooks, `QM_MagicChecked(41353,0,"XTIUSD.DWX")`, native D1 endpoint
reconstruction, terminal-global attempt state, fixed-risk sizing, and decision
trace logging. Reference tests cover both regressions, inclusive boundaries,
disagreement, direction, mirror, registry, and setfile.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial build | G0 | PENDING |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_wti_monthly_adf_phillips_perron_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41353_wti_monthly_adf_phillips_perron_agreement_trend_g0.md` |
| Q01 Build & Spec | 2026-09-05 | COMPILE_OK; BUILD_CHECK_PASS | `D:\\QM\\reports\\work_items\\6b38739d-6a70-4014-bf15-af5c0e586984\\QM5_41353\\COMPILE_EA\\compile_evidence.json` |
| Q02 Baseline | 2026-09-05 | NOT_ENQUEUED_CPU_CEILING | five CPU samples 97.9505%-99.4142%, average 98.77059%, threshold 97% |

## 16. Lessons Captured

- 2026-09-05: ADF and PP are not interchangeable because their regression and
  residual-covariance paths differ; disagreement must stay flat.

## Validation And Kill Criteria

Run reference fixtures, schema lint, strict Q01, and enqueue exactly one paced
Q02 only under CPU admission. Retire on zero trades, below five per full scored
post-warm-up year, nonpositive economics, mismatch, leakage, invalid risk,
missing stop, nondeterminism, lifecycle deviation, or downstream hard failure.

## Safety Boundary

Authorized: branch-only non-live build, reference tests, strict Q01, one
fixed-risk set, and one paced Q02 enqueue. Forbidden: manual backtests,
optimization, live/demo/shadow/stress sets, portfolio-gate edits, correlation
waivers, portfolio admission, deploy/live manifests, `T_Live`, AutoTrading,
terminal control, or live use.
