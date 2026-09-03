#!/usr/bin/env python3
"""ENB (effective number of bets) orthogonality estimator for sparse D1 sleeves.

SCRATCH / EVIDENCE script (board-advisor worktree). NOT a tools/ module, NOT wired
into any gate. Read-only: it only opens Q08/Q10 trade-stream .jsonl files for read.
It never writes under D:/QM or C:/QM/mt5 and never touches the farm DB.

Proposal context: docs/ops/evidence/2026-09-03_shadow_book_evaluation_39b77657_dossier.md
section 3c documents that tools/strategy_farm/portfolio/portfolio_correlation.py
hard-floors at min_overlap_days=60 and 0-fills sparse D1 sleeves, so pairwise |r|
collapses to ~0 mechanically and sparse pairs fail the overlap floor. This script
implements an AGGREGATE, weight-free orthogonality statistic that does not need any
pair to clear a 60-day overlap: the effective number of bets from the eigen-spectrum
of the Ledoit-Wolf-shrunk daily-return correlation matrix.

Method summary (full write-up in the accompanying .md):
  daily P&L per sleeve  ->  union-window align, 0-fill (0 = flat that day, economically real)
  ->  standardize columns  ->  sample correlation R
  ->  Ledoit-Wolf shrinkage (constant-correlation target [primary], identity target
      [sensitivity])  ->  eigenvalues  ->  ENB_PR = (sum L)^2 / sum L^2  and
      ENB_H = exp(-sum p ln p).  Aggregate "equivalent correlation" rho_eq inverts the
      equicorrelation ENB map, putting the whole book on the SAME 0-1 scale as the
      ratified pairwise |r| < 0.5 rule.

Estimator formulas cited to:
  Ledoit & Wolf (2004) "A well-conditioned estimator for large-dimensional covariance
    matrices", J. Multivariate Analysis 88(2):365-411  (identity target).
  Ledoit & Wolf (2003) "Improved estimation of the covariance matrix of stock returns
    with an application to portfolio selection", J. Empirical Finance 10(5):603-621
    (constant-correlation target).
  Meucci (2009) "Managing Diversification", Risk 22(5):74-79  (exp-entropy of the
    eigenvalue distribution as an effective number of bets).
"""
from __future__ import annotations

import json
import math
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------------------
# Stream stores (read-only)
# ---------------------------------------------------------------------------
C_STORE = Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\q08_trades")
D_STORE = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")

# Real qualified pool (book_build_guard --status --venue both => 5 pairs). All 5 have a
# stream in the C: Common\Files store that portfolio_correlation.py reads by default.
POOL = {
    "10706:GBPUSD": C_STORE / "10706_GBPUSD_DWX.jsonl",
    "11421:EURUSD": C_STORE / "11421_EURUSD_DWX.jsonl",
    "11422:USDCAD": C_STORE / "11422_USDCAD_DWX.jsonl",
    "13054:XTIUSD": C_STORE / "13054_XTIUSD_DWX.jsonl",
    "1537:XAGUSD":  C_STORE / "1537_XAGUSD_DWX.jsonl",
}

# The 9 audited cohort members that have a stream (dossier section 3b), D: store.
AUDITED9 = {
    "1556:XAUUSD":   D_STORE / "1556_XAUUSD_DWX.jsonl",
    "11132:SP500":   D_STORE / "11132_SP500_DWX.jsonl",
    "11165:AUDCAD":  D_STORE / "11165_AUDCAD_DWX.jsonl",
    "11165:EURUSD":  D_STORE / "11165_EURUSD_DWX.jsonl",
    "11708:EURUSD":  D_STORE / "11708_EURUSD_DWX.jsonl",
    "11910:NZDUSD":  D_STORE / "11910_NZDUSD_DWX.jsonl",
    "12710:XTIUSD":  D_STORE / "12710_XTIUSD_DWX.jsonl",
    "12778:basket":  D_STORE / "12778_AUDUSD_DWX.jsonl",
    "12969:USDJPY":  D_STORE / "12969_USDJPY_DWX.jsonl",
}


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------
def sha16(path: Path) -> str:
    import hashlib
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def load_trades(path: Path):
    """Return list of (exit_date, entry_date, net) for TRADE_CLOSED rows.

    net = the stream's own `net` field: worst-case-commission-inclusive per the
    FULL_POSITION_LIFECYCLE_ACTUAL_V1 money_basis. Centering removes any constant
    per-trade offset, so the commission convention is immaterial to correlation."""
    out = []
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("event") != "TRADE_CLOSED":
                continue
            t = row.get("time")
            if t is None or "net" not in row:
                continue
            exit_d = datetime.fromtimestamp(int(t), tz=timezone.utc).date()
            et = row.get("entry_time")
            entry_d = datetime.fromtimestamp(int(et), tz=timezone.utc).date() if et is not None else exit_d
            out.append((exit_d, entry_d, float(row["net"])))
    return out


