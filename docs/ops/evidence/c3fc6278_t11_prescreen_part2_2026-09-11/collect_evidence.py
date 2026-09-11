"""Task-bound read-only evidence collector. No terminal launch or DB writes."""
from __future__ import annotations
import csv
import hashlib
import json
import math
import sqlite3
import statistics
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = Path('C:/QM/repo')
TASK = 'c3fc6278-7c6f-4871-b311-59b8650d4961'
BASE = REPO / 'docs/ops/evidence/b48ba1fb_t11_prescreen_2026-09-10/real_tick_vs_cheap_cells.csv'
RESEARCH = Path('D:/QM/reports/research/T11_PRESCREEN_PART2_c3fc6278')

def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def save(name, obj):
    with (ROOT / name).open('x', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, indent=2, ensure_ascii=False)
        f.write('\n')

def table(name, rows):
    with (ROOT / name).open('x', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)

def freeze():
    rows = list(csv.DictReader(BASE.open(encoding='utf-8-sig')))
    assert len(rows) == 345 and len({r['cell_key'] for r in rows}) == 345
    errors = []
    for row in rows:
        for key in ('summary', 'report', 'tester_ini', 'setfile'):
            path = row[key + '_path']
            if not Path(path).is_file() or sha(path) != row[key + '_sha256']:
                errors.append({'cell_key': row['cell_key'], 'kind': key, 'path': path})
    table('frozen_ground_truth.csv', rows)
    programs = sorted({r['program_id'] for r in rows})
    speed = []
    # Select without looking at results: two windows per year and six pattern
    # arms, deterministic SHA-256 order over the fixed cell identity.
    for year in range(2019, 2026):
        candidates = [r for r in rows if r['program_id'].startswith('WINSWEEP') and int(r['year']) == year]
        speed.extend(sorted(candidates, key=lambda r: hashlib.sha256(r['cell_key'].encode()).hexdigest())[:2])
    speed.extend(sorted((r for r in rows if r['program_id'].startswith('DL089')),
                        key=lambda r: hashlib.sha256(r['cell_key'].encode()).hexdigest())[:6])
    table('speed_pilot_20_cells.csv', speed)
    db = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA query_only=ON')
    save('assigned_task.json', dict(db.execute('SELECT * FROM agent_tasks WHERE id=?', (TASK,)).fetchone()))
    save('spawn_lease.json', [dict(r) for r in db.execute('SELECT * FROM spawn_leases WHERE task_key=?', ('agent_task:' + TASK,))])
    census = [dict(r) for r in db.execute("SELECT json_extract(payload_json,'$.program_id') program_id,status,verdict,count(*) n FROM work_items WHERE phase='OPT_CENSUS' GROUP BY 1,2,3")]
    save('census_backlog_snapshot.json', {'captured_at': datetime.now(timezone.utc).isoformat(), 'rows': census,
        'pending_all_programs': sum(r['n'] for r in census if r['status'] == 'pending'),
        'pending_target_programs': sum(r['n'] for r in census if r['status'] == 'pending' and r['program_id'] in programs),
        'limit': 'Raw pending rows; holds and program eligibility are not inferred away.'})
    queue = [dict(r) for r in db.execute("SELECT id,status,phase,symbol,verdict,claimed_by,updated_at FROM work_items WHERE ea_id='QM5_10260'")]
    save('qm5_10260_queue.json', {'captured_at': datetime.now(timezone.utc).isoformat(),
        'counts': dict(Counter(r['status'] for r in queue)),
        'open_rows': [r for r in queue if r['status'] in ('pending','active')]})
    db.close()
    save('ground_truth_verification.json', {'baseline_path': str(BASE), 'baseline_sha256': sha(BASE),
        'cells': len(rows), 'counts': dict(Counter(r['program_id'] for r in rows)),
        'hash_checks': len(rows) * 4, 'errors': errors,
        'selection_rule': '2 WINSWEEP cells/year + 6 DL089 cells sorted by SHA256(cell_key)',
        'note': 'The first admission pilot is the already staged identity cell; it is additional to the frozen matrix.'})
    assert not errors, errors

def results():
    rows = list(csv.DictReader((ROOT / 'frozen_ground_truth.csv').open(encoding='utf-8')))
    receipts = []
    for path in sorted(RESEARCH.glob('*/receipt.json')):
        r = json.loads(path.read_text())
        receipts.append({'receipt_path': str(path), 'receipt_sha256': sha(path),
            'status': r['status'], 'model': r['model'], 'optimize': r['optimize'],
            'report_path': r.get('report',{}).get('path',''),
            'reason': r.get('reason',''), 'wall_seconds': r.get('wall_seconds'),
            'tester_wall_seconds': r.get('tester_wall_seconds'),
            'isolation_unchanged': r.get('isolation_unchanged'),
            'resource_guard': r.get('resource_guard'),
            'refusal_observation': r.get('refusal_observation')})
    save('research_receipts.json', receipts)
    # This collector deliberately cannot substitute a native run for a missing
    # paired matrix; successful pilot reports are handed back for review.
    speed = []
    fidelity = []
    for program in sorted({r['program_id'] for r in rows}):
        cohort = [r for r in rows if r['program_id'] == program]
        for model, name in [(4,'real-ticks'),(1,'ohlc-m1'),(0,'generated-ticks'),(2,'open-prices')]:
            speed.append({'program_id': program, 'model':model, 'mode':name,
                'frozen_real_cells':len(cohort), 'matched_matrix_cells':0,
                'historical_real_median_seconds':statistics.median(float(r['receipt_elapsed_seconds']) for r in cohort) if model==4 else '',
                't11_matrix_median_seconds':'', 'speedup':'', 'status':'NICHT GEZEIGT',
                'source':'frozen_ground_truth.csv; research_receipts.json'})
            if model == 4:
                continue
            for scope in [str(y) for y in range(2019,2026)] + ['pooled']:
                fidelity.append({'program_id':program,'model':model,'mode':name,'scope':scope,
                    'real_cells':sum(scope=='pooled' or r['year']==scope for r in cohort),
                    'matched_cells':0,'spearman_net':'','spearman_costed_score':'',
                    'plateau_top5_overlap':'','plateau_top10_overlap':'','sign_agreement':'',
                    'false_negative_top50pct':'','false_negative_top30pct':'','status':'NICHT GEZEIGT'})
    table('speed_matrix.csv', speed)
    table('fidelity_matrix.csv', fidelity)
    backlog = json.loads((ROOT/'census_backlog_snapshot.json').read_text())
    scenarios = []
    for population in ['pending_all_programs','pending_target_programs']:
        n = backlog[population]
        for retain in [0.5,0.3]:
            kept = math.ceil(n * retain)
            control = math.ceil((n-kept)*0.1)
            scenarios.append({'population':population,'pending_rows':n,'retain_fraction':retain,
                'dropped_control_fraction':0.1,'kept':kept,'controls':control,
                'real_tick_confirmations':kept+control,'fewer_real_tick_cells':n-kept-control,
                'cheap_run_seconds':'','net_saved_seconds':'','status':'CONDITIONAL_COUNTS_ONLY'})
    table('backlog_scenarios.csv', scenarios)

if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('action', choices=['freeze','results'])
    args=parser.parse_args()
    freeze() if args.action=='freeze' else results()
