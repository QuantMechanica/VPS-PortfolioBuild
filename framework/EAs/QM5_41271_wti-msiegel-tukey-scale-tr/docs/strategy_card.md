---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901_S01
variant_id: AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901_S01
source_id: AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901
ea_id: QM5_41271
slug: wti-msiegel-tukey-scale-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41271_wti-msiegel-tukey-scale-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41271_wti_monthly_siegel_tukey_scale_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_siegel_tukey_scale_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Sidney Siegel; John W. Tukey; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; National Institute of Standards and Technology"
source_citation: "OpenAI Codex (2026), WTI monthly Siegel-Tukey alternating-extremes scale continuation; supporting records Siegel and Tukey (1960), Journal of the American Statistical Association 55(291), DOI 10.1080/01621459.1960.10482073; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; NIST Dataplot Siegel Tukey Test."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Siegel-Tukey alternating-extremes scale continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_method_bibliography
    citation: "Siegel, S. and Tukey, J. W. (1960). A Nonparametric Sum of Ranks Procedure for Relative Spread in Unpaired Samples. Journal of the American Statistical Association 55(291), 429-445."
    location: "DOI 10.1080/01621459.1960.10482073; Crossref and publisher access receipt beside the governed source"
    quality_tier: A_metadata_abstract_body_access_controlled
    role: original_method_lineage_and_scope_only
  - type: official_statistical_software_documentation
    citation: "National Institute of Standards and Technology. Dataplot: Siegel Tukey Test."
    location: "https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/siegel.htm; stable normalized-text hash in retrieval_route_20260901.json"
    quality_tier: A
    role: alternating_extremes_score_order_rank_sum_orientation_and_exact_example
strategy_mechanic: monthly-wti-sixteen-completed-month-log-returns-fixed-eight-old-eight-recent-siegel-tukey-alternating-extremes-rank-sum-exact-12870-label-inclusive-lower-tail6698-recent-eight-month-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-scale-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/siegel-tukey-alternating-extremes-rank-sum]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, alternating-extremes-rank-state, siegel-tukey, exact-label-enumeration, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412710000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. The exact strict-rank qualification support is 6698/12870, about 6.245 states/year before zero cumulative returns and downstream market/execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI source, complete-read peer-reviewed WTI evidence, original peer-reviewed method metadata with body boundary, complete official NIST algorithm evidence, hashes, and explicit no-performance boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, strict ties, alternating-extremes score path, all 12,870 assignments, inclusive 68/6698 boundary, recent-return side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting, integer rank scores, deterministic enumeration, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 17 consecutive completed month-end closes; 16 adjacent log returns; fixed old/recent blocks of 8; pairwise-distinct pooled returns; Siegel-Tukey score path 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2; all 12,870 eight-label assignments; actual recent score at most 68; inclusive lower-tail count at most 6,698; actual recent eight-return cumulative direction with epsilon 1e-12; 1,200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1,500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly alternating-extremes rank-scale continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, fixed labels, strict ties, exact score path, all 12,870 assignments, score/tail identity 68/6698, recent cumulative-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, seventeen_consecutive_completed_months, no_current_month_price, sixteen_adjacent_log_returns, fixed_eight_old_recent_membership, pairwise_distinct_returns, siegel_tukey_alternating_extremes_scores, exact_12870_label_assignments, inclusive_score_68, inclusive_lower_tail_6698, recent_cumulative_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41271_wti_monthly_siegel_tukey_scale_trend_g0.md: R1 passes through one durable AI source, complete governed peer-reviewed WTI evidence, original method metadata, complete official NIST algorithm evidence, and explicit access limits; R2 locks clock, data, score path, enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup raised QM5_41261 as one fuzzy neighbor; mandatory manual formula review and two fixed fixtures proved both decision-disagreement directions."
---

# QM5_41271 WTI Siegel-Tukey Alternating-Extremes Scale Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand drivers that are absent from the certified
index/metal carriers and materially different from natural-gas weather and
storage exposure. When the newest eight completed monthly WTI returns occupy
the more-dispersed inclusive half of the pooled Siegel-Tukey rank support,
continue their cumulative direction for one broker month.

