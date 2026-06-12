"""OPEX-week index effect study (task 27195799 Study B, 2026-06-12).
Hypothesis: OPEX-week long-index effect (Stivers-Sun 1988-2010) OOS at NDX/WS30/GDAXI/SP500.
Data: D1 closes from T_Export (available from ~2018); Stivers-Sun DEV=1988-2010 is BEFORE
our data window, so ALL available data is genuinely OOS. We sub-split 2018-2021 / 2022-2026.
Pre-registered threshold: tradeable = both sub-periods net Sharpe > 0.5 AND same sign as the
Stivers-Sun finding (positive OPEX week return; post-OPEX-week weakness possible).
Cost: index CFD spread ~0.3-0.5bp/side; $0 swap on .DWX (confirmed cost model). Pure stdlib.
"""
import csv, math, os, datetime as dt

DATA = r"D:/QM/mt5/T_Export/MQL5/Files"
OUTDIR = r"D:/QM/reports/research"
os.makedirs(OUTDIR, exist_ok=True)

SYMS = ["NDX.DWX", "WS30.DWX", "GDAXI.DWX", "SP500.DWX"]
SPLIT1 = 2022  # sub-period 2 starts this year
COST_BPS = 0.5  # conservative round-trip cost in bps for weekly hold

def mean(x):
    return sum(x) / len(x) if x else 0.0

def std(x):
    if len(x) < 2: return 0.0
    m = mean(x)
    return math.sqrt(sum((v - m) ** 2 for v in x) / (len(x) - 1))

def tstat(x, bench=None):
    if bench is None:
        if len(x) < 3: return 0.0
        m = mean(x); s = std(x)
        return m / (s / math.sqrt(len(x))) if s > 0 else 0.0
    # Welch t-test: x vs bench
    n1, n2 = len(x), len(bench)
    if n1 < 3 or n2 < 3: return 0.0
    m1, m2 = mean(x), mean(bench)
    s1, s2 = std(x), std(bench)
    se = math.sqrt(s1 ** 2 / n1 + s2 ** 2 / n2)
    return (m1 - m2) / se if se > 0 else 0.0

def bootstrap_sharpe(r, n_boot=2000, seed=42):
    """Return (mean_boot_sharpe, p_value_two_tail) via percentile bootstrap."""
    if len(r) < 10: return 0.0, 1.0
    m = mean(r); s = std(r)
    obs_sharpe = m / s * math.sqrt(52) if s > 0 else 0.0
    # pseudo-random via LCG
    x = seed
    def rand():
        nonlocal x
        x = (1664525 * x + 1013904223) & 0xFFFFFFFF
        return x / 0xFFFFFFFF
    boots = []
    n = len(r)
    for _ in range(n_boot):
        sample = [r[int(rand() * n)] for _ in range(n)]
        ms = mean(sample); ss = std(sample)
        boots.append(ms / ss * math.sqrt(52) if ss > 0 else 0.0)
    boots.sort()
    pv = 2 * min(sum(b <= 0 for b in boots), sum(b > 0 for b in boots)) / n_boot
    return obs_sharpe, pv

def nth_weekday(year, month, weekday, n):
    """Return the nth occurrence of weekday (0=Mon..6=Sun) in (year, month)."""
    d = dt.date(year, month, 1)
    while d.weekday() != weekday:
        d += dt.timedelta(1)
    return d + dt.timedelta((n - 1) * 7)

def third_friday(year, month):
    return nth_weekday(year, month, 4, 3)  # weekday 4 = Friday

def build_opex_sets():
    """Return (opex_iso_weeks, quad_iso_weeks, week_after_iso_weeks) as sets of (iso_year, iso_week)."""
    opex = set(); quad = set(); after = set()
    for year in range(2015, 2027):
        for month in range(1, 13):
            tf = third_friday(year, month)
            yy, ww, _ = tf.isocalendar()
            opex.add((yy, ww))
            if month in (3, 6, 9, 12):
                quad.add((yy, ww))
            # week after
            after_date = tf + dt.timedelta(7)
            ay, aw, _ = after_date.isocalendar()
            after.add((ay, aw))
    return opex, quad, after

def load_d1(sym):
    """Return list of (date, close, log_return) sorted by date. First bar has log_return=0."""
    path = os.path.join(DATA, f"{sym}_D1.csv")
    bars = []
    with open(path, newline='') as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            ts = int(row[0])
            c = float(row[4])
            d = dt.datetime.utcfromtimestamp(ts).date()
            bars.append((d, c))
    bars.sort()
    result = []
    for i, (d, c) in enumerate(bars):
        lr = math.log(c / bars[i - 1][1]) if i > 0 else 0.0
        result.append((d, c, lr))
    return result

def weekly_returns(bars):
    """Aggregate daily bars into weekly (ISO week) returns.
    Returns list of (iso_year, iso_week, date_of_last_bar, total_log_return, n_bars)."""
    weeks = {}
    for d, c, lr in bars:
        yy, ww, _ = d.isocalendar()
        if (yy, ww) not in weeks:
            weeks[(yy, ww)] = {'close': None, 'last_date': None, 'lr_sum': 0.0, 'n': 0}
        w = weeks[(yy, ww)]
        w['close'] = c
        w['last_date'] = d
        w['lr_sum'] += lr
        w['n'] += 1
    result = sorted(
        [(yy, ww, v['last_date'], v['lr_sum'], v['n']) for (yy, ww), v in weeks.items()]
    )
    return result

