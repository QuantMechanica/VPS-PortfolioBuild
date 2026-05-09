"""
QuantMechanica V5 — Episode pack plot generator (QUA-1068).

Reads:
  summary.json         — pipeline run summary (schema below)
  mc_distribution.csv  — MC iteration rows (columns: iteration, max_dd_pct, sharpe[, final_equity])

Produces (in --out directory, default: ./assets/):
  equity_curve.png      — P2 baseline equity curve
  p3_heatmap.png        — P3 parameter sweep PF heatmap
  mc_distributions.png  — P4 MC max_dd + sharpe histograms

Usage:
  # from the episode pack directory (e.g. episodes/EP05-QM5_1003/)
  python ../../_template_assets/gen_plots.py

  # explicit paths
  python gen_plots.py --summary path/to/summary.json \\
                      --mc path/to/mc_distribution.csv \\
                      --out path/to/assets/

summary.json schema
-------------------
{
  "card": {
    "name": "QM5_1003_davey-eu-night",
    "ea_id": 1003,
    "source": "QuantMechanica V5 internal",
    "thesis": "one-line edge thesis"
  },
  "p2_baseline": {
    "symbols": ["EURUSD.DWX"],
    "timeframes": ["H1"],
    "modal_verdict": "PASS",
    "best_pf": 1.52,
    "max_dd_pct": 9.1,
    "trade_count": 387,
    "equity_curve": [[0, 10000], [1, 10045], ...]   // [trade_index, equity]
  },
  "p3_sweep": {
    "row_param": "tp_pips",
    "col_param": "sl_pips",
    "grid_pf_matrix": {
      "rows": [20, 30, 40],
      "cols": [15, 20, 25],
      "values": [[1.1, 1.4, 1.3], [1.5, 1.7, 1.6], [1.2, 1.3, 1.1]]
    },
    "total_cells": 9,
    "pass_cells": 6,
    "best_row_idx": 1,
    "best_col_idx": 1,
    "best_cell": {"tp_pips": 30, "sl_pips": 20, "pf": 1.7}
  },
  "p4_mc": {
    "iterations": 1000,
    "max_dd_mean": -12.3,
    "max_dd_p95": -18.7,
    "sharpe_mean": 0.82,
    "sharpe_p5": 0.31
  }
}

mc_distribution.csv schema
--------------------------
iteration,max_dd_pct,sharpe,final_equity
1,-12.3,0.82,11234.56
2,-9.1,1.05,12100.00
...
(final_equity column is optional)
"""

import argparse
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import pandas as pd

# Brand tokens (from branding/brand_tokens.json)
_BG        = "#020617"
_SURFACE_1 = "#0f172a"
_SURFACE_2 = "#1e293b"
_TEXT_PRI  = "#f8fafc"
_TEXT_MUT  = "#94a3b8"
_EMERALD   = "#10b981"
_FAIL      = "#ef4444"
_WARN      = "#f59e0b"


def _brand(fig, axes):
    fig.patch.set_facecolor(_BG)
    for ax in axes:
        ax.set_facecolor(_SURFACE_1)
        ax.tick_params(colors=_TEXT_MUT, labelsize=9)
        ax.xaxis.label.set_color(_TEXT_MUT)
        ax.yaxis.label.set_color(_TEXT_MUT)
        ax.title.set_color(_TEXT_PRI)
        for spine in ax.spines.values():
            spine.set_edgecolor(_SURFACE_2)


def plot_equity_curve(summary: dict, out_path: Path) -> bool:
    p2 = summary.get("p2_baseline", {})
    raw = p2.get("equity_curve", [])
    if not raw:
        print("  SKIP equity_curve.png — no equity_curve data in p2_baseline")
        return False

    ys = [r[1] if isinstance(r, (list, tuple)) else float(r) for r in raw]
    xs = list(range(len(ys)))

    fig, ax = plt.subplots(figsize=(10, 4))
    _brand(fig, [ax])

    ax.plot(xs, ys, color=_EMERALD, linewidth=1.5)
    ax.fill_between(xs, ys, min(ys), alpha=0.10, color=_EMERALD)
    ax.axhline(ys[0], color=_TEXT_MUT, linewidth=0.5, linestyle="--")

    verdict = p2.get("modal_verdict", "")
    vc = _EMERALD if verdict == "PASS" else _FAIL if verdict == "FAIL" else _WARN
    ax.set_title(f"P2 Baseline — Equity Curve  [{verdict}]", fontsize=12, color=vc)
    ax.set_xlabel("Trade #")
    ax.set_ylabel("Equity ($)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"${v:,.0f}"))

    fig.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, facecolor=_BG)
    plt.close(fig)
    print(f"  saved  {out_path}")
    return True


