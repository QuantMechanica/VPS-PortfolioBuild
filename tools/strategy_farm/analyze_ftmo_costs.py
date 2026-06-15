"""CEO ad-hoc: inject realistic FTMO costs into the 5-leg survivor portfolio and
re-run the FTMO Challenge Monte-Carlo. Analysis-only, no pipeline side effects."""
import os, glob, json, datetime, random, statistics
from collections import defaultdict
random.seed(42)
TD = r'C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/q08_trades'

# 5 profitable Q07-PASS legs (from 2026-06-15 portfolio analysis)
LEGS = [('10692', 'NDX_DWX'), ('10115', 'GDAXI_DWX'), ('10911', 'GDAXI_DWX'),
        ('11165', 'AUDCAD_DWX'), ('10815', 'GDAXI_DWX')]

# Representative price to reconstruct notional where the field is absent (10692/NDX).
REPRICE = {'NDX': 15000.0, 'GDAXI': 15000.0, 'AUDCAD': 0.90, 'XAUUSD': 1900.0}

def asset_of(sym):
    return sym.split('_')[0]

def load(ea, sym):
    f = f'{TD}/{ea}_{sym}.jsonl'
    if not os.path.exists(f):
        return []
    out = []
    a = asset_of(sym)
    for l in open(f, encoding='utf-8', errors='replace'):
        l = l.strip()
        if not l:
            continue
        try:
            d = json.loads(l)
        except Exception:
            continue
        if d.get('time') is None or d.get('net') is None:
            continue
        vol = float(d.get('volume') or 0.0)
        notional = d.get('notional')
        if notional is None:
            # reconstruct: FX 1 lot = 100k base; index 1 lot ~ price * 1 contract
            if a in ('AUDCAD',):
                notional = vol * 100000 * REPRICE[a]
            else:
                notional = vol * REPRICE.get(a, 15000.0)
        notional = abs(float(notional))
        dt = datetime.datetime.utcfromtimestamp(int(d['time'])).date()
        out.append((dt, float(d['net']), notional))
    return out

legs = {}
print("=== leg notional sanity (median) ===")
for ea, sym in LEGS:
    r = load(ea, sym)
    if not r:
        continue
    legs[(ea, sym)] = r
    med_not = statistics.median([x[2] for x in r])
    print(f"  {ea}/{sym:12} trades={len(r):4} median_notional=${med_not:,.0f} gross=${sum(x[1] for x in r):,.0f}")

# cost model: round-turn cost = notional * cost_bps (covers spread+commission+some swap)
def portfolio_daily(cost_bps):
    daily = defaultdict(float)
    for rows in legs.values():
        for dt, net, notional in rows:
            cost = notional * (cost_bps / 10000.0)
            daily[dt] += (net - cost)
    days = sorted(daily)
    return days, [daily[d] for d in days]

ACCT, TARGET, FLOOR, DAILY_LOSS, WINDOW = 100_000, 110_000, 90_000, 5_000, 22

def sim(series, kmult, nsim=20000):
    arr = [s * kmult for s in series]
    n = len(arr)
    P = F = T = 0
    for _ in range(nsim):
        bal = ACCT; ds = ACCT; done = False; i = random.randrange(n)
        for _d in range(WINDOW):
            i = random.randrange(n) if random.random() < 0.2 else (i + 1) % n
            bal += arr[i]
            if bal <= FLOOR or bal <= ds - DAILY_LOSS:
                F += 1; done = True; break
            if bal >= TARGET:
                P += 1; done = True; break
            ds = bal
        if not done:
            T += 1
    return P / nsim, F / nsim, T / nsim

print("\n=== cost-stress: portfolio gross/yr at each cost level ===")
for bps in (0, 2, 4, 6):
    days, series = portfolio_daily(bps)
    tot = sum(series)
    yrs = (days[-1] - days[0]).days / 365.25
    eq = peak = mdd = 0
    for s in series:
        eq += s; peak = max(peak, eq); mdd = min(mdd, eq - peak)
    print(f"  {bps} bps round-turn -> gross ${tot:,.0f} (${tot/yrs:,.0f}/yr), maxDD ${mdd:,.0f}")

print("\n=== FTMO PASS% at sizing 1.5x / 2.0x across cost levels (resolved = PASS+FAIL) ===")
print(f"{'cost_bps':>8} | {'1.5x PASS/FAIL':>16} | {'2.0x PASS/FAIL':>16}")
for bps in (0, 2, 4, 6):
    days, series = portfolio_daily(bps)
    p15, f15, _ = sim(series, 1.5)
    p20, f20, _ = sim(series, 2.0)
    print(f"{bps:>8} | {p15*100:>5.1f}% / {f15*100:>5.1f}% | {p20*100:>5.1f}% / {f20*100:>5.1f}%")
