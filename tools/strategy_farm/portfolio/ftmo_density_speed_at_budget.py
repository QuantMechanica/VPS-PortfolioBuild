"""At a MATCHED daily-breach budget, which book reaches +10% faster? Density cuts daily-breach,
so the denser book can be scaled UP to the same breach budget -> faster to target."""
import sys, statistics, collections, random
sys.path.insert(0, r'C:/QM/repo'); sys.path.insert(0, r'C:/QM/repo/tools/strategy_farm')
from tools.strategy_farm.portfolio import ftmo_phase1_mae as m

START=100_000.0; DAILY=0.05*START; FLOOR=0.90*START; BLOCK=5; RUNS=20000
base=m.load_ftmo_book(); med_rf=statistics.median(sorted(v['risk_fixed'] for v in base.values()))
NEW={(10118,'NDX.DWX'):{'risk_fixed':med_rf,'tf':'H1'},(10916,'GDAXI.DWX'):{'risk_fixed':med_rf,'tf':'H1'},
     (10546,'XAUUSD.DWX'):{'risk_fixed':med_rf,'tf':'M30'}}
book12=dict(base); book12m={k:v for k,v in base.items() if k!=(10163,'NDX.DWX')}
book15={**book12m,**NEW}

def pairs_for(book):
    days,realized,open_mae,trade_opens,loaded,stale=m.build_daily(book)
    cal=((days[-1]-days[0]).days+1)/len(days)
    return [(realized.get(d,0.0),open_mae.get(d,0.0),trade_opens.get(d,0)) for d in days], cal

def sim(pairs, norm):
    ann=sum(p[0] for p in pairs)/len(pairs)*365
    f=norm/ann; pr=[(r*f,o*f,t) for (r,o,t) in pairs]; rng=random.Random(3)
    passd=[]; out=collections.Counter()
    for _ in range(RUNS):
        seq=[]; n=len(pr)
        while len(seq)<365:
            s=rng.randrange(n)
            for o in range(BLOCK):
                seq.append(pr[(s+o)%n]);
                if len(seq)==365: break
        bal=START; trd=0; res='timeout'
        for i,(rz,om,op) in enumerate(seq,1):
            if op>0: trd+=1
            low=bal+om
            if bal-low>=DAILY: res='daily'; break
            if low<=FLOOR: res='max'; break
            bal+=rz
            if bal>=START*1.10 and trd>=4: res='pass'; passd.append(i); break
        out[res]+=1
    n=sum(out.values())
    return dict(p=len(passd)/RUNS, med=statistics.median(passd) if passd else None,
                daily=out['daily']/n, maxb=out['max']/n)

TARGET_DAILY=0.20  # match the current book's daily-breach budget
print(f"Scaling each book to daily-breach budget ~= {TARGET_DAILY*100:.0f}% (current 12-book level).")
print(f"{'book':<18} {'ann$@budget':>11} {'P(+10%)':>8} {'med cal days':>12} {'dailyBr':>8} {'maxBr':>6}")
for label,bk in [("current 12",book12),("12 minus 10163",book12m),("15 (+3 dense)",book15)]:
    pairs,cal=pairs_for(bk)
    # binary-search norm (annual $) so daily-breach ~ TARGET
    lo,hi=5000.0,200000.0
    for _ in range(22):
        mid=(lo+hi)/2; r=sim(pairs,mid)
        if r['daily']<TARGET_DAILY: lo=mid
        else: hi=mid
    r=sim(pairs,mid)
    mc=round(r['med']*cal) if r['med'] else None
    print(f"{label:<18} {mid:>11,.0f} {r['p']*100:>7.1f}% {str(mc):>12} {r['daily']*100:>7.0f}% {r['maxb']*100:>5.0f}%")
