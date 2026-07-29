"""challenge_single_account.py - ONE FTMO account, measured two ways.

OWNER decided 2026-07-27: ONE account at a time, no parallel accounts. Pass ONE
challenge first. That changes the optimisation problem and opens a question that
was asserted in prose but never measured.

challenge_book_60d.py answered the PARALLEL question: N INDEPENDENT accounts,
each carrying one sleeve, separate equity and caps, combined by OR. Its N=1 row
IS the single-sleeve / single-account answer (9936:USDJPY@3x, OOS 35.7%, median
34 calendar days, breach 49%) and this module reproduces it exactly. What was
never measured is the alternative a single account permits: SEVERAL sleeves
SHARING one account - shared equity, one -5% daily cap, one -10% static total
cap, combined P&L toward one +10% target. That is NOT an OR of independent
paths; the equity is coupled, so it must be simulated on one curve.

Earlier campaign notes claimed "diversification inside one book hurts a sprint
because averaging damps the upward excursions needed to reach a target far above
expected return." An adversarial review flagged that as unsupported prose. This
script measures it.

REUSE, NOT REWRITE. This module imports challenge_book_60d.py and takes its pool,
its gate + entry_time-coverage filter, its per-day pessimistic floating charge
(full adverse excursion on EVERY open day), its calendar deadlines, its 30-day
dormancy block (OWNER-confirmed; official scope unresolved - see
docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md), its four-trading-
day minimum, its end-of-day target check, and its 60% IS/OOS calendar split -
all unchanged. Single-sleeve numbers are cross-checked against that module's own
funded_flags. The only new code is the COUPLED-EQUITY phase engine below, and it
is verified to reproduce the imported engine bit-for-bit on every singleton.

RISK SPLIT CONVENTION - stated explicitly, as required.
  An account runs a set S of |S| sleeves under one total risk budget B, with B
  swept over {1,2,3,4,5} and capped at the OWNER-ratified 5.0
  (QM_Common.mqh:315 QM_FrameworkSetRiskCapPct; not weakened here). The PRIMARY
  convention is EQUAL SPLIT: every member runs at per-sleeve leverage B/|S|.
  Why B is a genuine, comparable budget: the model charges the pessimistic case
  where every member suffers its FULL adverse excursion on the SAME day, so on
  that worst day the account's combined charge is (B/|S|) * sum_k excursion_k =
  B * (mean per-sleeve excursion) - exactly what ONE sleeve run at leverage B
  would incur. So B bounds worst-case aggregate exposure at 5x whether the
  account holds one sleeve or five, and the two ends of the split are already
  both measured here:
      single sleeve at B          = fully CONCENTRATED split  (item 1)
      |S| sleeves at B/|S| each   = fully DIVERSIFIED split    (item 2)
  Every unequal tilt lies between those endpoints. We also run an explicit tilt
  sweep on the winning membership to confirm the interior only adds selection
  freedom, not pass probability.

METHOD (non-negotiable, inherited from the imported module):
  - IS/OOS split at 60% of the calendar. Risk (B), split, and membership are all
    chosen on the SELECTION window only; the scoring window reports, never
    decides. OOS is printed beside IS; if OOS materially exceeds IS that is
    evidence against a leak, and it is what this book shows.
  - Starts that run out of data are CENSORED and counted as failures, reported
    in their own column.
  - Effective sample size uses this repo's crude-but-defensible convention
    (challenge_firstpassage.py:388-393): ESS = starts / median resolution days,
    with a Wald 95% half-width 1.96*sqrt(p(1-p)/ESS). Overlapping starts share
    almost their whole path, so the raw count overstates independence.
"""
import contextlib
import io
import itertools
import statistics
import sys
from pathlib import Path

# --- Reuse the exact pool, data, constants and single-sleeve engine. Importing
#     runs that module's own report; suppress its stdout, we only want its state.
sys.path.insert(0, str(Path(__file__).resolve().parent))
with contextlib.redirect_stdout(io.StringIO()):
    import challenge_book_60d as base  # noqa: E402

