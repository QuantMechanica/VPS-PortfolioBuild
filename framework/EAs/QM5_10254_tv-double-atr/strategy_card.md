---
ea_id: QM5_10254
slug: tv-double-atr
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/reversal]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/atr-trailing-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: XAUUSD.DWX
expected_trades_per_year_per_symbol: 65
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 mechanical ATR trailing-stop flip entry/exit with ~65 trades/year/symbol; R3 OHLC/ATR rules testable on DWX symbols; R4 fixed ATR logic no ML/grid/martingale one-position."
---

# QM5_10254 TradingView Double ATR Reversal

## Quelle
- Source: TradingView Pine script "Double ATR Reversal"
- URL: https://www.tradingview.com/script/xG3SlzJB-Double-ATR-Reversal/
- Author: dublin_capital (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView Trend Analysis category, public open-source script, 2026-05-19 snapshot.

## Mechanik

### Entry
- Compute ATR(14).
- Maintain a ratcheting trailing stop with multiplier 2.0 ("Double ATR"):
  - In bull mode: stop = max(previous stop, Close - 2.0 x ATR).
  - In bear mode: stop = min(previous stop, Close + 2.0 x ATR).
- Long setup:
  - Prior state is bear mode.
  - Close flips above the active bear stop.
  - Enter long at next bar open.
- Short setup:
  - Prior state is bull mode.
  - Close flips below the active bull stop.
  - Enter short at next bar open.
- Yellow ATR expansion spike is treated as a filter candidate, not a mandatory entry rule.

### Exit
- Exit/reverse on the opposite ATR stop flip.
- P2 baseline allows immediate reversal: close current position and open opposite at next bar open after confirmed flip.

### Stop Loss
- Initial SL is the active Double ATR stop at entry.
- Catastrophic hard stop: entry +/- 5.0 x ATR(14).

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.

### Zusaetzliche Filter
- P3 filter candidate: require ATR expansion spike when `ATR(14) > 1.5 x SMA(ATR(14), 50)`.
- Baseline does not require the spike because the source lists it as a separate signal marker.
- Standard V5: QM_KillSwitch, news filter, MAX_DD trip, Friday-close flatten.

## Concepts
- [[concepts/reversal]] - primary; signal occurs when price flips through the ratcheting ATR stop.
- [[concepts/trend-following]] - the stop then trails the new active directional phase.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle dublin_capital are cited. |
| R2 Mechanical | PASS | ATR x 2 ratcheting stop and flip-through-stop entry/exit are deterministic. |
| R3 Data Available | PASS | ATR and OHLC close/stop flips are available on all DWX symbols/timeframes. |
| R4 ML Forbidden | PASS | Fixed ATR multiplier and fixed reversal logic. No ML, no adaptive learning, no grid, no martingale. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_9167_tv-boswaves-supertrend-extensions]] - related ATR-stop trend flip family, but this card uses the simpler Double ATR reversal scan.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Default P2 symbols: XAUUSD.DWX, NDX.DWX, WS30.DWX, EURUSD.DWX.
- Default timeframe: H1. P3 sweep: M30/H4.
- ATR multiplier fixed at 2.0 for baseline; P3 can test 1.5/2.5/3.0.
