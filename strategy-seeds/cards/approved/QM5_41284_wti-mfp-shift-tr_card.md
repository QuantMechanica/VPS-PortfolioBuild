---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MFP-SHIFT-20260902_S01
variant_id: AI-CODEX-WTI-MFP-SHIFT-20260902_S01
source_id: AI-CODEX-WTI-MFP-SHIFT-20260902
ea_id: QM5_41284
slug: wti-mfp-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41284_wti-mfp-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-02
created_by: Research+Development
last_updated: 2026-09-02
g0_status: APPROVED
g0_decision: decisions/2026-09-02_qm5_41284_wti_monthly_fligner_policello_shift_trend_g0.md
source_approval: decisions/2026-09-02_wti_monthly_fligner_policello_shift_trend_source_approval.md
source_author: OpenAI Codex
source_authors: OpenAI Codex; Michael A. Fligner; George E. Policello II; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Grant Schneider; Eric Chicken; Rachel Becvarik
source_citation: "OpenAI Codex (2026), WTI monthly Fligner-Policello unequal-variance rank-shift continuation; supporting records Fligner and Policello (1981), JASA 76(373), DOI 10.1080/01621459.1981.10477623; Moskowitz, Ooi, and Pedersen (2012), JFE 104(2), DOI 10.1016/j.jfineco.2011.11.003; CRAN NSM3 1.20."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly Fligner-Policello unequal-variance rank-shift continuation."
    location: strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/source.md
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_threshold_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership
  - type: peer_reviewed_statistical_method_record
    citation: "Fligner, M. A. and Policello, G. E. II (1981). Robust Rank Procedures for the Behrens-Fisher Problem. Journal of the American Statistical Association 76(373), 162-168."
    location: "DOI 10.1080/01621459.1981.10477623; publisher metadata and abstract only"
    quality_tier: A_metadata
    role: unequal_shape_rank_location_method_lineage
  - type: official_public_method_implementation
    citation: "CRAN NSM3 1.20, pFligPoli manual and R/pFligPoli.R source."
    location: "https://CRAN.R-project.org/package=NSM3; Git commit 4f610ad57ca573f82a76f413455206b0ccce2ac2, blob 9a41229d88e5ff0173ca6ec3273a3ae0dcec0834"
    quality_tier: A_method_implementation
    role: exact_pair_placement_dispersion_denominator_and_score_orientation
strategy_mechanic: monthly-wti-twenty-completed-log-returns-fixed-ten-old-ten-recent-fligner-policello-heteroskedastic-rank-location-score-absolute-threshold-0600-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MFP-SHIFT-20260902]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/unequal-shape-rank-location-shift]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/fligner-policello-pair-placement-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, rank-location-shift, fligner-policello, unequal-shape, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412840000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact pre-data distinct-rank density is 6.340 attempts/year. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_METHOD_BODY_BOUNDARY
r1_reasoning: "One durable AI-originated source ID; complete-read peer-reviewed WTI evidence; original peer-reviewed method metadata/abstract; complete pinned CRAN implementation; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed ten/ten samples, exact half-credit ties, pair placements, dispersion denominator, finite degeneracy, inclusive 0.600 boundaries, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, comparisons, finite arithmetic, square roots, ATR risk, quotes, positions, deals, and persistent state; no trained output or prohibited runtime feed."
parameters_to_test: "Locked Q02 baseline only: 21 consecutive completed month-end closes; 20 adjacent log returns; fixed old/recent blocks of 10; exact half-credit cross-block ties; source-defined p/q placement means, deviations, and p_bar*q_bar denominator; denominator epsilon 1e-12; finite directional cap 1e6; inclusive absolute score boundary 0.600; 1200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly unequal-shape rank-location sleeve outside the certified XAU/SP500/NDX/XNG book. Verify completed endpoints, log-return orientation, fixed ten/ten blocks, half-credit ties, p/q placements, dispersion denominator, finite complete separation, inclusive +/-0.600 boundaries, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_one_consecutive_completed_months, no_current_month_price, twenty_adjacent_log_returns, fixed_ten_old_ten_recent_membership, exact_half_credit_ties, source_pair_placements, source_dispersion_denominator, denominator_epsilon, finite_complete_separation_limit, inclusive_score_boundary, continuation_side, monthly_attempt_state, fixed_risk, hard_stop_present, nonnegative_spread, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-02 and decisions/2026-09-02_qm5_41284_wti_monthly_fligner_policello_shift_trend_g0.md: R1 passes with explicit method-body and synthesis boundaries; R2 locks all signal, risk, attempt, and lifecycle arithmetic; R3 uses registered native WTI D1 with continuous-CFD risk; R4 is deterministic native arithmetic only. Corrected-root dedup found no exact identity across 4,783 registry rows, 1,419 cards, and 45 Wiki nodes; fixed rank fixtures separate KS, Brunner-Munzel, Mann-Whitney, Welch, and certified XNG RSI neighbors."
---

