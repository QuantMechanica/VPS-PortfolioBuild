---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-GBP-WGAP-TAIL-20260831_S01
variant_id: AI-CODEX-GBP-WGAP-TAIL-20260831_S01
source_id: AI-CODEX-GBP-WGAP-TAIL-20260831
ea_id: QM5_41253
slug: gbpusd-weekend-tail-fade
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41253_gbpusd-weekend-tail-fade_card.md
execution_contract_status: APPROVED
created: 2026-08-31
created_by: Research+Development
last_updated: 2026-08-31
g0_status: APPROVED
g0_decision: decisions/2026-08-31_qm5_41253_gbpusd_weekend_tail_fade_g0.md
source_approval: decisions/2026-08-31_gbpusd_weekend_tail_fade_source_approval.md
source_author: "OpenAI Codex"
source_authors: "OpenAI Codex; Thu-Mai Dao; Frank McGroarty; Andrew Urquhart"
source_citation: "OpenAI Codex (2026), GBPUSD rolling-tail weekend-gap reversal; supporting record Dao, McGroarty, and Urquhart (2016), Journal of Multinational Financial Management 37-38, DOI 10.1016/j.mulfin.2016.11.001."
source_citations:
  - type: ai_originated_governed_source
    citation: "OpenAI Codex (2026). GBPUSD rolling-tail weekend-gap reversal."
    location: "strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/source.md"
    quality_tier: governed_source
    role: exact_52_week_tail_translation_threshold_indexes_risk_and_lifecycle
  - type: peer_reviewed_trading_paper
    citation: "Dao, T.-M., McGroarty, F., and Urquhart, A. (2016). A calendar effect: weekend overreaction (and subsequent reversal) in spot FX rates. Journal of Multinational Financial Management 37-38, 158-167."
    location: "DOI 10.1016/j.mulfin.2016.11.001; complete postprint https://irep.ntu.ac.uk/id/eprint/35555/1/13113_Dao.pdf"
    quality_tier: A
    role: gbpusd_membership_weekend_gap_empirical_tail_contrarian_direction_and_weekly_hold
strategy_mechanic: weekly-gbpusd-monday-broker-d1-open-versus-prior-friday-close-log-gap-strict-outside-trailing-fifty-two-week-ten-percent-empirical-tail-contrarian-hold-to-friday
sources:
  - "[[sources/AI-CODEX-GBP-WGAP-TAIL-20260831]]"
concepts:
  - "[[concepts/fx-weekend-overreaction]]"
  - "[[concepts/empirical-tail-reversal]]"
  - "[[concepts/calendar-effect]]"
indicators:
  - "[[indicators/completed-weekend-log-gap]]"
  - "[[indicators/finite-order-statistic]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [forex, structural-reversal, weekend-gap, empirical-tail, weekly-entry, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [forex]
timeframes: [D1]
target_symbols: [GBPUSD.DWX]
primary_target_symbols: [GBPUSD.DWX]
single_symbol_only: true
logical_symbol: GBPUSD.DWX
symbol: GBPUSD.DWX
host_symbol: GBPUSD.DWX
symbol_slot: 0
symbol_slots: [0]
magic: 412530000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately 8-11 completed GBPUSD positions per full post-warm-up year; one consumed attempt per genuine broker Monday. Q02 must prove at least five in every full scored post-warm-up year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_AI_SYNTHESIS_BOUNDARY
r1_reasoning: "One durable AI source ID and one complete peer-reviewed institutional-repository paper with explicit GBP/USD membership; the 52-prior-gap 10% order-statistic translation is disclosed as an untested QM synthesis."
r2_mechanical: PASS
r2_reasoning: "Host, broker-week clock, current and historical gap identities, exact 52-sample membership, ascending sort, indexes 5/46, strict tails, side, consumed week, fixed risk, stop, spread, Friday close, and stale repair are deterministic and locked."
r3_data_available: PASS
r3_reasoning: "Registered native GBPUSD.DWX D1 history covers 2017-2026; broker D1 versus source-fix timing, holidays, DST, gaps, financing, and CFD/spot basis remain binding falsification risks."
r4_ml_forbidden: PASS
r4_reasoning: "Only native timestamps and OHLC, logarithms, finite sorting/comparisons, ATR risk, quotes, positions, deals, and persistent state; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid."
parameters_to_test: "Locked Q02 baseline only: exact GBPUSD.DWX D1; current Monday open immediately after completed Friday close; 52 prior completed Friday-close/Monday-open log gaps; ascending finite sort; strict lower index 5 and upper index 46 comparisons; contrarian side; 900 D1 history bars; 180-minute Monday-entry grace; ATR(20)*3.5 frozen hard stop; 7-day stale exit; framework Friday close at broker hour 21; 50-point entry spread ceiling."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: true
friday_close_hour_broker: 21
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a low-frequency GBPUSD weekend-overreaction sleeve outside the certified index/metal/energy book. Verify exact Friday/Monday membership, exclusion of the current gap, 52 prior gaps, sort indexes 5/46, strict ties, contrarian side, consumed week, fixed risk, frozen stop, and Friday/stale exits. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_gbpusd_carrier, broker_d1_source_fix_proxy, first_executable_monday_tick, monday_after_friday_only, current_gap_excluded, exactly_52_prior_weekend_gaps, ascending_finite_sort, lower_index_5, upper_index_46, strict_tail_comparison, contrarian_direction, weekly_attempt_state, risk_mode_dual, hard_stop_present, friday_close_enabled, seven_day_stale_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER paced-fleet mission 2026-08-31 and decisions/2026-08-31_qm5_41253_gbpusd_weekend_tail_fade_g0.md: R1 passes with one durable AI source, a complete-read peer-reviewed FX paper, explicit GBP/USD membership, and explicit 52-week/10% synthesis boundary; R2 locks gap identity, sample, sort, indexes, side, attempt, risk, stop, spread, and lifecycle; R3 uses registered native GBPUSD D1 with source-fix proxy risk; R4 uses deterministic native arithmetic only. Corrected-root canonical dedup found no exact or fuzzy identity across 4,751 registry rows, 1,389 cards, and 45 Wiki nodes; manual review separates fixed-ATR/short-hold and pre-weekend gap families."
---

