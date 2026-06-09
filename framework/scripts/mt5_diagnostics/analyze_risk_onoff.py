"""Risk-on/off CROSS-ASSET-CLASS discovery (Claude 2026-06-09) — pure stdlib.
Equity index vs risk-FX vs havens vs gold. D1 (clean alignment, multi-day risk regime,
low turnover = cost-survivable). DEV 2017-22 / OOS 23-25, net of ~1bp/leg. OOS judges.

(A) Lead-lag: does equity[t] predict risk-asset[t+1]? (equities = fast risk asset)
(B) Cross-asset RV: spread = cumret(asset) - beta*cumret(SP500); when an asset diverges
    from its equity-risk-implied path beyond z, does it revert? (beta-hedged RV pair)
"""
import csv, math, os, datetime as dt
DATA=r"D:/QM/mt5/T_Export/MQL5/Files"; OOS=int(dt.datetime(2023,1,1,tzinfo=dt.timezone.utc).timestamp()); RT=0.0001
EQ="SP500"; ASSETS=["AUDUSD","NZDUSD","XAUUSD","USDJPY","USDCHF","NDX","GDAXI","WS30","EURUSD"]
ALL=[EQ]+ASSETS
def load(s):
    d={}
    with open(os.path.join(DATA,f"{s}.DWX_D1.csv"),newline="") as f:
        r=csv.reader(f); next(r)
        for row in r: d[int(row[0])]=float(row[4])
    return d
def mean(x): return sum(x)/len(x) if x else 0.0
def std(x):
    if len(x)<2: return 0.0
    m=mean(x); return math.sqrt(sum((v-m)**2 for v in x)/(len(x)-1))
def sharpe(r,ann=252): return mean(r)/std(r)*math.sqrt(ann) if len(r)>10 and std(r)>0 else 0.0
def corr(x,y):
    n=len(x)
    if n<3: return 0.0
    mx,my=mean(x),mean(y); num=sum((x[i]-mx)*(y[i]-my) for i in range(n))
    dx=math.sqrt(sum((v-mx)**2 for v in x)); dy=math.sqrt(sum((v-my)**2 for v in y))
    return num/(dx*dy) if dx>0 and dy>0 else 0.0
cl={s:load(s) for s in ALL}
ts=sorted(set.intersection(*[set(cl[s].keys()) for s in ALL]))
print(f"D1 aligned across {len(ALL)} assets: {len(ts)} bars ({dt.datetime.utcfromtimestamp(ts[0]):%Y-%m-%d}->{dt.datetime.utcfromtimestamp(ts[-1]):%Y-%m-%d})\n")
ret={s:[math.log(cl[s][ts[i]]/cl[s][ts[i-1]]) for i in range(1,len(ts))] for s in ALL}
rts=ts[1:]; dev=[i for i,t in enumerate(rts) if t<OOS]; oos=[i for i,t in enumerate(rts) if t>=OOS]

print("="*74); print(f"(A) LEAD-LAG: corr({EQ}[t], asset[t+1]) + sign-trade net Sharpe (DEV/OOS)")
print("="*74)
print(f"{'asset':10}{'IC_DEV':>9}{'IC_OOS':>9}{'OOS netSharpe':>15}")
for a in ASSETS:
    xd=[ret[EQ][i] for i in dev[:-1]]; yd=[ret[a][i+1] for i in dev[:-1]]
    xo=[ret[EQ][i] for i in oos[:-1]]; yo=[ret[a][i+1] for i in oos[:-1]]
    icd,ico=corr(xd,yd),corr(xo,yo)
    # trade asset[t+1] in sign(EQ[t]) per DEV sign; net of cost on flips
    sgn=1 if icd>=0 else -1
    g=[];prev=0
    for k in range(len(oos)-1):
        pos=sgn*(1 if ret[EQ][oos[k]]>0 else -1)
        g.append(pos*ret[a][oos[k]+1]-(RT if pos!=prev else 0)); prev=pos
    print(f"{a:10}{icd:>9.4f}{ico:>9.4f}{sharpe(g):>15.2f}")

print("\n"+"="*74); print(f"(B) CROSS-ASSET RV: spread=cumret(asset)-beta*cumret({EQ}); z-revert, net cost")
print("="*74)
cum={s:[0.0] for s in ALL}
for s in ALL:
    for i in range(len(ret[s])): cum[s].append(cum[s][-1]+ret[s][i])
# cum index aligns to rts via cum[s][k+1] after k returns; use idx into rts
def beta(a,idxs):
    x=[ret[EQ][i] for i in idxs]; y=[ret[a][i] for i in idxs]
    return corr(x,y)*(std(y)/std(x)) if std(x)>0 else 0.0
def rv_backtest(a,idxs,b,LOOK=40):
    # spread at return-index i = cum_asset - b*cum_eq (cum has len+1; use cum[..][i+1])
    sp=[cum[a][i+1]-b*cum[EQ][i+1] for i in range(len(ret[a]))]
    pos=0.0; rets=[]; nt=0
    for k in range(LOOK,len(idxs)-1):
        win=[sp[idxs[j]] for j in range(k-LOOK,k)]; m,sd=mean(win),std(win)
        z=(sp[idxs[k]]-m)/sd if sd>0 else 0
        npos=-1.0 if z>2 else (1.0 if z<-2 else (0.0 if abs(z)<0.5 else pos))
        # pnl of beta-hedged position over next bar
        pnl=pos*(ret[a][idxs[k]+1]-b*ret[EQ][idxs[k]+1]) if idxs[k]+1<len(ret[a]) else 0
        rets.append(pnl-RT*2*abs(npos-pos));
        if npos!=pos: nt+=1
        pos=npos
    return sharpe(rets),sum(rets),nt
print(f"{'asset~SP500':14}{'beta':>7}{'DEVshrp':>9}{'OOSshrp':>9}{'OOSret%':>9}{'OOStr':>6}{'corr':>7}")
for a in ASSETS:
    b=beta(a,dev); c=corr([ret[EQ][i] for i in dev],[ret[a][i] for i in dev])
    sd,_,_=rv_backtest(a,dev,b); so,sor,son=rv_backtest(a,oos,b)
    print(f"{a+'~'+EQ:14}{b:>7.2f}{sd:>9.2f}{so:>9.2f}{sor*100:>9.2f}{son:>6}{c:>7.2f}")
print("\nNOTE: net ~1bp/leg; swap unmodeled. Index CFD costs differ from FX. OOS + pipeline judge.")
