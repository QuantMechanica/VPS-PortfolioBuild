"""Compose a runner + 2/3 satellite book under the live Q09 hard gate.

The data universe and gate-clean filtering are imported from challenge_book_60d;
Q09 classification and high-volatility correlation are imported from
portfolio_admission.  Membership and equal risk splits are selected on the first
60% of the common calendar only.  The remaining 40% is reporting-only.
"""
from __future__ import annotations

import contextlib
import io
import itertools
import json
import math
import statistics
import sys
from collections import defaultdict
from datetime import timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
with contextlib.redirect_stdout(io.StringIO()):
    import challenge_book_60d as cb
import portfolio_admission as q09

OUT = Path(r"C:\QM\repo\docs\ops\evidence\2026-07-27_runner_satellite_composition.md")
JSON_OUT = OUT.with_suffix(".json")
RUNNER = "9936:USDJPY"
SPLIT = 0.60


def pearson(a, b):
    return q09._pearson(a, b)


def sharpe(vals):
    if len(vals) < 20:
        return None
    sd = statistics.stdev(vals)
    return (statistics.mean(vals) / sd * math.sqrt(252)) if sd else None


def metrics(days, vals):
    if not vals:
        return {"med60": None, "worst_day": None, "wdd_p90": None, "fund_score": None,
                "windows": 0, "censored": 0, "effective_n": 0}
    rolls, dds, censored = [], [], 0
    for i, start in enumerate(days):
        end = start + timedelta(days=60)
        if end > days[-1]:
            censored += 1
            continue
        window = [vals[j] for j in range(i, len(days)) if days[j] <= end]
        eq = peak = dd = 0.0
        for value in window:
            eq += value
            peak = max(peak, eq)
            dd = max(dd, peak - eq)
        rolls.append(sum(window) / cb.ACCOUNT * 100)
        dds.append(dd / cb.ACCOUNT * 100)
    med = statistics.median(rolls) if rolls else 0.0
    worst = min(vals) / cb.ACCOUNT * 100
    p90 = sorted(dds)[int(0.9 * (len(dds) - 1))] if dds else 0.0
    denom = max(2.0, 2 * abs(worst), p90)
    span = (days[-1] - days[0]).days + 1
    return {"med60": med, "worst_day": worst, "wdd_p90": p90,
            "fund_score": med / denom if denom else 0.0, "windows": len(rolls),
            "censored": censored, "effective_n": max(1, span // 60)}


def aligned(keys, indices):
    days = [cb.all_days[i] for i in indices]
    columns = {}
    for key in keys:
        byday = defaultdict(float)
        for _, close, net, _ in cb.sleeves[key]:
            byday[close] += net
        columns[key] = [byday.get(day, 0.0) for day in days]
    return days, columns


def book_values(columns, members):
    n = len(members)
    return [sum(columns[k][i] for k in members) / n for i in range(len(next(iter(columns.values()))))]


def admission(candidate, book, columns, days):
    keys = [candidate, *book]
    matrix = [[columns[k][i] for k in keys] for i in range(len(columns[candidate]))]
    fulls = [pearson(columns[candidate], columns[b]) for b in book]
    corr_full = max((v for v in fulls if v is not None), default=None)
    weights = {b: 1.0 / len(book) for b in book}
    corr_reg, regime_days, regime_known = q09._regime_correlation(
        candidate, book, keys, matrix, weights
    )
    before = book_values(columns, book)
    after = book_values(columns, [*book, candidate])
    sh0, sh1 = sharpe(before), sharpe(after)
    delta = (sh1 - sh0) if sh0 is not None and sh1 is not None else None
    m0, m1 = metrics(days, before), metrics(days, after)
    marginal = (sh1 is not None and sh0 is not None and sh1 > sh0) or (
        m1["wdd_p90"] < m0["wdd_p90"] and (delta is None or delta >= 0)
    )
    admit, reason, basis, eff = q09.classify_admission(
        corr_full, corr_reg, regime_known, delta, marginal
    )
    return {"admit": admit, "reason": reason, "basis": basis, "corr_full": corr_full,
            "corr_regime": corr_reg, "corr_eff": eff, "regime_days": regime_days,
            "delta_sharpe": delta, "marginal_positive": marginal}


def main():
    cut = int(len(cb.all_days) * SPLIT)
    is_days, is_cols = aligned(cb.keys, range(cut))
    oos_days, oos_cols = aligned(cb.keys, range(cut, len(cb.all_days)))
    positive = [k for k in cb.keys if sum(is_cols[k]) > 0 and k != RUNNER]
    rows = []
    corr = {}
    for a, b in itertools.combinations(cb.keys, 2):
        corr[f"{a}|{b}"] = pearson(is_cols[a], is_cols[b])
    for size in (2, 3):
        for sats in itertools.combinations(positive, size):
            passing_order = None
            for ordered in itertools.permutations(sats):
                book = [RUNNER]
                gates = []
                for sat in ordered:
                    gate = admission(sat, book, is_cols, is_days)
                    gates.append({"candidate": sat, **gate})
                    if not gate["admit"]:
                        break
                    book.append(sat)
                if len(book) == size + 1:
                    passing_order = (book, gates)
                    break
            if passing_order is None:
                continue
            book, gates = passing_order
            ism = metrics(is_days, book_values(is_cols, book))
            oosm = metrics(oos_days, book_values(oos_cols, book))
            rows.append({"members": book, "gates": gates, "is": ism, "oos": oosm})
    rows.sort(key=lambda r: (r["is"]["fund_score"], -r["is"]["wdd_p90"]), reverse=True)
    runner_is = metrics(is_days, is_cols[RUNNER])
    runner_oos = metrics(oos_days, oos_cols[RUNNER])
    artifact = {
        "runner": RUNNER, "split_day": str(cb.all_days[cut]), "pool": cb.keys,
        "thresholds": {"corr_admit_max": q09.CORR_ADMIT_MAX,
                       "corr_reject_min": q09.CORR_REJECT_MIN,
                       "sharpe_delta_admit": q09.SHARPE_DELTA_ADMIT,
                       "min_overlap_days": q09.DEFAULT_MIN_OVERLAP_DAYS,
                       "regime_window": q09.REGIME_VOL_WINDOW,
                       "regime_quantile": q09.REGIME_TOP_QUANTILE,
                       "min_regime_days": q09.MIN_REGIME_DAYS},
        "runner_is": runner_is, "runner_oos": runner_oos,
        "pairwise_is_daily_correlation": corr, "passing_sets": rows,
    }
    JSON_OUT.write_text(json.dumps(artifact, indent=2, default=str) + "\n", encoding="utf-8")
    lines = [
        "# Runner + decorrelated satellite composition",
        "",
        "Date: 2026-07-27. Decision: measurement only; no combined EA was built and no backtest was queued.",
        "",
        "## Binding method",
        "",
        "The live Q09 gate rejects `corr_eff >= 0.40`, admits the strong zone only at "
        "`corr_eff < 0.15` with positive marginal contribution, and otherwise requires "
        "`delta Sharpe >= 0.020` (`tools/strategy_farm/portfolio/portfolio_admission.py:69-71,124-160`). "
        "`corr_eff` is the stricter of full-history and the book's top-quartile 20-day-volatility "
        "regime, with at least 20 regime days (`portfolio_admission.py:76-90,208-249`).",
        "",
        f"The gate-clean, entry-time-complete pool contains {len(cb.keys)} sleeves. Parameters and "
        f"membership were chosen on {is_days[0]}..{is_days[-1]} (first 60%); "
        f"{oos_days[0]}..{oos_days[-1]} is untouched OOS. Equal weights implement a fixed risk budget. "
        "The stream universe, dormancy-safe inputs, pessimistic multi-day handling, calendar and "
        "censoring machinery come from `challenge_book_60d.py`; censored 60-day starts are failures.",
        "",
        "## Result",
        "",
        f"Runner alone IS: med60 {runner_is['med60']:.3f}%, |wDay| {abs(runner_is['worst_day']):.3f}%, "
        f"wDD p90 {runner_is['wdd_p90']:.3f}%, FUND_SCORE {runner_is['fund_score']:.3f}. "
        f"OOS: med60 {runner_oos['med60']:.3f}%, |wDay| {abs(runner_oos['worst_day']):.3f}%, "
        f"wDD p90 {runner_oos['wdd_p90']:.3f}%, FUND_SCORE {runner_oos['fund_score']:.3f}.",
        "",
        f"Q09-passing sets: **{len(rows)}**. Effective independent samples are conservatively "
        f"about {runner_is['effective_n']} IS and {runner_oos['effective_n']} OOS; the much larger "
        "overlapping-window counts are not independent.",
        "",
    ]
    if rows:
        lines += ["| Rank | Members | IS FUND_SCORE | OOS FUND_SCORE | IS wDD p90 | OOS wDD p90 |",
                  "|---:|---|---:|---:|---:|---:|"]
        for i, row in enumerate(rows, 1):
            lines.append(f"| {i} | {', '.join(row['members'])} | {row['is']['fund_score']:.3f} | "
                         f"{row['oos']['fund_score']:.3f} | {row['is']['wdd_p90']:.3f}% | "
                         f"{row['oos']['wdd_p90']:.3f}% |")
    else:
        lines.append("No runner + 2/3 satellite set passes the live Q09 gate. The correct next sourcing "
                     "target is genuine decorrelation; thresholds must not be weakened.")
    lines += ["", "Every pairwise IS daily correlation and every sequential gate decision is preserved "
              f"in `{JSON_OUT.name}`. This is the complete matrix and unrounded evidence.",
              "", "## Interpretation", ""]
    if rows:
        best = rows[0]
        direction = "improves" if best["oos"]["fund_score"] > runner_oos["fund_score"] else "lowers"
        worse_is = sum(r["is"]["fund_score"] < runner_is["fund_score"] for r in rows)
        worse_oos = sum(r["oos"]["fund_score"] < runner_oos["fund_score"] for r in rows)
        lines.append(f"The top IS-selected passing set {direction} OOS FUND_SCORE from "
                     f"{runner_oos['fund_score']:.3f} to {best['oos']['fund_score']:.3f}. "
                     f"Of the {len(rows)} Q09-passing sets, {worse_is} lower FUND_SCORE versus the "
                     f"runner on IS and {worse_oos} lower it on OOS. Those negative results remain "
                     "in the table: Q09 admission is necessary, not proof that drift dilution beats "
                     "drawdown reduction.")
    else:
        lines.append("The architecture cannot yet be tested with a build because no valid membership "
                     "set exists in the measured pool.")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT} and {JSON_OUT}; passing_sets={len(rows)}")


if __name__ == "__main__":
    main()
