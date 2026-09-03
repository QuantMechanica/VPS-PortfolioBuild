#!/usr/bin/env python3
"""Sparse-D1 orthogonality standard — trade-level co-activity estimator (READ-ONLY probe).

Context: docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md gap G3 / Vorlage V4;
dossier docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md sec 3c.

Problem: tools/strategy_farm/portfolio/portfolio_correlation.py buckets daily P&L by
EXIT day, 0-fills over the union window, and floors at min_overlap_days=60. For slow
D1 sleeves (a few trades/yr) co-active EXIT days almost never coincide, so Pearson |r|
collapses to ~0 mechanically and every pair fails the 60-day floor (dossier: max
co-active exit overlap = 50, max |r| = 0.102).

This probe implements an ALTERNATIVE orthogonality statistic that stays informative at
low frequency: trade-level CO-OCCUPANCY of open-position days, with an EXACT
circular-shift (maximal-block permutation) null distribution computed over all T cyclic
rotations via FFT. It measures whether two sleeves are simultaneously in-market MORE
than their own footprints would produce if their calendars were phase-unaligned.

READ-ONLY: reads .jsonl trade streams only; writes nothing under D:/QM or C:/QM/mt5.
Not added to tools/. Emits one JSON results file next to itself.

Statistic (per pair a,b over a common calendar-day ring of length T):
  occupancy set  D_s = union over trades of [entry_day .. exit_day]  (UTC calendar days)
  o_s in {0,1}^T occupancy indicator on the ring
  O_ab           = sum_i o_a[i] o_b[i]                 (co-occupied days, observed)
  n_a, n_b       = |D_a|, |D_b|
  E_ab           = n_a * n_b / T                       (expected overlap, fixed marginals)
  Lift  Lambda   = O_ab / E_ab                         (1 = chance, >1 = clustered)
  null           = { O_ab(delta) = sum_i o_a[i] o_b[(i-delta) mod T] : delta = 0..T-1 }
                   computed EXACTLY (all T shifts) via circular cross-correlation (FFT).
                   Each shift preserves n_b and b's run-length multiset (holding periods),
                   destroying only phase alignment => Politis-Romano (1992) circular block
                   bootstrap, maximal-block (whole-series) form.
  p_upper        = #{delta : O_ab(delta) >= O_ab} / T  (delta=0 is the observed => p>=1/T;
                   Phipson-Smyth 2010 exact-permutation add-one is built in)

Refinement (signed same-instrument co-exposure), diagnostic only, defined only when both
sleeves trade the same symbol and carry a 'side' field.

Reference cross-checks reproduced for contrast: exit-day Pearson r on the both-nonzero
active-day subset (portfolio_correlation._pearson logic) and the co-active exit-day count.
"""
from __future__ import annotations

import datetime as dt
import glob
import json
import math
import os
import sys
from collections import defaultdict

import numpy as np

DURABLE = r"D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades"
COMMON = r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades"

# Qualified pool (book_build_guard.py --status --venue both => 5 Q14-terminal pairs;
# pair identities via rebaseline_census.build_pairs, read-only, 2026-09-03).
QUALIFIED = [
    (COMMON, "10706_GBPUSD_DWX", "QM5_10706", "GBPUSD"),
    (COMMON, "11421_EURUSD_DWX", "QM5_11421", "EURUSD"),
    (COMMON, "11422_USDCAD_DWX", "QM5_11422", "USDCAD"),
    (COMMON, "13054_XTIUSD_DWX", "QM5_13054", "XTIUSD"),
    (COMMON, "1537_XAGUSD_DWX", "QM5_1537", "XAGUSD"),
]