all_days = base.all_days
day_index = base.day_index
ACCOUNT = base.ACCOUNT
CAP_D = -base.DAILY_CAP * ACCOUNT          # -5,000 on a 100k account
CAP_T = -base.TOTAL_CAP * ACCOUNT          # -10,000, static
P1_TGT = base.P1_TARGET * ACCOUNT          # +10,000
P2_TGT = base.P2_TARGET * ACCOUNT          # +5,000
D1, D2 = base.D1, base.D2
MIN_TRADING_DAYS = base.MIN_TRADING_DAYS
DORMANCY_DAYS = base.DORMANCY_DAYS
LEVERAGES = base.LEVERAGES
IS, OOS = list(base.IS), list(base.OOS)
cut = base.cut
keys = base.keys
multi_pct = base.multi_pct
N = len(all_days)

# integer calendar-day offsets so the hot loop uses int subtraction, not date
# arithmetic. dnum[di] = calendar days from the window start to all_days[di].
DNUM = [(d - all_days[0]).days for d in all_days]

BREACH = {"p1_breach", "p2_breach"}
DORMANT = {"p1_dormant", "p2_dormant"}
CENSORED = {"p1_censored", "p2_censored"}
EXPIRED = {"p1_expired", "p2_expired"}

# Cap membership enumeration so the coupled-equity search stays tractable; the
# candidate set is the sleeves that individually pass on the selection window,
# ranked by IS rate, top MULTI_POOL_MAX kept. Stated so the pool is auditable.
MULTI_POOL_MAX = 9


# --------------------------------------------------------------------------- #
# Coupled-equity engine. build() lays each membership's per-day adverse-excursion
# charge and closed nets on di-indexed lists, with a per-sleeve weight baked in.
# _phase() then applies a scalar sc, so equal split reuses ONE unscaled build
# across all budgets (sc = B/|S|) and unequal tilts bake the weights and use
# sc = 1. The arithmetic is identical to base.phase; the self-check proves it.
# --------------------------------------------------------------------------- #
def build(members, weight):
    act = [False] * N
    fl = [0.0] * N
    tr = [None] * N
    for k in members:
        for day in base.active[k]:
            di = day_index.get(day)
            if di is not None:
                act[di] = True
    for k in sorted(members):
        w = weight[k]
        for day, val in base.floating[k].items():
            fl[day_index[day]] += val * w
        for day, lst in base.closes[k].items():
            di = day_index[day]
            cell = tr[di]
            if cell is None:
                cell = []
                tr[di] = cell
            for net, _mae in lst:
                cell.append(net * w)
    return act, fl, tr


def _phase(act, fl, tr, sc, start_i, target, deadline):
    eq, traded = 0.0, 0
    start_dn = DNUM[start_i]
    last_dn = start_dn
    for di in range(start_i, N):
        dn = DNUM[di]
        if dn - start_dn > deadline:
            return "expired", di
        if dn - last_dn > DORMANCY_DAYS:
            return "dormant", di
        if act[di]:
            last_dn = dn
        f = fl[di] * sc
        if f and (eq + f <= CAP_T or f <= CAP_D):
            return "breach", di
        todays = tr[di]
        if todays is None:
            continue
        traded += 1
        realized = 0.0
        for net in todays:
            realized += net * sc
            if realized <= CAP_D or eq + realized <= CAP_T:
                return "breach", di
        eq += realized
        if eq >= target and traded >= MIN_TRADING_DAYS:
            return "pass", di
    return "censored", N - 1


def run(struct, sc):
    """Per start: funded?, calendar days to funded (or None), terminal reason.
    Two phases on ONE shared equity curve."""
    act, fl, tr = struct
    funded = [False] * N
    cal = [None] * N
    reason = [""] * N
    for s in range(N):
        o1, i1 = _phase(act, fl, tr, sc, s, P1_TGT, D1)
        if o1 != "pass":
            reason[s] = "p1_" + o1
            continue
        if i1 + 1 >= N:
            reason[s] = "p2_censored"
            continue
        o2, i2 = _phase(act, fl, tr, sc, i1 + 1, P2_TGT, D2)
        if o2 == "pass":
            funded[s] = True
            reason[s] = "funded"
            cal[s] = (all_days[i2] - all_days[s]).days
        else:
            reason[s] = "p2_" + o2
    return funded, cal, reason


