"""Faithful composite recompute: capped-inverse-vol weights RECOMPUTED from the FRESH
(q08-SL/TP-fixed) Common streams (not the DRAFT's frozen weights), using the s4 methodology.
Computes DXZ-20 (corrected) and DXZ-20 + the 3 new candidates (13128/1556/10706)."""
import sys, json, math
sys.path.insert(0, r"C:/QM/repo")
from pathlib import Path
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl, align

STARTING_CAPITAL = 100_000.0; TOTAL_RISK = 9.75; CAP = 1.0
COMMON = Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files")
DRAFT = json.load(open(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_20sleeve_DRAFT_20260708.json"))

def pstd(v):
    n=len(v)
    if n==0: return 0.0
    m=sum(v)/n; return math.sqrt(sum((x-m)**2 for x in v)/n)

def capped_invvol(keys, daily):
    ak, dates, mat = align({k:daily[k] for k in keys if k in daily and daily[k]})
    vols={}
    for c,k in enumerate(ak):
        vols[k]=pstd([float(mat[r][c]) for r in range(len(dates))])
    inv={k:(1.0/vols[k] if vols[k]>0 else 0.0) for k in ak}
    tot=sum(inv.values()) or 1.0
    w={k:(inv[k]/tot)*TOTAL_RISK for k in ak}
    capped=set()
    for _ in range(50):
        over=[k for k in w if k not in capped and w[k]>CAP]
        if not over: break
        ex=0.0
        for k in over: ex+=w[k]-CAP; w[k]=CAP; capped.add(k)
        under=[k for k in w if k not in capped]; ti=sum(inv[k] for k in under)
        if ti<=0: break
        for k in under: w[k]+=ex*(inv[k]/ti)
    return w

def metrics(keys, risk_pct, daily):
    ak, dates, mat = align({k:daily[k] for k in keys if k in daily and daily[k]})
    dpnl=[sum(float(mat[r][c])*risk_pct.get(k,0.0) for c,k in enumerate(ak)) for r in range(len(dates))]
    eq=[]; cum=0.0
    for v in dpnl: cum+=v; eq.append(cum)
    rets=[v/STARTING_CAPITAL*100 for v in dpnl]
    mean=sum(rets)/len(rets); sd=pstd(rets)
    sharpe=(mean/sd)*math.sqrt(252) if sd>0 else 0.0
    peak=mdd=0.0
    for e in eq: peak=max(peak,e); mdd=max(mdd,peak-e)
    yrs=(dates[-1]-dates[0]).days/365.25 if len(dates)>1 else 1.0
    return dict(sharpe=round(sharpe,3), maxdd_pct=round(mdd/STARTING_CAPITAL*100,3),
                net=round(eq[-1],0), ann_pct=round(eq[-1]/STARTING_CAPITAL/yrs*100,2),
                n_sleeves=len(ak), days=len(dates))

book20=[(int(s["ea_id"]),s["symbol"]) for s in DRAFT["sleeves"]]
new3=[(13128,"NDX.DWX"),(1556,"XAUUSD.DWX"),(10706,"GBPUSD.DWX")]
book23=book20+new3
allkeys=list({*book20,*new3})
streams=load_streams(COMMON, candidates=allkeys)
daily={k:to_daily_pnl(v) for k,v in streams.items()}
missing20=[k for k in book20 if k not in daily or not daily[k]]
print(f"loaded {len(daily)} streams; book20 missing/empty: {missing20}")
print(f"new3 streams: "+", ".join(f"{k[0]}={len(streams.get(k,[]))}tr" for k in new3))

for label,book in [("DXZ-20 (fresh streams, recomputed weights)",book20),
                   ("DXZ-23 (+13128/1556/10706)",book23)]:
    w=capped_invvol(book, daily)
    m=metrics(book, w, daily)
    print(f"\n=== {label} ===")
    print(f"  sleeves={m['n_sleeves']} days={m['days']}  Sharpe={m['sharpe']}  MaxDD={m['maxdd_pct']}%  ann={m['ann_pct']}%  net=${m['net']:,.0f}")
print(f"\n(DRAFT reference on FROZEN d2d streams: Sharpe 2.890, MaxDD 24.557% — NOT directly comparable; different stream provenance)")
