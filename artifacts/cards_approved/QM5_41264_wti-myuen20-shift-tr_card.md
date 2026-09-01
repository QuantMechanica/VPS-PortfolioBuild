---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MYUEN20-20260901_S01
variant_id: AI-CODEX-WTI-MYUEN20-20260901_S01
source_id: AI-CODEX-WTI-MYUEN20-20260901
ea_id: QM5_41264
slug: wti-myuen20-shift-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41264_wti-myuen20-shift-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41264_wti_monthly_yuen20_trimmed_shift_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_yuen20_trimmed_shift_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Karen K. Yuen; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; SciPy community"
source_citation: "OpenAI Codex (2026), WTI monthly fixed-block 20-percent Yuen trimmed-location shift continuation; supporting records Yuen (1974), Biometrika 61(1), DOI 10.1093/biomet/61.1.165; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003; SciPy 1.18.0 ttest_ind documentation and tag-pinned source."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI monthly fixed-block 20-percent Yuen trimmed-location shift continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/source.md"
    quality_tier: governed_source
    role: exact_trading_hypothesis_formula_activity_boundary_execution_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
  - type: peer_reviewed_statistical_method
    citation: "Yuen, K. K. (1974). The Two-Sample Trimmed t for Unequal Population Variances. Biometrika 61(1), 165-170."
    location: "DOI 10.1093/biomet/61.1.165; publisher metadata and abstract read with body access boundary"
    quality_tier: A
    role: robust_unequal_variance_trimmed_two_sample_method_identity_only
  - type: official_statistical_software
    citation: "SciPy 1.18.0 scipy.stats.ttest_ind documentation and tag-pinned scipy/stats/_stats_py.py source."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/retrieval_route_20260901.json"
    quality_tier: A_official
    role: trim_winsorized_variance_effective_sample_size_and_unequal_variance_arithmetic_only
strategy_mechanic: monthly-wti-twenty-completed-log-returns-fixed-ten-old-ten-recent-twenty-percent-yuen-trimmed-means-unequal-winsorized-variance-t-score-shift-direction-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MYUEN20-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/robust-location-regime-shift]]"
  - "[[concepts/commodity-diversification]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/yuen-trimmed-two-sample-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, robust-location-shift, yuen-trimmed-two-sample, winsorized-scale, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412640000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 5-6 completed WTI positions per full post-warm-up year under the centered continuous design prior; one consumed attempt per broker month. Q02 must prove at least five in every full scored year or retire."
expected_trades_per_year_per_symbol: 5
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE
r1_reasoning: "One durable AI-originated source ID; complete-read peer-reviewed WTI evidence; named peer-reviewed Yuen method record with explicit access boundary; complete official SciPy method and pinned-source evidence; exact trading conjunction disclosed as untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, fixed samples, sort, 20-percent trim, Winsorization, effective sample size, variance divisor, standard error, score boundary, direction, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, basis, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, sorting, finite arithmetic, square roots, comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 21 consecutive completed month-end closes; 20 adjacent log returns; fixed old/recent blocks of 10; 20-percent trim g=2 and effective size h=6; middle-six trimmed means; two-per-tail Winsorization; Winsorized variance divisor 5; unequal-variance se2; inclusive absolute score boundary 0.75; 900 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly robust-location regime sleeve outside the certified XAU/SP500/NDX/XNG book. Verify exact completed endpoints, log-return orientation, fixed ten/ten blocks, trim indices, Winsor replacements, effective sample size six, variance divisor five, unequal-variance denominator, inclusive 0.75 boundary, consumed month, fixed risk, frozen stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, twenty_one_consecutive_completed_months, no_current_month_price, twenty_adjacent_log_returns, fixed_ten_old_ten_recent_membership, sorted_copy_per_block, trim_two_each_tail, middle_six_trimmed_mean, winsor_two_each_tail, winsorized_variance_divisor_five, effective_trimmed_size_six, unequal_variance_standard_error, degenerate_variance_flat, inclusive_score_boundary, shift_direction_mapping, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41264_wti_monthly_yuen20_trimmed_shift_trend_g0.md: R1 passes with one durable AI source, complete-read peer-reviewed WTI evidence, a named peer-reviewed Yuen record, complete official SciPy method/source evidence, and explicit synthesis/access boundaries; R2 locks endpoints, returns, blocks, trim, Winsorization, variance divisor, score, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native WTI D1 with continuous-CFD risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact identity across 4,763 registry rows, 1,400 cards, and 45 Wiki nodes; fixed fixtures prove two-way decision disagreement with closest Welch neighbor QM5_41249."
---

