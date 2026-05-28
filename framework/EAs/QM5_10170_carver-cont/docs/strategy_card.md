---
ea_id: QM5_10170
slug: carver-cont
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/signal-reversal-exit]]"
indicators:
  - "[[indicators/moving-average-crossover]]"
  - "[[indicators/donchian-channel]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL and Carver attribution present; R2 mechanical aggregate trend entry and reversal/flat exits with ~8 trades/year/symbol; R3 OHLC rules portable to DWX symbols with SP500 T6 caveat; R4 fixed-rule no ML one net position."
---

# Carver Continuous Starter Trend System

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/a-complete-system-for-new-traders-trading-without-a-stop-loss/
- Author / institution: Raposa, adapting Rob Carver's Starter System from Leveraged Trading
- Date: 2021-11-09
- Location: sections "Drop the Stop" and "The Trend Following System".

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute four moving-average crossover signals: 8/32, 16/64, 32/128, 64/256.
- Compute five moving-breakout signals: 20, 40, 80, 160, 320-bar breakouts.
- Aggregate all active signals with equal weights into `signal = sign(sum(weighted_signal_i))`.
- Enter long when aggregate signal > 0 and current position is flat or short.
- Enter short when aggregate signal < 0 and current position is flat or long.

### Exit
- Exit long when aggregate signal < 0, then flip short if shorts are enabled.
- Exit short when aggregate signal > 0, then flip long.
- If aggregate signal == 0, flatten.

### Stop Loss
- No source stop loss; exit is purely by trend reversal.
- Research risk wrapper for V5: catastrophic emergency stop at 5.0 * ATR(14), not used as the primary strategy exit.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- Source uses target-risk volatility sizing; V5 build should keep one net position per magic and avoid adding units.

### Zusätzliche Filter
- Warmup: 340 D1 bars to cover the longest breakout and moving average.
- Shorts enabled by default; long-only is a P3 variant.
- Do not pyramid and do not hold separate sub-signal positions; aggregate to one net direction.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/signal-reversal-exit]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL with Rob Carver attribution and visible date. |
| R2 Mechanical | PASS | Entry/exit rules are signal-threshold driven and the article explicitly replaces stop exits with trend-reversal exits. |
| R3 Data Available | PASS | OHLC/close breakout and MA logic is portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed signal set; V5 card constrains implementation to one net position and no pyramiding. |

## R3
Stock examples can be ported to SP500.DWX / NDX.DWX / WS30.DWX. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the continuous model improved returns and Sharpe in the worked example and frames the benefit as riding trends until the trend signal reverses.

## Parameters To Test
- Signal families: MA only, breakout only, MA + breakout.
- MA pairs: default set vs 16/64 only vs 8/32 + 16/64 + 32/128.
- Breakout lengths: default set vs 20/40/80 only.
- Shorts: enabled vs long-only.
- Catastrophic stop: off, 5 ATR, 8 ATR.

## Initial Risk Profile
Classic continuous trend-following model with potentially long holds and large giveback. The no-stop primary exit is intentional, but the V5 emergency stop constrains catastrophic gap risk.

## Pipeline-Verlauf
- G0: PENDING.

