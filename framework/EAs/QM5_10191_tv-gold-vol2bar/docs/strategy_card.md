---
ea_id: QM5_10191
slug: tv-gold-vol2bar
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/volume-spike]]"
indicators:
  - "[[indicators/volume]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 110
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic two-bar volume momentum entry with TP/protective SL and ~110 trades/year/symbol; R3 directly testable on XAUUSD.DWX and portable to DWX CFDs; R4 fixed rules, no ML/grid/martingale, one-position-per-magic compatible."
---

# TradingView Gold Two-Bar Volume Momentum

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `GOLD Volume-Based Entry Strategy`, author handle `Rendon1`, published 2025-02-04, https://www.tradingview.com/script/4vLg0Rzd-GOLD-Volume-Based-Entry-Strategy/

## Mechanik

### Entry
Use M5/M15/M30 bars, long-only baseline.

- Compute volume SMA over 20 bars.
- First setup bar:
  - close > open.
  - volume > SMA(volume, 20).
- Second setup bar immediately follows:
  - close > open.
  - volume > SMA(volume, 20).
  - volume > prior bar volume.
- Enter long on the close of the second qualifying bar.
- One open position maximum.

### Exit
- Source target: fixed profit target from entry, default 5 USD on gold.
- DWX baseline: TP = max(source fixed target converted to symbol points, 1.5 * ATR(14)).
- If no TP hit, exit on opposite bearish volume shock: two consecutive bearish candles with volume > SMA(volume, 20), or after 12 bars.

### Stop Loss
Source says stop can be added but does not define it. V5 protective default: SL = 1.0 * ATR(14) below entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary symbol: XAUUSD.DWX.
- Optional ports: XAGUSD.DWX, XTIUSD.DWX, GER40.DWX, NDX.DWX.
- Do not run on timeframes above M30; source explicitly recommends 1M-30M.
- Spread must be <= 15% of ATR stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum]] - follows immediate buying pressure after two bullish bars.
- [[concepts/volume-spike]] - requires above-average and increasing volume.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Rendon1` are cited. |
| R2 Mechanical | PASS | Source gives explicit two-bar volume entry and profit target; stop is a documented V5 protective default. |
| R3 Data Available | PASS | XAUUSD.DWX is directly testable; OHLCV logic ports to other DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed volume and candle rules, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10190_tv-vsa-absorb]] - volume-bar family, but this card is long-only continuation rather than absorption reversal.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
