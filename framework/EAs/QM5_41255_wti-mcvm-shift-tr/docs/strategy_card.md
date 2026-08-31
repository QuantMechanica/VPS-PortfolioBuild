---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MCVM-20260831_S01
variant_id: AI-CODEX-WTI-MCVM-20260831_S01
source_id: AI-CODEX-WTI-MCVM-20260831
ea_id: QM5_41255
slug: wti-mcvm-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41255_wti-mcvm-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41255_wti_mcvm_distribution_shift_trend_g0.md
source_approval: decisions/2026-08-31_wti_mcvm_distribution_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; T. W. Anderson; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly exact-permutation integrated-ECDF distribution-shift continuation; supporting records Anderson (1962), Annals of Mathematical Statistics 33(3), DOI 10.1214/aoms/1177704477, and Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly exact-permutation integrated-ECDF distribution-shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MCVM-20260831/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_thresholds_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_method_bibliography
    citation: "Anderson, T. W. (1962). On the Distribution of the Two-Sample Cramer-von Mises Criterion. The Annals of Mathematical Statistics 33(3), 1148-1159."
    location: "DOI 10.1214/aoms/1177704477; content retrieval deferred by strategy-seeds/sources/AI-CODEX-WTI-MCVM-20260831/retrieval_route_20260831.json"
    quality_tier: A
    role: bibliographic_naming_context_only_no_content_or_significance_claim_transferred
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-two-sample-cramer-von-mises-rank-integrated-ecdf-exact-924-label-permutation-location-shift-recent-minus-old-median-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MCVM-20260831]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-distribution-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/integrated-squared-ecdf-rank-path]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, distribution-shift, integrated-ecdf-path, exact-label-permutation, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412550000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact strict-rank qualification is 460/924, about 5.974 decisions/year before market data and the median-direction zero guard."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY
r1_reasoning: "One durable AI-originated source ID and prompt/output trail; complete-read peer-reviewed WTI evidence; policy-deferred method bibliography; exact integrated-path/permutation trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, ties, rank path, integer score, all 924 assignments, inclusive 460 boundary, medians, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 history and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting, integer rank paths, deterministic enumeration, medians, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, banned signal indicator, or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; pairwise-distinct pooled returns; integrated squared membership path score; all 924 six-label assignments; inclusive tail count at most 460 (score at least 22); even-sample median difference; direction epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly return-distribution-shift sleeve outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, return orientation, fixed membership, strict ties, integrated path, all 924 assignments, tail cap 460, recent-median side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, pairwise_distinct_returns, pooled_rank_membership, integrated_squared_ecdf_path, exact_924_label_assignments, inclusive_tail_count_460, score_floor_22, even_sample_median_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-31 and decisions/2026-08-31_qm5_41255_wti_mcvm_distribution_shift_trend_g0.md: R1 passes through one durable AI source, a complete governed peer-reviewed WTI packet, and an explicit policy boundary on the method citation; R2 locks data, return/rank arithmetic, complete enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity across 4,754 registry rows, 1,392 cards, and 45 Wiki nodes; manual review separates MAD scale permutation, maximum signed price ECDF, Wilcoxon rank sum, Welch mean shift, and Brunner-Munzel placement families."
---

# QM5_41255 WTI Exact-Permutation Integrated-ECDF Distribution-Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Those forces can displace the distribution of
monthly WTI returns. When the newest six completed returns differ broadly
from the prior six across the entire pooled empirical-distribution path,
continue the recent block's median direction for one monthly package.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability, statistical significance, or decorrelation. Q02 owns activity
and baseline economics; later gates own robustness; unchanged Q09 alone owns
portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MCVM-20260831/source.md`, authorized by
`decisions/2026-08-31_wti_mcvm_distribution_shift_trend_source_approval.md`
at commit `e1273f93e8` before extraction.

The complete governed Moskowitz-Ooi-Pedersen packet supplies WTI membership,
monthly decisions, and own-return continuation only. Anderson (1962) is
bibliographic method context; its URL was policy-deferred, so no inaccessible
text, critical value, asymptotic distribution, or empirical result transfers.
The exact discrete score, enumeration, boundary, CFD translation, risk, stop,
and lifecycle are pre-result QM choices. The 460/924 state count is a
combinatorial activity fact, not a significance or performance claim.

## Non-duplicate boundary

The corrected-root checker found no exact identity across 4,754 EA registry
rows, 1,392 card files, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_wti_mcvm_shift_tr_preallocation_dedup_20260831.json`.

It reported one fuzzy neighbor, `QM5_41250_wti-mperm-scale-tr`, because both
enumerate 924 fixed-size labelings. The load-bearing statistic differs:
`QM5_41250` tests a recent-minus-old median-absolute-deviation scale change;
this card integrates every squared pooled-membership imbalance. A pure
location shift with stable dispersion can qualify only this card. A symmetric
scale expansion with equal block medians can qualify `QM5_41250` while this
card remains directionless.

Other neighbors are also separated:

