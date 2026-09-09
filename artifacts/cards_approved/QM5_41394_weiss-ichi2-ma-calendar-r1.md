---
ea_id: QM5_41394
slug: weiss-ichi2-ma-calendar-r1
type: strategy
source_id: 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
source_citation: "Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 3, pp. 52-53, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems"
sources:
  - "[[sources/weissman-mechanical-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators: [SMA]
target_symbols: [EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, SP500.DWX, XTIUSD.DWX]
period: D1
expected_trade_frequency: "Daily 9/26 SMA crossover with 26-day SMA slope confirmation; use 10 trades/year/symbol conservatively."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-09
g0_approval_authority: "OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909; receipt 70823296-549a-4fba-8d2d-68ef34607664"
g0_approval_reasoning: "OWNER authorized a brand-new EA identity using the already-approved Weissman mechanics, current V5 template, and current calendar-input bundle; no prior pipeline verdict or evidence is inherited."
---

# Weissman Ichimoku Two Moving Average Crossover — Calendar Bundle Rebuild

## Identity boundary

`QM5_41394` is a brand-new runtime and research identity authorized by `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909` (receipt `70823296-549a-4fba-8d2d-68ef34607664`). It reuses only the source-approved mechanical rules below. It inherits no Q02-Q09 result, verdict, optimization claim, trial count, binary, setfile binding, or evidence from any earlier identity.

## Source

- Source: [[sources/weissman-mechanical-trading-systems]]
- Citation: Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, "Ichimoku Two Moving Average Crossover", pp. 52-53. Web text: https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems.
- Source location: Chapter 3 defines a 9/26 SMA crossover with the 26-day average required to slope in the entry direction before reversing.

## Mechanics

### Entry

- Evaluate on completed D1 bars.
- Long when `SMA(9)[1] > SMA(26)[1]` and `SMA(26)[1] > SMA(26)[2]`; close any short and enter long.
- Short when `SMA(26)[1] < SMA(9)[1]` and `SMA(26)[1] < SMA(26)[2]`; close any long and enter short.

### Exit

- Stop and reverse on the opposite qualified signal.
- No profit target in the source.
- V5 safety controls provide Friday close and max-hold behavior only; no adaptive exit is added.

### Stop loss

- The source system is stop-and-reverse without a fixed stop.
- V5 safety fallback: catastrophic stop at `max(3 * ATR(20,D1), broker minimum)`.

### Position sizing

- Backtest baseline: `RISK_FIXED = 1000` and `RISK_PERCENT = 0`.
- Any live risk requires a future, separate OWNER-approved promotion; this card grants none.

### Additional controls

- One active position per symbol and magic number.
- Use completed-bar signals only.
- Use the current `QM_Common.mqh` / `QM_NewsFilter.mqh` bundle with news filtering enabled.
- Calendar inputs remain explicit tester-visible inputs: compliance, temporal window, minimum impact, and stale-calendar limit.
- `qm_news_stale_max_hours` must be no greater than `336`.
- Regime and volatility filters are disabled in the baseline setfiles.
- No grid, martingale, averaging-down, ML, online adaptation, or discretionary override.

## Candidate universe

The exact baseline universe is unchanged from the approved source card:

- `EURUSD.DWX`
- `USDJPY.DWX`
- `XAUUSD.DWX`
- `SP500.DWX`
- `XTIUSD.DWX`

All five use D1. `SP500.DWX` remains research/backtest-only unless a future live-promotion decision separately resolves broker routing. This rebuild does not grant live use.

## Framework mapping

- `Strategy_NoTradeFilter`: no strategy-specific veto beyond V5 controls.
- `Strategy_EntrySignal`: completed-bar SMA(9)/SMA(26) alignment plus SMA(26) slope.
- `Strategy_ManageOpenPosition`: retain the position until a qualified opposite signal; keep the catastrophic stop.
- `Strategy_ExitSignal`: qualified opposite signal closes the position before a new entry is considered.
- `Strategy_NewsBlackout`: returns false because the framework news filter is the sole calendar gate.

## R1-R4 assessment

| Criterion | Status | Rationale |
|---|---|---|
| R1 Source-Link | PASS | Named book, chapter, page range, and web-text location. |
| R2 Mechanical | PASS | SMA periods, slope confirmation, direction, reversal exit, and safety stop are explicit. |
| R3 DWX-testbar | PASS | Uses D1 OHLC-derived SMA/ATR inputs on the five declared DWX symbols. |
| R4 No ML | PASS | Fixed rules only; no ML or adaptive component. |

## Pipeline state

- G0: APPROVED only under the identity-rebuild authority above.
- Q02 and later: no inherited state; must begin with exactly one fresh Q02 canary admitted from this identity's own source-matched `COMPILE_OK` evidence.
- T6/live: not authorized.
