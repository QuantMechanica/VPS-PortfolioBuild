---
ea_id: QM5_10347
slug: et-donchian210
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "Chuck Krug, Richard D. Donchian System, Elite Trader, 2009-08-09, https://www.elitetrader.com/et/threads/richard-d-donchian-system.172693/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/long-horizon-trend-following]]"
  - "[[concepts/donchian-breakout]]"
  - "[[concepts/stop-and-reverse]]"
indicators:
  - "[[indicators/donchian-channel]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: D1
expected_trade_frequency: "210-day stop-and-reverse breakout; conservative estimate 4 trades/year/symbol."
expected_trades_per_year_per_symbol: 4
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS Elite Trader URL/handle; R2 PASS deterministic 210-day Donchian stop-reverse with plausible ~4 trades/year/symbol; R3 PASS daily DWX FX/metals/indices testable; R4 PASS fixed-rule no ML/grid/martingale."
---

# Elite Trader Seykota Donchian 210-Day Stop-Reverse

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/richard-d-donchian-system.172693/
- Author / handle: `Chuck Krug`.
- Date: 2009-08-09.
- Location: post #1 cites Ed Seykota's Donchian page and lists three rules: buy stop at 210-day high, sell stop at 210-day low, and size to protective-stop risk.

## Mechanik

### Entry
- Evaluate on completed D1 bars.
- Long if price breaks above prior DonchianHigh(210,D1).
- Short if price breaks below prior DonchianLow(210,D1).
- Stop-and-reverse behavior is implemented as close existing opposite position first, then open the new direction only if flat after close confirmation.
- One position per symbol/magic.

### Exit
- Long exits and reverses when price breaks below prior DonchianLow(210,D1).
- Short exits and reverses when price breaks above prior DonchianHigh(210,D1).
- Friday close default applies only if framework requires flat; otherwise this system is naturally multi-day and must be checked for Friday-close compatibility.

### Stop Loss
- Protective stop is the opposite 210-day channel boundary.
- Skip new trades if channel risk distance exceeds `4.0 * ATR(20,D1)` unless P3 explicitly enables wide-channel variant.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Source mentions 7% equity risk; V5 live risk defaults override this for safety.

### Zusaetzliche Filter
- Require at least 230 daily bars before first signal.
- Skip if current spread > 2.5x median spread.
- No pyramiding, grid, or averaging.

## Concepts
- [[concepts/long-horizon-trend-following]] - primary.
- [[concepts/donchian-breakout]] - 210-day channel.
- [[concepts/stop-and-reverse]] - opposite channel switches direction.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `Chuck Krug`; thread includes Seykota source link. |
| R2 Mechanical | PASS | Buy/sell stops at 210-day high/low and protective stop sizing are explicit. |
| R3 DWX-testbar | PASS | Uses daily OHLC on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed channel rules; no ML, adaptive parameters, grid, martingale, or multi-position stacking. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `NDX.DWX`. If reviewers add `SP500.DWX`, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The source lists the rule to place a buy stop at the 210-day high.
- The source lists the rule to place a sell stop at the 210-day low.

## Parameters To Test
- Channel length: 100, 150, 210.
- Wide-channel risk filter: 3 ATR, 4 ATR, off.
- Direction: long/short, long-only, short-only.
- Friday close: framework default, hold-through-weekend exception candidate.

## Initial Risk Profile
Very low-frequency trend-following profile with large giveback risk and long flat/losing periods. Cadence is sparse but acceptable because it is multi-symbol and mechanically classic.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
