"""Marginal-contribution evaluator (DL-082 §4, Spur 2 / portfolio lane) — v1.

Purpose
-------
A weaker-but-diversifying EA is book-relevant. When a candidate PARKS at Q05
(``FAIL_DD_PORTFOLIO_REVIEW``) or is otherwise proposed, this tool answers ONE
question with evidence: *does joining the sealed book at its capped inverse-vol
weight help the composite?* It never admits anything — it emits a decision-paper
(JSON + Markdown) whose recommendation (ADMIT-CANDIDATE / WEAK / REJECT) is an
input to the OWNER admission gate, which stays the sole authority.

What it computes
----------------
1. Candidate weight per **capped inverse-vol** (cap 1.0, total 9.75), the book's
   own ``weight_method`` — recomputed over incumbent ∪ candidate (daily-vol
   basis; verified to reproduce the sealed 24-sleeve weights exactly, err 0.0000).
2. Composite **ΔSharpe / ΔMaxDD / Δworst-day** of the book with vs without the
   candidate, both sides weighted by the same capped-inv-vol rule so the delta
   isolates the candidate (portfolio_kpi daily-basis metrics).
3. **Regime-split correlation** of the candidate vs the incumbent book: the
   window is split into thirds (disjoint sub-windows) plus a high-volatility
   subset (top-quintile days by |book daily PnL|), with a monthly cross-check —
   diversification must hold OUT of any single regime, not only full-sample.
4. **Minimum-contribution** (ops-worthiness): the candidate's annualized
   net-of-cost return contribution AT its book weight vs an ops-cost floor
   constant (config). A sleeve that adds less than the floor is not worth the
   live operational overhead (magic slot, chart, monitoring, review cadence).

Provenance / the 4.5x-lesson (2026-07-xx sealed-stream discipline)
------------------------------------------------------------------
Streams are read only through ``portfolio_common`` loaders on a report.htm /
q08 sealed-stream basis. The default book basis is the sealed bundle named in the
manifest ``stream_basis.bundle`` (``load_streams`` reads ``<bundle>/QM/q08_trades``),
NOT the mutable MT5 Common export. ``--frozen-manifest`` accepts a SHA-pinned
FrozenStreamBundle for the strictest provenance.

OOS-validation spirit (reused from the 2026-07-11 weighting validation)
-----------------------------------------------------------------------
``dxz_weight_oos_validation.py`` established that a portfolio claim must hold
OUT-OF-SAMPLE, not just in-sample. This tool reuses: (a) the capped inverse-vol
weighting (``capnorm``, cap 1.0 / total 9.75, daily-vol basis); (b) the
sub-window hold-out discipline — its 60/40 walk-forward folds become our
regime thirds, and its "must win in BOTH folds" rule becomes "diversification /
contribution must hold across ALL thirds and the high-vol stress subset". It
deliberately does NOT reuse the Darwin/VaR objective (DXZ-payout specific); here
the objective is the book's own Sharpe / MaxDD / worst-day / diversification.

Usage
-----
    py marginal_contribution_eval.py --candidate 13213:XAUUSD.DWX
    py marginal_contribution_eval.py --candidate 13128:NDX.DWX          # book member -> re-add sanity
    py marginal_contribution_eval.py --candidate 12700:USDJPY.DWX \
        --candidate-stream-dir D:/QM/reports/some_sealed_bundle \
        --book-manifest D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json

Read-only: no DB writes, no queue mutations, no terminal starts.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, r"C:/QM/repo")

try:  # numpy is available in the VPS Python311 env; guard for tidy failure.
    import numpy as np
except ModuleNotFoundError:  # pragma: no cover
    np = None  # type: ignore[assignment]

from tools.strategy_farm.portfolio.portfolio_common import (
    align,
    load_frozen_stream_bundle,
    load_streams,
    to_daily_pnl,
    to_monthly_pnl,
)
from tools.strategy_farm.portfolio.portfolio_kpi import (
    max_drawdown_pct,
    metrics_from_daily_pnl,
)

# --------------------------------------------------------------------------- #
# Config — documented, OWNER-tunable. The DL fixes the WEIGHTING convention
# (cap 1.0 / total 9.75). The recommendation thresholds and ops-cost floor were
# CALIBRATED evidence-based 2026-07-20 on OWNER's order (DL-083; evidence in
# artifacts/portfolio/marginal_contribution/threshold_calibration_20260720/)
# and are echoed into every decision-paper so a reviewer sees exactly which
# numbers drove the verdict.
# --------------------------------------------------------------------------- #
CONFIG = {
    "cap_pct": 1.0,                  # per-sleeve cap (existing convention)
    "total_risk_pct": 9.75,          # book risk budget (overridden by manifest)
    "starting_capital": 100_000.0,   # HR4 fixed-risk deposit (overridden by manifest)
    # Minimum-contribution / ops-worthiness: the candidate must add at least this
    # much ANNUALIZED net-of-cost return (in % of starting capital) AT its book
    # weight to justify the operational cost of running a live sleeve.
    # CALIBRATED 2026-07-20 (OWNER order, DL-083 / threshold_calibration_20260720):
    # anchored at the sealed Final-24 book's own MINIMUM accepted per-sleeve
    # contribution (0.063%/yr, 12778/AUDUSD). The prior 0.15 placeholder would
    # have rejected 5 of 24 revealed-accepted incumbents. Slippage ledger
    # (sub-1 bps/fill) confirms drag << floor.
    "ops_cost_floor_ann_pct": 0.06,
    # Diversification bands on |correlation| vs the incumbent book (regime-split).
    # CALIBRATED 2026-07-20: admit ceiling = book's revealed member↔rest-book
    # regime corr p95=0.143 / max=0.173 (crisis-adjusted pairwise-calm p90
    # 0.08+0.068≈0.148); hard reject = Q09 empirical redundancy cliff
    # (admit-rate→0 above 0.35 across 74 evals; max-ever-admitted corr 0.263).
    # Priors were 0.35 (=2x book max) / 0.70 (never reached).
    "regime_corr_admit_max": 0.15,   # below this in every regime => clearly diversifying
    "regime_corr_reject_min": 0.40,  # at/above this across regimes => redundant
    # Near-zero bands for the composite deltas (avoid recommending on noise).
    # CALIBRATED 2026-07-20: block-bootstrap SE(ΔSharpe)≈0.060, so the prior
    # 0.010 (~0.17 SE) sat deep inside noise. 0.020 demotes the one noise-driven
    # ADMIT (10848/XAUUSD, ΔS +0.0165, bootstrap P(ΔS<=0)=45%). NB: 0.02 is
    # still <1 SE — ΔSharpe must never be the SOLE admit driver (the
    # diversify+DD+ops co-gates enforce that).
    "sharpe_delta_eps": 0.020,       # |ΔSharpe| below this = neutral
    "maxdd_delta_eps_pct": 0.05,     # |ΔMaxDD %pts| below this = neutral
    "high_vol_quantile": 0.80,       # high-vol subset = top 20% of days by |book PnL|
}

Key = tuple[int, str]


# --------------------------------------------------------------------------- #
# Weighting — capped inverse-vol (capnorm), reused verbatim from the 2026-07-11
# weighting validation. Daily-vol basis (confirmed to reproduce the sealed book
# weights exactly).
# --------------------------------------------------------------------------- #
def capnorm(scores: list[float], total: float, cap: float) -> list[float]:
    n = len(scores)
    if n == 0:
        return []
    x = list(scores)
    if sum(x) <= 0:
        x = [1.0] * n
    w = [xi / sum(x) * total for xi in x]
    capped = [False] * n
    for _ in range(200):
        over = [i for i in range(n) if not capped[i] and w[i] > cap]
        if not over:
            break
        excess = 0.0
        for i in over:
            excess += w[i] - cap
            w[i] = cap
            capped[i] = True
        free = [i for i in range(n) if not capped[i]]
        denom = sum(x[i] for i in free)
        if denom <= 0:
            break
        for i in free:
            w[i] += excess * (x[i] / denom)
    return w


def _pstd_column(matrix, col: int, n_rows: int) -> float:
    vals = [float(matrix[r][col]) for r in range(n_rows)]
    k = len(vals)
    if k == 0:
        return 0.0
    mean = sum(vals) / k
    return math.sqrt(sum((v - mean) ** 2 for v in vals) / k)


def capped_inverse_vol_weights(keys: list[Key], matrix, total: float, cap: float) -> dict[Key, float]:
    """Daily-vol capped inverse-vol weights (risk_percent units, sum == total)."""
    n_rows = len(matrix)
    inv = []
    for col in range(len(keys)):
        std = _pstd_column(matrix, col, n_rows)
        inv.append(1.0 / std if std > 0 else 0.0)
    w = capnorm(inv, total, cap)
    return {keys[i]: w[i] for i in range(len(keys))}


# --------------------------------------------------------------------------- #
# Metrics helpers
# --------------------------------------------------------------------------- #
def _book_daily_pnl(keys: list[Key], matrix, weights: dict[Key, float]) -> list[float]:
    wv = [float(weights.get(k, 0.0)) for k in keys]
    if np is not None:
        return [float(v) for v in (np.asarray(matrix, dtype=float) @ np.asarray(wv, dtype=float))]
    return [sum(float(row[c]) * wv[c] for c in range(len(keys))) for row in matrix]


def _worst_day_pct(daily_pnl: list[float], starting_capital: float) -> float:
    return (min(daily_pnl) / starting_capital * 100.0) if daily_pnl else 0.0


def _metrics(daily_pnl: list[float], n_sleeves: int, starting_capital: float) -> dict:
    m = metrics_from_daily_pnl(daily_pnl, n_sleeves=n_sleeves, starting_capital=starting_capital)
    m["worst_day_pct"] = round(_worst_day_pct(daily_pnl, starting_capital), 6)
    return m


def _pearson(a: list[float], b: list[float]) -> float | None:
    if len(a) != len(b) or len(a) < 3:
        return None
    if np is not None:
        va, vb = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
        if va.std() == 0 or vb.std() == 0:
            return None
        return float(np.corrcoef(va, vb)[0, 1])
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    cov = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    da = math.sqrt(sum((x - ma) ** 2 for x in a))
    db = math.sqrt(sum((x - mb) ** 2 for x in b))
    if da == 0 or db == 0:
        return None
    return cov / (da * db)


# --------------------------------------------------------------------------- #
# Book manifest loading
# --------------------------------------------------------------------------- #
def load_book(manifest_path: Path) -> dict:
    m = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
    sleeves = m.get("sleeves") or m.get("book") or []
    keys: list[Key] = []
    weights: dict[Key, float] = {}
    for s in sleeves:
        k = (int(s["ea_id"]), str(s["symbol"]))
        keys.append(k)
        weights[k] = float(s.get("risk_percent", s.get("weight", 0.0)))
    basis = m.get("stream_basis") or {}
    bundle = basis.get("bundle") if isinstance(basis, dict) else None
    return {
        "manifest_path": str(manifest_path),
        "keys": keys,
        "manifest_weights": weights,
        "bundle": Path(bundle) if bundle else None,
        "total_risk_pct": float(m.get("total_risk_pct", CONFIG["total_risk_pct"])),
        "starting_capital": float(m.get("starting_capital", CONFIG["starting_capital"])),
        "weight_method": m.get("weight_method"),
        "kpis": m.get("kpis"),
    }


# --------------------------------------------------------------------------- #
# Stream assembly (sealed basis only)
# --------------------------------------------------------------------------- #
def assemble_series(
    book: dict,
    candidate: Key,
    incumbent_keys: list[Key],
    candidate_dir: Path,
    frozen_manifest: Path | None,
) -> tuple[list[Key], list[dt.date], object, Key, dict]:
    """Return (aligned_keys, dates, matrix, candidate_key, provenance).

    Incumbent streams come from the book bundle; the candidate stream from
    ``candidate_dir`` (default = book bundle) or a SHA-pinned frozen manifest.
    All are aligned on one common daily grid.
    """
    provenance: dict = {}
    series: dict[Key, dict] = {}

    book_bundle = book["bundle"]
    if book_bundle is None:
        raise SystemExit("[FATAL] manifest has no stream_basis.bundle")
    inc_streams = load_streams(book_bundle, candidates=incumbent_keys)
    missing_inc = sorted(set(incumbent_keys) - set(inc_streams))
    if missing_inc:
        raise SystemExit(f"[FATAL] incumbent streams missing in bundle: {missing_inc!r}")
    for k, trades in inc_streams.items():
        series[k] = to_daily_pnl(trades)
    provenance["incumbent_basis"] = str(book_bundle)
    provenance["incumbent_n_keys"] = len(incumbent_keys)

    # Candidate stream.
    if frozen_manifest is not None:
        bundle = load_frozen_stream_bundle(frozen_manifest, expected_keys=[candidate])
        cand_trades = bundle.streams[candidate]
        info = bundle.info[candidate]
        provenance["candidate_basis"] = "frozen_bundle"
        provenance["candidate_manifest"] = str(frozen_manifest)
        provenance["candidate_sha256"] = info.sha256
    else:
        cand_streams = load_streams(candidate_dir, candidates=[candidate])
        if candidate not in cand_streams:
            raise SystemExit(
                f"[FATAL] candidate stream {candidate!r} not found under {candidate_dir}"
            )
        cand_trades = cand_streams[candidate]
        provenance["candidate_basis"] = str(candidate_dir)
    series[candidate] = to_daily_pnl(cand_trades)
    provenance["candidate_trades"] = len(cand_trades)
    if cand_trades:
        provenance["candidate_first_close"] = dt.datetime.fromtimestamp(
            min(t.time for t in cand_trades), tz=dt.UTC
        ).date().isoformat()
        provenance["candidate_last_close"] = dt.datetime.fromtimestamp(
            max(t.time for t in cand_trades), tz=dt.UTC
        ).date().isoformat()
    provenance["candidate_monthly"] = to_monthly_pnl(cand_trades)

    aligned_keys, dates, matrix = align({k: v for k, v in series.items() if v})
    return aligned_keys, dates, matrix, candidate, provenance


# --------------------------------------------------------------------------- #
# Core evaluation
# --------------------------------------------------------------------------- #
def evaluate(book: dict, candidate: Key, candidate_dir: Path, frozen_manifest: Path | None) -> dict:
    cfg = CONFIG
    total = book["total_risk_pct"]
    cap = cfg["cap_pct"]
    sc = book["starting_capital"]

    is_book_member = candidate in book["keys"]
    incumbent_keys = [k for k in book["keys"] if k != candidate]

    aligned_keys, dates, matrix, cand, prov = assemble_series(
        book, candidate, incumbent_keys, candidate_dir, frozen_manifest
    )
    col = {k: i for i, k in enumerate(aligned_keys)}
    inc_aligned = [k for k in aligned_keys if k != cand]
    n_rows = len(matrix)
    years = ((dates[-1] - dates[0]).days / 365.25) if len(dates) > 1 else 0.0

    # --- weights: capped inverse-vol before (incumbent) and after (+candidate) ---
    def _submatrix(keys: list[Key]):
        idx = [col[k] for k in keys]
        return [[float(matrix[r][j]) for j in idx] for r in range(n_rows)]

    w_before = capped_inverse_vol_weights(inc_aligned, _submatrix(inc_aligned), total, cap)
    all_after = inc_aligned + [cand]
    w_after = capped_inverse_vol_weights(all_after, _submatrix(all_after), total, cap)
    cand_weight = w_after[cand]

    # --- composite metrics before vs after (consistent weighting) ---
    before_pnl = _book_daily_pnl(inc_aligned, _submatrix(inc_aligned), w_before)
    after_pnl = _book_daily_pnl(all_after, _submatrix(all_after), w_after)
    before_m = _metrics(before_pnl, len(inc_aligned), sc)
    after_m = _metrics(after_pnl, len(all_after), sc)

    def _d(after, before):
        if after is None or before is None:
            return None
        return round(after - before, 6)

    deltas = {
        "d_sharpe": _d(after_m["sharpe"], before_m["sharpe"]),
        "d_maxdd_pct": _d(after_m["max_drawdown_pct"], before_m["max_drawdown_pct"]),
        "d_worst_day_pct": _d(after_m["worst_day_pct"], before_m["worst_day_pct"]),
    }

    # --- minimum-contribution: candidate ann net-of-cost return AT its weight ---
    cand_col = col[cand]
    cand_daily = [float(matrix[r][cand_col]) for r in range(n_rows)]
    cand_total_contrib = sum(cand_daily) * cand_weight
    cand_ann_contrib_pct = (cand_total_contrib / years / sc * 100.0) if years > 0 else 0.0
    ops_worthy = cand_ann_contrib_pct >= cfg["ops_cost_floor_ann_pct"]

    # --- regime-split correlation: candidate vs incumbent book (w_before) ---
    inc_book_daily = _book_daily_pnl(inc_aligned, _submatrix(inc_aligned), w_before)
    thirds = []
    cut1, cut2 = n_rows // 3, 2 * n_rows // 3
    segments = {
        "third_1": range(0, cut1),
        "third_2": range(cut1, cut2),
        "third_3": range(cut2, n_rows),
    }
    for name, rng in segments.items():
        idx = list(rng)
        c = _pearson([cand_daily[i] for i in idx], [inc_book_daily[i] for i in idx])
        thirds.append({"segment": name, "n_days": len(idx), "corr": (round(c, 4) if c is not None else None)})
    # high-vol subset: top-quantile days by |incumbent book PnL|
    absb = sorted(abs(x) for x in inc_book_daily)
    thr = absb[int(cfg["high_vol_quantile"] * (len(absb) - 1))] if absb else 0.0
    hv_idx = [i for i in range(n_rows) if abs(inc_book_daily[i]) >= thr and thr > 0]
    hv_corr = _pearson([cand_daily[i] for i in hv_idx], [inc_book_daily[i] for i in hv_idx])
    overall_corr = _pearson(cand_daily, inc_book_daily)
    # monthly cross-check (structural low-freq sleeves have near-empty daily overlap)
    cand_month = prov.get("candidate_monthly", {})
    inc_month: dict[str, float] = {}
    for i, d in enumerate(dates):
        inc_month[f"{d.year:04d}-{d.month:02d}"] = inc_month.get(f"{d.year:04d}-{d.month:02d}", 0.0) + inc_book_daily[i]
    common_m = sorted(set(cand_month) & set(inc_month))
    monthly_corr = _pearson([cand_month[m] for m in common_m], [inc_month[m] for m in common_m]) if len(common_m) >= 3 else None

    regime_corrs = [t["corr"] for t in thirds if t["corr"] is not None]
    if hv_corr is not None:
        regime_corrs.append(round(hv_corr, 4))
    max_abs_regime_corr = max((abs(c) for c in regime_corrs), default=None)
    min_abs_regime_corr = min((abs(c) for c in regime_corrs), default=None)

    correlation = {
        "overall_daily_corr": round(overall_corr, 4) if overall_corr is not None else None,
        "thirds": thirds,
        "high_vol_subset": {"n_days": len(hv_idx), "corr": round(hv_corr, 4) if hv_corr is not None else None,
                            "threshold_abs_book_pnl": round(thr, 2)},
        "monthly_corr": round(monthly_corr, 4) if monthly_corr is not None else None,
        "monthly_overlap_months": len(common_m),
        "max_abs_regime_corr": round(max_abs_regime_corr, 4) if max_abs_regime_corr is not None else None,
        "min_abs_regime_corr": round(min_abs_regime_corr, 4) if min_abs_regime_corr is not None else None,
    }

    # --- recommendation (mechanism; OWNER decides) ---
    rec, rationale = _recommend(deltas, correlation, cand_ann_contrib_pct, ops_worthy, cfg)

    return {
        "schema": "marginal_contribution_eval.v1",
        "dl": "DL-082 §4 (Spur 2 portfolio lane)",
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "candidate": {"ea_id": cand[0], "symbol": cand[1], "is_current_book_member": is_book_member},
        "evaluation_mode": "book_member_re_add_sanity" if is_book_member else "parked_candidate_join",
        "book": {
            "manifest": book["manifest_path"],
            "weight_method": book["weight_method"],
            "n_incumbent_sleeves": len(inc_aligned),
            "total_risk_pct": total,
            "cap_pct": cap,
            "starting_capital": sc,
            "window": {"from": dates[0].isoformat(), "to": dates[-1].isoformat(),
                       "n_days": n_rows, "years": round(years, 3)},
            "sealed_kpis": book["kpis"],
        },
        "candidate_weight_capped_inverse_vol": round(cand_weight, 6),
        "composite_before": before_m,
        "composite_after": after_m,
        "composite_deltas": deltas,
        "minimum_contribution": {
            "candidate_ann_net_of_cost_contrib_pct": round(cand_ann_contrib_pct, 4),
            "ops_cost_floor_ann_pct": cfg["ops_cost_floor_ann_pct"],
            "ops_worthy": ops_worthy,
            "candidate_total_net_of_cost_contrib": round(cand_total_contrib, 2),
        },
        "regime_split_correlation": correlation,
        "provenance": prov,
        "config": cfg,
        "recommendation": rec,
        "recommendation_rationale": rationale,
        "authority_note": "Recommendation is advisory only; admission remains an OWNER gate (DL-082 §4).",
    }


def _recommend(deltas, corr, cand_ann_pct, ops_worthy, cfg) -> tuple[str, list[str]]:
    r: list[str] = []
    d_sharpe = deltas["d_sharpe"] or 0.0
    d_maxdd = deltas["d_maxdd_pct"] or 0.0  # negative = book DD improved
    max_abs = corr["max_abs_regime_corr"]

    eps_s = cfg["sharpe_delta_eps"]
    eps_dd = cfg["maxdd_delta_eps_pct"]

    risk_improves = (d_sharpe > eps_s) or (d_maxdd < -eps_dd)
    risk_hurts = (d_sharpe < -eps_s) and (d_maxdd > eps_dd)
    diversifying = (max_abs is not None) and (max_abs < cfg["regime_corr_admit_max"])
    redundant = (max_abs is not None) and (max_abs >= cfg["regime_corr_reject_min"])

    r.append(f"ΔSharpe={d_sharpe:+.4f} (eps {eps_s}); ΔMaxDD={d_maxdd:+.4f}%pts (eps {eps_dd}); "
             f"Δworst-day={ (deltas['d_worst_day_pct'] or 0.0):+.4f}%pts")
    r.append(f"max|regime corr|={max_abs} (admit<{cfg['regime_corr_admit_max']}, reject>={cfg['regime_corr_reject_min']})")
    r.append(f"ann contrib={cand_ann_pct:+.4f}%/yr vs ops floor {cfg['ops_cost_floor_ann_pct']}% -> "
             f"{'ops-worthy' if ops_worthy else 'BELOW floor'}")

    if risk_hurts:
        r.append("RULE: risk-adjusted metrics degrade (Sharpe down AND MaxDD up) -> REJECT")
        return "REJECT", r
    if redundant and not risk_improves:
        r.append("RULE: redundant (high regime correlation) with no risk-adjusted gain -> REJECT")
        return "REJECT", r
    if (cand_ann_pct <= 0.0) and not (d_maxdd < -eps_dd):
        r.append("RULE: non-positive return contribution and no material DD relief -> REJECT")
        return "REJECT", r
    if diversifying and (risk_improves or d_maxdd <= 0.0) and ops_worthy:
        r.append("RULE: diversifying (low regime corr) + risk-adjusted help + ops-worthy -> ADMIT-CANDIDATE")
        return "ADMIT-CANDIDATE", r
    r.append("RULE: mixed signals (diversifying OR helpful but not all-of admit criteria) -> WEAK")
    return "WEAK", r


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
DEFAULT_MANIFEST = Path(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json")
DEFAULT_OUT = Path(r"D:/QM/strategy_farm/artifacts/portfolio/marginal_contribution")


def _parse_key(text: str) -> Key:
    ea, sep, sym = text.partition(":")
    if not sep or not sym:
        raise SystemExit(f"[FATAL] --candidate must be EA:SYMBOL, got {text!r}")
    import re
    m = re.search(r"(\d+)", ea)
    if not m:
        raise SystemExit(f"[FATAL] cannot parse ea_id from {ea!r}")
    return int(m.group(1)), sym


def _render_md(paper: dict) -> str:
    c = paper["candidate"]
    b = paper["book"]
    d = paper["composite_deltas"]
    mc = paper["minimum_contribution"]
    corr = paper["regime_split_correlation"]
    lines = [
        f"# Marginal-Contribution Decision Paper — {c['ea_id']}:{c['symbol']}",
        "",
        f"**Recommendation: {paper['recommendation']}** (advisory; OWNER admission gate decides)",
        f"- DL: {paper['dl']} · schema {paper['schema']} · generated {paper['generated_at_utc']}",
        f"- Mode: `{paper['evaluation_mode']}`" + ("  (candidate is a current book member)" if c["is_current_book_member"] else ""),
        "",
        "## Book context",
        f"- Manifest: `{b['manifest']}`",
        f"- Weight method: `{b['weight_method']}` · incumbent sleeves: {b['n_incumbent_sleeves']} · "
        f"total risk {b['total_risk_pct']} · cap {b['cap_pct']} · SC {b['starting_capital']:.0f}",
        f"- Window: {b['window']['from']} → {b['window']['to']} ({b['window']['n_days']} days, {b['window']['years']} yr)",
        f"- Sealed KPIs: {json.dumps(b['sealed_kpis'])}",
        "",
        "## Candidate weight + composite effect",
        f"- Capped inverse-vol weight when joining: **{paper['candidate_weight_capped_inverse_vol']}** (risk %)",
        "",
        "| metric | incumbent | +candidate | Δ |",
        "|---|---|---|---|",
        f"| Sharpe | {paper['composite_before']['sharpe']} | {paper['composite_after']['sharpe']} | **{d['d_sharpe']:+}** |",
        f"| MaxDD % | {paper['composite_before']['max_drawdown_pct']} | {paper['composite_after']['max_drawdown_pct']} | **{d['d_maxdd_pct']:+}** |",
        f"| worst-day % | {paper['composite_before']['worst_day_pct']} | {paper['composite_after']['worst_day_pct']} | **{d['d_worst_day_pct']:+}** |",
        "",
        "## Minimum-contribution (ops-worthiness)",
        f"- Candidate annualized net-of-cost contribution at weight: **{mc['candidate_ann_net_of_cost_contrib_pct']:+}%/yr** "
        f"(total {mc['candidate_total_net_of_cost_contrib']})",
        f"- Ops-cost floor: {mc['ops_cost_floor_ann_pct']}%/yr → **{'ops-worthy' if mc['ops_worthy'] else 'BELOW floor'}**",
        "",
        "## Regime-split correlation vs incumbent book",
        f"- Overall daily corr: {corr['overall_daily_corr']} · monthly corr: {corr['monthly_corr']} "
        f"({corr['monthly_overlap_months']} common months)",
        f"- Thirds: " + ", ".join(f"{t['segment']}={t['corr']}(n{t['n_days']})" for t in corr["thirds"]),
        f"- High-vol subset (top {int((1-paper['config']['high_vol_quantile'])*100)}% days): "
        f"corr={corr['high_vol_subset']['corr']} (n{corr['high_vol_subset']['n_days']})",
        f"- max|regime corr|={corr['max_abs_regime_corr']} · min|regime corr|={corr['min_abs_regime_corr']}",
        "",
        "## Rationale",
    ]
    lines += [f"- {x}" for x in paper["recommendation_rationale"]]
    lines += [
        "",
        "## Provenance (sealed-stream basis — 4.5x lesson)",
        f"- Incumbent basis: `{paper['provenance'].get('incumbent_basis')}` ({paper['provenance'].get('incumbent_n_keys')} keys)",
        f"- Candidate basis: `{paper['provenance'].get('candidate_basis')}` · trades={paper['provenance'].get('candidate_trades')} "
        f"({paper['provenance'].get('candidate_first_close')} → {paper['provenance'].get('candidate_last_close')})",
        "",
        f"_{paper['authority_note']}_",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="Marginal-contribution evaluator (DL-082 §4, v1)")
    ap.add_argument("--candidate", required=True, help="EA:SYMBOL, e.g. 13213:XAUUSD.DWX")
    ap.add_argument("--book-manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--candidate-stream-dir", type=Path, default=None,
                    help="common_dir containing the candidate's sealed q08 stream "
                         "(default: the book manifest's stream_basis.bundle)")
    ap.add_argument("--frozen-manifest", type=Path, default=None,
                    help="optional SHA-pinned FrozenStreamBundle manifest for the candidate")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    if np is None:
        print("[WARN] numpy unavailable; correlations use the pure-Python fallback", file=sys.stderr)

    candidate = _parse_key(args.candidate)
    book = load_book(args.book_manifest)
    candidate_dir = args.candidate_stream_dir or book["bundle"]

    paper = evaluate(book, candidate, candidate_dir, args.frozen_manifest)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"marginal_contribution_{candidate[0]}_{candidate[1].replace('.', '_')}"
    json_path = args.out_dir / f"{stem}.json"
    md_path = args.out_dir / f"{stem}.md"
    json_path.write_text(json.dumps(paper, indent=2, ensure_ascii=False), encoding="utf-8")
    md_path.write_text(_render_md(paper), encoding="utf-8")

    print(f"[{paper['recommendation']}] {candidate[0]}:{candidate[1]}  "
          f"w={paper['candidate_weight_capped_inverse_vol']}  "
          f"dSharpe={paper['composite_deltas']['d_sharpe']:+}  "
          f"dMaxDD={paper['composite_deltas']['d_maxdd_pct']:+}%  "
          f"ann_contrib={paper['minimum_contribution']['candidate_ann_net_of_cost_contrib_pct']:+}%/yr  "
          f"max|corr|={paper['regime_split_correlation']['max_abs_regime_corr']}")
    print(f"  json={json_path}")
    print(f"  md  ={md_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