# 16 audited members with an existing Q08 stream (dossier sec 3b => 9 of 16). Durable store.
AUDITED = [
    (DURABLE, "1556_XAUUSD_DWX", "QM5_1556", "XAUUSD"),
    (DURABLE, "11132_SP500_DWX", "QM5_11132", "SP500"),
    (DURABLE, "11165_AUDCAD_DWX", "QM5_11165", "AUDCAD"),
    (DURABLE, "11165_EURUSD_DWX", "QM5_11165", "EURUSD"),
    (DURABLE, "11708_EURUSD_DWX", "QM5_11708", "EURUSD"),
    (DURABLE, "11910_NZDUSD_DWX", "QM5_11910", "NZDUSD"),
    (DURABLE, "12710_XTIUSD_DWX", "QM5_12710", "XTIUSD"),
    (DURABLE, "12778_AUDUSD_DWX", "QM5_12778", "AUDUSD_basket"),
    (DURABLE, "12969_USDJPY_DWX", "QM5_12969", "USDJPY"),
]


def load_trades(path: str) -> list[dict]:
    out = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            if r.get("event") != "TRADE_CLOSED":
                continue
            et = r.get("entry_time")
            xt = r.get("time")
            if et is None or xt is None:
                continue
            out.append(
                {
                    "entry": int(et),
                    "exit": int(xt),
                    "side": r.get("side"),
                    "notional": r.get("notional"),
                    "net": float(r.get("net")) if r.get("net") is not None else 0.0,
                }
            )
    return out


def d(ts: int) -> dt.date:
    return dt.datetime.fromtimestamp(ts, tz=dt.UTC).date()


def occupancy_days(trades: list[dict]) -> set[dt.date]:
    days: set[dt.date] = set()
    for t in trades:
        d0 = d(t["entry"])
        d1 = d(t["exit"])
        if d1 < d0:
            d0, d1 = d1, d0
        cur = d0
        while cur <= d1:
            days.add(cur)
            cur += dt.timedelta(days=1)
    return days


def entry_days(trades: list[dict]) -> set[dt.date]:
    return {d(t["entry"]) for t in trades}


def exit_day_pnl(trades: list[dict]) -> dict[dt.date, float]:
    daily: dict[dt.date, float] = defaultdict(float)
    for t in trades:
        daily[d(t["exit"])] += t["net"]
    return dict(daily)


def signed_daily_dir(trades: list[dict]) -> dict[dt.date, int]:
    """Net notional-weighted direction per occupied day; None-side trades contribute 0."""
    acc: dict[dt.date, float] = defaultdict(float)
    for t in trades:
        s = t["side"]
        if s not in ("BUY", "SELL"):
            continue
        w = float(t["notional"]) if t["notional"] is not None else 1.0
        sign = 1.0 if s == "BUY" else -1.0
        d0 = d(t["entry"]); d1 = d(t["exit"])
        if d1 < d0:
            d0, d1 = d1, d0
        cur = d0
        while cur <= d1:
            acc[cur] += sign * w
            cur += dt.timedelta(days=1)
    return {k: (1 if v > 0 else (-1 if v < 0 else 0)) for k, v in acc.items()}


def _pearson(la, lb):
    if len(la) < 2:
        return None
    ma = sum(la) / len(la); mb = sum(lb) / len(lb)
    da = [u - ma for u in la]; db = [v - mb for v in lb]
    na = math.sqrt(sum(u * u for u in da)); nb = math.sqrt(sum(v * v for v in db))
    if na == 0 or nb == 0:
        return None
    return sum(u * v for u, v in zip(da, db)) / (na * nb)


def pearson_active(a: dict[dt.date, float], b: dict[dt.date, float]):
    """Reproduce portfolio_correlation.py: Pearson on days where BOTH exit-day pnl != 0
    (min_overlap_days floor applied by the tool, not here)."""
    days = sorted(set(a) | set(b))
    pairs = [(a.get(x, 0.0), b.get(x, 0.0)) for x in days if a.get(x, 0.0) != 0.0 and b.get(x, 0.0) != 0.0]
    overlap = len(pairs)
    r = _pearson([u for u, _ in pairs], [v for _, v in pairs]) if overlap >= 2 else None
    return r, overlap


