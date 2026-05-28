---
ea_id: QM5_1187
slug: qp-comm-voltarget-mom
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Vol-Targeted Commodity Momentum

Approved source card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1187_qp-comm-voltarget-mom.md`.

## Mechanik

Monthly bars for the approved DWX commodity proxy basket. Candidate assets are precious metals, crude oil or Brent, and approved agricultural or industrial-metal proxies. This build uses the project-standard commodity proxy basket available in neighboring V5 commodity EAs:

- `XAUUSD.DWX`
- `XAGUSD.DWX`
- `XTIUSD.DWX`
- `XNGUSD.DWX`
- `XCUUSD.DWX`

At each monthly rebalance:

1. Compute 12-month total return for every eligible commodity proxy.
2. Compute trailing realized volatility from daily returns over the last 63 sessions.
3. Convert each commodity's return into a volatility-normalized score: `score = ROC12M / max(realized_vol_63d, floor_vol)`.
4. Rank commodities by score.
5. Long the top four proxies, or top three if fewer than six proxies pass data checks.

Exit any held commodity at the next monthly rebalance if it no longer ranks in the selected top group.

No short side. No discretionary stop in the source. The EA uses an ATR stop only to satisfy the V5 risk-distance contract for deterministic position sizing.

## Parameters

- `strategy_momentum_lookback_d1_bars=252`
- `strategy_realized_vol_d1_bars=63`
- `strategy_floor_vol_annualized=0.10`
- `strategy_top_n_normal=4`
- `strategy_top_n_narrow=3`
- `strategy_narrow_universe_threshold=6`

## Lessons Learned

The differentiator is deterministic risk normalization before commodity momentum selection. This must not become an adaptive optimizer; volatility window, floor, and caps stay fixed unless a later approved Card revision changes them.