This is an untested direct-crude structural-trend hypothesis. The rank gate is
a tail-occupancy state, not proof of a volatility change, significance,
profitability, or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MSIEGEL-TUKEY-SCALE-20260901/source.md`,
approved and committed as `2e39593ebe` before card extraction. Moskowitz,
Ooi, and Pedersen support only the WTI carrier, monthly clock, and broad own-
return continuation. Siegel-Tukey publisher metadata and the complete NIST
record support only method lineage, the alternating-extremes rank
construction, and rank-sum orientation. The original article body was
access-controlled, so no unobserved content is claimed.

The fixed eight-by-eight sample, exact `6698/12870` boundary, cumulative-
return conjunction, continuous CFD, fixed risk, stop, spread, and lifecycle
are pre-result QM choices. No statistical or trading performance result
transfers.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_msiegel_tukey_scale_tr_preallocation_dedup_20260901.json`,
SHA-256
`F3DA6AE29D70BC1BF5E210D7F61D64966A0908898DA4B2DCB6C0EBC7ACD62A72`,
found no exact identity across 4,770 registry rows, 1,407 cards, and 45 Wiki
nodes. It raised `QM5_41261_wti-mab-scale-tr` at fuzzy score
`0.7142857142857143`, requiring manual review.

Load-bearing distinctions are:

- `QM5_41261` uses twelve returns, six-by-six blocks, mirrored
  Ansari-Bradley scores, 924 assignments, and `21/522`.
- This card uses sixteen returns, eight-by-eight blocks, consecutive ranks
  assigned by alternating pooled extremes, 12,870 assignments, and
  `68/6698`.
- Chronological rank fixture
  `[7,6,1,8,14,9,5,15,2,12,3,11,4,10,16,13]` qualifies this card at 61 but
  leaves the existing card flat at 22.
- Chronological rank fixture
  `[15,14,7,3,5,10,1,11,12,6,13,8,4,2,16,9]` leaves this card flat at 74 but
  qualifies the existing card at 20.

The relevant recent returns are positive in both fixtures, proving the
disagreement is in the rank-scale qualification rather than the side gate.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_EIGHT_BY_EIGHT_SIEGEL_TUKEY_ALTERNATING_EXTREMES_RANK_SUM_EXACT_12870_LOWER_TAIL6698_RECENT_RETURN_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `412710000`.
- Decide only on the first executable tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of the raw host D1 bar open.
- Formation is seventeen consecutive completed month-end closes; every
  current-month price is excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- Exact rank support is 6,698 of 12,870 assignments, about 6.245 market-free
  states per twelve attempts. Retire below five completed positions in any
  full post-warm-up year.

## Formula

For chronological completed-month closes `C[0..16]`:

```text
r[i] = ln(C[i+1] / C[i]), i=0..15
old = r[0..7]; recent = r[8..15]

require every r[i] finite and pairwise distinct
pool and sort all returns ascending while preserving old/recent labels

ST score path = 1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2
S_recent = sum(score(j) for rank positions carrying recent labels)

tail_count = 0; assignment_count = 0
for each 16-bit mask having exactly eight recent labels:
    S_perm = sum(score(j) for set-bit ranks)
    if S_perm <= S_recent: tail_count++
    assignment_count++

require assignment_count == 12870
require S_recent <= 68
require tail_count <= 6698

recent_return = sum(r[8..15])
BUY  iff recent_return >  1e-12
SELL iff recent_return < -1e-12
FLAT otherwise
```

All closes, logarithms, returns, sums, and comparisons must be finite. A tie,
wrong score path or enumeration, excessive score/tail, or neutral direction
consumes the month flat. Score and return magnitudes never scale risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest close in each of the seventeen immediately prior
  consecutive broker months from a bounded 1,200-D1 buffer.
- Reject current-month input, missing/duplicate months, nonchronological data,
  nonpositive closes, nonfinite arithmetic, a newest endpoint more than ten
  calendar days stale, or any exact pooled return tie.
- Use only the fixed first eight and last eight returns, exact score path, all
  12,870 assignments, inclusive `68/6698`, and actual recent cumulative-
  return side.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require exact EA ID, `XTIUSD.DWX`, D1 period, slot 0, registered magic,
   fixed-risk mode, framework inputs, and every locked strategy input.
2. Process malformed-position and prior-month/stale exits before entry-only
   gates.
3. Require a genuine new broker month within the 180-minute entry window.
4. Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or order checks. No outcome retries that month.
5. Reject owned exposure or a same-magic entry deal already recorded in the
   current broker month.
6. Reconstruct seventeen consecutive completed endpoints and compute sixteen
   adjacent log returns with strict invariants.
7. Sort pooled returns with labels, apply the exact Siegel-Tukey path,
   enumerate 12,870 assignments, enforce `68/6698`, and map recent cumulative
   return to the continuation side.
8. Require spread in bounds, executable quotes, completed-bar `ATR(20,D1)`,
   valid metadata, and positive fixed-risk sizing.
9. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, and no target.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month before
   considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close malformed owned exposure immediately: duplicate, wrong symbol,
   wrong magic, invalid volume, stopless position, or invalid open time.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, period, EA ID, slot, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject a consumed attempt, owned exposure, same-month deal, malformed
  endpoints/returns/ties, wrong score or enumeration, excessive score/tail,
  neutral side, excessive spread, invalid quote, unavailable ATR, invalid
  stop/volume, or insufficient margin.
