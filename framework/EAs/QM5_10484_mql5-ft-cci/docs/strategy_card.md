---
ea_id: QM5_10484
slug: mql5-ft-cci
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "basile / Vasiliy idea, Vladimir Karputov (barabashkakvn) code, FT CCI MA, MQL5 CodeBase, published 2018-11-20, https://www.mql5.com/en/code/23061"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/cci-reversal]]"
  - "[[concepts/ma-trend-filter]]"
indicators: [CCI, Moving Average]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "CCI level triggers inside MA-slope regimes on H1; conservative estimate 35-80 trades/year/symbol."
expected_trades_per_year_per_symbol: 50
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 MA-slope plus CCI entry/exit rules with 35-80 trades/year/symbol; R3 OHLC indicators testable on DWX; R4 fixed non-ML one-position rules."
---

# MQL5 FT CCI MA Trend-Filtered CCI Levels

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: basile / Vasiliy idea, Vladimir Karputov (barabashkakvn) code, "FT CCI MA", MQL5 CodeBase, published 2018-11-20, URL https://www.mql5.com/en/code/23061.
- Source location: page defines MA rising/falling regimes and CCI level triggers: rising MA uses CCI -100 to buy and +200 to sell; falling MA uses CCI +100 to buy and -200 to sell. Source also describes optional trading-hour interval.

## Mechanik

### Entry
- Evaluate on closed H1 bars.
- Compute MA slope: `MA[1] > MA[2]` means rising; `MA[1] < MA[2]` means falling.
- Long:
  - If MA is rising, CCI crosses upward through -100.
  - If MA is falling, CCI crosses upward through +100.
  - No active position for this symbol/magic.
- Short:
  - If MA is rising, CCI crosses downward through +200.
  - If MA is falling, CCI crosses downward through -200.
  - No active position for this symbol/magic.

### Exit
- Close on opposite entry signal.
- Protective SL baseline = 1.5 * ATR(14).
- TP baseline = 2.0R.
- Time stop after 80 H1 bars.

### Stop Loss
- ATR-based fixed stop; no averaging or recovery.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Optional source time interval can be tested as a fixed London/New York filter; default G0 baseline trades all non-Friday-close hours.
- One active position per symbol/magic.
- Skip high-impact news windows when QM news filter is active.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | MA slope regimes and CCI trigger levels are explicitly described. |
| R3 DWX-testbar | PASS | Uses standard MA and CCI values on OHLC data available for DWX symbols. |
| R4 No ML | PASS | Fixed indicator levels, no ML, no grid/martingale, one-position baseline. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10460_mql5-cci-macd]] - CCI/MACD family; this card uses MA slope plus asymmetric CCI levels.

## Lessons Learned
- TBD during pipeline run.
