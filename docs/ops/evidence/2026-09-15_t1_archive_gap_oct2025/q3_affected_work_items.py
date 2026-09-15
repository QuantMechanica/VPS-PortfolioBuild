#!/usr/bin/env python3
"""Q3: which work_items are exposed to the archive gap 2025-10-09 .. 2025-11-03.

READ-ONLY (farm_state.sqlite opened mode=ro). Nothing mutated.

This is the reworked version. Four things the first version got wrong, and how
they are handled now:

F1 MATERIALITY IS PER ROW, NOT BLANKET.
    The first version divided the ~26-day gap by an assumed ~2,700-day
    (2018-2025) window and reported "<1%". Most cohort rows do not have that
    window. Materiality is now computed per row from the row's OWN window:
        gap_calendar_days   = |[2025-10-09,2025-11-03] INTERSECT [ws,we]|
        gap_weekdays        = same, counting Mon-Fri only (trading-day proxy)
        materiality_cal_pct = gap_calendar_days / window_span_days
        materiality_wd_pct  = gap_weekdays / window_weekdays
    and reported as a distribution, split by window class.

F3 NON-EXECUTING ROWS ARE A SEPARATE CLASS AND ARE EXCLUDED FROM IMPACT.
    The first version's relevance rule was "verdict string is non-empty", which
    swept in SKIPPED_PRESCREEN / SKIPPED_EXCLUDED rows. Those are census
    pruning decisions: no backtest ran, so no tick was read and the gap cannot
    have distorted them. The class is derived from the data, not hardcoded by
    verdict name: a row is `no-data-read` iff payload_json carries NO
    claimed_at_iso AND NO terminal AND NO report_root. Measured over the whole
    table, exactly SKIPPED_EXCLUDED (6,219 rows) and SKIPPED_PRESCREEN (5,240
    rows) have 0/N on all three fields, while every executing verdict
    (PASS/FAIL/MEASURED/INFRA_FAIL/...) has ~100% — so the predicate is an
    empirical separator, not an assumption.

F4 COHORT MEMBERSHIP IS EMITTED AT TWO THRESHOLDS.
    See f4_cohort_threshold_matrix.py / .csv. The manifest's 28 FX pairs occupy
    ratio 0.2157-0.4087 and the 9 non-FX symbols occupy 1.1725-2.0808 — a clean
    gap, so any threshold in (0.4087, 1.1725) selects exactly "all 28 FX pairs".
    The old 0.40 threshold cut inside the FX population and silently exonerated
    GBPJPY (0.4087). Both memberships are emitted per row; the default cohort
    used for the headline counts is 0.50 (= all 28 FX pairs).

F5 BASKET / MULTI-SYMBOL ROWS RESOLVE THEIR LEGS.
    A row whose `symbol` is a logical basket name (FX8_BASKET_D1,
    QM5_*_COINTEGRATION_D1, ...) is not a manifest symbol, so a literal match
    called it "not in cohort" = intact. Legs are now resolved from
    payload_json.basket_symbols (present on all such rows in this table) and
    the row is cohort-exposed if ANY leg is a cohort symbol. If legs cannot be
    resolved for a non-manifest symbol, the row is marked UNJUDGEABLE, never
    silently intact.

Output: q3_affected_work_items.csv (same directory) + stdout summary.
"""
import csv
import datetime as dt
import json
import os
import sqlite3
import statistics
from collections import Counter, defaultdict

DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
MANIFEST = (r'D:\QM\strategy_farm\artifacts\ops'
            r'\custom_history_custom_history_variant_a_20260809'
            r'\archive_manifest_owner_approved.json')
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_CSV = os.path.join(HERE, 'q3_affected_work_items.csv')

GAP_START = dt.date(2025, 10, 9)
GAP_END = dt.date(2025, 11, 3)
DEFAULT_THRESHOLD = 0.50   # any value in (0.4087, 1.1725) gives the same cohort


def cohort_at(threshold):
    """Symbols whose signed 202510.tkc is < threshold x its 202509.tkc."""
    with open(MANIFEST, 'r', encoding='utf-8') as fh:
        d = json.load(fh)
    sz = defaultdict(dict)
    for f in d['files']:
        rp = f['relative_path']
        if rp.startswith('ticks/'):
            _, sym, mon = rp.split('/')
            sz[sym][mon.replace('.tkc', '')] = f['size']
    cohort, ratios = set(), {}
    for sym, m in sz.items():
        s09, s10 = m.get('202509'), m.get('202510')
        if s09 and s10 is not None and s09 > 0:
            r = s10 / s09
            ratios[sym] = round(r, 4)
            if r < threshold:
                cohort.add(sym)
    return cohort, ratios


