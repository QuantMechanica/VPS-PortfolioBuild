---
ea_id: QM5_10198
slug: tv-barcount-rev
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/counter-trend]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/keltner-channel]]"
  - "[[indicators/volume]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic consecutive-bar/channel reversal entries with explicit V5 stop/exit defaults and ~80 trades/year/symbol; R3 OHLC/volume/channel logic testable on DWX FX/gold/index CFDs; R4 deterministic, no ML/grid/martingale, one-position compatible."
---

# TradingView Bar Counter Reversal

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `The Bar Counter Trend Reversal Strategy [TradeDots]`, author handle `tradedots`, published 2024-10-07, https://www.tradingview.com/script/0KAtQQDD-The-Bar-Counter-Trend-Reversal-Strategy-TradeDots/

## Mechanik

### Entry
Use H1 bars in baseline.

- Long reversal:
  - Detect `N` consecutive falling bars; baseline N = 4.
  - Optional volume confirmation enabled: volume increases during the consecutive falling sequence.
  - Channel confirmation enabled with Bollinger Bands in baseline.
  - Price interacts with or moves below the lower channel line.
  - Enter long on the next confirmed bar while flat.
- Short reversal:
  - Detect `N` consecutive rising bars; baseline N = 4.
  - Optional volume confirmation enabled: volume increases during the consecutive rising sequence.
  - Channel confirmation enabled with Bollinger Bands in baseline.
  - Price interacts with or moves above the upper channel line.
  - Enter short on the next confirmed bar while flat.

### Exit
- Source page does not provide built-in stop-loss or take-profit rules.
- Baseline V5 exit: close at mid-band touch or 2.0R target, whichever comes first.
- Time stop: close after 12 bars if neither mid-band nor stop/target is reached.

### Stop Loss
- Long stop: 1.5 ATR(14) below entry or below the setup low, whichever is farther.
- Short stop: 1.5 ATR(14) above entry or above the setup high, whichever is farther.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX, NDX.DWX.

### Zusatzliche Filter
- Baseline uses Bollinger Bands length 20, deviation 2.0. Keltner Channel variant can be tested in P3.
- Disable the source's percent-equity sizing; use V5 fixed risk.
- Avoid entries during the first/last 15 minutes of the broker day to reduce rollover artifacts.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/counter-trend]] - exhaustion after consecutive bars

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `tradedots` are cited. |
| R2 Mechanical | PASS | Source defines consecutive rising/falling bars, optional volume confirmation, channel interaction, and directional reversal signals; exits are filled with explicit V5 defaults. |
| R3 Data Available | PASS | Consecutive-bar, volume, Bollinger/Keltner, and ATR logic is testable on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Page mentions TradeDots AI products, but this script's described strategy is deterministic and uses no ML, grid, martingale, or pyramiding. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10172_tv-vwap-bb-dip]] - related band-based mean-reversion family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

