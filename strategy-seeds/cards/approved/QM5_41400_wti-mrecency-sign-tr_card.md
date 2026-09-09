---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909_S01
variant_id: AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909_S01
source_id: AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909
ea_id: QM5_41400
slug: wti-mrecency-sign-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41400_wti-mrecency-sign-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-09
created_by: Research+Development
last_updated: 2026-09-09
g0_status: APPROVED
g0_decision: decisions/2026-09-09_qm5_41400_wti_monthly_recency_sign_trend_g0.md
source_approval: decisions/2026-09-09_wti_monthly_recency_sign_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI monthly fixed-recency sign-score trend; supporting record Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: governed_mechanization
    citation: "OpenAI Codex (2026). WTI monthly fixed-recency sign-score trend."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909/source.md"
    quality_tier: governed_source
    role: exact_sign_weight_score_activity_risk_and_lifecycle_contract
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_twelve_lag_horizon_and_wti_membership_only
strategy_mechanic: monthly-wti-twelve-consecutive-completed-month-return-signs-fixed-chronological-recency-weights-one-through-twelve-centered-score-inclusive-absolute18-continuation-one-month
sources:
  - "[[sources/AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/fixed-recency-sign-score]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-log-return]]"
  - "[[indicators/fixed-recency-sign-score]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, sign-score, recency-weighting, exact-sign-support, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 414000000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 6 completed WTI positions per full post-warm-up year; one consumed attempt per broker month. Exact sign-path support is 2,124/4,096, or 6.22265625 states/year before history and execution gates."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RECENCY_SIGN_TRANSLATION_RISK
r1_reasoning: "Complete-read peer-reviewed WTI monthly-trend evidence with DOI and durable retrieval hash; fixed sign weights and boundary disclosed as untested."
r2_mechanical: PASS
r2_reasoning: "Month clock, endpoints, returns, zero rule, fixed chronological weights, total, score, boundary, side, attempt, risk, stop, spread, and lifecycle are exact."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply all runtime inputs; continuous-CFD roll, basis, financing, and gaps remain risks."
r4_ml_forbidden: PASS
r4_reasoning: "Timestamps, prices, logarithms, signs, fixed integer arithmetic, ATR risk controls, quotes, positions, deals, and persistent state only."
parameters_to_test: "Locked Q02 baseline only: 13 consecutive completed month-end closes; 12 adjacent log returns; zero epsilon 1e-12; fixed chronological sign weights 1..12; weight total 78; S=sum(weight*sign); BUY at S>=18; SELL at S<=-18; exact support 2,124/4,096; 1,200 D1 history bars; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 frozen stop; 40-day stale repair; 1,500-point spread ceiling."
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
review_focus: "Falsify a direct-WTI monthly fixed-recency sign continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify endpoints, signs, chronological weights 1..12, total 78, inclusive absolute-18 sides, consumed month, fixed risk, hard stop, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, thirteen_consecutive_completed_months, no_current_month_price, twelve_adjacent_log_returns, nonzero_returns, fixed_chronological_sign_weights, weight_total_78, centered_score_invariants, inclusive_absolute18_boundary, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission and decisions/2026-09-09_qm5_41400_wti_monthly_recency_sign_trend_g0.md: R1 passes with complete-read peer-reviewed WTI lineage and explicit translation risk; R2 locks all arithmetic and lifecycle; R3 uses registered WTI D1; R4 is deterministic non-ML. Canonical dedup found no exact identity and one manually resolved signed-rank fuzzy neighbor."
---

# QM5_41400 WTI Monthly Fixed-Recency Sign Trend

## Hypothesis

WTI carries physical supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand exposure absent from the certified index/metal
book and different from natural-gas weather/storage exposure. A fixed
recency-weighted concentration of completed monthly directions may identify a
persistent crude-oil regime while refusing weakly mixed paths.

This is an untested structural-trend hypothesis, not a profitability or
decorrelation claim. Q02 owns activity and baseline economics. Unchanged Q09
alone owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The governed source packet is
`strategy-seeds/sources/AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909/source.md`.
Its parent preserves a complete read of Moskowitz, Ooi, and Pedersen (2012),
monthly own-return continuation through twelve lags, and WTI membership.

The source does not define fixed chronological sign weights or the absolute-18
boundary. Continuous-CFD translation, fixed risk, ATR stop, spread, attempt,
and lifecycle controls are QM choices. No source performance result transfers.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_wti_mrecency_sign_tr_preallocation_dedup_20260909.json` scanned
4,880 registry rows, 1,491 cards, and 45 Wiki nodes. It found no exact identity
and one fuzzy match, `QM5_41273`, at score 0.53.

- `QM5_41273` sorts absolute return magnitudes and gives each sign its
  magnitude rank; this card never sorts and assigns weight only by month age.
- `QM5_20278` retains return magnitude in a linear weighted sum; this card
  reduces each return to `+1/-1` before weighting and has a participation band.
- `QM5_13150` gives each positive month one equal vote against a 0.40 boundary;
  this card has fixed age weights and symmetric `+18/-18` boundaries.

Verdict:
`DISTINCT_WTI_TWELVE_CONTIGUOUS_FIXED_CHRONOLOGICAL_RECENCY_SIGN_SCORE_ABS18_CONTINUATION`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`, D1, slot 0, magic `414000000`.
- Decide at most once on the first executable tick after a genuine broker-
  month transition, within 180 elapsed minutes of the raw D1 bar open.
- Formation: thirteen consecutive completed broker-month-end closes.
- Hold: until the next broker month; forty elapsed days is stale repair.
- Exact sign support: 2,124/4,096, about 6.223 states per twelve attempts.
- Retire below five completed positions in any full post-warm-up year.