def pearson_zerofill(a: dict[dt.date, float], b: dict[dt.date, float]):
    """Reproduce dossier sec 3a text: Pearson on 0-filled daily vectors over the union window."""
    days = sorted(set(a) | set(b))
    return _pearson([a.get(x, 0.0) for x in days], [b.get(x, 0.0) for x in days]), len(days)


def ring(all_days: set[dt.date]) -> list[dt.date]:
    lo = min(all_days); hi = max(all_days)
    out = []
    cur = lo
    while cur <= hi:
        out.append(cur)
        cur += dt.timedelta(days=1)
    return out


def vec(day_set: set[dt.date], ring_days: list[dt.date], idx: dict[dt.date, int]) -> np.ndarray:
    v = np.zeros(len(ring_days), dtype=np.float64)
    for day in day_set:
        v[idx[day]] = 1.0
    return v


def circ_null(oa: np.ndarray, ob: np.ndarray) -> np.ndarray:
    """All T circular-shift overlaps O(delta)=sum_i oa[i] ob[(i-delta) mod T], via FFT."""
    T = len(oa)
    fa = np.fft.rfft(oa)
    fb = np.fft.rfft(ob)
    cc = np.fft.irfft(fa * np.conj(fb), n=T)
    return np.rint(cc).astype(np.int64)


