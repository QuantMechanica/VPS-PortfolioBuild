import sys, random, statistics, collections
sys.path.insert(0, r'C:/QM/repo'); sys.path.insert(0, r'C:/QM/repo/tools/strategy_farm')
from tools.strategy_farm.portfolio import ftmo_phase1_mae as m

CURRENT = 9.0
START = 100_000.0; DAILY = 0.05*START; FLOOR = 0.90*START
HORIZON = 365; BLOCK = 5; RUNS = 20000

book = m.load_ftmo_book()
days, realized, open_mae, trade_opens, loaded, stale = m.build_daily(book)
if stale: print("stale", stale); raise SystemExit
base = [(realized.get(d,0.0), open_mae.get(d,0.0), trade_opens.get(d,0)) for d in days]

def bootstrap_path(pairs, rng):
    seq=[]; n=len(pairs)
    while len(seq)<HORIZON:
        s=rng.randrange(n)
        for o in range(BLOCK):
            seq.append(pairs[(s+o)%n])
            if len(seq)==HORIZON: break
    return seq

def evaluate(seq, target_pct):
    target = START*(1+target_pct/100.0)
    bal=START; trading=0
    for i,(rz,om,opens) in enumerate(seq,1):
        if opens>0: trading+=1
        low=bal+om
        if bal-low>=DAILY: return ('daily', i)
        if low<=FLOOR: return ('max', i)
        bal+=rz
        if bal>=target and trading>=4: return ('pass', i)
    return ('timeout', len(seq))

def sim_scale(scale, target_pct=10.0):
    f=scale/CURRENT; pairs=[(r*f,o*f,t) for (r,o,t) in base]
    rng=random.Random(11)
    outcomes=[]; passdays=[]
    for _ in range(RUNS):
        oc,day=evaluate(bootstrap_path(pairs,rng), target_pct)
        outcomes.append((oc,day))
        if oc=='pass': passdays.append(day)
    p=len(passdays)/RUNS
    med=statistics.median(passdays) if passdays else None
    p25=statistics.quantiles(passdays,n=4)[0] if len(passdays)>=4 else None
    return p, med, p25, passdays

def parallel_first_pass(passdays, p, K, portfolios=20000):
    """E[days to FIRST P1 pass] across K parallel challenges. Each challenge passes with
    prob p at a day ~ sampled from passdays; else it never passes (breach/timeout)."""
    if not passdays: return 0.0, None
    rng=random.Random(5); firsts=[]; any_pass=0
    for _ in range(portfolios):
        best=None
        for _ in range(K):
            if rng.random()<p:
                d=passdays[rng.randrange(len(passdays))]
                if best is None or d<best: best=d
        if best is not None: firsts.append(best); any_pass+=1
    return any_pass/portfolios, (statistics.median(firsts) if firsts else None)

print(f"12/12 streams, {len(days)} days. Phase-1 target +10%, no time limit (365d cap).\n")
print("=== SPEED per scale (single challenge) ===")
print(f"{'scale':>5} | {'P1 pass':>8} {'med days->+10%':>14} {'fast 25% days':>13}")
data={}
for sc in [7.0,6.0,5.0,4.0,3.0,2.5,2.0]:
    p,med,p25,pd = sim_scale(sc)
    data[sc]=(p,med,p25,pd)
    print(f"{sc:>5.1f} | {p*100:>7.1f}% {str(round(med) if med else '-'):>14} {str(round(p25) if p25 else '-'):>13}")

print("\n=== PARALLEL: expected days to FIRST funded (P1 pass) across K challenges ===")
print(f"{'scale':>5} | {'K=1':>18} {'K=5':>18} {'K=10':>18}   (P(>=1 pass), median days)")
for sc in [6.0,5.0,4.0,3.0,2.5,2.0]:
    p,med,p25,pd = data[sc]
    cells=[]
    for K in (1,5,10):
        ap,fd = parallel_first_pass(pd,p,K)
        cells.append(f"{ap*100:>3.0f}%/{str(round(fd) if fd else '-'):>4}d")
    print(f"{sc:>5.1f} | {cells[0]:>18} {cells[1]:>18} {cells[2]:>18}")
