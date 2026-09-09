"""Sealed, append-only Balke window experiment: plan, enqueue, report.

This program owns its selection rule. It never invokes or changes DL-089 selection.
"""
from __future__ import annotations
import argparse
import csv
import datetime as dt
import hashlib
import html
import json
import re
import sqlite3
import statistics
import subprocess
import sys
import uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0,str(ROOT))
PROGRAM='WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025'
SCHEMA='qm.window-sweep.v1'
AUTHORITY=ROOT/'docs/research/BALKE_WINDOW_SWEEP_PLAN_2026-09-09.md'
ART=Path('D:/QM/strategy_farm/artifacts/opt_census')/PROGRAM
BASE=ART.parent/'DL089_QM5_13213_USDJPY_DWX_2019_2025/setfiles/QM5_41398_balke-pattern-repair-opt_USDJPY.DWX_H1_opt_census_2019_baseline.set'
EA=ROOT/'framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt'
DB=Path('D:/QM/strategy_farm/state/farm_state.sqlite')
EVIDENCE=ROOT/'docs/ops/evidence'
YEARS=list(range(2019,2026))
NAMESPACE=uuid.UUID('f45f154c-65d5-5e0f-96c8-505bc44bbc39')
TASK='49af4f08-0d72-460d-959e-7c9a32db4650'
class SweepError(ValueError): pass
def digest(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def canonical(obj): return (json.dumps(obj,sort_keys=True,separators=(',',':'),ensure_ascii=True)+'\n').encode()
def seal(obj): return hashlib.sha256(canonical(obj)).hexdigest()
def write_json(p,obj):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(obj,indent=2,sort_keys=True)+'\n',encoding='utf-8',newline='\n')
def text(p):
    b=Path(p).read_bytes();return b.decode('utf-16' if b[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')
def inputs(s): return dict(re.findall(r'^\s*(\w+)\s*=\s*([^\r\n;]+)',s,re.M))
def stage_a(): return [(s,n,18) for s in range(10) for n in range(2,9) if s+n<=13]
def authority_sections(s):
    return {str(i):s[s.index(f'## {i}.'):s.index(f'## {i+1}.')] for i in (3,4,5)}
def declaration(art=ART):
    base_values=inputs(text(BASE))
    if float(base_values.get('RISK_FIXED',0))!=1000 or float(base_values.get('RISK_PERCENT',1))!=0: raise SweepError('risk contract drift')
    if int(base_values.get('qm_news_stale_max_hours',999))>336: raise SweepError('news staleness exceeds ceiling')
    if any(int(base_values.get(f'opt_pp_{side}{n}',-1))!=0 for side in ('buy','sell') for n in (1,2,3)): raise SweepError('pattern profile not neutral')
    if int(base_values.get('strategy_range_scan_bars',0))<36: raise SweepError('range scan below declared minimum')
    commit=subprocess.check_output(['git','-C',str(ROOT),'log','-1','--format=%H','--',str(AUTHORITY.relative_to(ROOT))],text=True).strip()
    committed=subprocess.check_output(['git','-C',str(ROOT),'show',f'{commit}:{AUTHORITY.relative_to(ROOT).as_posix()}'])
    if committed.replace(b'\r\n',b'\n')!=AUTHORITY.read_bytes().replace(b'\r\n',b'\n'): raise SweepError('plan working copy differs from committed authority')
    d={'schema':SCHEMA,'program_id':PROGRAM,'authority_path':str(AUTHORITY),'plan_commit':commit,'plan_sha256':digest(AUTHORITY),'verbatim_sections_3_5':authority_sections(text(AUTHORITY)),'declared_trial_count':90,'parameter_count':3,'years':YEARS,'stage_a_windows':[list(v) for v in stage_a()],'stage_b_exits':[15,16,17,19,20,21],'base_setfile_path':str(BASE),'base_setfile_sha256':digest(BASE),'ea_id':'QM5_41398','ea_label':EA.name,'symbol':'USDJPY.DWX','timeframe':'H1','artifact_identity':{'mq5_path':str(EA.with_suffix('.mq5')),'mq5_sha256':digest(EA.with_suffix('.mq5')),'ex5_path':str(EA.with_suffix('.ex5')),'ex5_sha256':digest(EA.with_suffix('.ex5'))},'cost_semantics':'plan section 4: summary net_profit minus 5 USD per entry lot; native commissions also reported explicitly','source_task':TASK}
    d['declaration_sha256']=seal(d)
    p=Path(art)/'declaration.json'
    if p.exists() and json.loads(p.read_text(encoding='utf-8'))!=d: raise SweepError('existing declaration differs; new program required')
    return d
def validate_declaration(d):
    unsigned=dict(d);expected=unsigned.pop('declaration_sha256',None)
    if expected!=seal(unsigned):raise SweepError('declaration hash mismatch')
    if d.get('schema')!=SCHEMA or d.get('program_id')!=PROGRAM or d.get('declared_trial_count')!=90 or d.get('parameter_count')!=3:raise SweepError('unsupported window program')
    if d.get('years')!=YEARS or d.get('stage_a_windows')!=[list(v) for v in stage_a()]:raise SweepError('grid drift')
    for p,h in [(d['authority_path'],d['plan_sha256']),(d['base_setfile_path'],d['base_setfile_sha256'])]+[(d['artifact_identity'][k+'_path'],d['artifact_identity'][k+'_sha256']) for k in ('mq5','ex5')]:
        if digest(p)!=h:raise SweepError(f'artifact changed: {p}')
def cells_for(windows,art):
    cells=[]
    for s,n,x in windows:
        arm=f's{s}_l{n}_x{x}'
        for year in YEARS:
            key=f'{PROGRAM}:{year}:{arm}'
            cells.append({'cell_key':key,'work_item_id':str(uuid.uuid5(NAMESPACE,key)),'year':year,'arm':arm,'direction':'NONE','predicate_id':0,'start':s,'length':n,'exit':x,'from_date':f'{year}.01.01','to_date':f'{year}.12.31','setfile_path':str(Path(art)/'setfiles'/f'{EA.name}_USDJPY.DWX_H1_{year}_{arm}.set')})
    return cells
def build_plan(stage='A',art=ART,stage_a_report=None):
    d=declaration(art);windows=stage_a()
    if stage=='B':
        if not stage_a_report:raise SweepError('stage B requires complete stage-A report')
        report=json.loads(Path(stage_a_report).read_text(encoding='utf-8'))
        if report.get('declaration_sha256')!=d['declaration_sha256'] or not report.get('complete') or len(report.get('top_five',[]))!=5:raise SweepError('stage-A report incomplete or wrong declaration')
        windows=[(w['start'],w['length'],x) for w in report['top_five'] for x in d['stage_b_exits']]
    cells=cells_for(windows,art)
    assert len(cells)==(420 if stage=='A' else 210)
    return {'schema':SCHEMA,'program_id':PROGRAM,'stage':stage,'declaration':d,'years':YEARS,'cells':cells,'ea_id':'QM5_41398','symbol':'USDJPY.DWX','planned_trials':len(cells)}
def render(base,cell):
    replacements={'strategy_range_start_hour':str(cell['start']),'strategy_range_end_hour':str(cell['start']+cell['length']),'strategy_exit_hour':str(cell['exit'])}
    result=base
    for key,value in replacements.items():
        result,count=re.subn(rf'(?m)^\s*{key}\s*=.*$',f'{key}={value}',result)
        if count!=1:raise SweepError(f'setfile input not unique: {key}')
    before,after=inputs(base),inputs(result)
    if set(before)!=set(after) or any(before[k]!=after[k] for k in before if k not in replacements):raise SweepError('unrelated input drift')
    return result.replace('\r\n','\n')
def enqueue(plan,db=DB,art=ART,apply=False):
    d=plan['declaration'];validate_declaration(d)
    if plan['stage']!='A':raise SweepError('stage B enqueue requires separate Claude adjudication; only plan is available')
    if apply and Path(db).resolve()==DB.resolve():require_current_workers()
    ledger_path=Path(art)/'ledger.json';base=text(BASE)
    rendered={c['work_item_id']:render(base,c) for c in plan['cells']}
    conn=sqlite3.connect(f'file:{Path(db).as_posix()}?mode={"rw" if apply else "ro"}',uri=True,timeout=60);conn.row_factory=sqlite3.Row
    try:
        # Reuse existing Q02 and fixture evidence gates, not their selection rule.
        try: from tools.strategy_farm import opt_census
        except ModuleNotFoundError: import opt_census
        q02=opt_census._q02_pass(conn,'QM5_41398')
        fixture=opt_census._harness_pass(conn,opt_census.HARNESS_WORK_ITEM_ID)
        priority=conn.execute("SELECT id,payload_json FROM work_items WHERE ea_id='QM5_41398' AND phase='OPT_CENSUS' AND status='pending' AND json_extract(payload_json,'$.program_id')='DL089_QM5_13213_USDJPY_DWX_2019_2025' AND json_extract(payload_json,'$.opt_census_frontier_priority')=1 LIMIT 1").fetchone()
        if priority is None:raise SweepError('no pending reference frontier row; do not invent priority')
        pp=json.loads(priority['payload_json'])
        ledger={k:v for k,v in plan.items() if k!='declaration'}
        ledger.update(declaration_path=str(Path(art)/'declaration.json'),declaration_sha256=d['declaration_sha256'],q02_precondition=q02,harness_evidence=fixture)
        payloads={}
        for c in plan['cells']:
            h=hashlib.sha256(rendered[c['work_item_id']].encode()).hexdigest();c['setfile_sha256']=h
            payload={**{k:c[k] for k in ('cell_key','year','arm','direction','predicate_id','from_date','to_date')},'schema':SCHEMA,'program_id':PROGRAM,'host_timeframe':'H1','opt_census_pool':True,'declared_trial_count':90,'planned_trials':420,'ledger_path':str(ledger_path),'declaration_path':ledger['declaration_path'],'declaration_sha256':d['declaration_sha256'],'source_agent_task_id':TASK,'priority_track':pp.get('priority_track') is True,'opt_census_frontier_priority':pp.get('opt_census_frontier_priority') is True,'priority_source_work_item':priority['id'],'evidence_binding_required':True,'expected_ex5_sha256':d['artifact_identity']['ex5_sha256'],'expected_mq5_sha256':d['artifact_identity']['mq5_sha256'],'expected_setfile_sha256':h,'expected_expert':EA.name,'artifact_identity':{**d['artifact_identity'],'setfile_sha256':h,'data_window_start':c['from_date'],'data_window_end':c['to_date']}}
            payload.update(expected_expert='QM\\'+EA.name,expected_symbol='USDJPY.DWX',expected_period='H1',expected_from_date=c['from_date'],expected_to_date=c['to_date'])
            payloads[c['work_item_id']]=payload
        existing=0
        for c in plan['cells']:
            row=conn.execute('SELECT * FROM work_items WHERE id=?',(c['work_item_id'],)).fetchone()
            if row:
                old=json.loads(row['payload_json'])
                if row['phase']!='OPT_CENSUS' or row['ea_id']!='QM5_41398' or row['symbol']!='USDJPY.DWX' or row['setfile_path']!=c['setfile_path'] or any(old.get(k)!=payloads[c['work_item_id']].get(k) for k in ('schema','program_id','cell_key','declaration_sha256','expected_setfile_sha256')):raise SweepError('idempotency collision')
                existing+=1
        result={'apply':apply,'planned':len(plan['cells']),'existing':existing,'new_rows':len(plan['cells'])-existing,'priority_source':priority['id'],'priority_track':True,'opt_census_frontier_priority':True,'cells':plan['cells']}
        if not apply:return result
        write_json(Path(art)/'declaration.json',d)
        # Sealed ledger is immutable; runtime status belongs to DB and reports.
        if ledger_path.exists() and json.loads(ledger_path.read_text())!=ledger:raise SweepError('ledger drift')
        write_json(ledger_path,ledger)
        for c in plan['cells']:
            p=Path(c['setfile_path']);p.parent.mkdir(parents=True,exist_ok=True)
            wanted=rendered[c['work_item_id']].encode()
            if p.exists() and p.read_bytes()!=wanted:raise SweepError('setfile drift')
            p.write_bytes(wanted)
        conn.execute('BEGIN IMMEDIATE')
        inserted=0;now=dt.datetime.now(dt.timezone.utc).isoformat()
        for c in plan['cells']:
            cur=conn.execute("INSERT OR IGNORE INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES (?,'backtest','OPT_CENSUS','QM5_41398','USDJPY.DWX',?,'pending',0,?,?,?)",(c['work_item_id'],c['setfile_path'],json.dumps(payloads[c['work_item_id']],sort_keys=True),now,now));inserted+=cur.rowcount
        conn.commit();result['inserted']=inserted;return result
    except Exception:
        conn.rollback();raise
    finally:conn.close()

def require_current_workers():
    """Old daemon modules would treat the new schema as ungoverned legacy work.

    A conservative process start-time check is deliberately read-only. A safe
    idle rollout belongs to the worker operator; this command never stops it.
    """
    command="Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^python(w)?\\.exe$' -and $_.CommandLine -match 'terminal_worker\\.py' } | ForEach-Object { [pscustomobject]@{pid=$_.ProcessId; command=$_.CommandLine; started=([DateTimeOffset]$_.CreationDate).ToUnixTimeSeconds()} } | ConvertTo-Json -Compress"
    raw=subprocess.check_output(['powershell','-NoProfile','-Command',command],text=True)
    rows=json.loads(raw or '[]');rows=rows if isinstance(rows,list) else [rows]
    threshold=max(Path(__file__).stat().st_mtime,(ROOT/'tools/strategy_farm/terminal_worker.py').stat().st_mtime)
    stale=[r['pid'] for r in rows if float(r['started'])<=threshold or str(ROOT).replace('\\','/').lower() not in r['command'].replace('\\','/').lower()]
    if not rows or stale:raise SweepError(f'WORKER_ROLLOUT_REQUIRED: stale or noncanonical worker PIDs {stale}; no rows inserted')
def authenticate_ledger(payload):
    if payload.get('schema')!=SCHEMA or payload.get('program_id')!=PROGRAM:raise SweepError('unregistered window program')
    dp=Path(payload.get('declaration_path',''));d=json.loads(dp.read_text(encoding='utf-8'));validate_declaration(d)
    if d['declaration_sha256']!=payload.get('declaration_sha256'):raise SweepError('payload declaration mismatch')
    lp=Path(payload.get('ledger_path',''));ledger=json.loads(lp.read_text(encoding='utf-8'))
    if ledger.get('schema')!=SCHEMA or ledger.get('program_id')!=PROGRAM or ledger.get('declaration_sha256')!=d['declaration_sha256'] or ledger.get('years')!=YEARS or ledger.get('stage')!='A':raise SweepError('ledger contract drift')
    expected=cells_for(stage_a(),lp.parent);cells=ledger.get('cells',[])
    if len(cells)!=420:raise SweepError('incomplete ledger')
    for actual,wanted in zip(cells,expected):
        if any(actual.get(k)!=v for k,v in wanted.items()):raise SweepError('ledger cell changed')
    target=next((c for c in cells if c['cell_key']==payload.get('cell_key')),None)
    if target is None:raise SweepError('candidate absent')
    for key in ('year','arm','direction','predicate_id','from_date','to_date'):
        if target[key]!=payload.get(key):raise SweepError(f'payload {key} mismatch')
    for key,value in dict(expected_expert='QM\\'+EA.name,expected_symbol='USDJPY.DWX',expected_period='H1',expected_from_date=target['from_date'],expected_to_date=target['to_date'],evidence_binding_required=True).items():
        if payload.get(key)!=value:raise SweepError(f'payload {key} binding mismatch')
    wanted=render(text(BASE),target).encode();h=hashlib.sha256(wanted).hexdigest()
    if target.get('setfile_sha256')!=h or payload.get('expected_setfile_sha256')!=h or digest(target['setfile_path'])!=h:raise SweepError('candidate setfile binding mismatch')
    for k in ('ex5','mq5'):
        if payload.get(f'expected_{k}_sha256')!=d['artifact_identity'][k+'_sha256']:raise SweepError('candidate binary/source mismatch')
    return lp,ledger
def native_rows(p):
    s=text(p);s=s[s.rfind('>Deals<'):];result=[]
    for tr in re.findall(r'<tr\b[^>]*>(.*?)</tr>',s,re.S):
        a=[html.unescape(re.sub('<[^>]+>','',v)).strip() for v in re.findall(r'<td\b[^>]*>(.*?)</td>',tr,re.S)]
        if len(a)==13 and a[4] in ('in','out'):result.append(a)
    return result
def number(s):return float(str(s).replace(' ','').replace('\xa0','') or 0)
def measure(summary_path,payload):
    obj=json.loads(Path(summary_path).read_text(encoding='utf-8-sig'));runs=[r for r in obj.get('runs',[]) if r.get('status')=='OK']
    from tools.strategy_farm import farmctl
    if not farmctl._summary_matches_expected_evidence(obj,payload):raise SweepError('native execution identity/window mismatch')
    if len(runs)!=1:raise SweepError('expected one native OK run')
    r=runs[0];p=Path(r['report_canonical_path']);deals=native_rows(p)
    entries=[x for x in deals if x[4]=='in'];exits=[x for x in deals if x[4]=='out']
    if len(entries)!=len(exits) or len(entries)!=int(r['total_trades']):raise SweepError('native deal count mismatch')
    pooled=[]
    for a,b in zip(entries,exits):
        if a[0]>b[0] or number(a[5])!=number(b[5]):raise SweepError('native round-trip pairing mismatch')
        net=sum(number(x[i]) for x in (a,b) for i in (8,9,10))
        pooled.append(net-5*number(a[5]))
    net=float(r['net_profit']);native_net=sum(number(x[i]) for x in deals for i in (8,9,10))
    if abs(net-native_net)>.011:raise SweepError('native net reconciliation failed')
    lots=sum(number(x[5]) for x in entries);dd=float(r['drawdown'])
    return {'trades':len(entries),'entry_days':len({x[0][:10] for x in entries}),'net_native':net,'gross_price_profit':sum(number(x[10]) for x in deals),'native_commission':sum(number(x[8]) for x in deals),'lots_rt':lots,'net_costed_plan':net-5*lots,'maxdd':dd,'score':(net-5*lots)/max(dd,1),'costed_trade_pnl':pooled,'native_report':str(p),'native_report_sha256':digest(p),'summary':str(summary_path),'summary_sha256':digest(summary_path)}
def select(windows):
    """Pure frozen stage-A rule. Refuse selection until every cell is measured."""
    if any(len(w.get('years',{}))!=7 for w in windows):return {'complete':False,'winner':None,'top_five':[],'reason':'incomplete annual matrix'}
    by={(w['start'],w['length']):w for w in windows}
    for w in windows:
        values=list(w['years'].values());w['admissible']=all(v['entry_days']>=10 and v['trades']>=5 for v in values) and statistics.mean(v['trades'] for v in values)>=40
        w['dev_score']=statistics.median(w['years'][y]['score'] for y in (2019,2020,2021,2022))
    for w in windows:
        neighbors=[by[(s,n)] for s in range(w['start']-1,w['start']+2) for n in range(w['length']-1,w['length']+2) if (s,n) in by]
        # The sealed neighbourhood is all valid GRID points. Admissibility
        # excludes candidate winners, not points from this fixed neighbourhood.
        w['plateau_score']=statistics.median(n['dev_score'] for n in neighbors)
    ranked=sorted((w for w in windows if w['admissible']),key=lambda w:(-w['plateau_score'],w['length'],w['start']))
    if not ranked:return {'complete':True,'winner':None,'top_five':[],'refutation':'NO_ADMISSIBLE_WINDOW'}
    winner=ranked[0];baseline=by[(3,3)]
    if not baseline['admissible']:return {'complete':True,'winner':None,'top_five':[],'refutation':'BASELINE_INADMISSIBLE'}
    oos=[winner['years'][y] for y in (2023,2024,2025)];bp=[baseline['years'][y] for y in (2023,2024,2025)]
    pnls=[n for v in oos for n in v['costed_trade_pnl']];profit=sum(n for n in pnls if n>0);loss=-sum(n for n in pnls if n<0)
    pf=profit/loss if loss else None
    confirm=statistics.median(v['score'] for v in oos)>=statistics.median(v['score'] for v in bp) and (pf>=1 if pf is not None else profit>0)
    improvement=winner['plateau_score']>=1.10*baseline['dev_score']
    slim=lambda w:{k:w[k] for k in ('start','length','exit','dev_score','plateau_score')}
    return {'complete':True,'winner':slim(winner),'top_five':[slim(w) for w in ranked[:5]],'oos_pooled_pf':pf,'oos_confirmation':confirm,'dev_improvement':improvement,'refutation':'SURVIVES' if confirm and improvement else 'REFUTED'}
def report(art=ART,db=DB,output=EVIDENCE/'2026-09-09_window_sweep_surface.csv'):
    d=json.loads((Path(art)/'declaration.json').read_text());validate_declaration(d)
    cells=cells_for(stage_a(),art);conn=sqlite3.connect(f'file:{Path(db).as_posix()}?mode=ro',uri=True);conn.row_factory=sqlite3.Row
    surface=[];missing=[];windows={(s,n):{'start':s,'length':n,'exit':x,'years':{}} for s,n,x in stage_a()}
    try:
        for c in cells:
            row=conn.execute('SELECT status,verdict,evidence_path,payload_json FROM work_items WHERE id=?',(c['work_item_id'],)).fetchone()
            entry={k:c[k] for k in ('cell_key','work_item_id','start','length','exit','year')};entry.update(status=row['status'] if row else 'NOT_ENQUEUED',verdict=row['verdict'] if row else '',error='')
            if row and row['status']=='done' and row['verdict']=='MEASURED':
                try:
                    payload=json.loads(row['payload_json']);authenticate_ledger(payload)
                    m=measure(row['evidence_path'],payload);windows[(c['start'],c['length'])]['years'][c['year']]=m
                    entry.update({k:v for k,v in m.items() if k!='costed_trade_pnl'})
                except (OSError,ValueError,KeyError) as exc:entry['error']=str(exc);missing.append(c['cell_key'])
            else:missing.append(c['cell_key'])
            surface.append(entry)
    finally:conn.close()
    selection=select(list(windows.values()))
    for entry in surface:entry['window_admissible']=windows[(entry['start'],entry['length'])].get('admissible','UNDETERMINED')
    fields=list(dict.fromkeys(k for r in surface for k in r));Path(output).parent.mkdir(parents=True,exist_ok=True)
    with Path(output).open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(surface)
    result={'schema':SCHEMA,'program_id':PROGRAM,'declaration_sha256':d['declaration_sha256'],'missing_or_unusable_cells':missing,'surface_path':str(output),'stage_table':[{k:v for k,v in w.items() if k!='years'} for w in windows.values()],**selection}
    write_json(Path(output).with_suffix('.json'),result);return result
def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    for name in ('plan','enqueue','report'):
        p=sub.add_parser(name);p.add_argument('--artifacts',type=Path,default=ART);p.add_argument('--output',type=Path)
        if name!='report':p.add_argument('--stage',choices=('A','B'),default='A');p.add_argument('--stage-a-report',type=Path)
        if name!='plan':p.add_argument('--db',type=Path,default=DB)
        if name=='enqueue':p.add_argument('--apply',action='store_true')
    a=parser.parse_args()
    try:
        if a.command=='report':result=report(a.artifacts,a.db,a.output or EVIDENCE/'2026-09-09_window_sweep_surface.csv')
        else:
            plan=build_plan(a.stage,a.artifacts,a.stage_a_report)
            result=plan if a.command=='plan' else enqueue(plan,a.db,a.artifacts,a.apply)
            if a.output:write_json(a.output,result)
        print(json.dumps(result,indent=2));return 0
    except (SweepError,OSError,sqlite3.Error) as exc:print(json.dumps({'ok':False,'error':str(exc)}));return 2
if __name__=='__main__':raise SystemExit(main())
