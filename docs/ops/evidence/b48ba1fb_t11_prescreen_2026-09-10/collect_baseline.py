"""Read-only T11 research preflight; no terminal launcher or farm mutation APIs.

Writes only this evidence directory and the commissioned research report root.
Run once; a second invocation refuses to overwrite its snapshot.
"""
from __future__ import annotations
import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
import sqlite3
import statistics
import subprocess
import psutil

REPO = Path('C:/QM/repo')
OUT = Path(__file__).resolve().parent
RAW = Path('D:/QM/reports/research/t11_prescreen_2026-09-10')
STATE = Path('D:/QM/strategy_farm/state')
T11 = Path('D:/QM/mt5/T11')
TASK = 'b48ba1fb-0201-4bfd-a700-fbc14c98a668'
PROGRAMS = ('WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025', 'DL089_QM5_13213_USDJPY_DWX_2019_2025')

def now():
    return datetime.now(timezone.utc).isoformat()

def sha(path):
    return hashlib.file_digest(Path(path).open('rb'), 'sha256').hexdigest()

def save(path, data):
    with path.open('x', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

def csvout(name, rows):
    with (OUT / name).open('x', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)

def snapshot(db):
    processes = []
    for proc in psutil.process_iter(['pid','name','exe','create_time','cmdline']):
        try:
            info = proc.info
            exe = (info['exe'] or '').replace('\\','/').lower()
            args = ' '.join(info['cmdline'] or [])
            worker = 'terminal_worker.py' in args
            if exe.startswith('d:/qm/mt5/t11/') or worker:
                processes.append({k:info[k] for k in ('pid','name','exe','create_time')})
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            continue
    return {'at_utc':now(), 'processes':processes,
            'worker_pids':json.loads((STATE/'worker_pids.json').read_text()),
            'disabled_terminals':(STATE/'disabled_terminals.txt').read_text().splitlines(),
            't11_rows':[dict(r) for r in db.execute("SELECT id,status,claimed_by FROM work_items WHERE claimed_by='T11' OR json_extract(payload_json,'$.terminal')='T11'")],
            'work_items_count':db.execute('SELECT count(*) FROM work_items').fetchone()[0],
            'mutation_lock_present':(STATE/'FACTORY_MUTATION.lock').exists()}

def main():
    assert not (OUT/'baseline_summary.json').exists(), 'Snapshot already exists'
    RAW.mkdir(parents=True,exist_ok=True)
    db = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA query_only=ON')
    before = snapshot(db)
    save(RAW/'isolation_before.json', before)
    task = dict(db.execute('SELECT * FROM agent_tasks WHERE id=?',(TASK,)).fetchone())
    assert task['state']=='IN_PROGRESS' and task['assigned_agent']=='codex'
    save(RAW/'assigned_task.json', task)
    save(RAW/'spawn_lease.json',[dict(r) for r in db.execute('SELECT * FROM spawn_leases WHERE task_key=?',('agent_task:'+TASK,))])
    rows = [dict(r) for r in db.execute("SELECT id,ea_id,status,verdict,evidence_path,setfile_path,payload_json FROM work_items WHERE ea_id='QM5_41398' AND phase='OPT_CENSUS' ORDER BY id")]
    save(RAW/'ground_truth_rows.json',rows)
    guard=[]
    for _ in range(3):
        cpu=psutil.cpu_percent(interval=1)
        available=psutil.virtual_memory().available
        guard.append({'at_utc':now(),'host_cpu_pct':cpu,'free_ram_bytes':available,
                      'research_metatester_agents':0,'maximum_research_agents':4,
                      'decision':'STOP_RAM' if available<20*2**30 else 'NO_LAUNCH_CONTRACT_BLOCKED',
                      'cpu_90pct_300sec_condition':'NOT_EVALUATED_NO_RUN',
                      'note':'Preflight samples only; not proof of a tested runtime guard'})
    save(RAW/'cpu_guard.json',guard)
    inventory=[]
    for kind,ext in [('history','hcc'),('ticks','tkc')]:
        for p in sorted((T11/'Bases/Custom'/kind/'USDJPY.DWX').glob('*.'+ext)):
            if 2019<=int(p.stem[:4])<=2025:
                st=p.stat()
                inventory.append({'kind':kind,'path':str(p),'bytes':st.st_size,'mtime_ns':st.st_mtime_ns,
                                  'hardlink_count':st.st_nlink,'reparse_point':bool(getattr(st,'st_file_attributes',0)&1024)})
    csvout('t11_history_inventory.csv', inventory)
    defaults=json.loads((REPO/'framework/registry/tester_defaults.json').read_text())
    save(RAW/'tester_defaults_snapshot.json',defaults)
    source=REPO/'framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt.ex5'
    binary_hash=sha(source)
    comparison=[]; errors=[]; durations=defaultdict(list); measured_counts=Counter(); years=defaultdict(Counter)
    for row in rows:
        payload=json.loads(row['payload_json']); program=payload.get('program_id')
        if program not in PROGRAMS or row['verdict']!='MEASURED':
            continue
        measured_counts[program]+=1; years[program][str(payload['year'])]+=1
        try:
            path=Path(row['evidence_path']); s=json.loads(path.read_text(encoding='utf-8-sig')); run=s['runs'][0]
            ident=s['execution_identity']; report=Path(run['report_canonical_path']); ini=Path(run['tester_ini_path']); setfile=Path(row['setfile_path'])
            assert s['model']==4 and s['ea_id']==41398 and s['symbol']=='USDJPY.DWX' and s['period']=='H1'
            assert run['status']=='OK' and run['real_ticks_marker'] is True
            assert ident['expert_binary']['required_sha256']==binary_hash
            assert ident['expert_binary']['stable_during_run'] and ident['stable_during_run']
            assert sha(report)==run['report_sha256'] and sha(ini)==run['tester_ini_sha256']
            assert sha(setfile)==ident['setfile']['source']['sha256']==payload['expected_setfile_sha256']
            assert s['from_date']==payload['from_date'] and s['to_date']==payload['to_date']
            setraw=setfile.read_bytes(); text=setraw.decode('utf-16' if setraw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
            inputs={k.strip():v.split('||')[0].strip() for line in text.splitlines() if '=' in line for k,v in [line.split('=',1)]}
            assert float(inputs['RISK_FIXED'])>0 and float(inputs['RISK_PERCENT'])==0
            assert int(inputs['qm_news_stale_max_hours'])<=336
            start=datetime.fromisoformat(payload['started_at_iso'].replace('Z','+00:00'))
            end=datetime.fromisoformat(s['timestamp_utc'].replace('Z','+00:00'))
            elapsed=(end-start).total_seconds(); assert elapsed>0
            durations[program].append(elapsed)
            comparison.append({'program_id':program,'cell_key':payload['cell_key'],'work_item_id':row['id'],
                'arm':payload['arm'],'year':payload['year'],'real_model':4,'real_net_profit':run['net_profit'],
                'real_profit_factor':run['profit_factor'],'real_drawdown':run['drawdown'],'real_trades':run['total_trades'],
                'gross_return_to_maxdd':run['net_profit']/max(run['drawdown'],1),
                'receipt_elapsed_seconds':round(elapsed,6),'started_at_utc':payload['started_at_iso'],
                'summary_timestamp_utc':s['timestamp_utc'],'summary_path':str(path),'summary_sha256':sha(path),
                'report_path':str(report),'report_sha256':run['report_sha256'],'tester_ini_path':str(ini),
                'tester_ini_sha256':run['tester_ini_sha256'],'setfile_path':str(setfile),'setfile_sha256':sha(setfile),
                'ex5_sha256':binary_hash,'commission_group_sha256':s['commission_group']['canonical_sha256'],
                'cheap_model':'','cheap_net_profit':'','cheap_profit_factor':'','cheap_trades':'','cheap_elapsed_seconds':'',
                'comparison_status':'NOT_MEASURED_LAUNCH_CONTRACT_BLOCKED'})
        except Exception as exc:
            errors.append({'work_item_id':row['id'],'error':repr(exc)})
    csvout('real_tick_vs_cheap_cells.csv',comparison)
    timing={p:{'cells':len(v),'mean_seconds':statistics.mean(v),'median_seconds':statistics.median(v),
               'min_seconds':min(v),'max_seconds':max(v),'total_seconds':sum(v)} for p,v in durations.items()}
    counts=[{'program_id':p,'state':state,'verdict':verdict,'n':n} for (p,state,verdict),n in Counter((json.loads(r['payload_json']).get('program_id'),r['status'],r['verdict']) for r in rows).items()]
    result={'schema':'qm.t11-prescreen-preflight.v1','at_utc':now(),'task_id':TASK,'status':'DEVIATION_NO_MT5_LAUNCH',
        'measured_counts':dict(measured_counts),'year_counts':{p:dict(v) for p,v in years.items()},'queue_counts':counts,
        'authenticated_cells':len(comparison),'authentication_errors':errors,'timing':timing,'ex5_sha256':binary_hash,
        't11_history_files':len(inventory),'t11_history_bytes':sum(r['bytes'] for r in inventory),
        'history_validation':'Filename/size/link inventory only; contents and tick completeness not validated by tester',
        't11_terminal_sha256':sha(T11/'terminal64.exe'),
        'cheap_measurements':0,'raw_tester_outputs_created':0,'fidelity_metrics':None,
        'declared_backlog':6453,'empirically_supported_reduction':None,
        'sources':{'database':'D:/QM/strategy_farm/state/farm_state.sqlite','snapshot':str(RAW/'ground_truth_rows.json'),
                   'cell_csv':str(OUT/'real_tick_vs_cheap_cells.csv')},
        'code_evidence':{str(p):sha(p) for p in [REPO/'framework/scripts/run_smoke.ps1', REPO/'tools/strategy_farm/custom_history_smoke_admission.py', REPO/'tools/strategy_farm/mt5_latency_lab.py', REPO/'tools/strategy_farm/mt5_warm_lab.py', REPO/'tools/strategy_farm/mt5_qm_warm_fixture.py']}}
    after=snapshot(db); save(RAW/'isolation_after.json',after)
    result['isolation']={'worker_pid_map_unchanged':before['worker_pids']==after['worker_pids'],
        't11_rows_before':len(before['t11_rows']),'t11_rows_after':len(after['t11_rows']),
        't11_process_count_before':sum('/t11/' in (p['exe'] or '').replace('\\','/').lower() for p in before['processes']),
        't11_process_count_after':sum('/t11/' in (p['exe'] or '').replace('\\','/').lower() for p in after['processes']),
        'research_db_connection':'mode=ro; PRAGMA query_only=ON','experiment_launches':0}
    save(OUT/'baseline_summary.json',result)
    assert not errors, errors
    assert len(comparison)==sum(measured_counts.values())
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    main()
