---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901_S01
variant_id: AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901_S01
source_id: AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901
ea_id: QM5_41273
slug: wti-msigned-rank-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41273_wti-msigned-rank-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41273_wti_monthly_signed_rank_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_signed_rank_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; R Core Team"
source_citation: "OpenAI Codex (2026), WTI monthly strict signed-rank trend continuation; supporting records Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; pinned R Core Team stats wilcox.test implementation and manual at commit bac583951b728e97b9786804d3b4081f0fe18df5."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly strict signed-rank trend continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_twelve_lag_horizon_and_explicit_wti_membership_only
  - type: primary_statistical_software
    citation: "R Core Team. stats::wilcox.test implementation and manual."
    location: "R source commit bac583951b728e97b9786804d3b4081f0fe18df5; complete-read hashes preserved in strategy-seeds/sources/KELOHARJU-WILCOXON-WTI-SAMECAL-SR-2026/source.md"
    quality_tier: A
    role: one_sample_signed_absolute_rank_arithmetic_only
strategy_mechanic: monthly-wti-twelve-consecutive-completed-month-log-returns-strict-absolute-ranks-centered-wilcoxon-signed-rank-score-inclusive-absolute18-continuation-one-month
sources:
  - "[[sources/AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/nonparametric-signed-rank]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/signed-absolute-rank-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, signed-rank, exact-sign-support, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412730000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact strict-rank sign-assignment support is 2,124/4,096, or 6.22265625 states/year before history, ties, and market/execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMPOSITE_SOURCE_AND_CONTINUOUS_CFD_TRANSLATION_RISK
r1_reasoning: "One durable AI source, complete-read peer-reviewed WTI evidence, complete pinned primary-software arithmetic, hashes, and an explicit no-performance/no-inference boundary."
r2_mechanical: PASS
r2_reasoning: "Month clock, thirteen endpoints, twelve returns, zero and absolute-tie rejection, strict ranks, centered integer score, inclusive absolute-18 boundary, side, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, finite sorting, integer ranks, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; zero epsilon 1e-12; pairwise-distinct absolute returns; strict ranks 1..12; V_plus positive-rank sum; T=78; S=2*V_plus-78; BUY at S>=18; SELL at S<=-18; exact sign support 2,124/4,096; 1,200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1,500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly signed-rank continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, return orientation, zero/tie handling, strict absolute ranks, T=78, S=2V-78, inclusive absolute-18 sides, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, nonzero_returns, pairwise_distinct_absolute_returns, strict_absolute_ranks, positive_rank_sum, centered_score_invariants, inclusive_absolute18_boundary, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41273_wti_monthly_signed_rank_trend_g0.md: R1 passes through one durable AI source, complete governed peer-reviewed WTI evidence, complete pinned R Core method evidence, and explicit claim limits; R2 locks clock, data, ranks, score, boundary, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root dedup returned CLEAN; mandatory semantic review and fixed fixtures separate the same-calendar signed-rank, cumulative-return, zero-threshold, sign-count, and two-sample rank-sum neighbors."
---

# QM5_41273 WTI Monthly Signed-Rank Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand drivers that are absent from the certified
index/metal carriers and materially different from natural-gas weather and
storage exposure. When the rank-weighted signs of the latest twelve completed
monthly WTI returns show sufficient directional concentration, continue that
direction for one broker month.

This is an untested direct-crude structural-trend hypothesis. The signed-rank
score is a deterministic state, not proof of a location shift, significance,
profitability, or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MSIGNED-RANK-TREND-20260901/source.md`,
approved and committed as `3203deb0df` before card extraction. Moskowitz,
Ooi, and Pedersen support only the WTI carrier, monthly clock, twelve-lag
trend horizon, and broad own-return continuation. The pinned R Core record
supports only one-sample signed absolute-rank arithmetic.

Neither source tests the exact WTI-only conjunction. The contiguous twelve-
return sample, strict zero/tie rejection, centered score, activity boundary,
continuous CFD, fixed risk, stop, spread, and lifecycle are pre-result QM
choices. No statistical or trading performance result transfers.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_msigned_rank_tr_preallocation_dedup_20260901.json`, SHA-256
`AE49BB417E6B8D35EEFBF8EA86FB6B3E1C3786ADACAF62FA6AA2F51EADBCE337`,
found no exact or above-threshold fuzzy identity across 4,772 registry rows,
1,408 cards, and 45 Wiki nodes.

Load-bearing distinctions are:

- `QM5_41191` uses disjoint same-calendar returns and no absolute-score gate;
  this card uses twelve contiguous latest returns and `|S|>=18`.
- Eleven positive returns `.01..11` plus one `-1.00` make this card buy at
  `S=54` while pure twelve-month cumulative-return momentum sells. Negation
  proves the opposite disagreement.
- Positive absolute ranks `{7,10,11,12}` produce `S=2`; a zero-threshold
  signed-rank rule buys while this card stays flat.
- Positive ranks `1..7` and negative ranks `8..12` give seven positive months
  but `S=-22`, so a sign-count rule and this card choose opposite states.
- `QM5_41176` compares fixed old and new blocks through a two-sample rank sum;
  this card is a one-sample signed absolute-rank functional.

Verdict:
`DISTINCT_WTI_MONTHLY_TWELVE_CONTIGUOUS_STRICT_SIGNED_ABSOLUTE_RANK_SCORE_ABS18_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `412730000`.
- Decide only on the first executable tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of the raw host D1 bar open.
- Formation is thirteen consecutive completed month-end closes; every current-
  month price is excluded.
- Hold to the next broker-month boundary; forty elapsed calendar days is stale
  repair.
- Exact sign support is 2,124 of 4,096 assignments, about 6.223 market-free
  states per twelve attempts. Retire below five completed positions in any
  full post-warm-up year.

## Formula

For chronological completed-month closes `C[0..12]`:

```text
r[i] = ln(C[i+1] / C[i]), i=0..11

