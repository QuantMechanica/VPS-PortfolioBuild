"""Read-only inventory/recomputation. Output directory must be new and canonical."""
import argparse
import collections
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import sqlite3
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--implementation-root', type=Path, required=True)
parser.add_argument('--out-dir', type=Path, required=True)
args = parser.parse_args()
evidence = Path('C:/QM/repo/docs/ops/evidence').resolve()
out = args.out_dir.resolve()
assert out.is_relative_to(evidence) and not out.exists(), 'Append-only canonical evidence directory required'
sys.path[:0] = [str(args.implementation_root), str(args.implementation_root/'framework/scripts'),
               str(args.implementation_root/'tools/strategy_farm')]
from q08_davey import dsr_v2 as v2, aggregate as q08, common
import evidence_status

c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
c.row_factory = sqlite3.Row
c.execute('PRAGMA query_only=ON')
c.execute('BEGIN')
snapshot = dt.datetime.now(dt.UTC).isoformat()
all_rows = {r['id']: dict(r) for r in c.execute('SELECT * FROM work_items')}
recent = [dict(r) for r in c.execute("SELECT * FROM work_items WHERE phase='Q08' AND verdict='PASS' ORDER BY updated_at DESC,id DESC LIMIT 28")]
frontier = [dict(r) for r in c.execute("SELECT * FROM (SELECT *,row_number() OVER (PARTITION BY ea_id,symbol ORDER BY updated_at DESC,id DESC) rn FROM work_items WHERE phase='Q11') WHERE rn=1 AND verdict='PASS' ORDER BY ea_id,symbol")]
c.rollback(); c.close()


def q08_ancestor(row):
    seen = set()
    current = row
    while current and current['id'] not in seen:
        if current['phase'] == 'Q08':
            return current, 'promoted_from_work_item_chain'
        seen.add(current['id'])
        payload = json.loads(current.get('payload_json') or '{}')
        current = all_rows.get(payload.get('promoted_from_work_item'))
    options = [r for r in all_rows.values() if r['phase'] == 'Q08' and r['ea_id'] == row['ea_id']
               and r['symbol'] == row['symbol'] and r['updated_at'] <= row['updated_at'] and r['verdict'] == 'PASS']
    return (max(options, key=lambda r: (r['updated_at'], r['id'])) if options else None,
            'latest_prior_pass_association_NOT_lineage_proof')


