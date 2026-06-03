---
ea_id: QM5_10490
slug: mql5-adx-ama
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Scriptor idea, Vladimir Karputov (barabashkakvn) code, Breadandbutter2, MQL5 CodeBase, published 2018-10-25, https://www.mql5.com/en/code/22003"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/adx-trend]]"
  - "[[concepts/adaptive-moving-average]]"
indicators: [ADX, AMA]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "New-bar ADX/AMA slope-cross system on H1; conservative estimate 40-90 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 MQL5 CodeBase citation/link; R2 new-bar ADX/AMA slope rules with opposite/time/ATR exits and ~60 trades/year/symbol; R3 portable to DWX FX/metals; R4 fixed indicators, no ML/grid/martingale, one-position baseline."
---

# MQL5 Breadandbutter2 ADX AMA Slope Cross

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Scriptor idea, Vladimir Karputov (barabashkakvn) code, "Breadandbutter2", MQL5 CodeBase, published 2018-10-25, URL https://www.mql5.com/en/code/22003.
- Source location: page states the EA is based on ADX and AMA, works only on new bars, closes opposite positions on signals, and shows explicit buy/sell comparisons in source snippets.

## Mechanik

### Entry
- Evaluate only when a new bar appears.
- Compute ADX and AMA on the selected timeframe.
- Long baseline:
  - Current ADX value is lower than previous ADX value.
  - Current AMA value is higher than previous AMA value.
  - No active position for this symbol/magic.
- Short baseline:
  - Current ADX value is higher than previous ADX value.
  - Current AMA value is lower than previous AMA value.
  - No active position for this symbol/magic.
- Source notes say best-parameter search can edit comparison signs; V5 baseline fixes the published comparison signs above.

### Exit
- Close on opposite ADX/AMA signal.
- Protective SL baseline = 1.5 * ATR(14).
- TP baseline = 2.0R.
- Time stop after 96 H1 bars.

### Stop Loss
- ATR stop, normalized by symbol tick size and broker stop level.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip high-impact news windows when QM news filter is active.
- AMA horizontal-shift optimization from source is treated as fixed P3 sweep parameter, not live adaptation.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Source includes explicit ADX and AMA comparisons for buy and sell. |
| R3 DWX-testbar | PASS | ADX and AMA are standard deterministic indicators portable to DWX instruments. |
| R4 No ML | PASS | No ML/grid/martingale; parameter search is offline only and V5 enforces one position. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10483_mql5-badx]] - ADX family; this card combines ADX direction with AMA slope.

## Lessons Learned
- TBD during pipeline run.
