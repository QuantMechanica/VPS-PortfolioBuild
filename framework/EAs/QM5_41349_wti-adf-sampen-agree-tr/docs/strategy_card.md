---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-ADF-SAMPEN-AGREE-TREND-20260905_S01
variant_id: AI-CODEX-WTI-ADF-SAMPEN-AGREE-TREND-20260905_S01
source_id: AI-CODEX-WTI-ADF-SAMPEN-AGREE-TREND-20260905
ea_id: QM5_41349
slug: wti-adf-sampen-agree-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41349_wti-adf-sampen-agree-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-05
created_by: Research+Development
last_updated: 2026-09-05
g0_status: APPROVED
g0_decision: decisions/2026-09-05_qm5_41349_wti_monthly_adf_sampen_agreement_trend_g0.md
source_approval: decisions/2026-09-05_wti_monthly_adf_sampen_agreement_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Ernest P. Chan; Jiri Tomcala; Joshua S. Richman; J. Randall Moorman; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen
source_citation: "Chan (2013), Algorithmic Trading, Wiley; Tomcala (2020), Entropy 22(8), DOI 10.3390/e22080863; Richman and Moorman (2000), AJP Heart 278(6), DOI 10.1152/ajpheart.2000.278.6.H2039; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: book
    citation: "Chan, E. P. (2013). Algorithmic Trading. Wiley."
    quality_tier: A
    role: primary_adf_method
  - type: paper
    citation: "Tomcala, J. (2020). New Fast ApEn and SampEn Entropy Algorithms Implementation and Their Application to Supercomputer Power Consumption. Entropy 22(8), 863."
    quality_tier: A
    role: primary_sample_entropy_method
  - type: paper
    citation: "Richman, J. S. and Moorman, J. R. (2000). Physiological time-series analysis using approximate entropy and sample entropy. American Journal of Physiology 278(6)."
    quality_tier: A
    role: foundational_sample_entropy_method
  - type: paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2)."
    quality_tier: A
    role: primary_commodity_trend_premise
strategy_mechanic: monthly-wti-sixty-one-completed-month-endpoints-newest-sixty-level-lag-one-adf-t-at-least-minus2p594-and-sixty-return-m2-r020sd-sample-entropy-at-most2p5-agreement-gated-twelve-month-return-sign-continuation
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, dual-diagnostic-agreement, augmented-dickey-fuller, sample-entropy, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 413490000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately five to seven completed positions per full post-warm-up year is an uncalibrated prior; Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE
r2_mechanical: PASS
r3_data_available: PASS_WITH_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: 61 completed month-end closes; ADF on newest 60 log levels with lag one, intercept, 58 observations, dof 55, inclusive t>=-2.594; 60 adjacent returns; sample sd denominator 59; m=2; lag=1; radius=0.2*sd; strict Chebyshev matching; no self matches; SampEn=ln(B/A), B>=A>0, inclusive <=2.5; 12-month direction; history 1800 D1 bars; entry grace 180 minutes; endpoint staleness 10 days; ATR(20)*3.5 stop; stale exit 40 days; spread ceiling 1500 points."
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
review_focus: "Falsify direct-WTI monthly ADF/sample-entropy agreement outside the certified XAU/SP500/NDX/XNG book. Verify shared endpoints, ADF arithmetic, exact template matching/counts, inclusive gates, disagreement abstention, twelve-month side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [q02_activity_floor, enhancement_doctrine, q09_portfolio_correlation]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
g0_approval_reasoning: "OWNER mission 2026-09-05 and G0 decision approve R1-R4 within disclosed source-synthesis and continuous-CFD risks. Corrected-root dedup found no exact identity; manual review separates raw-magnitude sample entropy from every other ADF agreement gate."
---

# QM5_41349 WTI Monthly ADF and Sample-Entropy Agreement Trend

## Hypothesis