def analyse(members: list[tuple], label: str) -> dict:
    sleeves = {}
    for base, fname, ea, sym in members:
        path = os.path.join(base, fname + ".jsonl")
        trades = load_trades(path)
        key = f"{ea}:{sym}"
        sleeves[key] = {
            "path": path.replace("\\", "/"),
            "file": fname,
            "trades": trades,
            "occ": occupancy_days(trades),
            "entry_days": entry_days(trades),
            "exit_pnl": exit_day_pnl(trades),
            "signed": signed_daily_dir(trades),
            "symbol": sym,
        }

    all_days: set[dt.date] = set()
    for s in sleeves.values():
        all_days |= s["occ"]
    ring_days = ring(all_days)
    T = len(ring_days)
    idx = {day: i for i, day in enumerate(ring_days)}

    # self-test the FFT null against brute force on a tiny case (correctness gate)
    _selftest_fft()

    per_sleeve = {}
    for key, s in sleeves.items():
        occ = s["occ"]
        yrs = defaultdict(int)
        for e in s["entry_days"]:
            yrs[e.year] += 1
        span_yrs = max(1e-9, (max(occ) - min(occ)).days / 365.25)
        holds = []
        for t in s["trades"]:
            holds.append((d(t["exit"]) - d(t["entry"])).days)
        per_sleeve[key] = {
            "file": s["file"],
            "trades": len(s["trades"]),
            "exit_active_days": len(s["exit_pnl"]),
            "occupancy_days": len(occ),
            "occupancy_frac_of_ring": round(len(occ) / T, 4),
            "first_day": min(occ).isoformat(),
            "last_day": max(occ).isoformat(),
            "entry_days_per_year": {str(y): c for y, c in sorted(yrs.items())},
            "min_entry_days_in_a_scored_year": min(yrs.values()) if yrs else 0,
            "median_hold_days": float(np.median(holds)) if holds else 0.0,
            "max_hold_days": max(holds) if holds else 0,
            "has_side": all(t["side"] in ("BUY", "SELL") for t in s["trades"]) if s["trades"] else False,
        }

    keys = sorted(sleeves)
    vecs = {k: vec(sleeves[k]["occ"], ring_days, idx) for k in keys}

    pairs = []
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            ka, kb = keys[i], keys[j]
            oa, ob = vecs[ka], vecs[kb]
            na, nb = int(oa.sum()), int(ob.sum())
            O_obs = int(np.dot(oa, ob))
            E = na * nb / T
            lam = (O_obs / E) if E > 0 else float("nan")
            null = circ_null(oa, ob)
            p_upper = float(np.mean(null >= O_obs))       # includes delta=0 => >= 1/T
            p_lower = float(np.mean(null <= O_obs))
            null_mean = float(null.mean())
            null_sd = float(null.std())
            z = (O_obs - null_mean) / null_sd if null_sd > 0 else float("nan")

            # exit-day Pearson reproduction (portfolio_correlation logic) + dossier 0-fill
            r, exit_overlap = pearson_active(sleeves[ka]["exit_pnl"], sleeves[kb]["exit_pnl"])
            r_zf, zf_days = pearson_zerofill(sleeves[ka]["exit_pnl"], sleeves[kb]["exit_pnl"])
            # testability under the co-activity null: needs a non-degenerate expected overlap
            testable = (E >= 5.0) and (na >= 30) and (nb >= 30)

            # signed same-instrument concordance on co-occupied days (diagnostic)
            psi = None
            psi_n = 0
            if sleeves[ka]["symbol"] == sleeves[kb]["symbol"]:
                sa = sleeves[ka]["signed"]; sb = sleeves[kb]["signed"]
                shared = [x for x in (sleeves[ka]["occ"] & sleeves[kb]["occ"]) if sa.get(x, 0) != 0 and sb.get(x, 0) != 0]
                psi_n = len(shared)
                if psi_n > 0:
                    agree = sum(1 for x in shared if sa[x] == sb[x])
                    disagree = psi_n - agree
                    psi = (agree - disagree) / psi_n

            pairs.append({
                "a": ka, "b": kb,
                "same_symbol": sleeves[ka]["symbol"] == sleeves[kb]["symbol"],
                "n_a": na, "n_b": nb, "ring_T": T,
                "co_occupied_days_O": O_obs,
                "expected_overlap_E": round(E, 3),
                "lift_lambda": round(lam, 3) if not math.isnan(lam) else None,
                "null_mean": round(null_mean, 3),
                "null_sd": round(null_sd, 3),
                "z": round(z, 3) if not math.isnan(z) else None,
                "p_upper_exact_allshifts": round(p_upper, 6),
                "p_lower_exact_allshifts": round(p_lower, 6),
                "testable": testable,
                "ref_exit_pearson_r_bothnonzero": round(r, 4) if r is not None else None,
                "ref_exit_coactive_overlap": exit_overlap,
                "ref_exit_pearson_r_zerofilled": round(r_zf, 4) if r_zf is not None else None,
                "ref_zerofill_union_days": zf_days,
                "signed_concordance_psi": round(psi, 3) if psi is not None else None,
                "signed_concordance_n": psi_n,
            })

    # Benjamini-Hochberg FDR on p_upper across the m pairs (alpha shown, not decided here)
    m = len(pairs)
    order = sorted(range(m), key=lambda k: pairs[k]["p_upper_exact_allshifts"])
    for alpha in (0.05,):
        crit = 0
        for rank, k in enumerate(order, start=1):
            if pairs[k]["p_upper_exact_allshifts"] <= alpha * rank / m:
                crit = rank
        reject = set(order[:crit])
        for k in range(m):
            pairs[k][f"bh_reject_at_{alpha}"] = k in reject

    pairs.sort(key=lambda p: p["p_upper_exact_allshifts"])
    return {
        "label": label,
        "ring_T_days": T,
        "ring_first": ring_days[0].isoformat(),
        "ring_last": ring_days[-1].isoformat(),
        "n_sleeves": len(keys),
        "n_pairs": m,
        "per_sleeve": per_sleeve,
        "pairs": pairs,
    }


def _selftest_fft():
    rng = np.random.default_rng(0)
    for _ in range(5):
        T = rng.integers(20, 60)
        a = (rng.random(T) < 0.3).astype(np.float64)
        b = (rng.random(T) < 0.4).astype(np.float64)
        fft_null = circ_null(a, b)
        brute = np.array([int(np.dot(a, np.roll(b, delta))) for delta in range(T)], dtype=np.int64)
        assert np.array_equal(fft_null, brute), "FFT circular-null does not match brute force"


