"""Read-only FTMO qualification planner; never submits or promotes work."""
from __future__ import annotations
import argparse,hashlib,json,sqlite3,sys,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
if str(ROOT) not in sys.path:sys.path.insert(0,str(ROOT))
from tools.strategy_farm import gate_manifest,q09_news_contract as contract,build_q09_include_closure as closure
from tools.strategy_farm.portfolio import ftmo_q09_admission as admission
DEFAULT_INTAKE=ROOT/'docs/ops/evidence/2026-09-09_ftmo_acceleration/intake.json'
DEFAULT_ROSTER=ROOT/'docs/ops/evidence/2026-09-09_ftmo_shortlist/comparison.json'
CALENDAR_CONFIG=ROOT/'tools/strategy_farm/config/news_calendar_scoped_consumer_b.v1.json'
DB=Path('D:/QM/strategy_farm/state/farm_state.sqlite')
SCHEMA='qm.ftmo-qualification-dry-run/v1'
NAMESPACE=uuid.UUID('e038a70c-7e7c-4ddf-a309-f36a748a796d')
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def key(ea,symbol):return f'{ea}:{symbol}'
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'))
def validate_selection(intake,roster,requested=None):
    allowed={key(p['ea_id'],p['symbol']) for p in intake['pairs']}
    selected=roster.get('selected_pairs')
    if not isinstance(selected,list) or len(selected)>5 or len(set(selected))!=len(selected):raise ValueError('roster must contain zero to five distinct pair keys')
    if not set(selected)<=allowed:raise ValueError('roster outside frozen intake')
    wanted=selected if requested is None else requested
    if len(wanted)>5 or len(set(wanted))!=len(wanted) or not set(wanted)<=set(selected):raise ValueError('requested pairs exceed prospective roster')
    return sorted(wanted)
def request_id(binding):return str(uuid.uuid5(NAMESPACE,SCHEMA+canonical(binding)))
def exact_existing(rows,binding):
    # Full binding includes plan window/policy identities. Similar old evidence
    # is never treated as the same qualification request.
    return sorted(r['id'] for r in rows if r.get('binding')==binding)
def calendar_identity():
    config=read(CALENDAR_CONFIG);candidate=config['candidate'];files=[]
    for role in ('manifest','declarations'):
        p=Path(candidate[role+'_path']);expected=candidate[role+'_sha256']
        files.append({'role':role,'path':str(p),'sha256':sha(p),'hash_matches':sha(p)==expected})
    parent=Path(candidate['manifest_path']).parent
    for name,expected in candidate['calendar_files'].items():
        p=parent/name;files.append({'role':name,'path':str(p),'sha256':sha(p),'hash_matches':sha(p)==expected})
    return {'config_path':str(CALENDAR_CONFIG),'config_sha256':sha(CALENDAR_CONFIG),'files':files,'verified':all(f['hash_matches'] for f in files),'scope':config['admissibility'],'release_mode':config['admissibility']['release_mode']}
