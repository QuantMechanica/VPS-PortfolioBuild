---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MAB-SCALE-20260901_S01
variant_id: AI-CODEX-WTI-MAB-SCALE-20260901_S01
source_id: AI-CODEX-WTI-MAB-SCALE-20260901
ea_id: QM5_41261
slug: wti-mab-scale-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41261_wti-mab-scale-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41261_wti_monthly_ansari_bradley_scale_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_ansari_bradley_scale_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; A. R. Ansari; R. A. Bradley; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly Ansari-Bradley symmetric-rank tail continuation; supporting records Ansari and Bradley (1960), The Annals of Mathematical Statistics 31(4), DOI 10.1214/aoms/1177705688; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.13.1 pinned at commit 44e4ebaac992fde33f04638b99629d23973cb9b2."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Ansari-Bradley symmetric-rank tail continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_method_bibliography
    citation: "Ansari, A. R. and Bradley, R. A. (1960). Rank-Sum Tests for Dispersions. The Annals of Mathematical Statistics 31(4), 1174-1189."
    location: "DOI 10.1214/aoms/1177705688; authoritative metadata and publisher access receipt strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/retrieval_route_ansari_bradley_20260901.json"
    quality_tier: A_metadata_body_access_blocked
    role: method_lineage_and_bibliography_only
  - type: primary_statistical_software
    citation: "SciPy community (2024). scipy.stats.ansari, SciPy 1.13.1 documentation and source."
    location: "scipy/scipy commit 44e4ebaac992fde33f04638b99629d23973cb9b2; retrieval receipt strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/retrieval_route_scipy_ansari_20260901.json"
    quality_tier: A
    role: symmetric_end_rank_score_scale_orientation_and_exact_no_tie_route_only
strategy_mechanic: monthly-wti-twelve-completed-log-returns-fixed-six-old-six-recent-ansari-bradley-symmetric-end-rank-score-exact-924-label-inclusive-lower-tail522-recent-six-month-cumulative-return-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MAB-SCALE-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-scale-state]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/ansari-bradley-symmetric-rank-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, symmetric-rank-tail-state, ansari-bradley, exact-label-enumeration, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412610000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6-7 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. The exact strict-rank qualification support is 522/924, about 6.779 states/year before zero cumulative returns and downstream market/execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_PRIMARY_SOFTWARE_AND_PAPER_ACCESS_BOUNDARY
r1_reasoning: "One durable AI source, complete-read peer-reviewed WTI evidence, authoritative method metadata, pinned official SciPy documentation/source, hashes, and explicit publisher-body and translation boundaries."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed blocks, strict ties, pooled order, symmetric scores, all 924 assignments, inclusive lower tail, recent-return side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting, integer rank scores, deterministic enumeration, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; fixed old/recent blocks of 6; pairwise-distinct pooled returns; symmetric rank scores 1,2,3,4,5,6,6,5,4,3,2,1; all 924 six-label assignments; actual recent score at most 21; inclusive lower-tail count at most 522; actual recent six-return cumulative direction with epsilon 1e-12; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly symmetric-rank tail-state continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, fixed labels, strict ties, mirrored rank scores, all 924 assignments, score/tail identity 21/522, recent cumulative-return side, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, fixed_six_old_six_recent_membership, pairwise_distinct_returns, symmetric_end_rank_scores, exact_924_label_assignments, inclusive_score_21, inclusive_lower_tail_522, recent_cumulative_return_direction, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41261_wti_monthly_ansari_bradley_scale_trend_g0.md: R1 passes through one durable AI source, complete governed peer-reviewed WTI evidence, authoritative method metadata, pinned official implementation evidence, and explicit access limits; R2 locks clock, data, score, enumeration, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup found no exact or fuzzy identity across 4,760 registry rows, 1,397 cards, and 45 Wiki nodes; fixed fixtures prove both decision-disagreement directions versus the closest permutation-MAD neighbor."
---

