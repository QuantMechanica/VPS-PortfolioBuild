---
ea_id: QM5_1540
slug: aa-vix-trend-top2
expected_trades_per_year_per_symbol: 100
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/volatility-regime]]"
  - "[[concepts/relative-momentum-rotation]]"
indicators:
  - "[[indicators/vix-sma-regime]]"
  - "[[indicators/relative-momentum]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Alpha Architect URL with named author Andrew Miller and dated 2017 publication."
r2_mechanical: PASS
r2_reasoning: "Fixed VIX SMA thresholds (18/32), fixed lookback-by-regime mapping (10/3/1 month), and monthly top-2 positive-return rotation are fully deterministic."
r3_data_available: PASS
r3_reasoning: "DWX instruments for the risky universe (SP500.DWX, NDX.DWX, WS30.DWX, GDAXI, XAUUSD, USOIL, FX majors) are available; VIX regime input can be provided deterministically via CSV as the card acknowledges."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed thresholds, fixed lookback mapping, and monthly rotation with no ML, online learning, grid, or martingale; 1-pos-per-magic."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 Alpha Architect URL; R2 fixed VIX SMA regime plus monthly top-2 rotation exits; R3 DWX universe testable with deterministic VIX CSV/custom-symbol input and SP500.DWX T6 caveat; R4 fixed non-ML one-position rules."
---

# Alpha Architect VIX-Regime Trend Top-2 Rotation

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Andrew Miller, "VIX and Trend-Following, the Killer Combo?", 2017-09-28, https://alphaarchitect.com/vix-and-trend-following-the-killer-combo/

## Mechanik

The article tests a multi-asset trend-following system where VIX regime selects the relative-momentum lookback: 10 months in calm markets, 3 months in intermediate markets, and 1 month in stressed markets. The top 1 or 2 assets are held only if their lookback returns are positive; otherwise cash is held.

### Entry
- Monthly rebalance.
- VIX input: use CBOE VIX daily close if available to the data pipeline. If unavailable in MT5, use a precomputed CSV signal or mark P1 data blocker.
- VIX regime:
  - Green: SMA(VIX,40 daily bars) <= 18.
  - Yellow: SMA(VIX,40) > 18 AND SMA(VIX,20) < 32.
  - Red: SMA(VIX,40) > 18 AND SMA(VIX,20) >= 32.
- Lookback by regime:
  - Green: rank assets by 10-month return.
  - Yellow: rank assets by 3-month return.
  - Red: rank assets by 1-month return.
- DWX risky universe: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.
- Select top 2 assets by regime-specific lookback return.
- Open long positions only for selected assets with positive lookback return; hold cash for any selected slot with negative return.

### Exit
- Rebalance monthly.
- Close any asset no longer in top 2 or whose lookback return is not positive.
- Change lookback immediately at the next monthly rebalance when VIX regime changes.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Time stop: monthly rebalance/rotation.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`, split across active top-2 slots.
- T6-live: `RISK_PERCENT = 0.5`, split across active slots.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 220 daily bars for the 10-month lookback.
- If VIX data is stale for more than 2 trading days, do not open new positions and close at next rebalance.
- No shorting in baseline; source uses long/cash rotation.

## Concepts (was ist das für eine Strategie)
- [[concepts/volatility-regime]] - primary
- [[concepts/relative-momentum-rotation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Andrew Miller and dated publication. |
| R2 Mechanical | PASS | Fixed VIX SMA thresholds, fixed lookback mapping, monthly top-2 positive-return rotation. |
| R3 Data Available | UNKNOWN | DWX price data is available for proxies, but VIX is an external signal and may require CSV import or custom symbol support. |
| R4 ML Forbidden | PASS | Deterministic thresholds and lookbacks; no ML, online learning, grid, martingale, or adaptive parameter search. |

## R3
Original assets are retirement-plan indexes plus cash and VIX. DWX port uses liquid index/FX/commodity CFDs, but the VIX regime input is external to standard DWX broker symbols and must be provided deterministically.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 2 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1089_aa-raa-robust-pairs]] - prior Alpha Architect trend/rotation card.

## Lessons Learned (während Pipeline-Lauf)
- TBD
