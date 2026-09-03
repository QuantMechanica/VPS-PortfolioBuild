#!/usr/bin/env python3
"""SCRATCH read-only estimator for the sparse-D1 orthogonality standard (G3/V4).

NOT part of tools/. Read-only: consumes existing Q08 net-of-cost streams and the
commission registry only; writes nothing under D:\\QM or C:\\QM\\mt5. It writes one
JSON results file next to itself (under the worktree docs/ops/evidence/).

Method (see the accompanying proposal):
  * daily net-of-cost P&L per (EA,symbol), zeros KEPT as real zeros
  * pair series aligned on the COMMON-SUPPORT window (intersection of [first,last])
    over an EXOGENOUS business-day (Mon-Fri) calendar -- no union padding, no
    co-active subsetting, no author-chosen denominator
  * point estimate: Pearson r on the zero-filled daily returns
  * uncertainty: stationary block bootstrap (Politis-Romano 1994) CI, block length
    from Politis-White (2004) / Patton-Politis-White (2009) automatic selection
  * shrinkage (portfolio layer only): bootstrap-reliability per-element shrinkage
    + Ledoit-Wolf-style intensity; ENB = N^2 / ||R||_F^2
  * controls: positive (same EA on two symbols) + negative (circular-rotation null)
"""
from __future__ import annotations

import datetime as dt
import hashlib
import itertools
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, r"C:\QM\repo")
from tools.strategy_farm.portfolio import portfolio_common as pc  # noqa: E402
from tools.strategy_farm.portfolio.commission import load_model, describe_model  # noqa: E402

RNG = np.random.default_rng(20260903)
B_BOOT = 4000
NULL_REPS = 3000
Q15_THRESHOLD = 0.5  # vault Q15 hard rule |r| < 0.5 -- the ONLY external constant

CF = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades")
DSTORE = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")

# (label, ea_id, symbol, store, filename)
QUALIFIED = [
    ("10706/GBPUSD", 10706, "GBPUSD.DWX", CF, "10706_GBPUSD_DWX.jsonl"),
    ("11421/EURUSD", 11421, "EURUSD.DWX", CF, "11421_EURUSD_DWX.jsonl"),
    ("11422/USDCAD", 11422, "USDCAD.DWX", CF, "11422_USDCAD_DWX.jsonl"),
    ("13054/XTIUSD", 13054, "XTIUSD.DWX", CF, "13054_XTIUSD_DWX.jsonl"),
    ("1537/XAGUSD", 1537, "XAGUSD.DWX", CF, "1537_XAGUSD_DWX.jsonl"),
]
AUDITED = [
    ("1556/XAUUSD", 1556, "XAUUSD.DWX", DSTORE, "1556_XAUUSD_DWX.jsonl"),
    ("11132/SP500", 11132, "SP500.DWX", DSTORE, "11132_SP500_DWX.jsonl"),
    ("11165/AUDCAD", 11165, "AUDCAD.DWX", DSTORE, "11165_AUDCAD_DWX.jsonl"),
    ("11165/EURUSD", 11165, "EURUSD.DWX", DSTORE, "11165_EURUSD_DWX.jsonl"),
    ("11708/EURUSD", 11708, "EURUSD.DWX", DSTORE, "11708_EURUSD_DWX.jsonl"),
    ("11910/NZDUSD", 11910, "NZDUSD.DWX", DSTORE, "11910_NZDUSD_DWX.jsonl"),
    ("12710/XTIUSD", 12710, "XTIUSD.DWX", DSTORE, "12710_XTIUSD_DWX.jsonl"),
    ("12778/basket", 12778, "AUDUSD.DWX", DSTORE, "12778_AUDUSD_DWX.jsonl"),
    ("12969/USDJPY", 12969, "USDJPY.DWX", DSTORE, "12969_USDJPY_DWX.jsonl"),
]

MODEL = load_model()