def analyze_sym(sym, opex, quad, after):
    bars = load_d1(sym)
    weeks = weekly_returns(bars)
    # Skip first week (incomplete log_return)
    weeks = weeks[1:]

    cats = {'OPEX_NON_QUAD': [], 'QUAD': [], 'WEEK_AFTER': [], 'NORMAL': []}
    cats_p1 = {k: [] for k in cats}  # 2018-2021
    cats_p2 = {k: [] for k in cats}  # 2022+

    for yy, ww, last_d, lr, n in weeks:
        if n < 3:
            continue  # skip weeks with <3 bars (holiday-heavy)
        cost = COST_BPS / 10000
        net_lr = lr - cost

        key = (yy, ww)
        if key in quad:
            cat = 'QUAD'
        elif key in opex:
            cat = 'OPEX_NON_QUAD'
        elif key in after:
            cat = 'WEEK_AFTER'
        else:
            cat = 'NORMAL'

        cats[cat].append(net_lr)
        if last_d.year < SPLIT1:
            cats_p1[cat].append(net_lr)
        else:
            cats_p2[cat].append(net_lr)

    return cats, cats_p1, cats_p2

def fmt_stats(label, r, bench):
    n = len(r)
    if n < 3:
        return f"  {label:<22} n={n:<4} -- insufficient data"
    m = mean(r) * 100
    s = std(r) * 100
    t = tstat(r, bench)
    sh, pv = bootstrap_sharpe(r)
    return (f"  {label:<22} n={n:<4} mean={m:+.3f}%  std={s:.3f}%  "
            f"t_vs_normal={t:+.2f}  Sharpe_ann={sh:+.2f}  boot_p={pv:.3f}")

def run():
    opex, quad, after = build_opex_sets()
    print("=" * 80)
    print("OPEX-WEEK INDEX STUDY — task 27195799 Study B — 2026-06-12")
    print("Data: T_Export D1 bars (~2018-2026). Pre-registered threshold: OOS net Sharpe > 0.5")
    print("Note: all data is OOS relative to Stivers-Sun DEV (1988-2010).")
    print("Sub-periods: P1=2018-2021, P2=2022-2026. Cost: 0.5bp round-trip assumed.")
    print("=" * 80)

    csv_rows = [["symbol", "period", "category", "n", "mean_pct", "std_pct",
                 "t_vs_normal", "sharpe_ann_52wk", "boot_pval"]]

    for sym in SYMS:
        try:
            cats, cats_p1, cats_p2 = analyze_sym(sym, opex, quad, after)
        except FileNotFoundError:
            print(f"\n[{sym}] DATA MISSING — skip")
            continue

        print(f"\n--- {sym} (FULL PERIOD 2018-2026) ---")
        bench = cats['NORMAL']
        for cat in ['OPEX_NON_QUAD', 'QUAD', 'WEEK_AFTER', 'NORMAL']:
            r = cats[cat]
            print(fmt_stats(cat, r, bench if cat != 'NORMAL' else None))
            n = len(r)
            m_pct = mean(r) * 100 if r else 0
            s_pct = std(r) * 100 if r else 0
            t = tstat(r, bench) if cat != 'NORMAL' and r else 0
            sh, pv = bootstrap_sharpe(r) if r else (0, 1)
            csv_rows.append([sym, "FULL", cat, n, round(m_pct, 4), round(s_pct, 4),
                             round(t, 3), round(sh, 3), round(pv, 3)])

        print(f"\n  Sub-period P1 (2018-{SPLIT1 - 1}):")
        bench_p1 = cats_p1['NORMAL']
        for cat in ['OPEX_NON_QUAD', 'QUAD', 'WEEK_AFTER']:
            r = cats_p1[cat]
            print(fmt_stats(cat, r, bench_p1))
            n = len(r); m_pct = mean(r) * 100 if r else 0; s_pct = std(r) * 100 if r else 0
            t = tstat(r, bench_p1) if r else 0; sh, pv = bootstrap_sharpe(r) if r else (0, 1)
            csv_rows.append([sym, f"P1_2018-{SPLIT1-1}", cat, n, round(m_pct, 4),
                             round(s_pct, 4), round(t, 3), round(sh, 3), round(pv, 3)])

        print(f"\n  Sub-period P2 ({SPLIT1}-2026):")
        bench_p2 = cats_p2['NORMAL']
        for cat in ['OPEX_NON_QUAD', 'QUAD', 'WEEK_AFTER']:
            r = cats_p2[cat]
            print(fmt_stats(cat, r, bench_p2))
            n = len(r); m_pct = mean(r) * 100 if r else 0; s_pct = std(r) * 100 if r else 0
            t = tstat(r, bench_p2) if r else 0; sh, pv = bootstrap_sharpe(r) if r else (0, 1)
            csv_rows.append([sym, f"P2_{SPLIT1}-2026", cat, n, round(m_pct, 4),
                             round(s_pct, 4), round(t, 3), round(sh, 3), round(pv, 3)])

    # Write CSV
    out_csv = os.path.join(OUTDIR, "opex_week_index_study_2026-06.csv")
    with open(out_csv, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerows(csv_rows)
    print(f"\nCSV evidence: {out_csv}")
    print("=" * 80)

if __name__ == "__main__":
    run()