# QM5_41253 GBPUSD Weekend Empirical-Tail Fade

## Hypothesis

Weekend information can push the first executable GBPUSD quote beyond the
range implied by recent weekend gaps. If that move is an overreaction, a gap
strictly outside a trailing empirical tail should reverse during the broker
week. The EA fades only those tail observations and closes on Friday.

This is a price-only structural calendar hypothesis, not evidence of
profitability or decorrelation. Q02 owns activity and baseline economics;
later gates own robustness; unchanged Q09 alone owns portfolio overlap.

## Source traceability and claim boundary

The single governed source ID resolves to
`strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/source.md`, authorized
by `decisions/2026-08-31_gbpusd_weekend_tail_fade_source_approval.md` before
card extraction. Reproducible retrieval evidence is
`strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/retrieval_route_20260831.json`.

Dao, McGroarty, and Urquhart (2016) supply peer-reviewed GBP/USD membership,
the Friday-close/Monday-open gap, empirical gap tails, contrarian direction,
and a one-week horizon. Their trading strategy uses five years of gaps and 5%
tails. This card's exact 52-gap window and 10% indexes are pre-result QM data-
availability and activity choices. No source return, alpha, significance,
drawdown, cost, crisis, spot/CFD-equivalence, or correlation result transfers.

## Non-duplicate boundary

The canonical pre-allocation checker returned `CLEAN` across 4,751 registry
identities, 1,389 cards, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_gbpusd_weekend_tail_fade_preallocation_dedup_20260831.json`.

The load-bearing differences from the closest families are:

- `QM5_10013` uses a fixed `0.35*ATR` gap threshold, gap-fill target, and
  24-hour/Tuesday exit. This card ranks 52 historical gaps and holds through
  Friday with no target.
- `QM5_12494` scans every broker-day on M1 using rolling price standard
  deviation and exits after five bars. This card is Monday-only D1 and weekly.
- `QM5_11458` enters from completed-Friday breakout structure and exits
  Monday; this card observes the Monday gap before entering and exits Friday.
- `QM5_10946` enters long before the weekend in trend direction; this card
  enters after the gap, is bidirectional, and is contrarian.

Verdict:
`DISTINCT_GBPUSD_WEEKLY_CURRENT_GAP_VERSUS_TRAILING_52_WEEK_EMPIRICAL_TAIL_CONTRARIAN_FRIDAY_EXIT`.

## Rules

### Market, clock, and data

- Host and trade exact `GBPUSD.DWX` on D1, slot 0, magic `412530000`.
- Evaluate only on the first executable tick of a current broker-Monday D1
  bar whose immediately preceding completed D1 bar is broker Friday.
- Entry must occur within 180 elapsed minutes of the current D1 bar open.
- Persist the normalized ISO-like broker-week key before all fallible gates.
  A restart, invalid history, flat signal, spread rejection, stop failure, or
  order failure never permits a same-week retry.
- Read at most 900 D1 bars. All prices must be positive and finite and all
  timestamps strictly chronological.

### Exact signal

For current Monday open `M_now` and prior Friday close `F_now`:

```text
g_now = log(M_now / F_now)
```

Reconstruct exactly 52 prior completed weekend gaps, oldest to newest. Each
observation must be a historical broker-Monday D1 open immediately following
a broker-Friday D1 close:

```text
g[i] = log(MondayOpen[i] / FridayClose[i]), i=0..51
```

Exclude the current weekend. Sort `g` ascending into `s`:

```text
lower = s[5]   // sixth smallest of 52
upper = s[46]  // sixth largest of 52

