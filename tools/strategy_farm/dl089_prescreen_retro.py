"""Receipt-bound retrospective B5/B2 holds. Work-item rows are never written."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import datetime as dt
from functools import lru_cache
import hashlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import sys
import time

try:
    from tools.strategy_farm import dl089_prescreen as prescreen
    try:
        from tools.strategy_farm.research import pattern_fire_count as counter
    except ModuleNotFoundError:
        from research import pattern_fire_count as counter  # script-style import (sys.path = tools/strategy_farm)
except ModuleNotFoundError:
    import dl089_prescreen as prescreen
    from research import pattern_fire_count as counter

SCHEMA='qm.dl089-prescreen-retro/v1'
HOLD='PRESCREEN_SKIPPED'
EVENT='prescreen_retro_receipt'
ENTITY='dl089_prescreen_program'
TASK='c3779c25-3795-4535-a3bf-66ee862d72b9'
DB=Path('D:/QM/strategy_farm/state/farm_state.sqlite')
OUT=Path('C:/QM/repo/docs/ops/evidence/2026-09-05_census_prescreen_retro')
CANON=Path('C:/QM/repo')


def now():return dt.datetime.now(dt.timezone.utc).isoformat()
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def digest(value):return prescreen.digest(value)
def payload(row):return json.loads(row['payload_json'] or '{}')
def write_new(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,indent=2,sort_keys=True);f.write('\n')


def declaration(ledger):
    return {k:ledger.get(k) for k in ('program_id','ea_id','symbol','years','cells','q12_work_item_id','q12_declaration_sha256')}


def classify(pairs, fire_counts):
    """Unknown evidence never becomes a rejection; use the existing Decimal B2."""
    if len(pairs)!=2 or any(a is None or b is None for a,b in pairs):
        return 'UNKNOWN','STAGE1_NOT_MEASURED'
    if len(fire_counts)!=2 or any(type(n) is not int or n<0 for n in fire_counts):
        return 'UNKNOWN','B5_EVIDENCE_MISSING'
    if any(n<prescreen.THRESHOLD for n in fire_counts):return 'SKIP','B5_BELOW_THRESHOLD'
    if not all(prescreen.qualifies(a,b) for a,b in pairs):return 'SKIP','B2_NOT_QUALIFIED'
    return 'ADMIT','B5_AND_B2_QUALIFIED'


def plan(conn,out):
    conn.row_factory=sqlite3.Row
    rows=[dict(r) for r in conn.execute("SELECT * FROM work_items WHERE phase='OPT_CENSUS'")]
    live={payload(r).get('ledger_path') for r in rows if r['status'] in ('pending','active') and payload(r).get('year') in range(2019,2026)}
    by_id={r['id']:r for r in rows};holds={r['work_item_id']:dict(r) for r in conn.execute('SELECT * FROM work_item_holds')}
    measured_2h=conn.execute("SELECT COUNT(*) FROM work_items WHERE phase='OPT_CENSUS' AND status='done' AND verdict='MEASURED' AND julianday(updated_at)>=julianday('now','-2 hours')").fetchone()[0]
    programs=[];contracts={}
    out.mkdir(parents=True,exist_ok=True);(out/'contracts').mkdir(exist_ok=True)
    for raw_path in sorted(p for p in live if p):
        path=Path(raw_path);ledger=json.loads(path.read_text(encoding='utf-8-sig'))
        cells=ledger['cells'];arms=sorted({c['arm'] for c in cells if c['arm']!='baseline'})
        if len(arms)!=154 or len(cells)!=1085 or ledger['years']!=list(range(2019,2026)):
            raise ValueError('legacy full declaration mismatch: '+str(path))
        reruns=(ledger.get('driver') or {}).get('reruns') or {}
        resolved={}
        for cell in cells:
            ids=reruns.get(cell['cell_key']) or [cell['work_item_id']]
            row=by_id.get(ids[-1])
            if row:
                p=payload(row)
                if any(p.get(k)!=cell.get(k) for k in ('arm','year','cell_key','direction','predicate_id')) or p.get('program_id')!=ledger['program_id']:
                    raise ValueError('resolved cell identity drift: '+row['id'])
            resolved[(cell['year'],cell['arm'])]=(cell,row)
        symbol=ledger['symbol'];metrics={};errors={}
        for key,(cell,row) in resolved.items():
            if key[0] in prescreen.YEARS:
                try:metrics[key]=prescreen.measured(row)
                except (OSError,ValueError,KeyError,TypeError) as exc:metrics[key]=None;errors[str(key)]=str(exc)
        baseline={y:metrics.get((y,'baseline')) for y in prescreen.YEARS}
        if symbol not in contracts:
            try:
                contracts[symbol]=prescreen.create_contract(symbol,manifest_root=out/'contracts',
                    authority=CANON/'decisions/2026-09-02_owner_receipts_ceo_asks.md')
            except (OSError,ValueError) as exc:contracts[symbol]={'error':str(exc)}
        contract=contracts[symbol];counts={};count_error=None
        if all(baseline.values()) and 'error' not in contract:
            try:
                manifest=prescreen.validate_contract(contract)
                counts=counter.count_program(ledger['program_id'],symbol,
                    {y:Path(baseline[y]['report_path']) for y in prescreen.YEARS},Path(manifest['bars_path']))['counts_by_year']
            except (OSError,ValueError,KeyError) as exc:count_error=str(exc)
        decisions={};targets=[]
        for arm in arms:
            pairs=[(metrics.get((y,arm)),baseline[y]) for y in prescreen.YEARS]
            fires=[counts.get(str(y),{}).get(arm) for y in prescreen.YEARS]
            disposition,reason=classify(pairs,fires)
            decisions[arm]={'disposition':disposition,'reason':reason,'fire_counts':fires,
                            'proof':[m for pair in pairs for m in pair if m] if disposition!='UNKNOWN' else []}
            if disposition!='SKIP':continue
            for year in range(2021,2026):
                cell,row=resolved[(year,arm)]
                if not row or row['status']!='pending' or row['claimed_by'] is not None or row['verdict'] is not None or row['id'] in holds:continue
                targets.append({'id':row['id'],'cell_key':cell['cell_key'],'year':year,'arm':arm,
                                'direction':cell['direction'],'predicate_id':cell['predicate_id'],
                                'setfile_path':row['setfile_path']})
        summary=Counter(d['disposition'] for d in decisions.values())
        programs.append({'program_id':ledger['program_id'],'ea_id':ledger['ea_id'],'symbol':symbol,
                         'ledger_path':str(path),'declaration_sha256':digest(declaration(ledger)),
                         'declared_trial_count':154,'contract':contract,'arm_decisions':decisions,
                         'classification_counts':dict(summary),'targets':targets,'candidate_holds':len(targets),
                         'pending_annual_rows':sum(r is not None and r['status']=='pending' for _,r in resolved.values()),
                         'estimated_hours_saved':len(targets)/(measured_2h/2) if measured_2h else None,
                         'evidence_errors':errors,'count_error':count_error})
        print(json.dumps({'program':ledger['program_id'],'classification':dict(summary),'would_hold':len(targets)}),flush=True)
    result={'schema':SCHEMA,'task_id':TASK,'decision_id':prescreen.DECISION,'created_at':now(),
            'read_only_database':True,'stage1_years':[2019,2020],'b5_threshold':5,'b2_uplift':'0.05',
            'measurements_last_2h':measured_2h,'measured_cells_per_hour':measured_2h/2,
            'rate_basis':'Completed MEASURED annual census rows by updated_at in the trailing two wall-clock hours',
            'programs':programs,'planned_holds':sum(p['candidate_holds'] for p in programs)}
    write_new(out/'dry_run.json',result)
    return result


@lru_cache(maxsize=128)
def _receipt(path,expected_sha,size,mtime):
    p=Path(path)
    if sha(p)!=expected_sha:raise ValueError('retro receipt SHA256 mismatch')
    r=json.loads(p.read_text(encoding='utf-8-sig'))
    if r.get('schema')!=SCHEMA or r.get('decision_id')!=prescreen.DECISION or r.get('task_id')!=TASK or r.get('declared_trial_count')!=154:
        raise ValueError('retro receipt authority/denominator mismatch')
    if r['held_targets']:prescreen.validate_contract(r['contract'],verify_bars=False)
    targets={t['id']:t for t in r['held_targets']}
    if len(targets)!=len(r['held_targets']):raise ValueError('duplicate retro target')
    return r,targets


def disposition(conn, row):
    row=dict(row)
    if row.get('status')!='pending' or row.get('verdict') is not None or row.get('claimed_by') is not None:return None
    if not conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='work_item_holds'").fetchone():return None
    h=conn.execute('SELECT hold_code,active,release_on_restart,reason FROM work_item_holds WHERE work_item_id=?',(row['id'],)).fetchone()
    if not h or h[0]!=HOLD or not h[1] or h[2]:return None
    current=conn.execute('SELECT status,verdict,claimed_by FROM work_items WHERE id=?',(row['id'],)).fetchone()
    if not current or tuple(current)!=('pending',None,None):return None
    binding=json.loads(h[3]);path=Path(binding['receipt_path']);stat=path.stat()
    r,targets=_receipt(str(path),binding['receipt_sha256'],stat.st_size,stat.st_mtime_ns)
    p=payload(row);t=targets.get(row['id'])
    if (binding.get('schema')!=SCHEMA or binding.get('decision_id')!=prescreen.DECISION
            or r.get('program_id')!=p.get('program_id') or r.get('plan_sha256')!=binding.get('plan_sha256')
            or not t or t['year'] not in range(2021,2026)
            or any(t[k]!=p.get(k) for k in ('cell_key','year','arm','direction','predicate_id'))):
        raise ValueError('retro held-cell receipt identity mismatch')
    decision=r['arm_decisions'][t['arm']]
    proof=decision['proof']
    if len(proof)!=4 or classify([(proof[0],proof[1]),(proof[2],proof[3])],decision['fire_counts'])[0]!='SKIP':
        raise ValueError('retro classification proof does not support SKIP')
    event=conn.execute('SELECT detail_json FROM events WHERE entity_type=? AND entity_id=? AND event=? ORDER BY id DESC LIMIT 1',
                       (ENTITY,r['program_id'],EVENT)).fetchone()
    if not event or json.loads(event[0])!=binding:raise ValueError('retro append-only program receipt row missing/mismatched')
    return {'receipt_path':str(path),'receipt_sha256':binding['receipt_sha256'],'program_id':r['program_id'],'unmeasured':True}


def project_row(conn,row):
    value=dict(row);d=disposition(conn,value)
    if d:value.update(status='done',verdict='SKIPPED_PRESCREEN',evidence_path=d['receipt_path'],prescreen_unmeasured=d)
    return value


def progress_snapshot(conn):
    columns=[r[1] for r in conn.execute('PRAGMA table_info(work_items)')]
    if not {'id','phase','status','verdict','payload_json','claimed_by'}<=set(columns):return {'valid_held_cells':0,'programs':{}}
    by=defaultdict(Counter)
    rows=conn.execute("SELECT id,phase,status,verdict,payload_json,claimed_by FROM work_items WHERE phase='OPT_CENSUS'").fetchall()
    for raw in rows:
        row=dict(zip(('id','phase','status','verdict','payload_json','claimed_by'),raw));p=payload(row)
        if p.get('year') not in range(2019,2026):continue
        d=disposition(conn,row)
        key='SKIPPED_EXCLUDED_UNMEASURED' if d else (row['verdict'] or row['status'])
        by[p.get('program_id','UNKNOWN')][key]+=1
    return {'valid_held_cells':sum(v['SKIPPED_EXCLUDED_UNMEASURED'] for v in by.values()),
            'gate_contiguity_changed':False,'programs':{k:dict(v) for k,v in sorted(by.items())}}


def apply_program(conn,program,plan_sha,out,backend,backup):
    """Caller holds shared factory lock. One SQLite transaction, INSERT only."""
    if prescreen.RETIRED:
        raise ValueError('B2/B5 prescreen retired: ' + prescreen.RETIREMENT_DECISION)
    conn.row_factory=sqlite3.Row;conn.execute('BEGIN IMMEDIATE')
    try:
        prior=conn.execute('SELECT detail_json FROM events WHERE entity_type=? AND entity_id=? AND event=?',
                           (ENTITY,program['program_id'],EVENT)).fetchall()
        if prior:
            if len(prior)!=1:raise ValueError('duplicate program receipt rows')
            binding=json.loads(prior[0][0]);path=Path(binding['receipt_path']);stat=path.stat()
            receipt,_=_receipt(str(path),binding['receipt_sha256'],stat.st_size,stat.st_mtime_ns)
            if binding['plan_sha256']!=plan_sha:raise ValueError('program already bound to a different dry-run')
            for t in receipt['held_targets']:
                row=conn.execute('SELECT * FROM work_items WHERE id=?',(t['id'],)).fetchone()
                if not row or not disposition(conn,row):raise ValueError('previous held receipt no longer active')
            conn.rollback();return {'program_id':program['program_id'],'inserted':0,'already_held':len(receipt['held_targets']),'receipt':str(path)}
        ledger=json.loads(Path(program['ledger_path']).read_text(encoding='utf-8-sig'))
        if digest(declaration(ledger))!=program['declaration_sha256']:raise ValueError('declaration drift after dry-run')
        if program['candidate_holds']:
            prescreen.validate_contract(program['contract'])
        all_before=[dict(r) for r in conn.execute("SELECT * FROM work_items WHERE phase='OPT_CENSUS' AND json_extract(payload_json,'$.program_id')=? ORDER BY id",(program['program_id'],))]
        rows={r['id']:r for r in all_before};targets=[];races=[]
        for t in program['targets']:
            row=rows.get(t['id'])
            if not row or row['status']!='pending' or row['verdict'] is not None or row['claimed_by'] is not None:
                races.append({'id':t['id'],'reason':'NO_LONGER_PENDING_UNCLAIMED'});continue
            if conn.execute('SELECT 1 FROM work_item_holds WHERE work_item_id=?',(t['id'],)).fetchone():
                races.append({'id':t['id'],'reason':'EXISTING_HOLD_PRESERVED'});continue
            p=payload(row)
            if row['ea_id']!=program['ea_id'] or row['symbol']!=program['symbol'] or row['setfile_path']!=t['setfile_path'] or any(p.get(k)!=t[k] for k in ('cell_key','year','arm','direction','predicate_id')):
                raise ValueError('target identity drift')
            d=program['arm_decisions'][t['arm']];proof=d['proof']
            if t['year'] not in range(2021,2026) or d['disposition']!='SKIP' or len(proof)!=4 or classify([(proof[0],proof[1]),(proof[2],proof[3])],d['fire_counts'])[0]!='SKIP':
                raise ValueError('target lacks stage-1 skip proof')
            targets.append(t)
        # Pin all measured inputs again inside the guarded transaction.
        checked=set()
        for arm in {t['arm'] for t in targets}:
            for m in program['arm_decisions'][arm]['proof']:
                if m['work_item_id'] in checked:continue
                row=conn.execute('SELECT * FROM work_items WHERE id=?',(m['work_item_id'],)).fetchone()
                if prescreen.measured(row)!=m:raise ValueError('stage-1 measured proof changed')
                checked.add(m['work_item_id'])
        receipt={**program,'schema':SCHEMA,'decision_id':prescreen.DECISION,'task_id':TASK,'plan_sha256':plan_sha,
                 'tool_sha256':sha(Path(__file__)),
                 'created_at':now(),'held_targets':targets,'raced_targets_preserved':races,'backup':backup,
                 'work_items_before_sha256':digest(all_before),'unmeasured':True,'release_on_restart':False}
        receipt.pop('targets')
        path=out/('program_'+hashlib.sha256(program['program_id'].encode()).hexdigest()[:16]+'.json')
        write_new(path,receipt)
        binding={'schema':SCHEMA,'decision_id':prescreen.DECISION,'plan_sha256':plan_sha,
                 'receipt_path':str(path.resolve()),'receipt_sha256':sha(path)}
        reason=json.dumps(binding,sort_keys=True);stamp=now()
        backend.inspect_targets(conn,[(t['id'],program['symbol']) for t in targets],ea_id=program['ea_id'],phase='OPT_CENSUS',hold_code=HOLD,reason=reason)
        for t in targets:
            conn.execute('INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note) VALUES(?,?,?,1,0,?,?,NULL,NULL)',
                         (t['id'],HOLD,reason,stamp,stamp))
        conn.execute('INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)',
                     (stamp,ENTITY,program['program_id'],EVENT,reason))
        all_after=[dict(r) for r in conn.execute("SELECT * FROM work_items WHERE phase='OPT_CENSUS' AND json_extract(payload_json,'$.program_id')=? ORDER BY id",(program['program_id'],))]
        if all_after!=all_before:raise ValueError('work-item row mutation detected; rollback')
        if digest(declaration(json.loads(Path(program['ledger_path']).read_text(encoding='utf-8-sig'))))!=program['declaration_sha256']:
            raise ValueError('declaration changed during hold transaction')
        for t in targets:
            if not disposition(conn,rows[t['id']]):raise ValueError('held disposition verification failed')
        conn.commit()
        return {'program_id':program['program_id'],'inserted':len(targets),'already_held':0,'raced':races,'receipt':str(path),
                'all_program_work_items_unchanged':True,'declaration_unchanged':True}
    except Exception:conn.rollback();raise


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['plan','apply','progress'])
    parser.add_argument('--plan-sha256')
    args=parser.parse_args()
    if args.command=='plan':
        con=sqlite3.connect(f'file:{DB.as_posix()}?mode=ro',uri=True);con.execute('BEGIN')
        try:result=plan(con,OUT)
        finally:con.close()
        print(json.dumps({'planned_holds':result['planned_holds'],'plan_sha256':sha(OUT/'dry_run.json')}));return
    if args.command=='progress':
        con=sqlite3.connect(f'file:{DB.as_posix()}?mode=ro',uri=True)
        try:print(json.dumps(progress_snapshot(con),indent=2))
        finally:con.close()
        return
    path=OUT/'dry_run.json'
    if not args.plan_sha256 or sha(path)!=args.plan_sha256:raise ValueError('exact recorded dry-run SHA256 required')
    saved=json.loads(path.read_text());assert saved['schema']==SCHEMA and saved['task_id']==TASK
    # Mutations reuse the canonical hold inspection/backup and lock implementations.
    sys.path.insert(0,str(CANON/'tools/strategy_farm'))
    import governed_work_item_hold as backend
    from factory_mutation_lock import FactoryMutationLock
    backend_path=Path(backend.__file__).resolve()
    if backend_path!=CANON/'tools/strategy_farm/governed_work_item_hold.py':raise ValueError('noncanonical hold backend refused')
    backup_receipt=OUT/'preapply_backup.json'
    if backup_receipt.exists():
        backup=json.loads(backup_receipt.read_text())
        if backup['plan_sha256']!=args.plan_sha256 or sha(backup['path'])!=backup['sha256']:
            raise ValueError('pre-apply backup binding changed')
    else:
        backup_path,backup_sha=backend.sqlite_backup(DB,Path('D:/QM/strategy_farm/state/backups/prescreen_retro'))
        backup={'path':str(backup_path),'sha256':backup_sha,'canonical_hold_backend_sha256':sha(backend_path),
                'plan_sha256':args.plan_sha256}
        write_new(backup_receipt,backup)
    results=[]
    for program in saved['programs']:
        lock=None
        for attempt in range(20):
            candidate=FactoryMutationLock(owner='codex:prescreen_retro:'+program['program_id'])
            try:candidate.__enter__();lock=candidate;break
            except RuntimeError:
                if attempt==19:raise
                time.sleep(0.25)
        try:
            con=sqlite3.connect(DB,timeout=60)
            try:result=apply_program(con,program,args.plan_sha256,OUT,backend,backup)
            finally:con.close()
        finally:lock.__exit__(None,None,None)
        results.append(result);print(json.dumps(result),flush=True)
    write_new(OUT/('apply_'+dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')+'.json'),
              {'schema':SCHEMA,'plan_sha256':args.plan_sha256,'backup':backup,'programs':results,'inserted':sum(r['inserted'] for r in results)})


if __name__=='__main__':main()
