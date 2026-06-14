---
ea_id: QM5_10689
slug: tv-zigzag-bos
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "rau_u_lanz, Trend ZigZag Strategy by LANZ, TradingView open-source indicator, https://www.tradingview.com/script/7XkGKdmw/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/break-of-structure]]"
  - "[[concepts/retest-entry]]"
  - "[[concepts/session-filter]]"
indicators:
  - "[[indicators/zigzag]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; exact TradingView URL and author handle rau_u_lanz cited."
r2_mechanical: PASS
r2_reasoning: "BOS detection, retest activation, last-pivot stop with ATR buffer, 1R TP, one-active-setup rule, and 16:00 forced close are all deterministically specified; card fills execution gaps from the indicator-first source."
r3_data_available: PASS
r3_reasoning: "OHLC-derived ZigZag swings and session times are available on DWX FX, metals, and index CFDs."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed non-ML structure rules; simultaneous-trade option disabled for one-position-per-magic compliance."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-22
g0_approval_reasoning: "R1 TradingView URL cited; R2 mechanical closed-bar ZigZag BOS/retest with pivot stop, 1R TP, forced close and ~90 trades/year/symbol; R3 DWX OHLC/session testable; R4 fixed non-ML one-position rules."
---

# TradingView ZigZag BOS Retest Workflow

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Trend ZigZag Strategy by LANZ`, author handle `rau_u_lanz`, open-source indicator, published 2026-05-20 relative page age and updated 2026-05-22 relative page age, https://www.tradingview.com/script/7XkGKdmw/

## Mechanik

### Entry
Use M5-M15 baseline on FX, metals, and liquid index CFDs.

- Build confirmed swing sequences with a ZigZag structure engine.
- Classify breaks as BOS or CHoCH.
- Ignore CHoCH for P2; only BOS events can create trades.
- During the configured New York operational window, a valid BOS creates one pending retest setup.
- If a newer valid BOS appears before the retest, cancel the old pending setup and keep only the newest one.
- Long setup:
  - Bullish BOS occurs during the operational window.
  - Entry point is the BOS level.
  - Price retests the BOS level.
  - Enter long on retest activation.
- Short setup:
  - Bearish BOS occurs during the operational window.
  - Entry point is the BOS level.
  - Price retests the BOS level.
  - Enter short on retest activation.
- P2 uses isolated active trades only; simultaneous trade mode is disabled.

### Exit
- Take profit = 1R from entry by source visual trade map.
- Force close all active and pending setups at 16:00 New York time.

### Stop Loss
- Stop source option A: last pivot before the BOS.
- Stop source option B: maker level; if unavailable, fall back to last pivot.
- P2 baseline uses last-pivot stop with 0.1 ATR(14) buffer.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Only one pending setup at a time.
- BOS must occur inside the selected operational window.
- CHoCH is excluded from execution.
- Closed-bar swing confirmation required to avoid repainting.

## Concepts (was ist das fur eine Strategie)
- [[concepts/break-of-structure]] - confirmed swing break creates directional setup.
- [[concepts/retest-entry]] - entry waits for price to revisit the BOS level.
- [[concepts/session-filter]] - source constrains setup creation to operational hours.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `rau_u_lanz` are cited. |
| R2 Mechanical | UNKNOWN | Source is an indicator/trade workflow, not a native strategy, but it defines BOS setup, retest activation, SL, TP, cancellation, and forced close rules. |
| R3 Data Available | PASS | Uses OHLC-derived ZigZag swings and session times available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed non-ML structure rules; simultaneous-trade option disabled for one-position-per-magic compliance. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX.

## Author Claims
- Source describes BOS events as tradable retest setups and excludes CHoCH from execution logic.
- Source states pending setups are replaced by newer valid BOS setups and all setups close or cancel at 16:00 New York.

## Parameters To Test
- ZigZag pivot length: 3, 5, 8.
- Operational window: London open, NY AM, London/NY overlap.
- Stop source: last pivot vs maker fallback.
- Target: 1R, 1.5R, 2R.
- Force close time: 15:55, 16:00, 16:15 New York.

## Initial Risk Profile
Structure-retest strategy with execution ambiguity because the source is indicator-first. Build should formalize closed-bar ZigZag confirmation and reject any variant that requires subjective retest judgment.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10669 tv-cleighty-bos
- QM5_10670 tv-ls-bos-retest

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
