---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MQNDISP-TREND-20260901_S01
variant_id: AI-CODEX-WTI-MQNDISP-TREND-20260901_S01
source_id: AI-CODEX-WTI-MQNDISP-TREND-20260901
ea_id: QM5_41275
slug: wti-mqndisp-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41275_wti-mqndisp-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41275_wti_monthly_qn_dispersion_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_qn_dispersion_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Peter J. Rousseeuw; Christophe Croux"
source_citation: "OpenAI Codex (2026), WTI completed-month Qn-core dispersion-normalized trend continuation; supporting records Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003, and Rousseeuw and Croux (1993), Journal of the American Statistical Association 88(424), DOI 10.1080/01621459.1993.10476408."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI completed-month Qn-core dispersion-normalized trend continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MQNDISP-TREND-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Rousseeuw, P. J. and Croux, C. (1993). Alternatives to the Median Absolute Deviation. Journal of the American Statistical Association 88(424), 1273-1283."
    location: "DOI 10.1080/01621459.1993.10476408; complete-paper retrieval evidence strategy-seeds/sources/AI-CODEX-WTI-MQNDISP-TREND-20260901/retrieval_route_rousseeuw_croux_qn_20260901.json"
    quality_tier: A
    role: qn_pairwise_distance_order_statistic_only
strategy_mechanic: monthly-wti-completed-month-final17-closes-sixteen-daily-log-returns-all-120-pairwise-absolute-return-distances-36th-order-qn-core-net-displacement-greater-than-four-core-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MQNDISP-TREND-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/qn-core-robust-dispersion]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-log-returns]]"
  - "[[indicators/qn-pairwise-distance-core]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-dispersion-normalized, qn-core, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412750000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 7-9 completed WTI positions per full post-warm-up year; one consumed attempt per broker month and a fixed Qn-core coherence gate. Q02 must establish at least five completed positions per full year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_QN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed WTI monthly continuation evidence plus a complete-read peer-reviewed Qn method paper; exact daily-return trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, sessions, final seventeen closes, sixteen returns, endpoint identity, 120 distances, 36th order statistic, omitted consistency factor, inclusive four-core gate, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; roll, basis, financing, gap, and broker-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: immediately completed broker month with 17-23 D1 sessions; final 17 chronological closes; 16 adjacent log returns; all 120 pairwise absolute return distances; 36th one-based order statistic; no Qn consistency multiplier; q_core above 1e-12; inclusive abs(net)>=4*q_core; endpoint tolerance 1e-10; 120 D1 history bars; 180-minute month-entry grace; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED_PENDING
force_build: true
review_focus: "Falsify a direct-WTI completed-month Qn-core dispersion-normalized trend sleeve outside the certified XAU/SP500/NDX/XNG book. Verify month/session membership, final seventeen closes, sixteen return orientation, endpoint identity, all 120 distances, exact 36th order statistic, absent consistency factor, inclusive four-core side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, immediately_completed_month_only, bounded_month_session_count, final_seventeen_daily_closes, no_current_month_price, sixteen_log_returns, endpoint_identity, all_120_pairwise_distances, exact_36th_order_statistic, no_qn_consistency_multiplier, q_core_floor, inclusive_four_core_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41275_wti_monthly_qn_dispersion_trend_g0.md: R1 uses complete-read peer-reviewed WTI and Qn evidence with disclosed QM trading translation; R2 locks clock, data, arithmetic, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact or fuzzy identity across 4,774 registry rows, 1,410 cards, and 45 Wiki nodes; fixed vectors prove two-way qualification disagreement with the closest L1 and RMS within-month systems."
---

# QM5_41275 WTI Completed-Month Qn-Core Dispersion Trend

## Hypothesis

When the net move across the final sixteen daily returns of a completed WTI
broker month is large relative to a lower-quartile pairwise-distance core of
those returns, carry that robustly coherent direction into the next month.
The Qn-shaped core is resistant to a small number of extreme daily returns,
so it asks a different question from L1 path efficiency or RMS coherence.

