"""Full FTMO time-to-first-PAYOUT model with staged de-risking + fee-burn.

Chains the three real gates on the 12/12 fresh-MAE FTMO book:
  Phase 1 (+10%) -> Phase 2 (+5%) -> Funded (first payout after >=14 cal days & in profit)
Each phase resets to a fresh 100k (FTMO evaluates each on its own account size).
Per-stage scale lets us de-risk: P1 fast/high, P2 mid, funded defensive.
One Challenge fee buys P1+P2 (Verification is free); refunded on first payout.
Conservative worst-case-aligned MAE => LOWER bound on pass / UPPER bound on time.
"""
import sys, random, statistics, collections, datetime as dt
sys.path.insert(0, r'C:/QM/repo'); sys.path.insert(0, r'C:/QM/repo/tools/strategy_farm')
from tools.strategy_farm.portfolio import ftmo_phase1_mae as m

CURRENT = 9.0
START = 100_000.0; DAILY = 0.05*START; FLOOR = 0.90*START
BLOCK = 5
FEE_EUR = 540.0          # FTMO 100k Challenge fee (covers P1+P2), refunded on 1st payout
FUND_MIN_CALDAYS = 14    # FTMO first-payout floor (calendar days from first funded trade)
RUNS = 40000

book = m.load_ftmo_book()
days, realized, open_mae, trade_opens, loaded, stale = m.build_daily(book)
if stale:
    print("STALE (abort):", stale); raise SystemExit
base = [(realized.get(d,0.0), open_mae.get(d,0.0), trade_opens.get(d,0)) for d in days]

# active-day -> calendar-day factor (sim samples ACTIVE days; funded floor is CALENDAR)
cal_span = (days[-1] - days[0]).days + 1
n_active = len(days)
CAL_PER_ACTIVE = cal_span / n_active
FUND_MIN_ACTIVE = max(1, round(FUND_MIN_CALDAYS / CAL_PER_ACTIVE))
print(f"12/12 sleeves; {n_active} active days over {cal_span} cal days "
      f"(1 active ~= {CAL_PER_ACTIVE:.2f} cal); funded floor {FUND_MIN_CALDAYS}cal ~= {FUND_MIN_ACTIVE} active days\n")

def path(pairs, horizon, rng):
    seq=[]; n=len(pairs)
    while len(seq)<horizon:
        s=rng.randrange(n)
        for o in range(BLOCK):
            seq.append(pairs[(s+o)%n])
            if len(seq)==horizon: break
    return seq

def stage(scale, target_pct, rng, horizon=365, min_days=4):
    """Return (outcome, active_day). target_pct=None => funded payout stage."""
    f=scale/CURRENT
    pairs=[(r*f,o*f,t) for (r,o,t) in base]
    seq=path(pairs,horizon,rng)
    bal=START; trading=0
    target = START*(1+target_pct/100.0) if target_pct is not None else None
    for i,(rz,om,opens) in enumerate(seq,1):
        if opens>0: trading+=1
        low=bal+om
        if bal-low>=DAILY: return ('daily', i)
        if low<=FLOOR:     return ('max', i)
        bal+=rz
        if target is not None:
            if bal>=target and trading>=min_days: return ('pass', i)
        else:  # funded: first payout when past floor, enough trading, and in profit
            if i>=FUND_MIN_ACTIVE and trading>=min_days and bal>START: return ('payout', i)
    return ('timeout', len(seq))

def account_chain(p1s, p2s, fs, rng):
    oc,d1 = stage(p1s, 10.0, rng)
    if oc!='pass':   return dict(result=f'p1_{oc}', days=None, paid=False)
    oc,d2 = stage(p2s, 5.0, rng)
    if oc!='pass':   return dict(result=f'p2_{oc}', days=None, paid=False)
    oc,d3 = stage(fs, None, rng)
    if oc!='payout': return dict(result=f'fund_{oc}', days=None, paid=False)
    return dict(result='payout', days=d1+d2+d3, paid=True)

