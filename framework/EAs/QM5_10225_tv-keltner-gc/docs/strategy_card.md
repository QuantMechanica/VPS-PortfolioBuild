---
ea_id: QM5_10225
slug: tv-keltner-gc
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/keltner-channel-breakout]]"
indicators:
  - "[[indicators/keltner-channel]]"
  - "[[indicators/moving-average]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 mechanical MA/Keltner breakout with ATR TP/SL and ~80 trades/year/symbol; R3 OHLC/ATR portable to DWX FX/gold/index CFDs; R4 no ML/grid/martingale and one-position compatible."
---

# Keltner Golden-Cross Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "Keltner Channel Strategy with Golden Cross" by OversoldPOS, published 2023-10-01.
- URL: https://www.tradingview.com/script/9N0JyfyH-Keltner-Channel-Strategy-with-Golden-Cross/

## Mechanik

### Entry
- Compute a Keltner Channel from the selected EMA basis and ATR multiplier.
- Long entry when the fast moving average is above the slow moving average, default interpreted as MA50 > MA200, and price crosses above the user-defined Keltner ATR breakout level.
- Short entry when the fast moving average is below the slow moving average, default interpreted as MA50 < MA200, and price crosses below the user-defined Keltner ATR breakout level.
- Use confirmed bar close only.

### Exit
- Exit long when price reaches the Keltner take-profit ATR level or the Keltner stop-loss ATR level.
- Exit short on the mirrored take-profit or stop-loss level.

### Stop Loss
- Source-defined stop is the Keltner Channel stop-loss ATR level.
- P1 default if the source input is absent: 1.5 ATR from entry.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade; live sizing deferred to framework defaults.
- One open position per magic number.

### Zusätzliche Filter
- Run on liquid DWX CFDs where ATR/Keltner bands are stable: XAUUSD.DWX, GER40.DWX, NDX.DWX, EURUSD.DWX.
- Recommended test timeframes: M15, H1, H4, following the source's 15m/H1/H4/Daily guidance.
- Standard spread and news filters from the V5 framework.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/keltner-channel-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle OversoldPOS are cited; relaxed R1 only requires verifiable attribution. |
| R2 Mechanical | PASS | Entry requires MA trend alignment plus Keltner breakout; exits are ATR take-profit or stop-loss. |
| R3 Data Available | PASS | Uses OHLC-derived moving averages, Keltner Channel, and ATR available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, adaptive learning, grid, martingale, or multi-position requirement. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10224_tv-viop-atr-snipe]] - another ATR-managed TradingView momentum scalper.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
