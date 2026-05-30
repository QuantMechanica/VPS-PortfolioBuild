---
ea_id: QM5_10253
slug: tv-ifvg-sweep
type: strategy
source_id: c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
sources:
  - "[[sources/tradingview-top-pine-scripts]]"
concepts:
  - "[[concepts/smart-money]]"
  - "[[concepts/pullback-continuation]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/fair-value-gap]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
primary_symbol: XAUUSD.DWX
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 mechanical EMA/sweep/IFVG retest entry plus 2R/time exits with ~90 trades/year/symbol; R3 OHLC/ATR/MTF rules testable on DWX symbols; R4 fixed-rule no ML/grid/martingale one-position."
---

# QM5_10253 TradingView EMA Sweep IFVG Retest

## Quelle
- Source: TradingView Pine script "Multicator + Sweeps + IFVG + Zone Alerts by Olu777"
- URL: https://www.tradingview.com/script/x6Xam693-Multicator-Sweeps-IFVG-Zone-Alerts-by-Olu777/
- Author: olujojomofe (TradingView handle - anon OK under relaxed R1 post-2026-05-15)
- Source location: TradingView Trend Analysis category, public open-source script, 2026-05-19 snapshot.

## Mechanik

### Entry
- Higher-timeframe bias on H4:
  - Bullish bias when EMA(13) > EMA(21) > EMA(34).
  - Bearish bias when EMA(13) < EMA(21) < EMA(34).
- Continuation confirmation on H1:
  - Bullish when Close > EMA(21) and EMA(13) > EMA(21).
  - Bearish when Close < EMA(21) and EMA(13) < EMA(21).
- Execution timeframe: M15.
- Liquidity sweep:
  - Sell-side sweep: current low breaks below the prior 20-bar low and closes back above that prior low.
  - Buy-side sweep: current high breaks above the prior 20-bar high and closes back below that prior high.
- IFVG completion:
  - Bullish IFVG: after a sell-side sweep and displacement candle, a three-bar imbalance forms with `low[0] > high[2]`.
  - Bearish IFVG: after a buy-side sweep and displacement candle, a three-bar imbalance forms with `high[0] < low[2]`.
- Long entry:
  - H4 bullish bias + H1 bullish continuation.
  - M15 sell-side sweep.
  - Bullish IFVG completes.
  - Enter on first retest into the bullish IFVG zone.
- Short entry: mirror conditions.

### Exit
- TP1 baseline: 2R fixed target.
- Alternative P3 target: prior 20-bar swing high for longs / prior 20-bar swing low for shorts.
- Time-stop: flatten after 32 M15 bars.

### Stop Loss
- Long SL: below the sweep low by 0.25 x ATR(14).
- Short SL: above the sweep high by 0.25 x ATR(14).

### Position Sizing
- V5 standard: `RISK_FIXED = $1,000` for P2 baseline. `RISK_PERCENT` for live.

### Zusaetzliche Filter
- Trade only during London Open and NY Open volatility windows.
- Require displacement candle body >= 1.0 x ATR(14) on M15.
- Standard V5: QM_KillSwitch, news filter, MAX_DD trip, Friday-close flatten.

## Concepts
- [[concepts/smart-money]] - source uses liquidity sweep and IFVG concepts.
- [[concepts/pullback-continuation]] - entry is a retest after bias, sweep, displacement, and imbalance.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public TradingView URL and author handle olujojomofe are cited. |
| R2 Mechanical | PASS | The source gives the workflow HTF trend -> sweep -> displacement -> IFVG -> retest -> trade entry; deterministic definitions are supplied in this card for ambiguous side-parameters. |
| R3 Data Available | PASS | EMA stacks, prior highs/lows, FVGs, ATR, and MTF OHLC are available on DWX FX/index/XAU symbols. |
| R4 ML Forbidden | PASS | No ML, no adaptive learning, no grid, no martingale. One retest entry per magic. |

## Pipeline-Verlauf
- G0: 2026-05-19 - drafted from TradingView top-script resume batch, PENDING.

## Verwandte Strategien
- Smart-money/FVG family cards in the farm; this one is distinguished by the explicit H4/H1/M15 EMA/sweep/IFVG stack from the source.

## Lessons Learned (waehrend Pipeline-Lauf)
- *(populated as pipeline progresses)*

## Implementation Notes for Codex (P1)
- Default P2 symbols: XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, NDX.DWX.
- Implement only one active pending retest zone per direction to stay one-position-per-magic compatible.
- Ambiguous ICT terminology is intentionally converted into fixed OHLC rules above; do not add discretionary zone selection.
