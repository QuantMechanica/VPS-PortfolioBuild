---
ea_id: QM5_10355
slug: et-session-orb
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "chair632 / Gary186, EasyLanguage Script for Position Sizing, Elite Trader, 2021-08-24 and 2024-09-07, https://www.elitetrader.com/et/threads/easylanguage-script-for-position-sizing.361086/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/range-stop]]"
  - "[[concepts/fixed-profit-target]]"
indicators: []
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, EURUSD.DWX]
period: M15
expected_trade_frequency: "One opening-range breakout per session with max one entry per day; conservative estimate 150 trades/year/symbol after filters."
expected_trades_per_year_per_symbol: 150
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS Elite Trader URL/handles cited; R2 PASS mechanical opening-range breakout with daily exits/stops and plausible 150 trades/year/symbol; R3 PASS DWX indices/FX testable with SP500.DWX T6 caveat; R4 PASS fixed non-ML one-position rules."
---

# Elite Trader Session Opening Range Breakout

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/easylanguage-script-for-position-sizing.361086/
- Author / handle: `chair632`; code revision by `Gary186`.
- Dates: 2021-08-24 and 2024-09-07.
- Location: posts #1-#3. The thread gives EasyLanguage opening-range code with range construction, breakout stop entries, opposite-side exits, fixed stop/target, max entries per day, and exit on close.

## Mechanik

### Entry
- On each new session, define `OpeningRngHigh` and `OpeningRngLow` over the first `NumBarsToSetRng` bars.
- Baseline: M15 chart and `NumBarsToSetRng = 3`.
- If flat, after the opening range is complete and before session end:
- Buy stop at `OpeningRngHigh + BreakOutTicksRqd * tick_size`.
- Sell short stop at `OpeningRngLow - BreakOutTicksRqd * tick_size`.
- Max one entry per day.

### Exit
- Long exits at `OpeningRngLow - tick_size` stop.
- Short exits at `OpeningRngHigh + tick_size` stop.
- Fixed target: baseline `1.0R` from entry.
- Fixed protective stop: baseline `1.0R`, aligned with source `DollarStopPerUnit`.
- Exit on session close; Friday close enforced by framework.

### Stop Loss
- Opposite range-side stop is always active.
- Additional V5 protective stop caps abnormal gaps at `1.5 * opening_range_width`.
- Skip if opening range width is zero or less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.
- Source discusses equal dollar risk by range width; V5 implements that through normal framework sizing, not custom adaptive risk.

### Zusaetzliche Filter
- Trade only liquid primary sessions per symbol.
- Skip when current spread exceeds 2.5x rolling median spread.
- Disable same-day re-entry after either target or stop.

## Concepts
- [[concepts/opening-range-breakout]] - entry triggers outside the first-session range.
- [[concepts/range-stop]] - opposite side of the opening range is the primary invalidation.
- [[concepts/fixed-profit-target]] - source includes built-in stop and target.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus handles `chair632` and `Gary186`. |
| R2 Mechanical | PASS | EasyLanguage code gives deterministic range, entries, exits, target, stop, and daily limit. |
| R3 DWX-testbar | PASS | Opening-range logic is testable on Darwinex indices, FX, and SP500.DWX backtest-only. |
| R4 No ML | PASS | Fixed breakout rules; one-position-per-magic compatible; no ML, grid, or martingale. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`, `EURUSD.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source says the code issues buy/sell short stop orders after the range is set.
- The source code limits entries per day and exits on close.

## Parameters To Test
- Opening bars: 2, 3, 4, 6 M15 bars.
- Breakout ticks: 1, 3, 5, 8.
- Target: 0.75R, 1.0R, 1.5R, 2.0R.
- Protective stop cap: 1.0, 1.25, 1.5 opening range widths.
- Period: M5, M15, M30.

## Initial Risk Profile
Classic opening-range breakout. Main risk is chop after early range completion; daily entry cap and opposite-side stop limit repeat losses.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
