"""Single-account sleeve scoring against OWNER's 60/30 KPI.

Imports the exact machinery in challenge_book_60d.py (no reimplementation of the
phase engine, gates, pool, IS/OOS split, or breach logic) and extends it with:
  1. a per-sleeve ranked table for a SINGLE account,
  2. Phase-1-in-60d isolated from full funded,
  3. dormancy classification and max inter-trade gap,
  4. sizing-invariant discriminating statistics per sleeve.

Everything honest: leverage/overlay chosen on IS only; all rates reported on OOS.
"""
import io
import os
import sys
import statistics
import contextlib
from collections import defaultdict
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
# Import the book machinery from this script's own directory so the reproducer
# is path-independent (it lives next to challenge_book_60d.py).
sys.path.insert(0, HERE)

# Importing runs the whole book optimisation (prints + heavy compute). Suppress
# its stdout so our own output is clean; we only want its loaded globals.
_buf = io.StringIO()
with contextlib.redirect_stdout(_buf):
    import challenge_book_60d as cb

ACCOUNT = cb.ACCOUNT
D1, D2 = cb.D1, cb.D2
P1_TARGET, P2_TARGET = cb.P1_TARGET, cb.P2_TARGET
all_days = cb.all_days
IS, OOS = cb.IS, cb.OOS
keys = cb.keys
CFGS = cb.CFGS
results = cb.results
sleeves = cb.sleeves
multi_pct = cb.multi_pct
DORMANCY = cb.DORMANCY_DAYS

OOS_list = list(OOS)


def rate(vals):
    return (sum(vals) / len(vals)) if vals else float("nan")


def classify_start(k, cfg, s):
    """Full 60/30 outcome for one start, reusing cb.phase exactly.

    Returns (p1_pass:bool, funded:bool, breach:bool, dormant:bool)."""
    o1, i1 = cb.phase(k, cfg, s, P1_TARGET, D1)
    p1_pass = (o1 == "pass")
    breach = (o1 == "breach")
    dormant = (o1 == "dormant")
    funded = False
    if p1_pass:
        if i1 + 1 < len(all_days):
            o2, i2 = cb.phase(k, cfg, i1 + 1, P2_TARGET, D2)
            funded = (o2 == "pass")
            breach = breach or (o2 == "breach")
            dormant = dormant or (o2 == "dormant")
    return p1_pass, funded, breach, dormant


def best_cfg_is(k):
    """Leverage/overlay chosen on IS by funded rate — identical selection rule to
    challenge_book_60d.py's per-sleeve config table (lines 299-316)."""
    best = None
    for cfg in CFGS:
        f = results[(k, cfg)][0]
        r_is = rate([f[s] for s in IS])
        if best is None or r_is > best[0]:
            best = (r_is, cfg)
    return best[1]


def max_gap_days(k):
    """Largest gap in calendar days between consecutive ACTIVE days (the model's
    dormancy notion: entry, close, and every held day count as active)."""
    ad = sorted(cb.active[k])
    if len(ad) < 2:
        return 0
    return max((ad[i + 1] - ad[i]).days for i in range(len(ad) - 1))


