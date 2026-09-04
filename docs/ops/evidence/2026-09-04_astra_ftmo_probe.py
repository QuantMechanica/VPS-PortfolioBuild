"""Bounded read-only FTMO analysis; writes only this evidence prefix and scratch.

No book manifest is created, no guard is bypassed, and no admission is made.
Run from C:/QM/repo with Python 3.11. The router lease is managed separately.
"""
from __future__ import annotations

import collections
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys

ROOT = Path('C:/QM/repo')
EVIDENCE = ROOT / 'docs/ops/evidence'
PREFIX = '2026-09-04_astra_ftmo'
SCRATCH = Path('D:/QM/scratch/astra_ftmo_book_analysis_20260904')
DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
sys.path.insert(0, str(ROOT))
sys.stdout.reconfigure(encoding='utf-8')
os.environ['OPENBLAS_NUM_THREADS'] = '1'
os.environ['OMP_NUM_THREADS'] = '1'


def write(name, obj):
    path = EVIDENCE / f'{PREFIX}_{name}.json'
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, default=str, allow_nan=False) + '\n', encoding='utf-8')
    return path


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def binding(path):
    path = Path(path)
    return {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'mtime_utc': dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc).isoformat()}


def vault_status():
    try:
        return {'available': Path('G:/My Drive/QuantMechanica - Company Reference/08 Current State/Current Operating State.md').is_file()}
    except OSError as exc:
        return {'available': False, 'error': str(exc)}


def command(name, argv, timeout=180):
    started = dt.datetime.now(dt.timezone.utc).isoformat()
    result = subprocess.run([sys.executable, '-X', 'utf8', *argv], cwd=ROOT,
                            capture_output=True, text=True, encoding='utf-8', timeout=timeout)
    receipt = {'started_utc': started, 'command': [sys.executable, '-X', 'utf8', *argv],
               'cwd': str(ROOT), 'exit_code': result.returncode,
               'stdout': result.stdout, 'stderr': result.stderr}
    write(name, receipt)
    print(name, result.returncode, flush=True)
    return receipt


