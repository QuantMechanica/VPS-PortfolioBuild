#!/usr/bin/env python3
"""F2: re-run cost estimate from MEASURED runtimes, not guesses.

READ-ONLY (farm_state.sqlite opened mode=ro). Nothing written outside this dir.

`work_items` has no duration column (verified via `.schema work_items`; columns
are id/kind/phase/ea_id/symbol/setfile_path/status/verdict/attempt_count/
parent_task_id/evidence_path/claimed_by/payload_json/created_at/updated_at/...).
The measurable wall-clock of an executed cell is therefore

    updated_at (terminal state written)  -  payload_json.claimed_at_iso (worker
                                            claimed the cell and started work)

`created_at` is enqueue time and includes arbitrary queue wait, so it is NOT
used. Rows without `claimed_at_iso`, with non-positive duration, or longer than
3 days (worker-crash/reclaim artefacts) are dropped and counted as excluded.
Rows whose verdict starts with SKIPPED_ are excluded from the runtime sample
too: they never ran a backtest, so they would deflate the median.

Parallelism is measured, not assumed: an interval-overlap sweep over the last
7 days of completed cells gives the observed peak and time-weighted mean number
of concurrently running cells.

The re-run cost of the Q3 impact set is then priced row by row: each row is
charged its own phase's measured median (and p75 as an upper bound), summed to
terminal-seconds, then divided by the measured concurrency to get wall-clock.

NOTE on `framework/registry/tester_defaults.json`: its
`p2_real_tick_policy.full_run.timeout_seconds_min/max` = 7200/14400 is a
TIMEOUT CEILING ("sized from the six-month pre-screen runtime with headroom
multipliers"), not an expected runtime. The measured Q02 median below is two
orders of magnitude under that ceiling, which is what a headroom-sized timeout
is supposed to look like. Neither the ceiling nor the previous write-up's
"~10 cells/h/slot" guess is used here.

Outputs: f2_phase_runtime_medians.csv and f2_rerun_cost_estimate.csv (same
directory) + stdout cost table.
"""
import csv
import datetime as dt
import os
import sqlite3
import statistics
from collections import Counter

DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_CSV = os.path.join(HERE, 'f2_phase_runtime_medians.csv')
OUT_COST = os.path.join(HERE, 'f2_rerun_cost_estimate.csv')
Q3_CSV = os.path.join(HERE, 'q3_affected_work_items.csv')
MAX_SANE_SECONDS = 3 * 86400
CONCURRENCY_WINDOW_DAYS = 7


def P(s):
    d = dt.datetime.fromisoformat(str(s).replace('Z', '+00:00'))
    return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)


def collect():
    con = sqlite3.connect(DB, uri=True)
    con.row_factory = sqlite3.Row
    samples = {}
    intervals = []
    excluded = {'no_claimed_at': 0, 'unparseable': 0, 'nonpositive': 0,
                'over_3d': 0, 'skipped_verdict': 0}
    cur = con.execute(
        "SELECT phase, verdict, updated_at, "
        "json_extract(payload_json,'$.claimed_at_iso') AS claimed, "
        "json_extract(payload_json,'$.terminal') AS terminal "
        "FROM work_items WHERE status='done'")
    for r in cur:
        if not r['claimed']:
            excluded['no_claimed_at'] += 1
            continue
        try:
            a, b = P(r['claimed']), P(r['updated_at'])
        except (ValueError, TypeError):
            excluded['unparseable'] += 1
            continue
        sec = (b - a).total_seconds()
        if sec <= 0:
            excluded['nonpositive'] += 1
            continue
        if sec > MAX_SANE_SECONDS:
            excluded['over_3d'] += 1
            continue
        intervals.append((a, b, r['terminal']))
        if (r['verdict'] or '').startswith('SKIPPED'):
            excluded['skipped_verdict'] += 1
            continue
        samples.setdefault(r['phase'], []).append(sec)
    con.close()
    return samples, intervals, excluded


def concurrency(intervals):
    if not intervals:
        return 0, 0.0, []
    end = max(b for _, b, _ in intervals)
    cut = end - dt.timedelta(days=CONCURRENCY_WINDOW_DAYS)
    iv = [x for x in intervals if x[0] >= cut]
    ev = []
    for a, b, _ in iv:
        ev.append((a, 1))
        ev.append((b, -1))
    ev.sort()
    cur = peak = 0
    prev = None
    area = 0.0
    for ts, d in ev:
        if prev is not None:
            area += cur * (ts - prev).total_seconds()
        cur += d
        peak = max(peak, cur)
        prev = ts
    span = (ev[-1][0] - ev[0][0]).total_seconds()
    terms = sorted(set(t for _, _, t in iv if t))
    return peak, (area / span if span else 0.0), terms


