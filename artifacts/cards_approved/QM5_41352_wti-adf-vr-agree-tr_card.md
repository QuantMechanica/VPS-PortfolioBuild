---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905
ea_id: QM5_41352
slug: wti-adf-vr-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41352_wti-adf-vr-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41352_wti_monthly_adf_variance_ratio_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_variance_ratio_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Julia S. Mehlitz; Benjamin R. Auer; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Chan (2013), Algorithmic Trading, Wiley; Mehlitz and Auer (2024), European Journal of Finance 30(8), DOI 10.1080/1351847X.2023.2220118; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF and robust variance-ratio agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_sample_threshold_risk_and_lifecycle
  - type: approved_book_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_constant_no_time_trend_adf_arithmetic_and_boundary_orientation
  - type: peer_reviewed_commodity_paper
    citation: "Mehlitz, J. S. and Auer, B. R. (2024). Memory-enhanced momentum in commodity futures markets. The European Journal of Finance 30(8), 773-802."
    location: strategy-seeds/sources/MEHLITZ-AUER-WTI-R3Q4-2026/source.md
    quality_tier: A
    role: wti_r3_q4_heteroskedasticity_robust_variance_ratio_arithmetic_and_persistence_state
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-TSMOM-2012/source.md
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-thirty-two-log-returns-q4-heteroskedasticity-robust-lo-mackinlay-z-strictly-above1p64485362695147-agreement-gated-twelve-month-return-sign-continuation
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-diagnostic-agreement, augmented-dickey-fuller, variance-ratio, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413520000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately three to seven completed positions per full post-warm-up year is an uncalibrated conjunction prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r1_reasoning: "Complete approved ADF, peer-reviewed WTI q4 robust variance-ratio, and peer-reviewed WTI continuation records provide exact hashes and explicit non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, both locked arithmetic paths, inclusive ADF and strict positive VR boundaries, conjunction, twelve-month side, consumed attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain material risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, bounded return sums, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 completed month-end closes; ADF on all 60 log levels, 58 rows, lag one, intercept, residual dof 55, inclusive t>=-2.594; robust VR on newest 32 returns, q=4, strict z>1.64485362695147; 12-month direction; 1800 D1 bars; 180-minute grace; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: COMPILE_OK
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify direct-WTI monthly ADF/robust-VR agreement outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, q4 robust weights, positive-persistence-only boundary, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, inclusive_adf_boundary, newest_thirty_two_returns, q4_heteroskedasticity_robust_variance_ratio, strict_positive_vr_boundary, both_gates_required, twelve_month_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER 2026-09-05 commodity/energy sleeve mission: R1 complete hash-bound Wiley and peer-reviewed WTI/robust-VR parents; R2 locked monthly ADF plus positive q4 VR agreement and fixed lifecycle; R3 registered XTIUSD.DWX D1 with disclosed CFD basis risk; R4 deterministic native arithmetic only. Correct"
---

# QM5_41352 WTI Monthly ADF and Robust Variance-Ratio Agreement Trend

## Hypothesis

WTI supplies direct physical-energy exposure outside the certified carrier
set. The hypothesis is that the newest twelve-month WTI direction is suitable
for one broker month only when lag-one ADF does not show strong error
correction and the newest 32 monthly returns show significantly positive q=4
heteroskedasticity-robust variance-ratio persistence. Agreement does not prove
persistence, profit, or decorrelation.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-VR-AGREE-TREND-20260905/source.md`.
Its complete reputable parents define ADF, robust variance-ratio memory, and
WTI continuation separately. The corrected-root scan found no exact identity
across 4,832 registry rows, 1,445 cards, and 45 Wiki nodes. Nine expected
fuzzy family matches were manually resolved: `QM5_20253` omits ADF, uses a
three-month side, and reverses negative VR states; the ADF-only parent omits
VR; every ADF-agreement sibling uses another load-bearing state function.
Shared WTI direction remains a correlation risk for Q09.

## Source-Defined Rules

- Chan supplies lag-one intercept-only ADF arithmetic and negative-tail
  orientation.
- Mehlitz and Auer supply the 32-return q=4 heteroskedasticity-robust
  Lo-MacKinlay statistic, significant positive persistence state, and WTI
  membership.
- Moskowitz, Ooi, and Pedersen supply instrument-own completed twelve-month
  return direction and explicit crude-oil futures membership.
- No parent defines this conjunction, its thresholds on a continuous CFD, the
  ATR stop, spread ceiling, or QM lifecycle.

## QM Interpretations

`XTIUSD.DWX` is a registered continuous-CFD test carrier rather than a matched
WTI futures contract. Requiring both diagnostics is a pre-result sparsity
hypothesis. ADF alone, insignificant VR, or significant negative VR is
deliberately insufficient. The numeric gates, one-month package, stop, spread
cap, and consumed-month state are QM implementation choices.

## Exact Formula

For chronological log month-end closes `x[0..59]`, fit the locked lag-one
intercept ADF over `t=2..59` and require `adf_t>=-2.594`. From all 59 adjacent
returns use the newest 32. With deviations `d`, `S=sum(d^2)`, and lags 1..3:

```text
rho(k)=sum(d[t]*d[t-k])/S
delta(k)=sum(d[t]^2*d[t-k]^2)/S^2
VR4=1+1.5*rho1+rho2+0.5*rho3
theta4=2.25*delta1+delta2+0.25*delta3
vr_z=(VR4-1)/sqrt(theta4)
mom12=x[59]-x[47]