# QM5_41284 WTI Monthly Fligner-Policello Rank-Shift Trend

## Hypothesis

WTI has physical supply, storage, transport, refining, hedging, geopolitical,
and demand drivers absent from the certified XAU, SP500, NDX, and XNG carrier
set. Slow shocks can shift the location and dispersion of completed WTI
monthly returns. When the newest ten returns dominate or trail the prior ten
under the Fligner-Policello unequal-shape pair-placement score, continue the
direction for one broker month.

This is a falsifiable direct-crude structural trend sleeve. It is not evidence
of profitability, independence, or decorrelation. Q02 owns activity and
baseline economics; unchanged Q09 alone owns portfolio overlap.

## Source Traceability And Claim Boundary

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MFP-SHIFT-20260902/source.md`, SHA-256
`401DF9A761FEAF72AB9A748B39E577A666E65AAB9B3BD2E9267DC76D701137BF`,
approved at commit `3df48ffd73` before card extraction.

Moskowitz, Ooi, and Pedersen supply the WTI carrier and monthly continuation
lineage. Fligner and Policello supply method metadata and purpose; the original
article body is not claimed read. The pinned complete CRAN source supplies the
operative score arithmetic. None tests the exact ten/ten CFD conjunction,
`0.600` boundary, risk, stop, spread, or lifecycle.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mfp_shift_tr_preallocation_dedup_20260902.json`, SHA-256
`831900D97AF2EAC1655C174FA1B4AAC94DF371DA0374A42A488D1F752FE1CF8D`,
found no exact identity across 4,783 registry rows, 1,419 cards, and 45 Wiki
nodes. Manual formula review resolves the fuzzy neighbors:

- `QM5_41183` is a six-by-six price-level KS maximum-gap statistic; this card
  averages ten-by-ten return placements and studentizes their dispersion.
- `QM5_41251` uses corrected Brunner-Munzel pooled/within-rank variance; this
  card uses Fligner-Policello pair-placement deviations and `p_bar*q_bar`.
- `QM5_41176` uses only an unstudentized Mann-Whitney total. Fixed equal-total
  allocations cross this card's boundary because placement dispersion differs.
- `QM5_41249` uses raw mean/variance; this card is pooled-rank invariant.
- `QM5_12567` is a long-only short-horizon XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_FLIGNER_POLICELLO_UNEQUAL_SHAPE_RANK_LOCATION_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`, D1, slot 0.
- Magic after governed allocation: `412840000`.
- Decision clock: first executable D1 tick after a genuine normalized broker-
  month transition, no later than 180 minutes after current D1 bar open.
- Formation: twenty-one immediately prior consecutive completed broker-month
  endpoints and twenty adjacent returns, fixed oldest/newest blocks of ten.
- Hold: next genuine broker month; forty days is stale repair.
- Expected pre-result cadence: about six positions/year. Retire below five in
  any full scored post-warm-up year.

## Exact Formula

For chronological completed-month log returns `old[0..9]` and
`recent[0..9]`:

```text
p_i = count(recent_j < old_i) + 0.5*count(recent_j == old_i)
q_j = count(old_i < recent_j) + 0.5*count(old_i == recent_j)

p_bar = sum(p_i)/10
q_bar = sum(q_j)/10
v_p = sum((p_i-p_bar)^2)
v_q = sum((q_j-q_bar)^2)

numerator = sum(q_j)-sum(p_i)
denominator = 2*sqrt(v_p+v_q+p_bar*q_bar)
score = numerator/denominator