# QM5_41264 WTI Monthly Yuen20 Trimmed-Shift Trend

## Hypothesis

WTI has physical supply, production, storage, transport, refining, hedging,
investment, geopolitical, and demand drivers absent from the certified
XAU/SP500/NDX/XNG carrier set. Slow adjustment can shift the center of monthly
WTI returns while extreme months distort raw estimates. A recent ten-month
regime whose 20%-trimmed return location has moved away from the preceding ten
months under separate Winsorized scales may persist through the next month.

This is a direct-crude structural-trend hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/source.md`, authorized by
`decisions/2026-09-01_wti_monthly_yuen20_trimmed_shift_trend_source_approval.md`
at commit `6b929669e7` before extraction. Its reproducible retrieval evidence is
`strategy-seeds/sources/AI-CODEX-WTI-MYUEN20-20260901/retrieval_route_20260901.json`.

Supporting evidence is bounded as follows:

- Moskowitz, Ooi, and Pedersen (2012) supply complete-read peer-reviewed
  monthly own-return continuation evidence and explicit NYMEX WTI membership.
- Yuen (1974) supplies the named peer-reviewed unequal-variance trimmed-
  location method; only publisher metadata and abstract are claimed read.
- SciPy 1.18.0 supplies complete public documentation and tag-pinned source
  for trim count, Winsorized variance, effective sample size, orientation,
  and unequal-variance standard error.

None tests this twenty-return sample, ten/ten split, 20% trim, `0.75`
boundary, WTI CFD, fixed risk, stop, or lifecycle. No source performance,
significance, density, cost, CFD-equivalence, correlation, or portfolio
statistic transfers.

## Source-Defined Rules

- Moskowitz, Ooi, and Pedersen support an own-return continuation effect at
  monthly horizons and explicitly include NYMEX WTI in their futures panel.
- Yuen identifies an unequal-variance two-sample comparison based on trimmed
  locations; official SciPy documentation/source fixes the tail-count,
  Winsorized-scale, effective-sample-size, and statistic arithmetic used here.
- No supporting source defines the fixed ten/ten WTI blocks, `0.75` boundary,
  CFD carrier, attempt state, ATR stop, spread ceiling, or month exit.

## QM Interpretations

- The exact fixed-block Yuen statistic is a pre-result state filter applied to
  WTI monthly log returns; it is not a source-reported trading strategy.
- Positive recent-minus-old trimmed location maps to continuation long;
  negative maps to continuation short. The score is never called a p-value or
  used to scale risk.
- `XTIUSD.DWX` is a continuous-CFD research carrier, not a matched-maturity
  futures contract. Roll, basis, financing, and month-label risks remain.
- The 21-endpoint window, ten/ten split, 20% trim, `0.75` boundary, monthly
  attempt, fixed-risk stop, spread cap, and lifecycle are locked QM choices.

## Non-duplicate boundary

The corrected-root pre-allocation checker found no exact identity across
4,763 EA registry rows, 1,400 card files, and 45 Strategy Wiki nodes. Its one
fuzzy match is the expected WTI Welch neighbor. Receipt:
`artifacts/qm5_wti_myuen20_shift_tr_preallocation_dedup_20260901.json`,
SHA-256 `8D33C19E0A75BEFCCCDF8778DD44C89A844DAE48E0FCF64E7D37520BD3C26ED7`.

- `QM5_41249` uses the most recent twelve returns in raw six/six blocks,
  ordinary means/variances, and a recent-mean sign gate.
- This card uses twenty returns in ten/ten blocks, removes two observations
  per tail from each location, replaces two observations per tail for each
  scale, uses `h=6` and divisor five, and follows the robust shift itself.
- The locked source contains one fixture that trades only here and another
  that trades only in `QM5_41249`; the reference suite freezes both.
- Rank, ECDF-distance, split-search, and scale-only WTI families retain
  different information objects and decision functions.

Verdict:
`FUZZY_WELCH_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_TEN_BY_TEN_YUEN20_TRIMMED_LOCATION_UNEQUAL_WINSORIZED_SCALE_SHIFT_CONTINUATION`.

## Rules

### Market, clock, and data

- Host and trade exact `XTIUSD.DWX` on D1, slot 0, magic `412640000`.
- Run only on the first executable D1 tick after a genuine normalized broker-
  month transition and within 180 elapsed minutes of raw current-bar open.
- Persist the new `yyyymm` attempt before every fallible entry gate. A
  restart, stop-out, invalid signal, or order failure never permits a same-
  month retry.
- Reconstruct exactly 21 immediately prior consecutive completed broker-
  month end closes, oldest to newest, from a bounded 900-D1 buffer.
- Exclude every current-month price. Require positive finite closes, strict
  chronology, exact month continuity, and a newest endpoint no more than ten
  calendar days before the current month bar.

### Exact signal

For chronological completed-month closes `C[0..20]`:

```text
for i = 0..19:
    r[i] = log(C[i+1] / C[i])