def plot_p3_heatmap(summary: dict, out_path: Path) -> bool:
    p3 = summary.get("p3_sweep", {})
    gm = p3.get("grid_pf_matrix")
    if not gm:
        print("  SKIP p3_heatmap.png — no grid_pf_matrix in p3_sweep")
        return False

    rows  = gm["rows"]
    cols  = gm["cols"]
    vals  = np.array(gm["values"], dtype=float)
    rlabel = p3.get("row_param", "row_param")
    clabel = p3.get("col_param", "col_param")

    best_r = p3.get("best_row_idx")
    best_c = p3.get("best_col_idx")

    fig, ax = plt.subplots(figsize=(max(6, len(cols) * 1.2), max(4, len(rows) * 0.9)))
    _brand(fig, [ax])

    vmax = max(2.0, float(np.nanmax(vals)))
    im = ax.imshow(vals, cmap="RdYlGn", vmin=0.8, vmax=vmax, aspect="auto")

    ax.set_xticks(range(len(cols)))
    ax.set_xticklabels([str(c) for c in cols], fontsize=8, color=_TEXT_MUT)
    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels([str(r) for r in rows], fontsize=8, color=_TEXT_MUT)
    ax.set_xlabel(clabel)
    ax.set_ylabel(rlabel)

    for ri in range(len(rows)):
        for ci in range(len(cols)):
            v = vals[ri, ci]
            if not np.isnan(v):
                ax.text(ci, ri, f"{v:.2f}", ha="center", va="center",
                        fontsize=7, color="black" if v > 1.1 else _TEXT_MUT)

    if best_r is not None and best_c is not None:
        rect = plt.Rectangle((best_c - 0.5, best_r - 0.5), 1, 1,
                              fill=False, edgecolor=_EMERALD, linewidth=2.5)
        ax.add_patch(rect)

    pass_n = p3.get("pass_cells", "?")
    total_n = p3.get("total_cells", "?")
    ax.set_title(f"P3 Parameter Sweep — PF Heatmap  [{pass_n}/{total_n} PASS]",
                 fontsize=11, color=_TEXT_PRI)

    cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    cbar.ax.tick_params(colors=_TEXT_MUT, labelsize=8)
    cbar.set_label("Profit Factor", color=_TEXT_MUT)

    fig.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, facecolor=_BG)
    plt.close(fig)
    print(f"  saved  {out_path}")
    return True


def plot_mc_distributions(mc_csv: Path, summary: dict, out_path: Path) -> bool:
    if not mc_csv.exists():
        print(f"  SKIP mc_distributions.png — {mc_csv} not found")
        return False

    df = pd.read_csv(mc_csv)
    missing = {"max_dd_pct", "sharpe"} - set(df.columns)
    if missing:
        print(f"  SKIP mc_distributions.png — mc_distribution.csv missing columns: {missing}")
        return False

    dd = df["max_dd_pct"].values
    sh = df["sharpe"].values
    n  = len(df)

    fig, (ax_dd, ax_sh) = plt.subplots(1, 2, figsize=(12, 4))
    _brand(fig, [ax_dd, ax_sh])

    # max_dd — smaller (more negative) = worse
    p5_dd = np.percentile(dd, 5)
    ax_dd.hist(dd, bins=40, color=_FAIL, alpha=0.7, edgecolor="none")
    ax_dd.axvline(dd.mean(), color=_WARN, linewidth=1.5, linestyle="--",
                  label=f"mean {dd.mean():.1f}%")
    ax_dd.axvline(p5_dd, color=_FAIL, linewidth=1.5, linestyle=":",
                  label=f"p5  {p5_dd:.1f}%")
    ax_dd.set_xlabel("Max Drawdown (%)")
    ax_dd.set_ylabel("Count")
    ax_dd.set_title(f"P4 MC — Max Drawdown  (n={n})", color=_TEXT_PRI)
    ax_dd.legend(fontsize=8, facecolor=_SURFACE_2, edgecolor="none", labelcolor=_TEXT_PRI)

    # sharpe
    p5_sh = np.percentile(sh, 5)
    ax_sh.hist(sh, bins=40, color=_EMERALD, alpha=0.7, edgecolor="none")
    ax_sh.axvline(sh.mean(), color=_WARN, linewidth=1.5, linestyle="--",
                  label=f"mean {sh.mean():.2f}")
    ax_sh.axvline(p5_sh, color=_FAIL, linewidth=1.5, linestyle=":",
                  label=f"p5   {p5_sh:.2f}")
    ax_sh.axvline(0, color=_TEXT_MUT, linewidth=0.8, linestyle="-")
    ax_sh.set_xlabel("Sharpe Ratio")
    ax_sh.set_ylabel("Count")
    ax_sh.set_title(f"P4 MC — Sharpe Distribution  (n={n})", color=_TEXT_PRI)
    ax_sh.legend(fontsize=8, facecolor=_SURFACE_2, edgecolor="none", labelcolor=_TEXT_PRI)

    fig.suptitle("P4 Monte Carlo Robustness Check", fontsize=13, color=_TEXT_PRI, y=1.02)
    fig.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, facecolor=_BG, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved  {out_path}")
    return True


def main():
    ap = argparse.ArgumentParser(description="Generate episode-pack plots from pipeline artifacts")
    ap.add_argument("--summary", default="summary.json",
                    help="path to summary.json (default: ./summary.json)")
    ap.add_argument("--mc", default="mc_distribution.csv",
                    help="path to mc_distribution.csv (default: ./mc_distribution.csv)")
    ap.add_argument("--out", default="assets",
                    help="output directory for PNGs (default: ./assets/)")
    args = ap.parse_args()

    sp = Path(args.summary)
    if not sp.exists():
        print(f"ERROR: {sp} not found. Run from episode pack dir or pass --summary.", file=sys.stderr)
        sys.exit(1)

    with open(sp) as f:
        summary = json.load(f)

    out_dir = Path(args.out)
    mc_path = Path(args.mc)

    print(f"Generating episode-pack plots -> {out_dir}/")
    plot_equity_curve(summary, out_dir / "equity_curve.png")
    plot_p3_heatmap(summary, out_dir / "p3_heatmap.png")
    plot_mc_distributions(mc_path, summary, out_dir / "mc_distributions.png")
    print("Done.")


if __name__ == "__main__":
    main()