def inspect(row, source, association):
    result = {'work_item_id': row['id'], 'ea_id': row['ea_id'], 'symbol': row['symbol'],
              'recorded_phase': row['phase'], 'recorded_verdict': row['verdict'],
              'q08_association': association, 'q08_work_item_id': source['id'] if source else None,
              'v2_classification': 'UNCORRECTED_SELECTION', 'v2_dsr_p': None,
              'reason': 'No hash-bound complete search history and loser-inclusive cohort supplied.',
              'numeric_recompute_status': 'UNAVAILABLE'}
    if not source:
        result['legacy_dsr'] = 'Q08_EVIDENCE_MISSING'
        return result
    path = Path(source['evidence_path'] or '')
    try:
        raw = path.read_bytes()
        a = json.loads(raw.decode('utf-8-sig'))
        result.update(aggregate_path=str(path), aggregate_sha256=hashlib.sha256(raw).hexdigest())
        old = next((g for g in a.get('sub_gates', []) if str(g.get('name','')).startswith('8.2')), {})
        result.update(legacy_dsr=old.get('status', 'UNAVAILABLE'), legacy_detail=old.get('detail'),
                      legacy_dsr_p=old.get('value'), legacy_dsr_evidence=old.get('evidence'),
                      legacy_n_trades=a.get('n_trades'))
        result['projection'] = evidence_status.project(path)
        payload = json.loads(source.get('payload_json') or '{}')
        binding = payload.get('dsr_context')
        if binding:
            result['supplied_dsr_context'] = binding
        baseline = a.get('baseline_run') or {}
        stream = a.get('portfolio_stream') or {}
        essential = {x['label']: x for x in result['projection']['bindings']}
        if any(essential[k]['status'] != 'current' for k in ('summary', 'stream', 'report')):
            result['numeric_recompute_status'] = 'BOUND_STREAM_SUMMARY_OR_REPORT_UNAVAILABLE'
            return result
        summary = json.loads(Path(baseline['baseline_summary_path']).read_text(encoding='utf-8-sig'))
        window = summary.get('test_window') or {}
        start, end = (window.get(k) or summary.get(k) for k in ('from_date', 'to_date'))
        if not start or not end or window.get('source') != 'generated_tester_ini':
            result['numeric_recompute_status'] = 'SEALED_WINDOW_UNAVAILABLE'
            return result
        start, end = start.replace('.', '-'), end.replace('.', '-')
        stream_path = Path(stream.get('durable_path') or stream.get('path'))
        trades = common.load_trades_from_log(stream_path)
        adjusted, costs = q08._apply_worst_case_commission(trades, row['symbol'])
        result['cost_replay'] = {k: costs[k] for k in ('commission_total', 'gross_total', 'commission_model')}
        if any(not math.isclose(float(costs[k]), float(a[k]), abs_tol=1e-5, rel_tol=1e-9)
               for k in ('commission_total', 'gross_total')):
            result['numeric_recompute_status'] = 'FROZEN_COST_TOTALS_NOT_REPRODUCED'
            return result
        # Cash scale does not affect SR/skew/kurtosis. This is a diagnostic,
        # not an attestation of legacy epoch/timezone semantics or daily MTM.
        values, active = v2.daily_series(adjusted, start, end, timezone='UTC', initial_balance=1)
        stats = v2.moments(values)
        result.update(numeric_recompute_status='DIAGNOSTIC_CALENDAR_STATS_ONLY',
                      calendar_stats={**stats, 'active_trading_days': active},
                      calendar_window={'from': start, 'to': end},
                      assumptions=['Legacy epoch interpreted as UTC for diagnostic only.',
                                   'Realized daily cash PnL; not mark-to-market; scale=1 cancels in Sharpe.',
                                   'Current cost replay matches frozen aggregate totals; original model is not hash-sealed.'])
        if binding:
            result['v2_result'] = v2.evaluate(adjusted, binding=binding, ea_id=a['ea_id'], symbol=a['symbol'])
            result['v2_classification'] = result['v2_result']['evidence'].get('statistical_status','uncorrected_selection').upper()
            result['v2_dsr_p'] = result['v2_result']['evidence'].get('dsr_p')
    except (OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        result['numeric_recompute_status'] = 'UNAVAILABLE:' + str(exc)
    return result


groups = {'current_q11_pass_pairs': [inspect(r, *q08_ancestor(r)) for r in frontier],
          'latest_28_q08_pass_artifacts': [inspect(r, r, 'same_work_item') for r in recent]}
report = {'schema': 'qm.dsr-v2-readonly-recompute/v1', 'snapshot_utc': snapshot,
          'query_only': True, 'stored_verdicts_modified': False, 'dsr_v2_activated': False,
          'implementation_root': str(args.implementation_root), 'groups': groups}
report['counts'] = {name: {'rows': len(rows), 'legacy_statuses': dict(collections.Counter(r.get('legacy_dsr') for r in rows)),
                'deferred': sum('deferred' in str(r.get('legacy_detail','')).lower() for r in rows),
                'v2': dict(collections.Counter(r['v2_classification'] for r in rows)),
                'numeric': dict(collections.Counter(r['numeric_recompute_status'] for r in rows))}
                   for name, rows in groups.items()}
out.mkdir(parents=True)
(out/'recompute.json').write_text(json.dumps(report, indent=2, allow_nan=False)+'\n', encoding='utf-8')
lines = ['# Read-only DSR before/after', '', 'Snapshot: '+snapshot+'. Existing verdicts retained.', '']
for group, rows in groups.items():
    lines += ['## '+group, '', '| EA / symbol | Q08 evidence | Before DSR | Calendar / active days | After V2 | Numeric evidence |',
              '|---|---|---|---:|---|---|']
    for r in rows:
        stats = r.get('calendar_stats', {})
        days = str(stats.get('n_calendar_days','—'))+' / '+str(stats.get('active_trading_days','—'))
        old = r.get('legacy_dsr','UNAVAILABLE') + (' deferred' if 'deferred' in str(r.get('legacy_detail','')).lower() else '')
        lines.append(f"| {r['ea_id']} / {r['symbol']} | {str(r['q08_work_item_id'])[:8]} | {old} | {days} | {r['v2_classification']} | {r['numeric_recompute_status']} |")
    lines.append('')
(out/'before_after.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print(json.dumps({'output': str(out), 'snapshot': snapshot, 'counts': report['counts']}, indent=2))