old    = sort(r[0..9])
recent = sort(r[10..19])
g = 2
h = 6

tmean(x) = sum(x[2..7]) / 6
winsor(x) = [x[2],x[2],x[2],x[3],x[4],x[5],x[6],x[7],x[7],x[7]]
wmean(x)  = sum(winsor(x)) / 10
wvar(x)   = sum((winsor(x)[i]-wmean(x))^2 for i=0..9) / 5

se2 = wvar(old)/6 + wvar(recent)/6
require se2 > 1e-18
score = (tmean(recent)-tmean(old)) / sqrt(se2)

BUY  iff score >=  0.75
SELL iff score <= -0.75
FLAT otherwise
```

Every close, logarithm, return, sorted value, sum, mean, centered difference,
variance, `se2`, square root, and score must be finite. Degenerate variance,
boundary miss, malformed endpoint, or arithmetic failure consumes the month
flat. There is no p-value, degrees-of-freedom calculation, fitted split,
pooled variance, fallback, or signal-strength sizing.

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
- Reject malformed or current-month history, late attachment, an existing
  owned position, a same-month entry deal, crossed quotes, excessive spread,
  invalid ATR/stop metadata, or a nonpositive fixed-risk size.

## 7. Trade Management Rules

- Repair malformed owned exposure before entry-only gates: duplicates, wrong
  symbol/magic, invalid volume, missing stop, or invalid open time close.
- Apply no stop modification after entry. There is no trail, break-even,
  partial close, grid, martingale, scale-in, or pyramid.

## Parameters to test

Q02 uses one locked baseline and no optimization surface:

| parameter | default | Q02 status | role |
|---|---:|---|---|
| `strategy_month_returns` | 20 | locked | adjacent completed monthly log returns |
| `strategy_block_size` | 10 | locked | fixed older and recent samples |
| `strategy_trim_each_tail` | 2 | locked | observations deleted/replaced per tail |
| `strategy_effective_size` | 6 | locked | retained location count and scale denominator input |
| `strategy_wvar_divisor` | 5 | locked | exact `h-1` Winsorized variance divisor |
| `strategy_score_floor` | `0.75` | locked | inclusive absolute score boundary |
| `strategy_min_se2` | `1e-18` | locked | degenerate-standard-error guard |
| `strategy_history_bars` | 900 | locked | bounded D1 reconstruction buffer |
| `strategy_entry_grace_minutes` | 180 | locked | first-month-bar entry window |
| `strategy_endpoint_stale_days` | 10 | locked | newest completed endpoint age ceiling |
| `strategy_atr_period` | 20 | locked | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | frozen broker hard-stop multiple |
| `strategy_stale_days` | 40 | locked | survivor repair |
| `strategy_max_spread_points` | 1500 | locked | entry execution ceiling |

Changing the return count, split, trim count, Winsorization, effective size,
variance divisor, standard error, score boundary, risk, or hold after
observing Q02 is forbidden.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled because the card holds through the broker month.
- Framework kill switch and frozen server-side hard stop: authoritative.
- Forced session flatten: none beyond month/stale lifecycle and framework
  emergency controls.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. Malformed-position repair for wrong symbol, magic, direction metadata,
   volume, stop, or open time.
3. First processed tick of a genuine new normalized broker month.
4. Forty elapsed calendar days as stale repair.
5. No target, signal-reversal, Friday, discretionary, or adaptive exit.

## Runtime Data Dependencies

- Exact chart, signal, and trade route: `XTIUSD.DWX`, D1.
- Native tester inputs only: completed D1 closes, completed D1 ATR, current
  executable quote/spread, symbol metadata, broker timestamps, positions,
  deals, and terminal-persistent attempt state.
- Completed month endpoints are reconstructed from D1; no synthesized MN1
  tester bar, current-month price, futures curve, inventory, volume, open
  interest, forecast, CSV, API, or external calendar is authorized.
- Tester account currency and fixed-risk lot sizing remain framework-owned.

## Reputable-source criteria

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE | One durable source ID; complete WTI paper record; named Yuen record with access boundary; complete public SciPy method/source evidence; explicit untested translation. |
| R2 | PASS | Clock, data, formula, blocks, trim, Winsorization, variance divisor, score, side, attempt, risk, stop, spread, and exits are exact. |
| R3 | PASS | Registered native WTI D1 and MT5 state only; roll/basis/financing/gap risks disclosed. |
| R4 | PASS | Deterministic native arithmetic only; no trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Risk and kill criteria

- Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- WTI gaps, continuous-CFD roll/basis, financing, small-sample scale
  instability, tail deletion, and month-label offsets are material risks.
- Retire on zero positions, fewer than five completed positions in any full
  post-warm-up year, nonpositive governed economics, or a failed
  deterministic fixture.
- Fail on current-month leakage, missing/duplicate months, wrong return order,
  wrong block membership, in-place chronological mutation, wrong trim index,
  wrong Winsor replacement, ordinary ten-value variance divisor, pooled
  variance, degenerate-standard-error entry, wrong score boundary, missing
  stop, wrong risk mode, same-month retry, or nondeterminism.
- Q09 alone may establish realized portfolio correlation. This card grants no
  correlation waiver or portfolio admission.

## Framework alignment

- no_trade: exact host/timeframe/ID/slot, locked inputs, fixed-risk mode,
  month grace, persistent attempt, endpoint integrity, signal integrity,
  position/deal, spread, quote, ATR, stop, and sizing guards.
- trade_entry: cached Yuen trimmed-location shift direction, one fixed-risk
  WTI order, frozen ATR hard stop, no target.
- trade_management: malformed-position repair, month rollover, and forty-day
  stale repair; no modification logic.
- trade_close: framework close helper, broker hard stop, and deterministic
  lifecycle reason mapping.

## Falsification And Requalification

Any change to the symbol, timeframe, completed-endpoint count, return
orientation, block split, sort, trim, Winsorization, effective sample size,
variance divisor, denominator, boundary, side mapping, attempt timing, risk,
stop, spread cap, or exit requires a new binary and full pipeline
requalification. Ambiguous history, arithmetic, or state fails closed. Q02
may kill the card but may not tune it; Q09 alone may establish decorrelation.

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
| v1 | 2026-09-01 | initial fixed-block Yuen20 WTI trimmed-shift card | G0 | APPROVED; build pending |

## Pipeline phase status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-01 | APPROVED; R1-R4 PASS | source approval, corrected-root dedup receipt, G0 decision, and this card |
| Q01 Build Validation | - | NOT_BUILT | pending magic allocation and exact implementation |
| Q02 Baseline Screening | - | NOT_ENQUEUED_Q01_PENDING | one paced enqueue only after strict Q01 and CPU admission |
