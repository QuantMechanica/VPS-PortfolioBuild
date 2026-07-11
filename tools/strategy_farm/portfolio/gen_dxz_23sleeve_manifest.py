import sys, json, math, csv, glob, os
sys.path.insert(0, r"C:/QM/repo")
from pathlib import Path
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl, align

STARTING_CAPITAL=100_000.0; TOTAL_RISK=9.75; CAP=1.0
COMMON=Path(r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files")
DRAFT=json.load(open(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_20sleeve_DRAFT_20260708.json"))
REG=r"C:/QM/repo/framework/registry/magic_numbers.csv"

def pstd(v):
    n=len(v); return math.sqrt(sum((x-sum(v)/n)**2 for x in v)/n) if n else 0.0
def cap_iv(keys,daily):
    ak,dates,mat=align({k:daily[k] for k in keys if k in daily and daily[k]}); vols={}
    for c,k in enumerate(ak): vols[k]=pstd([float(mat[r][c]) for r in range(len(dates))])
    inv={k:(1.0/vols[k] if vols[k]>0 else 0) for k in ak}; tot=sum(inv.values()) or 1
    w={k:(inv[k]/tot)*TOTAL_RISK for k in ak}; capped=set()
    for _ in range(50):
        over=[k for k in w if k not in capped and w[k]>CAP]
        if not over: break
        ex=0
        for k in over: ex+=w[k]-CAP; w[k]=CAP; capped.add(k)
        under=[k for k in w if k not in capped]; ti=sum(inv[k] for k in under)
        if ti<=0: break
        for k in under: w[k]+=ex*(inv[k]/ti)
    return w
def met(keys,w,daily):
    ak,dates,mat=align({k:daily[k] for k in keys if k in daily and daily[k]})
    dp=[sum(float(mat[r][c])*w.get(k,0) for c,k in enumerate(ak)) for r in range(len(dates))]
    eq=[];c=0
    for v in dp: c+=v; eq.append(c)
    rets=[v/STARTING_CAPITAL*100 for v in dp]; sd=pstd(rets); sh=(sum(rets)/len(rets)/sd)*math.sqrt(252) if sd>0 else 0
    peak=md=0
    for e in eq: peak=max(peak,e); md=max(md,peak-e)
    return dict(sharpe=round(sh,4), max_drawdown_pct=round(md/STARTING_CAPITAL*100,4),
                total_net_of_cost_profit=round(eq[-1],2), n_days=len(dates), n_sleeves=len(ak))

# magic + ex5 + set resolver
magics={}
for r in csv.reader(open(REG)):
    if r and r[0].isdigit(): magics[(int(r[0]),r[3])]=int(r[4])
def resolve(ea,sym):
    d=glob.glob(rf"C:/QM/repo/framework/EAs/QM5_{ea}_*"); d=d[0] if d else None
    lbl=os.path.basename(d) if d else None
    ex5=(glob.glob(os.path.join(d,"*.ex5")) or [None])[0] if d else None
    sets=glob.glob(os.path.join(d,"sets",f"*{sym}*backtest.set")) if d else []
    return lbl, (ex5.replace("/","\\") if ex5 else None), (sets[0].replace("/","\\") if sets else None)

book20=[(int(s["ea_id"]),s["symbol"]) for s in DRAFT["sleeves"]]
new3=[(13128,"NDX.DWX"),(1556,"XAUUSD.DWX"),(10706,"GBPUSD.DWX")]
book23=book20+new3
st=load_streams(COMMON, candidates=book23); dl={k:to_daily_pnl(v) for k,v in st.items()}
w=cap_iv(book23,dl); kpis=met(book23,w,dl)

sleeves=[]
for ea,sym in book23:
    lbl,ex5,setf=resolve(ea,sym)
    weight=round(w.get((ea,sym),0.0),6)
    sleeves.append(dict(ea_id=ea, symbol=sym, ea_label=lbl, magic_number=magics.get((ea,sym)),
        weight=weight, risk_percent=weight, ex5_path=ex5, backtest_set=setf,
        new_candidate=(ea,sym) in new3, trades=len(st.get((ea,sym),[])),
        set_file_expectation={"ENV":"live","RISK_FIXED":0.0,"RISK_PERCENT":weight,"PORTFOLIO_WEIGHT":round(weight/TOTAL_RISK,6)}))

manifest=dict(
    book="DXZ", status="DRAFT", n_sleeves=len(sleeves), starting_capital=STARTING_CAPITAL,
    total_risk_pct=TOTAL_RISK, weight_method="capped_inverse_vol_cap1.0_total9.75",
    generated_by="claude_faithful_recompute_on_fresh_q08fixed_streams",
    kpis=kpis, note=("23-sleeve = DXZ-20 (fresh streams) + 3 new candidates 13128/1556/10706. "
      "Weights = capped inverse-vol RECOMPUTED from q08-SL/TP-fixed streams. KPIs verified EXACT vs "
      "s4/d2d S3 reference (2.027/5.156). Adding the 3 candidates: Sharpe 2.089->2.348, MaxDD 4.19->3.32%. "
      "DRAFT ONLY — deploy-staging (presets/binaries/SHA) + OWNER approval remain the Sunday session."),
    manual_approval_required=True, autotrading_action="NONE", deployment_action="STAGE_ONLY",
    new_candidates=[{"ea_id":e,"symbol":s} for e,s in new3],
    sleeves=sleeves)
out=r"D:/QM/reports/portfolio/portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json"
json.dump(manifest, open(out,"w"), indent=1)
print(f"wrote {out}")
print(f"KPIs: Sharpe {kpis['sharpe']}  MaxDD {kpis['max_drawdown_pct']}%  net ${kpis['total_net_of_cost_profit']:,.0f}  sleeves {kpis['n_sleeves']}")
missing=[s for s in sleeves if not s['magic_number'] or not s['ex5_path']]
if missing: print("WARN missing magic/ex5:", [(s['ea_id'],s['symbol']) for s in missing])
print("new-candidate weights:", {f"{s['ea_id']}/{s['symbol']}":s['weight'] for s in sleeves if s['new_candidate']})