def metrics(funded, cal, reason, idx):
    n = len(idx)
    rate = sum(funded[s] for s in idx) / n
    br = sum(reason[s] in BREACH for s in idx) / n
    do = sum(reason[s] in DORMANT for s in idx) / n
    ce = sum(reason[s] in CENSORED for s in idx) / n
    ex = sum(reason[s] in EXPIRED for s in idx) / n
    days = sorted(cal[s] for s in idx if funded[s])
    med = statistics.median(days) if days else None
    p90 = days[int(len(days) * 0.9)] if days else None
    span = statistics.median(days) if days else 60.0
    ess = max(1, int(n / max(1.0, span)))
    hw = 1.96 * (rate * (1 - rate) / ess) ** 0.5
    return dict(n=n, rate=rate, breach=br, dormant=do, censored=ce, expired=ex,
                med=med, p90=p90, ess=ess, hw=hw)


def rate_is(funded):
    return sum(funded[s] for s in IS) / len(IS)


def fmt_d(v):
    return f"{v:.0f}" if v is not None else "-"


# --------------------------------------------------------------------------- #
# Self-check: the coupled engine on a singleton must reproduce the imported
# single-sleeve engine on EVERY start. If it does not, the multi numbers are
# meaningless - so this aborts loudly rather than print a wrong table.
# --------------------------------------------------------------------------- #
print("Coupled-engine self-check vs challenge_book_60d.funded_flags "
      "(singleton == imported engine on every start):")
mismatch = 0
for k in keys:
    st = build([k], {k: 1.0})
    for L in LEVERAGES:
        f_new, _, _ = run(st, L)
        f_ref = base.results[(k, (L, None, None))][0]
        if f_new != f_ref:
            mismatch += 1
            print(f"  MISMATCH {k}@{L:.0f}x")
if mismatch:
    print(f"  !!! {mismatch} singleton configs disagree with the imported engine.")
    print("  !!! The coupled engine is NOT a faithful generalisation. Aborting.")
    sys.exit(1)
print(f"  OK - all {len(keys) * len(LEVERAGES)} singleton configs match bit-for-bit.")
print()


# --------------------------------------------------------------------------- #
# ITEM 1 - single sleeve, risk cap swept 1x..5x, chosen on IS, reported OOS.
# --------------------------------------------------------------------------- #
print("=" * 100)
print("ITEM 1 - ONE sleeve on the account, leverage swept 1x..5x (concentrated split).")
print("Leverage chosen on the SELECTION window; OOS only reports. breach/dorm/cens are")
print("OOS shares of starts. 'cens' = ran out of data (counted as failure).")
print("=" * 100)
hdr = (f"{'sleeve':16}{'multi%':>7}{'lev':>4}{'IS':>8}{'OOS':>8}"
       f"{'breach':>8}{'dorm':>7}{'cens':>7}{'exp':>7}{'med d':>7}{'p90 d':>7}{'ESS':>6}{'+-95%':>8}")
print(hdr)
print("-" * len(hdr))
single = {}          # key -> (best_lev, is_rate, funded, cal, reason)
for k in keys:
    st = build([k], {k: 1.0})
    best = None
    for L in LEVERAGES:
        f, c, r = run(st, L)
        r_is = rate_is(f)
        if best is None or r_is > best[0]:
            best = (r_is, L, f, c, r)
    r_is, L, f, c, r = best
    m = metrics(f, c, r, OOS)
    single[k] = (L, r_is, f, c, r)
    print(f"{k:16}{multi_pct[k]:>6.0f}%{L:>4.0f}{r_is:>8.1%}{m['rate']:>8.1%}"
          f"{m['breach']:>8.0%}{m['dormant']:>7.0%}{m['censored']:>7.0%}{m['expired']:>7.0%}"
          f"{fmt_d(m['med']):>7}{fmt_d(m['p90']):>7}{m['ess']:>6}{m['hw']:>8.1%}")

