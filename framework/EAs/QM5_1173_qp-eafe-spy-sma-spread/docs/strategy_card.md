---
ea_id: QM5_1173
slug: qp-eafe-spy-sma-spread
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL/title+author; R2 PASS deterministic monthly spread-vs-SMA entry/exit; R3 PASS portable to GDAXI.DWX/UK100.DWX vs SP500.DWX; R4 PASS fixed rules no ML/grid/martingale."
---

# Quantpedia EAFE-US SMA Spread Trend

## Quelle

- Source: Quantpedia "Systematic Allocation in International Equity Regimes"
- Accessed 2026-05-18.
- Named author: Cyril Dujava, Quant Analyst, Quantpedia.
- Location: Strategy B, Trend-Conditioned Spread / SMA sections.

## Mechanik

On the final trading day of each month:

1. Build a monthly total-return spread index `S = EAFE_proxy_return - US_proxy_return`.
2. Compute SMA of `S` over 12 months. Parameter sweep: 3, 6, 12, 24, 36 months.
3. If current `S >= SMA(S, lookback)`, enter LONG spread: LONG EAFE proxy and SHORT US proxy.
4. If current `S < SMA(S, lookback)`, enter SHORT spread: SHORT EAFE proxy and LONG US proxy.
5. Hold one spread position at a time and rebalance monthly.

## Exit

- Close and reverse at the next monthly rebalance when `S` crosses the SMA threshold.
- Close to flat if either leg's proxy data is missing or stale.

## Stops

- Strategy-level monthly stop: close both legs if spread drawdown from entry exceeds 2.5x monthly ATR(12) of the spread.
- Per-leg emergency stop: 3.0x monthly ATR(12).

## Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD total spread risk, split equally across two legs.
- Live: `RISK_PERCENT = 0.25` total spread risk.

## Build Port

- DWX ports: `GDAXI.DWX/SP500.DWX` and `UK100.DWX/SP500.DWX`.
- Monthly signals are computed from closed monthly bars only.
- Fixed 1:1 notional/risk split for G0/P1; no rolling beta hedge ratio.