def daily_series(trades):
    d = defaultdict(float)
    for exit_d, _entry_d, net in trades:
        d[exit_d] += net
    return dict(d)


def monthly_series(trades):
    d = defaultdict(float)
    for exit_d, _entry_d, net in trades:
        d[(exit_d.year, exit_d.month)] += net
    return dict(d)


def entry_days_per_year(trades):
    by_year = defaultdict(set)
    for _exit_d, entry_d, _net in trades:
        by_year[entry_d.year].add(entry_d)
    return {y: len(s) for y, s in sorted(by_year.items())}


def build_matrix(series_by_key):
    """Union-align sparse per-key {bucket: pnl} dicts -> (keys, buckets, X[n_buckets,p])."""
    keys = list(series_by_key.keys())
    buckets = sorted({b for s in series_by_key.values() for b in s})
    idx = {b: i for i, b in enumerate(buckets)}
    X = np.zeros((len(buckets), len(keys)), dtype=float)
    for j, k in enumerate(keys):
        for b, v in series_by_key[k].items():
            X[idx[b], j] = v
    return keys, buckets, X


# ---------------------------------------------------------------------------
# Correlation + Ledoit-Wolf shrinkage
# ---------------------------------------------------------------------------
def standardize(X):
    """Column-standardize to zero mean / unit population std. Returns (Z, keep_mask)."""
    mu = X.mean(axis=0)
    sd = X.std(axis=0, ddof=0)
    keep = sd > 0
    Z = (X[:, keep] - mu[keep]) / sd[keep]
    return Z, keep


def sample_corr(Z):
    n = Z.shape[0]
    return (Z.T @ Z) / n  # unit diagonal since Z is population-standardized


def lw_identity(Z):
    """Ledoit-Wolf (2004) shrinkage of the correlation matrix toward the identity.

    Applied to standardized returns Z (n x p) so the sample covariance S == sample
    correlation R and the target mu*I == I (mu = trace(R)/p = 1).
    Returns (R_shrunk, delta)."""
    n, p = Z.shape
    S = (Z.T @ Z) / n
    mu = np.trace(S) / p
    I = np.eye(p)
    d2 = np.sum((S - mu * I) ** 2)                      # ||S - muI||_F^2  (/p cancels in delta)
    norms4 = np.sum(Z * Z, axis=1) ** 2                 # ||y_k||^4 per observation
    b2bar = (np.sum(norms4) - n * np.sum(S * S)) / (n * n)
    b2 = min(b2bar, d2)
    delta = 0.0 if d2 <= 0 else b2 / d2
    R = delta * mu * I + (1.0 - delta) * S
    return R, float(delta)


