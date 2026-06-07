---
ea_id: QM5_11172
slug: weiss-dmi
type: strategy
source_id: 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
source_citation: "Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 3, pp. 56-57, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems"
sources:
  - "[[sources/weissman-mechanical-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/dmi]]"
indicators: [DMI]
target_symbols: [EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX]
period: D1
expected_trade_frequency: "Daily DMI threshold trend follower; Weissman reports 72-99 trades per asset over 10 years, so use 8 trades/year/symbol conservatively."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-23
g0_approval_reasoning: "R1 PASS cited Weissman book/web text; R2 PASS fixed DMI entry/exit with reported ~8 trades/year/symbol; R3 PASS OHLC-derived on DWX symbols with SP500 T6 caveat; R4 PASS fixed rules no ML/grid/martingale."
---

# Weissman DMI Threshold Trend

## Quelle
- Source: [[sources/weissman-mechanical-trading-systems]]
- Citation: Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, "DMI", pp. 56-57. Web text: https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems.
- Author: Richard L. Weissman.
- Source location: Chapter 3 defines a DMI trend-following system using 10-period directional difference thresholds of +20/-20 for entries and zero-line crosses for exits.

## Mechanik

### Entry
- Evaluate on completed D1 bar.
- Compute `DDIF(10)` / directional movement difference.
- Long:
  - `DDIF(10)[1]` crosses above `+20`.
  - Enter long if flat.
- Short:
  - `DDIF(10)[1]` crosses below `-20`.
  - Enter short if flat.

### Exit
- Long exit:
  - `DDIF(10)[1]` crosses below `0`.
- Short exit:
  - `DDIF(10)[1]` crosses above `0`.
- Exit to flat; do not reverse until the opposite entry threshold is crossed.

### Stop Loss
- Source does not specify a fixed stop for the DMI prototype.
- V5 build fallback: protective catastrophic stop at `max(3 * ATR(20,D1), broker minimum)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Use completed-bar signals only.
- Do not use Weissman's suggested implied-volatility confirmation in baseline because options IV is not available in DWX data.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/dmi]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author/book plus web text URL and chapter/page location. |
| R2 Mechanical | PASS | DMI entry and exit thresholds are explicit. |
| R3 DWX-testbar | PASS | Uses only D1 OHLC-derived DMI values on DWX instruments. |
| R4 No ML | PASS | Fixed indicator periods and thresholds; no ML, no online adaptation, no grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Framework Alignment
- Strategy_NoTrade: no same-symbol/magic duplicate position; obey V5 calendar controls.
- Strategy_EntrySignal: DMI directional difference crosses the +20/-20 trend threshold.
- Strategy_ManageOpenPosition: hold until zero-line exit or catastrophic stop.
- Strategy_ExitSignal: DMI directional difference crosses back through zero.

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING.

## Verwandte Strategien
- QM5_11173_weiss-dmi-adx.

## Lessons Learned
- TBD during pipeline run.
