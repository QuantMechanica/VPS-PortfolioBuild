---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-WTI-MDAILY-MEANLOC-20260901_S01
variant_id: AI-CODEX-WTI-MDAILY-MEANLOC-20260901_S01
source_id: AI-CODEX-WTI-MDAILY-MEANLOC-20260901
ea_id: QM5_41262
slug: wti-mdaily-meanloc-tr
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41262_wti-mdaily-meanloc-tr_card.md
execution_contract_status: APPROVED
created: 2026-09-01
created_by: Research+Development
last_updated: 2026-09-01
g0_status: APPROVED
g0_decision: decisions/2026-09-01_qm5_41262_wti_monthly_daily_mean_location_trend_g0.md
source_approval: decisions/2026-09-01_wti_monthly_daily_mean_location_trend_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "OpenAI Codex (2026), WTI completed-month daily mean-location continuation; supporting carrier evidence Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). WTI completed-month daily mean-location continuation."
    location: "strategy-seeds/sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901/source.md"
    quality_tier: governed_source
    role: exact_hypothesis_formula_activity_boundary_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_explicit_wti_membership_only
strategy_mechanic: normalized-broker-month-wti-immediately-completed-17-to-23-d1-closes-final-close-versus-arithmetic-mean-strict-sign-one-month-continuation
sources:
  - "[[sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/crude-oil-structural-trend]]"
  - "[[concepts/within-month-path-location]]"
indicators:
  - "[[indicators/completed-month-close-mean-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, path-location, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
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
magic: 412620000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 12 decisions and up to 12 positions per full post-warm-up year; exact equality is expected to be rare, while history and execution gates may reduce realized activity."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r1_reasoning: "Durable AI prompt/output/source lineage plus complete-read peer-reviewed monthly WTI continuation evidence with explicit translation and performance boundaries."
r2_mechanical: PASS
r2_reasoning: "Clock, buffer, month normalization, observation count, boundary proof, arithmetic mean, strict sign, attempt, risk, stop, spread, and lifecycle are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native XTIUSD.DWX D1 and MT5 state supply every runtime input; continuous-CFD roll, financing, gap, and broker-month-label risks remain."
r4_ml_forbidden: PASS
r4_reasoning: "Native timestamps, close levels, bounded arithmetic, comparisons, ATR risk, quotes, positions, deals, and persistent state only; no trained output, banned signal indicator, external feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: 45 D1 history bars; immediately completed normalized month; 17-23 closes; older boundary bar required; arithmetic mean; final-close location epsilon 1e-12; 180-minute entry grace; ATR(20)*3.5 frozen stop; 40-day stale exit; 1500-point spread ceiling; 20-point order deviation."
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
review_focus: "Falsify a direct-WTI completed-month path-location continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify normalized month membership, boundary proof, final/mean orientation, consumed month, fixed risk, frozen stop, next-month lifecycle, and decision disagreement. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_wti_carrier, first_tradable_month_bar, no_current_month_price, completed_month_all_closes, session_count_17_23, older_boundary_proof, arithmetic_mean_close, newest_close_orientation, strict_epsilon_sign, monthly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_disabled, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-01 and decisions/2026-09-01_qm5_41262_wti_monthly_daily_mean_location_trend_g0.md: R1-R4 pass; corrected-root dedup found no exact or fuzzy identity across 4,761 registry rows, 1,398 cards, and 45 Wiki nodes; fixed fixtures prove decision disagreement with raw-return and median-return neighbors."
---

# QM5_41262 WTI Completed-Month Daily Mean-Location Trend

## Hypothesis

