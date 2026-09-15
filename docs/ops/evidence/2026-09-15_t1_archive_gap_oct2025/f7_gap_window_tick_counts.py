#!/usr/bin/env python3
"""F7: bind the gap localisation to TICK/BAR COUNTS, not just .tkc file sizes.

READ-ONLY. Reads only already-produced export artefacts under D:/QM/reports.
No terminal started, nothing written outside this evidence directory.

Two independent count-level sources, both produced by the 2026-09-15 06:35Z
DWX M1 overlap export that ran against T1's Custom archive (the same archive
whose .tkc bytes match the signed manifest):

  A) per-chunk journal  raw/<SYMBOL>_M1_chunks.csv
     columns: symbol, chunk_start_epoch, chunk_end_epoch, phase, attempt,
              copied, error_code, status
     `copied` on the phase=final row is the number of TICKS CopyTicksRange
     returned for that 7-day chunk; status=ZERO_TICK_CHUNK means 0 ticks after
     3 retries. This is a direct tick count out of the archive.

  B) per-day M1 bar counts  dwx_m1/<SYMBOL>_M1.csv
     columns: time,open,high,low,close,tickvol
     Counting rows per calendar day inside 2025-10-01..2025-11-10 gives bars/day
     and summed tickvol/day directly out of the exported archive data.

IMPORTANT CAVEAT (do not read the counts naively): this same export has a
SEPARATE, already-documented defect — 10 of the 37 symbols came back
SHORT_READ (a handful of bars for the whole 6-month window), measured in
`docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/f2_completeness_floor_measurement.csv`.
For those 10 symbols a zero chunk / zero day proves nothing about the archive,
only that the export failed. They are marked `export_status=SHORT_READ` and
`count_evidence=UNJUDGEABLE` here and MUST be excluded from any count-level
conclusion. Only the 27 `COMPLETE` symbols carry count-level evidence.

Outputs (same directory):
  f7_chunk_tick_counts.csv   - one row per (symbol, chunk) for chunks intersecting
                               2025-09-24 .. 2025-11-12
  f7_daily_bar_counts.csv    - one row per (symbol, date) for 2025-10-01..2025-11-10
  f7_symbol_gap_summary.csv  - per symbol: export status, zero chunks, gap-window
                               weekday bars vs control-weekday median
"""
import csv
import datetime as dt
import os
import sys

EXPORT = r'D:\QM\reports\dukascopy\reconciliation_inputs\dwx_m1\20260915_063500'
RAW = os.path.join(EXPORT, 'raw')
M1 = os.path.join(EXPORT, 'dwx_m1')
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_CHUNKS = os.path.join(HERE, 'f7_chunk_tick_counts.csv')
OUT_DAILY = os.path.join(HERE, 'f7_daily_bar_counts.csv')
OUT_SUM = os.path.join(HERE, 'f7_symbol_gap_summary.csv')

# Export-completeness classification produced by the sibling ticket (read-only).
COMPLETENESS_CSV = os.path.abspath(os.path.join(
    HERE, '..', '2026-09-15_dukascopy_export_fix_r2',
    'f2_completeness_floor_measurement.csv'))

GAP_START = dt.date(2025, 10, 9)
GAP_END = dt.date(2025, 11, 3)
CH_LO = dt.datetime(2025, 9, 24, tzinfo=dt.timezone.utc)
CH_HI = dt.datetime(2025, 11, 12, tzinfo=dt.timezone.utc)
DAY_LO = dt.date(2025, 10, 1)
DAY_HI = dt.date(2025, 11, 10)


def export_status():
    """symbol -> COMPLETE | SHORT_READ | UNKNOWN (export-side completeness)."""
    out = {}
    try:
        with open(COMPLETENESS_CSV, 'r', encoding='utf-8', newline='') as fh:
            for r in csv.DictReader(fh):
                out[r['symbol']] = r['status']
    except OSError:
        pass
    return out


