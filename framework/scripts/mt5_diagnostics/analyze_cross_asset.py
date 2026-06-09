"""Cross-asset FX edge DISCOVERY (Claude 2026-06-09) — pure stdlib, no deps.

Hypothesis-first + strict DEV(2017-2022)/OOS(2023-2025) on H1 bars exported from the
dedicated T_Export terminal. Reports GROSS effects + an explicit cost-reality line
(H1 FX round-trip ~ spread+commission). We do NOT trust any DEV effect that does not
hold OOS; cross-asset mining is the most overfitting-prone approach (our 88% Q04 death).

Three economically-grounded hypotheses:
  H1  Lead-lag: does pair A's return predict pair B's NEXT-bar return? (info diffusion)
  H2  Cross-sectional reversion (OWNER's idea): build a USD factor; when one USD pair
      diverges from the cross-section this bar, does it revert next bar?
  H3  Cointegration pairs: EURUSD~GBPUSD, AUDUSD~NZDUSD spread mean-reversion.
"""
import csv, math, glob, os, datetime as dt

DATA = r"D:/QM/mt5/T_Export/MQL5/Files"
OOS_START = int(dt.datetime(2023, 1, 1, tzinfo=dt.timezone.utc).timestamp())
USD_MAJORS = ["EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDJPY", "USDCHF", "USDCAD"]
USD_QUOTE = {"EURUSD", "GBPUSD", "AUDUSD", "NZDUSD"}   # USD is quote -> usd_str = -ret
ALL = USD_MAJORS + ["EURJPY", "GBPJPY", "EURGBP", "AUDJPY", "EURAUD"]
# realistic H1 round-trip cost in return units (spread+commission), conservative ~0.8bp
RT_COST = 0.00008

def load(sym):
    out = {}
    p = os.path.join(DATA, f"{sym}.DWX_H1.csv")
    with open(p, newline="") as f:
        r = csv.reader(f); next(r)
        for row in r:
            out[int(row[0])] = float(row[4])  # close
    return out

def mean(x): return sum(x) / len(x) if x else 0.0
def std(x):
    if len(x) < 2: return 0.0
    m = mean(x); return math.sqrt(sum((v - m) ** 2 for v in x) / (len(x) - 1))
def corr(x, y):
    n = len(x)
    if n < 3: return 0.0
    mx, my = mean(x), mean(y)
    num = sum((x[i]-mx)*(y[i]-my) for i in range(n))
    dx = math.sqrt(sum((v-mx)**2 for v in x)); dy = math.sqrt(sum((v-my)**2 for v in y))
    return num/(dx*dy) if dx>0 and dy>0 else 0.0
def sharpe_ann(rets, bars_per_year=6048):
    if len(rets) < 10 or std(rets) == 0: return 0.0
    return mean(rets)/std(rets)*math.sqrt(bars_per_year)

print("loading H1 closes...")
closes = {s: load(s) for s in ALL}
common = set.intersection(*[set(c.keys()) for c in closes.values()])
ts = sorted(common)
print(f"aligned bars: {len(ts)}  ({dt.datetime.utcfromtimestamp(ts[0]):%Y-%m-%d} -> {dt.datetime.utcfromtimestamp(ts[-1]):%Y-%m-%d})")

# log returns per symbol, aligned to ts[1:]
ret = {s: [math.log(closes[s][ts[i]]/closes[s][ts[i-1]]) for i in range(1, len(ts))] for s in ALL}
rts = ts[1:]
dev = [i for i, t in enumerate(rts) if t < OOS_START]
oos = [i for i, t in enumerate(rts) if t >= OOS_START]
print(f"DEV bars {len(dev)}  OOS bars {len(oos)}\n")

# ---------------- H1: lead-lag ----------------
print("="*70); print("H1  LEAD-LAG: corr(ret_A[t], ret_B[t+1])  — DEV-selected, OOS-checked")
print("="*70)
cands = []
for a in ALL:
    for b in ALL:
        if a == b: continue
        xa = [ret[a][i] for i in dev[:-1]]; yb = [ret[b][i+1] for i in dev[:-1]]
        c_dev = corr(xa, yb)
        cands.append((abs(c_dev), c_dev, a, b))
cands.sort(reverse=True)
print(f"{'A->B(t+1)':20}{'IC_DEV':>9}{'IC_OOS':>9}{'grossSharpe_OOS':>16}{'net_OOS':>9}")
for _, c_dev, a, b in cands[:8]:
    xo = [ret[a][i] for i in oos[:-1]]; yo = [ret[b][i+1] for i in oos[:-1]]
    c_oos = corr(xo, yo)
    # trade B[t+1] in sign(ret_A[t]); gross per-bar return = sign(a)*ret_b
    g = [ (1 if ret[a][i] > 0 else -1) * ret[b][i+1] for i in oos[:-1] ]
    net = [ g[k] - (RT_COST if (1 if ret[a][oos[k]]>0 else -1) != (1 if ret[a][oos[k-1]]>0 else -1) else 0) for k in range(1,len(g)) ]
    print(f"{a+'->'+b:20}{c_dev:>9.4f}{c_oos:>9.4f}{sharpe_ann(g):>16.2f}{sharpe_ann(net):>9.2f}")

