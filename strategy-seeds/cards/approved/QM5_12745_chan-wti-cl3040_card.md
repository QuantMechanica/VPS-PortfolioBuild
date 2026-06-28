---
ea_id: QM5_12745
slug: chan-wti-cl3040
type: strategy
strategy_id: SRC05_S07_CL3040
source_id: SRC05
source_citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading, Chapter 6, crude-oil 30/40-day combination variant."
sources:
  - "[[sources/SRC05]]"
concepts:
  - "[[concepts/crude-oil-structural-momentum-reversion]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/rolling-close-comparison]]"
  - "[[indicators/atr]]"
strategy_type_flags: [time-series-momentum, signal-reversal-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI 30/40-day Chan CL filter; expected to trade only when the 30-day pullback and 40-day trend conditions overlap into discrete signal clusters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS single Chan AT source; R2 PASS deterministic 30/40 closed-D1 close comparison with explicit flatten rule, ATR hard stop, and max-hold guard; R3 PASS XTIUSD.DWX is testable as a WTI/CL CFD proxy; R4 PASS no ML, grid, martingale, external feed, or multiple-position mechanic."
expected_pf: 1.08
expected_dd_pct: 20.0
---

# WTI Chan 30/40-Day CL Structural Filter

## Source

- Source: [[sources/SRC05]]
- Strategy lineage: `SRC05_S07` variant extracted from Chan AT Chapter 6.
- Primary citation: Chan, Ernest P. (2013), Algorithmic Trading: Winning
  Strategies and Their Rationale, Wiley Trading, Chapter 6, crude-oil 30/40
  day combination example.
- Repo evidence: `strategy-seeds/cards/chan-at-ts-mom-fut_card.md` documents
  the CL 30/40 variant under the S07 time-series momentum card.

## Concept

This card isolates the crude-oil-specific 30/40-day combination variant from
the broader Chan time-series-momentum card and ports it to `XTIUSD.DWX`. The
edge is structural rather than event-driven: it buys a short-term crude-oil
dip that remains above a longer 40-day reference, and sells the symmetric
short-term rally that remains below that longer reference.

This is deliberately different from:

- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`,
  `QM5_12708_commodity-tsmom-6m`, and `QM5_12711_commodity-tsmom-dual-6-12`:
  this is not a monthly 6/9/12-month return-sign package.
- `QM5_12594_yang-wti-reversal` and `QM5_12621_comm-reversal-4wk-xtiusd`:
  this is not a pure overreaction fade; it requires a 30-day pullback or rally
  to sit inside the opposite 40-day structural condition.
- WTI calendar/event sleeves: no weekday, month, expiry, EIA, OPEC, driving
  season, roll-window, or post-roll trigger.
- XNG natural-gas sleeves and metal ratio sleeves: the exposure is WTI crude.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 6-14 entries/year after signal clustering.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only. No futures
  curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or
  ML model is used.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Let `c0` be the prior closed D1 close.
- Let `c30` be the close `strategy_short_lookback_d1` completed D1 bars before
  `c0` (default 30).
- Let `c40` be the close `strategy_long_lookback_d1` completed D1 bars before
  `c0` (default 40).
- Long signal: BUY XTIUSD.DWX when `c0 < c30` and `c0 > c40`.
- Short signal: SELL XTIUSD.DWX when `c0 > c30` and `c0 < c40`.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit a long when the long condition is no longer true or when the short
  condition becomes true.
- Exit a short when the short condition is no longer true or when the long
  condition becomes true.
- Exit any stale position after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Require `strategy_short_lookback_d1 < strategy_long_lookback_d1`.
- Skip entries when D1 history is shorter than the long lookback plus warmup.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, spread, and Friday-close guards remain
  active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_short_lookback_d1
  default: 30
  sweep_range: [20, 25, 30, 35]
- name: strategy_long_lookback_d1
  default: 40
  sweep_range: [35, 40, 50, 60]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.25, 2.75, 3.25, 3.75]
- name: strategy_max_hold_days
  default: 20
  sweep_range: [10, 15, 20, 30]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

Chan reports the crude-oil CL variant as a 30/40-day combination rule and gives
the summary claim: "APR is 12 percent, with a Sharpe ratio of 1.1."

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 20.0.
- expected_trade_frequency: about 6-14 entries/year/symbol.
- risk_class: medium-high, because crude-oil gaps and reversals can be sharp.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- R1: PASS, single source ID `SRC05`.
- R2: PASS, entry and exit are deterministic closed-D1 close comparisons.
- R3: PASS, `XTIUSD.DWX` is available as the DWX crude-oil CFD proxy.
- R4: PASS, no ML, randomization, martingale, grid, external data, or multiple
  positions per magic number.

## Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "XTIUSD.DWX D1 only; valid lookback ordering; spread cap; standard framework news, kill-switch, and Friday close."
  trade_entry:
    used: true
    notes: "D1 30/40 closed-close condition, symmetric long/short."
  trade_management:
    used: true
    notes: "ATR hard stop plus max-hold stale-position guard."
  trade_close:
    used: true
    notes: "Close when the active 30/40 condition disappears or reverses."
hard_rules_at_risk:
  - friday_close
  - enhancement_doctrine
at_risk_explanation: |
  friday_close - D1 crude-oil positions can straddle weekends; the default V5
  Friday close is retained and must be measured in pipeline.
  enhancement_doctrine - 30/40 is source-stated; post-PASS retuning must be
  handled as a pipeline enhancement, not silent optimization.
```

## Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-06-28 | initial build | Q02 queued | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
| P1 Build Validation | 2026-06-28 | PASS | `framework/EAs/QM5_12745_chan-wti-cl3040/` |
| Q02 Baseline Screening | TBD | QUEUED | farm work item |