def stream_stats(k):
    """Sizing-invariant fundamentals at 1x from the raw Q08 stream.

    ev entries are (entry_date, close_date, net, mae) at native RISK_FIXED sizing;
    the account is $100k so pct = value / ACCOUNT * 100."""
    ev = sleeves[k]
    nets = [net for _, _, net, _ in ev]
    n = len(nets)
    closes = [c for _, c, _, _ in ev]
    span_years = max((max(closes) - min(closes)).days / 365.25, 1e-9)
    wins = [x for x in nets if x > 0]
    losses = [x for x in nets if x < 0]
    win_rate = len(wins) / n
    avg_win = (statistics.mean(wins) / ACCOUNT * 100) if wins else 0.0
    avg_loss = (statistics.mean(losses) / ACCOUNT * 100) if losses else 0.0
    expectancy = statistics.mean(nets) / ACCOUNT * 100
    total = sum(nets) / ACCOUNT * 100
    annual = total / span_years
    trades_yr = n / span_years

    # daily realized P&L at 1x, worst day, max drawdown on realized equity curve
    byday = defaultdict(float)
    for _, c, net, _ in ev:
        byday[c] += net
    daily = [byday[d] for d in sorted(byday)]
    worst_day = min(daily) / ACCOUNT * 100 if daily else 0.0  # negative %
    eq = 0.0
    peak = 0.0
    maxdd = 0.0
    for d in daily:
        eq += d
        peak = max(peak, eq)
        maxdd = max(maxdd, peak - eq)
    maxdd_pct = maxdd / ACCOUNT * 100  # positive %

    # leverage the FTMO caps historically permit (approximate, path-agnostic):
    #   daily cap 5% and total cap 10%, hard ceiling 5.0
    L_daily = 5.0 / abs(worst_day) if worst_day < 0 else 5.0
    L_total = 10.0 / maxdd_pct if maxdd_pct > 0 else 5.0
    L_cap = min(5.0, L_daily, L_total)

    # rolling 60-calendar-day raw return at 1x (median), the direct sprint drift,
    # AND the max peak-to-trough drawdown INSIDE each 60-day window (the path risk
    # that actually binds a sprint, not the 8-year max DD).
    from datetime import timedelta
    import bisect
    close_net = sorted((c, net) for _, c, net, _ in ev)
    cds = [c for c, _ in close_net]
    nts = [net for _, net in close_net]
    roll, wdd = [], []
    for i, c0 in enumerate(cds):
        hi = c0 + timedelta(days=60)
        k2 = bisect.bisect_right(cds, hi)
        window = nts[i:k2]
        roll.append(sum(window) / ACCOUNT * 100)
        e = pk = dd = 0.0
        for x in window:
            e += x
            pk = max(pk, e)
            dd = max(dd, pk - e)
        wdd.append(dd / ACCOUNT * 100)
    med60_1x = statistics.median(roll) if roll else 0.0
    sr = sorted(roll)
    p20_60_1x = sr[int(len(sr) * 0.20)] if sr else 0.0
    p10_60_1x = sr[int(len(sr) * 0.10)] if sr else 0.0
    wdd_med = statistics.median(wdd) if wdd else 0.0
    wdd_p90 = sorted(wdd)[int(len(wdd) * 0.9)] if wdd else 0.0

    # Leverage tension: leverage NEEDED to hit +10% at the median window vs the
    # leverage the -5% daily cap and -10% total (window p90 DD) permit.
    L_target = (10.0 / med60_1x) if med60_1x > 0 else 999.0
    L_daily = 5.0 / abs(worst_day) if worst_day < 0 else 5.0
    L_total_w = 10.0 / wdd_p90 if wdd_p90 > 0 else 5.0
    L_permit = min(5.0, L_daily, L_total_w)
    binding = ("drift" if L_target > L_permit + 1e-9 else "headroom")
    sprint_score = L_permit / L_target if L_target > 0 else 0.0

    return dict(n=n, span_years=span_years, trades_yr=trades_yr, win_rate=win_rate,
                avg_win=avg_win, avg_loss=avg_loss, expectancy=expectancy,
                total=total, annual=annual, worst_day=worst_day, maxdd=maxdd_pct,
                L_daily=L_daily, L_total=L_total, L_cap=L_cap,
                med60_1x=med60_1x, p20_60=p20_60_1x, p10_60=p10_60_1x,
                wdd_med=wdd_med, wdd_p90=wdd_p90,
                L_target=L_target, L_permit=L_permit, binding=binding,
                sprint_score=sprint_score,
                annual_at_cap=annual * L_cap, med60_at_cap=med60_1x * L_cap)


rows = []
for k in keys:
    cfg = best_cfg_is(k)
    lev, dstop, dr = cfg
    # OOS classification
    p1, fu, br, do = [], [], [], []
    for s in OOS_list:
        a, b, c, d = classify_start(k, cfg, s)
        p1.append(a); fu.append(b); br.append(c); do.append(d)
    st = stream_stats(k)
    gap = max_gap_days(k)
    rows.append(dict(
        k=k, lev=lev, dstop=dstop,
        p_p1=rate(p1), p_fund=rate(fu), breach=rate(br), dorm=rate(do),
        maxgap=gap, multi=multi_pct[k], **st))

rows.sort(key=lambda r: r["p_fund"], reverse=True)

print("=" * 118)
print("SINGLE-ACCOUNT RANKED TABLE  (leverage chosen IS; P and breach on OOS)")
print("=" * 118)
hdr = (f"{'sleeve':13}{'lev':>4}{'dstop':>6}{'P(P1<=60d)':>11}{'P(fund60/30)':>13}"
       f"{'breach':>8}{'dorm':>7}{'maxgap_d':>9}{'dq30':>6}{'multi%':>7}")
print(hdr)
print("-" * 118)
for r in rows:
    dq = "YES" if r["maxgap"] > DORMANCY else "no"
    ds = f"{r['dstop']*100:.1f}%" if r["dstop"] else "-"
    print(f"{r['k']:13}{r['lev']:>4.0f}{ds:>6}{r['p_p1']:>11.1%}{r['p_fund']:>13.1%}"
          f"{r['breach']:>8.0%}{r['dorm']:>7.0%}{r['maxgap']:>9}{dq:>6}{r['multi']:>6.0f}%")

