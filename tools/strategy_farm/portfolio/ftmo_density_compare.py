"""Does adding 3 diverse high-density sleeves speed the book to +10% WITHOUT raising breach?
Compares at MATCHED annualized return (apples-to-apples): a denser, more diversified book
should hit the same return with smoother equity -> scale up -> reach +10% in fewer days.
Books: 12 (current) | 12-minus-10163 (drop net-negative) | 15 (minus-10163 + 3 dense)."""
import sys, statistics, collections, datetime as dt, random
sys.path.insert(0, r'C:/QM/repo'); sys.path.insert(0, r'C:/QM/repo/tools/strategy_farm')
from tools.strategy_farm.portfolio import ftmo_phase1_mae as m

START=100_000.0; DAILY=0.05*START; FLOOR=0.90*START; BLOCK=5; RUNS=30000; NORM=30000.0

base=m.load_ftmo_book()
med_rf=statistics.median(sorted(v['risk_fixed'] for v in base.values()))
NEW={(10118,'NDX.DWX'):{'risk_fixed':med_rf,'tf':'H1'},
     (10916,'GDAXI.DWX'):{'risk_fixed':med_rf,'tf':'H1'},
     (10546,'XAUUSD.DWX'):{'risk_fixed':med_rf,'tf':'M30'}}
book12=dict(base)
book12m={k:v for k,v in base.items() if k!=(10163,'NDX.DWX')}
book15={**book12m,**NEW}

def pairs_for(book):
    days,realized,open_mae,trade_opens,loaded,stale=m.build_daily(book)
    if stale: print("  [stale in book]:",stale)
    return [(realized.get(d,0.0),open_mae.get(d,0.0),trade_opens.get(d,0)) for d in days], days

def speed(pairs, target=10.0):
    ann=sum(p[0] for p in pairs)/len(pairs)*365 if pairs else 0
    if ann<=0: return 0.0,None,{}
    f=NORM/ann
    pr=[(r*f,o*f,t) for (r,o,t) in pairs]; rng=random.Random(3)
    passd=[]; out=collections.Counter()
    for _ in range(RUNS):
        seq=[]; n=len(pr)
        while len(seq)<365:
            s=rng.randrange(n)
            for o in range(BLOCK):
                seq.append(pr[(s+o)%n])
                if len(seq)==365: break
        bal=START; trd=0; tgt=START*1.10; res='timeout'
        for i,(rz,om,op) in enumerate(seq,1):
            if op>0: trd+=1
            low=bal+om
            if bal-low>=DAILY: res='daily'; break
            if low<=FLOOR: res='max'; break
            bal+=rz
            if bal>=tgt and trd>=4: res='pass'; passd.append(i); break
        out[res]+=1
    p=len(passd)/RUNS; med=statistics.median(passd) if passd else None
    return p,med,out

print(f"new-sleeve risk_fixed = book median {med_rf:.0f}\n")
print(f"{'book':<22} {'sleeves':>7} {'ann$(raw)':>10} {'P(+10%)':>8} {'med act':>8} {'med cal':>8} {'dailyBr':>8} {'maxBr':>6}")
for label,bk in [("current 12",book12),("12 minus 10163",book12m),("15 (+3 dense)",book15)]:
    pairs,days=pairs_for(bk)
    cal=((days[-1]-days[0]).days+1)/len(days)
    annraw=sum(p[0] for p in pairs)/len(pairs)*365
    p,med,out=speed(pairs)
    n=sum(out.values())
    mc=round(med*cal) if med else None
    print(f"{label:<22} {len(bk):>7} {annraw:>10,.0f} {p*100:>7.1f}% {str(med):>8} {str(mc):>8} "
          f"{out['daily']/n*100:>7.0f}% {out['max']/n*100:>5.0f}%")