def lw_constant_correlation(Z):
    """Ledoit-Wolf (2003) shrinkage toward the constant-correlation target.

    Skeptical target for THIS problem: it pulls toward the average-pairwise-correlation
    (equicorrelation) structure rather than toward independence, so a data-starved set
    cannot masquerade as orthogonal via shrinkage. Applied to standardized returns Z, the
    target F has 1 on the diagonal and r_bar (mean sample correlation) off-diagonal.
    Returns (R_shrunk, delta, r_bar). Formula follows Ledoit-Wolf (2003) sec. 2-3."""
    n, p = Z.shape
    S = (Z.T @ Z) / n
    s = np.sqrt(np.clip(np.diag(S), 1e-300, None))
    Rmat = S / np.outer(s, s)
    off = ~np.eye(p, dtype=bool)
    r_bar = Rmat[off].mean() if p > 1 else 0.0
    F = r_bar * np.outer(s, s)
    np.fill_diagonal(F, np.diag(S))

    # pi_hat: sum over i,j of AsyVar(sqrt(n) S_ij) estimate
    Zc = Z  # already demeaned
    Y2 = Zc * Zc
    pi_mat = (Y2.T @ Y2) / n - S * S
    pi_hat = float(pi_mat.sum())

    # rho_hat: diagonal sum + off-diagonal cross terms (constant-corr target)
    rho_diag = float(np.trace(pi_mat))
    # theta_ii_ij = (1/n) sum_k (Z_ki^2 - S_ii)(Z_ki Z_kj - S_ij)
    term1 = (Zc ** 3).T @ Zc / n            # (i,j): E[Z_i^3 Z_j]
    theta_ii = term1 - np.diag(S)[:, None] * S     # theta_ii_ij matrix, row i col j
    theta_jj = term1.T - np.diag(S)[None, :] * S   # theta_jj_ij
    ratio_ji = np.outer(1.0 / s, s)               # sqrt(S_jj/S_ii) with s=sqrt(diag)
    ratio_ij = np.outer(s, 1.0 / s)
    cross = 0.5 * r_bar * (ratio_ji * theta_ii + ratio_ij * theta_jj)
    np.fill_diagonal(cross, 0.0)
    rho_hat = rho_diag + float(cross[off].sum())

    gamma_hat = float(np.sum((F - S) ** 2))
    kappa = (pi_hat - rho_hat) / gamma_hat if gamma_hat > 0 else 0.0
    delta = max(0.0, min(1.0, kappa / n))
    R = delta * F + (1.0 - delta) * S
    return R, float(delta), float(r_bar)


# ---------------------------------------------------------------------------
# ENB from the eigen-spectrum
# ---------------------------------------------------------------------------
def eigenvalues(M):
    w = np.linalg.eigvalsh((M + M.T) / 2.0)
    return np.clip(w, 0.0, None)


def enb_pr(w):
    s = w.sum()
    s2 = np.sum(w * w)
    return float(s * s / s2) if s2 > 0 else float("nan")


def enb_h(w):
    s = w.sum()
    if s <= 0:
        return float("nan")
    p = w[w > 0] / s
    return float(math.exp(-np.sum(p * np.log(p))))


def enb_pr_equicorr(rho, N):
    """ENB_PR of an N x N equicorrelation matrix with off-diagonal rho."""
    l1 = 1.0 + (N - 1) * rho
    l2 = 1.0 - rho
    s2 = l1 * l1 + (N - 1) * l2 * l2
    return (N * N) / s2


def rho_equivalent(enb, N):
    """Invert enb_pr_equicorr: the constant pairwise correlation an N-sleeve book would
    need to have this ENB_PR. Bisection on rho in [0, 1)."""
    if N < 2:
        return float("nan")
    lo, hi = 0.0, 0.999999
    # enb decreasing in rho
    if enb >= enb_pr_equicorr(lo, N):
        return 0.0
    if enb <= enb_pr_equicorr(hi, N):
        return hi
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if enb_pr_equicorr(mid, N) > enb:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def coactivity_fraction(X):
    """phi = (# buckets with >=2 active sleeves) / (# buckets with >=1 active sleeve)."""
    active = (X != 0.0).sum(axis=1)
    denom = int((active >= 1).sum())
    numer = int((active >= 2).sum())
    return (numer / denom) if denom else float("nan"), numer, denom