def sha16(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()[:16]


def load_daily(ea_id: int, symbol: str, path: Path) -> dict[dt.date, float]:
    trades = pc._load_one_stream(path, ea_id, symbol, MODEL)
    return pc.to_daily_pnl(trades)


def business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    days = []
    d = start
    one = dt.timedelta(days=1)
    while d <= end:
        if d.weekday() < 5:
            days.append(d)
        d += one
    return days


def pair_vectors(di: dict, dj: dict):
    """Zero-filled daily returns over the common-support business-day calendar.
    Also fold in any actual trade-day that falls on a weekend so no P&L is dropped."""
    si, ei = min(di), max(di)
    sj, ej = min(dj), max(dj)
    start, end = max(si, sj), min(ei, ej)
    if start > end:
        return None
    cal = set(business_days(start, end))
    # exogenous business-day calendar + any weekend trade-day inside the window
    extra = {d for d in set(di) | set(dj) if start <= d <= end and d.weekday() >= 5}
    days = sorted(cal | extra)
    x = np.array([di.get(d, 0.0) for d in days], dtype=float)
    y = np.array([dj.get(d, 0.0) for d in days], dtype=float)
    coactive = int(np.sum((x != 0.0) & (y != 0.0)))
    active_i = int(np.sum(x != 0.0))
    active_j = int(np.sum(y != 0.0))
    return dict(days=days, x=x, y=y, n=len(days), start=start, end=end,
               coactive=coactive, active_i=active_i, active_j=active_j,
               weekend_folded=len(extra))


def pearson(x: np.ndarray, y: np.ndarray) -> float:
    xd = x - x.mean()
    yd = y - y.mean()
    nx = np.sqrt((xd * xd).sum())
    ny = np.sqrt((yd * yd).sum())
    if nx == 0.0 or ny == 0.0:
        return float("nan")
    return float((xd * yd).sum() / (nx * ny))


def coactive_pearson(x: np.ndarray, y: np.ndarray):
    """The tool's estimand: Pearson on days where BOTH traded (co-active subset)."""
    mask = (x != 0.0) & (y != 0.0)
    m = int(mask.sum())
    if m < 2:
        return float("nan"), m
    return pearson(x[mask], y[mask]), m


# ---- Politis-White (2004) / PPW (2009) automatic block length for stationary bootstrap ----
def flat_top_kernel(t: np.ndarray) -> np.ndarray:
    a = np.abs(t)
    out = np.zeros_like(a)
    out[a <= 0.5] = 1.0
    mid = (a > 0.5) & (a <= 1.0)
    out[mid] = 2.0 * (1.0 - a[mid])
    return out


def autocov(z: np.ndarray, kmax: int) -> np.ndarray:
    z = z - z.mean()
    n = len(z)
    r = np.empty(kmax + 1)
    for k in range(kmax + 1):
        r[k] = np.dot(z[: n - k], z[k:]) / n
    return r


def opt_block_length_sb(z: np.ndarray) -> float:
    """Politis-White 2004 optimal stationary-bootstrap mean block length for series z.
    Returns b_opt (mean block length). PPW-2009 SB variance constant D_SB=2*(sum lambda*R)^2."""
    z = np.asarray(z, dtype=float)
    n = len(z)
    if n < 8 or np.allclose(z, z[0]):
        return 1.0
    # bandwidth M: correlogram rule (Politis-White): smallest m with |rho(k)|<c*sqrt(log10(n)/n)
    kmax = min(n - 1, int(np.ceil(10 * np.log10(n))) + 20)
    R = autocov(z, kmax)
    if R[0] <= 0:
        return 1.0
    rho = R / R[0]
    c = 2.0
    thresh = c * np.sqrt(np.log10(n) / n)
    KN = max(5, int(np.ceil(np.sqrt(np.log10(n)))))
    mhat = 0
    for k in range(1, kmax - KN + 1):
        if np.all(np.abs(rho[k : k + KN]) < thresh):
            mhat = k - 1
            break
    else:
        mhat = kmax
    M = min(max(2 * mhat, 2), kmax)
    ks = np.arange(-M, M + 1)
    Rk = np.array([R[abs(k)] for k in ks])
    lam = flat_top_kernel(ks / M)
    g = np.sum(lam * np.abs(ks) * Rk)
    Dsb = 2.0 * (np.sum(lam * Rk) ** 2)
    if Dsb <= 0 or g == 0:
        return 1.0
    b = ((2.0 * g * g) / Dsb) ** (1.0 / 3.0) * (n ** (1.0 / 3.0))
    return float(np.clip(b, 1.0, max(1.0, n / 3.0)))


def stationary_indices(n: int, b: float, B: int) -> np.ndarray:
    """Vectorized stationary-bootstrap index matrix (B,n), mean block length b."""
    p = 1.0 / max(b, 1.0)
    starts = RNG.integers(0, n, size=(B, n))
    restart = RNG.random((B, n)) < p
    restart[:, 0] = True
    idx = np.empty((B, n), dtype=np.int64)
    idx[:, 0] = starts[:, 0]
    for t in range(1, n):
        prev_plus = (idx[:, t - 1] + 1) % n
        idx[:, t] = np.where(restart[:, t], starts[:, t], prev_plus)
    return idx


def boot_corr_ci(x: np.ndarray, y: np.ndarray, b: float, B: int = B_BOOT):
    n = len(x)
    idx = stationary_indices(n, b, B)
    X = x[idx]
    Y = y[idx]
    Xd = X - X.mean(axis=1, keepdims=True)
    Yd = Y - Y.mean(axis=1, keepdims=True)
    nx = np.sqrt((Xd * Xd).sum(axis=1))
    ny = np.sqrt((Yd * Yd).sum(axis=1))
    good = (nx > 0) & (ny > 0)
    r = np.full(B, np.nan)
    r[good] = (Xd * Yd).sum(axis=1)[good] / (nx[good] * ny[good])
    r = r[np.isfinite(r)]
    if r.size < 50:
        return None
    lo, hi = np.percentile(r, [2.5, 97.5])
    return dict(mean=float(r.mean()), sd=float(r.std(ddof=1)),
               lo=float(lo), hi=float(hi),
               abs_upper=float(max(abs(lo), abs(hi))),
               n_valid=int(r.size))


def fisher_ci(r: float, nobs: int):
    if not np.isfinite(r) or nobs < 4 or abs(r) >= 1:
        return None
    z = np.arctanh(r)
    se = 1.0 / np.sqrt(nobs - 3)
    lo, hi = np.tanh(z - 1.96 * se), np.tanh(z + 1.96 * se)
    return dict(lo=float(lo), hi=float(hi))


def circular_null(x: np.ndarray, y: np.ndarray, reps: int = NULL_REPS):
    """Null: rotate y circularly by a random offset -> destroys cross-dependence,
    preserves each series' marginal + autocorrelation + sparsity."""
    n = len(x)
    xd = x - x.mean()
    nx = np.sqrt((xd * xd).sum())
    if nx == 0:
        return None
    offs = RNG.integers(1, n, size=reps)
    rs = np.empty(reps)
    for i, k in enumerate(offs):
        yr = np.roll(y, k)
        yd = yr - yr.mean()
        ny = np.sqrt((yd * yd).sum())
        rs[i] = (xd * yd).sum() / (nx * ny) if ny > 0 else 0.0
    return dict(mean=float(rs.mean()), sd=float(rs.std(ddof=1)),
               p975=float(np.percentile(np.abs(rs), 97.5)),
               p_ge_thresh=float(np.mean(np.abs(rs) >= Q15_THRESHOLD)))


def analyze_pool(members, name):
    daily = {}
    meta = {}
    for label, ea, sym, store, fn in members:
        p = store / fn
        daily[label] = load_daily(ea, sym, p)
        d = daily[label]
        meta[label] = dict(ea=ea, symbol=sym, file=str(p), sha256_16=sha16(p),
                           trades=None, active_days=len(d),
                           first=min(d).isoformat(), last=max(d).isoformat())
    pairs_out = []
    labels = [m[0] for m in members]
    for a, c in itertools.combinations(labels, 2):
        pv = pair_vectors(daily[a], daily[c])
        if pv is None:
            pairs_out.append(dict(pair=[a, c], overlap="none"))
            continue
        x, y = pv["x"], pv["y"]
        r = pearson(x, y)
        r_ca, m_ca = coactive_pearson(x, y)
        bx = opt_block_length_sb(x)
        by = opt_block_length_sb(y)
        bz = opt_block_length_sb(x * y)
        b = max(bx, by, bz)
        boot = boot_corr_ci(x, y, b)
        fis_n = fisher_ci(r, pv["n"])
        fis_m = fisher_ci(r, pv["coactive"])
        certifiable = (boot is not None) and (boot["abs_upper"] < Q15_THRESHOLD)
        tool_verdict = "insufficient_overlap(None)" if m_ca < 60 else f"r={r_ca:.3f}"
        pairs_out.append(dict(
            pair=[a, c], n_businessdays=pv["n"], coactive_days=pv["coactive"],
            active_a=pv["active_i"], active_c=pv["active_j"],
            weekend_folded=pv["weekend_folded"],
            window=[pv["start"].isoformat(), pv["end"].isoformat()],
            r_pearson_zeroskept=round(r, 4),
            r_coactive_subset=round(r_ca, 4) if np.isfinite(r_ca) else None,
            coactive_m=m_ca,
            block_len_x=round(bx, 2), block_len_y=round(by, 2), block_len_xy=round(bz, 2),
            block_len_used=round(b, 2),
            boot_mean=round(boot["mean"], 4) if boot else None,
            boot_ci95=[round(boot["lo"], 4), round(boot["hi"], 4)] if boot else None,
            boot_abs_upper=round(boot["abs_upper"], 4) if boot else None,
            boot_ci_width=round(boot["hi"] - boot["lo"], 4) if boot else None,
            fisher_ci95_fulln=[round(fis_n["lo"], 4), round(fis_n["hi"], 4)] if fis_n else None,
            fisher_ci95_coactive=[round(fis_m["lo"], 4), round(fis_m["hi"], 4)] if fis_m else None,
            certifiable_orthogonal=bool(certifiable),
            tool_min_overlap60_verdict=tool_verdict,
        ))
    # ---- matrix + shrinkage + ENB ----
    L = labels
    N = len(L)
    R = np.eye(N)
    Vboot = np.zeros((N, N))
    idxof = {lab: i for i, lab in enumerate(L)}
    for po in pairs_out:
        if "r_pearson_zeroskept" not in po:
            continue
        i, j = idxof[po["pair"][0]], idxof[po["pair"][1]]
        rv = po["r_pearson_zeroskept"]
        R[i, j] = R[j, i] = rv
        if po["boot_ci95"]:
            sd = po["boot_ci_width"] / (2 * 1.96)
            Vboot[i, j] = Vboot[j, i] = sd * sd
    evals = np.linalg.eigvalsh(R)
    fro2 = float((R * R).sum())
    enb_raw = (N * N) / fro2
    # bootstrap-reliability per-element shrinkage (portfolio-layer only)
    Rsh = R.copy()
    for i in range(N):
        for j in range(N):
            if i == j:
                continue
            r2 = R[i, j] ** 2
            w = r2 / (r2 + Vboot[i, j]) if (r2 + Vboot[i, j]) > 0 else 0.0
            Rsh[i, j] = R[i, j] * w
    # Ledoit-Wolf-style global intensity toward identity (off-diagonal)
    off = [(i, j) for i in range(N) for j in range(i + 1, N)]
    num = sum(Vboot[i, j] for i, j in off)
    den = sum(R[i, j] ** 2 for i, j in off)
    delta_lw = float(np.clip(num / den, 0.0, 1.0)) if den > 0 else 1.0
    # minimal ridge to restore PSD if needed
    min_eval = float(evals.min())
    delta_psd = 0.0
    if min_eval < 1e-8:
        lo_d, hi_d = 0.0, 1.0
        for _ in range(40):
            md = (lo_d + hi_d) / 2
            Rt = (1 - md) * R + md * np.eye(N)
            if np.linalg.eigvalsh(Rt).min() >= 1e-8:
                hi_d = md
            else:
                lo_d = md
        delta_psd = hi_d
    fro2_sh = float((Rsh * Rsh).sum())
    enb_sh = (N * N) / fro2_sh
    return dict(
        pool=name, members=meta, pairs=pairs_out,
        matrix_labels=L,
        matrix_raw=[[round(R[i, j], 4) for j in range(N)] for i in range(N)],
        min_eigenvalue=round(min_eval, 6),
        psd=bool(min_eval >= -1e-9),
        enb_raw=round(enb_raw, 3),
        enb_shrunk=round(enb_sh, 3),
        delta_lw_toward_identity=round(delta_lw, 4),
        delta_psd_ridge=round(delta_psd, 4),
        matrix_shrunk=[[round(Rsh[i, j], 4) for j in range(N)] for i in range(N)],
    )


def controls(audited_daily):
    out = {}
    # positive control: same EA (11165) on two symbols
    a, c = "11165/AUDCAD", "11165/EURUSD"
    pv = pair_vectors(audited_daily[a], audited_daily[c])
    x, y = pv["x"], pv["y"]
    r = pearson(x, y)
    b = max(opt_block_length_sb(x), opt_block_length_sb(y), opt_block_length_sb(x * y))
    boot = boot_corr_ci(x, y, b)
    nul = circular_null(x, y)
    out["positive_same_ea_11165"] = dict(
        pair=[a, c], r=round(r, 4), coactive=pv["coactive"], n=pv["n"],
        block_len=round(b, 2),
        boot_ci95=[round(boot["lo"], 4), round(boot["hi"], 4)],
        boot_abs_upper=round(boot["abs_upper"], 4),
        certifiable_orthogonal=bool(boot["abs_upper"] < Q15_THRESHOLD),
        null_abs_p975=round(nul["p975"], 4),
        null_frac_ge_0p5=round(nul["p_ge_thresh"], 4),
    )
    # positive control 2: a stream vs itself shifted by 1 business day (should be highly certifiable-FAIL)
    x2 = audited_daily["12969/USDJPY"]
    dd = x2
    pv2 = pair_vectors(dd, dd)  # identical -> r=1
    out["positive_identity_12969"] = dict(r=round(pearson(pv2["x"], pv2["y"]), 4))
    return out


def detection_power(base_daily, reps=200):
    """POSITIVE control / power curve. Build a synthetic near-duplicate sleeve that
    PERFECTLY co-moves with `base` on k shared active days (strongest possible
    co-movement for a sparse sleeve) and measure how often the standard REJECTS it
    (boot |hi| >= 0.5). The smallest k with reliable rejection is the empirical
    minimum-co-active-days floor k* below which the standard is blind and must abstain."""
    days = sorted(base_daily)
    start, end = min(days), max(days)
    cal = set(business_days(start, end))
    cal |= {d for d in days if d.weekday() >= 5}
    calendar = sorted(cal)
    di = {d: base_daily.get(d, 0.0) for d in calendar}
    x = np.array([di[d] for d in calendar])
    active_pos = np.array([i for i, d in enumerate(calendar) if x[i] != 0.0])
    b_x = max(opt_block_length_sb(x), 1.0)  # block length precomputed once
    out = []
    for k in (2, 3, 5, 8, 10, 12, 15, 20, 25, 30, 40, 50):
        if k > len(active_pos):
            break
        rejects = 0
        r_list, hi_list = [], []
        for _ in range(reps):
            chosen = RNG.choice(active_pos, size=k, replace=False)
            y = np.zeros_like(x)
            y[chosen] = x[chosen]  # exact co-move on the k shared days
            r = pearson(x, y)
            boot = boot_corr_ci(x, y, b_x, B=1500)
            if boot is None:
                continue
            r_list.append(r)
            hi_list.append(boot["abs_upper"])
            if boot["abs_upper"] >= Q15_THRESHOLD:
                rejects += 1
        out.append(dict(k_coactive=k, reps=len(r_list),
                        median_r=round(float(np.median(r_list)), 3),
                        median_boot_abs_upper=round(float(np.median(hi_list)), 3),
                        reject_rate=round(rejects / max(len(r_list), 1), 3)))
        print(f"    [power] k={k} r~{np.median(r_list):+.3f} "
              f"|hi|~{np.median(hi_list):.3f} rej={rejects/max(len(r_list),1):.2f}", flush=True)
    # k* = smallest k with reject_rate >= 0.95
    kstar = next((o["k_coactive"] for o in out if o["reject_rate"] >= 0.95), None)
    return dict(base="12969/USDJPY", curve=out, k_star_reject95=kstar)


def null_calibration(pool_daily, pairs, reps=2000):
    """NEGATIVE control across real pairs: circular-rotation null. Fraction of pairs
    for which the null 97.5th-pct |r| reaches 0.5 (false-positive rate must be ~0)."""
    fp = []
    for a, c in pairs:
        pv = pair_vectors(pool_daily[a], pool_daily[c])
        if pv is None:
            continue
        nul = circular_null(pv["x"], pv["y"], reps=reps)
        if nul:
            fp.append(dict(pair=[a, c], null_abs_p975=round(nul["p975"], 4),
                           null_frac_ge_0p5=round(nul["p_ge_thresh"], 4)))
    worst = max((f["null_abs_p975"] for f in fp), default=None)
    return dict(pairs=fp, worst_null_abs_p975=worst,
                any_false_positive=any(f["null_frac_ge_0p5"] > 0 for f in fp))


def main():
    ql = analyze_pool(QUALIFIED, "qualified_pool_5")
    ad = analyze_pool(AUDITED, "audited_16_with_stream_9")
    # controls need the audited daily dicts
    adaily = {label: load_daily(ea, sym, store / fn) for label, ea, sym, store, fn in AUDITED}
    ctrl = controls(adaily)
    power = detection_power(adaily["12969/USDJPY"])
    audited_labels = [m[0] for m in AUDITED]
    nullcal = null_calibration(adaily, list(itertools.combinations(audited_labels, 2)))
    result = dict(
        generated_at=dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        commission_model=describe_model(MODEL),
        q15_threshold=Q15_THRESHOLD, B_boot=B_BOOT, null_reps=NULL_REPS,
        seed=20260903,
        qualified_pool=ql, audited_pool=ad, controls=ctrl,
        detection_power=power, null_calibration=nullcal,
    )
    outp = Path(__file__).with_name("2026-09-03_sparse_d1_orthogonality_results.json")
    outp.write_text(json.dumps(result, indent=2), encoding="utf-8")
    # console summary
    for pool in (ql, ad):
        print(f"\n===== {pool['pool']} =====")
        print(f"ENB raw={pool['enb_raw']}  ENB shrunk={pool['enb_shrunk']}  "
              f"minEig={pool['min_eigenvalue']} PSD={pool['psd']}  "
              f"delta_LW={pool['delta_lw_toward_identity']} delta_psd={pool['delta_psd_ridge']}")
        for po in pool["pairs"]:
            if "r_pearson_zeroskept" not in po:
                print(f"  {po['pair']}: NO OVERLAP")
                continue
            print(f"  {po['pair'][0]:>14s} x {po['pair'][1]:<14s} "
                  f"co={po['coactive_days']:>3d} n={po['n_businessdays']:>4d} "
                  f"r={po['r_pearson_zeroskept']:+.3f} "
                  f"boot95=[{po['boot_ci95'][0]:+.2f},{po['boot_ci95'][1]:+.2f}] "
                  f"|hi|={po['boot_abs_upper']:.2f} b={po['block_len_used']:.1f} "
                  f"cert={'Y' if po['certifiable_orthogonal'] else 'n'} "
                  f"tool={po['tool_min_overlap60_verdict']}")
    print("\n--- controls ---")
    print(json.dumps(ctrl, indent=2))
    print("\n--- detection power (positive control, base 12969/USDJPY) ---")
    for o in power["curve"]:
        print(f"  k_coactive={o['k_coactive']:>3d} median_r={o['median_r']:+.3f} "
              f"median|hi|={o['median_boot_abs_upper']:.3f} reject_rate={o['reject_rate']:.2f}")
    print(f"  k* (reject>=0.95) = {power['k_star_reject95']}")
    print("\n--- null calibration (negative control, audited pairs) ---")
    print(f"  worst null |r|_97.5 = {nullcal['worst_null_abs_p975']}  "
          f"any_false_positive={nullcal['any_false_positive']}")
    print(f"\nwrote {outp}")


if __name__ == "__main__":
    main()
