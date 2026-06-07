---
ea_id: QM5_11144
slug: vbt-macd-zero
type: strategy
source_id: 3f3833d9-8676-52e4-a822-2c5fc87bbe20
source_citation: "Oleg Polakow / vectorbt, MACDVolume example notebook, https://github.com/polakowo/vectorbt/blob/master/examples/MACDVolume.ipynb"
sources:
  - "[[sources/vectorbt-examples]]"
concepts:
  - "[[concepts/macd-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/macd]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX]
period: D1
strategy_type_flags: [symmetric-long-short, signal-reversal-exit, trend-filter-ma]
expected_trade_frequency: "D1 MACD zero-plus-signal filter, conservative estimate 8-18 trades/year/symbol."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS linked vectorbt GitHub source; R2 PASS mechanical D1 MACD zero/signal rules with plausible 8-18 trades/year/symbol; R3 PASS close-derived MACD portable to DWX FX/metals/indices; R4 PASS fixed non-ML rules one position per magic."
---

# vectorbt MACD Zero Signal Momentum

## Quelle
- Source: [[sources/vectorbt-examples]]
- Citation: Oleg Polakow / vectorbt, `examples/MACDVolume.ipynb`, GitHub repository `polakowo/vectorbt`, URL https://github.com/polakowo/vectorbt/blob/master/examples/MACDVolume.ipynb.
- Accessed 2026-05-22: GitHub URL https://github.com/polakowo/vectorbt/blob/master/examples/MACDVolume.ipynb.
- Source location: notebook code downloads daily BTC close, runs `vbt.MACD`, sets entries when MACD is above zero and above signal, exits when MACD is below zero or below signal, then uses `Portfolio.from_signals`.

## Mechanik

### Entry
- Evaluate on each completed D1 bar.
- Compute MACD on Close.
- Baseline parameters use standard MACD: fast 12, slow 26, signal 9. Source sweeps fast 2-50, slow combinations, and signal 2-20; P2 uses standard fixed defaults to avoid in-sample optimization.
- Long:
  - `MACD > 0`.
  - `MACD > Signal`.
  - Previous bar did not satisfy both conditions, or no open long exists.
  - Enter long at next bar open.
- Short DWX port:
  - `MACD < 0`.
  - `MACD < Signal`.
  - Enter short at next bar open.

### Exit
- Long exit when `MACD < 0` or `MACD < Signal`.
- Short exit when `MACD > 0` or `MACD > Signal`.

### Stop Loss
- Source uses indicator exit only.
- V5 safety stop: 2.5 * ATR(14), frozen at entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent-risk if approved.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Reject entries if MACD has fewer than `SlowWindow + SignalWindow` initialized bars.
- No walk-forward parameter selection in live logic; fixed parameters only for R4.

## Concepts
- [[concepts/macd-momentum]] - MACD above/below zero defines directional momentum regime.
- [[concepts/trend-following]] - signal-line relationship times entries and exits.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full GitHub URL plus named project author Oleg Polakow / vectorbt. |
| R2 Mechanical | PASS | MACD entry and exit inequalities are explicit and deterministic. |
| R3 DWX-testbar | PASS | Uses close-derived MACD and ATR only, testable on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed non-ML indicator rules; optimization grid is research-only, not adaptive runtime logic. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, NDX.DWX.

## Author Claims
- Source code labels the long condition as MACD above zero and above signal.
- Source code labels exit as MACD below zero or below signal.

## Parameters To Test
- MACD fast/slow/signal: 12/26/9 baseline, 8/21/5, 16/34/9.
- Exit strictness: exit on either zero breach or signal breach vs both.
- Safety stop: 2.0, 2.5, 3.0 * ATR(14).
- Direction: symmetric long/short vs long-only.

## Initial Risk Profile
Momentum filter risk is whipsaw in sideways markets and delayed exits after volatility shocks. Source is BTC daily, so DWX portability must be judged by P2/P3 evidence, not assumed edge persistence.

## Framework Alignment
- No-Trade: V5 kill-switch, news mode, Friday close where enabled.
- Entry: MACD zero-line plus signal-line condition on completed bars.
- Management: fixed safety SL only.
- Close: MACD zero-line or signal-line reversal.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from vectorbt examples.

## Verwandte Strategien
- Existing MACD cards may share the same indicator family; this card is specifically the vectorbt zero-line plus signal-line rule.

## Lessons Learned
- TBD during pipeline run.