require every r[i] finite and abs(r[i]) > 1e-12
require every pair abs(r[i]), abs(r[j]) distinct beyond 1e-12
rank abs(r) strictly from 1 through 12

V_plus = sum(rank(abs(r[i])) for each r[i] > 0)
T = 12*13/2 = 78
S = 2*V_plus - T

require sum(all ranks) == 78
require -78 <= S <= 78

BUY  iff S >= 18
SELL iff S <= -18
FLAT otherwise
```

All closes, logarithms, returns, absolute values, and comparisons must be
finite. A zero return, absolute tie, broken rank invariant, or sub-threshold
score consumes the month flat. Score magnitude never scales risk.

## Rules

- Consume the normalized broker month before every fallible entry gate.
- Select the latest close in each of the thirteen immediately prior
  consecutive broker months from a bounded 1,200-D1 buffer.
- Reject current-month input, missing or duplicate months, nonchronological
  data, nonpositive closes, nonfinite arithmetic, a newest endpoint more than
  ten calendar days stale, any epsilon-zero return, or any absolute tie.
- Use only strict ranks 1 through 12, `T=78`, `S=2*V_plus-78`, and the exact
  inclusive `+18/-18` sides.
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
7. Rank absolute returns, compute `V_plus`, verify `T=78` and the centered
   score, then map only `S>=18` to BUY and `S<=-18` to SELL.
8. Require spread in bounds, executable quotes, completed-bar `ATR(20,D1)`,
   valid metadata, and positive fixed-risk sizing.
9. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, and no target.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month before
   considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Close malformed owned exposure immediately: duplicate, wrong symbol, wrong
   magic, invalid volume, stopless position, or invalid open time.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact symbol, period, EA ID, slot, fixed-risk,
  news/Friday, stress, or locked-input contract.
- Reject a consumed attempt, owned exposure, same-month deal, malformed
  endpoints/returns, zeros/ties, broken ranks, sub-threshold score, excessive
  spread, invalid quote, unavailable ATR, invalid stop/volume, or insufficient
  margin.
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
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_total_rank_sum` | 78 | locked |
| `strategy_score_abs_min` | 18 | locked |
| `strategy_zero_epsilon` | `1e-12` | locked |
| `strategy_history_bars_d1` | 1200 | locked |
| `strategy_entry_window_minutes` | 180 | locked |
| `strategy_max_endpoint_gap_days` | 10 | locked |
| `strategy_atr_period_d1` | 20 | locked |
| `strategy_atr_sl_mult` | 3.5 | locked |
| `strategy_max_hold_days` | 40 | locked |
| `strategy_max_spread_points` | 1500 | locked |
| `strategy_deviation_points` | 20 | locked |

Changing the sample, return definition, zero/tie rule, rank convention, score
boundary, side, risk, stop, spread, or hold after Q02 is forbidden result-
driven repair.

## Expected Behavior And Frequency

Complete sign enumeration gives exact support `2124/4096`, or 0.5185546875.
At twelve monthly attempts this is 6.22265625 states per year before history,
ties, spread, ATR, sizing, and execution gates. This is not a WTI performance
or trade-count result. Q02 must retire the candidate if any full post-warm-up
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
- Consecutive returns need not be independent. The score is a structural
  state, not a valid inference claim.

## Source-Defined Rules

- WTI belongs to the peer-reviewed own-return continuation universe.
- The source horizon includes monthly lags through twelve.
- The R Core one-sample statistic ranks absolute observations and sums ranks
  attached to positive observations.
- No source defines this exact sample, centered activity boundary, CFD
  mapping, stop, risk, or portfolio statistic.

## QM Interpretations

- Thirteen completed endpoints, twelve adjacent returns, strict zero/tie
  rejection, centered `S=2V-78`, inclusive `|S|>=18`, one-month hold, ATR
  stop, spread cap, and consumed attempt are transparent pre-result choices.
- `2124/4096` is an activity boundary, not a p-value, critical value, or
  significance level.
- Signed absolute ranks deliberately discard metric magnitude after ordering;
  Q02 must falsify whether that robustness helps net WTI economics.

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
post-warm-up year, failed formula/distribution fixture parity, nondeterministic
rank or score output, malformed position behavior, nonpositive governed
economics, or any downstream gate failure. No threshold, side, sample, or hold
rescue is authorized.

## Logging

Log normalized month key, decision bar, endpoint/return counts, positive-rank
sum, total rank sum, centered score, chosen side, attempt state, ATR/stop
distance, volume, magic, order outcome, repair action, and exit reason. Never
log credentials or external account data.

## Framework Alignment

| card rule | module / implementation target |
|---|---|
| framework, risk, news, Friday, stress, and locked-input contract | `Strategy_NoTradeFilter` plus `OnInit` framework validation |
| completed month endpoints/returns, zero/tie checks, strict ranks, score, side, quote, ATR, and sizing | `Strategy_EntrySignal` and bounded helpers |
| malformed-position, new-month, and forty-day repair | `Strategy_ManageOpenPosition` |
| lifecycle reason mapping | `Strategy_ExitSignal` plus framework close helper |
| both news axes OFF | `Strategy_NewsFilterHook` and framework initialization |

## Status

`APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does not
authorize optimization, portfolio admission, threshold changes,
live/demo/shadow/stress presets, deploy/live manifests, `T_Live`, or
AutoTrading.