def norm_date(s, is_end):
    """Normalize the mixed YYYY.MM.DD / YYYY-MM-DD / ISO / bare-year forms."""
    if s is None:
        return None
    s = str(s).strip()
    if not s:
        return None
    if 'T' in s:
        s = s.split('T')[0]
    s = s.replace('-', '.')
    parts = s.split('.')
    try:
        if len(parts) == 1:
            y = int(parts[0])
            return dt.date(y, 12, 31) if is_end else dt.date(y, 1, 1)
        if len(parts) == 2:
            y, m = int(parts[0]), int(parts[1])
            if is_end:
                nm = dt.date(y + (m == 12), (m % 12) + 1, 1)
                return nm - dt.timedelta(days=1)
            return dt.date(y, m, 1)
        return dt.date(int(parts[0]), int(parts[1]), int(parts[2]))
    except (ValueError, IndexError):
        return None


def weekdays_between(a, b):
    """Mon-Fri days in the inclusive range [a, b]; 0 if a > b."""
    if a > b:
        return 0
    n = 0
    d = a
    while d <= b:
        if d.weekday() < 5:
            n += 1
        d += dt.timedelta(days=1)
    return n


def main():
    cohort_050, ratios = cohort_at(0.50)
    cohort_040, _ = cohort_at(0.40)
    cohort = cohort_at(DEFAULT_THRESHOLD)[0]
    manifest_syms = set(ratios)

    con = sqlite3.connect(DB, uri=True)
    con.row_factory = sqlite3.Row
    cur = con.execute("""
        SELECT id, kind, phase, ea_id, symbol, status, verdict, verdict_taxonomy,
               data_window_start, data_window_end, evidence_path, updated_at,
               json_extract(payload_json,'$.from_date')       AS pj_from,
               json_extract(payload_json,'$.to_date')         AS pj_to,
               json_extract(payload_json,'$.terminal')        AS pj_terminal,
               json_extract(payload_json,'$.claimed_at_iso')  AS pj_claimed,
               json_extract(payload_json,'$.report_root')     AS pj_report,
               json_extract(payload_json,'$.basket_symbols')  AS pj_legs,
               json_extract(payload_json,'$.host_symbol')     AS pj_host
        FROM work_items
    """)

    out = []
    for r in cur:
        ws = norm_date(r['data_window_start'] or r['pj_from'], is_end=False)
        we = norm_date(r['data_window_end'] or r['pj_to'], is_end=True)
        if ws is None or we is None or ws > we:
            continue
        if not (ws <= GAP_END and we >= GAP_START):
            continue

        # ---- F1: per-row materiality -------------------------------------
        ov_lo, ov_hi = max(ws, GAP_START), min(we, GAP_END)
        gap_cal = (ov_hi - ov_lo).days + 1
        gap_wd = weekdays_between(ov_lo, ov_hi)
        span_cal = (we - ws).days + 1
        span_wd = weekdays_between(ws, we)
        mat_cal = round(100.0 * gap_cal / span_cal, 3) if span_cal else ''
        mat_wd = round(100.0 * gap_wd / span_wd, 3) if span_wd else ''
        window_class = ('2025_only_census'
                        if (ws == dt.date(2025, 1, 1) and we == dt.date(2025, 12, 31))
                        else 'multi_year')

        # ---- F3: did this row ever read data? ----------------------------
        executed = bool(r['pj_claimed'] or r['pj_terminal'] or r['pj_report'])
        has_verdict = bool((r['verdict'] or '').strip())
        if not executed:
            relevance = 'no-data-read'
        elif has_verdict:
            relevance = 'verdict-relevant'
        else:
            relevance = 'not-verdict-relevant'

        # ---- F5: resolve legs --------------------------------------------
        sym = r['symbol']
        legs, leg_src = [], ''
        if r['pj_legs']:
            try:
                legs = [str(x) for x in json.loads(r['pj_legs'])]
                leg_src = 'payload.basket_symbols'
            except (ValueError, TypeError):
                legs = []
        if not legs:
            if sym in manifest_syms:
                legs, leg_src = [sym], 'literal_symbol'
            elif r['pj_host'] and r['pj_host'] in manifest_syms:
                legs, leg_src = [r['pj_host']], 'payload.host_symbol'
            else:
                leg_src = 'UNRESOLVED'

        if leg_src == 'UNRESOLVED':
            exposure = 'UNJUDGEABLE'
            exposed_legs = []
        else:
            exposed_legs = [x for x in legs if x in cohort]
            exposure = 'EXPOSED' if exposed_legs else 'CONTROL'

        exp040 = ('EXPOSED' if any(x in cohort_040 for x in legs)
                  else ('UNJUDGEABLE' if leg_src == 'UNRESOLVED' else 'CONTROL'))

        out.append({
            'id': r['id'], 'kind': r['kind'], 'phase': r['phase'],
            'ea_id': r['ea_id'], 'symbol': sym,
            'is_multi_symbol': len(legs) > 1,
            'leg_source': leg_src,
            'legs': '|'.join(legs),
            'exposed_legs': '|'.join(exposed_legs),
            'cohort_exposure_at_0_50': exposure,
            'cohort_exposure_at_0_40': exp040,
            'oct_size_ratio_vs_sep': ratios.get(sym, ''),
            'terminal': r['pj_terminal'] or '',
            'status': r['status'], 'verdict': r['verdict'] or '',
            'verdict_taxonomy': r['verdict_taxonomy'] or '',
            'executed_backtest': executed,
            'evidence_relevance': relevance,
            'window_start': str(ws), 'window_end': str(we),
            'window_class': window_class,
            'window_span_days': span_cal,
            'window_span_weekdays': span_wd,
            'gap_calendar_days': gap_cal,
            'gap_weekdays': gap_wd,
            'materiality_calendar_pct': mat_cal,
            'materiality_weekday_pct': mat_wd,
            'evidence_path': r['evidence_path'] or '',
            'updated_at': r['updated_at'],
        })
    con.close()

    out.sort(key=lambda x: (x['phase'], x['symbol'], x['id']))
    with open(OUT_CSV, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)

    # ------------------------------------------------------------------ report
    def dist(rows, key):
        v = sorted(r[key] for r in rows if r[key] != '')
        if not v:
            return 'n/a'
        return (f'min={v[0]:.3f} p25={v[len(v)//4]:.3f} '
                f'median={statistics.median(v):.3f} '
                f'p75={v[3*len(v)//4]:.3f} max={v[-1]:.3f}')

    print('cohort @0.40:', len(cohort_040), '| cohort @0.50:', len(cohort_050),
          '| default threshold used:', DEFAULT_THRESHOLD)
    print('symbols that differ between the two thresholds:',
          sorted(cohort_050 - cohort_040))
    print()
    print('overlapping rows total:', len(out))
    print('by evidence_relevance:',
          dict(Counter(x['evidence_relevance'] for x in out)))
    print('by cohort_exposure_at_0_50:',
          dict(Counter(x['cohort_exposure_at_0_50'] for x in out)))
    print('multi-symbol (basket) rows:',
          sum(1 for x in out if x['is_multi_symbol']),
          '| leg sources:', dict(Counter(x['leg_source'] for x in out)))

    exposed = [x for x in out
               if x['cohort_exposure_at_0_50'] == 'EXPOSED'
               and x['evidence_relevance'] == 'verdict-relevant']
    exposed40 = [x for x in out
                 if x['cohort_exposure_at_0_40'] == 'EXPOSED'
                 and x['evidence_relevance'] == 'verdict-relevant']
    nodata_exposed = [x for x in out
                      if x['cohort_exposure_at_0_50'] == 'EXPOSED'
                      and x['evidence_relevance'] == 'no-data-read']
    unjudge = [x for x in out if x['cohort_exposure_at_0_50'] == 'UNJUDGEABLE']

    print()
    print('IMPACT SET = cohort-EXPOSED and verdict-relevant (executed):',
          len(exposed), f'(at the old 0.40 threshold it would be {len(exposed40)})')
    print('EXCLUDED as no-data-read but cohort-exposed:', len(nodata_exposed),
          dict(Counter(x['verdict'] for x in nodata_exposed)))
    print('UNJUDGEABLE (legs unresolvable):', len(unjudge))
    print()
    print('impact set by phase:', dict(Counter(x['phase'] for x in exposed)))
    print('impact set by verdict:', dict(Counter(x['verdict'] for x in exposed)))
    print('impact set by window_class:',
          dict(Counter(x['window_class'] for x in exposed)))
    print()
    for wc in ('2025_only_census', 'multi_year'):
        sub = [x for x in exposed if x['window_class'] == wc]
        if not sub:
            continue
        print(f'materiality {wc} (n={len(sub)}):')
        print('   calendar-day basis:', dist(sub, 'materiality_calendar_pct'))
        print('   weekday basis     :', dist(sub, 'materiality_weekday_pct'))
        print('   distinct windows  :',
              dict(Counter((x['window_start'], x['window_end']) for x in sub)))
    print()
    print('wrote', OUT_CSV)


if __name__ == '__main__':
    main()