best_single_key = max(single, key=lambda k: single[k][1])
bL, bis, bf, bc, br_ = single[best_single_key]
bm = metrics(bf, bc, br_, OOS)
print("-" * len(hdr))
print(f"BEST SINGLE (IS-chosen): {best_single_key}@{bL:.0f}x  ->  "
      f"IS {bis:.1%}  OOS {bm['rate']:.1%}  breach {bm['breach']:.0%}  "
      f"med {fmt_d(bm['med'])}d  p90 {fmt_d(bm['p90'])}d")
if "9936:USDJPY" in single:
    sL, s_is, sf, sc_, sr = single["9936:USDJPY"]
    rep = metrics(sf, sc_, sr, OOS)
    ok = sL == 3 and abs(rep["rate"] - 0.357) < 0.006
    print(f"REPRODUCTION 9936:USDJPY: IS picks {sL:.0f}x, OOS {rep['rate']:.1%}, "
          f"breach {rep['breach']:.0%}, med {fmt_d(rep['med'])}d -> "
          f"{'MATCHES brief (3x, 35.7%, breach 49%, med 34d)' if ok else '*** DOES NOT MATCH brief ***'}")
else:
    print("REPRODUCTION: 9936:USDJPY not in pool - LOUD FINDING, cannot reproduce brief.")
print()


# --------------------------------------------------------------------------- #
# ITEM 2 - several sleeves sharing ONE account. Membership + total budget B
# chosen on IS under equal split (B/|S| per member). OOS only reports.
# --------------------------------------------------------------------------- #
pool = [k for k in keys if single[k][1] > 0]
pool.sort(key=lambda k: single[k][1], reverse=True)
pool = pool[:MULTI_POOL_MAX]
BUDGETS = LEVERAGES  # {1,2,3,4,5}, same 5.0 ceiling

print("=" * 100)
print("ITEM 2 - SEVERAL sleeves SHARING one account (equal split: each runs at B/|S|).")
print(f"candidate pool (IS single-sleeve rate > 0, top {MULTI_POOL_MAX}): " + ", ".join(pool))
print("Membership AND total budget B chosen on the SELECTION window; OOS only reports.")
print("=" * 100)
hdr2 = (f"{'N':>2}{'B':>4}{'each':>8}{'IS':>8}{'OOS':>8}"
        f"{'breach':>8}{'dorm':>7}{'cens':>7}{'exp':>7}{'med d':>7}{'p90 d':>7}{'ESS':>6}{'+-95%':>8}"
        f"   members")
print(hdr2)
print("-" * 122)

# N=1 reference row: the IS-best single sleeve.
print(f"{1:>2}{bL:>4.0f}{f'{bL:.2f}x':>8}{bis:>8.1%}{bm['rate']:>8.1%}"
      f"{bm['breach']:>8.0%}{bm['dormant']:>7.0%}{bm['censored']:>7.0%}{bm['expired']:>7.0%}"
      f"{fmt_d(bm['med']):>7}{fmt_d(bm['p90']):>7}{bm['ess']:>6}{bm['hw']:>8.1%}"
      f"   {best_single_key}@{bL:.0f}x")

best_multi = None  # (is_rate, N, B, members, funded, cal, reason)
for size in range(2, 6):
    if len(pool) < size:
        break
    win = None
    for members in itertools.combinations(pool, size):
        st = build(list(members), {k: 1.0 for k in members})
        for B in BUDGETS:
            f, c, r = run(st, B / size)
            r_is = rate_is(f)
            if win is None or r_is > win[0]:
                win = (r_is, B, members, f, c, r)
    r_is, B, members, f, c, r = win
    m = metrics(f, c, r, OOS)
    if best_multi is None or r_is > best_multi[0]:
        best_multi = (r_is, size, B, list(members), f, c, r)
    print(f"{size:>2}{B:>4.0f}{f'{B/size:.2f}x':>8}{r_is:>8.1%}{m['rate']:>8.1%}"
          f"{m['breach']:>8.0%}{m['dormant']:>7.0%}{m['censored']:>7.0%}{m['expired']:>7.0%}"
          f"{fmt_d(m['med']):>7}{fmt_d(m['p90']):>7}{m['ess']:>6}{m['hw']:>8.1%}"
          f"   {', '.join(members)}")
print()


