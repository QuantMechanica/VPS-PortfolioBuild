"""Cross-asset v3 (Claude 2026-06-09): SYSTEMATIC idea generation, data-tested.
(A) Cointegration scan over ALL C(12,2)=66 FX pairs (D1, hedge fit on DEV, OOS net backtest).
(B) Triangular mispricing reversion (structural, near-zero-param).
Pure stdlib. DEV 2017-22 / OOS 23-25, net of ~0.8bp/leg. OOS is the judge."""
import csv, math, os, itertools, datetime as dt
DATA=r"D:/QM/mt5/T_Export/MQL5/Files"; OOS=int(dt.datetime(2023,1,1,tzinfo=dt.timezone.utc).timestamp()); RT=0.00008
SYMS=["EURUSD","GBPUSD","USDJPY","USDCHF","USDCAD","AUDUSD","NZDUSD","EURJPY","GBPJPY","EURGBP","AUDJPY","EURAUD"]
def load(s):
    d={};
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
cl={s:load(s) for s in SYMS}
ts=sorted(set.intersection(*[set(cl[s].keys()) for s in SYMS]))
di=[i for i,t in enumerate(ts) if t<OOS]; oi=[i for i,t in enumerate(ts) if t>=OOS]
L=lambda s,i: math.log(cl[s][ts[i]])

def pairs_backtest(a,b,idxs,hedge,LOOK=60):
    pos=0.0; rets=[]; nt=0
    for k in range(LOOK,len(idxs)-1):
        win=[L(a,idxs[j])-hedge*L(b,idxs[j]) for j in range(k-LOOK,k)]
        m,sd=mean(win),std(win)
        sp=L(a,idxs[k])-hedge*L(b,idxs[k]); spn=L(a,idxs[k+1])-hedge*L(b,idxs[k+1])
        z=(sp-m)/sd if sd>0 else 0
        npos=-1.0 if z>2 else (1.0 if z<-2 else (0.0 if abs(z)<0.5 else pos))
        rets.append(pos*(spn-sp)-RT*2*abs(npos-pos))
        if npos!=pos: nt+=1
        pos=npos
    return sharpe(rets), sum(rets), nt

print("="*78); print("(A) SYSTEMATIC COINTEGRATION SCAN — all 66 FX pairs, ranked by OOS net Sharpe")
print("    (require: DEV net Sharpe>0 AND OOS net Sharpe>0.8 AND >=4 OOS trades)")
print("="*78)
res=[]
for a,b in itertools.combinations(SYMS,2):
    la=[L(a,i) for i in di]; lb=[L(b,i) for i in di]
    if std(lb)==0: continue
    hedge=corr(lb,la)*(std(la)/std(lb))
    if hedge<=0: continue
    sd_s,sd_r,_=pairs_backtest(a,b,di,hedge); so_s,so_r,so_n=pairs_backtest(a,b,oi,hedge)
    sp_dev=[L(a,i)-hedge*L(b,i) for i in di]; ac1=corr(sp_dev[:-1],sp_dev[1:])
    hl=(-math.log(2)/math.log(ac1)) if 0<ac1<1 else 9999
    res.append((so_s,sd_s,so_r,so_n,a,b,hedge,hl))
res.sort(reverse=True)
print(f"{'pair':18}{'DEVshrp':>8}{'OOSshrp':>8}{'OOSret%':>8}{'OOStr':>6}{'hedge':>7}{'half-life':>10}")
shown=0
for so_s,sd_s,so_r,so_n,a,b,hedge,hl in res:
    if sd_s>0 and so_s>0.8 and so_n>=4:
        print(f"{a+'~'+b:18}{sd_s:>8.2f}{so_s:>8.2f}{so_r*100:>8.2f}{so_n:>6}{hedge:>7.2f}{hl:>10.0f}")
        shown+=1
if not shown: print("  (none cleared the bar — honest null result)")
print(f"\n  [AUDUSD~NZDUSD baseline already carded as QM5_12532]")

print("\n"+"="*78); print("(B) TRIANGULAR MISPRICING REVERSION — ln(cross) vs ln(leg1)+ln(leg2)")
print("="*78)
# triangles available from our 12 syms: (EURUSD,USDJPY,EURJPY),(GBPUSD,USDJPY,GBPJPY),
# (EURUSD,EURGBP->GBPUSD),(AUDUSD,USDJPY,AUDJPY),(EURUSD,EURAUD->AUDUSD)
tris=[("EURJPY","EURUSD","USDJPY",+1),("GBPJPY","GBPUSD","USDJPY",+1),
      ("AUDJPY","AUDUSD","USDJPY",+1),("EURGBP","EURUSD","GBPUSD",-1),
      ("EURAUD","EURUSD","AUDUSD",-1)]
print(f"{'triangle':28}{'resid_AC1_OOS':>14}{'OOS net Sharpe':>16}")
for cross,l1,l2,sgn in tris:
    # ln(cross) ~ ln(l1) + sgn*ln(l2);  resid = ln(cross)-ln(l1)-sgn*ln(l2)
    def resid(i): return L(cross,i)-L(l1,i)-sgn*L(l2,i)
    rd=[resid(i) for i in di]; ro=[resid(i) for i in oi]
    ac1=corr(ro[:-1],ro[1:])
    # trade the residual reversion: pos=-sign(z), pnl=pos*dresid, net of cost on flips
    m,sd=mean(rd),std(rd); pos=0.0; pnl=[]
    for k in range(len(ro)-1):
        z=(ro[k]-m)/sd if sd>0 else 0
        npos=-1.0 if z>2 else (1.0 if z<-2 else (0.0 if abs(z)<0.5 else pos))
        pnl.append(pos*(ro[k+1]-ro[k])-RT*3*abs(npos-pos)); pos=npos  # 3 legs
    print(f"{cross+'='+l1+('+' if sgn>0 else '-')+l2:28}{ac1:>14.4f}{sharpe([p for p in pnl]):>16.2f}")
print("\nNOTE: net of cost; swap unmodeled (D1 holds). Survivors -> Edge Lab cards; the pipeline judges.")
