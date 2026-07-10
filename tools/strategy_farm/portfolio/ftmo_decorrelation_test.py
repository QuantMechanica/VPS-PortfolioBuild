"""B: do FX decorrelators cut the core book's max-breach tail?
Core = density-improved 14-sleeve book (12 - 10163 + 10118/10916/10546).
For each FX candidate: realized-daily-PnL correlation vs core, then augmented-book speed/breach
sim at MATCHED daily-breach budget. Lower corr + lower max-breach = the tail-cutting win."""
import sys, statistics, collections, random, math
sys.path.insert(0, r'C:/QM/repo'); sys.path.insert(0, r'C:/QM/repo/tools/strategy_farm')
from tools.strategy_farm.portfolio import ftmo_phase1_mae as m

START=100_000.0; DAILY=0.05*START; FLOOR=0.90*START; BLOCK=5; RUNS=20000
base=m.load_ftmo_book(); med_rf=statistics.median(sorted(v['risk_fixed'] for v in base.values()))
DENSE={(10118,'NDX.DWX'):{'risk_fixed':med_rf,'tf':'H1'},(10916,'GDAXI.DWX'):{'risk_fixed':med_rf,'tf':'H1'},
       (10546,'XAUUSD.DWX'):{'risk_fixed':med_rf,'tf':'M30'}}
CORE={**{k:v for k,v in base.items() if k!=(10163,'NDX.DWX')},**DENSE}
FX={(10569,'EURUSD.DWX'):{'risk_fixed':med_rf,'tf':'H4'},
    (10706,'GBPUSD.DWX'):{'risk_fixed':med_rf,'tf':'H1'},
    (11891,'GBPJPY.DWX'):{'risk_fixed':med_rf,'tf':'D1'}}

def daily_realized(book):
    days,realized,open_mae,trade_opens,loaded,stale=m.build_daily(book)
    return realized  # {day: realized_pnl}

def pairs_of(book):
    days,realized,open_mae,trade_opens,loaded,stale=m.build_daily(book)
    cal=((days[-1]-days[0]).days+1)/len(days)
    return [(realized.get(d,0.0),open_mae.get(d,0.0),trade_opens.get(d,0)) for d in days], cal

def corr(a,b):
    keys=sorted(set(a)|set(b)); xa=[a.get(k,0.0) for k in keys]; xb=[b.get(k,0.0) for k in keys]
    n=len(keys); ma=sum(xa)/n; mb=sum(xb)/n
    cov=sum((xa[i]-ma)*(xb[i]-mb) for i in range(n))
    va=math.sqrt(sum((x-ma)**2 for x in xa)); vb=math.sqrt(sum((x-mb)**2 for x in xb))
    return cov/(va*vb) if va*vb>0 else 0.0

def sim(pairs, norm):
    ann=sum(p[0] for p in pairs)/len(pairs)*365; f=norm/ann
    pr=[(r*f,o*f,t) for (r,o,t) in pairs]; rng=random.Random(3); passd=[]; out=collections.Counter()
    for _ in range(RUNS):
        seq=[]; n=len(pr)
        while len(seq)<365:
            s=rng.randrange(n)
            for o in range(BLOCK):
                seq.append(pr[(s+o)%n])
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

def at_budget(book, target=0.20):
    pairs,cal=pairs_of(book); lo,hi=5000.0,200000.0; mid=hi
    for _ in range(22):
        mid=(lo+hi)/2; r=sim(pairs,mid)
        if r['daily']<target: lo=mid
        else: hi=mid
    r=sim(pairs,mid); r['ann']=mid; r['cal']=cal; return r

core_real=daily_realized(CORE)
print("=== realized-daily-PnL correlation of each FX candidate vs 14-sleeve core ===")
for k,v in FX.items():
    cr=daily_realized({k:v})
    print(f"  {k[0]} {k[1]:<11} corr_to_core = {corr(core_real,cr):+.3f}")

print("\n=== augmented-book speed/breach at matched 20% daily-breach budget ===")
print(f"{'book':<26} {'sleeves':>7} {'P(+10%)':>8} {'med cal':>8} {'dailyBr':>8} {'maxBr':>6}")
tests=[("core 14",CORE)]
for k,v in FX.items(): tests.append((f"core + {k[0]} {k[1][:6]}",{**CORE,k:v}))
tests.append(("core + all 3 FX",{**CORE,**FX}))
for label,bk in tests:
    r=at_budget(bk); mc=round(r['med']*r['cal']) if r['med'] else None
    print(f"{label:<26} {len(bk):>7} {r['p']*100:>7.1f}% {str(mc):>8} {r['daily']*100:>7.0f}% {r['maxb']*100:>5.0f}%")