## Formula

For chronological completed-month closes `C[0..12]`:

```text
r[i] = ln(C[i+1]/C[i]), i=0..11
require abs(r[i]) > 1e-12
w[i] = i+1
require sum(w) = 78
S = sum(w[i] * sign(r[i]))

BUY  iff S >= 18
SELL iff S <= -18
FLAT otherwise
```

Require finite arithmetic, `S` in `[-78,78]`, and even score parity. Magnitude
and magnitude rank never affect direction or risk.

## Rules

The following entry, exit, filter, and management rules are the complete
single-configuration Q02 contract. There is no parameter sweep or fallback.

## 4. Entry Rules

1. Require exact EA ID, `XTIUSD.DWX`, D1, slot 0, registered magic, fixed-risk
   backtest mode, and every strategy input at its locked value.
2. Run malformed-position and prior-month/stale lifecycle repair before entry
   gates. Evaluate only a genuine broker-month transition.
3. Persist the normalized broker month before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. No outcome retries that month.
4. Reject owned exposure or a same-magic entry deal in the current month.
5. Reconstruct exactly thirteen immediately prior consecutive completed month
   ends, oldest first. Reject current-month data, stale newest endpoint,
   nonpositive close, bad order, missing month, or nonfinite arithmetic.
6. Form twelve adjacent chronological log returns. Reject any return inside or
   on the locked `1e-12` zero band.
7. Map returns to signs, multiply by fixed weights `1..12`, verify total 78,
   score range/parity, and trade only inclusive `S>=18` or `S<=-18`.
8. Require spread in `[0,1500]`, executable quote, completed `ATR(20,D1)`,
   valid stop/volume metadata, and sufficient fixed-risk sizing.
9. Open at most one position with a frozen `3.5*ATR(20,D1)` broker hard stop
   and no target. Score magnitude never changes risk.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized broker month before
   considering replacement risk.
3. Close after forty elapsed calendar days as stale repair.
4. Immediately close duplicate, wrong-symbol, wrong-type, invalid-volume, or
   stopless owned exposure.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, period, EA ID, slot, registered magic,
  fixed-risk mode, or locked strategy inputs.
- Framework RNG, news, and Friday inputs remain configurable and must not be
  equality-pinned by the EA. Stress probability is checked only for finiteness
  and inclusive `[0,1]` range.
- Reject consumed attempt, owned exposure, same-month entry deal, malformed
  endpoints/returns, zero return, invalid weight/total/score, sub-threshold
  score, excessive spread, invalid quote, unavailable ATR, invalid stop/volume,
  or insufficient margin.
- Runtime may not read futures curves, inventory, volume, open interest,
  files, APIs, forecasts, trained outputs, optimizer results, or portfolio
  state.

## 7. Trade Management Rules

- Maintain zero exposure or exactly one valid stop-protected WTI position.
- Preserve the original stop and close before renewal or after forty days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; future-dated tester markers are cleared.
- Lifecycle repair runs before entry-only gates on every tick.
- No randomness, adaptation, partial close, scale-in, grid, martingale, or
  pyramiding is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value | contract |
|---|---:|---|
| `strategy_endpoint_count` | 13 | locked |
| `strategy_return_count` | 12 | locked |
| `strategy_weight_start` | 1 | locked |
| `strategy_weight_step` | 1 | locked |
| `strategy_weight_total` | 78 | locked |
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

Changing the sample, sign rule, weights, score boundary, direction, carrier,
risk, stop, hold, spread, or retry contract requires a new identity.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures, include WTI, and study monthly lags through twelve. They do not claim
this fixed-recency sign score works or diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. WTI gaps, continuous-CFD roll/basis/financing, mixed
regimes, hard-stop slippage, single-energy concentration, and overlap with XNG
or risk assets can dominate the premise. The sign score is descriptive, not a
confidence estimate.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions in any full
  post-warm-up year.
- Fail on current-month leakage, missing month, reverse return, zero accepted,
  wrong weight/order/total/score/side, repeated attempt, missing stop, invalid
  risk mode, lifecycle breach, or nondeterminism.
- Retire on nonpositive governed economics or any downstream rejection.
- Never rescue failure by changing the sample, weights, boundary, direction,
  stop, hold, spread, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1 reputable-source criteria pass with disclosed translation risk.
- [x] R2 exact mechanical rules are frozen before Q02.
- [x] R3 registered native WTI D1 data is available.
- [x] R4 deterministic, non-ML, non-banned runtime only.
- [x] Dedup has no exact collision; the fuzzy family is manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/ID/slot, fixed-risk and locked strategy guards.
- trade_entry: attempt persistence, endpoint reconstruction, sign score,
  spread/quote/ATR/stop checks, and one fixed-risk order.
- trade_management: malformed-state repair, next-month close, and stale close
  before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-09-09 | initial source-bounded card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Source Approval | 2026-09-09 | APPROVED_SOURCE | `decisions/2026-09-09_wti_monthly_recency_sign_trend_source_approval.md` |
| G0 Research Intake | 2026-09-09 | APPROVED | `decisions/2026-09-09_qm5_41400_wti_monthly_recency_sign_trend_g0.md` |
| Q01 Build Validation | — | NOT_BUILT | — |
| Q02 Baseline Screening | — | NOT_ENQUEUED_Q01_PENDING | — |

## Safety Boundary

Only branch research, deterministic allocation, non-live build/Q01, and one
paced Q02 enqueue are authorized. No manual backtest, optimization, live/demo/
shadow/stress preset, terminal control, AutoTrading, `T_Live`, deployment,
live manifest, portfolio gate/admission, correlation waiver, or live use.
