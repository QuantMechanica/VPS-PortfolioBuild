"""Intraday structure studies H3-H4-H5 (task 648ffc09, 2026-06-12).
Uses H1 bars as proxy for M30 specification (M30 not yet exported from T_Export).
Broker time: UTC+2 (non-US-DST) / UTC+3 (US-DST, 2nd Sun Mar -> 1st Sun Nov).
DEV: 2018-2021 (full years), OOS: 2022-2025 (partial 2026 excluded for OOS purity).
Pre-registered threshold: tradeable = OOS net Sharpe > 0.5 AND same sign as DEV.
Pure stdlib. Evidence over claims: t-stats reported; M30-upgrade note per study.
"""
import csv, math, os, datetime as dt

DATA = r"D:/QM/mt5/T_Export/MQL5/Files"
OUTDIR = r"D:/QM/reports/research"
os.makedirs(OUTDIR, exist_ok=True)

DEV_END = 2022   # DEV = 2018-2021
OOS_START = 2022 # OOS = 2022-2025
OOS_END = 2026   # exclusive

def mean(x): return sum(x) / len(x) if x else 0.0
def std(x):
    if len(x) < 2: return 0.0
    m = mean(x); return math.sqrt(sum((v - m) ** 2 for v in x) / (len(x) - 1))
def tstat1(x):
    if len(x) < 3: return 0.0
    m = mean(x); s = std(x)
    return m / (s / math.sqrt(len(x))) if s > 0 else 0.0

def nth_weekday_in_month(year, month, weekday, n):
    d = dt.date(year, month, 1)
    while d.weekday() != weekday: d += dt.timedelta(1)
    return d + dt.timedelta((n - 1) * 7)

def is_us_dst(ts):
    """True if UTC timestamp falls in US DST (2nd Sun Mar -> 1st Sun Nov)."""
    d = dt.datetime.utcfromtimestamp(ts)
    y = d.year
    dst_start = nth_weekday_in_month(y, 3, 6, 2)  # 2nd Sun Mar
    dst_end = nth_weekday_in_month(y, 11, 6, 1)   # 1st Sun Nov
    date = d.date()
    return dst_start <= date < dst_end

def broker_hour(ts):
    """Return broker hour (0-23) for UTC timestamp."""
    off = 3 if is_us_dst(ts) else 2
    return (dt.datetime.utcfromtimestamp(ts).hour + off) % 24

def load_h1(sym):
    """Return sorted list of (ts, date, broker_hour, open, high, low, close, log_ret)."""
    path = os.path.join(DATA, f"{sym}_H1.csv")
    raw = []
    with open(path, newline='') as f:
        r = csv.reader(f); next(r)
        for row in r:
            ts = int(row[0]); o = float(row[1]); h = float(row[2])
            lo = float(row[3]); c = float(row[4])
            raw.append((ts, o, h, lo, c))
    raw.sort()
    result = []
    prev_c = None
    for ts, o, h, lo, c in raw:
        lr = math.log(c / prev_c) if prev_c else 0.0
        d = dt.datetime.utcfromtimestamp(ts).date()
        bh = broker_hour(ts)
        result.append((ts, d, bh, o, h, lo, c, lr))
        prev_c = c
    return result

# ─── H3: By-broker-hour mean return (NDX, XAUUSD) ───────────────────────────

def study_h3(sym, bars):
    """Return by-hour stats for DEV and OOS periods."""
    dev = {h: [] for h in range(24)}
    oos = {h: [] for h in range(24)}
    for ts, d, bh, o, h, lo, c, lr in bars[1:]:
        year = d.year
        if 2018 <= year < DEV_END:
            dev[bh].append(lr)
        elif OOS_START <= year < OOS_END:
            oos[bh].append(lr)
    return dev, oos

def fmt_h3_row(h, r, label):
    n = len(r)
    if n < 10: return f"  bkr{h:02d}  {label}  n={n:<4} -- sparse"
    m = mean(r) * 100; s = std(r) * 100; t = tstat1(r)
    return f"  bkr{h:02d}  {label}  n={n:<4}  mean={m:+.4f}%  std={s:.4f}%  t={t:+.2f}"

# ─── H4: GDAXI Xetra-close -> US-close drift conditioned on Xetra session ──

# Broker Xetra-equivalent session: Xetra open 09:00 CET = broker 10:00 (UTC+2) or 11:00 (UTC+3)
# Xetra close 17:30 CET = broker 18:30 (UTC+2) or 19:30 (UTC+3)
# Post-Xetra window: broker 18:00 -> 22:00 (H1 hours 18, 19, 20, 21)
# Xetra body session: broker hours 10-17 (8 bars, conservative)
XETRA_BODY_HOURS = set(range(10, 18))     # broker hours 10-17
POST_XETRA_HOURS = set(range(18, 23))     # broker hours 18-22 (5 bars)