This is an untested direct-crude structural-trend hypothesis. WTI adds a
physical-energy carrier absent from the stated XAU/SP500/NDX/XNG book, but
carrier difference is not a correlation result. Q02 owns activity and
economics; later gates own robustness; unchanged Q09 alone owns overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/AI-CODEX-WTI-MQNDISP-TREND-20260901/source.md`,
authorized before extraction by
`decisions/2026-09-01_wti_monthly_qn_dispersion_trend_source_approval.md`.
The complete parent hashes are
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`
for the WTI paper packet and
`F4355DB3925B02FFD35B4499342F4D26C5C7372535E5A4ACE7CD4F9041628969`
for the Qn paper PDF.

Moskowitz, Ooi, and Pedersen document monthly own-return continuation, report
a pooled one-month commodity rule, and include WTI. Rousseeuw and Croux define
the pairwise-distance Qn order statistic. Neither source tests a WTI-only
within-month daily-return Qn-core trading gate, continuous CFD, fixed-dollar
ATR risk, or the QM book. The exact formula and execution contract below are
pre-result QM synthesis. No source alpha, profit factor, p-value, drawdown,
trade count, cost, CFD equivalence, or decorrelation statistic is imported.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_mqndisp_tr_preallocation_dedup_20260901.json`, SHA-256
`831C20BF85E9B38C85F29D71F15D22422BD24BD10F3A9C40223DDBCA6AEC066D`,
found no exact or fuzzy identity.

- `QM5_41126` uses net divided by an L1 path and `QM5_41124` uses mean divided
  by RMS. This card uses only the 36th of 120 pairwise return distances.
- The fixed `.0010..0402` vector in the source approval buys here but leaves
  both L1 and RMS neighbors flat. The fixed `-.007421..003460` vector
  qualifies both neighbors but stays flat here.
- `QM5_41250` and the rank-scale family compare old/recent monthly-return
  groups. This card has one fixed within-month daily-return sample and no
  permutation or group comparison.
- `QM5_20187` follows an endpoint sign with no dispersion gate.
- `QM5_12567` is a long-only two-day XNG pullback.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL17_RETURN_QN_CORE_DISPERSION_NORMALIZED_CONTINUATION`.

## Rules

### Market, Clock, And Data

- Host and trade exact `XTIUSD.DWX`, D1, slot 0, magic `412750000`.
- Act only within 180 elapsed minutes of the first D1 bar of a genuine new
  broker month. Persist the `yyyymm` attempt before every fallible entry gate.
- Reconstruct only the immediately completed broker month from a bounded
  120-D1 buffer. Require 17 through 23 chronological completed sessions.
- Select its final seventeen closes in chronological order. Exclude every
  current-month price.
- Require positive finite closes and strict increasing timestamps.

### Exact Signal

```text
r[i] = ln(C[i+1] / C[i]), i=0..15
net  = sum(r)
require abs(net - ln(C[16]/C[0])) <= 1e-10

D = sorted(abs(r[j]-r[i]) for 0<=i<j<=15)
require len(D) == 120
q_core = D[35]
require q_core > 1e-12

BUY  if net >=  4*q_core
SELL if net <= -4*q_core
FLAT otherwise
```

For `n=16`, Qn gives `h=floor(16/2)+1=9` and
`k=C(9,2)=36`. The EA uses the raw 36th one-based distance and deliberately
does not multiply it by any consistency factor. The four-core boundary is
inclusive. Wrong history, membership, chronology, close, return, endpoint,
distance count, sort, order-statistic index, core, or side consumes the month
flat. Signal magnitude never scales risk.

This is a deterministic classifier, not a statistical test. There is no
p-value, significance threshold, independence claim, or volatility forecast.

### Entry Rules

- Reject existing owned exposure or a same-magic current-month entry deal.
- Both news axes, legacy news mode, and Friday close are OFF.
- Reject crossed/negative quotes and a positive spread above 1,500 points.
- Require completed-bar `ATR(20,D1)` and a normalized `3.5*ATR` stop.
- Open at most one market position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, a frozen broker hard stop, and no target.

### Exit And Management Rules

- Close on the first tick in a later broker month.
- Close after forty elapsed calendar days as stale repair.
- Close duplicate, wrong-symbol, wrong-magic, wrong-side, invalid-volume, or
  stopless owned exposure before entry-only gates.
- No target, trail, break-even, partial close, grid, martingale, scale-in,
  pyramid, opposite-signal exit, or same-month retry.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| parameter | default | status |