def pairwise_overlap_stats(X):
    """Min/median/max count of buckets on which BOTH sleeves are active (the quantity
    portfolio_correlation.py floors at 60). Reports how far the pool is from that floor."""
    p = X.shape[1]
    act = (X != 0.0)
    ov = []
    for i in range(p):
        for j in range(i + 1, p):
            ov.append(int((act[:, i] & act[:, j]).sum()))
    ov = np.array(ov) if ov else np.array([0])
    return int(ov.min()), float(np.median(ov)), int(ov.max()), int((ov >= 60).sum()), len(ov)


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def analyze(name, filemap, freq="daily", verbose=True):
    trades_by_key = {k: load_trades(p) for k, p in filemap.items()}
    if freq == "daily":
        series = {k: daily_series(t) for k, t in trades_by_key.items()}
    else:
        series = {k: monthly_series(t) for k, t in trades_by_key.items()}
    keys, buckets, X = build_matrix(series)
    Z, keep = standardize(X)
    kept_keys = [k for k, m in zip(keys, keep) if m]
    N = Z.shape[1]
    n = Z.shape[0]

    R = sample_corr(Z)
    R_id, d_id = lw_identity(Z)
    R_cc, d_cc, r_bar = lw_constant_correlation(Z)

    res = {}
    for label, M in (("raw", R), ("LW_identity", R_id), ("LW_constcorr", R_cc)):
        w = eigenvalues(M)
        res[label] = {
            "ENB_PR": enb_pr(w),
            "ENB_H": enb_h(w),
            "rho_eq": rho_equivalent(enb_pr(w), N),
            "eig": np.round(np.sort(w)[::-1], 4).tolist(),
        }
    phi, co2, co1 = coactivity_fraction(X)
    ov_min, ov_med, ov_max, ov_ge60, ov_npairs = pairwise_overlap_stats(X)
    floor = enb_pr_equicorr(0.5, N)

    if verbose:
        print(f"\n================ {name}  [{freq}] ================")
        print(f" sleeves N (nonzero-var) = {N}   buckets n = {n}   union = {buckets[0]}..{buckets[-1]}")
        print(f" co-activity phi = {phi:.3f}  ({co2} multi-active / {co1} active buckets)")
        print(f" pairwise co-active overlap: min={ov_min} median={ov_med:.0f} max={ov_max}  "
              f"pairs>=60d: {ov_ge60}/{ov_npairs}  (portfolio_correlation.py floor=60)")
        print(f" mean sample |r_bar| off-diag = {r_bar:+.4f}")
        print(f" LW shrink delta: identity={d_id:.3f}  const-corr={d_cc:.3f}")
        print(f" derived floor ENB_PR(rho=0.5,N={N}) = {floor:.3f}   "
              f"(book must exceed this; rho_eq must be < 0.5)")
        for label in ("raw", "LW_identity", "LW_constcorr"):
            r = res[label]
            print(f"   {label:13s}: ENB_PR={r['ENB_PR']:.3f}  ENB_H={r['ENB_H']:.3f}  "
                  f"rho_eq={r['rho_eq']:.3f}  eig(top5)={r['eig'][:5]}")
    return {"keys": kept_keys, "N": N, "n": n, "buckets": (str(buckets[0]), str(buckets[-1])),
            "phi": phi, "co2": co2, "co1": co1, "r_bar": r_bar,
            "delta_id": d_id, "delta_cc": d_cc, "floor": floor, "res": res, "X": X, "series": series,
            "trades_by_key": trades_by_key}


def split_window_enb(name, filemap, freq="monthly"):
    """R3 refutation: ENB stability across first/second half of the union window (raw
    spectrum, on the certifiable frequency). A PASS that is a window artifact would show
    large H1-vs-H2 drift in rho_eq."""
    trades_by_key = {k: load_trades(p) for k, p in filemap.items()}
    sfun = monthly_series if freq == "monthly" else daily_series
    series = {k: sfun(t) for k, t in trades_by_key.items()}
    keys, buckets, X = build_matrix(series)
    half = len(buckets) // 2
    out = {}
    for tag, sl in (("H1", slice(0, half)), ("H2", slice(half, None))):
        Xh = X[sl]
        Zh, keep = standardize(Xh)
        if Zh.shape[1] < 2 or Zh.shape[0] < 3:
            out[tag] = None
            continue
        w = eigenvalues(sample_corr(Zh))
        out[tag] = {"N": int(Zh.shape[1]), "n": int(Zh.shape[0]),
                    "ENB_PR": enb_pr(w), "rho_eq": rho_equivalent(enb_pr(w), Zh.shape[1])}
    print(f"\n---- R3 split-window ({freq}, raw) : {name} ----")
    for tag in ("H1", "H2"):
        o = out[tag]
        if o is None:
            print(f"   {tag}: insufficient")
        else:
            print(f"   {tag}: N={o['N']} n={o['n']} ENB_PR={o['ENB_PR']:.3f} rho_eq={o['rho_eq']:.3f}")
    return out