print()
print("=" * 118)
print("DISCRIMINATING STATISTICS  (1x, sizing-invariant; L_cap = min(5, 5/|worstday|, 10/maxDD))")
print("=" * 118)
hdr2 = (f"{'sleeve':13}{'P(fund)':>8}{'tr/yr':>7}{'winrt':>7}{'avgW%':>7}{'avgL%':>7}"
        f"{'exp%':>7}{'ann%':>8}{'wDay%':>7}{'maxDD%':>8}{'Lcap':>6}{'ann@cap':>8}"
        f"{'med60_1x':>9}{'med60@cap':>10}")
print(hdr2)
print("-" * 118)
for r in rows:
    print(f"{r['k']:13}{r['p_fund']:>8.1%}{r['trades_yr']:>7.1f}{r['win_rate']:>7.0%}"
          f"{r['avg_win']:>7.2f}{r['avg_loss']:>7.2f}{r['expectancy']:>7.3f}"
          f"{r['annual']:>8.1f}{r['worst_day']:>7.2f}{r['maxdd']:>8.1f}{r['L_cap']:>6.2f}"
          f"{r['annual_at_cap']:>8.1f}{r['med60_1x']:>9.2f}{r['med60_at_cap']:>10.2f}")

# ---- group separation: good = P(fund) OOS >= 0.10, bad = ~0
print()
print("=" * 118)
print("GROUP SEPARATION  good = P(fund)>=10%   bad = P(fund)<3%")
print("=" * 118)
good = [r for r in rows if r["p_fund"] >= 0.10]
bad = [r for r in rows if r["p_fund"] < 0.03]
mid = [r for r in rows if 0.03 <= r["p_fund"] < 0.10]
print(f"good ({len(good)}): {', '.join(r['k'] for r in good)}")
print(f"mid  ({len(mid)}): {', '.join(r['k'] for r in mid)}")
print(f"bad  ({len(bad)}): {', '.join(r['k'] for r in bad)}")
print()


def summarize(name, grp):
    def med(f):
        vals = [f(r) for r in grp]
        return statistics.median(vals) if vals else float("nan")
    def rng(f):
        vals = sorted(f(r) for r in grp)
        return (vals[0], vals[-1]) if vals else (float("nan"), float("nan"))
    print(f"[{name}] n={len(grp)}")
    for label, f in [
        ("trades/yr", lambda r: r["trades_yr"]),
        ("win_rate", lambda r: r["win_rate"]),
        ("avg_win%", lambda r: r["avg_win"]),
        ("avg_loss%", lambda r: r["avg_loss"]),
        ("expectancy%/trade", lambda r: r["expectancy"]),
        ("annual% 1x", lambda r: r["annual"]),
        ("worst_day% 1x", lambda r: r["worst_day"]),
        ("maxDD% 1x", lambda r: r["maxdd"]),
        ("L_cap", lambda r: r["L_cap"]),
        ("annual%@cap", lambda r: r["annual_at_cap"]),
        ("med60_1x%", lambda r: r["med60_1x"]),
        ("med60@cap%", lambda r: r["med60_at_cap"]),
    ]:
        lo, hi = rng(f)
        print(f"   {label:20} median={med(f):8.3f}   range=[{lo:8.3f}, {hi:8.3f}]")


summarize("GOOD", good)
print()
summarize("BAD", bad)

# ---- which single stat best separates good from bad? rank-order test
print()
print("=" * 118)
print("SEPARATION POWER  (does the stat perfectly order good above bad?)")
print("=" * 118)
for label, f, direction in [
    ("trades/yr", lambda r: r["trades_yr"], "hi"),
    ("win_rate", lambda r: r["win_rate"], "hi"),
    ("avg_win%", lambda r: r["avg_win"], "hi"),
    ("expectancy%/trade", lambda r: r["expectancy"], "hi"),
    ("annual% 1x", lambda r: r["annual"], "hi"),
    ("maxDD% 1x", lambda r: r["maxdd"], "hi"),
    ("L_cap", lambda r: r["L_cap"], "hi"),
    ("annual%@cap", lambda r: r["annual_at_cap"], "hi"),
    ("med60_1x%", lambda r: r["med60_1x"], "hi"),
    ("med60@cap%", lambda r: r["med60_at_cap"], "hi"),
]:
    gv = [f(r) for r in good]
    bv = [f(r) for r in bad]
    lo_good = min(gv)
    hi_bad = max(bv)
    clean = lo_good > hi_bad
    # threshold midway
    thr = (lo_good + hi_bad) / 2
    print(f"{label:20} min(good)={lo_good:8.3f}  max(bad)={hi_bad:8.3f}  "
          f"clean_split={'YES thr~%.2f' % thr if clean else 'no (overlap)'}")


