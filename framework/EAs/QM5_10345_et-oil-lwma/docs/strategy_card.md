---
ea_id: QM5_10345
slug: et-oil-lwma
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "oilfxpro, CRUDE OIL 1 min trading system by OILFXPRO, Elite Trader, 2007-12-04, https://www.elitetrader.com/et/threads/crude-oil-1-min-trading-system-by-oilfxpro.111115/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-trend-following]]"
  - "[[concepts/moving-average-stack]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/lwma]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
period: M1
expected_trade_frequency: "M1 trend-stack scalp on liquid CFDs; conservative estimate 120 trades/year/symbol after session, spread, and one-position filters."
expected_trades_per_year_per_symbol: 120
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS Elite Trader URL/handle; R2 PASS deterministic LWMA/RSI/impulse entries plus ATR/BE/trailing exits with ~120 trades/year/symbol; R3 PASS XTIUSD/CFD DWX testable; R4 PASS fixed-rule no ML/grid/martingale."
---

# Elite Trader Oil LWMA RSI Impulse Scalp

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/crude-oil-1-min-trading-system-by-oilfxpro.111115/
- Author / handle: `oilfxpro`.
- Date: 2007-12-04.
- Location: post #1 defines an M1 crude system with LWMA 36/75/120, RSI(14), Waddah Attar Explosion or similar impulse filter, minimum stop, ATR target, break-even, and trailing stop.

## Mechanik

### Entry
- Evaluate on completed M1 bars.
- Long when LWMA(36) > LWMA(75), LWMA(75) > LWMA(120), close > LWMA(36), and RSI(14) > 50.
- Require impulse confirmation: `MACDHistogram(12,26,9) > 0` and `abs(MACDHistogram) > 1.0 * ATR(14,M1) / close` as a Waddah-Attar-style volatility impulse proxy.
- Require two successive higher swing highs over the last 10 M1 bars for long confirmation.
- Short when LWMA(36) < LWMA(75), LWMA(75) < LWMA(120), close < LWMA(36), RSI(14) < 50, negative impulse proxy, and two successive lower swing lows.
- Enter on first pullback to within `0.25 * ATR(14,M1)` of LWMA(36) after conditions are true.

### Exit
- TP = `1.0 * ATR(14,M1)` from entry.
- Exit at end of liquid session.
- Exit long if LWMA(36) slope turns negative for two closed bars or RSI(14) crosses below 50.
- Exit short if LWMA(36) slope turns positive for two closed bars or RSI(14) crosses above 50.

### Stop Loss
- Initial SL = max(source minimum stop proxy, `1.0 * ATR(14,M1)`).
- Move to break-even after +1R.
- Trail by `1.0 * ATR(14,M1)` after break-even trigger.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Trade only during liquid XTIUSD/CFD sessions.
- Skip if current spread > 2.0x rolling median spread.
- Source's discretionary support/resistance and heating-oil checks are not used in P2; optional deterministic intermarket filter can be evaluated later only if DWX data is available.

## Concepts
- [[concepts/intraday-trend-following]] - primary.
- [[concepts/moving-average-stack]] - 36/75/120 LWMA trend state.
- [[concepts/volatility-breakout]] - impulse proxy replacing platform-specific Waddah Attar indicator.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `oilfxpro`. |
| R2 Mechanical | PASS | MA stack, RSI filter, impulse proxy, pullback, ATR target, BE, and trail are deterministic. |
| R3 DWX-testbar | PASS | Source market crude oil maps to `XTIUSD.DWX`; XAUUSD and indices provide CFD robustness checks. |
| R4 No ML | PASS | Fixed indicators and stops; no ML, adaptive online parameters, grid, or martingale. |

## R3
Primary P2 basket: `XTIUSD.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`.

## Author Claims
- The source describes the method as a "1 minute crude oil trading system."
- The post says to use LWMA 36/75/120, RSI 14, and a Waddah Attar Explosion-style confirmation.

## Parameters To Test
- LWMA stack: 24/60/120, 36/75/120, 50/100/150.
- RSI threshold: 50, 55/45, 60/40.
- Impulse threshold: 0.5, 1.0, 1.5 normalized units.
- ATR target: 0.75, 1.0, 1.5.
- Trail ATR multiplier: 0.75, 1.0, 1.25.

## Initial Risk Profile
High-turnover M1 scalp with latency/spread sensitivity. Requires P5b calibrated latency scrutiny if it reaches stress stages.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