# ---------------- H2: cross-sectional USD reversion ----------------
print("\n"+"="*70); print("H2  CROSS-SECTIONAL USD REVERSION (OWNER): diverging USD pair reverts?")
print("="*70)
# usd-strength return per major: +ret if USD is base, -ret if USD is quote
def usd_ret(s, i): return -ret[s][i] if s in USD_QUOTE else ret[s][i]
def xsec_reversal_sharpe(idxs, apply_cost=False):
    port = []
    prevw = {s: 0.0 for s in USD_MAJORS}
    for k in range(len(idxs)-1):
        i = idxs[k]
        cur = {s: usd_ret(s, i) for s in USD_MAJORS}
        m = mean(list(cur.values()))
        # reversal weight = -(demeaned current); long laggards, short leaders; normalize
        w = {s: -(cur[s]-m) for s in USD_MAJORS}
        nrm = sum(abs(v) for v in w.values()) or 1.0
        w = {s: v/nrm for s, v in w.items()}
        nxt = idxs[k+1]
        pnl = sum(w[s]*usd_ret(s, nxt) for s in USD_MAJORS)
        if apply_cost:
            turn = sum(abs(w[s]-prevw[s]) for s in USD_MAJORS)
            pnl -= turn*RT_COST
        prevw = w
        port.append(pnl)
    return sharpe_ann(port), mean(port)
sd, md = xsec_reversal_sharpe(dev); so, mo = xsec_reversal_sharpe(oos)
sd_n, _ = xsec_reversal_sharpe(dev, True); so_n, _ = xsec_reversal_sharpe(oos, True)
print(f"long-laggard/short-leader USD basket, next-bar reversion:")
print(f"  DEV gross Sharpe {sd:>6.2f}   OOS gross Sharpe {so:>6.2f}")
print(f"  DEV  net Sharpe  {sd_n:>6.2f}   OOS  net Sharpe  {so_n:>6.2f}   (net of ~{RT_COST*1e4:.1f}bp/turn)")

# residual autocorrelation: regress each pair's usd_ret on USD factor, test residual revert
def usd_factor(i): return mean([usd_ret(s, i) for s in USD_MAJORS])
print("\n  per-pair residual next-bar autocorr (neg = reverts), OOS:")
for s in USD_MAJORS:
    fac_dev = [usd_factor(i) for i in dev]; y_dev = [usd_ret(s, i) for i in dev]
    b = corr(fac_dev, y_dev)*(std(y_dev)/std(fac_dev) if std(fac_dev)>0 else 0)
    resid = [usd_ret(s, i) - b*usd_factor(i) for i in oos]
    ac1 = corr(resid[:-1], resid[1:])
    print(f"    {s}: beta={b:>5.2f}  resid_AC1_OOS={ac1:>7.4f}")

# ---------------- H3: cointegration pairs ----------------
print("\n"+"="*70); print("H3  COINTEGRATION PAIRS: spread mean-reversion (hedge fit on DEV)")
print("="*70)
def lclose(s, i): return math.log(closes[s][ts[i]])
for a, b in [("EURUSD","GBPUSD"), ("AUDUSD","NZDUSD"), ("USDCHF","USDCAD")]:
    di = [i for i in range(len(ts)) if ts[i] < OOS_START]
    oi = [i for i in range(len(ts)) if ts[i] >= OOS_START]
    la = [lclose(a,i) for i in di]; lb = [lclose(b,i) for i in di]
    hedge = corr(lb, la)*(std(la)/std(lb)) if std(lb)>0 else 1.0
    sp_dev = [lclose(a,i)-hedge*lclose(b,i) for i in di]
    m, sdv = mean(sp_dev), std(sp_dev)
    # spread AR1 + half-life on DEV
    ac1 = corr(sp_dev[:-1], sp_dev[1:]); hl = (-math.log(2)/math.log(abs(ac1))) if 0<ac1<1 else float('inf')
    # OOS z-score reversion: short spread when z>2, long when z<-2, exit at 0; next-bar pnl proxy via -z*dspread
    sp_oos = [lclose(a,i)-hedge*lclose(b,i) for i in oi]
    z = [(v-m)/sdv if sdv>0 else 0 for v in sp_oos]
    pnl = [ -(1 if z[k]>1 else (-1 if z[k]<-1 else 0))*(sp_oos[k+1]-sp_oos[k]) for k in range(len(sp_oos)-1) ]
    print(f"  {a}~{b}: hedge={hedge:.2f}  spread_AC1_DEV={ac1:.4f}  half-life={hl:.0f} bars  OOS rev grossSharpe={sharpe_ann([p for p in pnl if p!=0]):.2f}")

print("\nNOTE: all Sharpes GROSS unless 'net'. H1 FX round-trip ~{:.1f}bp modeled; spread/slippage/swap NOT fully modeled. OOS is the judge.".format(RT_COST*1e4))
