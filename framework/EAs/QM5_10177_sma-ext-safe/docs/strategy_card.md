---
ea_id: QM5_10177
slug: sma-ext-safe
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/volatility-threshold]]"
indicators:
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/average-true-range]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 28
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS: Raposa article URL and Medium mirror cited; R2 PASS: deterministic D1 SMA/ATR threshold entry, SMA/time/ATR exits, expected 28 trades/year/symbol; R3 PASS: portable to SP500.DWX/NDX/WS30 and liquid DWX CFDs; R4 PASS: fixed-rule non-ML one-position-per-magic."
---

# SMA Extension Mean Reversion With Safety Threshold

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/how-to-build-your-first-mean-reversion-trading-strategy-in-python/
- Mirror/reference: https://medium.com/raposa-technologies/how-to-build-your-first-mean-reversion-trading-strategy-in-python-8c9d4813ee40
- Author / institution: Raposa / Raposa Technologies
- Date: 2021-03-01
- Location: article section "Adding a Safety Threshold".

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute SMA(close, 20) and ATR(14).
- Define `extension = close[1] - SMA20[1]`.
- Define `threshold = 1.0 * ATR14[1]`.
- Enter long only when `extension <= -threshold`.
- Enter short only when `extension >= threshold`.
- Do nothing while price is inside the threshold band around SMA20.

### Exit
- Exit long when close crosses back above SMA20.
- Exit short when close crosses back below SMA20.
- Exit on opposite threshold signal and reverse only after the prior position is closed.

### Stop Loss
- Initial long stop: entry - 2.0 * ATR(14).
- Initial short stop: entry + 2.0 * ATR(14).
- Time stop: close after 20 D1 bars if neither SMA reversion nor stop has fired.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One active position per symbol and magic number.

### Zusätzliche Filter
- Warmup: 40 D1 bars.
- Use closed bars only.
- Optional P3 trend-regime filter: stand down when ADX(14) > 30, because strong directional regimes are hostile to mean-reversion.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/volatility-threshold]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa article URL plus Medium mirror with named institution and date. |
| R2 Mechanical | PASS | SMA extension, ATR-normalized threshold, SMA re-cross exit, stop, and time stop are deterministic. |
| R3 Data Available | PASS | SMA and ATR are available for DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed periods and threshold multiplier; no ML, adaptive online learning, martingale, or multi-position stacking. |

## R3
The source examples are equity-style daily bars. The rule ports directly to SP500.DWX / NDX.DWX / WS30.DWX and liquid FX/commodity CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source adds the safety threshold to avoid trading every small price deviation from the moving average.

## Parameters To Test
- SMA period: 10, 20, 30, 50.
- Threshold basis: 0.5 ATR, 1.0 ATR, 1.5 ATR, 2.0 ATR.
- Exit: SMA re-cross, half-extension reversion, opposite threshold signal.
- Time stop: off, 10, 20, 30 D1 bars.
- ADX no-trade filter: off, 25, 30, 35.

## Initial Risk Profile
Selective daily mean-reversion variant. Lower cadence than the raw extension model; threshold should reduce noise but can enter only after larger adverse moves, so stop placement and trend filters matter.

## Pipeline-Verlauf
- G0: PENDING.