# --------------------------------------------------------------------------- #
# Split-tilt robustness: does an UNEQUAL split of the winning membership beat
# equal? Small integer-weight grid, chosen on IS, reported OOS. If the IS-best
# tilt collapses toward one sleeve, that IS the single-sleeve answer re-derived.
# --------------------------------------------------------------------------- #
_, bn, bb, bmembers = best_multi[:4]
print("=" * 100)
print(f"SPLIT-TILT robustness on the winning membership, B fixed at {bb:.0f}.")
print(f"  members: {', '.join(bmembers)}")
print("Total budget B fixed; only the SPLIT across members varies. Integer weight")
print("shares normalised to sum to B. IS chooses the tilt; OOS reports.")
print("=" * 100)
hdrt = f"{'per-sleeve leverage':40}{'IS':>8}{'OOS':>8}{'breach':>8}{'med d':>7}{'p90 d':>7}"
print(hdrt)
print("-" * len(hdrt))
raw = list(itertools.product((1, 2, 3), repeat=len(bmembers)))
seen, vecs = set(), []
for w in raw:
    g = min(w)
    sig = tuple(x / g for x in w)
    if sig in seen:
        continue
    seen.add(sig)
    vecs.append(w)
tilt = []
for w in vecs:
    tot = sum(w)
    lev = {k: bb * wi / tot for k, wi in zip(bmembers, w)}
    st = build(bmembers, lev)
    f, c, r = run(st, 1.0)
    r_is = rate_is(f)
    m = metrics(f, c, r, OOS)
    label = ", ".join(f"{k.split(':')[0]} {v:.2f}x" for k, v in lev.items())
    tilt.append((r_is, m, label, w))
tilt.sort(key=lambda x: x[0], reverse=True)
is_best_sig = tilt[0][3]
for r_is, m, label, w in tilt[:8]:
    tag = ""
    if len(set(w)) == 1:
        tag = "  <- equal split"
    elif w == is_best_sig:
        tag = "  <- IS-best tilt"
    print(f"{label:40}{r_is:>8.1%}{m['rate']:>8.1%}{m['breach']:>8.0%}"
          f"{fmt_d(m['med']):>7}{fmt_d(m['p90']):>7}{tag}")
print()


# --------------------------------------------------------------------------- #
# VERDICT
# --------------------------------------------------------------------------- #
bmr = metrics(*best_multi[4:], OOS)
print("=" * 100)
print("VERDICT - single account: one sleeve at high risk vs several sleeves sharing it")
print("=" * 100)
print(f"  best SINGLE sleeve : {best_single_key}@{bL:.0f}x")
print(f"       IS {bis:.1%}   OOS {bm['rate']:.1%} +-{bm['hw']:.1%}   "
      f"breach {bm['breach']:.0%}   dorm {bm['dormant']:.0%}   cens {bm['censored']:.0%}   "
      f"med {fmt_d(bm['med'])}d  p90 {fmt_d(bm['p90'])}d")
print(f"  best SHARED book   : {bn} sleeves, B={bb:.0f} ({bb/bn:.2f}x each)")
print(f"       members: {', '.join(bmembers)}")
print(f"       IS {best_multi[0]:.1%}   OOS {bmr['rate']:.1%} +-{bmr['hw']:.1%}   "
      f"breach {bmr['breach']:.0%}   dorm {bmr['dormant']:.0%}   cens {bmr['censored']:.0%}   "
      f"med {fmt_d(bmr['med'])}d  p90 {fmt_d(bmr['p90'])}d")
delta = bmr["rate"] - bm["rate"]
who = "SHARING SEVERAL SLEEVES" if delta > 0.5 * (bm["hw"] + bmr["hw"]) else (
    "ONE SLEEVE AT HIGH RISK" if delta < -0.5 * (bm["hw"] + bmr["hw"]) else
    "a TIE within noise (favour the simpler single sleeve)")
print(f"  OOS difference (shared - single): {delta:+.1%} "
      f"(pooled +-95% ~ {0.5*(bm['hw']+bmr['hw'])*2:.1%})")
print(f"  ==> for a single account on the 60/30 KPI, out of sample: {who}.")
print()
print("Baseline: the same KPI at 1x with no leverage was 9.1% (challenge_book_60d.py).")
