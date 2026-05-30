---
ea_id: QM5_10394
slug: et-rsi-trend
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "no_pm_please, NPP builds a Emini system, Elite Trader, 2006-12-08, https://www.elitetrader.com/et/threads/npp-builds-a-emini-system.82314/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-trend-following]]"
  - "[[concepts/rsi-regime]]"
  - "[[concepts/indicator-trailing-exit]]"
indicators: [RSI]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M15
expected_trade_frequency: "Intraday RSI regime flips on 15-240 minute bars; conservative M15 estimate 80 trades/year/symbol after one-position and session filters."
expected_trades_per_year_per_symbol: 80
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 linked Elite Trader source; R2 explicit RSI cross entries and indicator exits with plausible 80 trades/year/symbol; R3 testable on SP500.DWX with NDX/WS30 live caveat; R4 fixed-rule no-ML one-position logic."
---

# Elite Trader RSI Regime Trend

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/npp-builds-a-emini-system.82314/
- Author / handle: `no_pm_please`.
- Date: 2006-12-08.
- Location: posts #1-#3 describe the RSI trend logic and an ES M15 test example.

## Mechanik

### Entry
- Run on M15 baseline; source also proposes M30, H1, H2, H3, and H4 tests.
- Compute `RSI(close, Length)`.
- If flat and RSI crosses above 50.5, enter long next bar.
- If flat and RSI crosses below 49.5, enter short next bar.
- V5 baseline uses `Length = 43`, the source's example optimum for 2003 ES M15; later P3 can sweep fixed lengths.

### Exit
- For a long, arm a trailing indicator exit after RSI has traded above 52.5; exit when RSI crosses back below 52.5.
- For a short, arm a trailing indicator exit after RSI has traded below 47.0; exit when RSI crosses back above 47.0.
- Emergency exit at Friday session close if the broker has a weekend break.

### Stop Loss
- Source describes RSI-band risk but no price stop.
- V5 baseline stop: `2.0 * ATR(20, period)` from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Trade regular index CFD sessions only.
- Skip if ATR stop distance is below four spreads.

## Concepts
- [[concepts/intraday-trend-following]] - follows RSI regime direction.
- [[concepts/rsi-regime]] - RSI thresholds define long/short state.
- [[concepts/indicator-trailing-exit]] - exits are triggered by RSI retracing through a trend threshold.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handle `no_pm_please`. |
| R2 Mechanical | PASS | Directional entries and indicator exits are explicit; V5 adds a bounded price stop. |
| R3 DWX-testbar | PASS | ES/e-mini logic is testable on SP500.DWX and live index CFD analogs. |
| R4 No ML | PASS | Fixed RSI thresholds and fixed sweepable lengths; no ML, adaptive online parameters, martingale, grid, or pyramiding. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- `no_pm_please` frames the idea as an e-mini trend-following system.
- The author says the ES M15 2003 example used 43 RSI bars and followed the trend-following idea.

## Parameters To Test
- RSI length: 21, 34, 43, 55, 89.
- Period: M15, M30, H1, H2.
- Entry bands: 50.25/49.75, 50.5/49.5, 51/49.
- Exit-arm/retrace bands: 52/48, 52.5/47, 55/45.
- Stop: 1.5, 2.0, 2.5 ATR.

## Initial Risk Profile
Medium-frequency intraday trend following. Main risks are whipsaw near RSI 50, cost sensitivity on short periods, and source overfitting because examples discuss per-year optimization.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