def refutation_duplicate(name, filemap, dup_key, freq="monthly"):
    """R1: inject an exact duplicate of one sleeve; a working standard drops ENB by ~1.

    Reports RAW spectrum (the primary object) and the LW-const-corr spectrum. The
    contrast is the point: when delta->1 (data-starved), the shrunk ENB does NOT drop
    -> the redundancy is invisible -> that regime must be ruled INSUFFICIENT_EVIDENCE,
    not PASS. The raw ENB, computed on the certifiable frequency, must fall ~1."""
    trades_by_key = {k: load_trades(p) for k, p in filemap.items()}
    sfun = monthly_series if freq == "monthly" else daily_series
    series = {k: sfun(t) for k, t in trades_by_key.items()}
    keys, buckets, X = build_matrix(series)
    Z, keep = standardize(X)
    N0 = Z.shape[1]
    raw0 = enb_pr(eigenvalues(sample_corr(Z)))
    cc0 = enb_pr(eigenvalues(lw_constant_correlation(Z)[0]))

    j = keys.index(dup_key)
    Xd = np.hstack([X, X[:, [j]]])
    Zd, _ = standardize(Xd)
    rawd = enb_pr(eigenvalues(sample_corr(Zd)))
    ccd = enb_pr(eigenvalues(lw_constant_correlation(Zd)[0]))
    _, dcc_d, _ = lw_constant_correlation(Zd)
    # Analytic perfect-duplicate reference: adding an exact copy to K~indep sleeves gives
    # eigenvalues {2, 1x(K-1), 0} => ENB_PR = (K+1)^2/(K+3). For an orthogonal base of
    # size N0, expected raw ENB_PR after one perfect dup:
    exp_dup = (N0 + 1) ** 2 / (N0 + 3)
    print(f"\n---- R1 duplicate-insensitivity : {name} (dup {dup_key}) [{freq}] ----")
    print(f"   base   N={N0:2d}  raw ENB_PR={raw0:.3f}   const-corr ENB_PR={cc0:.3f}")
    print(f"   +dup   N={Zd.shape[1]:2d}  raw ENB_PR={rawd:.3f}   const-corr ENB_PR={ccd:.3f}   "
          f"(delta_cc={dcc_d:.3f})")
    print(f"   raw delta_ENB={rawd-raw0:+.3f}  (perfect-dup target for orthogonal N={N0}: "
          f"ENB_PR->{exp_dup:.3f}); const-corr delta_ENB={ccd-cc0:+.3f}")
    print(f"   PASS-of-test: raw must NOT rise (redundancy detected); const-corr rises when "
          f"delta_cc>0 -> over-shrinkage hides duplicates -> raw spectrum is primary.")
    return raw0, rawd


def self_test():
    """Known-answer sanity check: 4 independent + 2 near-identical Gaussian sleeves,
    fully co-active (n=2000). Raw ENB_PR should be ~5 (the pair counts as ~1 bet), and
    the duplicate drop ~-1. Confirms the estimator is sensitive when data is adequate."""
    rng = np.random.default_rng(42)
    n = 2000
    base = rng.normal(size=(n, 5))
    twin = base[:, 4] + 0.15 * rng.normal(size=n)   # ~0.99 corr with col 4
    X = np.column_stack([base, twin])               # 6 cols, cols 4&5 near-identical
    Z, _ = standardize(X)
    R = sample_corr(Z)
    off = ~np.eye(6, dtype=bool)
    _, dcc, rbar = lw_constant_correlation(Z)
    w = eigenvalues(R)
    print("\n---- SELF-TEST (known answer): 4 indep + 1 near-dup pair, n=2000 ----")
    print(f"   corr(col4,col5) = {R[4,5]:.3f}   mean|off-diag| = {np.abs(R[off]).mean():.3f}")
    print(f"   raw ENB_PR = {enb_pr(w):.3f}  (perfect-dup target {(5+1)**2/(5+3):.3f}: the "
          f"collapsed pair counts as ~1 bet, so 6 sleeves read as 4.5 not 5)")
    print(f"   raw ENB_H  = {enb_h(w):.3f}   rho_eq = {rho_equivalent(enb_pr(w),6):.3f}")
    print(f"   LW const-corr delta = {dcc:.3f}  r_bar = {rbar:.3f}  "
          f"(low delta => data-rich, shrinkage light)")


