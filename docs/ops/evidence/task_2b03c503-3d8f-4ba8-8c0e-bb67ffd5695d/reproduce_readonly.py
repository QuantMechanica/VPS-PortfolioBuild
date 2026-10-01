import sys, json, hashlib, math
sys.path.insert(0, r"C:/QM/repo")
P = r"D:\QM\reports\work_items\21b31c7c-c4f2-45a0-9ebb-f3cb0d149859\QM5_41112\Q08\QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1\q08_sealed_stream.42f9b94736e8cd23.jsonl"
b = open(P,'rb').read()
print("sha", hashlib.sha256(b).hexdigest(), len(b))
from framework.scripts.q08_davey import common, aggregate, sub_8_9_runs_test as s89, sub_8_11_mc_shuffle_dd as s811
trades = common.load_trades_from_log(__import__('pathlib').Path(P))
print("n", len(trades))
adj, info = aggregate._apply_worst_case_commission(trades, "QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1")
print("comm", info["commission_total"], info["gross_total"])
r9 = s89.run(adj); print("8.9", r9["status"], r9["value"], r9["evidence"])
r11 = s811.run(adj); print("8.11", r11["status"], r11["evidence"]["as_realized_maxdd"], r11["evidence"]["mc_maxdd_p95"])
# order check
ts=[t["time"] for t in adj]
print("monotone_nondecreasing", all(ts[i]<=ts[i+1] for i in range(len(ts)-1)))
syms=[t["symbol"][:3] for t in adj]
print("alternating symbols", all(syms[i]!=syms[i+1] for i in range(len(syms)-1)), "first", syms[:6])
# pair into cycles by entry_time
from collections import defaultdict, Counter
cyc=defaultdict(list)
for i,t in enumerate(adj): cyc[t["entry_time"]].append((i,t))
sizes=Counter(len(v) for v in cyc.values()); print("cycle sizes by entry_time", sizes)
# exit time gaps within cycle
gaps=[max(x[1]["time"] for x in v)-min(x[1]["time"] for x in v) for v in cyc.values() if len(v)==2]
print("exit gap s: max", max(gaps), "n>0", sum(g>0 for g in gaps), "n>3600", sum(g>3600 for g in gaps))
# adjacency of pair legs
adjpair = all(abs(v[0][0]-v[1][0])==1 for v in cyc.values() if len(v)==2); print("pair legs adjacent in stream", adjpair)
seq=[(i,1 if t["net"]>0 else 0) for i,t in enumerate(adj) if t["net"]!=0]
print("zeros", sum(1 for t in adj if t["net"]==0))
# classify transitions: within-cycle vs between-cycle
cid={i:t["entry_time"] for i,t in enumerate(adj)}
w_tot=w_ch=b_tot=b_ch=0
for k in range(1,len(seq)):
    (i0,s0),(i1,s1)=seq[k-1],seq[k]
    if cid[i0]==cid[i1]:
        w_tot+=1; w_ch+= s0!=s1
    else:
        b_tot+=1; b_ch+= s0!=s1
print("within-cycle transitions", w_tot, "sign changes", w_ch)
print("between-cycle transitions", b_tot, "sign changes", b_ch)
# cycle-level sums (diagnostic only)
csum=[sum(x[1]["net"] for x in v) for k,v in sorted(cyc.items())]
cseq=[1 if x>0 else 0 for x in csum if x!=0]
print("cycles", len(csum), "cycle-level runs (DIAGNOSTIC)", s89._runs_test_p_value(cseq))
opp=sum(1 for v in cyc.values() if len(v)==2 and (v[0][1]["net"]>0)!=(v[1][1]["net"]>0)); print("opposite-sign pairs", opp, "of", sum(1 for v in cyc.values() if len(v)==2))
# 8.11 cycle-block shuffle diagnostic
import random
rng=random.Random(8112026); w=list(csum); dds=[]
for _ in range(1000):
    rng.shuffle(w); dds.append(s811._max_drawdown_abs(w))
print("cycle-block realized dd", s811._max_drawdown_abs(csum), "p95", s811._nearest_rank_percentile(dds,95))
# MAE sum per cycle (upper bound of concurrent unrealized)
maes=[sum(x[1].get("mae_acct",0) for x in v) for v in cyc.values()]
print("worst cycle sum-of-leg-MAE", min(maes), "worst single-leg MAE", min(t.get("mae_acct",0) for t in adj))
print("worst realized cycle", min(csum), "worst leg", min(t["net"] for t in adj))
print("==== ordering sensitivity")
cyc_sorted=[ [ (1 if x[1]["net"]>0 else 0) for x in v] for k,v in sorted(cyc.items())]
def runs_of(order_bits):
    s=[b for c in order_bits for b in c]; return s89._runs_test_p_value(s)
print("as-stream", runs_of(cyc_sorted))
print("reversed-within-pair", runs_of([c[::-1] for c in cyc_sorted]))
# DP min/max runs over 2^53 within-pair orderings
INF=10**9
dp={}  # last bit -> (minR,maxR)
c0=cyc_sorted[0]
for o in ({tuple(c0),tuple(c0[::-1])}):
    r=1+(o[0]!=o[1]); l=o[1]
    mn,mx=dp.get(l,(INF,-INF)); dp[l]=(min(mn,r),max(mx,r))
for c in cyc_sorted[1:]:
    nd={}
    for last,(mn,mx) in dp.items():
        for o in {tuple(c),tuple(c[::-1])}:
            add=(o[0]!=last)+(o[0]!=o[1]); l=o[1]
            a,b=nd.get(l,(INF,-INF)); nd[l]=(min(a,mn+add),max(b,mx+add))
    dp=nd
mn=min(v[0] for v in dp.values()); mx=max(v[1] for v in dp.values())
n1,n2=55,51
E=2*n1*n2/(n1+n2)+1; V=2*n1*n2*(2*n1*n2-n1-n2)/((n1+n2)**2*(n1+n2-1))
for R in (mn,78,mx):
    z=(R-E)/math.sqrt(V); p=2*(1-0.5*(1+math.erf(abs(z)/math.sqrt(2))))
    print("R",R,"z",round(z,3),"p",p)
print("E",E,"Var",V)
print("==== toy")
legs=[]; cyc_signs=[1,1,0,1,0,0,1,0,1,1]
for s in cyc_signs: legs += [1,0]
print("toy leg-level", s89._runs_test_p_value(legs))
print("toy cycle-level", s89._runs_test_p_value(cyc_signs))
