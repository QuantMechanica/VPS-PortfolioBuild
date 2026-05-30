---
ea_id: QM5_10094
slug: gh-h4-zone
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/breakout-retest]]"
  - "[[concepts/support-resistance]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/daily-high-low]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 90
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
card_body_incomplete: false
card_body_missing: ""
g0_approval_reasoning: "R1 source repo/file cited; R2 deterministic zone breakout-retest with ATR exits and ~90 trades/year/symbol; R3 testable on XAUUSD.DWX/CFDs; R4 no ML/grid/martingale and one-position-per-magic."
---

# GitHub H4 Zone Breakout Retest

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Repository: https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE
- File: https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5
- Author / handle: phatnomenal
- Location: `blackXAU2.mq5`, zone update, M5 breakout, and retest entry logic.
- Source citation: 2026 GitHub URL https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5
- Target symbols: XAUUSD.DWX primary; DAX.DWX, NDX.DWX, and WS30.DWX port candidates after zone/session normalization.

## Mechanik

### Entry
- Define the daily zone each day:
  - Default mode: previous D1 high and previous D1 low.
  - Alternate mode: high/low of first configured H4 bars.
- On each new M5 bar, detect a valid bullish breakout:
  - Last completed M5 candle closes above `zoneHigh`.
  - The candle opened at or below `zoneHigh`.
  - Candle body is at least configured percent of candle range, default 50%, or absolute breakout body exceeds minimum points.
- Set waiting-retest state after the breakout and cancel it after `MaxWaitSeconds`, default 24 hours.
- Enter long when price retests the breakout level: bid <= `zoneHigh`.
- Apply optional EMA filter: price must be above EMA 50 and EMA 200 on the configured EMA timeframe, default H1.
- V5 version is long-only because the source sell branch is commented out.
- V5 constraint: one active position per magic, matching source `OnlyOnePosition`.

### Exit
- If ATR sizing is enabled, stop = entry - 1.5 * ATR(14 H1), target = entry + 3.0 * ATR(14 H1).
- If ATR sizing is disabled, stop = breakout candle low, target = entry + 1.5R.
- Optional trailing stop and breakeven management from source.

### Stop Loss
- ATR-based structural stop by default; fixed breakout-candle stop as source alternative.

### Position Sizing
- Source supports fixed lot or risk percent. V5 build uses fixed $1,000 risk for P2 baseline and 0.25% percent risk live default.

### Zusätzliche Filter
- Session filter default 07:00-22:00 server time.
- Spread cap default 50 points.
- Optional economic-calendar news filter.
- Broker-time normalization required in P1.

## Concepts (was ist das für eine Strategie)
- [[concepts/breakout-retest]] - primary
- [[concepts/support-resistance]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub repository and file URL are cited; author handle is visible. |
| R2 Mechanical | PASS | Daily zone, breakout confirmation, retest entry, ATR exits, trailing, and filters are explicit. |
| R3 Data Available | PASS | Uses OHLC, EMA, ATR, spread, session time, and calendar filter; directly testable on XAUUSD.DWX and other DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, or adaptive parameter learning; source has one-position option and V5 keeps one active position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10052_gh-time-range]] - range breakout, but this card requires retest after daily-zone break.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Research note: cadence estimate is below daily because it requires a confirmed M5 breakout, retest, EMA alignment, session, and spread filters.*