def summarize(res: dict) -> dict:
    ps = res["pairs"]
    lifts = [p["lift_lambda"] for p in ps if p["lift_lambda"] is not None]
    return {
        "label": res["label"],
        "n_sleeves": res["n_sleeves"],
        "n_pairs": res["n_pairs"],
        "ring_T_days": res["ring_T_days"],
        "max_lift": max(lifts) if lifts else None,
        "min_lift": min(lifts) if lifts else None,
        "pairs_p_upper_below_0.05": sum(1 for p in ps if p["p_upper_exact_allshifts"] < 0.05),
        "pairs_bh_reject_0.05": sum(1 for p in ps if p.get("bh_reject_at_0.05")),
        "testable_pairs": sum(1 for p in ps if p["testable"]),
        "max_co_occupied_O": max((p["co_occupied_days_O"] for p in ps), default=0),
        "max_exit_coactive_overlap": max((p["ref_exit_coactive_overlap"] for p in ps), default=0),
        "max_abs_exit_pearson_bothnonzero": max((abs(p["ref_exit_pearson_r_bothnonzero"]) for p in ps if p["ref_exit_pearson_r_bothnonzero"] is not None), default=None),
        "max_abs_exit_pearson_zerofilled": max((abs(p["ref_exit_pearson_r_zerofilled"]) for p in ps if p["ref_exit_pearson_r_zerofilled"] is not None), default=None),
        "pairs_reaching_60day_exit_overlap": sum(1 for p in ps if p["ref_exit_coactive_overlap"] >= 60),
    }


def main() -> int:
    out = {"generated_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()}
    out["qualified_pool"] = analyse(QUALIFIED, "qualified_pool_5")
    out["audited_members"] = analyse(AUDITED, "audited_members_9")
    out["summary"] = {
        "qualified_pool": summarize(out["qualified_pool"]),
        "audited_members": summarize(out["audited_members"]),
    }
    dest = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "2026-09-03_sparse_coactivity_orthogonality_results.json")
    with open(dest, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=2, sort_keys=True)
    # console digest
    for pool_key in ("qualified_pool", "audited_members"):
        s = out["summary"][pool_key]
        print(f"\n===== {s['label']} =====")
        print(f"  sleeves={s['n_sleeves']} pairs={s['n_pairs']} ring_T={s['ring_T_days']}d")
        print(f"  max co-occupied O={s['max_co_occupied_O']}  vs  max exit-coactive overlap={s['max_exit_coactive_overlap']}  (pairs reaching 60d exit-overlap={s['pairs_reaching_60day_exit_overlap']})")
        print(f"  max |exit Pearson r|: both-nonzero={s['max_abs_exit_pearson_bothnonzero']}  0-filled(dossier)={s['max_abs_exit_pearson_zerofilled']}")
        print(f"  testable pairs (E>=5,n>=30)={s['testable_pairs']}/{s['n_pairs']}  lift range=[{s['min_lift']}, {s['max_lift']}]  p_up<0.05={s['pairs_p_upper_below_0.05']}  BH-reject@0.05={s['pairs_bh_reject_0.05']}")
        print(f"  --- pairs (sorted by p_upper) ---")
        for p in out[pool_key]["pairs"]:
            tf = "T" if p["testable"] else "u"
            print(f"    [{tf}] {p['a']:18} x {p['b']:18} O={p['co_occupied_days_O']:3} E={p['expected_overlap_E']:6} "
                  f"lift={p['lift_lambda']} z={p['z']} p_up={p['p_upper_exact_allshifts']:.4f} BH={p.get('bh_reject_at_0.05')} "
                  f"| exitOv={p['ref_exit_coactive_overlap']:3} r_bnz={p['ref_exit_pearson_r_bothnonzero']} r_zf={p['ref_exit_pearson_r_zerofilled']} "
                  f"psi={p['signed_concordance_psi']}(n={p['signed_concordance_n']})")
    print(f"\nwrote {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
