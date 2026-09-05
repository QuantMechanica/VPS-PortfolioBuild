---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905
ea_id: QM5_41354
slug: wti-adf-mkendall-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41354_wti-adf-mkendall-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41354_wti_monthly_adf_mann_kendall_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_mann_kendall_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Chan (2013), Algorithmic Trading, Wiley; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). WTI monthly ADF and Mann-Kendall agreement trend."
    location: strategy-seeds/sources/AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905/source.md
    quality_tier: governed_source
    role: exact_conjunction_threshold_risk_and_lifecycle
  - type: approved_book_source
    citation: "Chan, E. P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading."
    location: strategy-seeds/sources/AI-CODEX-WTI-MADF-PERSIST-TREND-20260903/source.md
    quality_tier: A
    role: lag_one_intercept_adf_arithmetic_and_boundary
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: strategy-seeds/sources/MOP-WTI-RANKTREND-2026/source.md
    quality_tier: A
    role: wti_monthly_continuation_and_governed_all_pairs_ordinal_mechanization
strategy_mechanic: monthly-wti-sixty-completed-log-price-levels-lag-one-intercept-adf-t-at-least-minus2p594-and-newest-thirteen-endpoint-all-pairs-mann-kendall-score-absolute-at-least28-with-score-sign-direction
sources:
  - "[[sources/AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905]]"
concepts:
  - "[[concepts/error-correction-persistence-state]]"
  - "[[concepts/ordinal-trend]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/lag-one-adf-regression-t-statistic]]"
  - "[[indicators/mann-kendall-pairwise-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, adf-persistence-state, mann-kendall, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413540000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to nine completed positions per full post-warm-up year is an uncalibrated conjunction prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_REPUTABLE_EVIDENCE
r1_reasoning: "Complete approved Wiley ADF and peer-reviewed WTI continuation records preserve exact hashes, adverse evidence, and non-transfer boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, sixty endpoints, ADF regression, all 78 newest-thirteen comparisons, inclusive thresholds, score-sign side, attempt, fixed risk, stop, spread, and lifecycle are deterministic."
r3_data_available: PASS
r3_qualification: CONTINUOUS_CFD_BASIS_RISK
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gaps, and broker-month labels remain risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, bounded OLS, comparisons, ATR risk, quotes, positions, deals, and persistent state are used."
parameters_to_test: "Locked Q02 baseline only: 60 completed month-end closes; ADF 58 rows, lag one, intercept, residual dof 55, inclusive t>=-2.594; Mann-Kendall on newest 13 endpoints, all 78 pairs non-tied, inclusive abs(S)>=28 and sign(S) direction; 1800 D1 bars; 180-minute grace; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: COMPILE_OK
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify direct-WTI ADF persistence plus ordinal direction outside the XAU/SP500/NDX/XNG book. Verify completed endpoints, ADF arithmetic, all 78 comparisons, inclusive boundaries, score direction, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, sixty_consecutive_completed_months, no_current_month_price, chronological_log_levels, adf_lag_one_constant_no_time_trend, adf_residual_dof_55, newest_thirteen_endpoints, all_78_pairs, exact_tie_rejection, inclusive_minus2p594_boundary, inclusive_abs_score_28_boundary, score_sign_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER 2026-09-05 commodity/energy sleeve mission: R1 complete hash-bound Wiley and peer-reviewed WTI parents; R2 locked dual-function conjunction and fixed lifecycle; R3 registered XTIUSD.DWX D1 with disclosed CFD basis risk; R4 deterministic native arithmetic only."
---

# QM5_41354 WTI Monthly ADF and Mann-Kendall Agreement Trend

## Hypothesis

WTI supplies direct physical-energy exposure outside the certified carrier
set. The hypothesis is that a strong ordinal monthly trend is suitable for one
broker-month continuation attempt only when a separate lag-one ADF regression
does not identify strong negative error correction. Agreement does not prove
persistence, profit, or decorrelation.

## Source Traceability And Non-Duplicate Decision

