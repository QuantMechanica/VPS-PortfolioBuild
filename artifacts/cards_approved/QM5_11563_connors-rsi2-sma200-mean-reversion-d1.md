---
ea_id: QM5_11563
slug: connors-rsi2-sma200-mean-reversion-d1
type: strategy
source_id: 278c6e13-0726-5779-83fe-a38f5a2e480f
sources:
  - "[[sources/connors-larry-short-term-trading-strategies-that-work]]"
concepts:
  - "[[concepts/rsi2-mean-reversion]]"
  - "[[concepts/sma200-trend-filter]]"
  - "[[concepts/oversold-pullback-buy]]"
indicators:
  - RSI(2)
  - SMA(200)
period: D1
source_citation: "Larry Connors & Cesar Alvarez, 'Short-Term Trading Strategies That Work' (TradingMarkets Publishing, 2009), Strategies 8-9 (The 2-Period RSI). R1 CONDITIONAL."
g0_status: APPROVED
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-26
expected_trades_per_year_per_symbol: 8
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX]
expected_trade_frequency: "D1 RSI(2) extreme gated by the SMA200 regime filter and no-Friday rule; conservative joint estimate 5-10 trades/year/symbol."
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Entry/exit are explicit iRSI(2) and iMA(SMA,200) threshold comparisons with an ATR safety stop — fully mechanical, MT5-native indicators."
r3_reasoning: "RSI(2) and SMA(200) compute natively on D1 DWX FX close data for EURUSD, GBPUSD, USDJPY."
r4_reasoning: "Fixed RSI/SMA thresholds and ATR stop multiple, no ML or PnL-dependent adaptation, one-position-per-magic compatible."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_11563_connors-rsi2-sma200-mean-reversion-d1.md"
g0_approval_reasoning: "R1 PASS single book lineage; R2 PASS deterministic RSI(2) extreme plus SMA200 regime entry and RSI/ATR exits with conservative joint D1 cadence; R3 PASS on listed DWX FX symbols; R4 PASS deterministic, ML-free and one position per magic."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# QM5_11563 Connors — RSI(2) + SMA(200) Mean Reversion (D1, adapted to Forex)

## Source
- Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work: A Quantified Guide to Trading Stocks and ETFs" (TradingMarkets Publishing, 2009), Strategies 8–9 "The 2-Period RSI."

## Mechanics

**Concept**: Close above SMA(200) identifies an uptrend. When the 2-period RSI drops below 10 (extreme short-term oversold), a mean-reversion bounce is expected. Buy on close. Exit when RSI(2) closes above 65. Original book designed for US stocks/ETFs; adapted here for Forex on D1. Author argues stops reduce performance ("stops hurt"); P2 adds a safety stop.

**Adaptation note**: Original tested on SPY (1995–2007). Forex adaptation is untested in the original source — P2 backtest determines viability.

### Entry
**LONG**: `iClose(D1,1) > iMA(D1,SMA,200,1)` AND `iRSI(D1,2,1) < 10` → Buy at close of next D1 bar
**SHORT**: `iClose(D1,1) < iMA(D1,SMA,200,1)` AND `iRSI(D1,2,1) > 90` → Sell (not in original — added for symmetry)

### Exit
- **LONG exit**: `iRSI(D1,2,0) > 65` → close long on next open
- **SHORT exit**: `iRSI(D1,2,0) < 35` → close short on next open

### Stop Loss
- Not in original ("stops hurt"). P2 safety stop: `2 * iATR(D1,14,1)` from entry. Cap: 150 pips.

### Position Sizing
- `RISK_FIXED = $1000` for P2. `RISK_PERCENT = 0.5%` for live.

### Additional filters
- Timeframe: D1; Instruments: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX; Spread cap: 15p; No Friday entry

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | CONDITIONAL | Co-founder TradingMarkets.com, former Merrill Lynch/DLJ broker, prolific author — self-published through own company. |
| R2 Mechanical | PASS | iRSI(period=2): iRSI. iMA(SMA,200): iMA(MODE_SMA). All MT5-native. |
| R3 Data Available | PASS | D1 DWX. |
| R4 No ML | PASS | Threshold only. |

## Pipeline history
- G0: 2026-05-23 — from Connors "Short-Term Trading Strategies That Work" (2009), Strategies 8-9

## Implementation Notes for Codex (P1)
- `double sma200 = iMA(NULL,PERIOD_D1,200,0,MODE_SMA,PRICE_CLOSE,1)`
- `double rsi2 = iRSI(NULL,PERIOD_D1,2,PRICE_CLOSE,1)`
- `double atr14 = iATR(NULL,PERIOD_D1,14,1)`
- LONG trigger: iClose[1] > sma200 && rsi2 < 10 → Buy on close (or next bar open)
- Exit long: iRSI(D1,2,current) > 65 → close on next open
- Safety SL: entry - 2*atr14 (capped at 150 pips)
- P3 sweeps: RSI entry threshold (5/10/15), RSI exit threshold (55/65/75), ATR multiplier (1.5/2.0/2.5), SMA period (100/200/50)

## Related strategies
- Related: QM5_11564 (connors-double7s-sma200-d1) — same source, 7-bar breakout version
- Related: QM5_11565 (connors-3down-days-sma200-d1) — same source, consecutive days version
- Related: QM5_11549 (carter-t-m5-bb503234-rsi3-stoch633) — RSI mean reversion M5

## Lessons Learned
- *(populated as pipeline progresses)*

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact GBPUSD.DWX/D1 configuration used by Q08 (set file `QM5_11563_connors-rsi2-sma200-mean-reversion-d1_GBPUSD.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_11563",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "11563",
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "1",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_atr_sl_mult": "2.0",
    "strategy_no_friday_entry": "true",
    "strategy_rsi_entry_long": "10.0",
    "strategy_rsi_entry_short": "90.0",
    "strategy_rsi_exit_long": "65.0",
    "strategy_rsi_exit_short": "35.0",
    "strategy_rsi_period": "2",
    "strategy_sl_cap_pips": "150",
    "strategy_sma_period": "200",
    "strategy_spread_cap_pips": "15"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "60a24c8d4a20c8d6dc725108117d7005de73690ad2466b1d962d3f1da0ed572a",
  "symbol": "GBPUSD.DWX",
  "timeframe": "D1"
}
```
