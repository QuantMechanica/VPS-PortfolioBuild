"""Q08.9 — Wald-Wolfowitz Runs Test + monthly profit-concentration check.

Two checks (both must PASS):
  (a) Wald-Wolfowitz runs test on the win/loss sequence — p > 0.05 means
      wins and losses are NOT significantly clustered. EAs that win-streak
      then lose-streak are exploiting a non-stationary anomaly.
  (b) Profit concentration: top 20% of months must account for ≤ 70% of
      total profit. EAs whose profit comes from a handful of huge months
      have brittle edges.
"""

from __future__ import annotations

import math
from collections import defaultdict

from .common import make_result, trade_timestamp

GATE_NAME = "8.9_runs_test"
RUNS_P_MIN = 0.05
TOP_PCT_MONTHS = 20
TOP_PCT_PROFIT_MAX = 70.0


def _runs_test_p_value(seq: list[int]) -> tuple[int, int, int, float]:
    """Wald-Wolfowitz two-sample runs test on a binary sequence (0/1).

    Returns (n_wins, n_losses, n_runs, p_value). Normal approximation:
        E[R]   = 2 n1 n2 / (n1 + n2) + 1
        Var[R] = 2 n1 n2 (2 n1 n2 - n1 - n2) / ((n1+n2)^2 (n1+n2-1))
        Z      = (R - E[R]) / sqrt(Var[R])
        p      = 2 * (1 - Φ(|Z|))   (two-tailed)
    """
    n = len(seq)
    if n < 2:
        return 0, 0, 0, 1.0
    n1 = sum(1 for x in seq if x == 1)  # wins
    n2 = n - n1                          # losses
    if n1 == 0 or n2 == 0:
        # All same — runs test undefined; treat as significantly clustered
        return n1, n2, 1, 0.0

    runs = 1
    for i in range(1, n):
        if seq[i] != seq[i - 1]:
            runs += 1

    expected = (2.0 * n1 * n2) / (n1 + n2) + 1.0
    variance_num = 2.0 * n1 * n2 * (2.0 * n1 * n2 - n1 - n2)
    variance_den = (n1 + n2) ** 2 * (n1 + n2 - 1)
    variance = variance_num / variance_den if variance_den > 0 else 0.0
    if variance <= 0:
        return n1, n2, runs, 1.0
    z = (runs - expected) / math.sqrt(variance)
    # Two-tailed p-value: 2 * (1 - Phi(|z|))
    # Phi via erf: Phi(x) = 0.5 * (1 + erf(x/sqrt(2)))
    p_value = 2.0 * (1.0 - 0.5 * (1.0 + math.erf(abs(z) / math.sqrt(2.0))))
    return n1, n2, runs, p_value


def _profit_concentration_top_pct(monthly_net: dict[int, float]) -> tuple[float, float]:
    """Returns (top_share_pct, top_n_count) — share of total positive profit
    captured by the top TOP_PCT_MONTHS% of months by P&L.
    """
    positive_months = [v for v in monthly_net.values() if v > 0]
    if not positive_months:
        return 0.0, 0
    total = sum(positive_months)
    if total <= 0:
        return 0.0, 0
    top_n = max(1, int(math.ceil(len(positive_months) * TOP_PCT_MONTHS / 100.0)))
    top_sorted = sorted(positive_months, reverse=True)[:top_n]
    top_total = sum(top_sorted)
    return (top_total / total) * 100.0, top_n


def run(trades: list[dict], **_) -> dict:
    # DL-070 (OWNER 2026-06-05): swing/low-freq track. Runs-test is still valid (with
    # somewhat lower power) at ~40 trades, which a ~10-trades/yr swing EA reaches over
    # the 9-year Q08 window (~90). Floor lowered 100 -> 40 so swing EAs are evaluated
    # instead of auto-INVALID; the test itself still judges win/loss-run randomness.
    if len(trades) < 40:
        return make_result(GATE_NAME, "INVALID",
                           value=len(trades), threshold=40,
                           detail=f"insufficient_trade_count:got={len(trades)}:need>=40")

    # Build win/loss sequence and per-month P&L stream
    seq: list[int] = []
    monthly: dict[int, float] = defaultdict(float)
    for t in trades:
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        if net == 0:
            continue  # break-even trades don't contribute to run-direction
        seq.append(1 if net > 0 else 0)
        ts = trade_timestamp(t)
        if ts is not None:
            monthly[ts.year * 100 + ts.month] += net

    n_wins, n_losses, n_runs, p_value = _runs_test_p_value(seq)
    runs_pass = (p_value > RUNS_P_MIN)

    top_share_pct, top_n = _profit_concentration_top_pct(monthly)
    concentration_pass = (top_share_pct <= TOP_PCT_PROFIT_MAX)

    overall = "PASS" if (runs_pass and concentration_pass) else "FAIL"
    reasons: list[str] = []
    if not runs_pass:
        reasons.append(f"runs_test_p={p_value:.4f}<={RUNS_P_MIN}")
    if not concentration_pass:
        reasons.append(f"top{TOP_PCT_MONTHS}pct_months_share={top_share_pct:.1f}%>{TOP_PCT_PROFIT_MAX}%")
    detail = ";".join(reasons) if reasons else (
        f"runs_p={p_value:.3f}>{RUNS_P_MIN};top{TOP_PCT_MONTHS}pct_share={top_share_pct:.1f}<{TOP_PCT_PROFIT_MAX}"
    )
    return make_result(
        GATE_NAME, overall,
        value={"runs_p_value": round(p_value, 5), "top_pct_share": round(top_share_pct, 2)},
        threshold={"runs_p_min": RUNS_P_MIN, "top_pct_max": TOP_PCT_PROFIT_MAX},
        detail=detail,
        evidence={"n_wins": n_wins, "n_losses": n_losses, "n_runs": n_runs,
                  "monthly_count": len(monthly), "top_n_months": top_n})