- Terminal-persistent state plus deal history prevents restart retries. Tester
  initialization clears only future or prior-run markers so historical runs
  remain deterministic.
- Runtime may not read futures chains, inventory, volume, open interest,
  files, APIs, forecasts, trained outputs, optimizer results, or portfolio
  state.

## 7. Trade Management Rules

- Maintain either zero exposure or exactly one valid stop-protected WTI
  position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  elapsed calendar days.
- Run malformed-position repair before entry-only gates on every tick.
- Restart recovery combines the terminal-persistent month marker with owned
  position and same-month deal history; no restart creates a second attempt.
- No randomness, adaptation, partial close, scale-in, grid, martingale, or
  pyramiding is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_endpoint_count` | 17 | locked |
| `strategy_return_count` | 16 | locked |
| `strategy_block_size` | 8 | locked |
| `strategy_assignment_count` | 12870 | locked |
| `strategy_score_max` | 68 | locked |
| `strategy_tail_count_max` | 6698 | locked |
| `strategy_direction_epsilon` | `1e-12` | locked |
| `strategy_history_bars_d1` | 1200 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, return definition, split, score path, tie rule,
enumeration, score/tail boundary, side, risk, stop, spread, or hold after Q02
is forbidden result-driven repair.

## Expected Behavior And Frequency

Complete assignment enumeration gives an exact market-free qualification
support of `6698/12870`, or 0.5204351204. At twelve monthly attempts this is
about 6.245 states per year before ties, neutral direction, missing data,
spread, ATR, sizing, and execution gates. This is not a WTI performance or
trade-count result. Q02 must retire the candidate if any full post-warm-up
year has fewer than five completed positions.

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- One frozen `3.5*ATR(20,D1)` broker hard stop and no target.
- Signal or score magnitude never scales exposure.
- WTI gaps can exceed the broker stop; Q02 economics and later stress gates
  own this risk.
- Both news axes, legacy news mode, and Friday close are OFF to preserve the
  approved full-month lifecycle.
- Chronological blocks overlap in market regime and are not independent
  samples. The score is a structural state, not a valid inference claim.

## Source-Defined Rules

- WTI belongs to the peer-reviewed own-return continuation universe.
- The Siegel-Tukey construction pools observations and assigns consecutive
  ranks by alternating between the low and high extremes before a rank-sum
  comparison.
- Smaller transformed-rank sums correspond to greater occupancy of pooled
  extremes for that labelled sample.
- No source defines this WTI sample, exact half-support boundary, direction,
  activity, stop, risk, CFD mapping, or portfolio statistic.

## QM Interpretations

- Seventeen completed endpoints, fixed eight-by-eight blocks, strict tie
  rejection, exact enumeration, inclusive `68/6698`, cumulative-return side,
  one-month hold, ATR stop, spread cap, and consumed attempt are transparent
  pre-result choices.
- `6698/12870` is an activity boundary, not a p-value, critical value, or
  significance level.
- Because the blocks are not separately location-adjusted, a location shift
  may affect the score. The card calls the state tail occupancy and leaves
  causal interpretation to falsification.

## Framework Execution Overrides

- Friday close is disabled to preserve the approved full-month hold.
- News temporal mode is `QM_NEWS_TEMPORAL_OFF`.
- News compliance profile is `QM_NEWS_COMPLIANCE_NONE`.
- Legacy news mode passed to framework initialization is OFF.
- Backtest risk is fixed 1,000 account-currency units; percentage risk is zero.
- Stress rejection probability is zero in the canonical set.

## Exit Precedence

1. Framework kill switch and hard-stop enforcement.
2. Malformed-position integrity repair.
3. New-broker-month close.
4. Forty-day stale close.
5. Entry-only history, signal, news, spread, quote, ATR, sizing, and margin
   gates.
6. New single-position entry.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and one
terminal-persistent attempt marker. No external runtime dataset exists.

## Failure Conditions

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, failed NIST/formula fixture parity, nondeterministic score
or enumeration output, malformed position behavior, nonpositive governed
economics, or any downstream gate failure. No threshold, side, sample, or
hold rescue is authorized.

## Logging

Log normalized month key, decision bar, label offset, endpoint/return counts,
score, tail count, assignment count, recent return, chosen side, attempt
state, ATR/stop distance, volume, magic, order outcome, repair action, and
exit reason. Never log credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, and locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| completed month endpoints/returns, strict sorting, score path, enumeration, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes,
live/demo/shadow/stress presets, deploy/live manifests, `T_Live`, or
AutoTrading.