def ep(x):
    """Format the export's broker-epoch integer the same way the reconciliation
    summary does (plain UTC rendering of the epoch value)."""
    return dt.datetime.fromtimestamp(int(x), dt.timezone.utc)


def do_chunks(est):
    rows = []
    if not os.path.isdir(RAW):
        return rows
    for fn in sorted(os.listdir(RAW)):
        if not fn.endswith('_M1_chunks.csv'):
            continue
        path = os.path.join(RAW, fn)
        with open(path, 'r', encoding='utf-8', newline='') as fh:
            for r in csv.DictReader(fh):
                if r['phase'] != 'final':
                    continue  # the final row carries the settled count
                a, b = ep(r['chunk_start_epoch']), ep(r['chunk_end_epoch'])
                if b <= CH_LO or a >= CH_HI:
                    continue
                st = est.get(r['symbol'], 'UNKNOWN')
                rows.append({
                    'symbol': r['symbol'],
                    'export_status': st,
                    'count_evidence': 'USABLE' if st == 'COMPLETE' else 'UNJUDGEABLE',
                    'chunk_start_utc': a.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    'chunk_end_utc': b.strftime('%Y-%m-%dT%H:%M:%SZ'),
                    'chunk_start_epoch': r['chunk_start_epoch'],
                    'chunk_end_epoch': r['chunk_end_epoch'],
                    'ticks_copied': int(r['copied']),
                    'status': r['status'],
                    'intersects_gap': not (b.date() <= GAP_START or a.date() >= GAP_END),
                    'source_journal': path,
                })
    rows.sort(key=lambda x: (x['symbol'], x['chunk_start_epoch']))
    if rows:
        with open(OUT_CHUNKS, 'w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
    return rows


def do_daily(est):
    rows = []
    if not os.path.isdir(M1):
        return rows
    for fn in sorted(os.listdir(M1)):
        if not fn.endswith('_M1.csv'):
            continue
        sym = fn[:-len('_M1.csv')]
        bars = {}
        tv = {}
        with open(os.path.join(M1, fn), 'r', encoding='utf-8', newline='') as fh:
            rd = csv.DictReader(fh)
            for r in rd:
                d = r['time'][:10]
                try:
                    day = dt.date(int(d[0:4]), int(d[5:7]), int(d[8:10]))
                except ValueError:
                    continue
                if day < DAY_LO or day > DAY_HI:
                    continue
                bars[day] = bars.get(day, 0) + 1
                try:
                    tv[day] = tv.get(day, 0) + int(r['tickvol'])
                except (ValueError, TypeError):
                    pass
        d = DAY_LO
        while d <= DAY_HI:
            st = est.get(sym, 'UNKNOWN')
            rows.append({
                'symbol': sym,
                'export_status': st,
                'count_evidence': 'USABLE' if st == 'COMPLETE' else 'UNJUDGEABLE',
                'date': str(d),
                'weekday': d.strftime('%a'),
                'm1_bars': bars.get(d, 0),
                'tickvol_sum': tv.get(d, 0),
                'inside_gap': GAP_START <= d <= GAP_END,
            })
            d += dt.timedelta(days=1)
    if rows:
        with open(OUT_DAILY, 'w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
    return rows


def main():
    est = export_status()
    if not est:
        print('WARNING: export-completeness CSV not readable at',
              COMPLETENESS_CSV, '- all symbols will be UNKNOWN/UNJUDGEABLE')

    ch = do_chunks(est)
    if not ch:
        print('NO CHUNK JOURNAL FOUND under', RAW, '- F7 chunk leg unavailable')
    else:
        usable = [r for r in ch if r['count_evidence'] == 'USABLE']
        zero = [r for r in usable if r['status'] == 'ZERO_TICK_CHUNK']
        print(f'chunk journal: {len(ch)} settled chunks over '
              f'{len(set(r["symbol"] for r in ch))} symbols in '
              f'{CH_LO.date()}..{CH_HI.date()}; '
              f'{len(usable)} chunks on export-COMPLETE symbols '
              f'({len(set(r["symbol"] for r in usable))} symbols)')
        print(f'  ZERO_TICK_CHUNK on export-COMPLETE symbols: {len(zero)} rows'
              f' over {len(set(r["symbol"] for r in zero))} symbols')
        wins = sorted(set((r['chunk_start_utc'], r['chunk_end_utc']) for r in zero))
        for w in wins:
            n = sum(1 for r in zero if (r['chunk_start_utc'], r['chunk_end_utc']) == w)
            print(f'    {w[0]} .. {w[1]}  ZERO on {n} export-COMPLETE symbols')
        print('  wrote', OUT_CHUNKS)

    da = do_daily(est)
    if not da:
        print('NO M1 EXPORT FOUND under', M1, '- F7 daily leg unavailable')
        return

    syms = sorted(set(r['symbol'] for r in da))
    summary = []
    for s in syms:
        rr = [r for r in da if r['symbol'] == s]
        gap_wd = [r for r in rr if r['inside_gap'] and r['weekday'] not in ('Sat', 'Sun')]
        ctl_wd = [r for r in rr if not r['inside_gap'] and r['weekday'] not in ('Sat', 'Sun')]
        gb = sum(r['m1_bars'] for r in gap_wd)
        gt = sum(r['tickvol_sum'] for r in gap_wd)
        z = sum(1 for r in gap_wd if r['m1_bars'] == 0)
        med = sorted(r['m1_bars'] for r in ctl_wd)
        med = med[len(med) // 2] if med else 0
        exp = med * len(gap_wd)
        chz = sum(1 for r in ch
                  if r['symbol'] == s and r['status'] == 'ZERO_TICK_CHUNK'
                  and r['intersects_gap'])
        summary.append({
            'symbol': s,
            'export_status': rr[0]['export_status'],
            'count_evidence': rr[0]['count_evidence'],
            'gap_weekdays': len(gap_wd),
            'gap_weekdays_with_zero_bars': z,
            'gap_weekday_m1_bars': gb,
            'gap_weekday_tickvol': gt,
            'control_weekday_median_bars': med,
            'expected_gap_weekday_bars_at_control_rate': exp,
            'gap_bar_shortfall_pct': (round(100.0 * (1 - gb / exp), 2)
                                      if exp else ''),
            'zero_tick_chunks_intersecting_gap': chz,
        })
    with open(OUT_SUM, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(summary[0].keys()))
        w.writeheader()
        w.writerows(summary)

    print(f'daily bar counts: {len(syms)} symbols x '
          f'{(DAY_HI - DAY_LO).days + 1} days')
    print(f'{"symbol":14s} {"expst":11s} {"gapWDbars":>10s} {"zeroWD":>8s} '
          f'{"ctrlMed":>8s} {"shortfall%":>10s} {"zeroChunks":>10s}')
    for r in summary:
        print(f'{r["symbol"]:14s} {r["export_status"]:11s} '
              f'{r["gap_weekday_m1_bars"]:10d} '
              f'{r["gap_weekdays_with_zero_bars"]:>3d}/{r["gap_weekdays"]:<4d} '
              f'{r["control_weekday_median_bars"]:8d} '
              f'{str(r["gap_bar_shortfall_pct"]):>10s} '
              f'{r["zero_tick_chunks_intersecting_gap"]:10d}')
    usable = [r for r in summary if r['count_evidence'] == 'USABLE']
    fxlike = [r for r in usable if r['gap_bar_shortfall_pct'] != '' and
              r['gap_bar_shortfall_pct'] > 50]
    print(f'\nexport-COMPLETE symbols: {len(usable)}; of those, '
          f'{len(fxlike)} lost >50% of their expected gap-window weekday M1 bars')
    print('  wrote', OUT_DAILY)
    print('  wrote', OUT_SUM)


if __name__ == '__main__':
    sys.exit(main())
