---
ea_id: QM5_1166
slug: qp-gold-treasury-mom
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Gold Treasury Joint Momentum - XAUUSD.DWX

## Source

- Source: Quantpedia encyclopedia, "Cross-Asset Price-Based Regimes for Gold"
- Source citation: 2026 Quantpedia article, quantpedia.com/cross-asset-price-based-regimes-for-gold/
- Named source author: Cyril Dujava, Quant Analyst, Quantpedia.
- Location: Annual Joint-Momentum Allocation Rule, the 12-Month Gold-Treasury Regime Filter.

## Mechanics

### Entry

At each month-end:

1. Compute trailing 12-month total return for `XAUUSD.DWX` as GLD proxy.
2. Compute trailing 12-month total return for a deterministic Treasury proxy series, default `IEF_total_return.csv`.
3. If both 12-month returns are strictly positive, open or maintain long `XAUUSD.DWX` at the next D1 open.

### Exit

- If either 12-month return is non-positive at month-end, close `XAUUSD.DWX` at the next D1 open.
- Otherwise hold until the next monthly rebalance.

### Stop Loss

- Hard stop at `5.0 * ATR(20)` on D1 from entry.
- Time exit is governed by monthly signal change.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Additional Filters

- Require 270 valid D1 bars for `XAUUSD.DWX` and the Treasury proxy before first signal.
- Treasury proxy must be a versioned local CSV; EA must not call web/API live.
- Optional P3 sweep: 6-month and 12-month return horizons.

## G0 Approval Reasoning

R1 PASS Quantpedia title attribution; R2 PASS deterministic monthly gold/Treasury momentum entry/exit; R3 PASS testable on `XAUUSD.DWX` with local Treasury proxy; R4 PASS fixed non-ML one-position rule.