if g_now < lower: BUY
if g_now > upper: SELL
otherwise:         FLAT
```

Comparisons are strict. Threshold ties, nonfinite values, the wrong sample
count, a non-Friday/Monday pair, or an invalid sort consume the week flat.

## 4. Entry Rules

- Require no open exact-magic GBPUSD position and no later-week stale
  survivor.
- Require valid executable bid/ask and spread no greater than 50 points.
- Freeze completed-bar `ATR(20,D1)` and attach a broker-side hard stop at
  `3.5*ATR`; use no take profit.
- Backtest with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` only.
- Never scale risk with the gap or rank.

## 5. Exit Rules

- Keep framework Friday close enabled at broker hour 21.
- Close any survivor after seven calendar days and before any later week can
  enter.
- No target, trailing stop, break-even, partial close, reverse-on-signal,
  scale-in, grid, martingale, or pyramid.
- News controls may block no required exit; the Q02 baseline has both news
  axes off.

## 6. Filters (No-Trade Module)

- Do not trade when the current bar is not Monday, the entry-grace window has
  expired, the current spread exceeds 50 points, or an EA position is already
  open.
- Do not trade unless exactly 52 prior completed Friday-to-Monday gaps can be
  reconstructed and ATR(20) from the last completed D1 bar is valid.
- Do not trade when the current gap equals either empirical boundary; both
  tail tests are strict.

## 7. Trade Management Rules

- Use one position at a time, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and an
  initial hard stop at 3.5 times ATR(20).
- Do not trail, scale in, average down, or move the stop. Exit at the configured
  Friday close; the seven-day stale exit is repair-only.

## Parameters

| parameter | locked Q02 value | role |
|---|---:|---|
| `strategy_prior_gap_count` | 52 | exact historical sample |
| `strategy_lower_index` | 5 | sixth-smallest tail threshold |
| `strategy_upper_index` | 46 | sixth-largest tail threshold |
| `strategy_history_bars` | 900 | bounded D1 reconstruction |
| `strategy_entry_grace_minutes` | 180 | no late Monday catch-up |
| `strategy_atr_period_d1` | 20 | frozen hard-stop volatility |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance |
| `strategy_max_hold_days` | 7 | stale repair |
| `strategy_max_spread_points` | 50 | entry-only spread cap |
| `strategy_deviation_points` | 20 | market-order deviation |

Changing the carrier, clock, gap definition, sample size, order-statistic
indexes, strictness, side, stop, or hold requires a new card. Q02 does not
authorize a parameter rescue.

## Risk and falsification

- Expected activity is approximately 8-11 positions per full post-warm-up
  year, not a claimed result.
- Retire on zero positions, fewer than five completed positions in any full
  scored post-warm-up year, nonpositive governed economics, or any identity,
  sample, ordering, tie, side, risk, stop, or lifecycle failure.
- Broker D1 bars are a proxy for the paper's Australian-open and US-close
  fixes. DST, holidays, missing Mondays/Fridays, financing, spread, gaps, and
  CFD/spot basis can invalidate transport.
- GBPUSD adds a forex carrier absent from the certified index/metal/energy
  book; this does not establish independence.

## Strategy allowability and framework alignment

- [x] R1: complete peer-reviewed paper plus durable governed synthesis and
  explicit translation boundary.
- [x] R2: exact deterministic weekly signal and lifecycle.
- [x] R3: registered GBPUSD D1 coverage with the one-year warm-up visible to
  Q02.
- [x] R4: no banned signal indicator, ML, external runtime feed, grid,
  martingale, scale-in, or pyramid.
- [x] Backtest contract is fixed-dollar risk only.

- no_trade: exact host/timeframe, locked parameters, Monday-after-Friday,
  entry grace, attempt state, bounded history, quote, spread, ATR, and open-
  position guards.
- trade_entry: exact current gap, 52 prior gaps, finite ascending sort, strict
  order-statistic tails, contrarian market order, and frozen hard stop.
- trade_management: Friday framework close plus seven-day stale repair.
- trade_close: framework close helper and broker-side stop.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-31 | APPROVED | `decisions/2026-08-31_qm5_41253_gbpusd_weekend_tail_fade_g0.md` |
| Q01 Build Validation | pending | NOT_BUILT | pending |
| Q02 Baseline Screening | pending | NOT_ENQUEUED | pending |