# QM5_41261 WTI Ansari-Bradley Symmetric-Rank Scale Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand drivers that are absent from the certified
index/metal carriers and materially different from natural-gas weather and
storage exposure. When the newest six completed monthly WTI returns occupy at
least as much of the pooled distribution's symmetric tails as its center,
continue their cumulative direction for one broker month.

This is an untested direct-crude structural-trend hypothesis. The rank gate is
a robust tail-occupancy state, not proof of a volatility change, significance,
profitability, or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/source.md`, approved
and committed as `0fbfcc47f8` before card extraction. Moskowitz, Ooi, and
Pedersen support only the WTI carrier, monthly clock, and own-return
continuation. Crossref and the pinned SciPy records support only method
lineage, the symmetric end-rank construction, smaller-score scale orientation,
and the finite no-tie exact route. The publisher article body was access-
blocked, so no unobserved content is claimed.

The fixed six/six sample, `522/924` boundary, cumulative-return conjunction,
continuous CFD, fixed risk, stop, spread, and lifecycle are pre-result QM
choices. No statistical or trading performance result transfers.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_mab_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`2A4F4D50F5B36A20BDCC3950C1A334615F2DEF38F42136C05EA422D4DF967E74`,
found no exact or fuzzy identity across 4,760 registry rows, 1,397 cards, and
45 Wiki nodes.

Load-bearing distinctions are:

- `QM5_41250_wti-mperm-scale-tr` recalculates magnitude-sensitive medians and
  MADs under every assignment and requires positive MAD expansion. This card
  discards spacing after sorting and uses a fixed symmetric-rank lower tail.
- `QM5_41252_wti-css-volshift-tr` searches an ordered 252-D1 cumulative-square
  variance break. This card uses twelve monthly returns, fixed six/six labels,
  no squares, and no searched time split.
- `QM5_41257_wti-mmedscore524-tr` counts recent observations only in pooled
  ranks 7..12. This card scores both tails symmetrically and can qualify with
  three recent observations above the pooled median.
- `QM5_41176_wti-mwilcoxon-shift-tr` uses monotone ranks for location. This
  card gives mirrored ranks the same score and discards signed ordering at the
  qualification gate.

On pooled values `[-5.5,-4.5,...,5.5]`, recent ranks `{1,2,3,4,5,6}` qualify
here at score/tail `21/522` while permutation MAD has zero expansion. Recent
ranks `{1,2,3,4,6,7}` are flat here at `22/629` while permutation MAD
qualifies at tail 340. These fixtures prove decision disagreement.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_ANSARI_BRADLEY_SYMMETRIC_END_RANK_EXACT_924_LOWER_TAIL522_CUMULATIVE_RETURN_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `412610000`.
- Decide only on the first executable tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of the raw host D1 bar open.
- Formation is thirteen consecutive completed month-end closes; every
  current-month price is excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is
  stale repair.
- Exact rank support is 522 of 924 assignments, about 6.779 market-free states
  per twelve attempts. Retire below five completed positions in any full
  post-warm-up year.

## Formula

For chronological completed-month closes `C[0..12]`:

```text
r[i] = ln(C[i+1] / C[i]), i=0..11
old = r[0..5]; recent = r[6..11]

require every r[i] finite and pairwise distinct
pool and sort all returns ascending while preserving old/recent labels

score(rank j) = min(j, 13-j), j=1..12
score path = 1,2,3,4,5,6,6,5,4,3,2,1
A_recent = sum(score(j) for ranks carrying actual recent labels)

tail_count = 0; assignment_count = 0
for each 12-bit mask having exactly six recent labels:
    A_perm = sum(score(j) for set-bit ranks)
    if A_perm <= A_recent: tail_count++
    assignment_count++

require assignment_count == 924
require A_recent <= 21
require tail_count <= 522