- `QM5_41183` uses price levels and only the greatest signed ECDF gap;
- `QM5_41176` uses a price-level Wilcoxon rank sum;
- `QM5_41249` standardizes an arithmetic-mean difference by variances;
- `QM5_41251` standardizes rank-placement means by placement variances; and
- certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_RETURN_INTEGRATED_SQUARED_ECDF_PATH_EXACT_924_LABEL_TAIL460_RECENT_MEDIAN_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412550000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly thirteen immediately prior consecutive completed
  broker-month end closes, oldest to newest, from a bounded 900-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..12]`:

```text
for i = 0..11:
    r[i] = log(C[i+1] / C[i])

old    = r[0..5]
recent = r[6..11]
require all twelve pooled returns are finite and pairwise distinct

sort pooled returns ascending, preserving actual old/recent membership
old_seen = 0
recent_seen = 0
S_observed = 0
for every sorted rank k = 0..11:
    increment the actual membership count
    delta = old_seen - recent_seen
    S_observed += delta * delta

tail_count = 0
assignment_count = 0
for each 12-bit mask having exactly six set bits:
    treat set ranks as pseudo-recent and the complement as pseudo-old
    S_perm = the same integrated squared membership path
    if S_perm >= S_observed:
        tail_count += 1
    assignment_count += 1

require assignment_count == 924
require tail_count <= 460
require S_observed >= 22

median6(x): sort ascending; return (x[2] + x[3]) / 2
direction_delta = median6(recent) - median6(old)
BUY  iff direction_delta >  1e-12
SELL iff direction_delta < -1e-12
FLAT otherwise
```

Every close, logarithm, return, comparison, sort, count, score, median, and
direction difference must be finite and internally consistent. A pooled tie,
wrong assignment count, excessive tail count, score below 22, or zero median
direction consumes the month flat. Score magnitude never scales risk.

## 4. Entry Rules

- Reject an owned position or a same-magic entry deal already present for the
  current normalized broker month.
- Both news axes and legacy news mode are OFF. Friday close is OFF.
- Reject crossed or negative quotes and a genuinely positive spread above
  1,500 points. A modeled zero `.DWX` spread remains valid.
- Require valid completed-bar `ATR(20,D1)`, valid point/tick metadata, and a
  normalized stop distance of `3.5 * ATR`.
- Submit at most one market position with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one frozen broker hard stop, and no
  take-profit.

## 5. Exit Rules

- Close on the first tick whose normalized broker month differs from the
  entry month.
- Close after forty elapsed calendar days as stale repair.
- Broker hard stop remains authoritative. There is no target, opposite-
  signal exit, or same-month re-entry.

## 6. Filters (No-Trade Module)

- Fail closed on wrong symbol, timeframe, EA ID, slot, magic, unlocked input,
  risk mode, news mode, Friday-close mode, or stress state.
- Consume the month before history, signal, position, deal, spread, quote,
  ATR, stop, sizing, margin, or order checks.
- Reject malformed or current-month history, late attachment, existing owned
  exposure, a same-month entry deal, a pooled tie, invalid score/enumeration,
  zero direction, crossed quote, excessive spread, invalid ATR/stop metadata,
  or a nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic/side, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_month_returns` | 12 | locked | adjacent completed monthly log returns |
| `strategy_block_size` | 6 | locked | fixed older and recent samples |
| `strategy_assignment_count` | 924 | locked | complete six-of-twelve label space |
| `strategy_tail_count_max` | 460 | locked | inclusive upper-tail activity boundary |
| `strategy_score_min` | 22 | locked | equivalent integrated-path score floor |
| `strategy_direction_epsilon` | `1e-12` | locked | recent-minus-old median side guard |
| `strategy_history_bars` | 900 | locked | bounded D1 endpoint reconstruction |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, split, tie rule, path statistic, assignment set,
tail boundary, score floor, direction, risk, or hold after observing Q02 is
forbidden.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY | One durable AI source ID and prompt/output trail; complete-read peer-reviewed WTI evidence; deferred method citation transfers no content claim. |
| R2 | PASS | Clock, data, blocks, tie rule, path score, assignments, boundary, medians, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample rank
  instability, return ties, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed
  deterministic fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong block membership, accepted tie, wrong integrated score, an assignment
  count other than 924, wrong inclusive 460 cap or score floor 22, wrong
  recent-median direction, missing stop, wrong risk mode, same-month retry, or
  nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, endpoint integrity, rank/enumeration
  integrity, position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached integrated-path-qualified recent-median direction, one
  fixed-risk WTI order, frozen ATR hard stop, no target.
- trade_management: malformed-position repair, month rollover, and forty-day
  stale repair; no modification logic.
- trade_close: framework close helper, broker hard stop, and deterministic
  lifecycle reason mapping.

## Safety boundary

This card authorizes only one branch build, deterministic reference tests,
strict Q01, one D1 `RISK_FIXED` backtest setfile, and one paced non-live Q02
handoff if the governed CPU ceiling permits. It does not authorize a manual
tester run; live/demo/shadow/stress/optimization setfile; AutoTrading;
`T_Live`; deploy or live manifest; portfolio-gate mutation; portfolio
admission; or correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-31 | initial exact-permutation integrated-ECDF WTI card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
