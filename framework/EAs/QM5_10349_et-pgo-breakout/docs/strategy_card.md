---
ea_id: QM5_10349
slug: et-pgo-breakout
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "andrasnm, the Pretty Good Oscillator, Elite Trader, 2003, https://www.elitetrader.com/et/threads/the-pretty-good-oscillator.18598/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/volatility-breakout]]"
  - "[[concepts/moving-average-distance]]"
  - "[[concepts/atr-normalisation]]"
indicators:
  - "[[indicators/pretty-good-oscillator]]"
  - "[[indicators/atr]]"
  - "[[indicators/moving-average]]"
target_symbols: [EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "Volatility-distance threshold on completed H1 bars; conservative estimate 45 trades/year/symbol after spread and one-position filters."
expected_trades_per_year_per_symbol: 45
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 mechanical PGO threshold entry/zero-line exit with 45 trades/year/symbol estimate; R3 DWX ATR-normalized rule testable; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader PGO ATR Breakout

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/the-pretty-good-oscillator.18598/
- Author / handle: `andrasnm`.
- Date: 2003 thread; forum page exposes relative age but not a clean date in the scraped view.
- Location: post #1. The post defines Pretty Good Oscillator signals: positive threshold for long entry, negative threshold for short entry, and zero-line reversion exits.

## Mechanik

### Entry
- Evaluate completed H1 bars.
- Compute `PGO = (Close - MA(Close, pgo_ma_period)) / ATR(atr_period)`.
- Long when PGO crosses above `+3.0`.
- Short when PGO crosses below `-3.0`.
- Enter one position per symbol/magic only.

### Exit
- Exit long when PGO crosses below `0.0`.
- Exit short when PGO crosses above `0.0`.
- Protective stop: `2.0 * ATR(14,H1)` from entry.
- Friday close enforced by framework.

### Stop Loss
- Source treats the moving-average/zero-line return as the primary stop concept.
- V5 protective stop: `2.0 * ATR(14,H1)`.
- Skip trade when computed stop distance is less than four current spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- Trade only during liquid London/New York overlap for FX and index CFDs.
- Skip first H1 bar after weekly open.
- Skip entries when spread exceeds 2.5x rolling median spread.

## Concepts
- [[concepts/volatility-breakout]] - entry requires price to be multiple ATRs away from its moving average.
- [[concepts/moving-average-distance]] - zero-line exit returns to the average.
- [[concepts/atr-normalisation]] - threshold is volatility-scaled across DWX instruments.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus author handle `andrasnm`. |
| R2 Mechanical | PASS | Entry and exit thresholds are explicit; MA/ATR periods are test parameters. |
| R3 DWX-testbar | PASS | Volatility-normalized price rule ports directly to FX, metals, and index CFDs. |
| R4 No ML | PASS | Fixed oscillator thresholds; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`.

## Author Claims
- The source describes the PGO system as simple threshold logic around zero.
- The source says the oscillator value represents ATR distance from a moving average.

## Parameters To Test
- PGO MA period: 21, 34, 55.
- ATR period: 14, 21.
- Entry threshold: 2.0, 2.5, 3.0.
- Protective stop: 1.5, 2.0, 2.5 ATR.
- Period: M30, H1, H4.

## Initial Risk Profile
Trend/impulse continuation profile. Main risk is entering exhaustion spikes when price is already stretched far from the moving average.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