def eval_config(p1s, p2s, fs, label):
    rng=random.Random(101)
    res=[account_chain(p1s,p2s,fs,rng) for _ in range(RUNS)]
    paid=[r['days'] for r in res if r['paid']]
    p_paid=len(paid)/RUNS
    med=statistics.median(paid) if paid else None
    p25=statistics.quantiles(paid,n=4)[0] if len(paid)>=4 else None
    reasons=collections.Counter(r['result'] for r in res)
    return dict(label=label, p1s=p1s, p2s=p2s, fs=fs, p_paid=p_paid,
                med_active=med, p25_active=p25, paid=paid, reasons=reasons)

def to_cal(x): return None if x is None else round(x*CAL_PER_ACTIVE)

def parallel_first(paid_days, p_paid, K, campaigns=40000):
    """K parallel single-firm accounts -> P(>=1 reaches payout), median active-days to
    FIRST payout, E[# paid], E[net fee-burn] = FEE*(K - n_paid)."""
    if not paid_days: return dict(any=0.0, med=None, e_npaid=0.0, e_burn=FEE_EUR*K)
    rng=random.Random(7); firsts=[]; anyc=0; npaid_tot=0
    for _ in range(campaigns):
        best=None; npaid=0
        for _ in range(K):
            if rng.random()<p_paid:
                npaid+=1
                d=paid_days[rng.randrange(len(paid_days))]
                if best is None or d<best: best=d
        if best is not None: firsts.append(best); anyc+=1
        npaid_tot+=npaid
    e_npaid=npaid_tot/campaigns
    return dict(any=anyc/campaigns, med=(statistics.median(firsts) if firsts else None),
                e_npaid=e_npaid, e_burn=FEE_EUR*(K-e_npaid))

CONFIGS = [
    (6.0,4.0,2.0,"aggressive  P1=6 P2=4 fund=2"),
    (5.0,3.0,2.0,"balanced    P1=5 P2=3 fund=2"),
    (4.0,3.0,2.0,"steady      P1=4 P2=3 fund=2"),
    (5.0,5.0,5.0,"flat-5      P1=5 P2=5 fund=5"),
    (3.0,3.0,2.0,"safe        P1=3 P2=3 fund=2"),
]

print("=== SINGLE ACCOUNT: full chain P1->P2->funded->1st payout ===")
print(f"{'config':<30} {'P(payout)':>9} {'med days (active/cal)':>22} {'top-fail modes':>28}")
evals={}
for p1s,p2s,fs,lab in CONFIGS:
    e=eval_config(p1s,p2s,fs,lab); evals[lab]=e
    top=', '.join(f'{k}:{v*100//RUNS}%' for k,v in e['reasons'].most_common(3) if k!='payout')
    md=f"{e['med_active']}/{to_cal(e['med_active'])}" if e['med_active'] else "-"
    print(f"{lab:<30} {e['p_paid']*100:>8.1f}% {md:>22}  {top}")

print(f"\n=== PARALLEL (single-firm, K accounts) — fee EUR{FEE_EUR:.0f}/acct, refunded on payout ===")
print(f"{'config':<30} {'K':>2} {'P(>=1 paid)':>11} {'1st payout med (act/cal)':>25} {'E[#paid]':>8} {'E[net fee-burn]':>15}")
for lab in [c[3] for c in CONFIGS]:
    e=evals[lab]
    for K in (1,3,5):
        pr=parallel_first(e['paid'], e['p_paid'], K)
        md=f"{pr['med']}/{to_cal(pr['med'])}" if pr['med'] else "-"
        print(f"{lab:<30} {K:>2} {pr['any']*100:>10.1f}% {md:>25} {pr['e_npaid']:>8.2f} {'EUR'+format(pr['e_burn'],'.0f'):>15}")