BUY  iff score >= +0.600
SELL iff score <= -0.600
FLAT otherwise
```

At `denominator<=1e-12`, a nonzero numerator receives the finite signed limit
`+/-1e6`; a directionless state consumes flat. Every input and intermediate
must be finite. No p-value, resampling, significance statement, raw-mean
fallback, or score-sized risk exists.

Exact distinct-rank enumeration qualifies `97,616/184,756`, or `52.8351%`.
This is an activity prior only, recorded in
`artifacts/qm5_wti_mfp_shift_tr_threshold_density_20260902.json`.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
Q02 baseline. Inputs expose the locks for auditability, not optimization.

## 4. Entry Rules

1. Require exact EA ID `41284`, `XTIUSD.DWX`, D1, slot 0, magic `412840000`,
   fixed-risk inputs, both news axes OFF, legacy news OFF, and Friday close OFF.
2. Process malformed exposure and prior-month liquidation before entry-only
   gates. Evaluate only after a genuine normalized broker-month transition.
3. Persist the current broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or submission. Never retry the month.
4. Reconstruct exactly twenty-one consecutive completed month endpoints from
   at most 1,200 completed D1 bars. The newest endpoint may be at most ten days
   stale; no current-month OHLC may enter the signal.
5. Form twenty finite chronological log returns. Fix the first ten as old and
   the last ten as recent; never search or move the split.
6. Calculate exact half-credit cross-block ties, all twenty placements, both
   means and dispersions, the product term, numerator, denominator, and score.
7. Buy at or above `+0.600`; sell at or below `-0.600`; equality is included.
   Interior, directionless, malformed, or nonfinite states consume flat.
8. Require no owned exposure or same-month entry deal, positive finite Bid and
   Ask, `Ask>=Bid`, spread in `[0,1500]` points, completed ATR(20,D1), a valid
   normalized stop, and valid symbol/volume metadata.
9. Submit one market position with `RISK_FIXED=1000` and a frozen
   `3.5*ATR(20,D1)` hard stop. Use no target or second attempt.

## 5. Exit Rules

1. Close on the first processed tick of a later normalized broker month before
   considering a replacement position.
2. Close after forty elapsed calendar days as stale repair.
3. Immediately flatten duplicate, wrong-symbol, wrong-magic, invalid-side,
   missing-stop, invalid-volume, or invalid-open-time owned exposure.
4. The broker hard stop, framework kill switch, and framework close helper
   remain authoritative.
5. Friday close is disabled because the approved hold spans weekends.
6. There is no intramonth signal exit, target, trail, break-even, partial
   close, scale-in, grid, martingale, pyramid, stop-and-reverse, or
   discretionary exit.

## 6. Filters (No-Trade Module)

- Wrong host, period, identity, slot, locked input, late month start,
  duplicate state, invalid history, invalid arithmetic, interior score, quote,
  spread, ATR, sizing, or order state consumes the persisted month.
- Both news axes and legacy news are OFF; no external calendar or feed exists.
- No oscillator, moving average, raw endpoint sign, season selection,
  inventory, curve, volume, event, or price-action fallback is authorized.
- Entry-only filters never block lifecycle repair or mandatory exits.

## 7. Trade Management Rules

- Track framework MAE before any management guard can return.
- Malformed, later-month, and stale repair runs before every entry-only gate
  and remains retryable until owned exposure is flat.
- Own at most one exact slot-0 WTI position and never manage another magic.
- The entry stop and size never change; no same-month signal reversal acts on
  an open trade.
- Persist the consumed-month ledger in a terminal global variable so restart
  cannot generate a second attempt.

## Parameters To Test

| Input | Locked value | Role |
|---|---:|---|
| `strategy_month_returns` | 20 | exact adjacent return count |
| `strategy_block_size` | 10 | fixed old and recent samples |
| `strategy_score_threshold` | 0.600 | inclusive absolute activity boundary |
| `strategy_denominator_epsilon` | 1e-12 | degenerate denominator guard |
| `strategy_score_cap` | 1,000,000 | finite complete-separation limit |
| `strategy_history_bars` | 1,200 | bounded D1 endpoint scan |
| `strategy_entry_grace_minutes` | 180 | first-month-bar grace |
| `strategy_endpoint_stale_days` | 10 | newest completed endpoint cap |
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1,500 | nonnegative entry-cost guard |

No sample, formula, threshold, direction, stop, hold, spread, or lifecycle
sweep is authorized.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target, signal-magnitude sizing, risk renewal, or compounding override.
- Invalid price, stop distance, tick value, tick size, volume step, lot,
  margin, or position composition consumes the month.
- No live, demo, shadow, stress, or optimization preset is authorized.

WTI gaps, continuous-CFD roll/basis, financing, serially dependent small
samples, ties, complete separation, rank instability, threshold density, and
stop slippage can erase the premise. Q09 alone may measure book correlation.

## Data Requirements

Native `XTIUSD.DWX` D1 OHLC/timestamps, broker clock, quotes and symbol
properties, positions, deal history, and terminal-global attempt state only.
No futures curve, inventory, report feed, volume, open interest, API, CSV,
optimizer artifact, trained output, or manual signal input.

## Framework Execution Overrides

- `qm_news_temporal=QM_NEWS_TEMPORAL_OFF`.
- `qm_news_compliance=QM_NEWS_COMPLIANCE_NONE`.
- `qm_news_mode_legacy=QM_NEWS_OFF`.
- `qm_friday_close_enabled=false`.
- Framework kill switch, fixed-risk sizing, magic resolution, order services,
  MAE tracking, and exact position isolation remain mandatory.

## Exit Precedence

1. Framework kill switch or close-only instruction.
2. Malformed, duplicate, invalid-side, stopless, or invalid-metadata repair.
3. Broker hard stop.
4. New normalized broker-month exit.
5. Forty-day stale repair.
6. New entry only when flat and the current month is not consumed.

## Runtime Data Dependencies

All signal inputs are deterministic transformations of completed native MT5
D1 prices and timestamps. ATR is risk plumbing only. Nothing updates or fits
the signal from realized PnL.

## Reputable-Source Gate Findings

- R1: `PASS_WITH_AI_SYNTHESIS_AND_METHOD_BODY_BOUNDARY`.
- R2: `PASS` for the exact locked mechanical contract.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`.
- R4: `PASS`; deterministic native arithmetic only.