The approved packet is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905/source.md`.
It binds complete reputable ADF and WTI continuation/rank parents. The
corrected-root scan found no exact identity across 4,834 registry rows, 1,447
cards, and 45 Wiki nodes. ADF-agreement siblings use different second-state
functions and endpoint return for side. The standalone ADF and Mann-Kendall
parents each omit the other's required function.

## Source-Defined Rules

- Chan supplies lag-one intercept-only ADF arithmetic and negative-tail
  orientation.
- Moskowitz, Ooi, and Pedersen supply monthly own-price continuation and
  explicit WTI membership.
- The governed WTI rank extraction fixes thirteen completed endpoints, every
  older/newer comparison, tie rejection, the `28` boundary, and score side.
- No parent tests this conjunction, CFD transport, fixed risk, or lifecycle.

## QM Interpretations

`XTIUSD.DWX` is a continuous-CFD test carrier, not a matched WTI future. The
rounded `-2.594` ADF line is a state gate, not a valid p-value for this sample.
The Mann-Kendall line is a fixed conventional ordinal boundary, not a fitted
parameter. Neither statistic magnitude changes risk.

## Exact Formula

For chronological log month-end closes `x[0..59]`, fit over `t=2..59`:

```text
dx[t] = alpha + gamma*x[t-1] + phi*dx[t-1] + u[t]
adf_t = gamma / se(gamma), residual dof = 55
```

For closes `C[47..59]`, compare every older/newer pair:

```text
S = sum(sign(C[j]-C[i])) for 47 <= i < j <= 59
require all 78 pairs non-tied
BUY  iff adf_t>=-2.594 and S>=+28
SELL iff adf_t>=-2.594 and S<=-28
FLAT otherwise
```

## Rules

Use only sixty consecutive completed broker-month endpoints and exclude all
current-month prices. Both functions must qualify. Consume the month before
every fallible gate. Permit zero or one owned WTI position and never retry,
resize, scale in, pyramid, grid, or martingale.

## 4. Entry Rules

Require exact WTI D1 identity, slot/magic, locked inputs, and fixed risk. On a
genuine new month within 180 minutes, persist the attempt, reconstruct
endpoints, compute ADF, compute all 78 ordinal comparisons, then require spread
`[0,1500]`, quotes, completed ATR(20), sizing, and margin. Open at most one
position with a frozen `3.5*ATR` hard stop and no target.

## 5. Exit Rules

Framework kill switch and broker stop remain authoritative. Close on the first
later-month tick or after 40 days. No intramonth signal exit, target, trail,
break-even, partial close, retry, or Friday flatten.

## 6. Filters (No-Trade Module)

Require exact carrier, D1 host, slot/magic, locked risk and framework inputs,
first-tradable-month timing, complete fresh endpoints, ADF state, strong
non-tied ordinal score, valid quotes/ATR, and spread in `[0,1500]`. Persist the
attempt before fallible filters.

## 7. Trade Management Rules

Permit only zero or one owned WTI position. Immediately close duplicates,
wrong-symbol, wrong-side, or stopless owned positions. A valid position keeps
its frozen stop until next-month or 40-day close.

## 8. Parameters To Test

One locked baseline: 60 levels; ADF 58 rows/dof 55; newest 13 closes; all 78
pairs; exact-tie rejection; inclusive ADF `-2.594`; inclusive score `28`; 1,800
D1 bars; 180-minute grace; 10-day endpoint freshness; ATR(20)*3.5 stop; 40-day
stale exit; 1,500-point spread cap. No sweep is authorized before baseline.

## 9. Author Claims

No parent performance transfers. The conjunction, CFD transport, density,
economics, and portfolio correlation are untested.

## 10. Initial Risk Profile

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, sparse qualification,
shared trend direction, and stop slippage are material. No live risk is
authorized.

## Risk

The only preset uses fixed risk 1,000, zero percent risk, weight one, a frozen
`3.5*ATR(20,D1)` stop, and no target. Signal magnitude never changes risk.

## 11. Strategy Allowability Check

- [x] R1 reputable complete parent records with hashes and adverse boundaries.
- [x] R2 mechanical formulas, gates, side, lifecycle, and risk.
- [x] R3 registered native `XTIUSD.DWX` D1 supplies runtime data.
- [x] R4 no prohibited learned/banned signal machinery or external feed.
- [x] Friday close is disabled to preserve the monthly hold.
- [x] Corrected-root dedup has no exact identity; fuzzy neighbors are resolved.

## 12. Framework Alignment

- no_trade: identity, host, inputs, month attempt, endpoints, formulas, spread,
  ATR, position, and malformed-exposure guards.
- trade_entry: conjunctive state, score side, fixed-risk size, frozen ATR stop.
- trade_management: defensive repair and restart-safe next-month/stale exits.
- trade_close: framework reason mapping and broker-side hard stop.

## 13. Implementation Notes

Use V5 hooks, `QM_MagicChecked(41354,0,"XTIUSD.DWX")`, native D1 endpoint
reconstruction, terminal-global attempt state, fixed-risk sizing, and decision
trace logging. Reference tests cover ADF, pair count, ties, boundaries,
disagreement, direction, mirror, registry, and setfile.

## 14. Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial build | Q02 | ENQUEUED_PENDING |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | `decisions/2026-09-05_wti_monthly_adf_mann_kendall_agreement_trend_source_approval.md` |
| G0 Research Intake | 2026-09-05 | APPROVED | `decisions/2026-09-05_qm5_41354_wti_monthly_adf_mann_kendall_agreement_trend_g0.md` |
| Q01 Build & Spec | 2026-09-05 | COMPILE_OK; BUILD_CHECK_PASS | `D:/QM/reports/work_items/3e81b611-54da-4c98-b2a0-b3eab917e591/QM5_41354/COMPILE_EA/compile_evidence.json` |
| Q02 Baseline | 2026-09-05 | ENQUEUED_PENDING | work item `c762c5a5-8d19-4d8b-b54a-4ffc3a47038e` |

## 16. Lessons Captured

- 2026-09-05: an ADF state and all-pairs ordinal direction are not
  interchangeable; either parent can trade while their conjunction stays flat.

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
