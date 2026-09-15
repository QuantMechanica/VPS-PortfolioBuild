#!/usr/bin/env python3
"""Q3: find backtest work_items whose data window overlaps the archive gap
2025-10-09 .. 2025-11-03 AND ran on an affected terminal.

READ-ONLY (mode=ro). The gap is farm-wide: T1's Bases/Custom was the manifest
source and the identical signed .tkc bytes were verified byte-for-byte on
T1/T2/T5 (see q1q2_tkc_vs_manifest.csv), so ALL of T1..T10 are affected. We
therefore do not restrict by terminal; we record the terminal each row ran on.

Overlap test: window_start <= GAP_END AND window_end >= GAP_START.

Verdict-relevance:
  verdict-relevant     - row has a non-empty verdict AND its window overlaps the
                         gap (a gate verdict was produced from data covering the
                         gap window) -> the gap could have distorted that verdict
  not-verdict-relevant - window does not overlap the gap, OR the row never
                         produced a verdict (status pending/active, verdict NULL)
Only FX-cohort symbols (the ~21 with the shared Oct hole) are truly data-short in
Oct; index/commodity symbols carry a normal October (control), so a further
`symbol_in_oct_cohort` flag is emitted so the reader can see whether the row's
symbol is actually one that lost October ticks.
"""
import sqlite3
import json
import csv
import os
import datetime as dt

DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
GAP_START = dt.date(2025, 10, 9)
GAP_END = dt.date(2025, 11, 3)
OUT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'q3_affected_work_items.csv')

# The Oct-hole FX cohort (symbols whose 202510.tkc is ~75% short in the manifest).
# Derived empirically: any tick symbol whose manifest 202510 size < 40% of its
# 202509 size. Computed here from the manifest so it is not hand-asserted.
import json as _json
MAN = r'D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\archive_manifest_owner_approved.json'


def oct_hole_cohort():
    d = _json.load(open(MAN))
    from collections import defaultdict
    sz = defaultdict(dict)
    for f in d['files']:
        if f['relative_path'].startswith('ticks/'):
            _, sym, mon = f['relative_path'].split('/')
            sz[sym][mon.replace('.tkc', '')] = f['size']
    cohort = set()
    detail = {}
    for sym, m in sz.items():
        o10 = m.get('202510')
        o09 = m.get('202509')
        if o10 and o09 and o09 > 0:
            ratio = o10 / o09
            detail[sym] = round(ratio, 3)
            if ratio < 0.40:
                cohort.add(sym)
    return cohort, detail


def norm_date(s, is_end):
    """Normalize varied window strings to a date. Returns None if unparseable."""
    if s is None:
        return None
    s = str(s).strip()
    if not s:
        return None
    # ISO with time
    if 'T' in s:
        s = s.split('T')[0]
        s = s.replace('-', '.')
    s = s.replace('-', '.')
    parts = s.split('.')
    try:
        if len(parts) == 1:  # bare year
            y = int(parts[0])
            return dt.date(y, 12, 31) if is_end else dt.date(y, 1, 1)
        if len(parts) == 2:  # YYYY.MM
            y, m = int(parts[0]), int(parts[1])
            if is_end:
                nm = dt.date(y + (m == 12), (m % 12) + 1, 1)
                return nm - dt.timedelta(days=1)
            return dt.date(y, m, 1)
        y, m, day = int(parts[0]), int(parts[1]), int(parts[2])
        return dt.date(y, m, day)
    except (ValueError, IndexError):
        return None


def main():
    cohort, ratio_detail = oct_hole_cohort()
    con = sqlite3.connect(DB, uri=True)
    con.row_factory = sqlite3.Row
    cur = con.cursor()
    # Pull only rows whose window plausibly reaches 2025 (end year >= 2025) to
    # bound the scan; still normalize precisely in Python.
    cur.execute("""
        SELECT id, kind, phase, ea_id, symbol, status, verdict, verdict_taxonomy,
               data_window_start, data_window_end, evidence_path, updated_at,
               json_extract(payload_json,'$.from_date')  AS pj_from,
               json_extract(payload_json,'$.to_date')    AS pj_to,
               json_extract(payload_json,'$.terminal')   AS pj_terminal
        FROM work_items
    """)
    rows = cur.fetchall()
    out = []
    for r in rows:
        ws = norm_date(r['data_window_start'] or r['pj_from'], is_end=False)
        we = norm_date(r['data_window_end'] or r['pj_to'], is_end=True)
        if ws is None or we is None:
            continue
        overlaps = ws <= GAP_END and we >= GAP_START
        if not overlaps:
            continue
        has_verdict = bool((r['verdict'] or '').strip())
        sym = r['symbol']
        in_cohort = sym in cohort
        if has_verdict:
            relevance = 'verdict-relevant'
        else:
            relevance = 'not-verdict-relevant'  # window overlaps but no verdict yet
        out.append({
            'id': r['id'], 'kind': r['kind'], 'phase': r['phase'],
            'ea_id': r['ea_id'], 'symbol': sym,
            'terminal': r['pj_terminal'] or '',
            'status': r['status'], 'verdict': r['verdict'] or '',
            'verdict_taxonomy': r['verdict_taxonomy'] or '',
            'window_start': str(ws), 'window_end': str(we),
            'symbol_in_oct_cohort': in_cohort,
            'oct_size_ratio_vs_sep': ratio_detail.get(sym, ''),
            'evidence_relevance': relevance,
            'evidence_path': r['evidence_path'] or '',
            'updated_at': r['updated_at'],
        })
    con.close()

    out.sort(key=lambda x: (x['phase'], x['symbol'], x['id']))
    with open(OUT_CSV, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)

    from collections import Counter
    print('Oct-hole FX cohort (ratio 202510/202509 < 0.40):', sorted(cohort))
    print('total overlapping rows:', len(out))
    print('by relevance:', dict(Counter(x['evidence_relevance'] for x in out)))
    print('by phase:', dict(Counter(x['phase'] for x in out)))
    print('by terminal:', dict(Counter(x['terminal'] for x in out)))
    print('verdict-relevant AND symbol in Oct cohort:',
          sum(1 for x in out if x['evidence_relevance'] == 'verdict-relevant' and x['symbol_in_oct_cohort']))
    print('verdict-relevant but symbol NOT in Oct cohort (control syms):',
          sum(1 for x in out if x['evidence_relevance'] == 'verdict-relevant' and not x['symbol_in_oct_cohort']))
    print('wrote', OUT_CSV)


if __name__ == '__main__':
    main()