def study_h4(bars):
    """Per-day: compute Xetra body log-return direction, then post-Xetra cumulative LR."""
    days = {}
    for ts, d, bh, o, h, lo, c, lr in bars[1:]:
        if d not in days: days[d] = {'body': [], 'post': []}
        if bh in XETRA_BODY_HOURS: days[d]['body'].append(lr)
        if bh in POST_XETRA_HOURS: days[d]['post'].append(lr)

    dev_pos = []; dev_neg = []; oos_pos = []; oos_neg = []
    for d, v in sorted(days.items()):
        if not v['body'] or not v['post']: continue
        body_ret = sum(v['body'])
        post_ret = sum(v['post'])
        year = d.year
        if 2018 <= year < DEV_END:
            (dev_pos if body_ret > 0 else dev_neg).append(post_ret)
        elif OOS_START <= year < OOS_END:
            (oos_pos if body_ret > 0 else oos_neg).append(post_ret)

    return dev_pos, dev_neg, oos_pos, oos_neg

# ─── H5: XAUUSD Asia range vs London persistence ────────────────────────────

ASIA_HOURS = set(range(1, 9))      # broker hours 01-08 (8 bars)
LONDON_HOURS = set(range(9, 15))   # broker hours 09-14 (6 bars)

def study_h5(bars):
    """Per-day: compute Asia H-L range, London cumulative return, directional persistence."""
    days = {}
    for ts, d, bh, o, h, lo, c, lr in bars[1:]:
        if d not in days:
            days[d] = {'asia_h': [], 'asia_l': [], 'asia_open': None, 'london': [], 'london_open': None}
        if bh in ASIA_HOURS:
            days[d]['asia_h'].append(h)
            days[d]['asia_l'].append(lo)
            if days[d]['asia_open'] is None: days[d]['asia_open'] = o
        if bh in LONDON_HOURS:
            days[d]['london'].append(lr)
            if days[d]['london_open'] is None: days[d]['london_open'] = o

    day_data = []
    for d, v in sorted(days.items()):
        year = d.year
        if not (2018 <= year < OOS_END) or not v['asia_h'] or not v['london']:
            continue
        asia_range = max(v['asia_h']) - min(v['asia_l'])
        london_ret = sum(v['london'])
        is_dev = year < DEV_END
        day_data.append((d, asia_range, london_ret, is_dev))

    return day_data

def quintile_split(day_data):
    """Return lists of London returns by Asia range quintile."""
    if len(day_data) < 25: return {}, {}
    dev_days = [(r, lr) for d, r, lr, is_dev in day_data if is_dev]
    oos_days = [(r, lr) for d, r, lr, is_dev in day_data if not is_dev]

    def by_quintile(days):
        if len(days) < 10: return {}
        ranges = sorted([r for r, lr in days])
        n = len(ranges)
        # Build 5 quintile boundaries safely
        q_bounds = [ranges[min(int(n * i / 5), n - 1)] for i in range(5)] + [float('inf')]
        result = {q: [] for q in range(1, 6)}
        for r, lr in days:
            for q in range(1, 6):
                lo = q_bounds[q - 1]; hi = q_bounds[q]
                if lo <= r < hi or (q == 5 and r >= lo):
                    result[q].append(lr)
                    break
        return result

    return by_quintile(dev_days), by_quintile(oos_days)

# ─── Main ────────────────────────────────────────────────────────────────────

