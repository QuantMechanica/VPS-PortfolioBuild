---
ea_id: QM5_11160
slug: dwx-brk-risk
type: strategy
source_id: 0d015701-0978-5f79-85bc-045914b12692
source_citation: "Darwinex Blog / darwinexblog, The Journey of an Automated Trading Expert, 2024-10-03, https://blog.darwinex.com/the-journey-of-an-automated-trading-expert"
sources:
  - "[[sources/darwinex-blog-trading-strategies]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/risk-control]]"
  - "[[concepts/systematic-trading]]"
indicators:
  - "[[indicators/price-channel]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX]
period: H1
expected_trade_frequency: "Simple price-channel breakout with few indicators and one hard stop; conservative estimate 40-90 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id with full Darwinex Blog URL and named interview subject Wim — lineage traceable."
r2_mechanical: PASS
r2_reasoning: "Price-channel breakout entry, TP/time/opposite-breakout exits, and ATR-derived hard SL are mechanical; exact lookback and multiplier gaps are Research defaults."
r3_data_available: PASS
r3_reasoning: "EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX are all DWX CFD instruments available in MT5 for backtesting."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed-rule breakout with one position per symbol/magic; no ML, no PnL-adaptive logic, no martingale."
pipeline_phase: G0
last_updated: 2026-05-23
g0_approval_reasoning: "R1 PASS Darwinex article URL cited; R2 PASS deterministic H1 price-channel breakout with ATR stop/TP/time exit and ~55 trades/year/symbol plausible; R3 PASS DWX FX/index OHLC testable; R4 PASS fixed non-ML one-position no grid/martingale."
---

# Darwinex Simple Breakout Risk-Control

## Quelle
- Source: [[sources/darwinex-blog-trading-strategies]]
- Citation: Darwinex Blog / `darwinexblog`, "The Journey of an Automated Trading Expert", 2024-10-03, URL https://blog.darwinex.com/the-journey-of-an-automated-trading-expert
- Author / institution: Darwinex Blog, interview subject Wim, automated trading expert and MQL5 seller.
- Source location: article section "Breakout Systems and Night Scalping" says Wim's hallmark systems are simple breakout systems with few indicators, risk control, and a stop loss on every trade.

## Mechanik

### Entry
- Baseline timeframe: H1; P3 may test M30 and H4.
- Compute rolling `breakout_lookback` high/low on closed bars; P2 default 48 bars.
- Long:
  - Previous closed bar closes above the rolling high from bars `[2..breakout_lookback+1]`.
  - Breakout bar range >= 0.75 x ATR(14).
  - Enter BUY at market on next bar open.
- Short:
  - Previous closed bar closes below the rolling low from bars `[2..breakout_lookback+1]`.
  - Breakout bar range >= 0.75 x ATR(14).
  - Enter SELL at market on next bar open.

### Exit
- TP at 1.5R.
- Time stop after `max_holding_bars`; P2 default 18 H1 bars.
- Exit on opposite breakout signal.

### Stop Loss
- Hard stop on every trade, per source risk-control emphasis.
- Initial SL = 1.5 x ATR(14) from entry, capped at the opposite side of the breakout bar if closer.
- Move to break-even at +1R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- One active position per symbol/magic.
- No grid, no martingale, no pyramiding.

### Zusaetzliche Filter
- Trade only when spread <= 10% of planned SL.
- Skip first 15 minutes after weekly market open.
- Optional session branch: London and New York active hours only for FX; cash-session proxy for GER40.DWX.

## Concepts
- [[concepts/breakout]] - price leaves a recent range and continuation is expected.
- [[concepts/risk-control]] - source emphasizes every trade has a stop loss.
- [[concepts/systematic-trading]] - simple automated rules with few indicators.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Darwinex article URL and institution/subject are cited. |
| R2 Mechanical | UNKNOWN | Source gives the breakout/risk-control skeleton but not the exact channel lookback or target; Research supplies deterministic defaults. |
| R3 DWX-testbar | PASS | Uses OHLC and ATR only on DWX FX/index symbols. |
| R4 No ML | PASS | Fixed-rule, one-position, no ML/grid/martingale/adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX.

## Author Claims
- Darwinex says Wim's breakout systems used "as few indicators as possible".
- Wim is quoted: "My strategy is not nuclear science".
- Darwinex says every trade has a stop loss.

## Parameters To Test
- `breakout_lookback`: 24, 48, 72, 96 bars.
- `atr_stop_mult`: 1.0, 1.5, 2.0, 2.5.
- `tp_rr`: 1.0, 1.5, 2.0.
- `max_holding_bars`: 12, 18, 24, 48.
- Session filter: off, London+NY, London only.

## Initial Risk Profile
Medium risk simple breakout system. The main weakness is that exact source rules are not public in the article; G0 should treat R2 as UNKNOWN rather than full PASS.

## Pipeline-Verlauf
- G0: 2026-05-23, PENDING, drafted from Darwinex blog interview article.

## Verwandte Strategien
- TBD during G0 duplicate check.

## Lessons Learned
- TBD during pipeline run.
