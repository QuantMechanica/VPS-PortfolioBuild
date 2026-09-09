"""Read-only lineage audit; writes one new evidence file, no factory mutations."""
import argparse
from collections import Counter
import dataclasses
import datetime as dt
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import sqlite3

from tools.strategy_farm.portfolio.ftmo_report_cost_reconcile import extract_round_trips
from tools.strategy_farm import opt_census_pruning

REPO = Path('C:/QM/repo')
FARM = Path('D:/QM/strategy_farm')
OLD_PROGRAM = 'DL089_QM5_41097_USDJPY_DWX_2019_2025'
NEW_PROGRAM = 'DL089_QM5_13213_USDJPY_DWX_2019_2025'


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def assignments(text):
    result = {}
    for line in text.splitlines():
        match = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$', line)
        if match:
            result.setdefault(match[1], []).append(match[2].split('||', 1)[0].strip())
    return result


def equivalent(left, right, input_type=''):
    left, right = str(left).strip(), str(right).strip()
    if input_type == 'string':
        return left == right
    if input_type == 'bool':
        left = {'true': '1', 'false': '0'}.get(left.lower(), left)
        right = {'true': '1', 'false': '0'}.get(right.lower(), right)
    try:
        return Decimal(left) == Decimal(right)
    except InvalidOperation:
        return left == right


def compare_defaults(card_info, actual):
    findings = []
    for key, expected in card_info.get('card_defaults', {}).items():
        values = actual.get(key, [])
        source = card_info.get('input_defaults', {}).get(key)
        typ = card_info.get('input_types', {}).get(key, '')
        if len(values) > 1:
            state = 'DUPLICATE_ASSIGNMENT'
        elif values:
            state = 'EXPLICIT_MATCH' if equivalent(values[0], expected, typ) else 'EXPLICIT_CURRENT_CARD_DIFFERENCE'
        elif source is None:
            state = 'MISSING_UNKNOWN_DEFAULT'
        elif equivalent(source, expected, typ):
            state = 'OMITTED_CURRENT_SOURCE_MATCH'
        else:
            state = 'OMITTED_CURRENT_SOURCE_DIFFERS'
        findings.append({'input': key, 'card_value': expected, 'set_values': values,
                         'current_source_value': source, 'classification': state})
    return findings


def activity_from_summary(path):
    summary = read_json(path)
    run = summary['runs'][0]
    report = Path(run['report_canonical_path'])
    assert sha(report) == run['report_sha256'], str(report)
    # Use the read-only native parser, not cell_report's sidecar-writing cache.
    trips, _ = extract_round_trips(report, summary['symbol']) if run['total_trades'] else ([], {})
    return {'summary_path': str(path), 'summary_sha256': sha(path), 'report_sha256': sha(report),
            'entry_days': len({t.entry_time.date() for t in trips}), 'trades': len(trips),
            'sides': dict(Counter(t.side for t in trips))}


def work_summary(db, wid):
    row = dict(db.execute('SELECT * FROM work_items WHERE id=?', (wid,)).fetchone())
    payload = json.loads(row.pop('payload_json') or '{}')
    evidence = read_json(row['evidence_path']) if row['evidence_path'] else None
    result = {k: row[k] for k in ('id', 'phase', 'ea_id', 'status', 'verdict', 'evidence_path', 'updated_at')}
    result.update({'claimed_at': payload.get('claimed_at_iso'), 'started_at': payload.get('started_at_iso')})
    if result['started_at']:
        result['runner_to_verdict_seconds'] = (dt.datetime.fromisoformat(row['updated_at']) - dt.datetime.fromisoformat(result['started_at'])).total_seconds()
    if result['claimed_at']:
        result['claim_to_verdict_seconds'] = (dt.datetime.fromisoformat(row['updated_at']) - dt.datetime.fromisoformat(result['claimed_at'])).total_seconds()
    if evidence:
        result['evidence_sha256'] = sha(row['evidence_path'])
        result['window'] = {k: evidence['test_window'][k] for k in ('from_date', 'to_date')}
        result['metrics'] = [{k: r.get(k) for k in ('net_profit', 'profit_factor', 'drawdown', 'total_trades')} for r in evidence['runs']]
        result['report_path'] = evidence['runs'][0]['report_canonical_path']
        result['report_sha256'] = sha(result['report_path'])
        result['report_hash_matches_summary'] = result['report_sha256'] == evidence['runs'][0]['report_sha256']
    return result


