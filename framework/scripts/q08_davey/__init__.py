"""Q08 Davey Statistical Validation — 10 sub-gates.

Per 2026-05-23 pipeline rewrite. Vault: `03 Pipeline/Q08 Davey Statistical Validation.md`.

Sub-gates (ALL must PASS for Q08 to advance):
  8.1   correlation          — pairwise |r| < 0.50 vs existing portfolio
  8.2   dsr_mc_fdr           — DSR p < 0.05 OR FDR PASS
  8.3   tail_dependence      — tail correlation <= baseline
  8.4   seasonal             — all 12 months profitable
  8.5   neighborhood         — ±10% param perturbation: PF > 1.0, DD < 1.5× baseline
  8.6   chopping_block       — top 5% removed → PF > 1.0  (Davey signature)
  8.7   pbo                  — PBO < 0.40 via CSCV
  8.8   edge_decay           — rolling 12m PF decline < 40%
  8.9   runs_test            — Wald-Wolfowitz p > 0.05 + top-20% months ≤ 70% profit
  8.10  regime_crisis        — profitable in 3 ATR regimes; crisis slices informational

Each sub-gate is a standalone callable in its own module. The aggregator
(`aggregate.py`) runs them in order, AND-combines verdicts, writes
per-(EA, symbol) report JSON.

Common inputs:
  - trades:        list of per-trade {ts_utc, net_profit, side, lot, ...}
                   read from the EA's JSON-lines log
  - equity_stream: list of {ts_utc, equity, day_pnl, month_pnl, atr_regime}
                   read from EQUITY_SNAPSHOT events (FW6)
  - portfolio:     list of {ea_id, symbol, equity_curve} for active Q11 EAs
                   (needed by 8.1 correlation; empty pool = trivial PASS)

Common output (each sub-gate):
    {
      "name":      "8.6_chopping_block",
      "status":    "PASS" | "FAIL" | "INVALID",
      "value":     <measured value>,
      "threshold": <gate threshold>,
      "detail":    "<short explanation>",
      "evidence":  <module-specific extra data>
    }
"""

from __future__ import annotations