BUY  iff adf_t>=-2.594 and vr_z>1.64485362695147 and mom12>+1e-12
SELL iff adf_t>=-2.594 and vr_z>1.64485362695147 and mom12<-1e-12
FLAT otherwise
```

## Rules

Use only sixty consecutive completed broker-month endpoints and exclude the
current month. Both diagnostics must qualify; only twelve-month return sign
chooses side. Consume the month before every fallible gate. Permit zero or one
owned WTI position, attach one frozen hard stop, and never retry, resize,
scale in, pyramid, grid, or martingale.

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
contract, first-tradable-month timing, complete fresh endpoints, both gates,
nonzero twelve-month direction, valid quotes and ATR, and spread in
`[0,1500]`. Persist the monthly attempt before fallible filters.

## 7. Trade Management Rules

Permit only zero or one owned WTI position. Immediately close duplicates,
wrong-symbol, wrong-side, or stopless owned positions. A valid position keeps
its frozen initial stop until the next-month or 40-day close; signal magnitude
never resizes it.

## 8. Parameters To Test

The Q02 identity is locked to 60 endpoints, 58-row lag-one ADF with intercept
and threshold `-2.594`, newest 32 returns, q=4 robust VR with threshold
`1.64485362695147`, twelve-month direction, 1800 D1 history bars, 180-minute
entry grace, ten-day endpoint staleness, ATR(20)*3.5 stop, 40-day stale exit,
and 1,500-point spread cap. No parameter sweep is authorized before baseline.

## 9. Author Claims

No parent-source performance number transfers. The conjunction, continuous
CFD carrier, density, economics, and portfolio correlation are untested.

## 10. Initial Risk Profile

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, small-sample diagnostic
size, overlapping windows, shared trend direction, and stop slippage are
material. No live risk is authorized.

## Risk

The only test preset uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The frozen stop is `3.5*ATR(20,D1)` and no target is
used. Signal magnitude never changes risk.

## 11. Strategy Allowability Check

- [x] R1 reputable complete parent records with hashes and claim boundaries.
- [x] R2 mechanical samples, formulas, gates, side, lifecycle, and risk.
- [x] R3 registered native `XTIUSD.DWX` D1 supplies all runtime data.
- [x] R4 no ML, external runtime feed, grid, martingale, scale-in, or pyramid.
- [x] Friday close is explicitly disabled to preserve the monthly hold.
- [x] Corrected-root dedup has no exact identity; fuzzy neighbors are resolved.

## 12. Framework Alignment

- no_trade: identity, host, inputs, month attempt, endpoints, formulas, spread,
  ATR, position, and malformed-exposure guards.
- trade_entry: conjunctive diagnostic state, twelve-month side, fixed-risk
  size, and frozen ATR stop.
- trade_management: defensive repair and restart-safe next-month/stale exits.
- trade_close: framework reason mapping and broker-side hard stop.

## 13. Implementation Notes

Use the V5 four-hook lifecycle, `QM_MagicChecked(41352,0,"XTIUSD.DWX")`, native
D1 reconstruction, terminal-global monthly attempt state, fixed-risk sizing,
and decision-trace logging. Reference tests must cover both formulas,
inclusive/strict boundaries, disagreement, direction, card mirror, registry,
and setfile.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial build | G0 | PENDING |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_wti_monthly_adf_variance_ratio_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41352_wti_monthly_adf_variance_ratio_agreement_trend_g0.md` |
| Q01 Build & Spec | 2026-09-05 | COMPILE_OK; BUILD_CHECK_PASS | `D:\\QM\\reports\\work_items\\d3b585c0-f23b-4b02-9f72-413e91b74964\\QM5_41352\\COMPILE_EA\\compile_evidence.json` |
| Q02 Baseline | 2026-09-05 | ENQUEUED_PENDING | work item `e001ff07-3e79-4cb2-a2de-e623cbb6f0f4` |

## 16. Lessons Captured

- 2026-09-05: ADF non-rejection and positive q4 VR must both qualify; a
  negative significant VR state is disagreement and stays flat.

## Validation And Kill Criteria

Run reference fixtures, schema lint, strict Q01, and enqueue exactly one paced
Q02 only under CPU admission. Retire on zero trades, below five per full scored
post-warm-up year, nonpositive economics, formula mismatch, leakage, invalid
risk, missing stop, nondeterminism, lifecycle deviation, or any downstream
hard failure. No post-result tuning is authorized.

## Safety Boundary

Authorized: branch-only non-live build, reference tests, strict Q01, one
fixed-risk backtest set, and one paced Q02 enqueue. Forbidden: manual
backtests, optimization, live/demo/shadow/stress sets, portfolio-gate edits,
correlation waivers, portfolio admission, deploy/live manifests, `T_Live`,
AutoTrading, terminal control, or live use.
