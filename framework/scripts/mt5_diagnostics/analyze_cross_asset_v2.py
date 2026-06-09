"""Cross-asset v2 (Claude 2026-06-09): does the gross edge survive NET at LOW frequency?
Proper D1 backtests w/ entry/exit/holding + cost, DEV(2017-22)/OOS(2023-25). Pure stdlib.
Tests the two v1 survivors: AUDUSD~NZDUSD cointegration + cross-sectional USD reversion."""
import csv, math, os, datetime as dt
DATA = r"D:/QM/mt5/T_Export/MQL5/Files"
OOS = int(dt.datetime(2023,1,1,tzinfo=dt.timezone.utc).timestamp())
RT = 0.00008  # ~0.8bp per leg round-trip (spread+comm); D1 holds -> swap extra, noted
USD=["EURUSD","GBPUSD","AUDUSD","NZDUSD","USDJPY","USDCHF","USDCAD"]; QUOTE={"EURUSD","GBPUSD","AUDUSD","NZDUSD"}
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
    n=len(x);
    if n<3: return 0.0
    mx,my=mean(x),mean(y); num=sum((x[i]-mx)*(y[i]-my) for i in range(n))
    dx=math.sqrt(sum((v-mx)**2 for v in x)); dy=math.sqrt(sum((v-my)**2 for v in y))
    return num/(dx*dy) if dx>0 and dy>0 else 0.0

cl={s:load(s) for s in USD}
ts=sorted(set.intersection(*[set(cl[s].keys()) for s in USD]))
print(f"D1 aligned: {len(ts)} bars ({dt.datetime.utcfromtimestamp(ts[0]):%Y-%m-%d}->{dt.datetime.utcfromtimestamp(ts[-1]):%Y-%m-%d})\n")

# ---- AUDUSD~NZDUSD cointegration pairs trade (D1) ----
print("="*68); print("AUDUSD~NZDUSD pairs (D1): enter |z|>2, exit |z|<0.5, net of cost")
print("="*68)
a,b="AUDUSD","NZDUSD"
la=[math.log(cl[a][t]) for t in ts]; lb=[math.log(cl[b][t]) for t in ts]
di=[i for i,t in enumerate(ts) if t<OOS]
hedge=corr([lb[i] for i in di],[la[i] for i in di])*(std([la[i] for i in di])/std([lb[i] for i in di]))
LOOK=60  # rolling z lookback (the only real param besides thresholds)
def run(idxs,label):
    pos=0.0; entry_costed=False; rets=[]; ntrades=0
    for k in range(LOOK, len(idxs)-1):
        win=[la[idxs[j]]-hedge*lb[idxs[j]] for j in range(k-LOOK,k)]
        m,sd=mean(win),std(win)
        sp=la[idxs[k]]-hedge*lb[idxs[k]]; spn=la[idxs[k+1]]-hedge*lb[idxs[k+1]]
        z=(sp-m)/sd if sd>0 else 0
        newpos = -1.0 if z>2 else (1.0 if z<-2 else (0.0 if abs(z)<0.5 else pos))
        pnl = pos*(spn-sp)
        cost = RT*2*abs(newpos-pos)  # 2 legs
        if newpos!=pos: ntrades+=1
        rets.append(pnl-cost); pos=newpos
    yrs=len(idxs)/252
    print(f"  {label}: Sharpe={sharpe(rets):>6.2f}  net_ret_tot={sum(rets)*100:>7.2f}%  trades={ntrades}  (~{ntrades/max(yrs,1):.0f}/yr)")
run(di,"DEV"); run([i for i,t in enumerate(ts) if t>=OOS],"OOS")

# ---- cross-sectional USD reversion at D1, threshold-gated (lower turnover) ----
print("\n"+"="*68); print("Cross-sectional USD reversion (D1, daily rebalance): net of cost")
print("="*68)
def uret(s,i): return -(math.log(cl[s][ts[i]])-math.log(cl[s][ts[i-1]])) if s in QUOTE else (math.log(cl[s][ts[i]])-math.log(cl[s][ts[i-1]]))
def xsec(idxs,label):
    prev={s:0.0 for s in USD}; port=[]
    for k in range(len(idxs)-1):
        i=idxs[k]
        if i==0: continue
        cur={s:uret(s,i) for s in USD}; m=mean(list(cur.values()))
        w={s:-(cur[s]-m) for s in USD}; nrm=sum(abs(v) for v in w.values()) or 1.0
        w={s:v/nrm for s,v in w.items()}
        nxt=idxs[k+1]
        pnl=sum(w[s]*uret(s,nxt) for s in USD)
        turn=sum(abs(w[s]-prev[s]) for s in USD); prev=w
        port.append(pnl-turn*RT)
    print(f"  {label}: net Sharpe={sharpe(port):>6.2f}  net_ret_tot={sum(port)*100:>7.2f}%")
xsec(di,"DEV"); xsec([i for i,t in enumerate(ts) if t>=OOS],"OOS")
print("\nNOTE: net of ~0.8bp/leg. D1 holds incur SWAP (not modeled here) — real test = the pipeline.")