def inventory(conn,pair,cal):
    ea,symbol=pair['ea_id'],pair['symbol'];result={'ea_id':ea,'symbol':symbol,'cost_eligibility':'NOT_ESTABLISHED','deployment_eligibility':False,'blockers':[]}
    a=admission.evaluate_ftmo_q09_admission(conn,ea,symbol);result['news_admission']=a
    paths=list((ROOT/'framework/EAs').glob(ea+'_*'))
    if len(paths)!=1:return dict(result,source_compatibility='AMBIGUOUS_EA_DIRECTORY',blockers=['EXACT_ACTIVE_SOURCE_REQUIRED'])
    directory=paths[0];source=directory/(directory.name+'.mq5');binary=source.with_suffix('.ex5');setfile=directory/'sets'/f'{directory.name}_{symbol}_D1_backtest.set'
    row=conn.execute('SELECT * FROM work_items WHERE id=?',(a['q09_news_work_item_id'],)).fetchone() if a['q09_news_work_item_id'] else None
    if row and row['setfile_path']:setfile=Path(row['setfile_path'])
    if not setfile.is_file():
        choices=sorted((directory/'sets').glob(f'{directory.name}_{symbol}_*_backtest.set'))
        if len(choices)==1:setfile=choices[0]
    cp=closure.OUT_DIR/f'{ea}_include_closure.json'
    result['current_files']={role:{'path':str(p),'sha256':sha(p) if p.is_file() else None} for role,p in [('mq5',source),('ex5',binary),('baseline_setfile',setfile),('include_closure',cp)]}
    for role,item in result['current_files'].items():
        if item['sha256'] is None:result['blockers'].append(role.upper()+'_MISSING')
    try:
        closure.validate_include_closure(ea,cp,ea_dir=directory);result['include_closure_current']=True
    except (RuntimeError,OSError,ValueError) as exc:
        result['include_closure_current']=False;result['blockers'].append('INCLUDE_CLOSURE_NOT_CURRENT');result['include_closure_error']=str(exc)
    test=conn.execute('SELECT contract_version,calendar_bundle_id,baseline_setfile_sha256,ex5_sha256,include_closure_sha256,aggregate_path,aggregate_sha256 FROM q09_news_tests WHERE work_item_id=?',(a['q09_news_work_item_id'],)).fetchone() if row else None
    if test:
        test=dict(test);result['historical_news_identity']=test
        result['historical_ex5_matches_current']=test['ex5_sha256']==result['current_files']['ex5']['sha256']
        result['contract_supported']=test['contract_version'] in ('Q09_NEWS_V2','Q09_NEWS_V3')
        relation=admission._cell_relation(conn)
        seeds=conn.execute(f'SELECT seed,count(*) n FROM {relation} WHERE q09_news_work_item_id=? GROUP BY seed',(a['q09_news_work_item_id'],)).fetchall()
        result['native_seed_counts']={str(r['seed']):r['n'] for r in seeds}
        if not result['historical_ex5_matches_current']:result['blockers'].append('HISTORICAL_BINARY_DIFFERS')
        if not result['contract_supported']:result['blockers'].append('UNSUPPORTED_NEWS_CONTRACT')
    else:result['blockers'].append('NO_NEWS_IDENTITY')
    result['source_compatibility']='CURRENT_CLOSURE_VERIFIED' if result['include_closure_current'] else 'REQUALIFICATION_REQUIRED'
    if not a['admitted']:result['blockers'].append(a['reason_code'])
    result['calendar_identity']=cal['config_sha256']
    # Scoped activation is row-by-row. Merely matching a currency is not release.
    result['blockers'].extend(['TARGET_FTMO_CALENDAR_SCOPE_AND_ROW_RELEASE_REQUIRED','PROSPECTIVE_WINDOWS_NOT_SEALED','COST_AND_EXECUTION_ACCEPTANCE_REQUIRED'])
    result['target_plan_contract']='Q09_NEWS_V3'
    result['target_native_configs']=8;result['target_native_windows_per_config']=2
    result['target_native_runs_before_reuse']=16
    result['native_cost_seconds']=None
    return result
def build(conn,intake,roster,cal,requested=None):
    selected=validate_selection(intake,roster,requested);phase=gate_manifest.load_gate_manifest().storage_phase_for_role('NEWS','NEWS')
    matrix=[inventory(conn,p,cal) for p in intake['pairs']]
    requests=[]
    for row in matrix:
        if key(row['ea_id'],row['symbol']) not in selected:continue
        binding={'ea_id':row['ea_id'],'symbol':row['symbol'],'phase':phase,'target':'FTMO','contract':'Q09_NEWS_V3','files':row.get('current_files',{}),'calendar_config_sha256':cal['config_sha256'],'prospective_windows_sha256':None,'roster_sha256':hashlib.sha256(canonical(roster).encode()).hexdigest()}
        rows=[]
        for old in conn.execute('SELECT id,payload_json FROM work_items WHERE ea_id=? AND symbol=? AND phase=?',(row['ea_id'],row['symbol'],phase)):
            p=json.loads(old['payload_json'] or '{}');rows.append({'id':old['id'],'binding':p.get('ftmo_acceleration_binding')})
        duplicates=exact_existing(rows,binding)
        requests.append({'request_id':request_id(binding),'binding':binding,'existing_exact_requests':duplicates,'action':'REUSE_EXISTING_REQUEST' if duplicates else 'WAIT_FOR_PREREQUISITES','new_native_runs_now':0,'blockers':row['blockers']})
    return {'schema':SCHEMA,'phase':phase,'current_calendar':cal,'pairs':matrix,'selected_pairs':selected,'requests':requests,'new_work_items':0,'database_mutations':0,'no_holdout_metrics_read':True,'admitted_count':sum(r['news_admission']['admitted'] for r in matrix),'role_boundaries':['source compatibility','news admission','cost eligibility','deployment eligibility']}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--intake',type=Path,default=DEFAULT_INTAKE);p.add_argument('--roster',type=Path,default=DEFAULT_ROSTER);p.add_argument('--db',type=Path,default=DB);p.add_argument('--pairs',nargs='*');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    conn=sqlite3.connect(f'file:{a.db.as_posix()}?mode=ro',uri=True);conn.row_factory=sqlite3.Row;conn.execute('PRAGMA query_only=ON');conn.execute('BEGIN')
    try:r=build(conn,read(a.intake),read(a.roster),calendar_identity(),a.pairs)
    finally:conn.close()
    r['input_bindings']={str(p):sha(p) for p in (a.intake,a.roster,Path(__file__))}
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(r,indent=2)+'\n',encoding='utf-8');print(json.dumps({'pairs':len(r['pairs']),'admitted':r['admitted_count'],'requests':len(r['requests']),'new_rows':0,'phase':r['phase']}))
if __name__=='__main__':main()