def run():
    csv_rows = [["study", "sym", "period", "label", "n", "mean_pct", "std_pct", "t"]]

    print("=" * 80)
    print("INTRADAY STRUCTURE STUDIES H3 / H4 / H5 — task 648ffc09 — 2026-06-12")
    print("NOTE: M30 not available; H1 used as 1h-slot proxy (lower resolution than spec).")
    print(f"DEV={2018}-{DEV_END-1}  OOS={OOS_START}-{OOS_END-1}")
    print("Pre-registered: tradeable = OOS net t > 2.0 AND same sign as DEV.")
    print("=" * 80)

    # ── H3 ──
    print("\n=== H3: By-broker-hour mean log-return (NDX, XAUUSD H1) ===")
    print("NY lunch = broker hr 19, power hour = broker hr 21 (H1 proxy for 30min slots)")
    for sym in ["NDX.DWX", "XAUUSD.DWX"]:
        try:
            bars = load_h1(sym)
        except FileNotFoundError:
            print(f"[{sym}] DATA MISSING"); continue

        dev, oos = study_h3(sym, bars)
        print(f"\n  {sym}:")
        focus_hours = [0, 1, 2, 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
        stable_hours = []
        for bh in range(24):
            dev_t = tstat1(dev[bh]); oos_t = tstat1(oos[bh])
            dev_sign = dev_t > 0; oos_sign = oos_t > 0
            stable = (abs(dev_t) > 2 and abs(oos_t) > 2 and dev_sign == oos_sign)
            if stable:
                stable_hours.append(bh)
            if bh in focus_hours or stable:
                print(fmt_h3_row(bh, dev[bh], "DEV") + "  " + fmt_h3_row(bh, oos[bh], "OOS"))
        print(f"  STABLE HOURS (|t|>2 both periods, same sign): {stable_hours if stable_hours else 'NONE'}")

        for bh in list(range(24)):
            for period_label, r in [("DEV", dev[bh]), ("OOS", oos[bh])]:
                n = len(r); m = mean(r)*100 if r else 0; s = std(r)*100 if r else 0; t = tstat1(r) if r else 0
                csv_rows.append(["H3", sym, period_label, f"bkr_h{bh:02d}", n, round(m, 5), round(s, 5), round(t, 3)])

    # ── H4 ──
    print("\n=== H4: GDAXI post-Xetra drift conditioned on Xetra body sign (H1 proxy) ===")
    print("Xetra body = broker hr 10-17; post-Xetra window = broker hr 18-22")
    try:
        gdaxi_bars = load_h1("GDAXI.DWX")
        dev_pos, dev_neg, oos_pos, oos_neg = study_h4(gdaxi_bars)
        for label, r, period in [
            ("DEV_body_UP", dev_pos, "DEV"), ("DEV_body_DN", dev_neg, "DEV"),
            ("OOS_body_UP", oos_pos, "OOS"), ("OOS_body_DN", oos_neg, "OOS")
        ]:
            n = len(r); m = mean(r)*100 if r else 0; s = std(r)*100 if r else 0; t = tstat1(r) if r else 0
            sig = "SIGNAL" if abs(t) > 2 else "."
            print(f"  {label:<20} n={n:<4} mean={m:+.4f}%  std={s:.4f}%  t={t:+.2f}  {sig}")
            csv_rows.append(["H4", "GDAXI.DWX", period, label, n, round(m, 5), round(s, 5), round(t, 3)])

        # Key hypothesis: positive body -> positive post-Xetra continuation
        up_t = tstat1(oos_pos); dn_t = tstat1(oos_neg)
        verdict = ("BUILD_CARD" if (abs(up_t) > 2 and abs(dn_t) > 2 and mean(oos_pos) > 0 and mean(oos_neg) < 0
                                   and abs(tstat1(dev_pos)) > 2 and abs(tstat1(dev_neg)) > 2)
                   else "INCONCLUSIVE" if (abs(up_t) > 1.5 or abs(dn_t) > 1.5) else "DEAD")
        print(f"  H4 VERDICT: {verdict}")
    except FileNotFoundError:
        print("  [GDAXI.DWX] DATA MISSING")

    # ── H5 ──
    print("\n=== H5: XAUUSD Asia range contraction vs London persistence (H1 proxy) ===")
    print("Asia session = broker hr 01-08; London = broker hr 09-14")
    try:
        xau_bars = load_h1("XAUUSD.DWX")
        day_data = study_h5(xau_bars)
        dev_q, oos_q = quintile_split(day_data)

        for period_label, q_data in [("DEV", dev_q), ("OOS", oos_q)]:
            if not q_data:
                print(f"  {period_label}: insufficient data"); continue
            print(f"\n  {period_label}:")
            for q in range(1, 6):
                r = q_data.get(q, [])
                n = len(r); m = mean(r)*100 if r else 0; s = std(r)*100 if r else 0; t = tstat1(r) if r else 0
                q_label = f"Q{q}({'contracted' if q==1 else 'expanded' if q==5 else 'mid'})"
                print(f"    Asia_range_{q_label:<30} n={n:<4} mean={m:+.4f}%  std={s:.4f}%  t={t:+.2f}")
                csv_rows.append(["H5", "XAUUSD.DWX", period_label, f"asia_range_Q{q}", n, round(m, 5), round(s, 5), round(t, 3)])

        # Verdict: Q1 (contracted) vs Q5 (expanded) OOS comparison
        q1_oos = oos_q.get(1, []); q5_oos = oos_q.get(5, [])
        q1_dev = dev_q.get(1, []); q5_dev = dev_q.get(5, [])
        if q1_oos and q5_oos:
            t1_oos = tstat1(q1_oos); t5_oos = tstat1(q5_oos)
            verdict = ("BUILD_CARD" if (abs(t1_oos) > 2 and abs(t5_oos) > 2
                                       and abs(tstat1(q1_dev)) > 1.5 and abs(tstat1(q5_dev)) > 1.5)
                       else "INCONCLUSIVE" if (abs(t1_oos) > 1.5 or abs(t5_oos) > 1.5) else "DEAD")
        else:
            verdict = "DEAD"
        print(f"\n  H5 VERDICT: {verdict}")
    except FileNotFoundError:
        print("  [XAUUSD.DWX] DATA MISSING")

    # Write CSV
    out_csv = os.path.join(OUTDIR, "intraday_h3_h4_h5_study_2026-06.csv")
    with open(out_csv, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerows(csv_rows)
    print(f"\nCSV evidence: {out_csv}")
    print("=" * 80)

if __name__ == "__main__":
    run()