def refutation_disjoint():
    """R2: temporally disjoint synthetic sleeves. phi ~ 0 => the daily correlation is
    estimated from ~no joint observations; raw/identity ENB inflates toward N (evidence
    -free 'orthogonality'). Demonstrates why the phi guard is mandatory."""
    rng = np.random.default_rng(20260903)
    N, per = 6, 40
    days = []
    cols = []
    for j in range(N):
        # each sleeve trades on its own disjoint set of days
        base = j  # offset so sleeves never share a day
        dd = base + N * np.arange(per)
        v = rng.normal(size=per)
        cols.append((dd, v))
        days.extend(dd.tolist())
    alld = sorted(set(days))
    idx = {d: i for i, d in enumerate(alld)}
    X = np.zeros((len(alld), N))
    for j, (dd, v) in enumerate(cols):
        for d, val in zip(dd, v):
            X[idx[d], j] = val
    Z, _ = standardize(X)
    phi, co2, co1 = coactivity_fraction(X)
    w_raw = eigenvalues(sample_corr(Z))
    w_id = eigenvalues(lw_identity(Z)[0])
    w_cc, dcc = (lambda t: (eigenvalues(t[0]), t[1]))(lw_constant_correlation(Z))
    print("\n---- R2 sparsity-inflation (synthetic, fully disjoint) ----")
    print(f"   N={N}  n={len(alld)}  phi={phi:.3f} ({co2} multi-active / {co1} active)")
    print(f"   raw ENB_PR         = {enb_pr(w_raw):.3f}  (-> ~N: evidence-free 'orthogonality')")
    print(f"   LW_identity ENB_PR = {enb_pr(w_id):.3f}  (identity shrink pushes further to N)")
    print(f"   LW_constcorr ENB_PR= {enb_pr(w_cc):.3f}  delta_cc={dcc:.3f}")
    print("   VERDICT: phi ~ 0 => INSUFFICIENT_EVIDENCE. ENB must NOT be read as PASS here.")


def report_min_data(name, info):
    print(f"\n---- minimum-data profile : {name} (daily) ----")
    for k in info["keys"]:
        tr = info["trades_by_key"][k]
        edy = entry_days_per_year(tr)
        yrs = [y for y in edy if edy[y] >= 1]
        full_years = [y for y in yrs if y not in (min(edy), max(edy))]  # crude interior years
        min_edy = min((edy[y] for y in edy), default=0)
        below10 = sorted(y for y, c in edy.items() if c < 10)
        print(f"   {k:16s} trades={len(tr):4d}  entry-days/yr min={min_edy:3d}  "
              f"years<10={below10}")


def main():
    print("SHA16 of loaded streams")
    for grp, fm in (("POOL", POOL), ("AUDITED9", AUDITED9)):
        for k, p in fm.items():
            print(f"   {grp:9s} {k:16s} {p.name:52s} sha16={sha16(p)}")

    pool = analyze("QUALIFIED POOL (5, C: store)", POOL, "daily")
    analyze("QUALIFIED POOL (5, C: store)", POOL, "monthly")
    aud = analyze("AUDITED-9 (D: store)", AUDITED9, "daily")
    analyze("AUDITED-9 (D: store)", AUDITED9, "monthly")

    report_min_data("QUALIFIED POOL", pool)
    report_min_data("AUDITED-9", aud)

    self_test()

    split_window_enb("QUALIFIED POOL", POOL, "monthly")
    split_window_enb("AUDITED-9", AUDITED9, "monthly")

    refutation_duplicate("QUALIFIED POOL", POOL, "10706:GBPUSD", "monthly")
    refutation_duplicate("AUDITED-9", AUDITED9, "11165:EURUSD", "monthly")
    refutation_duplicate("QUALIFIED POOL", POOL, "10706:GBPUSD", "daily")
    refutation_disjoint()


if __name__ == "__main__":
    main()