## Failure Modes And Kill Criteria

Retire on zero trades, any full scored post-warm-up year below five completed
positions, nonpositive governed economics, or deterministic-fixture failure.
Fail on current-month leakage, missing/duplicate month keys, wrong endpoint,
wrong return orientation or split, incorrect tie credit, placement count,
dispersion/product term, numerator, denominator, degeneracy, boundary, side,
attempt state, fixed-risk mode, hard stop, spread, or lifecycle. No after-result
rescue change is allowed.

## Execution And State Contract

- `ea_id=41284`, exact `XTIUSD.DWX`, D1, slot 0, magic `412840000`.
- Persist `QM5_41284_MONTH_ATTEMPT_<magic>` before every fallible entry gate.
- Recover persisted attempt across restarts and reconcile it with entry deals.
- A late restart consumes the new month flat; no catch-up entry.
- Exactly one active magic row and resolver mapping are mandatory before Q01.

## Portfolio Interaction

This candidate adds direct WTI exposure rather than another index, gold, or
XNG rule. That is an exposure hypothesis, not a measured correlation result.
No portfolio gate, incumbent, allocation, manifest, or waiver changes here.

## Validation Plan

1. Card schema lint and prohibited-token scan.
2. Canonical dedup receipt and separating rank fixtures.
3. Pure reference tests for endpoints, placements, ties, formula, degeneracy,
   symmetry, threshold density, risk preset, and source/card identity.
4. Strict MQL5 compile and V5 build check.
5. One canonical `RISK_FIXED` XTIUSD.DWX D1 backtest set only.
6. At most one paced Q02 enqueue below the whole-host CPU ceiling.
7. Q02 owns activity/economics; unchanged Q09 owns realized overlap.

## Framework Alignment

| Card rule | V5 location |
|---|---|
| Exact host, identity, risk/news/Friday/input locks | no-trade filter and `OnInit` |
| Month transition, endpoint reconstruction, and consumed attempt | decision-clock/history/state helpers |
| Fixed blocks, placements, dispersion, score, and side | entry signal helper |
| Frozen ATR stop and fixed-risk market request | `Strategy_EntrySignal` and framework transaction manager |
| Integrity repair, month close, and forty-day exit | `Strategy_ManageOpenPosition` |
| No discretionary signal close | `Strategy_ExitSignal` returns none |

## Safety Boundary

Authorized: one approved card, one registered V5 identity, one non-live source
build, strict Q01, and at most one paced Q02 enqueue if admitted.

Forbidden: manual tester backtests; live/demo/shadow/stress/optimization
presets; `T_Live`; AutoTrading; deploy/live manifests; portfolio-gate edits;
portfolio admission; correlation waivers; terminal control; and claims of
profitability, certification, or decorrelation before governed evidence.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-02 | initial source-complete card | G0 approved; build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-02 | APPROVED_SOURCE | `decisions/2026-09-02_wti_monthly_fligner_policello_shift_trend_source_approval.md` |
| G0 Research Intake | 2026-09-02 | APPROVED | `decisions/2026-09-02_qm5_41284_wti_monthly_fligner_policello_shift_trend_g0.md` |
| Q01 Build Validation | 2026-09-02 | NOT_BUILT | build pending |
| Q02 Baseline Screening | 2026-09-02 | NOT_ENQUEUED_Q01_PENDING | compile and Q01 pending |
