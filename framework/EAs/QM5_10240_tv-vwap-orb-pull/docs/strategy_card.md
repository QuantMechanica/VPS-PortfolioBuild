---
ea_id: QM5_10240
slug: tv-vwap-orb-pull
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/vwap-pullback]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL cited; R2 mechanical ORB/VWAP pullback with ATR exits and ~80 trades/year/symbol; R3 DWX intraday CFD ports incl SP500 backtest caveat; R4 no ML/grid/martingale."
---

# VWAP ORB Pullback

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "VWAP ORB Pullback Strategy" by TraderTed420, published 2026-05-01.
- URL: https://www.tradingview.com/script/75epRRh2-VWAP-ORB-Pullback-Strategy/

## Mechanik

### Entry
- Execution timeframe: M1, M5, or M15 intraday.
- Define the opening range high and low during the first configurable minutes after the 09:30 New York session open.
- Long setup: after the opening-range window ends, price breaks above the opening-range high, remains above session VWAP, remains above EMA9, and pulls back toward VWAP before entry.
- Short setup: after the opening-range window ends, price breaks below the opening-range low, remains below session VWAP, remains below EMA9, and retests VWAP from below before entry.
- Enter only after breakout and pullback conditions align; do not enter on the initial breakout chase.

### Exit
- Take profit at the ATR-derived target using the selected risk/reward ratio.
- Stop out at the ATR-derived stop.
- Flat by end of the active trading session.

### Stop Loss
- Source uses ATR(14) to set stop loss and profit target automatically.
- P1 default: stop = 1.0 ATR(14), target = 1.5 ATR(14), expose the risk/reward ratio for P3.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Keep the VWAP filter enabled in the baseline; source allows it to be toggled off, but the edge thesis is ORB plus VWAP pullback confirmation.
- Best DWX ports: NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX, SP500.DWX.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das für eine Strategie)
- [[concepts/opening-range-breakout]] - primary
- [[concepts/vwap-pullback]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle TraderTed420 are cited. |
| R2 Mechanical | PASS | Opening range, VWAP/EMA side, pullback entry, ATR stop, and ATR target are explicit. |
| R3 Data Available | PASS | OHLC, session clock, VWAP, EMA, and ATR are available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or online parameter adaptation. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10164_tv-hilo-atr-break]] - first-30-minute high/low breakout without VWAP pullback requirement.
- [[strategies/QM5_10157_tv-nyrange-close-break]] - broader New York range breakout family.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