def snapshot():
    prior = read_json(REPO/'docs/ops/evidence/2026-09-09_pattern_filter_repair_final.json')
    cohort = read_json(REPO/'docs/ops/evidence/2026-09-09_candidates_pattern_balke.json')
    cards_path = Path('D:/QM/reports/pattern_permission_repair/current_card_defaults_20260909.json')
    cards = read_json(cards_path)
    by_id = {x['ea_id']: x for x in cards['rows']}
    cohort_keys = {(r['ea_id'], r['symbol']) for r in cohort['qualified']}
    program_names = sorted({r['program_id'] for r in prior['programs']} | {NEW_PROGRAM})
    result = {'schema': 'qm.pattern-lineage-analysis/v1', 'created_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'database_read_only': True, 'factory_mutations': 0,
              'current_card_evidence': str(cards_path), 'current_card_evidence_sha256': sha(cards_path),
              'cohort_definition': 'Frozen 16 pairs from 2026-09-09 04:29Z audit, not a refreshed qualification verdict',
              'programs': [], 'limits': ['SQLite transaction is consistent; external artifacts are read separately with hashes and drift flags.',
              'Current card/source differences are exposure flags, not proven historical default defects.',
              'SKIPPED_EXCLUDED is kept distinct from retired B2/B5 prescreen; no verdict is rewritten.',
              'Parser labels broker report timestamps UTC internally; parity compares identical raw clock labels, not verified UTC conversion.']}
    with sqlite3.connect((FARM/'state/farm_state.sqlite').as_uri()+'?mode=ro', uri=True, timeout=15) as db:
        db.row_factory = sqlite3.Row
        db.execute('BEGIN')
        work = {r['id']: dict(r) for r in db.execute("SELECT id,status,verdict,setfile_path,setfile_sha256,mq5_sha256,ex5_sha256,evidence_path FROM work_items WHERE phase='OPT_CENSUS'")}
        holds = {r['work_item_id']: r['hold_code'] for r in db.execute('SELECT work_item_id,hold_code FROM work_item_holds WHERE active=1')}
        for name in program_names:
            lp = FARM/'artifacts/opt_census'/name/'ledger.json'
            raw = lp.read_bytes(); ledger = json.loads(raw)
            owner = db.execute('SELECT id,ea_id,status,verdict,evidence_path FROM work_items WHERE id=?', (ledger['q12_work_item_id'],)).fetchone()
            counts, patterns, measured_years = Counter(), Counter(), Counter()
            prune_sample, baseline_2019 = None, None
            bad_hashes, missing_sets, n, bound_hash_count = [], [], 0, 0
            for cell in ledger['cells']:
                w = work.get(cell['work_item_id']); state = 'NOT_MATERIALIZED' if not w else w['verdict'] or w['status']
                if holds.get(cell['work_item_id']) == 'PRESCREEN_SKIPPED':
                    state = 'PRESCREEN_HELD_UNMEASURED'
                counts[state] += 1
                if cell.get('predicate_id') in (33, 34): patterns[state] += 1
                if state == 'MEASURED': measured_years[str(cell['year'])] += 1
                if state == 'SKIPPED_EXCLUDED' and prune_sample is None and w and w['evidence_path']:
                    try:
                        receipt = opt_census_pruning.validate_receipt(Path(w['evidence_path']), expected_cell_key=cell['cell_key'])
                        trigger = work.get(receipt['trigger_work_item_id'])
                        activity = activity_from_summary(trigger['evidence_path']) if trigger else None
                        prune_sample = {'cell_id': w['id'], 'receipt_path': w['evidence_path'], 'receipt_sha256': sha(w['evidence_path']),
                                        'structural_validation': 'PASS', 'trigger_work_item_id': receipt['trigger_work_item_id'],
                                        'trigger_days_declared': receipt['trigger_entry_trading_days'], 'trigger_native_activity': activity,
                                        'trigger_days_equal': activity is not None and activity['entry_days'] == receipt['trigger_entry_trading_days']}
                    except (OSError, ValueError, KeyError, AssertionError) as exc:
                        prune_sample = {'cell_id': w['id'], 'error': str(exc)}
                if cell.get('arm') == 'baseline' and cell['year'] == 2019 and state == 'MEASURED' and (owner['ea_id'], ledger['symbol']) in cohort_keys:
                    try: baseline_2019 = activity_from_summary(w['evidence_path'])
                    except (OSError, ValueError, KeyError, AssertionError) as exc: baseline_2019 = {'error': str(exc)}
                # Bind only the seven neutral controls here; do not scan 30k setfiles.
                if cell.get('arm') == 'baseline' and w:
                    bp = Path(w['setfile_path']); n += 1
                    if w['setfile_sha256']: bound_hash_count += 1
                    if not bp.is_file(): missing_sets.append(w['id'])
                    elif w['setfile_sha256'] and sha(bp) != w['setfile_sha256']: bad_hashes.append(w['id'])
            base = Path(ledger['base_setfile_path'])
            base_exists = base.is_file()
            vals = assignments(base.read_text(encoding='utf-8-sig')) if base_exists else {}
            info = by_id.get(ledger['ea_id'], {})
            checks = compare_defaults(info, vals)
            parent = by_id.get(owner['ea_id'], {})
            inherited = dict(info)
            inherited['card_defaults'] = {k: v for k, v in parent.get('card_defaults', {}).items() if k in info.get('input_defaults', {})}
            parent_checks = compare_defaults(inherited, vals)
            qp = Path(owner['evidence_path']) if owner['evidence_path'] else None
            qr = read_json(qp) if qp and qp.is_file() else {}
            stability = qr.get('stability', {})
            entry = {'program_id': name, 'subject_ea_id': owner['ea_id'], 'measurement_ea_id': ledger['ea_id'],
                     'symbol': ledger['symbol'], 'in_frozen_16_cohort': (owner['ea_id'], ledger['symbol']) in cohort_keys,
                     'owner_status': owner['status'], 'historical_verdict': owner['verdict'],
                     'ledger_path': str(lp), 'ledger_sha256': hashlib.sha256(raw).hexdigest(), 'ledger_changed_during_read': lp.read_bytes() != raw,
                     'annual_dispositions': dict(counts), 'pattern_33_34_dispositions': dict(patterns), 'measured_per_year': dict(measured_years),
                     'base_setfile_path': str(base), 'base_setfile_exists': base_exists,
                     'base_setfile_hash_matches_ledger': base_exists and sha(base) == ledger['base_setfile_sha256'],
                     'neutral_controls_checked': n, 'neutral_control_hash_mismatches': bad_hashes, 'neutral_control_missing_paths': missing_sets,
                     'neutral_controls_with_recorded_hash': bound_hash_count,
                     'base_duplicates': {k: v for k, v in vals.items() if len(v) > 1},
                     'card_path_current': info.get('card_path'), 'current_card_input_count': len(info.get('card_defaults', {})),
                     'current_source_input_count': len(info.get('input_defaults', {})),
                     'omitted_current_source_inputs': sorted(set(info.get('input_defaults', {})) - set(vals)),
                     'card_comparison': checks, 'card_comparison_counts': dict(Counter(x['classification'] for x in checks)),
                     'parent_card_path_current': parent.get('card_path'), 'parent_card_comparison': parent_checks,
                     'parent_card_comparison_counts': dict(Counter(x['classification'] for x in parent_checks)),
                     'baseline_2019_native_activity': baseline_2019, 'one_floor_skip_sample': prune_sample,
                     'selection_receipt_path': str(qp) if qp else None, 'selection_receipt_sha256': sha(qp) if qp and qp.is_file() else None,
                     'selection_receipt_schema': qr.get('schema'), 'selection_completed_at': qr.get('completed_at_utc'),
                     'selection_stability': stability, 'selected_before_stability_gate': stability.get('final_selection'),
                     'selection_failure_class': ('NO_TERMINAL_SELECTION_RECEIPT' if not stability else 'NO_NONEMPTY_FINAL_SELECTION' if not stability.get('final_selection') else
                         'PERFORMANCE_AND_SELECTION_UNSTABLE' if stability.get('not_worse_count', 0) < stability.get('not_worse_required', 3) and stability.get('subset_count', 0) < stability.get('subset_required', 2) else
                         'PERFORMANCE_UNSTABLE' if stability.get('not_worse_count', 0) < stability.get('not_worse_required', 3) else 'SELECTION_UNSTABLE'),
                     'driver_status': ledger.get('driver', {}).get('state'),
                     'harness_work_item_id': ledger.get('harness_work_item_id')}
            result['programs'].append(entry)
        baseline = work_summary(db, '2fc84747-27db-5e88-9568-3fdda6c30769')
        old = work_summary(db, '356a3655-5f0a-51ea-84f3-a3d04e2ed714')
        new = work_summary(db, 'bc035c74-0000-5a7f-9c21-69a5e92b9529')
        result['balke_q02'] = baseline
        result['balke_2019_controls'] = [old, new]
        result['review_task'] = dict(db.execute('SELECT id,state,assigned_agent,verdict,artifact_path,updated_at FROM agent_tasks WHERE id=?', ('e1358f42-c9f2-4cd2-89ce-f337b17ac84a',)).fetchone())
        result['balke_duplicate_holds'] = [dict(r) for r in db.execute("SELECT work_item_id,active,hold_code FROM work_item_holds WHERE work_item_id IN ('97908d93-3ff8-5528-9518-8968aea72342','ed127702-3a08-59fa-888a-c3a0a20a0803','0e5eff83-75b8-5c59-99d0-609f5f2fb65c')")]
    trade_rows = []
    for control in result['balke_2019_controls']:
        trips, stats = extract_round_trips(Path(control['report_path']), 'USDJPY.DWX')
        rows = [dataclasses.asdict(t) for t in trips]; trade_rows.append(rows)
        control['round_trip_count'] = len(rows)
        control['round_trip_sha256'] = hashlib.sha256(json.dumps(rows, sort_keys=True, default=str).encode()).hexdigest()
        control['native_commission_sum'] = round(sum(t.native_commission for t in trips), 2)
        control['native_swap_sum'] = round(sum(t.native_swap for t in trips), 2)
    result['balke_2019_all_round_trips_equal'] = trade_rows[0] == trade_rows[1]
    result['balke_matrix_runtime_projection'] = {
        'basis': 'one 2019 neutral annual run; linear scenario only, not ETA',
        'observed_claim_to_verdict_seconds': new['claim_to_verdict_seconds'],
        'annual_cells': 1085, 'serial_terminal_hours': round(new['claim_to_verdict_seconds'] * 1085 / 3600, 2),
        'excludes': ['four WF combinations', 'queue wait', 'retries', 'different annual tick volumes', 'contention changes']}
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__); ap.add_argument('--out', type=Path, required=True); args = ap.parse_args()
    if args.out.exists(): raise ValueError('Evidence output already exists')
    result = snapshot()
    with args.out.open('x', encoding='utf-8') as fh: json.dump(result, fh, indent=2)
    print(json.dumps({'out': str(args.out), 'program_count': len(result['programs']),
                      'balke_2019_round_trip_parity': result['balke_2019_all_round_trips_equal'],
                      'runtime_projection': result['balke_matrix_runtime_projection']}, indent=2))


if __name__ == '__main__': main()
