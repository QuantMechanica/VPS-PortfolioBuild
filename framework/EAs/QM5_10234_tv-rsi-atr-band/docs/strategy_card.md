---
ea_id: QM5_10234
slug: tv-rsi-atr-band
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-reversal]]"
  - "[[concepts/volatility-band]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/atr-stop]]"
  - "[[indicators/heikin-ashi]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present with TradingView URL and named author handle joseph_lemery."
r2_mechanical: PASS
r2_reasoning: "RSI/ATR band construction from price extremes since last cross, source-cross entry, and band-flip exit are deterministic rules described mechanically enough for P1."
r3_data_available: PASS
r3_reasoning: "RSI, ATR, and Heikin-Ashi OHLC are available on NDX.DWX, WS30.DWX, XAUUSD.DWX, and SP500.DWX (backtest-only)."
r4_ml_forbidden: PASS
r4_reasoning: "Band parameters depend solely on price history (not PnL), no ML/grid/martingale, one position per magic."
pipeline_phase: G0
period: M15
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "R1 verifiable TradingView URL; R2 mechanical RSI/ATR band cross entries and band/bracket exits with ~60 trades/year/symbol; R3 testable on DWX CFDs with SP500 caveat; R4 fixed deterministic no ML/martingale."
---

# RSI ATR Reversal Band

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "RSI and ATR Trend Reversal SL/TP" by joseph_lemery, updated 2024-05-30.
- URL: https://www.tradingview.com/script/hZLgJ29l-RSI-and-ATR-Trend-Reversal-SL-TP/

## Mechanik

### Entry
- Execution timeframe: M15.
- Compute RSI and ATR on Heikin-Ashi close values by default.
- Build mirrored upper/lower reversal bands from the highest or lowest source since the last cross event, scaled by inverse RSI pressure and ATR/source ratio.
- Long entry when selected source crosses up relative to the active lower band.
- Short entry when selected source crosses down relative to the active upper band.
- Use confirmed bar close only; the source release notes fixed repainting by waiting for bar close.

### Exit
- Exit long when source crosses down through the active upper/bear band or when the active band flips bearish.
- Exit short when source crosses up through the active lower/bull band or when the active band flips bullish.
- The band also functions as a dynamic SL/TP line; P1 should expose signal exit and bracket exit separately.

### Stop Loss
- Source provides minimum difference as a fallback SL/TP percent. P1 default: minimum difference 2% equivalent on indices or 2 ATR emergency stop on FX/gold if percent is unsuitable.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Source tested 15-minute TSLA, AAPL, and NVDA. Port to liquid index/gold CFDs: NDX.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
- Standard V5 spread and news filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-reversal]] - primary
- [[concepts/volatility-band]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle joseph_lemery are cited. |
| R2 Mechanical | PASS | RSI/ATR band calculation, source cross entries, and band exits are described mechanically enough for P1. |
| R3 Data Available | PASS | RSI, ATR, Heikin-Ashi-derived OHLC, and source crosses are testable on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10174_tv-rsi-atr-3tp]] - RSI/ATR strategy with staged TP; different band-reversal mechanics.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
