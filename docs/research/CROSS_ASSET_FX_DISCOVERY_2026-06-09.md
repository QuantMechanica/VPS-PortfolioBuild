# Cross-Asset FX Edge Discovery — own-data, hypothesis-first

**Author:** Claude · **Date:** 2026-06-09 · **Status:** research result (in-house edge discovery, OWNER-requested)
**Data:** H1+D1 OHLC for 12 FX symbols (2017-10 → 2024-12), exported from a **dedicated `D:/QM/mt5/T_Export`
terminal** (clone of T1 minus the 36GB tick cache; zero factory-rotation collision) via
`framework/scripts/mt5_diagnostics/Export_FX_Bars.mq5`. Analysis: `analyze_cross_asset.py` (H1 screen) +
`analyze_cross_asset_v2.py` (D1 net-of-cost backtests). Pure stdlib, DEV 2017-2022 / OOS 2023-2025.

## Method discipline
Cross-asset mining is the MOST overfitting-prone approach (our own ~88% Q04 death proves it). So:
hypothesis-first + strict DEV/OOS + economic cause required + report GROSS vs NET (H1 round-trip
~0.8bp modeled; spread/slippage/swap not fully — the pipeline is the real cost judge).

## Results

| Hypothesis | Gross | Net (after ~0.8bp/leg) | Verdict |
|---|---|---|---|
| **Lead-lag** (ret_A[t] → ret_B[t+1]) | DEV IC ~0.03-0.04, **OOS sign-flips** | OOS Sharpe −1.3 to −4.3 | **DEAD** — arbitraged at liquid-FX H1, unstable OOS |
| **Cross-sectional USD reversion** (diverging USD pair reverts — OWNER's idea) | **OOS gross Sharpe 2.47** (real, persists OOS!) | H1 net −16, **D1 net −0.55** | **DEAD net** — real edge, smaller than the cost to harvest it (turnover). Exactly what the cost gates catch. |
| **AUDUSD~NZDUSD cointegration pairs** (z>±2 in / z<0.5 out, hedge 0.93) | OOS rev gross Sharpe 5.84 | **OOS net Sharpe 1.29, +5.68%, ~7 trades/yr** | **SURVIVOR** (low-freq, cost-friendly) — but DEV weak (0.13) → regime-sensitive |
| EURUSD~GBPUSD / USDCHF~USDCAD pairs | OOS 0.63 / −0.36 | — | weak / dead |

## The one candidate: AUDUSD~NZDUSD cointegration pairs-trade
- **Economic cause:** AUD & NZD are both Antipodean commodity/risk currencies driven by the same factors
  (China demand, commodity cycle, risk sentiment, rate differentials) → their USD crosses are tightly
  cointegrated (DEV hedge 0.93, spread AC1 0.9994). Divergences in the spread mean-revert.
- **Mechanics (near-zero-param):** spread = ln(AUDUSD) − 0.93·ln(NZDUSD); rolling z (lookback ~60 D1 bars);
  **enter** short-spread at z>+2 / long-spread at z<−2; **exit** at |z|<0.5. ~7 trades/yr/instrument-pair.
- **Honest caveats:** (1) DEV Sharpe only 0.13 vs OOS 1.29 — regime-sensitive, not a slam dunk; one OOS
  window + 14 trades = low statistical power. (2) **D1 holds incur SWAP** (unmodeled here) → ties directly
  to the deferred `live_swap.json`; for a multi-day pairs hold, swap is material. (3) Classic, well-known
  stat-arb → likely partly arbitraged; the pipeline (real spread+swap+recalibrated gates) is the true test.

## Recommendation
Mechanize the AUDUSD~NZDUSD cointegration pairs-trade as a near-zero-param **Edge Lab card** (2-leg
single-host basket EA, per the QM5_10717 reference recipe) and route it through the pipeline — which now
applies realistic cost (DL-073 notional + DL-072 cushion) and is the honest judge. Cross-sectional
reversion + lead-lag: **do not pursue** (cost-killed / dead), but the cross-sectional result confirms
OWNER's intuition was directionally right — the edge is real, just sub-cost.

## v3 — systematic scan (idea generation, data-tested)
`analyze_cross_asset_v3.py`: cointegration scan over ALL 66 FX pairs + triangular mispricing.
Disciplined null-heavy result — only **2 of 66 pairs** cleared (DEV>0 AND OOS net Sharpe>0.8 AND ≥4 trades):

| pair | DEV | OOS net Sharpe | OOS ret | OOS trades | half-life | verdict |
|---|---|---|---|---|---|---|
| **EURJPY~GBPJPY** | 0.59 | **1.53** | +5.98% | 24 | 35d | **STRONGEST — carded QM5_12533** (positive DEV *and* OOS; common JPY leg + European-risk factor) |
| AUDUSD~NZDUSD | 0.13 | 1.29 | +5.68% | 14 | 65d | carded QM5_12532 (OOS-only; regime-sensitive) |

**Triangular mispricing (EURJPY=EUR+JPY, GBPJPY, AUDJPY, EURGBP, EURAUD): ALL DEAD net**
(OOS net Sharpe −1.1 to −3.4) — the 3-leg cost annihilates the tiny residual; HFT territory, no edge for us at D1.

## Carded (routed to pipeline, force_build)
- **QM5_12532** edgelab-audnzd-cointegration
- **QM5_12533** edgelab-eurjpy-gbpjpy-cointegration (the stronger one)
Both 2-leg market-neutral RV basket EAs (QM5_10717 recipe); the pipeline (DL-073 notional + DL-072 cushion + swap) is the judge.

## Forward idea menu (not yet tested — need data we haven't exported)
- **Risk-on/off cross-asset:** export NDX/SP500/XAUUSD bars, test JPY/CHF (havens) & gold vs equity-index
  selloffs (lead/lag + reversion across asset classes — genuinely orthogonal to FX-only).
- **Regime-conditioned pairs:** does cross-sectional FX dispersion (or VIX-proxy) predict when the
  cointegration pairs revert fastest → a regime filter to lift the pairs Sharpe.
- **Gold-USD / gold-AUD structural link** (XAUUSD vs AUDUSD commodity-currency beta).

Reusable tooling kept: `T_Export` terminal + the export/analysis scripts (re-run for any future
cross-asset study; re-export to refresh data, or add NDX/SP500/XAUUSD to Export_FX_Bars.mq5 for the risk-on/off menu).
