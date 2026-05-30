---
ea_id: QM5_1191
slug: qp-pair-switch-spx-gold
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL; R2 PASS deterministic 3-month relative-return rebalance entry/exit; R3 PASS SP500.DWX backtest-only plus XAUUSD.DWX with T6 caveat; R4 PASS fixed rules, no ML/grid/martingale, one active leg."
---

# Quantpedia Paired Switching - SP500 Gold

## Quelle
- Source: Quantpedia strategy encyclopedia, "Paired Switching".
- Citation date: 2026-05-17 research extraction.
- Named source author/institution: Quantpedia strategy encyclopedia; source cites Paired Switching tactical allocation research.

## Mechanik

### Entry
At each monthly or quarterly rebalance close:
1. Compute total return over the prior 3 months for `SP500.DWX` and `XAUUSD.DWX`.
2. If `SP500.DWX` return is greater than `XAUUSD.DWX` return, hold LONG `SP500.DWX` for the next rebalance period.
3. If `XAUUSD.DWX` return is greater than `SP500.DWX` return, hold LONG `XAUUSD.DWX` for the next rebalance period.
4. If returns are equal or either input is missing, stay flat until the next scheduled rebalance.

### Exit
- Close the currently held asset at the next rebalance close before opening the new winning asset.
- Safety exit: close any stale position after 70 calendar days if the rebalance event is missed.

### Stop Loss
- Initial hard stop: 3.0x ATR(20) D1 from entry.
- No trailing stop by default; rebalance is the primary exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD for the active leg.
- Live: `RISK_PERCENT = 0.25` for the active leg.

### Zusaetzliche Filter
- First P1 implementation should use monthly rebalancing; P3 may test quarterly rebalancing.
- Use only one active leg per magic number.
- Spread filter: skip rebalance entry if spread is greater than 3x the 20-day median spread for the target symbol.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires a parallel-validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