def main():
    samples, intervals, excluded = collect()
    peak, avg, terms = concurrency(intervals)

    rows = []
    for ph in sorted(samples, key=lambda k: -len(samples[k])):
        v = sorted(samples[ph])
        n = len(v)
        rows.append({
            'phase': ph,
            'n_measured_runs': n,
            'p25_seconds': round(v[n // 4]),
            'median_seconds': round(statistics.median(v)),
            'p75_seconds': round(v[(3 * n) // 4]),
            'p95_seconds': round(v[min(n - 1, int(n * 0.95))]),
            'max_seconds': round(v[-1]),
        })
    with open(OUT_CSV, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    print('excluded from runtime sample:', excluded)
    print(f'measured parallelism over last {CONCURRENCY_WINDOW_DAYS}d: '
          f'peak={peak} concurrent cells, time-weighted mean={avg:.2f}; '
          f'terminals seen={terms}')
    print()
    print(f'{"phase":16s} {"n":>7s} {"p25":>8s} {"median":>8s} {"p75":>8s} '
          f'{"p95":>9s}')
    for r in rows:
        print(f'{r["phase"]:16s} {r["n_measured_runs"]:7d} '
              f'{r["p25_seconds"]:8d} {r["median_seconds"]:8d} '
              f'{r["p75_seconds"]:8d} {r["p95_seconds"]:9d}')
    print('wrote', OUT_CSV)

    by_phase = {r['phase']: r for r in rows}
    price_impact_set(by_phase, peak, avg)
    return by_phase, peak, avg


PASS_LIKE = {'PASS', 'PASS_SOFT', 'PASS_LOWFREQ'}


def price_impact_set(by_phase, peak, avg):
    """Charge each Q3 impact-set row its own phase's measured runtime."""
    if not os.path.isfile(Q3_CSV):
        print('\n(no', os.path.basename(Q3_CSV),
              '- run q3_affected_work_items.py first to price the impact set)')
        return
    with open(Q3_CSV, 'r', encoding='utf-8', newline='') as fh:
        q3 = list(csv.DictReader(fh))

    impact = [r for r in q3
              if r['cohort_exposure_at_0_50'] == 'EXPOSED'
              and r['evidence_relevance'] == 'verdict-relevant']
    scopes = [
        ('A_all_exposed_executed', impact),
        ('B_pipeline_gates_only', [r for r in impact
                                   if r['phase'] not in ('OPT_CENSUS', 'P2')]),
        ('C_pass_like_gates_only', [r for r in impact
                                    if r['phase'] not in ('OPT_CENSUS', 'P2')
                                    and r['verdict'] in PASS_LIKE]),
    ]

    out = []
    print()
    print('RE-RUN COST, priced from measured per-phase runtimes')
    print(f'(parallelism: measured peak={peak} concurrent cells, '
          f'time-weighted mean={avg:.2f} over the last '
          f'{CONCURRENCY_WINDOW_DAYS}d, 10 factory terminals T1-T10)')
    print(f'{"scope":26s} {"rows":>6s} {"unpriced":>9s} {"term-h@p50":>11s} '
          f'{"term-h@p75":>11s} {"wall-h@mean":>12s} {"wall-h@peak":>12s}')
    for name, rows in scopes:
        sec50 = sec75 = 0.0
        unpriced = 0
        per_phase = Counter()
        for r in rows:
            ph = by_phase.get(r['phase'])
            if not ph:
                unpriced += 1
                continue
            sec50 += ph['median_seconds']
            sec75 += ph['p75_seconds']
            per_phase[r['phase']] += 1
        th50, th75 = sec50 / 3600.0, sec75 / 3600.0
        rec = {
            'scope': name,
            'rows': len(rows),
            'rows_unpriced_no_phase_sample': unpriced,
            'terminal_hours_at_phase_median': round(th50, 1),
            'terminal_hours_at_phase_p75': round(th75, 1),
            'wallclock_hours_at_measured_mean_concurrency': (
                round(th50 / avg, 1) if avg else ''),
            'wallclock_hours_at_measured_peak_concurrency': (
                round(th50 / peak, 1) if peak else ''),
            'phase_mix': ';'.join(f'{k}={v}' for k, v in sorted(per_phase.items())),
        }
        out.append(rec)
        print(f'{name:26s} {rec["rows"]:6d} {unpriced:9d} '
              f'{rec["terminal_hours_at_phase_median"]:11.1f} '
              f'{rec["terminal_hours_at_phase_p75"]:11.1f} '
              f'{rec["wallclock_hours_at_measured_mean_concurrency"]:12} '
              f'{rec["wallclock_hours_at_measured_peak_concurrency"]:12}')
        print(f'{"":26s} mix: {rec["phase_mix"]}')

    with open(OUT_COST, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0].keys()))
        w.writeheader()
        w.writerows(out)
    print('wrote', OUT_COST)


if __name__ == '__main__':
    main()