def census_and_inputs():
    from tools.strategy_farm import assemble_stream_bundle as bundle
    from tools.strategy_farm.portfolio import build_book_ftmo as builder
    import numpy as np

    SCRATCH.mkdir(parents=True, exist_ok=True)
    pairs = bundle.resolve_qualified_pairs(Path('D:/QM/strategy_farm/state/farm_state.sqlite'))
    scores_path = builder.DEFAULT_FUND_SCORES
    scores = {r['sleeve']: r for r in read(scores_path)['rows']}
    costs = read(builder.DEFAULT_COST_SNAPSHOT)
    cost_symbols = {r['dwx_symbol'] for r in costs['book3_normalization']}
    previous = read(EVIDENCE / '2026-09-04_q08_stream_auto_rerun_dry_run.json')
    seals = {(r['ea_id'], r['symbol']): r for r in previous['items'] if r.get('reason') == 'stream_already_bound'}
    rows, daily, spans = [], {}, {}
    for ea, symbol in pairs:
        ea_text = str(ea) if str(ea).startswith('QM5_') else f'QM5_{ea}'
        number = int(ea_text.split('_')[-1])
        base = symbol.removesuffix('.DWX')
        key = f'{number}:{base}'
        stream = Path('D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades') / f'{number}_{symbol.replace(".", "_")}.jsonl'
        records = [json.loads(line) for line in stream.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
        trades = [r for r in records if r.get('event') == 'TRADE_CLOSED']
        exits = [dt.datetime.fromtimestamp(r['time'], dt.timezone.utc) for r in trades]
        entries = [dt.datetime.fromtimestamp(r['entry_time'], dt.timezone.utc) for r in trades if r.get('entry_time')]
        series = collections.defaultdict(float)
        for trade, stamp in zip(trades, exits):
            series[stamp.date()] += float(trade['net'])
        daily[key] = series
        spans[key] = (min(exits).date(), max(exits).date())
        row = {'ea_id': ea_text, 'symbol': symbol, 'sleeve_id': key, 'binding': binding(stream),
               'sealed_receipt': seals.get((ea_text, symbol)), 'trades': len(trades),
               'first_close_day_label': str(min(exits).date()), 'last_close_day_label': str(max(exits).date()),
               'entry_time_records': len(entries), 'exit_days': len(series),
               'open_days': len({x.date() for x in entries}),
               'overnight_trades_day_labels': sum(a.date() < b.date() for a,b in zip(entries, exits)) if len(entries) == len(exits) else None,
               'net_dxz': sum(float(r['net']) for r in trades),
               'swap_dxz': sum(float(r.get('swap', 0)) for r in trades),
               'fund_score_row': scores.get(key), 'normalized_ftmo_cost_covered': symbol in cost_symbols,
               'warning': 'Broker timestamp day labels only; not certified Prague intraday equity or FTMO execution.'}
        rows.append(row)
    first, last = max(v[0] for v in spans.values()), min(v[1] for v in spans.values())
    days = [first + dt.timedelta(days=i) for i in range((last-first).days+1)
            if (first + dt.timedelta(days=i)).weekday() < 5]
    keys = sorted(daily)
    data = np.asarray([[daily[k].get(d, 0) for k in keys] for d in days])
    matrix = np.corrcoef(data, rowvar=False)
    stress = np.abs(data).sum(axis=1) >= np.quantile(np.abs(data).sum(axis=1), .75)
    stress_matrix = np.corrcoef(data[stress], rowvar=False)
    correlations = []
    for i, a in enumerate(keys):
        for j in range(i+1, len(keys)):
            b = keys[j]
            correlations.append({'a': a, 'b': b, 'pearson': float(matrix[i,j]),
                'stress_pearson': float(stress_matrix[i,j]),
                'both_negative_days': int(((data[:,i] < 0) & (data[:,j] < 0)).sum()),
                'both_nonzero_days': int(((data[:,i] != 0) & (data[:,j] != 0)).sum())})
    roster = [(int(r['ea_id'].split('_')[-1]), r['symbol']) for r in rows]
    score_map, score_binding = builder.load_fund_scores(scores_path)
    selection, assessments, control = builder.select_under_aggregate_control(roster, score_map, {})
    # The pure screening helper reports exclusions only. Never call build_ftmo_manifest.
    assert not selection, 'Unexpected eligible sleeve: stop rather than mint a book below its guard.'
    artifact = {'observed_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'pairs': rows,
        'qualified_pairs': len(rows), 'distinct_eas': len({r['ea_id'] for r in rows}),
        'builder_screen_only': {'selected': selection, 'assessments': assessments, 'control': control},
        'cost_binding': binding(builder.DEFAULT_COST_SNAPSHOT), 'fund_scores_binding': binding(scores_path),
        'cost_normalization': costs['book3_normalization'],
        'literal_builder_defaults': {'roster': str(builder.DEFAULT_ROSTER), 'stream_root': str(builder.DEFAULT_STREAM_ROOT),
            'as_of': '2026-08-12', 'fund_score_floor': builder.FUND_SCORE_FLOOR,
            'max_pairwise_correlation': builder.WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION,
            'account_weight_budget': builder.WORKING_DEFAULT_ACCOUNT_WEIGHT_BUDGET},
        'correlation_diagnostic': {'basis': 'DXZ reported net; exogenous weekday zeros; common exit-date support; NO certification',
            'start': str(first), 'end': str(last), 'days': len(days), 'stress_days': int(stress.sum()),
            'stress_definition': 'top quartile of sum(abs(sleeve daily net)); not a venue volatility series',
            'max_abs_pearson': max(abs(r['pearson']) for r in correlations),
            'max_abs_stress_pearson': max(abs(r['stress_pearson']) for r in correlations), 'pairs': correlations},
        'official_rules_binding': binding(EVIDENCE/'2026-09-04_ftmo_official_rules_snapshot.json'),
        'rulepack_binding': binding(ROOT/'tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json'),
        'vault_status': vault_status()}
    with sqlite3.connect(DB, uri=True) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute('PRAGMA query_only=ON')
        receipt = read('D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/enqueue_receipt.json')
        ids = receipt['inserted'] + receipt['existing']
        oos = [dict(r) for r in conn.execute('SELECT id,ea_id,symbol,phase,status,verdict,evidence_path,updated_at FROM work_items WHERE id IN (' + ','.join('?' for _ in ids) + ')', ids)]
        artifact['oos_confirmation'] = {'receipt_binding': binding('D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/enqueue_receipt.json'),
            'count': len(oos), 'status_counts': dict(collections.Counter(r['status'] for r in oos)), 'rows': oos}
        artifact['db_query_only'] = conn.execute('PRAGMA query_only').fetchone()[0]
    write('inventory', artifact)
    print('inventory written', len(rows), flush=True)


def oos_and_contracts():
    from tools.strategy_farm.portfolio import ftmo_timebox_eval as tb
    inventory = read(EVIDENCE/f'{PREFIX}_inventory.json')
    campaign_path = Path('D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json')
    campaign = read(campaign_path)
    rows = []
    with sqlite3.connect(DB, uri=True) as conn:
        conn.execute('PRAGMA query_only=ON')
        for row in inventory['oos_confirmation']['rows']:
            if row['status'] != 'done':
                continue
            payload = json.loads(conn.execute('SELECT payload_json FROM work_items WHERE id=?', (row['id'],)).fetchone()[0])
            summary = read(row['evidence_path'])
            plan_path = payload.get('q09_run_plan_path')
            plan = read(plan_path) if plan_path else {}
            input_path = plan.get('input_manifest_path')
            inputs = read(input_path) if input_path else {}
            tester = summary.get('test_window', {}).get('tester_ini_files', [])
            rows.append({'work_item_id': row['id'], 'ea_id': row['ea_id'], 'symbol': row['symbol'],
                'summary': binding(row['evidence_path']), 'summary_schema': summary.get('evidence_schema'),
                'report_from_date': summary.get('from_date'), 'report_to_date': summary.get('to_date'),
                'input_manifest': binding(input_path) if input_path else None, 'input_windows': inputs.get('windows'),
                'run_plan': binding(plan_path) if plan_path else None, 'window_source': plan.get('window_source'),
                'payload_expected_from_date': payload.get('expected_from_date'),
                'payload_expected_to_date': payload.get('expected_to_date'),
                'tester_ini_bindings': [{'binding': binding(x['path']), 'reported': x} for x in tester],
                'expected_2026_window_matches': summary.get('from_date') == '2026.01.01' and summary.get('to_date') == '2026.04.06'})
    one_day = [tb.DailyPoint(dt.date(2026,1,5), .101, 0, 1, True, True)]
    returned = tb.evaluate_phase(one_day, 0, .10, 60)
    # Probe an existing defect, not an admission test or alteration of production code.
    assert returned['outcome'] == 'PASS' and returned['days_elapsed'] == 1
    out = {'observed_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
        'campaign': binding(campaign_path), 'declared_window': [campaign['full_from_utc'], campaign['full_to_utc']],
        'completed_reviewed': len(rows), 'matching_expected_window': sum(r['expected_2026_window_matches'] for r in rows),
        'rows': rows, 'four_day_reproducer': {'function':'ftmo_timebox_eval.evaluate_phase',
            'input': 'one flat day, one trade, net return 0.101, low 0, initial 1',
            'actual': returned, 'official_expectation': 'Cannot pass before four separate CE(S)T opening days',
            'production_file': binding(ROOT/'tools/strategy_farm/portfolio/ftmo_timebox_eval.py')},
        'timebox_rules': tb.DEFAULT_RULES, 'timebox_correlation': tb.DEFAULT_CORRELATION,
        'verdict': 'EVIDENCE_GAPS; NO_PIPELINE_VERDICT; NO_REPAIR_APPLIED'}
    write('contracts', out)
    print('OOS completed/valid',len(rows),out['matching_expected_window'],flush=True)


def timebox_refusals():
    from tools.strategy_farm.portfolio import ftmo_qualification as qual
    from tools.strategy_farm.portfolio import ftmo_timebox_eval as tb
    inventory = read(EVIDENCE/f'{PREFIX}_inventory.json')
    bundle = read(SCRATCH/'streams/bundle_manifest.json')
    with sqlite3.connect(DB, uri=True) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute('PRAGMA query_only=ON')
        candidates = [qual.evaluate_candidate(conn, row['ea_id'], row['symbol'], repo_root=ROOT,
            common_dir=SCRATCH/'streams', min_trades=50) for row in inventory['pairs']]
    qualification = {'candidates':candidates, 'challenge_ready_count':sum(r['challenge_ready'] for r in candidates),
        'generated_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(), 'read_only': True,
        'claim': 'Existing legacy qualification code on the current Q14 pool; incompatibilities are findings, not new gate verdicts.'}
    qual_path = write('qualification', qualification)
    projected = SCRATCH/'selected_provider_rows.json'
    projected.write_text(json.dumps(read(ROOT/'docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json')['selected_provider_rows'],indent=2)+'\n', encoding='utf-8')
    # Exact schema projection of existing provider rows. No cost value is changed or supplied.
    streams = [{'sleeve_id':f"{r['ea_int']}:{r['symbol'].removesuffix('.DWX')}",
        'symbol':r['symbol'].removesuffix('.DWX'),
        'ftmo_code': {'XTIUSD.DWX':'USOIL.cash'}.get(r['symbol'],r['symbol'].removesuffix('.DWX')),
        'stream_schema':'DXZ_Q08_TRADES_V1','path':r['bundle_path']} for r in bundle['results'] if r['outcome']=='bound']
    # Singleton probes test each data chain without constructing a book.
    compositions = [{'id': 'DATA_CHAIN_'+s['sleeve_id'], 'sleeves':[{'sleeve_id':s['sleeve_id'],'weight':1.0}]} for s in streams]
    runs = []
    frozen_scores = SCRATCH/'fund_scores.json'
    frozen_scores.write_bytes(Path(inventory['fund_scores_binding']['path']).read_bytes())
    for label, cost in [('native_cost_schema',ROOT/'docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json'),('exact_cost_projection',projected)]:
        spec = {'inventory_path':str(qual_path), 'fund_scores_path':str(frozen_scores),
            'ftmo_cost_snapshot_path':str(cost),'streams':streams,'compositions':compositions}
        spec_path = write('timebox_'+label+'_spec', spec)
        config_path = EVIDENCE/f'{PREFIX}_timebox_{label}_config.json'
        prep = command('timebox_'+label+'_prepare', [str(ROOT/'tools/strategy_farm/portfolio/ftmo_timebox_eval.py'),
            'prepare-config','--spec',str(spec_path),'--output',str(config_path)])
        assert prep['exit_code'] == 0
        config_sha = hashlib.sha256(config_path.read_bytes()).hexdigest()
        run = command('timebox_'+label+'_evaluate',[str(ROOT/'tools/strategy_farm/portfolio/ftmo_timebox_eval.py'),
            'evaluate','--config',str(config_path),'--expected-config-sha256',config_sha,
            '--output',str(EVIDENCE/f'{PREFIX}_timebox_{label}_result.json')])
        runs.append({'label':label,'exit_code':run['exit_code'],'stdout':run['stdout']})
    write('timebox_summary', {'runs':runs, 'qualification_ready':qualification['challenge_ready_count'],
        'cost_projection':binding(projected), 'projection_source':inventory['cost_binding'],
        'actual_book_admitted':False, 'p1_probability':None,'p2_conditional_probability':None,'joint_probability':None,
        'expected_time_to_target_days':None,'reason':'No admitted or cost-certified composition; null is not zero probability.'})


def legacy_first_passage():
    import contextlib
    import io
    import statistics
    sys.path.insert(0,str(ROOT/'tools/strategy_farm/portfolio'))
    import audit_ev_funded_account as ev
    with contextlib.redirect_stdout(io.StringIO()):
        cb = ev.sw.engine()
    book = ev.sw.Book(cb)
    anchor = ev.sw.selftest(book,cb)
    assert anchor['reproduced']
    floor = ev.overlap_floor(cb)
    rows = []
    for basis, lows in [('close',None),('overlap_floor',floor)]:
        for mult in ev.GRID:
            for stage2_scale in (1.0,.75):
                outcomes = []
                for start in book.starts:
                    one,end1 = ev.phase(book,start,mult,.10,60,lows)
                    two,end2 = ev.phase(book,end1+dt.timedelta(days=1),mult*stage2_scale,.05,30,lows) if one=='pass' else (None,None)
                    outcomes.append({'start':str(start),'stage1':one,'stage2':two,
                        'stage1_days_if_pass':(end1-start).days+1 if one=='pass' else None,
                        'stage2_days_if_pass':(end2-end1).days if two=='pass' else None,
                        'joint_days_if_pass':(end2-start).days+1 if two=='pass' else None})
                n = len(outcomes)
                p1 = sum(r['stage1']=='pass' for r in outcomes)
                p2 = sum(r['stage2']=='pass' for r in outcomes)
                def moments(field):
                    vals = [r[field] for r in outcomes if r[field] is not None]
                    return {'mean':statistics.mean(vals),'median':statistics.median(vals),'count':len(vals)} if vals else None
                rows.append({'basis':basis,'multiplier':mult,'stage2_scale':stage2_scale,'starts':n,
                    'stage1_pass':p1/n,'stage2_given_stage1':p2/p1 if p1 else None,'joint_pass':p2/n,
                    'stage1_outcomes':dict(collections.Counter(r['stage1'] for r in outcomes)),
                    'stage1_days_conditional_on_pass':moments('stage1_days_if_pass'),
                    'stage2_days_conditional_on_pass':moments('stage2_days_if_pass'),
                    'joint_days_conditional_on_pass':moments('joint_days_if_pass')})
    write('legacy_first_passage', {'claim':'FROZEN_24_DXZ_DIAGNOSTIC; NOT_CURRENT_8; NOT_FTMO_MONEY_EVIDENCE',
        'selftest':anchor,'fingerprint':ev.sw.stream_fingerprint(cb),'rows':rows,
        'limitations':['close/MAE proxy; no synchronized intraday equity','DXZ costs, not FTMO-adjusted',
            'legacy stage counts close days, not opening days; flat state not enforced',
            'fixed dollar scaling, not verified live RISK_PERCENT anchor',
            'time means conditional on passing; no finite unconditional expected target time claimed',
            '50 grid starts are not 50 independent complete two-stage paths; no selection-sealed OOS claim']})
    print('first passage diagnostics written',flush=True)


def validate_evidence():
    inv = read(EVIDENCE/f'{PREFIX}_inventory.json')
    bundle_path = SCRATCH/'streams/bundle_manifest.json'
    bundle = read(bundle_path)
    assert bundle['bound_count'] == 8 and bundle['refused_count'] == 0
    assert bundle['loader_verification']['verified'] is True
    assert len(inv['pairs']) == 8 and not inv['builder_screen_only']['selected']
    assert sum(r['normalized_ftmo_cost_covered'] for r in inv['pairs']) == 2
    comparisons = []
    for row in bundle['results']:
        assert binding(row['bundle_path'])['sha256'] == row['seal_content_sha256']
        assert binding(row['recorded_path'])['sha256'] == row['seal_content_sha256']
        previous = Path('D:/QM/reports/portfolio/dxz_final_20260719/QM/q08_trades')/row['filename']
        comparisons.append({'sleeve':row['filename'],'current':binding(row['bundle_path']),
            'legacy_score_source':binding(previous) if previous.exists() else None})
    contracts = read(EVIDENCE/f'{PREFIX}_contracts.json')
    assert contracts['completed_reviewed'] == 15 and contracts['matching_expected_window'] == 0
    for row in contracts['rows']:
        assert row['input_windows']['full_from_utc'] == '2026-01-01T00:00:00Z'
        assert row['input_windows']['full_to_utc'] == '2026-04-06T23:59:59Z'
        assert row['report_from_date'] == '2024.01.01' and row['report_to_date'] == '2024.12.31'
        for item in row['tester_ini_bindings']:
            raw = Path(item['binding']['path']).read_bytes()
            text = raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8-sig')
            assert 'FromDate=2024.01.01' in text and 'ToDate=2024.12.31' in text
            assert hashlib.sha256(raw).hexdigest() == item['reported']['sha256']
    result = read(EVIDENCE/f'{PREFIX}_timebox_exact_cost_projection_result.json')
    assert result['status'] == 'NO_ADMISSIBLE_COMPOSITION'
    assert result['decision']['best_bootstrap_lower_bound_p1'] is None
    assert len(result['sleeve_refusals']) == 8
    ev = read(EVIDENCE/f'{PREFIX}_legacy_ev.json')
    assert ev['selftest']['reproduced'] and ev['stream_fingerprint'] == 'e50e8f891c34f838e576f00c4b4d85e0815bd358c20028ac55dd294369b81759'
    fp = read(EVIDENCE/f'{PREFIX}_legacy_first_passage.json')
    for row in ev['rows']:
        match = next(x for x in fp['rows'] if x['basis']==row['basis'] and x['multiplier']==row['multiplier'] and x['stage2_scale']==1.0)
        assert abs(match['stage1_pass']-row['p1_rate'])<1e-12
        assert abs(match['joint_pass']-row['funded_rate'])<1e-12
    mc_path = SCRATCH/'legacy_mc/results.json'
    mc = read(mc_path)
    write('legacy_mc', mc)
    checks = {'all_8_stream_hashes_still_match_seals':True,'zero_fund_score_selected':True,
        'normalized_cost_coverage_2_of_8':True,'all_15_oos_reports_are_wrong_window':True,
        'raw_tester_inis_confirm_all_15_wrong_windows':True,'timebox_all_8_refused':True,
        'legacy_24_fingerprint_and_numeric_anchors_reproduced':True,'first_passage_rates_match_existing_ev':True,
        'builder_created_no_manifest':not (SCRATCH/'builder').exists(),
        'production_code_changed':False, 'farm_db_mutated_by_analysis':False}
    assert checks['builder_created_no_manifest']
    scripts = ['portfolio/build_book_ftmo.py','portfolio/fund_score.py','portfolio/sleeve_improvement_targets.py',
        'portfolio/challenge_book_60d.py','portfolio/ftmo_timebox_eval.py','portfolio/ftmo_p1_mc.py',
        'portfolio/audit_ev_funded_account.py','portfolio/portfolio_correlation.py','portfolio/book_builder_common.py',
        'portfolio/portfolio_common.py','q15_fit_report.py','assemble_stream_bundle.py','target_rulepacks.py']
    write('verification',{'verified_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'checks':checks,
        'current_vs_legacy_scoring_streams':comparisons,'bundle_receipt':binding(bundle_path),
        'legacy_mc_input_and_output':binding(mc_path),
        'code_bindings':[binding(ROOT/'tools/strategy_farm'/p) for p in scripts]})
    print('focused evidence verification PASS',flush=True)


if __name__ == '__main__':
    operation = sys.argv[1]
    if operation == 'inventory':
        census_and_inputs()
    elif operation == 'builder':
        command('builder_run', [str(ROOT/'tools/strategy_farm/portfolio/build_book_ftmo.py'), '--as-of','2026-09-04', '--out-dir',str(SCRATCH/'builder')])
    elif operation == 'bundle':
        command('bundle_run', [str(ROOT/'tools/strategy_farm/assemble_stream_bundle.py'), '--out',str(SCRATCH/'streams')])
    elif operation == 'ev':
        command('legacy_ev_run', [str(ROOT/'tools/strategy_farm/portfolio/audit_ev_funded_account.py'), '--json-out',str(EVIDENCE/f'{PREFIX}_legacy_ev.json')])
    elif operation == 'freeze':
        command('risk_freeze', [str(ROOT/'tools/strategy_farm/risk_freeze.py'), 'status'])
    elif operation == 'contracts':
        oos_and_contracts()
    elif operation == 'timebox':
        timebox_refusals()
    elif operation == 'first_passage':
        legacy_first_passage()
    elif operation == 'legacy_mc':
        command('legacy_mc_run', [str(ROOT/'tools/strategy_farm/portfolio/ftmo_p1_mc.py'),
            '--out-dir',str(SCRATCH/'legacy_mc'), '--paths','2000','--horizon','43',
            '--seed','20260904','--compositions','a_motor_solo_050,a_motor_solo_100'])
    elif operation == 'verify':
        validate_evidence()
    else:
        raise ValueError(operation)
