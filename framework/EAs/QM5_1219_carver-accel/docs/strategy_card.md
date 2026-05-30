---
ea_id: QM5_1219
slug: carver-accel
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum-acceleration]]"
  - "[[concepts/volatility-normalisation]]"
indicators:
  - "[[indicators/ewmac]]"
  - "[[indicators/forecast-difference]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-19
expected_trades_per_year_per_symbol: 140
g0_approval_reasoning: "Carver qoppac 2021 live accel16/32/64 + pysystemtrade rules/accel.py R1-R4 PASS: R1 named author + qoppac URL + open-source code URL; R2 raw_accel=ewmac_t-ewmac_(t-Lfast) explicit in code + ForecastScalar(Lfast)*raw + cap [-20,+20] + sign-flip exit at 0 deterministic; R3 D1 OHLC EMA+StdDev portable "
---

# QM5_1219 Carver EWMAC Acceleration

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2021/12/my-trading-system.html
- Code URL: https://github.com/pst-group/pysystemtrade/blob/develop/systems/provided/rules/accel.py
- Author: Rob Carver. The 2021 post lists `accel16/32/64` in the live rule table and links the implementation; the code defines acceleration as the current EWMAC forecast minus the same EWMAC forecast lagged by `Lfast`.

## Mechanik

Acceleration rule on a volatility-normalised EWMAC signal. Instead of trading the level of trend, it trades the change in trend strength: long when the EWMAC signal is improving, short when it is deteriorating.

Suggested DWX universe for P2: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX, NDX.DWX, WS30.DWX, XAUUSD, XTIUSD.

### Entry
- On each closed D1 bar:
  - `Lslow = 4 * Lfast`.
  - `ewmac_t = (EMA(Close, Lfast) - EMA(Close, Lslow)) / StdDev(Close changes, 25)`.
  - `raw_accel_t = ewmac_t - ewmac_(t-Lfast)`.
  - `forecast = ForecastScalar(Lfast) * raw_accel_t`.
  - cap forecast to `[-20,+20]`.
- LONG if `forecast > +EntryForecast`.
- SHORT if `forecast < -EntryForecast`.
- Default variant: `Lfast=32`, `Lslow=128`, `EntryForecast=2`.
- P3 sweep Carver variants: `Lfast in {16,32,64}`, `Lslow=4*Lfast`.

### Exit
- Close LONG when forecast falls below `0`.
- Close SHORT when forecast rises above `0`.
- Flip only on a later closed D1 bar with opposite threshold.

### Stop Loss
- Emergency stop: `2.5 * ATR(20, D1)`.
- Optional P3 variants: `2.0`, `2.5`, `3.0` ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.5%`.
- Size from emergency stop distance. One position per symbol/magic.

### Zusätzliche Filter
- Require at least `Lslow + Lfast + 30` D1 bars before trading.
- Optional volatility attenuation for P3 only: reduce forecast by 50% when current volatility exceeds `1.5 * slow_vol_10y_proxy`.
- Spread cap: skip new entries when spread exceeds `2 * MedianSpread(20D)`.
- Rebalance once per D1 bar; no intraday re-entry loops.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/momentum-acceleration]] - primary
- [[concepts/volatility-normalisation]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author, exact qoppac URL, and linked open-source rule implementation. |
| R2 Mechanical | PASS | Formula is explicit in code: EWMAC forecast minus lagged EWMAC forecast. |
| R3 DWX-testbar | PASS | Uses only D1 OHLC-derived price and volatility; portable to DWX FX, indices, metals, and oil. |
| R4 No ML | PASS | Fixed lookbacks, fixed caps, one position per magic, no ML, no adaptive equity/PnL parameters. |

## R3 - T6 Live-Promotion-Caveat
N/A - proposed universe uses broker-routable DWX symbols only. SP500.DWX is not required.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog third batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1066_carver-ewmac-trend]] - trades EWMAC level rather than EWMAC change.
- [[strategies/QM5_1208_carver-normmom]] - trend-family cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