The final WTI daily close's location relative to the arithmetic mean of all
daily closes in that same completed broker month captures late-month price
acceptance. Continue the strict sign for one broker month. This is an untested
direct-crude structural hypothesis. Q02 owns activity and economics; later
gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source and duplicate boundary

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901/source.md`,
approved and committed before extraction. The peer-reviewed paper supports
only the monthly WTI continuation carrier; every exact formula and execution
choice here is a pre-result QM interpretation.

The canonical dedup receipt is `CLEAN`. Unlike `QM5_13100`, this rule does not
average six month-end points; unlike `QM5_41133`, it does not form or sort
daily returns; unlike `QM5_41105`, it uses no highs/lows; unlike `QM5_41130`,
it uses no month open or residence count; unlike `QM5_20187`, its signal is
not the boundary-to-endpoint return. Fixed disagreement fixtures are required
in the reference test.

## Formula

For chronological closes `C[0..n-1]` from the immediately completed month:

```text
require 17 <= n <= 23
require an older bar proving the month boundary
mean_close = sum(C) / n
location = C[n-1] / mean_close - 1
BUY  iff location >  1e-12
SELL iff location < -1e-12
FLAT otherwise
```

Every timestamp, close, sum, mean, and ratio must be valid and finite. The
current month is excluded. Signal magnitude never scales risk.

## Rules

- Exact host/traded symbol `XTIUSD.DWX`, period D1, slot 0, magic `412620000`.
- Evaluate only after a genuine normalized broker-month transition and within
  180 elapsed minutes of the raw D1 bar open.
- Read 45 D1 bars; require every completed-month close, 17-23 observations,
  chronological timestamps, and one older boundary-proving bar.
- Persist current `yyyymm` before history, signal, news, spread, quote, ATR,
  sizing, margin, or order checks. No retry that month.
- Both news axes, legacy news mode, Friday close, and stress rejection are OFF.
- Runtime uses no external data, optimization result, or portfolio state.

## 4. Entry Rules

1. Fail closed unless EA ID, symbol, D1, slot, registered magic, framework
   inputs, fixed-risk mode, and every locked strategy input match the card.
2. Repair malformed exposure and process month/stale exits before entry gates.
3. Require a genuine month transition inside the 180-minute window.
4. Consume and persist the month before all fallible gates.
5. Reject owned exposure or a same-magic entry deal in the current month.
6. Load and validate the completed-month close path and boundary proof.
7. Compute the arithmetic mean and strict signal side exactly once.
8. Require spread, quote, completed-bar ATR, metadata, volume, and margin.
9. Open at most one fixed-risk position with a frozen hard stop and no target.

## 5. Exit Rules

1. Framework kill switch and broker hard stop remain authoritative.
2. Close on the first processed tick in a later normalized month.
3. Close after forty elapsed calendar days as stale repair.
4. Close malformed owned exposure immediately.
5. No intramonth flip, target, trail, break-even, partial close, Friday close,
   news exit, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

Fail closed on contract mismatch, consumed attempt, owned exposure,
same-month deal, malformed month history, wrong count, missing boundary proof,
nonfinite arithmetic, neutral sign, excessive spread, invalid quote,
unavailable ATR, invalid stop/volume, or insufficient margin. Tester init may
clear only future/prior-run attempt markers so historical runs remain
deterministic.

## 7. Trade Management Rules

Maintain zero exposure or exactly one valid stop-protected WTI position.
Preserve its original stop and close before renewal or after forty days.
Restart recovery combines terminal-persistent month state, owned positions,
and same-month deal history. No randomness or adaptation is authorized.

## 8. Parameters To Test

Q02 has one locked baseline and no optimization surface:

| input | value |
|---|---:|
| `strategy_history_bars_d1` | 45 |
| `strategy_min_month_sessions` | 17 |
| `strategy_max_month_sessions` | 23 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_direction_epsilon` | 1e-12 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_max_hold_days` | 40 |
| `strategy_max_spread_points` | 1500 |
| `strategy_deviation_points` | 20 |

Changing the path statistic, count bounds, sign, hold, risk, stop, or spread
after Q02 is forbidden result-driven repair.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. One frozen `3.5*ATR(20,D1)` broker stop and no target.
WTI gaps, roll/basis, financing, spread, sparse month transitions, and broker
month-label offsets are material risks.

## Failure conditions and status

Retire on zero positions, fewer than ten completed positions in any full
post-warm-up year, a failed arithmetic or disagreement fixture, malformed
position behavior, nonpositive governed economics, or downstream gate
failure. No parameter rescue is authorized.

Status: `APPROVED_FOR_BRANCH_BUILD_AND_NON_LIVE_Q01_Q02_ONLY`. This card does
not authorize optimization, portfolio admission, live/demo/shadow/stress
presets, deploy/live manifests, `T_Live`, AutoTrading, terminal control, or
portfolio-gate changes.
