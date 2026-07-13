---
strategy_id: OWNER-FTMO-SURVIVORS-20260711_S05
source_id: OWNER-FTMO-SURVIVORS-20260711
ea_id: QM5_13138
slug: xau-m5-ema20
status: APPROVED
created: 2026-07-11
created_by: Codex
last_updated: 2026-07-11
g0_status: APPROVED
source_citation: "OWNER FTMO survivor handoff dated 2026-07-11; immutable research evidence under .private/secret_strategy_lab/xau_m5_ema20_impulse_harvest/."
source_citations:
  - type: owner_originated_research
    citation: "OWNER FTMO survivor handoff, 2026-07-11"
    location: "strategy-seeds/sources/OWNER-FTMO-SURVIVORS-20260711/README.md"
    quality_tier: INTERNAL
    role: primary
target_symbols: [XAUUSD.DWX]
primary_target_symbols: [XAUUSD.DWX]
markets: [metals, gold, intraday]
timeframes: [M5]
period: M5
single_symbol_only: true
expected_trade_frequency: "Approximately 40-55 completed trades/year; 310 exact MT5 trades across 2018H2-2025."
expected_trades_per_year_per_symbol: 45
expected_pf: 1.25
expected_dd_pct: 20.0
risk_class: high
ml_required: false
r1_track_record: PASS
r1_reasoning: "Exactly one OWNER source_id and an immutable local evidence trail."
r2_mechanical: PASS
r2_reasoning: "Completed-bar EMA cross and Heikin-Ashi confirmation, delayed target, 10pct stop and fixed 5760-bar exit are deterministic at about 45 trades/year."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX M5 has registered tester data; all indicators derive from native OHLC."
r4_ml_forbidden: PASS
r4_reasoning: "Long-only and one position per magic with no ML, grid, martingale or PnL adaptation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal]
hard_rules_at_risk: [friday_close, long_holding_period, wide_stop, floating_mae, current_ftmo_xau_cost]
g0_approval_reasoning: "R1 single OWNER source; R2 frozen completed-bar EMA/HA entry and fixed stop/target/time exit; R3 native XAU M5; R4 deterministic one-position non-ML; dedup clean."
---

# XAU M5 EMA20 Asymmetric Impulse Harvest

## Hypothesis

Bullish EMA20/EMA50 transitions confirmed by a bullish Heikin-Ashi signal can
start multi-session gold impulses. A delayed 1% target allows the impulse to
mature while a wide catastrophe stop defines fixed initial risk.

## Source And Evidence Boundary

The single source is the OWNER handoff dated 2026-07-11. Source URL:
`local://OWNER-FTMO-SURVIVORS-20260711`. Research provenance is
`.private/secret_strategy_lab/xau_m5_ema20_impulse_harvest/`. The rule was
selected with visibility across all segments, so Q02 is falsification, not a
pristine-OOS confirmation.

## Markets And Timeframe

- Target symbol: `XAUUSD.DWX`, magic slot 0.
- Host and signal timeframe: M5.
- Expected frequency: 45 trades/year/symbol.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.

## 4. Entry Rules

- Evaluate on each new M5 bar using completed bars only.
- Require `EMA20[2] <= EMA50[2]` and `EMA20[1] > EMA50[1]`.
- Reconstruct Heikin-Ashi over 200 completed M5 bars and require the latest
  HA close above HA open and above `EMA20[1]`.
- Enter long at the current M5 market open.
- Attach a catastrophe stop 10.0% below entry.
- Require valid warm-up, prices, risk clearance and no existing position.
- No shorts, signal exit, scale-in or same-position re-entry.

## 5. Exit Rules

- During the first 12 M5 bars after entry, no profit target is active.
- Thereafter, close immediately when bid reaches `entry * 1.01`.
- On the first new M5 bar at or after 5,760 held M5 bars, close at market.
- The 10% broker hard stop remains authoritative throughout.
- No indicator, Friday, trailing or break-even exit is allowed.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` M5 or an invalid magic slot.
- Require at least 200 completed M5 bars, valid EMA20/EMA50 values and complete
  HA reconstruction.
- Framework kill switch and risk-mode checks remain authoritative.
- Friday flattening is disabled because it invalidates the frozen long hold.
- Entry-only news filtering must never block target, time or hard-stop exits.

## 7. Trade Management Rules

- Exactly one position is allowed for the registered magic.
- Target management runs on every tick after the 12-bar delay.
- Do not partially close, pyramid, recover, average, grid or adapt parameters.
- Floating MAE and current FTMO XAU commission/swap must be reconstructed before
  any book admission.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_fast_ema_m5` | 20 | [20] |
| `strategy_mid_ema_m5` | 50 | [50] |
| `strategy_ha_warmup_bars` | 200 | [200] |
| `strategy_stop_pct` | 10.0 | [10.0] |
| `strategy_target_pct` | 1.0 | [1.0] |
| `strategy_target_delay_bars` | 12 | [12] |
| `strategy_max_hold_bars` | 5760 | [5760] |

## Kill Criteria

Retire below current-cost PF 1.20 in either pre-holdout or holdout, on excessive
floating MAE, nondeterminism, minimum-lot risk distortion, or cost sensitivity.
No stop, target, delay or hold-time rescue is authorized before baseline.