|---|---:|---|
| `strategy_month_sessions_min` | 17 | locked |
| `strategy_month_sessions_max` | 23 | locked |
| `strategy_close_count` | 17 | locked |
| `strategy_return_count` | 16 | locked |
| `strategy_distance_count` | 120 | locked |
| `strategy_qn_order_one_based` | 36 | locked |
| `strategy_qn_core_floor` | `1e-12` | locked |
| `strategy_net_core_multiplier` | 4.0 | locked |
| `strategy_endpoint_tolerance` | `1e-10` | locked |
| `strategy_history_bars_d1` | 120 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, order statistic, core floor, multiplier, side, carrier,
risk, stop, spread, or hold after Q02 is forbidden.

## Expected Behaviour And Frequency

There is one consumed attempt per broker month and at most twelve entries per
full year. The seven-to-nine ordering prior is not a source probability. Q02
must establish at least five completed positions in every full post-warm-up
year or retire the candidate.

## Reputable-Source Criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_QN_TRADING_MECHANIZATION_AND_CONTINUOUS_CFD_TRANSLATION_RISK | Complete-read peer-reviewed WTI trend and Qn method evidence; exact trading conjunction disclosed as untested QM synthesis. |
| R2 | PASS | Exact clock, data, returns, endpoint identity, 120 distances, 36th core, omitted multiplier, inclusive direction, attempt, risk, and lifecycle. |
| R3 | PASS | Native registered WTI D1 and MT5 state; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native logarithms, sorting, comparisons, and state only; no trained signal or external runtime feed. |

## Risk

Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. This card authorizes no live preset.

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, failed deterministic
fixtures, or any downstream gate failure. Fail current-month leakage, wrong
month/session membership, wrong final-seventeen selection, reversed return,
endpoint mismatch, missing or duplicate distance, wrong sort/index/core,
hidden consistency factor, wrong inclusive gate/side, retry, missing stop,
wrong risk mode, late entry, missed exit, or nondeterminism. No result-driven
rescue is authorized.

WTI gaps, geopolitical and inventory shocks, CFD roll/basis and financing,
hard-stop slippage, sparse monthly decisions, and correlation with XNG or risk
assets can dominate the premise. A low Qn core can also make one net move look
coherent even when a minority of returns is extreme; the fixed-vector
counterexample is deliberate, not hidden.

## Framework Alignment

- `no_trade`: exact identity, carrier, period, risk/news/Friday/input locks,
  month clock, attempt, history, position/deal, quote, spread, ATR, stop, and
  sizing guards.
- `trade_entry`: cached Qn-core side, one fixed-risk WTI market order, frozen
  ATR stop, and no target.
- `trade_management`: malformed-position, next-month, and forty-day repair.
- `trade_close`: framework close helper, broker hard stop, and kill switch.

## Validation Plan

1. Card schema lint and forbidden-token scan.
2. Canonical dedup receipt plus two-way functional-neighbor fixtures.
3. Pure reference checks for month membership, return orientation, endpoint
   identity, all 120 distances, sort, exact 36th core, inclusive sides, and
   counterexamples.
4. Strict MQL5 compile and framework build check.
5. Canonical `RISK_FIXED` XTIUSD D1 backtest set only.
6. One paced Q02 enqueue if the whole-host CPU admission allows it; no manual
   tester launch.

## Safety Boundary

Authorized: one registered V5 identity, one non-live source build, reference
tests, strict Q01, and at most one paced Q02 enqueue.

Forbidden: manual backtest, optimization, live/demo/shadow/stress setfiles,
external runtime data, portfolio-gate edits, correlation waiver, portfolio
admission, deploy/live manifest, `T_Live`, AutoTrading, or terminal control.

## Pipeline History

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, complete-read receipts, dedup, card decision |
| Q01 | 2026-09-01 | PASS | governed `COMPILE_OK`; build check PASS, 0 compile errors, 0 compile warnings |
| Q02 | 2026-09-01 | ENQUEUED_PENDING | `9cc24276-b079-4abc-8813-1ee3a2f8b5d6`; paced worker owns dispatch |

## Revision History

| version | date | reason | phase | verdict |
|---|---|---|---|---|
| v1 | 2026-09-01 | initial WTI Qn-core dispersion-normalized trend card | G0 | APPROVED |
| v1.1 | 2026-09-01 | governed build and paced handoff | Q01/Q02 | PASS / ENQUEUED_PENDING |