WTI supplies direct physical-energy exposure outside the certified carrier
set. The hypothesis is that the newest twelve-month WTI direction is suitable
for one more broker month only when lag-one ADF does not show strong error
correction and raw-magnitude return templates have sufficiently low sample
entropy. The conjunction does not prove persistence, profit, or decorrelation.

## Source Traceability And Claim Boundary

The approved source packet is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-SAMPEN-AGREE-TREND-20260905/source.md`.
Its parents define ADF, sample entropy, and WTI continuation separately; none
tests this exact conjunction, sample, thresholds, CFD, costs, activity, or fit.

## Non-Duplicate Decision

The corrected-root scan found no exact identity across 4,829 registry rows,
1,442 cards, and 45 Wiki nodes. Existing ADF agreement EAs use KPSS level
partial sums, spectral-energy entropy, von-Neumann dispersion, or LZ76 sign
phrases. This EA counts overlapping raw-magnitude templates at dimensions two
and three; both disagreement directions must remain flat. Q09 gets no waiver.

## Markets, Timeframe, And Cadence

Exact host/traded symbol is `XTIUSD.DWX`, D1, slot zero, magic `413490000`.
Decide on the first executable tick after a genuine broker-month transition
within 180 minutes. Use 61 completed month ends and hold until the next month;
40 days is stale repair. Expected cadence is 5–7 positions/year, uncalibrated.

## Exact Formula

For chronological log closes `x[0..60]`, run the locked lag-one intercept-only
ADF regression on `x[1..60]` and require `adf_t>=-2.594`. On all adjacent
returns `r[i]=x[i+1]-x[i]`, compute sample sd, radius `0.2*sd`, strict
Chebyshev template matches at lengths two and three, and
`SampEn=ln(B/A)` with `B>=A>0`; require `SampEn<=2.5`.

```text
mom12=x[60]-x[48]
BUY  iff both gates qualify and mom12 > +1e-12
SELL iff both gates qualify and mom12 < -1e-12
FLAT otherwise
```

## Rules

Use only completed broker-month endpoints and the exact arithmetic above.
Both diagnostic gates must qualify, only the strict twelve-month return chooses
side, and the broker month is consumed before any fallible entry check. One
fixed-risk position, one frozen hard stop, one monthly package, and no adaptive
or retry behavior are permitted.

## 4. Entry Rules

1. Require exact identity, WTI D1 host, slot/magic, locked inputs, and fixed risk.
2. Process malformed/later-month exposure before entry-only gates.
3. Require a genuine new broker month inside the entry grace and persist it
   before history, signal, news, spread, quote, ATR, sizing, or order submission.
4. Reconstruct exactly 61 consecutive completed month ends, excluding current month.
5. Apply both exact arithmetic paths and require their inclusive conjunction.
6. Use only the strict twelve-month return sign for direction.
7. Require spread in `[0,1500]`, valid quotes/metadata, completed ATR(20),
   sizing, and margin; open at most one position with frozen `3.5*ATR` stop.

## 5. Exit Rules

Close on the first later-month bar, after 40 calendar days, or immediately for
duplicate/wrong-symbol/wrong-side/stopless owned exposure. Framework kill
switch and broker stop remain authoritative. There is no intramonth statistic
exit, target, trail, break-even, partial close, retry, scale-in, grid,
martingale, or pyramid.

## 6. Filters (No-Trade Module)

Fail closed on identity, risk/news/Friday/stress/input, endpoint, arithmetic,
template/count, neutral side, spread, quote, ATR, sizing, and margin defects.
Lifecycle repair precedes entry-only gates. Runtime uses no external file/API,
curve, inventory, optimizer output, portfolio state, randomness, or trained artifact.

## 7. Trade Management Rules

Exactly zero or one owned WTI position is valid. Preserve its frozen stop and
entry-month state; reconstruct the identical signal after restart to validate
side. Close at next month, 40 days, or malformed state. Never resize or retry.

## Parameters To Test

Q02 has one baseline: 61 month ends; ADF newest 60 levels/lag one/intercept/
58 rows/dof 55/threshold `-2.594`; sample entropy 60 returns/sample sd/
`m=2`/lag one/radius `0.2*sd`/strict Chebyshev/no self matches/threshold `2.5`;
12-month side; 1,800 D1 history bars; 180-minute grace; 10-day staleness;
`3.5*ATR(20)` stop; 40-day exit; 1,500-point spread ceiling.

## Expected Behavior And Frequency

One month is consumed at each eligible clock. The combination is expected to
attempt about 5–7 positions annually, but this is not market evidence. Q02
retires the candidate below five positions in any full scored post-warm-up year.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, roll/basis/financing, shared samples,
finite-sample test size, template scarcity, stop slippage, and book correlation
are material. Signal magnitude never changes size.

## Data Requirements

Native `XTIUSD.DWX` D1 time/close history, ATR, broker time, quotes, metadata,
positions, deals, and terminal globals. No external runtime source.

## Framework Execution Overrides

Both news axes and legacy news are off, Friday close is disabled, and stress
rejection is zero. Kill-switch, weekend, disconnect, and hard-stop coverage remain.

## Exit Precedence

Kill switch/broker stop; malformed-state repair; next-month exit; 40-day stale
exit; no other strategy exit.

## Runtime Data Dependencies

Tester host is `XTIUSD.DWX` D1 with MT5-native history and execution state only.
The canonical Q02 window is governed by the factory; no future bars or files.

## Reputable-Source Gate Findings

R1 passes with complete governed parent evidence and an explicit synthesis
boundary. R2 passes with fully locked arithmetic and execution. R3 passes with
continuous-CFD basis risk. R4 passes without ML or banned indicators.

## Failure Modes And Kill Criteria

Retire on zero trades, any full scored year below five, nonpositive economics,
formula/fixture mismatch, current-month leakage, repeated attempt, missing stop,
invalid fixed risk, lifecycle deviation, nondeterminism, or downstream failure.
Do not tune after observing failure.

## Execution And State Contract

Persist one month attempt before all fallible gates. Persist entry month only
after a confirmed fill and recover it from owned state. Use checked magic,
framework sizing/normalization, and governed order helpers.

## Portfolio Interaction

Direct WTI adds crude-oil exposure absent from the current carrier set and is
not the certified XNG cumulative-RSI logic. This is a diversification
hypothesis only; unchanged Q09 may reject it.

## Validation Plan

Reference-test endpoint alignment, ADF, sample sd/radius, strict templates,
counts, boundary, direction, and disagreement paths; schema-lint and strict
compile; enqueue one fixed-risk Q02 only below the CPU ceiling.

## Framework Alignment

- no_trade: exact identity, locked inputs, risk/news/Friday/stress guards.
- trade_entry: consumed month, endpoints, ADF, sample entropy, conjunction,
  side, spread/quote/ATR/stop, one fixed-risk order.
- trade_management: malformed-state repair, side validation, month/stale exits.
- trade_close: framework close helper, broker stop, and kill switch.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live build, reference
tests, strict Q01, one fixed-risk set, and one paced Q02 enqueue below the CPU
ceiling. Forbidden: manual backtests, optimization, live/demo/shadow/stress
sets, terminal control, portfolio gate/admission/waiver changes, deploy/live
manifests, `T_Live`, AutoTrading, and live use.

## Revision History

| version | date | reason | gate | verdict |
|---|---|---|---|---|
| v1 | 2026-09-05 | initial ADF/sample-entropy agreement card | G0 | APPROVED; source built; governed compile pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-05 | APPROVED_SOURCE | source approval decision |
| G0 Research Intake | 2026-09-05 | APPROVED | G0 decision |
| Q01 Build | 2026-09-05 | SOURCE_BUILT; COMPILE_PENDING | commit `947e74f89e`; compile item `58f2abcf-00c1-4d8e-a928-9a25dde9e1c9` |
| Q02 Baseline | 2026-09-05 | NOT_ENQUEUED_Q01_PENDING | strict compile/EX5 prerequisite not yet available |