recent_return = sum(r[6..11])
BUY  iff recent_return >  1e-12
SELL iff recent_return < -1e-12
FLAT otherwise
```

All closes, logarithms, returns, sums, and comparisons must be finite. A tie,
wrong enumeration, excessive score/tail, or neutral direction consumes the
month flat. Score and return magnitudes never scale risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest close in each of the thirteen immediately prior
  consecutive broker months from a bounded 900-D1 buffer.
- Reject current-month input, missing/duplicate months, nonchronological data,
  nonpositive closes, nonfinite arithmetic, a newest endpoint more than ten
  calendar days stale, or any exact pooled return tie.
- Use only the fixed first six and last six returns, symmetric score path,
  all 924 assignments, inclusive score cap 21, lower-tail cap 522, and actual
  recent cumulative-return side.
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
6. Reconstruct thirteen consecutive completed endpoints and compute twelve
   adjacent log returns with strict invariants.
7. Sort pooled returns with labels, compute the symmetric score, enumerate
   exactly 924 assignments, enforce `21/522`, and map recent cumulative return
   to the continuation side.
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

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_block_size` | 6 | locked |
| `strategy_assignment_count` | 924 | locked |
| `strategy_score_max` | 21 | locked |
| `strategy_tail_count_max` | 522 | locked |
| `strategy_direction_epsilon` | 1e-12 | locked |
| `strategy_history_bars_d1` | 900 | locked |
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

## Source-Defined Rules

- Monthly own-return continuation is documented across liquid futures,
  including WTI membership in the source commodity universe.
- The Ansari-Bradley construction pools observations, ranks them, assigns
  symmetric end ranks, and sums one sample's scores; smaller sums correspond
  to greater dispersion for that first sample.
- The official implementation documents an exact route for small no-tie
  samples.
- No source-defined trading threshold, performance, WTI-only alpha, CFD
  equivalence, stop, risk, density, or portfolio statistic is imported.

## QM Interpretations

- Thirteen completed endpoints, fixed six/six blocks, strict tie rejection,
  exact enumeration, inclusive `21/522` boundary, cumulative-return side,
  one-month hold, ATR stop, spread cap, and consumed attempt are transparent
  pre-result choices.
- `522/924` is an activity boundary, not a p-value, critical value, or
  significance level.
- Because the blocks are not separately location-adjusted, location shift may
  affect the score. The card calls the state tail occupancy and leaves causal
  interpretation to falsification.

## Framework Execution Overrides

- Friday close is disabled to preserve the approved full-month hold.
- News temporal mode is OFF.
- News compliance profile is NONE.
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

## Risk

- Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- The position receives one frozen `3.5*ATR(20,D1)` broker hard stop and no
  target.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample rank
  instability, ties, and month-label offsets are material risks.

## Execution Assumptions

Q02 runs exact `XTIUSD.DWX` D1 with registered slot 0 magic, native quotes,
canonical tester deposit/currency defaults, and real-tick execution. The
continuous CFD is not the paper's rolling futures return and may invalidate
the edge through basis, financing, spread, or gaps.

## Failure Conditions

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, a failed symmetric-score or permutation fixture,
nondeterministic enumeration, malformed position behavior, nonpositive
governed economics, or any downstream gate failure. No threshold, side,
sample, or hold rescue is authorized.

## Expected Behavior

The EA checks once per genuine broker month, often consumes flat, and opens at
most one WTI position. It should never retry within a consumed month, hold
beyond the next month except for stale repair latency, or scale exposure with
score or return magnitude.

## Logging

Log normalized month key, endpoint keys/timestamps, twelve returns, pooled
label path, symmetric score, assignment count, lower-tail count, recent
cumulative return, chosen side, ATR/stop distance, volume, magic, order
outcome, repair action, and exit reason. Never log credentials or external
account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, and locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| endpoints, returns, sorting, symmetric score, exact tail, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes, live/demo/
shadow/stress presets, deploy/live manifests, `T_Live`, or AutoTrading.
