---
ea_id: QM5_11091
slug: stoch-mtf-state
type: strategy
source_id: 0693c604-4f96-56ef-be79-15efe9f48b86
source_citation: "EarnForex, Stochastic Multi-Timeframe, GitHub repository and MQL5 source, https://github.com/EarnForex/Stochastic-Multi-Timeframe"
sources:
  - "[[sources/earnforex-github]]"
concepts:
  - "[[concepts/oscillator-reversion]]"
  - "[[concepts/multi-timeframe-confluence]]"
indicators: [Stochastic]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "H1/H4/D1 stochastic state alignment should occur several times per quarter; conservative estimate 24 trades/year/symbol."
expected_trades_per_year_per_symbol: 24
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-08
g0_approval_reasoning: "R1 PASS single source_id/EarnForex GitHub attribution; R2 PASS deterministic H1 stochastic cross with H4/D1 state filters, exits, and plausible >=2 trades/year/symbol cadence; R3 PASS OHLC stochastic testable on DWX FX/metals; R4 PASS deterministic non-ML one-position compatible."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# EarnForex Stochastic MTF State

## Quelle
- Source: [[sources/earnforex-github]]
- Citation: EarnForex, "Stochastic Multi-Timeframe", GitHub, accessed 2026-05-22, URL https://github.com/EarnForex/Stochastic-Multi-Timeframe.
- Author / institution: `EarnForex.com`.
- Source location: `MQL5/Indicators/MQLTA MT5 Stochastic Multi-Timeframe.mq5`, state-count and alert logic; source article URL https://www.earnforex.com/metatrader-indicators/Stochastic-Multi-Timeframe/.

## Mechanik

### Entry
- Evaluate on completed H1 bars.
- Source defaults: Stochastic `%K=5`, `%D=3`, `Slowing=3`, SMA, low/high price field, high limit 80, low limit 20.
- V5 baseline uses enabled set H1, H4, D1.
- Long signal:
  - All enabled timeframes are in source "Oversold" state: Stochastic main <= 20.
  - On the trading timeframe, Stochastic main is above Stochastic signal line, confirming upward turn.
- Short signal:
  - All enabled timeframes are in source "Overbought" state: Stochastic main >= 80.
  - On the trading timeframe, Stochastic main is below Stochastic signal line, confirming downward turn.

### Exit
- Close long when the enabled set returns to "In Range" on all selected timeframes or when the trading timeframe becomes overbought.
- Close short when the enabled set returns to "In Range" on all selected timeframes or when the trading timeframe becomes oversold.
- Catastrophic time stop: 10 H1 bars.

### Stop Loss
- Source is an indicator, not an EA, so no native SL.
- P2 baseline: ATR(14) stop at 1.8 ATR.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Use completed candles only (`CandleToCheck=CLOSED_CANDLE`).
- News blackout deferred to P8.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Public EarnForex GitHub repository plus source article URL. |
| R2 Mechanical | PASS | Stochastic limits, state aggregation, and signal-line relation are deterministic in source. |
| R3 DWX-testbar | PASS | Stochastic is OHLC-derived and available for DWX FX/metals/index CFDs. |
| R4 No ML | PASS | Fixed periods and limits; no ML, adaptive parameters, martingale, or grid. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_11089_trade-asst-conf]] - broader EarnForex confluence sibling.

## Lessons Learned
- TBD during pipeline run.