# ---- Spearman rank correlation of each stat with P(fund) across all 15 sleeves
def spearman(xs, ys):
    def ranks(v):
        order = sorted(range(len(v)), key=lambda i: v[i])
        rk = [0.0] * len(v)
        i = 0
        while i < len(v):
            j = i
            while j + 1 < len(v) and v[order[j + 1]] == v[order[i]]:
                j += 1
            avg = (i + j) / 2.0 + 1
            for m in range(i, j + 1):
                rk[order[m]] = avg
            i = j + 1
        return rk
    rx, ry = ranks(xs), ranks(ys)
    n = len(xs)
    mx = sum(rx) / n
    my = sum(ry) / n
    num = sum((rx[i] - mx) * (ry[i] - my) for i in range(n))
    dx = sum((rx[i] - mx) ** 2 for i in range(n)) ** 0.5
    dy = sum((ry[i] - my) ** 2 for i in range(n)) ** 0.5
    return num / (dx * dy) if dx and dy else float("nan")


print()
print("=" * 118)
print("SPEARMAN rank-correlation with P(fund) across all 15 sleeves")
print("=" * 118)
pf = [r["p_fund"] for r in rows]
for label, f in [
    ("trades/yr", lambda r: r["trades_yr"]),
    ("win_rate", lambda r: r["win_rate"]),
    ("avg_win%", lambda r: r["avg_win"]),
    ("expectancy%/trade", lambda r: r["expectancy"]),
    ("annual% 1x (drift)", lambda r: r["annual"]),
    ("med60_1x% (drift)", lambda r: r["med60_1x"]),
    ("maxDD% 1x (whole)", lambda r: r["maxdd"]),
    ("wdd_p90% (window)", lambda r: r["wdd_p90"]),
    ("L_permit", lambda r: r["L_permit"]),
    ("sprint_score", lambda r: r["sprint_score"]),
]:
    rho = spearman([f(r) for r in rows], pf)
    print(f"{label:22} rho={rho:+.3f}")

print()
print("=" * 118)
print("LEVERAGE-TENSION  L_target=lev to hit +10% at median 60d window;  "
      "L_permit=min(5, 5/|wDay|, 10/wDD_p90)")
print("=" * 118)
hdr3 = (f"{'sleeve':13}{'P(fund)':>8}{'med60_1x':>9}{'wDay%':>7}{'wDD_p90':>8}"
        f"{'L_target':>9}{'L_permit':>9}{'binding':>9}{'sprintSc':>9}")
print(hdr3)
print("-" * 118)
for r in rows:
    print(f"{r['k']:13}{r['p_fund']:>8.1%}{r['med60_1x']:>9.2f}{r['worst_day']:>7.2f}"
          f"{r['wdd_p90']:>8.2f}{r['L_target']:>9.2f}{r['L_permit']:>9.2f}"
          f"{r['binding']:>9}{r['sprint_score']:>9.2f}")

# ---- Requirement-derived FUND_SCORE and its reduced-form target.
# FUND_SCORE = L_permit / L_target = med60_1x * min(5, 5/|wDay|, 10/wDD_p90) / 10.
# FUND_SCORE >= 1.0  <=>  a leverage <=5x exists at which the MEDIAN 60-day window
# reaches +10% while the worst historical day stays inside -5% and the p90 60-day
# window drawdown inside -10%.  Algebra: that is exactly
#     med60_1x  >=  max( 2.0 , 2*|wDay_1x| , wDD_p90_1x ).
# One inequality, all four terms from the Q08 stream, no new backtest.
print()
print("=" * 118)
print("REQUIREMENT-DERIVED TARGET  med60_1x >= max(2.0, 2*|wDay_1x|, wDD_p90_1x)  "
      "<=>  FUND_SCORE >= 1.0")
print("=" * 118)
print("  LHS = median 60-day GAIN at 1x. RHS = the 60-day path risk it must out-run.")
print("  RHS term that binds tells the factory WHICH lever to pull.")
hdr4 = (f"{'sleeve':13}{'P(fund)':>8}{'LHS med60':>10}{'2|wDay|':>9}{'wDD_p90':>9}"
        f"{'5xfloor':>8}{'RHS':>7}{'FUND_SC':>8}{'binds':>9}")
print(hdr4)
print("-" * 118)
for r in rows:
    terms = {"5x_floor": 2.0, "daily(2|wDay|)": 2 * abs(r["worst_day"]),
             "windowDD": r["wdd_p90"]}
    rhs_label = max(terms, key=terms.get)
    rhs = terms[rhs_label]
    fund_sc = r["med60_1x"] / rhs if rhs > 0 else 0.0
    print(f"{r['k']:13}{r['p_fund']:>8.1%}{r['med60_1x']:>10.2f}{2*abs(r['worst_day']):>9.2f}"
          f"{r['wdd_p90']:>9.2f}{2.0:>8.2f}{rhs:>7.2f}{fund_sc:>8.2f}{rhs_label:>9}")
